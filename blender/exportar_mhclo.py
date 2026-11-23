# SPDX-License-Identifier: GPL-3.0-or-later
"""Exporta assets .mhclo de MakeHuman (pelo, ropa: CC0) como piezas que siguen al cuerpo (fase RE, MH01/MH02).

Uso: blender -b -P blender/exportar_mhclo.py -- godot/datos/humana godot/packs/makehuman <tipo>:<ruta.mhclo> ...
     tipo: pelo, ropa_torso, ropa_piernas, ropa_pies o accesorio (la ranura de la pieza).
Escribe en <pack> un <id>.glb por asset (con su .import) y pack.json (lo rehace con los assets de esta llamada).

Cada asset lo encaja MPFB (HumanService.add_mhclo_asset: posición y pesos interpolados del cuerpo) sobre el cuerpo
neutro. Sus formas, con los mismos nombres que cuerpo.glb: para cada forma se pone el cuerpo neutro + esa forma
(todos los vértices, helpers incluidos; medida como en exportar_helpers.py) y se vuelve a encajar el asset con
ClothesService.fit_clothes_to_human; la forma es lo que se ha movido. Se quitan las que lo mueven menos de MIN_DELTA.
Sin materiales ni texturas: el color lo pone el programa (estilo ilustración). Todo en pose A, como cuerpo.glb.
"""
import hashlib
import json
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import exportar_datos as ed  # noqa: E402
import exportar_helpers as eh  # noqa: E402
import generar_cuerpo as gc  # noqa: E402
from bl_ext.blender_org.mpfb.entities.clothes.mhclo import Mhclo  # noqa: E402
from bl_ext.blender_org.mpfb.services import ClothesService, HumanService  # noqa: E402
from exportar_glb import export_glb, rename_to_humanoid  # noqa: E402
from limpiar_malla import bake_shapes, remove_masks, remove_non_bone_groups  # noqa: E402
from poner_rig import add_rig, limit_weights  # noqa: E402

MIN_DELTA = 0.0001  # metros (0,1 mm): una forma que mueve menos el asset no se guarda
PACK = {"formato": "gamemolde-pack", "version": 1, "id": "makehuman", "nombre": "MakeHuman (system assets)",
        "autor": "MakeHuman Community", "licencia": "CC0-1.0",
        "origen": "https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html"}
TYPES = {"pelo": "pelo", "ropa_torso": "ropa", "ropa_piernas": "ropa", "ropa_pies": "ropa", "accesorio": "accesorio"}
COLORS = {"pelo": [0.24, 0.16, 0.12], "ropa": [0.3, 0.32, 0.4], "accesorio": [0.25, 0.22, 0.2]}


def full_deltas(names, measured, skin_only, coords, skin):
    """{forma: desplazamiento de todos los vértices}: las de MakeHuman, medidas; las de cara y propias (solo piel),
    copiadas en los helpers del vértice de piel más cercano."""
    nearest = eh.nearest_skin(coords, skin, list(range(skin, len(coords))))
    deltas = {}
    for name in names:
        if name in measured:
            deltas[name] = measured[name]
        else:
            skin_part = skin_only[name]
            deltas[name] = np.concatenate([skin_part, skin_part[nearest]])
    return deltas


def clothes_coords(clothes):
    coords = np.empty(len(clothes.data.vertices) * 3)
    clothes.data.vertices.foreach_get("co", coords)
    return coords.reshape(-1, 3)


def fit_shapes(basemesh, assets, mhclos, names, deltas):
    """{asset: {forma: desplazamiento}}: cada forma, encajando de nuevo los assets sobre neutro + forma."""
    base = np.empty(len(basemesh.data.vertices) * 3)
    basemesh.data.vertices.foreach_get("co", base)
    basemesh.shape_key_add(name="Basis", from_mix=False)
    probe = basemesh.shape_key_add(name="_sonda", from_mix=False)
    probe.value = 1.0
    neutral = {}
    for clothes, mhclo in zip(assets, mhclos):
        ClothesService.fit_clothes_to_human(clothes, basemesh, mhclo)
        neutral[clothes.name] = clothes_coords(clothes)
    shapes = {clothes.name: {} for clothes in assets}
    for name in names:
        probe.data.foreach_set("co", base + deltas[name].ravel())
        basemesh.data.update()
        for clothes, mhclo in zip(assets, mhclos):
            ClothesService.fit_clothes_to_human(clothes, basemesh, mhclo)
            moved = clothes_coords(clothes) - neutral[clothes.name]
            if np.linalg.norm(moved, axis=1).max() >= MIN_DELTA:
                shapes[clothes.name][name] = (moved, None)
    for clothes in assets:  # de vuelta al neutro
        clothes.data.vertices.foreach_set("co", neutral[clothes.name].ravel())
        clothes.data.update()
    basemesh.shape_key_clear()
    return shapes


