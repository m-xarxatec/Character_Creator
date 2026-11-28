# SPDX-License-Identifier: GPL-3.0-or-later
"""Exporta las mallas de ayuda de MakeHuman como piezas base que siguen al cuerpo (paso AB.3).

Uso: blender -b -P blender/exportar_helpers.py -- godot/datos/humana godot/packs/base
Lee <datos>/deslizadores.csv y <datos>/cuerpo.glb; escribe en <pack> tights.glb y hair.glb (con su .import)
y pack.json.

Cada pieza es un helper de la malla base (CC0, como el cuerpo: viene en la misma malla), con el mismo rig y pesos
(4 influencias que suman 1) y las formas de cuerpo.glb con los mismos nombres, para que ShapeWeights.apply la mueva
igual que al cuerpo:
- las de MakeHuman (targets, macros y sus correcciones) se miden como en exportar_datos.py, en los vertices del helper;
- las de cara y las propias (alisado incluido) solo existen en la piel: cada vertice del helper copia la del vertice de
  piel mas cercano.
Se quitan las formas que no mueven el helper (< MIN_DELTA). Todo en pose A, como cuerpo.glb.
Comprobado antes (2026-11-21): los targets y las macros mueven los tres helpers, y el rig Game engine da pesos a todos
sus vertices (tights 2674, skirt 720, hair 428).
"""
import hashlib
import json
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils.kdtree import KDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import exportar_datos as ed  # noqa: E402
import generar_cuerpo as gc  # noqa: E402
from exportar_glb import export_glb, humanoid_names, rename_to_humanoid  # noqa: E402
from limpiar_malla import bake_shapes, remove_masks, remove_non_bone_groups  # noqa: E402
from poner_rig import add_rig  # noqa: E402

MIN_DELTA = 1e-5  # metros (0,01 mm): una forma que mueve menos el helper no se guarda
PIECES = {  # id: (grupo de MakeHuman, nombre del objeto, ficha de pack.json)
    "tights": ("helper-tights", "Tights", {"nombre": "Malla de cuerpo completo", "tipo": "ropa", "ranura": "ropa_interior"}),
    "hair": ("helper-hair", "Hair", {"nombre": "Volumen de melena (base)", "tipo": "pelo", "ranura": "pelo"}),
}
DERIVED = [  # piezas hechas en Godot con caras del cuerpo (BodyDerived, paso AB.9a): sin archivo
    {"id": "casquete", "nombre": "Casquete", "tipo": "pelo", "ranura": "pelo", "especies": ["humana"],
     "derivada": {"mascara": "casquete", "separacion": 0.004}, "sigue_al_cuerpo": True, "colores": ["principal"]},
]
GENERATED = [  # accesorios rígidos hechos en Godot por un generador (RigidPiece, paso AB.11): sin archivo
    {"id": "cuernos", "nombre": "Cuernos", "tipo": "accesorio", "ranura": "accesorio", "especies": ["humana"],
     "generador": {"tipo": "cuernos", "simetria": True, "parametros": {"largo": 0.12, "radio": 0.016, "curva": 70,
                   "afilado": 1.2, "segmentos": 14, "lados": 10, "anillos": 4, "relieve": 0.12}},
     "anclaje": {"hueso": "Head", "transform": [0.045, 0.125, 0.04, 0, 0, -0.1736, 0.9848, 1]},
     "sigue_al_cuerpo": False, "colores": ["principal"]},
    {"id": "halo", "nombre": "Halo", "tipo": "accesorio", "ranura": "accesorio", "especies": ["humana"],
     "generador": {"tipo": "aro", "parametros": {"radio": 0.08, "grosor": 0.007}},
     "anclaje": {"hueso": "Head", "transform": [0, 0.205, -0.01, -0.1305, 0, 0, 0.9914, 1]},
     "sigue_al_cuerpo": False, "colores": ["principal"]},
]
CUTS = [  # piezas recortadas en Godot de otra (GarmentCut): sin archivo
    {"id": "melena", "nombre": "Melena con flequillo", "tipo": "pelo", "ranura": "pelo", "especies": ["humana"],
     "corte": {"de": "hair", "quitar": [[-0.07, 0.9, 0.04, 0.07, 1.585, 0.3]]},  # el flequillo, por encima de las cejas
     "sigue_al_cuerpo": True, "colores": ["principal"]},
]
COLORS = {"tights": [0.22, 0.26, 0.4], "hair": [0.24, 0.16, 0.12], "melena": [0.24, 0.16, 0.12],
          "casquete": [0.24, 0.16, 0.12], "cuernos": [0.85, 0.82, 0.72],
          "halo": [0.95, 0.82, 0.4]}  # color de partida de cada pieza (RGB de 0 a 1)
PACK = {"formato": "gamemolde-pack", "version": 1, "id": "base", "nombre": "Pack base",
        "autor": "GameMolde (de la malla base de MakeHuman)", "licencia": "CC0-1.0",
        "origen": "https://static.makehumancommunity.org/makehuman/faq/are_makehuman_files_free.html"}
KEEP_IMPORT = '[remap]\n\nimporter="keep"\n'  # como cuerpo.glb.import: el .glb viaja tal cual en el .pck


def sample_all(basemesh):
    """Como exportar_datos.sample, pero con todos los vertices (piel y helpers)."""
    key = basemesh.shape_key_add(name="_mezcla", from_mix=True)
    coords = np.empty(len(key.data) * 3)
    key.data.foreach_get("co", coords)
    basemesh.shape_key_remove(key)
    rig, names = basemesh.parent, humanoid_names()
    joints = {names[b.name]: (np.array(rig.matrix_world @ b.head_local), np.array(rig.matrix_world @ b.tail_local))
              for b in rig.data.bones}
    return coords.reshape(-1, 3), joints


