# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso 12.1b-b1: diagnóstico de la ropa de MakeHuman en neutro (solo mide; no escribe nada).

Uso: (ulimit -v 4000000; timeout 600 blender -b -P pruebas/fase_12/medir_traje.py 2>&1 | grep -E 'MEDIDA|FALLO|RESULTADO')
Encaja las prendas sobre el cuerpo neutro como exportar_mhclo.export_assets y mide, por prenda: 2) si el .glb del pack
es el ajuste; 3) vértices de tela bajo la piel; 4) piel tapada que asoma entre vértices (rayos de 12.1a: BELOW 0,04 y
ABOVE 0,09), con su distancia a la piel sin tapar; 5) cuánto de eso está en delete_verts; 6) referencias a helpers.
Todo en coordenadas de Blender (Z arriba), pose A.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import exportar_datos as ed  # noqa: E402
import exportar_mhclo as em  # noqa: E402
import exportar_overscore as eo  # noqa: E402
import exportar_quaternius as eq  # noqa: E402
import generar_cuerpo as gc  # noqa: E402
import generar_zonas_piel as gz  # noqa: E402
from exportar_glb import rename_to_humanoid  # noqa: E402
from limpiar_malla import SKIN_GROUP, bake_shapes, remove_masks  # noqa: E402
from poner_rig import add_rig  # noqa: E402

MPFB = os.path.expanduser("~/.config/blender/5.2/extensions/.user/blender_org/mpfb/data/clothes")
GARMENTS = {
    "female_casualsuit01": os.path.join(MPFB, "female_casualsuit01", "female_casualsuit01.mhclo"),
    "elvs_crude_t-shirt_male": os.path.join(ROOT, "recursos_externos/MH01_shirts01/clothes/elvs_crude_t-shirt_male/elvs_crude_t-shirt_male.mhclo"),
    "cortu_jeans_shorts": os.path.join(ROOT, "recursos_externos/MH01_pants01/clothes/cortu_jeans_shorts/cortu_jeans_shorts.mhclo"),
}
PACK = os.path.join(ROOT, "godot", "packs", "makehuman")
BODY_GLB = os.path.join(ROOT, "godot", "datos", "humana", "cuerpo.glb")
eo.BELOW, eo.ABOVE = 0.04, 0.09  # los de probar_ropa_extremos.gd (12.1a), para comparar con su 23,9 %
HEM, HIDE_HEM = 0.025, 0.04  # metros: los de la ficha 12.1b
HAND_PARTS = ("Hand", "Thumb", "Index", "Middle", "Ring", "Little")


def read_mhclo(path):
    """(índices de la malla base que usa cada vértice de tela, delete_verts)."""
    refs, deleted, section = [], set(), None
    for line in open(path, encoding="utf-8"):
        words = line.split()
        if not words or words[0].startswith("#"):
            continue
        if words[0] in ("verts", "delete_verts") or words[0][0].isalpha():
            section = words[0]
            continue
        if section == "verts":
            refs += [int(w) for w in words[:3 if len(words) >= 9 else 1]]
        elif section == "delete_verts":
            for k, w in enumerate(words):
                if w == "-":
                    deleted.update(range(int(words[k - 1]), int(words[k + 1]) + 1))
                elif w.isdigit():
                    deleted.add(int(w))
    return np.array(refs), deleted


def world(obj, coords):
    m = np.array(obj.matrix_world)
    return coords @ m[:3, :3].T + m[:3, 3]


def glb_positions(path):
    mesh, _ = gz.read_glb(path)
    p = mesh["POSITION"]
    moved = [n.get("name") for n in ed._glb_parts(path)[0]["nodes"]
             if "mesh" in n and any(k in n for k in ("matrix", "translation", "rotation", "scale"))]
    return np.stack([p[:, 0], -p[:, 2], p[:, 1]], 1), moved  # glTF (Y arriba) → Blender (Z arriba)


def nearest_dist(points, targets):
    tree = KDTree(len(targets))
    for i, t in enumerate(targets.tolist()):
        tree.insert(t, i)
    tree.balance()
    return np.array([tree.find(p)[2] for p in points.tolist()])


def pct(part, whole):
    return 100.0 * part / max(whole, 1)


def top(bones, mask):
    names, counts = np.unique(bones[mask], return_counts=True)
    return ", ".join(f"{n} {c}" for n, c in sorted(zip(names, counts), key=lambda x: -x[1])[:4]) or "-"


def skin_data(basemesh):
    group = basemesh.vertex_groups[SKIN_GROUP].index
    bone_names = {g.index: g.name for g in basemesh.vertex_groups if g.name in basemesh.parent.data.bones}
    skin_ids, bones, hand = [], [], []
    for v in basemesh.data.vertices:
        if any(g.group == group for g in v.groups):
            weights = [(g.weight, bone_names[g.group]) for g in v.groups if g.group in bone_names]
            skin_ids.append(v.index)
            bones.append(max(weights)[1] if weights else "-")
            hand.append(sum(w for w, n in weights if any(p in n for p in HAND_PARTS)))
    skin_ids = np.array(skin_ids)
    all_coords = world(basemesh, em.clothes_coords(basemesh))
    remap = np.full(len(all_coords), -1)
    remap[skin_ids] = np.arange(len(skin_ids))
    _, tris = eo.mesh_arrays(basemesh.data)
    tris = remap[tris[(remap[tris] >= 0).all(1)]]
    skin = all_coords[skin_ids]
    return skin_ids, skin, tris, eo.vertex_normals(skin, tris), np.array(bones), np.array(hand) < 0.5


