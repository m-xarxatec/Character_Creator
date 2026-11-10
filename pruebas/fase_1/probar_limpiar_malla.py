# SPDX-License-Identifier: GPL-3.0-or-later
"""Pruebas del paso 1.3. Uso: blender -b -P pruebas/fase_1/probar_limpiar_malla.py"""
import os
import sys

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import generar_cuerpo as gc  # noqa: E402
from limpiar_malla import clean_mesh  # noqa: E402
from poner_rig import add_rig, bone_weights  # noqa: E402
from prenda_base import paint_base_garment  # noqa: E402

BODIES = ("neutro", "mujer_baja", "hombre_alto_fuerte", "robusto_mayor", "delgada_estilizada")
SKIN_VERTICES = 13380
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def skin_snapshot(mesh):
    """Posicion final y valor de prenda de cada vertice de piel, en orden."""
    body = mesh.vertex_groups["body"].index
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    garment = mesh.data.color_attributes["garment"].data
    skin = [v.index for v in mesh.data.vertices if any(g.group == body for g in v.groups)]
    # La mascara quita la malla auxiliar, asi que la malla evaluada ya solo trae piel, en el mismo orden.
    positions = [tuple(v.co) for v in evaluated.data.vertices]
    return positions, [garment[i].color[0] for i in skin]


for body in BODIES:
    print(body)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mesh = gc.create_body(gc.load_spec(os.path.join(ROOT, "pruebas", "fase_1", "cuerpos", body + ".json")))
    add_rig(mesh)
    paint_base_garment(mesh)
    before_positions, before_garment = skin_snapshot(mesh)
    before_size = gc.measure(mesh)

    remaining = clean_mesh(mesh)
    data = mesh.data

    check("quedan solo los vertices de piel", remaining == SKIN_VERTICES, str(remaining))
    check("no quedan shape keys", data.shape_keys is None)
    check("solo queda el modificador de esqueleto", [m.type for m in mesh.modifiers] == ["ARMATURE"], str([m.type for m in mesh.modifiers]))
    check("los grupos de vertices son solo huesos", all(g.name in mesh.parent.data.bones for g in mesh.vertex_groups), str(len(mesh.vertex_groups)))
    used = {i for polygon in data.polygons for i in polygon.vertices}
    check("no hay vertices sueltos", len(used) == remaining, str(remaining - len(used)))

    moved = max(max(abs(a - b) for a, b in zip(v.co, old)) for v, old in zip(data.vertices, before_positions))
    check("el cuerpo no cambia de forma al hornear", moved < 1e-5, f"mayor movimiento {moved:.7f} m")
    check("las medidas no cambian", gc.measure(mesh) == before_size)
    garment = [c.color[0] for c in data.color_attributes["garment"].data]
    check("la prenda sigue en su sitio", garment == before_garment)
    counts = [len(bone_weights(mesh, v)) for v in data.vertices]
    worst = max(abs(sum(bone_weights(mesh, v).values()) - 1.0) for v in data.vertices)
    check("los pesos siguen bien (1 a 4 huesos, suman 1)", min(counts) >= 1 and max(counts) <= 4 and worst < 1e-4, f"min {min(counts)}, max {max(counts)}, desvio {worst:.6f}")

print("RESULTADO:", "TODO BIEN" if not failures else f"{len(failures)} FALLOS: {failures}")
sys.exit(1 if failures else 0)
