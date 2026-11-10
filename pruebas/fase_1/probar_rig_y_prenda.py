# SPDX-License-Identifier: GPL-3.0-or-later
"""Pruebas del paso 1.2. Uso: blender -b -P pruebas/fase_1/probar_rig_y_prenda.py"""
import os
import sys

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import generar_cuerpo as gc  # noqa: E402
from poner_rig import bone_weights  # noqa: E402

BODIES = ("neutro", "mujer_baja", "hombre_alto_fuerte", "robusto_mayor", "delgada_estilizada")
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def skin_vertices(mesh):
    body = mesh.vertex_groups["body"].index
    return [v for v in mesh.data.vertices if any(g.group == body for g in v.groups)]


def garment_values(mesh):
    return [round(c.color[0], 4) for c in mesh.data.color_attributes["garment"].data]


reference = None
for body in BODIES:
    print(body)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mesh = gc.build_character(gc.load_spec(os.path.join(ROOT, "pruebas", "fase_1", "cuerpos", body + ".json")))
    rig = mesh.parent
    height = gc.measure(mesh)["height"]
    skin = skin_vertices(mesh)

    check("53 huesos", len(rig.data.bones) == 53, str(len(rig.data.bones)))
    head_top = (rig.matrix_world @ rig.data.bones["head"].tail_local).z
    check("la cabeza del rig queda dentro del cuerpo", 0.85 * height < head_top <= height * 1.01, f"{head_top:.3f} de {height:.3f}")
    foot = (rig.matrix_world @ rig.data.bones["ball_l"].head_local).z
    check("el pie del rig queda junto al suelo", 0 <= foot < 0.06, f"{foot:.3f}")

    counts = [len(bone_weights(mesh, v)) for v in skin]
    check("cada vertice de piel tiene de 1 a 4 huesos", min(counts) >= 1 and max(counts) <= 4, f"min {min(counts)}, max {max(counts)}")
    worst = max(abs(sum(bone_weights(mesh, v).values()) - 1.0) for v in skin)
    check("los pesos suman 1", worst < 1e-4, f"peor desvio {worst:.6f}")

    values = garment_values(mesh)
    painted = [v for v in skin if values[v.index] >= 0.5]
    check("hay prenda pintada, y no cubre todo", 0.04 < len(painted) / len(skin) < 0.3, f"{len(painted)} de {len(skin)}")
    limbs = ("head", "neck_01", "hand_l", "hand_r", "lowerarm_l", "lowerarm_r", "calf_l", "calf_r", "foot_l", "foot_r")
    stray = [v.index for v in painted if max(bone_weights(mesh, v).items(), key=lambda kv: kv[1])[0] in limbs]
    check("nada pintado en cabeza, antebrazos, manos, pantorrillas ni pies", not stray, str(len(stray)))
    left = sum(1 for v in painted if v.co.x > 0.001)
    right = sum(1 for v in painted if v.co.x < -0.001)
    check("la prenda es simetrica", abs(left - right) <= 2, f"{left} / {right}")
    if reference is None:
        reference = values
    drift = max(abs(a - b) for a, b in zip(values, reference))
    check("la prenda es igual a la del cuerpo neutro", drift < 0.01, f"mayor diferencia {drift:.5f}")

print("RESULTADO:", "TODO BIEN" if not failures else f"{len(failures)} FALLOS: {failures}")
sys.exit(1 if failures else 0)