def measure(name, clothes, mhclo_path, sk):
    skin_ids, skin, skin_tris, normals, bones, free = sk
    cloth = world(clothes, em.clothes_coords(clothes))
    _, cloth_tris = eo.mesh_arrays(clothes.data)
    # 2) ¿el .glb es el ajuste?
    glb, moved = glb_positions(os.path.join(PACK, name + ".glb"))
    same = len(glb) == len(cloth)
    diff = np.linalg.norm(glb - cloth, axis=1).max() if same else nearest_dist(glb, cloth).max()
    print(f"MEDIDA {name} glb: {len(glb)} vértices (ajuste {len(cloth)}), diferencia máx {diff * 1000:.3f} mm"
          f" ({'en orden' if same else 'por el más cercano'}); nodos con transformación: {moved or 'ninguno'}")
    # 3) vértices de tela bajo la piel
    skin_tree = eq.tree_of(skin, skin_tris)
    signed, near_bone = np.empty(len(cloth)), np.empty(len(cloth), object)
    for i, p in enumerate(cloth.tolist()):
        loc, _, face, _ = skin_tree.find_nearest(Vector(p))
        n = normals[skin_tris[face]].mean(0)
        signed[i] = (np.array(p) - np.array(loc)) @ n / max(np.linalg.norm(n), 1e-12)
        near_bone[i] = bones[skin_tris[face][0]]
    inside = signed < 0
    print(f"MEDIDA {name} tela dentro: {inside.sum()} de {len(cloth)} ({pct(inside.sum(), len(cloth)):.1f} %),"
          f" mínimo {signed.min() * 1000:.1f} mm; por hueso: {top(near_bone, inside)}")
    # 4) piel que asoma entre vértices
    refs, deleted = read_mhclo(mhclo_path)
    in_del = np.isin(skin_ids, sorted(deleted))
    low, high = cloth.min(0) - eo.BELOW - 0.01, cloth.max(0) + eo.BELOW + 0.01
    near = free & (skin >= low).all(1) & (skin <= high).all(1)
    which = np.nonzero(near | in_del)[0]
    heights = np.full(len(skin), np.nan)
    heights[which] = eo.ray_heights(eq.tree_of(cloth, cloth_tris), skin, normals, which)[0]
    covered = np.isfinite(heights) & near
    bare = near & ~np.isfinite(heights)
    edge = nearest_dist(skin, skin[bare]) if bare.any() else np.full(len(skin), np.inf)
    out = covered & (heights < 0)
    depth = -heights[out] * 1000
    p = np.percentile(depth, [50, 95, 100]) if len(depth) else [0, 0, 0]
    inner = covered & (edge > HEM)
    print(f"MEDIDA {name} piel asoma: {out.sum()} de {covered.sum()} tapada ({pct(out.sum(), covered.sum()):.1f} %);"
          f" sin la franja de {HEM * 1000:.0f} mm: {(out & inner).sum()} de {inner.sum()} ({pct((out & inner).sum(), inner.sum()):.1f} %);"
          f" profundidad p50/p95/máx {p[0]:.1f}/{p[1]:.1f}/{p[2]:.1f} mm; por hueso: {top(bones, out)}")
    print(f"MEDIDA {name} asoma por distancia al borde: < {HEM * 1000:.0f} mm {(out & (edge <= HEM)).sum()},"
          f" {HEM * 1000:.0f}-{HIDE_HEM * 1000:.0f} mm {(out & (edge > HEM) & (edge <= HIDE_HEM)).sum()},"
          f" > {HIDE_HEM * 1000:.0f} mm {(out & (edge > HIDE_HEM)).sum()};"
          f" máx a ≤ {HIDE_HEM * 1000:.0f} mm {max([0.0] + list(-heights[out & (edge <= HIDE_HEM)] * 1000)):.1f} mm")
    # 5) delete_verts
    skin_del = in_del.sum()
    no_cloth = in_del & ~np.isfinite(heights)
    print(f"MEDIDA {name} delete_verts: {len(deleted)} índices ({skin_del} de piel); asoma en la lista:"
          f" {(out & in_del).sum()} de {out.sum()} ({pct((out & in_del).sum(), out.sum()):.1f} %);"
          f" lista sin tela encima: {no_cloth.sum()} ({pct(no_cloth.sum(), skin_del):.1f} %), por hueso: {top(bones, no_cloth)}")
    # 6) referencias a helpers
    helpers = ~np.isin(refs, skin_ids)
    print(f"MEDIDA {name} referencias a helpers: {helpers.sum()} de {len(refs)} ({pct(helpers.sum(), len(refs)):.1f} %)")


def main():
    ed.keep_small_macro_weights()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    basemesh = gc.create_body(gc.validate_spec({"version": gc.FORMAT_VERSION}))
    add_rig(basemesh)
    bake_shapes(basemesh)
    remove_masks(basemesh)
    assets = []
    for name, path in GARMENTS.items():
        clothes = em.HumanService.add_mhclo_asset(path, basemesh, asset_type="Clothes", subdiv_levels=0,
                                                  material_type="MAKESKIN")
        mhclo = em.Mhclo()
        mhclo.load(path)
        mhclo.clothes = clothes
        em.ClothesService.fit_clothes_to_human(clothes, basemesh, mhclo)  # como el neutro de fit_shapes
        assets.append((name, clothes, path))
    rename_to_humanoid(basemesh)
    sk = skin_data(basemesh)
    body, _ = glb_positions(BODY_GLB)
    print(f"MEDIDA cuerpo.glb: {len(body)} vértices, piel {len(sk[0])} (índices {sk[0].min()}-{sk[0].max()}),"
          f" diferencia máx con el neutro {nearest_dist(body, sk[1]).max() * 1000:.3f} mm")
    for name, clothes, path in assets:
        measure(name, clothes, path, sk)
    print("RESULTADO: TODO BIEN (solo mide)")


if __name__ == "__main__":
    main()
