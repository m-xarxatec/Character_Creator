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
los vértices del cuerpo ELBOW["body"] con el codo doblado (paso 3.4: MPFB + esqueleto de Blender),
los de T_POSE_BODIES en pose T con blender/pose_t.py (paso 3.6.2)
y los pesos de las 243 esquinas de las macros (cada una a 0, 0,5 o 1) para el paso 3.2.
"""
import collections
import itertools
import json
import os
import struct
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import exportar_datos as ed  # noqa: E402
from exportar_glb import humanoid_names  # noqa: E402
import pose_t  # noqa: E402
import poner_rig  # noqa: E402
from bl_ext.blender_org.mpfb.services import HumanService, TargetService  # noqa: E402

DATA = os.path.join(ROOT, "datos", "humana")
OUT = os.path.join(ROOT, "pruebas", "fase_2", "salida", "referencia_reajuste.json")
CONTINUITY = (0.49985, 0.5, 0.50015)
WITH_VERTICES = ("atletico", "extremo")  # prueba de punta a punta del paso 3.2
ELBOW = {"body": "largo", "bone": "LeftLowerArm", "axis": [0.0, 0.0, 1.0], "degrees": 90.0}  # ejes de Godot
T_POSE_BODIES = ("neutro", "extremo")  # paso 3.6.2
T_REST_BODIES = ("extremo", "al_azar")  # paso 3.6.3
FOUR_WEIGHT_POSES = {  # paso 3.6.3: (hueso, eje en Blender, grados)
    "codo 90°": [(ELBOW["bone"], (0.0, -1.0, 0.0), 90.0)],
    "giro de tronco 45° (Spine)": [("Spine", (0.0, 0.0, 1.0), 45.0)],
    "giro de tronco 45° (Chest)": [("Chest", (0.0, 0.0, 1.0), 45.0)],
    "tronco hacia delante 45° (Chest)": [("Chest", (1.0, 0.0, 0.0), 45.0)],
    "cabeza girada 45° (Neck)": [("Neck", (0.0, 0.0, 1.0), 45.0)],
}
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


def bend_elbow(rig):
    """Gira el hueso de ELBOW sobre su cabeza (paso 3.4)."""
    name = next(old for old, new in humanoid_names().items() if new == ELBOW["bone"])
    pose = rig.pose.bones[name]
    axis = Vector(to_blender(ELBOW["axis"]))
    turn = Matrix.Translation(pose.head) @ Matrix.Rotation(np.radians(ELBOW["degrees"]), 4, axis) \
        @ Matrix.Translation(-pose.head)
    pose.matrix = turn @ pose.matrix


def t_pose(rig):
    """Brazos en T con blender/pose_t.py, sin fijarla como reposo (paso 3.6.2)."""
    for suffix, direction in pose_t.SIDES:
        pose_t._straighten_arm(rig, suffix, Vector((direction, 0.0, 0.0)))


def posed_vertices(values, rows, offset, pose):
    """Vértices de la piel de MPFB (ejes de Godot) tras poner el esqueleto de Blender con pose(rig)."""
    body = ed.raw_body(*mpfb_inputs(values, rows))
    rig = body.parent
    if rig.matrix_world != Matrix.Identity(4):
        raise ValueError("El rig de MPFB no está en el origen")
    pose(rig)
    for modifier in body.modifiers:  # solo el esqueleto: MPFB pone otro que oculta la malla auxiliar
        modifier.show_viewport = modifier.type == "ARMATURE"
    bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    if len(evaluated.data.vertices) != len(body.data.vertices):
        raise ValueError("La malla evaluada no tiene los mismos vértices")
    world = evaluated.matrix_world
    return [to_godot(np.array(world @ v.co) + offset) for v in evaluated.data.vertices[:ed._skin_count(body)]]


def evaluated_skin(body):
    """Vértices de la piel deformados solo por el esqueleto, en ejes de Blender."""
    for modifier in body.modifiers:
        modifier.show_viewport = modifier.type == "ARMATURE"
    bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    world = evaluated.matrix_world
    return np.array([world @ v.co for v in evaluated.data.vertices[:ed._skin_count(body)]])


def turn_bone(rig, bone, axis, degrees):
    """Gira un hueso (nombre humanoide) sobre su cabeza, con un eje en ejes de Blender."""
    name = next(old for old, new in humanoid_names().items() if new == bone)
    pose = rig.pose.bones[name]
    turn = Matrix.Translation(pose.head) @ Matrix.Rotation(np.radians(degrees), 4, Vector(axis)) \
        @ Matrix.Translation(-pose.head)
    pose.matrix = turn @ pose.matrix
    bpy.context.view_layer.update()


def clear_pose(rig):
    for pose in rig.pose.bones:
        pose.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def four_weights_measure(values, rows):
    """Paso 3.6.3: cuánto cambia la malla deformada al recortar los pesos de MPFB a 4 por vértice (poner_rig.py)."""
    ed.keep_small_macro_weights()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    macros, targets = mpfb_inputs(values, rows)
    body = HumanService.create_human(macro_detail_dict=macros, feet_on_ground=False)
    for name, weight in targets.items():
        TargetService.load_target(body, TargetService.target_full_path(name), weight=weight, name=name)
    HumanService.add_builtin_rig(body, poner_rig.RIG_NAME, import_weights=True)  # sin recortar
    rig = body.parent
    skin = ed._skin_count(body)
    weights = [poner_rig.bone_weights(body, v) for v in body.data.vertices[:skin]]
    over = [len(w) > 4 for w in weights]
    names = humanoid_names()
    where = collections.Counter(names[max(w, key=w.get)] for w in weights if len(w) > 4)
    dropped = max(sum(sorted(w.values())[:-4]) / sum(w.values()) for w in weights if len(w) > 4)

    def posed():
        found = {}
        for label, turns in FOUR_WEIGHT_POSES.items():
            clear_pose(rig)
            for bone, axis, degrees in turns:
                turn_bone(rig, bone, axis, degrees)
            found[label] = evaluated_skin(body)
        clear_pose(rig)
        return found

    before = posed()
    poner_rig.limit_weights(body)
    after = posed()
    poses = {}
    for label in before:
        moved = np.linalg.norm(after[label] - before[label], axis=1) * 1000
        poses[label] = {"max_mm": float(moved.max()), "mean_mm": float(moved.mean()),
                        "mean_over_four_mm": float(moved[over].mean()), "over_0_1_mm": int((moved > 0.1).sum())}
    return {"vertices": skin, "over_four": int(sum(over)), "most": int(max(len(w) for w in weights)),
            "main_bones": dict(where.most_common(6)), "largest_dropped_weight": float(dropped), "poses": poses}


def t_rest_elbow(values, rows):
    """Paso 3.6.3: pose T fijada como reposo con blender/pose_t.py (como en la Fase 1) y después el codo de ELBOW.

    Devuelve los vértices de la piel en ejes de Godot, con el suelo (punto más bajo antes de doblar) en y = 0.
    """
    body = ed.raw_body(*mpfb_inputs(values, rows))
    for modifier in [m for m in body.modifiers if m.type != "ARMATURE"]:
        body.modifiers.remove(modifier)
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.shape_key_remove(all=True, apply_mix=True)  # las formas pasan a la malla
    pose_t.apply_t_pose(body)
    ground = evaluated_skin(body)[:, 2].min()
    bend_elbow(body.parent)
    return [to_godot(v - np.array([0.0, 0.0, ground])) for v in evaluated_skin(body)]


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
    reference["elbow"] = {**ELBOW, "vertices": posed_vertices(every[ELBOW["body"]], rows, offset, bend_elbow)}
    reference["t_pose"] = {name: posed_vertices(every[name], rows, offset, t_pose) for name in T_POSE_BODIES}
    reference["four_weights"] = four_weights_measure(every[ELBOW["body"]], rows)
    print("MEDIDA 4 influencias:", json.dumps(reference["four_weights"], ensure_ascii=False))
    reference["t_rest_elbow"] = {name: t_rest_elbow(every[name], rows) for name in T_REST_BODIES}
    macros = [i for i, _ in ed.macro_sliders(rows)]
    for corner in itertools.product((0.0, 0.5, 1.0), repeat=len(macros)):  # activan las 81 correcciones
        values = {**every["neutro"], **{(i, None): v for i, v in zip(macros, corner)}}
        reference["corners"].append({"values": slot_values(values), "weights": weights(values, shape_names)})
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as file:
        json.dump(reference, file, ensure_ascii=False)
    print(f"RESULTADO: referencia escrita ({len(reference['bodies'])} cuerpos,"
          f" {len(reference['bodies'][0]['bones'])} huesos, {len(reference['continuity'])} tríos de continuidad)")


if __name__ == "__main__":
    main()
