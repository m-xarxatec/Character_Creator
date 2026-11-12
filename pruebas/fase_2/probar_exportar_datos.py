# SPDX-License-Identifier: GPL-3.0-or-later
"""Pruebas del paso 2.3: los datos generados cumplen datos/FORMATO.md y reproducen a MPFB.

Uso: blender -b -P pruebas/fase_2/probar_exportar_datos.py
Genera los datos dos veces en pruebas/fase_2/salida/ (a y b) y compara con cuerpos creados por MPFB.
"""
import itertools
import json
import os
import shutil
import sys

import bpy
import numpy as np
from mathutils import Vector, kdtree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import exportar_datos as ed  # noqa: E402
from exportar_glb import humanoid_names  # noqa: E402
import poner_rig  # noqa: E402

OUT = os.path.join(ROOT, "pruebas", "fase_2", "salida")
SLIDERS = os.path.join(ROOT, "datos", "humana", "deslizadores.csv")
SOCKET_PARENTS = {"socket_hand_r": "RightHand", "socket_hand_l": "LeftHand",
                  "socket_back": "UpperChest", "socket_hip": "Hips"}
EXACT_MM = 0.1  # mezclar formas sueltas o una macro sola debe dar lo mismo que MPFB
COMBINED_MM = 1.0  # macros combinadas, con sus correcciones
RANDOM_BODIES = 243
BONE_MM, BONE_DEG = 1.0, 1.0
REFERENCE = Vector((0.0, 1.0, 0.0))  # +Y de Blender = -Z de Godot
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def generate(name):
    folder = os.path.join(OUT, name)
    shutil.rmtree(folder, ignore_errors=True)
    os.makedirs(folder)
    shutil.copy(SLIDERS, folder)
    shutil.copytree(os.path.join(os.path.dirname(SLIDERS), "presets"), os.path.join(folder, "presets"))
    return folder, ed.export_species(folder)


def weights_for(macros, shape_weights, names):
    """Pesos de todas las formas: los dados, los de cada macro y, en las correcciones, el producto de sus partes."""
    return ed.shape_weights({(i, None): v for i, v in macros.items()}, names, ed.neutral_values(rows), shape_weights)


def mpfb(macros=None, targets=None):
    """(vertices de piel, cabeza/cola y matriz de cada hueso) de un cuerpo de MPFB, en ejes de Blender."""
    full = ed.neutral_macros()
    full.update(macros or {})
    body = ed.raw_body(full, targets or {})
    names = humanoid_names()
    matrices = {names[b.name]: b.matrix_local.to_3x3() for b in body.parent.data.bones}
    verts, joints = ed.sample(body)
    return verts, joints, matrices