def measure(rows):
    """({forma de MakeHuman: desplazamiento de todos los vertices}, cuerpos de las esquinas con todos los vertices)."""
    original = ed.sample
    ed.sample = sample_all  # measure_shapes y corner_bodies leen la muestra con este nombre
    try:
        _, shapes, bodies = ed.measure_shapes(rows)
    finally:
        ed.sample = original
    return {name: verts for name, (verts, _) in shapes.items()}, bodies


def skin_shapes(rows, bodies):
    """{forma: desplazamiento de la piel} de las formas de cara y las propias, como en exportar_datos.export_species."""
    basemesh, _ = ed.build_base()
    skin = len(basemesh.data.vertices)
    skin_bodies = {corner: (verts[:skin], joints) for corner, (verts, joints) in bodies.items()}
    shapes = ed.face_shapes(basemesh, rows)
    shapes.update(ed.own_shapes(basemesh, rows, skin_bodies))
    return {name: verts for name, (verts, _) in shapes.items()}, skin


def build_with_helpers():
    """Cuerpo neutro como ed.build_base (pose A, pies en el suelo, rig y nombres humanoides), sin borrar los helpers."""
    ed.keep_small_macro_weights()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    basemesh = gc.create_body(gc.validate_spec({"version": gc.FORMAT_VERSION}))
    add_rig(basemesh)
    bake_shapes(basemesh)
    remove_masks(basemesh)
    rename_to_humanoid(basemesh)
    return basemesh


def group_indices(basemesh, group_name):
    group = basemesh.vertex_groups[group_name].index
    return [v.index for v in basemesh.data.vertices if any(g.group == group for g in v.groups)]


def helper_object(basemesh, keep, name):
    """Copia del cuerpo con solo los vertices keep (en el mismo orden), el mismo rig y solo grupos de huesos."""
    obj = basemesh.copy()
    obj.data = basemesh.data.copy()
    bpy.context.scene.collection.objects.link(obj)
    keep_set = set(keep)
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if v.index not in keep_set], context="VERTS")
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    remove_non_bone_groups(obj)
    obj.name = obj.data.name = name
    return obj


def nearest_skin(coords, skin, keep):
    """Indice del vertice de piel mas cercano a cada vertice de keep (en reposo)."""
    tree = KDTree(skin)
    for i in range(skin):
        tree.insert(coords[i], i)
    tree.balance()
    return np.array([tree.find(coords[i])[1] for i in keep])


def piece_shapes(names, measured, skin_only, keep, nearest):
    """{forma: desplazamiento del helper} en el orden de cuerpo.glb, sin las que no lo mueven."""
    shapes = {}
    for name in names:
        if name in measured:
            verts = measured[name][keep]
        elif name in skin_only:
            verts = skin_only[name][nearest]
        else:
            raise ValueError(f"{name}: forma de cuerpo.glb que no se ha medido")
        if np.linalg.norm(verts, axis=1).max() >= MIN_DELTA:
            shapes[name] = (verts, None)
    return shapes


def sha256(path):
    with open(path, "rb") as file:
        return hashlib.sha256(file.read()).hexdigest()


def export_pieces(data_folder, pack_folder):
    rows = ed.read_sliders(data_folder)
    names = ed.target_names(os.path.join(data_folder, "cuerpo.glb"))
    measured, bodies = measure(rows)
    skin_only, skin = skin_shapes(rows, bodies)
    basemesh = build_with_helpers()
    coords = np.empty(len(basemesh.data.vertices) * 3)
    basemesh.data.vertices.foreach_get("co", coords)
    coords = coords.reshape(-1, 3)
    os.makedirs(pack_folder, exist_ok=True)
    cards = []
    for piece_id, (group_name, object_name, card) in PIECES.items():
        keep = group_indices(basemesh, group_name)
        shapes = piece_shapes(names, measured, skin_only, keep, nearest_skin(coords, skin, keep))
        obj = helper_object(basemesh, keep, object_name)
        ed.add_shape_keys(obj, shapes)
        path = os.path.join(pack_folder, f"{piece_id}.glb")
        export_glb(obj, [], path, morph=True, deform_only=True)
        ed.write_full_names(path, list(shapes))
        with open(path + ".import", "w", encoding="utf-8") as file:
            file.write(KEEP_IMPORT)
        cards.append(dict(card, id=piece_id, especies=["humana"], archivo=f"{piece_id}.glb", sha256=sha256(path),
                          miniatura="", anclaje={"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]},
                          sigue_al_cuerpo=True, fisica=[], colores=["principal"]))
        print(f"PIEZA: {piece_id}: {len(keep)} vertices, {len(shapes)} de {len(names)} formas,"
              f" {os.path.getsize(path) / 1e6:.2f} MB")
    pieces = cards + DERIVED + GENERATED + CUTS
    for card in pieces:
        card["color"] = COLORS[card["id"]]
    write_pack(os.path.join(pack_folder, "pack.json"), pieces)


def write_pack(pack_json, pieces):
    """Escribe pack.json con `pieces`, conservando el campo oculta (12.1b, lo pone ocultar_piel.py) de las fichas que
    ya lo tenían. Si la malla cambia en neutro, hay que repetir ocultar_piel.py (el sha256 de la máscara no lo nota)."""
    old = {}
    if os.path.exists(pack_json):
        with open(pack_json, encoding="utf-8") as file:
            old = {card["id"]: card for card in json.load(file).get("piezas", [])}
    for card in pieces:
        if "oculta" in old.get(card["id"], {}):
            card["oculta"] = old[card["id"]]["oculta"]
    ed.write_json(pack_json, dict(PACK, piezas=pieces))


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    export_pieces(args[0], args[1])
    print("EXPORTADO:", args[1])


if __name__ == "__main__":
    main()
