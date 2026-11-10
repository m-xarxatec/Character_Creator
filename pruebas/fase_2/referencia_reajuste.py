# SPDX-License-Identifier: GPL-3.0-or-later
"""Referencia del paso 2.4: cuerpos de MPFB con los que se compara el reajuste de huesos de Godot.

Uso: blender -b -P pruebas/fase_2/referencia_reajuste.py
Lee datos/humana/ y escribe pruebas/fase_2/salida/referencia_reajuste.json (lo usa pruebas/godot/probar_reajuste.gd).

Cada cuerpo se define con los valores de los deslizadores Forma (0 a 1; 0,5 = neutro; los de dos lados, por lado).
Se guardan, en ejes de Godot, los valores de los deslizadores, los pesos de las formas (regla de FORMATO.md) y la cabeza, la cola y el giro de cada
hueso según MPFB (sin su descarte de pesos < 0,01, como en el paso 2.3). Los anclajes no existen en MPFB: se colocan
con su regla de FORMATO.md sobre el cuerpo de MPFB; como no cambian de dirección, su giro es el de la base.
También guarda los pesos de la prueba de continuidad en 0,5 (sin MPFB, que ahí tiene huecos) y los vértices de
la piel de MPFB del cuerpo neutro y de WITH_VERTICES (prueba de punta a punta del paso 3.2),
y los pesos de las 243 esquinas de las macros (cada una a 0, 0,5 o 1) para el paso 3.2.
"""
import itertools
import json
import os
import struct
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import exportar_datos as ed  # noqa: E402
from exportar_glb import humanoid_names  # noqa: E402

DATA = os.path.join(ROOT, "datos", "humana")
OUT = os.path.join(ROOT, "pruebas", "fase_2", "salida", "referencia_reajuste.json")
CONTINUITY = (0.49985, 0.5, 0.50015)
WITH_VERTICES = ("atletico", "extremo")  # prueba de punta a punta del paso 3.2
IDENTITY = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]


def slots(rows):
    """[(id, lado)] de cada deslizador Forma; lado None si es uno solo."""
    return [(r["id"], side) for r in rows if r["tipo"] == "Forma"
            for side in (("l", "r") if r["lados"] == "2" else (None,))]


def bodies(rows):
    """{nombre: {(id, lado): valor}} de los 6 cuerpos de la prueba."""
    neutral = {slot: 0.5 for slot in slots(rows)}
    rng = np.random.default_rng(0)

    def with_values(**values):
        return {slot: values.get(slot[0], 0.5) for slot in neutral}

    return {
        "neutro": neutral,
        "atletico": with_values(muscle=1.0, shoulder_width=0.8, shoulder_muscle=0.9, torso_vshape=1.0,
                                back_width=0.8, arm_muscle=0.9, arm_thickness=0.7),
        "mujer_robusta": with_values(gender=0.0, weight=0.9, breast_volume=0.8, hip_width=0.8, leg_length=0.2),
        "largo": with_values(leg_length=1.0, neck_length=0.9, arm_length=1.0),
        "al_azar": {slot: float(rng.random()) for slot in neutral},
        "extremo": {slot: float(rng.integers(0, 2)) for slot in neutral},
    }


def weights(values, shape_names):
    """{forma: peso > 0}, con la misma función que se comparó con MPFB en el paso 2.3."""
    return {name: w for name, w in sorted(ed.shape_weights(values, shape_names).items()) if w > 0}


def slot_values(values):
    """{"id" o "id_l"/"id_r": valor}, las claves que usa Godot (shape_weights.gd)."""
    return {(f"{i}_{side}" if side else i): v for (i, side), v in values.items()}


def glb_shape_names(path):
    """Nombres de las formas de cuerpo.glb (los guarda el exportador glTF en extras.targetNames)."""
    with open(path, "rb") as file:
        data = file.read()
    size = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + size])["meshes"][0]["extras"]["targetNames"]


def mpfb_inputs(values, rows):
    """(macros, {target: peso}) de MPFB para unos valores de los deslizadores."""
    by_id = {r["id"]: r for r in rows}
    macros, targets = ed.neutral_macros(), {}
    gaps = ed.gc.mpfb_gaps()
    for (slider, side), v in values.items():
        row = by_id[slider]
        if row["decr"].startswith("macro:"):
            key = row["decr"][len("macro:"):].split("=")[0]
            if v != 0.5 and ed.gc.in_mpfb_gap(key, v, gaps):
                raise ValueError(f"{slider} = {v} cae en un hueco de MPFB")
            macros[key] = v
            continue
        for direction, w in (("decr", max(0.0, 1 - 2 * v)), ("incr", max(0.0, 2 * v - 1))):
            for target in row[direction].split("+") if w > 0 else ():
                targets[f"{side}-{target}" if side else target] = w
    return macros, targets