def read_glb(path):
    """Importa el .glb y devuelve (malla, rig, base, {forma: vertices})."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    mesh = next(o for o in bpy.data.objects if o.type == "MESH")
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    to_world = np.array(mesh.matrix_world)

    def coords(block):
        flat = np.empty(len(block.data) * 3)
        block.data.foreach_get("co", flat)
        local = flat.reshape(-1, 3)
        return local @ to_world[:3, :3].T + to_world[:3, 3]

    keys = mesh.data.shape_keys.key_blocks
    return mesh, rig, coords(keys[0]), {k.name: coords(k) for k in keys[1:]}


def deltas_by_skin_index(base, shapes, reference):
    """Pasa los desplazamientos del .glb (con vertices duplicados en las costuras) a los 13380 de la piel."""
    tree = kdtree.KDTree(len(reference))
    for i, p in enumerate(reference):
        tree.insert(p, i)
    tree.balance()
    found = [tree.find(p) for p in base]
    index = np.array([f[1] for f in found])
    deltas = {}
    for name, verts in shapes.items():
        d = np.zeros_like(reference)
        d[index] = verts - base
        deltas[name] = d
    return max(f[2] for f in found), deltas


def error_mm(predicted, actual):
    return float(np.linalg.norm(predicted - actual, axis=1).max() * 1000)


def to_blender(v):
    return Vector((v[0], -v[2], v[1]))


def predict_bone(bone, weights):
    head, tail = np.array(bone["head"]), np.array(bone["tail"])
    for shape, w in weights.items():
        if shape in bone["deltas"]:
            head = head + w * np.array(bone["deltas"][shape]["head"])
            tail = tail + w * np.array(bone["deltas"][shape]["tail"])
    return to_blender(head), to_blender(tail)


# --- Generar dos veces: mismo resultado ---
folder, manifest = generate("a")
_, manifest_b = generate("b")
check("generar dos veces da los mismos sha256", manifest["files"] == manifest_b["files"])
with open(os.path.join(folder, "articulaciones.json"), encoding="utf-8") as file:
    joints = json.load(file)["bones"]

# --- Manifiesto ---
check("manifiesto: versión 2, humana, pose A",
      (manifest["version"], manifest["species"], manifest["pose"]) == (2, "humana", "A"))
check("manifiesto: 13380 vértices", manifest["vertex_count"] == 13380, manifest["vertex_count"])
check("manifiesto: 53 huesos de deformación y 4 de anclaje",
      len(manifest["bones"]["deform"]) == 53 and sorted(manifest["bones"]["sockets"]) == sorted(SOCKET_PARENTS))
check(f"manifiesto: sha256 de los {len(ed.FILES)} archivos",
      all(manifest["files"][f]["sha256"] == ed.sha256(os.path.join(folder, f)) for f in ed.FILES))

# --- articulaciones.json ---
check("articulaciones: 57 huesos con cabeza, cola y padre",
      len(joints) == 57 and all({"head", "tail", "parent", "deltas"} <= set(b) for b in joints.values()))
check("anclajes cuelgan de su hueso", all(joints[s]["parent"] == p for s, p in SOCKET_PARENTS.items()))
hip, hips = joints["socket_hip"]["head"], joints["Hips"]["head"]
check("anclaje de cadera en la cadera (no en la mano)", 0.05 < hip[0] < 0.25 and abs(hip[1] - hips[1]) < 0.05, hip)

# --- cuerpo.glb ---
rows = ed.read_sliders(folder)
expected = [name for name, _, _ in ed.shape_specs(rows)]
mesh, rig, base, shapes = read_glb(os.path.join(folder, "cuerpo.glb"))
fixes = [n for n in shapes if "*" in n]
face = [r["id"] for r in ed.face_rows(rows)]
check("glb: las 78 formas de la tabla", len(expected) == 78 and sorted(set(shapes) - set(fixes) - set(face)) == sorted(expected))
check("glb: las 5 formas de cara (paso 3.14)", len(face) == 5 and set(face) <= set(shapes), face)
check("glb: correcciones hechas de formas de macro", fixes and all(
    p in expected and p.startswith(tuple(i for i, _ in ed.macro_sliders(rows))) for n in fixes for p in n.split("*")),
    f"{len(fixes)} correcciones, {len(shapes)} formas en total")
check("glb: nombres _decr / _incr (y _l / _r)",
      all(p.rsplit("_", 2)[-1] in ("decr", "incr", "l", "r") for n in set(shapes) - set(face) for p in n.split("*")))
colors = mesh.data.color_attributes
values = np.empty(len(colors[0].data) * 4) if colors else np.zeros(1)
if colors:
    colors[0].data.foreach_get("color", values)
check("glb: color de prenda (hay piel y prenda)", bool(colors) and values[0::4].min() < 0.1 < 0.9 < values[0::4].max())
check("glb: 57 huesos", len(rig.data.bones) == 57, len(rig.data.bones))
socket_groups = {g.index for g in mesh.vertex_groups if g.name.startswith("socket_")}
check("glb: anclajes sin peso", len(socket_groups) == 4 and not any(
    g.group in socket_groups and g.weight > 0 for v in mesh.data.vertices for g in v.groups))

# --- Pesos cruzados entre lados (paso 2.5) ---
groups = {g.index: g.name for g in mesh.vertex_groups}
glb_cross = sum(1 for v in mesh.data.vertices if abs(v.co.x) > poner_rig.CROSS_MIN_X and any(
    g.weight > 0 and groups[g.group].startswith("Right" if v.co.x > 0 else "Left") for g in v.groups))
check("glb: 0 vértices con peso del otro lado a más de 5 cm", glb_cross == 0, glb_cross)


def cross_report():
    """{vertice: peso cruzado} antes (MPFB sin limpiar) y despues (con poner_rig.add_rig)."""
    found = []
    for clean in (False, True):
        ed.keep_small_macro_weights()
        bpy.ops.wm.read_factory_settings(use_empty=True)
        body = ed.HumanService.create_human(macro_detail_dict=ed.neutral_macros(), feet_on_ground=False)
        if clean:
            ed.add_rig(body)
        else:
            ed.HumanService.add_builtin_rig(body, poner_rig.RIG_NAME, import_weights=True)
            poner_rig.limit_weights(body)
        skin = ed._skin_count(body)
        found.append({v.index: sum(poner_rig.cross_weights(body, v).values()) for v in body.data.vertices[:skin]})
    return found


before, after = cross_report()
listed = sorted(i for i, w in before.items() if w > 0)
for i in listed:
    print(f"  vértice {i}: peso cruzado {before[i]:.4f} -> {after[i]:.4f}")
check("pesos cruzados a más de 5 cm del centro: 0 tras limpiar", listed and not any(after.values()),
      f"{len(listed)} vértices los tenían")

# --- Malla: comparar con MPFB ---
neutral, neutral_joints, neutral_matrices = mpfb()
offset = np.array([0.0, 0.0, -neutral[:, 2].min()])  # el .glb tiene los pies en el suelo
distance, deltas = deltas_by_skin_index(base, shapes, neutral + offset)
check("glb: la malla base es la neutra de MPFB", distance * 1000 < 0.01, f"{distance * 1000:.4f} mm")


MACRO_KEYS = dict(ed.macro_sliders(rows))  # id del deslizador -> macro de MakeHuman


def body_error(macros, shape_weights=None, targets=None):
    """Error máximo en mm entre las formas del .glb y MPFB. macros: {id del deslizador: valor de 0 a 1}."""
    actual = mpfb({MACRO_KEYS[i]: v for i, v in macros.items()}, targets)[0] - neutral
    weights = weights_for(macros, shape_weights or {}, shapes)
    return error_mm(sum(w * deltas[s] for s, w in weights.items() if w), actual)


def compare(label, limit, **body):
    mm = body_error(**body)
    check(f"{label} (< {limit} mm)", mm < limit, f"error máximo {mm:.3f} mm")


GAPS = ed.gc.mpfb_gaps()


def statistics(label, bodies):
    """Máximo y media del error. Los cuerpos en un hueco de MPFB no se comparan (MPFB falla ahí: hueco_mpfb/)."""
    usable = [b for b in bodies if not any(ed.gc.in_mpfb_gap(MACRO_KEYS[i], v, GAPS) for i, v in b.items())]
    errors = [body_error(b) for b in usable]
    check(f"{label}: {len(errors)} cuerpos (< {COMBINED_MM} mm)", max(errors) < COMBINED_MM,
          f"error máximo {max(errors):.3f} mm, media {np.mean(errors):.3f} mm,"
          f" {len(bodies) - len(usable)} saltados por caer en un hueco de MPFB")


compare("dos targets: cuello 60 % + dedos izq. 30 %", EXACT_MM,
        macros={}, shape_weights={"neck_length_incr": 0.6, "finger_length_incr_l": 0.3},
        targets={"measure-neck-height-incr": 0.6, "l-hand-fingers-length-incr": 0.3})
compare("una macro sola: músculo 80 %", EXACT_MM, macros={"muscle": 0.8})
compare("macros combinadas (a): músculo 100 % + peso 100 %", COMBINED_MM, macros={"muscle": 1.0, "weight": 1.0})
compare("macros combinadas (b): sexo 0 % + músculo 0 % + peso 100 %", COMBINED_MM,
        macros={"gender": 0.0, "muscle": 0.0, "weight": 1.0})
compare("macros combinadas (c): peso 100 % + pecho 100 %", COMBINED_MM, macros={"weight": 1.0, "breast_volume": 1.0})
statistics("esquinas (cada macro a 0, 0,5 o 1)",
           [dict(zip(MACRO_KEYS, values)) for values in itertools.product((0.0, 0.5, 1.0), repeat=len(MACRO_KEYS))])
rng = np.random.default_rng(0)
statistics("macros al azar", [{i: float(rng.random()) for i in MACRO_KEYS} for _ in range(RANDOM_BODIES)])

moved_l = np.linalg.norm(deltas["hand_position_incr_l"], axis=1) > 1e-5
moved_r = np.linalg.norm(deltas["hand_position_incr_r"], axis=1) > 1e-5
check("forma _l solo mueve el lado izquierdo (+X)", moved_l.any() and (neutral[moved_l, 0] > 0).all())
check("forma _r solo mueve el lado derecho (-X)", moved_r.any() and (neutral[moved_r, 0] < 0).all())

# --- Huesos: brazo + hombros + pierna + macro, contra el rig de MPFB ---
weights = weights_for({"muscle": 1.0}, {"arm_length_incr": 0.7, "shoulder_width_incr": 0.5, "leg_length_incr": 0.6},
                      shapes)
_, actual_joints, actual_matrices = mpfb(
    {"muscle": 1.0},
    {"measure-upperarm-length-incr": 0.7, "measure-lowerarm-length-incr": 0.7, "measure-shoulder-dist-incr": 0.5,
     "measure-upperleg-height-incr": 0.6, "measure-lowerleg-height-incr": 0.6})
worst_mm, worst_deg = 0.0, 0.0
for name in manifest["bones"]["deform"]:
    head, tail = predict_bone(joints[name], weights)
    real_head, real_tail = (Vector(p) + Vector(offset) for p in actual_joints[name])
    worst_mm = max(worst_mm, (head - real_head).length * 1000, (tail - real_tail).length * 1000)
    # Orientación como en FORMATO.md: giro fijo sobre el propio eje (roll), referido al +Y de Blender.
    base_head, base_tail = (Vector(p) for p in neutral_joints[name])
    to_new, to_base = (REFERENCE.rotation_difference(d).to_matrix() for d in (tail - head, base_tail - base_head))
    predicted = to_new @ to_base.inverted() @ neutral_matrices[name]
    worst_deg = max(worst_deg, np.degrees((predicted.inverted() @ actual_matrices[name]).to_quaternion().angle))
check(f"huesos: brazo + hombros + pierna + músculo, posición < {BONE_MM} mm", worst_mm < BONE_MM, f"{worst_mm:.4f} mm")
check(f"huesos: orientación < {BONE_DEG}°", worst_deg < BONE_DEG, f"{worst_deg:.3f}°")

print(f"RESULTADO: {len(failures)} fallos" + (f" ({', '.join(failures)})" if failures else ""))
sys.exit(1 if failures else 0)