def export_assets(data_folder, pack_folder, specs):
    rows = ed.read_sliders(data_folder)
    names = ed.target_names(os.path.join(data_folder, "cuerpo.glb"))
    measured, bodies = eh.measure(rows)
    skin_only, skin = eh.skin_shapes(rows, bodies)
    ed.keep_small_macro_weights()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    basemesh = gc.create_body(gc.validate_spec({"version": gc.FORMAT_VERSION}))
    rig = add_rig(basemesh)
    bake_shapes(basemesh)
    remove_masks(basemesh)
    coords = np.empty(len(basemesh.data.vertices) * 3)
    basemesh.data.vertices.foreach_get("co", coords)
    deltas = full_deltas(names, measured, skin_only, coords.reshape(-1, 3), skin)
    assets = []
    mhclos = []  # cargados aquí: MPFB solo sabe buscar solo los de ropa
    for slot, path in specs:
        clothes = HumanService.add_mhclo_asset(path, basemesh, asset_type="Clothes", subdiv_levels=0,
                                               material_type="MAKESKIN")
        clothes.name = clothes.data.name = os.path.basename(path).replace(".mhclo", "")
        assets.append(clothes)
        mhclo = Mhclo()
        mhclo.load(path)
        mhclo.clothes = clothes
        mhclos.append(mhclo)
    shapes = fit_shapes(basemesh, assets, mhclos, names, deltas)
    rename_to_humanoid(basemesh)
    os.makedirs(pack_folder, exist_ok=True)
    cards = []
    for (slot, path), clothes in zip(specs, assets):
        piece_id = clothes.name.lower()
        for modifier in [m for m in clothes.modifiers if m.type not in ("ARMATURE",)]:
            clothes.modifiers.remove(modifier)
        world = clothes.matrix_world.copy()
        clothes.parent = rig  # export_glb exporta la malla y su padre: el esqueleto, no el cuerpo
        clothes.matrix_world = world
        remove_non_bone_groups(clothes)
        print(f"GRUPOS: {clothes.name}: {len(clothes.vertex_groups)} (p. ej. {[g.name for g in clothes.vertex_groups][:3]})")
        limit_weights(clothes)
        ed.add_shape_keys(clothes, shapes[clothes.name])
        out = os.path.join(pack_folder, f"{piece_id}.glb")
        export_glb(clothes, [], out, morph=True, deform_only=True, morph_normals=False)
        ed.write_full_names(out, list(shapes[clothes.name]))
        with open(out + ".import", "w", encoding="utf-8") as file:
            file.write(eh.KEEP_IMPORT)
        kind = TYPES[slot]
        cards.append({"id": piece_id, "nombre": piece_id.replace("_", " ").capitalize(), "tipo": kind, "ranura": slot,
                      "especies": ["humana"], "archivo": f"{piece_id}.glb", "sha256": eh.sha256(out),
                      "sigue_al_cuerpo": True, "colores": ["principal"], "color": COLORS[kind]})
        print(f"PIEZA: {piece_id}: {len(clothes.data.vertices)} vertices, {len(shapes[clothes.name])} de {len(names)}"
              f" formas, {os.path.getsize(out) / 1e6:.2f} MB")
    ed.write_json(os.path.join(pack_folder, "pack.json"), dict(PACK, piezas=cards))


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    specs = [tuple(a.split(":", 1)) for a in args[2:]]
    export_assets(args[0], args[1], specs)
    print("EXPORTADO:", args[1])


if __name__ == "__main__":
    main()
