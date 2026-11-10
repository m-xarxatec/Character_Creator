# SPDX-License-Identifier: GPL-3.0-or-later
"""Genera los datos de una especie para Godot (paso 2.3), segun datos/FORMATO.md.

Uso: blender -b -P blender/exportar_datos.py -- datos/humana
Lee <carpeta>/deslizadores.csv y escribe cuerpo.glb, articulaciones.json y manifiesto.json.

Cada forma se mide creando un cuerpo nuevo con MPFB (target o macro al 100 %, con su rig)
y restandole el cuerpo neutro: asi la malla y los huesos salen tal cual los calcula MPFB.
Ademas mide las formas de correccion de las macros combinadas (ver FORMATO.md).
"""
import copy
import csv
import itertools
import hashlib
import json
import os
import sys

import bpy
import numpy as np
from bl_ext.blender_org.mpfb.services import HumanService, TargetService
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generar_cuerpo as gc  # noqa: E402
from anclajes import add_sockets  # noqa: E402
from exportar_glb import export_glb, humanoid_names, rename_to_humanoid  # noqa: E402
from limpiar_malla import SKIN_GROUP, clean_mesh  # noqa: E402
from poner_rig import add_rig  # noqa: E402
from prenda_base import paint_base_garment  # noqa: E402

FORMAT_VERSION = 1
SPECIES = "humana"
SOURCE = "MakeHuman system assets (CC0) con MPFB 2.0.18"
SOCKET_LENGTH = 0.05  # metros; el hueso de anclaje apunta hacia arriba
MIN_DELTA = 1e-6  # metros; por debajo, el hueso no se mueve con esa forma
CORRECTION_MIN = 0.0005  # metros; una correccion mas pequena no se guarda
FILES = ("cuerpo.glb", "articulaciones.json", "deslizadores.csv")


def neutral_macros():
    return gc.validate_spec({"version": gc.FORMAT_VERSION})["macros"]


def read_sliders(folder):
    with open(os.path.join(folder, "deslizadores.csv"), encoding="utf-8", newline="") as file:
        return list(csv.DictReader(file))


def shape_specs(rows):
    """[(nombre de la forma, macros, {target: peso})] de cada deslizador Forma, por sentido y lado."""
    specs = []
    for row in (r for r in rows if r["tipo"] == "Forma"):
        for direction in ("decr", "incr"):
            for side in ("l", "r") if row["lados"] == "2" else (None,):
                name = f"{row['id']}_{direction}" + (f"_{side}" if side else "")
                specs.append((name, *_source(row[direction], side)))
    return specs


def _source(value, side):
    macros = neutral_macros()
    if value.startswith("macro:"):
        key, number = value[len("macro:"):].split("=")
        macros[key] = float(number)
        return macros, {}
    return macros, {(f"{side}-{t}" if side else t): 1.0 for t in value.split("+")}


def keep_small_macro_weights():
    """MPFB descarta cada combinacion de macros con peso < 0,01: el cuerpo da saltos de hasta ~1 mm por target.
    Aqui se guardan todas (corte en 0), para que las formas sigan las mezclas de MakeHuman sin saltos."""
    stack = TargetService.calculate_target_stack_from_macro_info_dict
    if not getattr(stack, "keeps_small_weights", False):
        def without_cutoff(macro_info=None, cutoff=0.0):
            return stack(macro_info, cutoff=0.0)
        without_cutoff.keeps_small_weights = True
        TargetService.calculate_target_stack_from_macro_info_dict = staticmethod(without_cutoff)


def raw_body(macros, targets):
    """Cuerpo de MPFB con rig, sin bajar los pies al suelo (las restas no deben llevar ese desplazamiento)."""
    keep_small_macro_weights()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    basemesh = HumanService.create_human(macro_detail_dict=copy.deepcopy(macros), feet_on_ground=False)
    for name, weight in targets.items():
        TargetService.load_target(basemesh, TargetService.target_full_path(name), weight=weight, name=name)
    add_rig(basemesh)
    return basemesh


def sample(basemesh):
    """(vertices de la piel, {hueso humanoide: (cabeza, cola)}) en ejes de Blender."""
    key = basemesh.shape_key_add(name="_mezcla", from_mix=True)
    coords = np.empty(len(key.data) * 3)
    key.data.foreach_get("co", coords)
    basemesh.shape_key_remove(key)
    skin = _skin_count(basemesh)
    rig, names = basemesh.parent, humanoid_names()
    joints = {names[b.name]: (np.array(rig.matrix_world @ b.head_local), np.array(rig.matrix_world @ b.tail_local))
              for b in rig.data.bones}
    return coords.reshape(-1, 3)[:skin], joints


