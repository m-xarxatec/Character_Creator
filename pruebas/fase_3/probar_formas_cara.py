# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso 3.14: las formas de cara de datos/humana/cuerpo.glb son las de la maqueta (cara_anime.json).

Compara cada forma y su suma (todas a 1): maximo y media en mm, en los vertices que mueve alguna de las dos.
Ademas mide la suma contra la cara aprobada en la 3.13a-4 (sin limite, como probar_cara_anime.py).
Antes: (ulimit -v 4000000; timeout 300 blender -b -P blender/cara_anime.py -- pruebas/fase_3/salida/cara_anime/cara_anime.json)
Uso: (ulimit -v 4000000; timeout 600 blender -b -P pruebas/fase_3/probar_formas_cara.py 2>&1 | grep -E 'FALLO|medida|RESULTADO')
"""
import json
import os
import sys

import bpy
import numpy as np
from mathutils import kdtree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import cara_anime as ca  # noqa: E402
import exportar_datos as ed  # noqa: E402

DATA = os.path.join(ROOT, "datos", "humana")
MAQUETA = os.path.join(ROOT, "pruebas", "fase_3", "salida", "cara_anime", "cara_anime.json")
MAX_MM = 0.01  # la maqueta guarda micras (1 µm por eje) y el .glb, 32 bits
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def to_godot(points):
    return np.column_stack((points[:, 0], points[:, 2], -points[:, 1]))


def maqueta_shapes(count):
    with open(MAQUETA, encoding="utf-8") as file:
        data = json.load(file)
    shapes = {}
    for name, rows in data["shapes"].items():
        delta = np.zeros((count, 3))
        for row in rows:
            delta[int(row[0])] = row[4:7]
        shapes[name] = delta
    return data["vertex_count"], shapes


def glb_shapes(path, names, base):
    """{forma: desplazamiento por vertice de la malla base (ejes de Godot)} y los vertices sin pareja."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    mesh = next(o for o in bpy.data.objects if o.type == "MESH")
    world = np.array(mesh.matrix_world)
    keys = mesh.data.shape_keys.key_blocks

    def coords(block):
        flat = np.empty(len(block.data) * 3)
        block.data.foreach_get("co", flat)
        return to_godot(flat.reshape(-1, 3) @ world[:3, :3].T + world[:3, 3])

    tree = kdtree.KDTree(len(base))
    for i, p in enumerate(base):
        tree.insert(p, i)
    tree.balance()
    rest = coords(keys[0])
    found = [tree.find(p) for p in rest]
    index = np.array([i for _, i, _ in found])
    unmatched = sum(d > 1e-5 for _, _, d in found)
    shapes = {}
    for name in names:
        delta = np.zeros((len(base), 3))
        delta[index] = coords(keys[name]) - rest
        shapes[name] = delta
    return shapes, unmatched


def gap(a, b):
    moved = (np.abs(a).max(axis=1) > ca.MIN_DELTA) | (np.abs(b).max(axis=1) > ca.MIN_DELTA)
    mm = 1000 * np.linalg.norm(a - b, axis=1)[moved]
    return mm.max(), mm.mean(), moved.sum()


def main():
    rows = ed.read_sliders(DATA)
    face = [r["id"] for r in ed.face_rows(rows)]
    points, edges, zones = ca.neutral_head()
    approved = sum(ca.deform(points, edges, zones, ca.APPROVED).values())
    count, maqueta = maqueta_shapes(len(points))
    check("la maqueta es de esta malla", count == len(points) and sorted(maqueta) == sorted(face), sorted(maqueta))
    data, unmatched = glb_shapes(os.path.join(DATA, "cuerpo.glb"), face, to_godot(points))
    check("cada vértice del .glb tiene su vértice de la malla base", unmatched == 0, f"{unmatched} sin pareja")
    for name in face:
        worst, mean, moved = gap(data[name], maqueta[name])
        print(f"medida {name}: máx. {worst:.4f} mm / media {mean:.4f} mm en {moved} vértices")
        check(f"{name} = maqueta (< {MAX_MM} mm)", worst < MAX_MM)
    total = sum(data.values())
    worst, mean, moved = gap(total, sum(maqueta.values()))
    print(f"medida suma de las 5 formas contra la maqueta: máx. {worst:.4f} mm / media {mean:.4f} mm en {moved} vértices")
    check(f"la suma de las formas da la cara de la maqueta (< {MAX_MM} mm)", worst < MAX_MM)
    worst, mean, moved = gap(total, to_godot(approved))
    print(f"medida suma contra la cara aprobada (3.13a-4, sin límite): máx. {worst:.2f} mm / media {mean:.3f} mm")
    with open(os.path.join(DATA, "articulaciones.json"), encoding="utf-8") as file:
        bones = json.load(file)["bones"]
    check("las formas de cara no mueven huesos", not any(set(face) & set(b["deltas"]) for b in bones.values()))
    print(f"RESULTADO: {len(failures)} fallos" + (f" ({', '.join(failures)})" if failures else ""))
    sys.exit(1 if failures else 0)


main()