def mpfb_body(macros, targets):
    """(vértices de piel, {hueso: (cabeza, cola)}, {hueso: giro 3x3}) de MPFB, en ejes de Blender."""
    body = ed.raw_body(macros, targets)
    verts, joints = ed.sample(body)
    rig, names = body.parent, humanoid_names()
    turns = {names[b.name]: rig.matrix_world.to_3x3() @ b.matrix_local.to_3x3() for b in rig.data.bones}
    return verts, joints, turns


def to_godot(v):
    return [float(v[0]), float(v[2]), -float(v[1])]


def to_blender(v):
    return np.array([v[0], -v[2], v[1]])


def basis(matrix):
    """Ejes x, y, z del hueso (columnas) en ejes de Godot."""
    return [to_godot(matrix.col[i]) for i in range(3)]


def socket_rules(joints, neutral_verts, offset):
    """{anclaje: función(vértices, huesos) -> punto que lo mueve}, como en FORMATO.md."""
    rules = {}
    for name in (b for b in joints if b.startswith("socket_")):
        parent = joints[name]["parent"]
        if parent.endswith("Hand"):
            knuckle = parent.replace("Hand", "MiddleProximal")
            rules[name] = lambda verts, bones, p=parent, k=knuckle: (bones[p][0] + bones[k][0]) / 2
        else:
            position = to_blender(joints[name]["head"]) - offset
            index = int(np.argmin(np.linalg.norm(neutral_verts - position, axis=1)))
            rules[name] = lambda verts, bones, i=index: verts[i]
    return rules


def bone_record(head, tail, turn):
    return {"head": to_godot(head), "tail": to_godot(tail), "basis": turn}


def main():
    rows = ed.read_sliders(DATA)
    with open(os.path.join(DATA, "articulaciones.json"), encoding="utf-8") as file:
        joints = json.load(file)["bones"]
    shape_names = glb_shape_names(os.path.join(DATA, "cuerpo.glb"))
    neutral_verts, neutral_joints, neutral_turns = mpfb_body(ed.neutral_macros(), {})
    offset = np.array([0.0, 0.0, -neutral_verts[:, 2].min()])  # articulaciones.json tiene los pies en el suelo
    rules = socket_rules(joints, neutral_verts, offset)
    reference = {"base": {b: basis(t) for b, t in neutral_turns.items()}, "bodies": [], "continuity": [], "corners": [],
                 "shapes": shape_names, "neutral_vertices": [to_godot(v + offset) for v in neutral_verts]}
    reference["base"].update({s: IDENTITY for s in rules})
    every = bodies(rows)
    for name, values in every.items():
        verts, body_joints, turns = mpfb_body(*mpfb_inputs(values, rows))
        bones = {b: bone_record(h + offset, t + offset, basis(turns[b])) for b, (h, t) in body_joints.items()}
        for socket, rule in rules.items():
            move = rule(verts, body_joints) - rule(neutral_verts, neutral_joints)
            head, tail = (to_blender(joints[socket][end]) + move for end in ("head", "tail"))
            bones[socket] = bone_record(head, tail, IDENTITY)
        record = {"name": name, "values": slot_values(values), "weights": weights(values, shape_names), "bones": bones}
        if name in WITH_VERTICES:
            record["vertices"] = [to_godot(v + offset) for v in verts]
        reference["bodies"].append(record)
    for background in ("neutro", "extremo"):
        for slot in slots(rows):
            label = f"{background}: {slot[0]}" + (f" {slot[1]}" if slot[1] else "")
            triple = [{**every[background], slot: v} for v in CONTINUITY]
            reference["continuity"].append({"name": label, "values": [slot_values(b) for b in triple],
                                            "weights": [weights(b, shape_names) for b in triple]})
    macros = [i for i, _ in ed.macro_sliders(rows)]
    for corner in itertools.product((0.0, 0.5, 1.0), repeat=len(macros)):  # activan las 81 correcciones
        values = {**every["neutro"], **{(i, None): v for i, v in zip(macros, corner)}}
        reference["corners"].append({"values": slot_values(values), "weights": weights(values, shape_names)})
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as file:
        json.dump(reference, file, ensure_ascii=False)
    print(f"RESULTADO: referencia escrita ({len(reference['bodies'])} cuerpos,"
          f" {len(reference['bodies'][0]['bones'])} huesos, {len(reference['continuity'])} tríos de continuidad)")


main()