def _skin_count(basemesh):
    """La piel son los primeros vertices de la malla base; la malla auxiliar va detras."""
    group = basemesh.vertex_groups[SKIN_GROUP].index
    skin = [v.index for v in basemesh.data.vertices if any(g.group == group for g in v.groups)]
    if skin != list(range(len(skin))):
        raise ValueError("La piel no son los primeros vertices de la malla")
    return len(skin)


def measure_shapes(rows):
    """{forma: (desplazamiento de cada vertice, {hueso: (d_cabeza, d_cola)})} respecto al cuerpo neutro.

    Primero las formas de la tabla y despues las correcciones de las macros combinadas.
    """
    neutral = sample(raw_body(neutral_macros(), {}))
    shapes = {name: _minus(sample(raw_body(macros, targets)), neutral) for name, macros, targets in shape_specs(rows)}
    shapes.update(corrections(corner_bodies(macro_sliders(rows))))
    return neutral[0], shapes


def _minus(a, b):
    return a[0] - b[0], {bone: (h - b[1][bone][0], t - b[1][bone][1]) for bone, (h, t) in a[1].items()}


def _combine(terms):
    """Suma [(coeficiente, muestra)] de vertices y de cabeza/cola de cada hueso."""
    verts = sum(c * s[0] for c, s in terms)
    joints = {bone: tuple(sum(c * s[1][bone][i] for c, s in terms) for i in (0, 1)) for bone in terms[0][1][1]}
    return verts, joints


def macro_sliders(rows):
    """[(id, macro)] de los deslizadores que mueven una macro de 0 (decr) a 1 (incr)."""
    found = []
    for row in (r for r in rows if r["tipo"] == "Forma" and r["decr"].startswith("macro:")):
        key = row["decr"][len("macro:"):].split("=")[0]
        if (row["decr"], row["incr"]) != (f"macro:{key}=0", f"macro:{key}=1"):
            raise ValueError(f"{row['id']}: una macro debe ir de 0 a 1")
        found.append((row["id"], key))
    return found


def corner_bodies(sliders):
    """{esquina: muestra} con cada combinacion de macros a 0 o a 1; esquina = ((id, 0 o 1), ...), () = neutro."""
    bodies = {}
    for size in range(len(sliders) + 1):
        for subset in itertools.combinations(sliders, size):
            for sides in itertools.product((0, 1), repeat=size):
                macros = neutral_macros()
                macros.update({key: float(side) for (_, key), side in zip(subset, sides)})
                bodies[tuple((i, side) for (i, _), side in zip(subset, sides))] = sample(raw_body(macros, {}))
    return bodies


def corrections(bodies):
    """Lo que cada esquina de 2 o mas macros anade a la suma de sus partes (inclusion-exclusion).

    Nombre: formas unidas por '*', p. ej. 'muscle_incr*weight_incr'; su peso es el producto de sus pesos.
    """
    shapes = {}
    for corner in (c for c in bodies if len(c) >= 2):
        terms = [((-1) ** (len(corner) - size), bodies[part])
                 for size in range(len(corner) + 1) for part in itertools.combinations(corner, size)]
        verts, joints = _combine(terms)
        if np.linalg.norm(verts, axis=1).max() > CORRECTION_MIN:
            shapes["*".join(f"{i}_{'incr' if side else 'decr'}" for i, side in corner)] = (verts, joints)
    return shapes


def build_base():
    """Cuerpo neutro en pose A, con pies en el suelo, prenda, nombres humanoides y anclajes como huesos."""
    keep_small_macro_weights()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    basemesh = gc.create_body(gc.validate_spec({"version": gc.FORMAT_VERSION}))
    add_rig(basemesh)
    paint_base_garment(basemesh)
    clean_mesh(basemesh)
    rename_to_humanoid(basemesh)
    return basemesh, sockets_to_bones(basemesh, add_sockets(basemesh))


def sockets_to_bones(basemesh, sockets):
    """Cambia los anclajes (objetos vacios) por huesos sin peso. Devuelve {anclaje: regla para moverlo}."""
    rig = basemesh.parent
    points = [(s.name, s.parent_bone, s.matrix_world.translation.copy()) for s in sockets]
    for socket in sockets:
        bpy.data.objects.remove(socket)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, position in points:
        bone = rig.data.edit_bones.new(name)
        bone.head, bone.tail = position, position + Vector((0.0, 0.0, SOCKET_LENGTH))
        bone.parent, bone.use_deform = rig.data.edit_bones[parent], False
    bpy.ops.object.mode_set(mode="OBJECT")
    return {name: _socket_rule(basemesh, parent, position) for name, parent, position in points}


def _socket_rule(basemesh, parent, position):
    """Mano: entre muneca y nudillo (como anclajes.py). Espalda y cadera: el vertice de piel mas cercano."""
    if parent.endswith("Hand"):
        return ("palm", parent, parent.replace("Hand", "MiddleProximal"))
    nearest = min(basemesh.data.vertices, key=lambda v: (v.co - position).length)
    return ("vertex", nearest.index)


