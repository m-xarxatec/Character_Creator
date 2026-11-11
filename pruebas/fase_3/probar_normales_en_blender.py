# SPDX-License-Identifier: GPL-3.0-or-later
"""Maqueta 3.13a-2: ¿las normales de elipsoide del .glb llegan a Blender?

Compara las normales que Blender usa (por esquina) con las enviadas (cara_normales.json), emparejando por posición.
Uso: (ulimit -v 4000000; timeout 300 blender -b -P pruebas/fase_3/probar_normales_en_blender.py 2>&1 | grep -E 'FALLO|RESULTADO|bien')
Antes: pruebas/godot/probar_normales_cara.gd (escribe pruebas/fase_3/salida/normales/).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "salida", "normales")
LIMIT_DEG = 1.0  # límite inicial de la maqueta
GRID = 10000.0  # empareja posiciones a 0,1 mm
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def to_blender(x, y, z):
    """glTF (Y arriba) a Blender (Z arriba)."""
    return Vector((x, -z, y))


def key(position):
    return tuple(round(c * GRID) for c in position)


def near(by_position, k):
    """Los enviados en esa casilla o, si cae justo en el borde, en las vecinas."""
    found = by_position.get(k)
    if found:
        return found
    return [c for dx in (-1, 0, 1) for dy in (-1, 0, 1) for dz in (-1, 0, 1)
            for c in by_position.get((k[0] + dx, k[1] + dy, k[2] + dz), [])]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(FOLDER, "cara.glb"))
    with open(os.path.join(FOLDER, "cara_normales.json"), encoding="utf-8") as file:
        sent = json.load(file)
    by_position = {}
    p, n, w = sent["positions"], sent["normals"], sent["head_weight"]
    for i in range(len(w)):
        position = to_blender(*p[3 * i:3 * i + 3])
        by_position.setdefault(key(position), []).append((to_blender(*n[3 * i:3 * i + 3]), w[i]))

    body = next(o for o in bpy.data.objects if o.type == "MESH" and len(o.data.vertices) > 1000)
    mesh = body.data
    check("la malla trae normales propias", mesh.has_custom_normals)
    world = body.matrix_world
    rotation = world.to_3x3().normalized()
    missing, worst, total, count, head_worst = 0, 0.0, 0.0, 0, 0.0
    for loop, corner in zip(mesh.loops, mesh.corner_normals):
        candidates = near(by_position, key(world @ mesh.vertices[loop.vertex_index].co))
        if not candidates:
            missing += 1
            continue
        normal = rotation @ Vector(corner.vector)
        angle, weight = min((math.degrees(normal.angle(c[0])), c[1]) for c in candidates)
        worst = max(worst, angle)
        total += angle
        count += 1
        if weight > 0.5:
            head_worst = max(head_worst, angle)
    check("todas las esquinas tienen pareja", missing == 0, "%d de %d sin pareja" % (missing, len(mesh.loops)))
    check("normales iguales a las enviadas", worst <= LIMIT_DEG,
          "máx. %.4f° / media %.4f° (cabeza: máx. %.4f°; límite %.1f°)" % (worst, total / max(count, 1), head_worst, LIMIT_DEG))
    print("RESULTADO:", "TODO BIEN" if not failures else "%d FALLOS" % len(failures))


main()
sys.exit(1 if failures else 0)