def socket_delta(rule, verts_delta, joints_delta):
    if rule[0] == "palm":
        return (joints_delta[rule[1]][0] + joints_delta[rule[2]][0]) / 2
    return verts_delta[rule[1]]


def shape_weights(values, names, fixed=None):
    """{forma: peso} como los calcula Godot (FORMATO.md), para todas las formas de names.

    values: {(id, lado o None): valor de 0 a 1}; fixed: {forma: peso} puestos a mano.
    _decr = max(0, 1−2v), _incr = max(0, 2v−1); cada correccion, el producto de los pesos de sus partes.
    """
    weights = dict.fromkeys(names, 0.0)
    for (slider, side), v in values.items():
        end = f"_{side}" if side else ""
        weights[f"{slider}_decr{end}"] = max(0.0, 1 - 2 * v)
        weights[f"{slider}_incr{end}"] = max(0.0, 2 * v - 1)
    weights.update(fixed or {})
    for name in (n for n in names if "*" in n):
        weights[name] = float(np.prod([weights[part] for part in name.split("*")]))
    return weights


def add_shape_keys(basemesh, shapes):
    base = np.empty(len(basemesh.data.vertices) * 3)
    basemesh.data.vertices.foreach_get("co", base)
    basemesh.shape_key_add(name="Basis", from_mix=False)
    for name, (verts_delta, _) in shapes.items():
        if len(verts_delta) * 3 != len(base):
            raise ValueError(f"{name}: {len(verts_delta)} vertices, la malla tiene {len(base) // 3}")
        key = basemesh.shape_key_add(name=name, from_mix=False)
        key.data.foreach_set("co", base + verts_delta.ravel())


def godot(v):
    """Blender (Z arriba, mira a -Y) -> Godot (Y arriba, mira a +Z), redondeado a micras."""
    return [round(float(c), 6) + 0.0 for c in (v[0], v[2], -v[1])]


def joints_json(rig, shapes, socket_rules):
    bones = {}
    for bone in rig.data.bones:
        deltas = {}
        for shape, (verts_delta, joints_delta) in shapes.items():
            if bone.name in socket_rules:
                head = tail = socket_delta(socket_rules[bone.name], verts_delta, joints_delta)
            else:
                head, tail = joints_delta[bone.name]
            if max(np.abs(head).max(), np.abs(tail).max()) > MIN_DELTA:
                deltas[shape] = {"head": godot(head), "tail": godot(tail)}
        bones[bone.name] = {
            "parent": bone.parent.name if bone.parent else None,
            "head": godot(rig.matrix_world @ bone.head_local),
            "tail": godot(rig.matrix_world @ bone.tail_local),
            "deltas": deltas,
        }
    return {"bones": bones}


def manifest(folder, basemesh, rig):
    return {
        "version": FORMAT_VERSION,
        "species": SPECIES,
        "pose": "A",
        "source": SOURCE,
        "vertex_count": len(basemesh.data.vertices),
        "bones": {
            "deform": [b.name for b in rig.data.bones if b.use_deform],
            "sockets": [b.name for b in rig.data.bones if not b.use_deform],
        },
        "files": {name: {"sha256": sha256(os.path.join(folder, name))} for name in FILES},
    }


def sha256(path):
    with open(path, "rb") as file:
        return hashlib.sha256(file.read()).hexdigest()


def write_json(path, data):
    with open(path, "w", encoding="utf-8") as file:
        json.dump(data, file, ensure_ascii=False, indent=1, sort_keys=True)
        file.write("\n")


def export_species(folder):
    """Escribe los datos de la especie en folder. Devuelve el manifiesto."""
    folder = os.path.abspath(folder)
    _, shapes = measure_shapes(read_sliders(folder))
    basemesh, socket_rules = build_base()
    add_shape_keys(basemesh, shapes)
    export_glb(basemesh, [], os.path.join(folder, "cuerpo.glb"), morph=True, deform_only=False)
    write_json(os.path.join(folder, "articulaciones.json"), joints_json(basemesh.parent, shapes, socket_rules))
    data = manifest(folder, basemesh, basemesh.parent)
    write_json(os.path.join(folder, "manifiesto.json"), data)
    return data


def main():
    folder = sys.argv[sys.argv.index("--") + 1]
    data = export_species(folder)
    size = os.path.getsize(os.path.join(folder, "cuerpo.glb")) / 1e6
    print(f"EXPORTADO: {folder} ({len(data['bones']['deform'])} huesos + {len(data['bones']['sockets'])} anclajes,"
          f" {data['vertex_count']} vertices, cuerpo.glb {size:.1f} MB)")


if __name__ == "__main__":
    main()
