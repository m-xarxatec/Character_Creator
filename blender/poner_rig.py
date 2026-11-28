# SPDX-License-Identifier: GPL-3.0-or-later
"""Pone el rig "Game engine" de MPFB y deja los pesos listos para juegos.

Paso 9.3: el rig Game engine no trae los ojos ni la mandibula del perfil humanoide de Godot. add_face_bones los anade
(LeftEye, RightEye y Jaw, hijos de la cabeza, de deformacion y sin pesos) en el centro de los cubos de articulacion de
MakeHuman (FACE_JOINTS): como esos cubos siguen a los targets, los huesos se mueven con las formas igual que los demas.
"""
import bpy
from bl_ext.blender_org.mpfb.services import HumanService
from mathutils import Vector

RIG_NAME = "game_engine"
MAX_INFLUENCES = 4
CROSS_MIN_X = 0.05  # metros: mas lejos del centro, un vertice no lleva pesos de huesos del otro lado
# Paso 9.3: hueso -> (grupo del cubo de articulacion de MakeHuman, direccion de la cola en ejes de Blender). NO VERIFICADO
# que los grupos se llamen asi en esta version: si falta alguno, add_face_bones para y lista los «joint-*» que hay.
FACE_JOINTS = {"LeftEye": ("joint-l-eye", (0.0, -1.0, 0.0)), "RightEye": ("joint-r-eye", (0.0, -1.0, 0.0)),
               "Jaw": ("joint-jaw", (0.0, -0.8, -0.6))}
FACE_PARENT = "head"  # nombre del rig Game engine (rename_to_humanoid lo cambia a Head despues)
FACE_BONE_LENGTH = 0.02  # metros


def add_rig(basemesh):
    """Crea el esqueleto ajustado al cuerpo y devuelve el objeto armature."""
    HumanService.add_builtin_rig(basemesh, RIG_NAME, import_weights=True)
    add_face_bones(basemesh)  # paso 9.3
    remove_cross_weights(basemesh)
    limit_weights(basemesh)
    return basemesh.parent


def add_face_bones(basemesh):
    """Paso 9.3: LeftEye, RightEye y Jaw (FACE_JOINTS), hijos de la cabeza, de deformacion y sin pesos (los ojos son
    capas con shader y la boca se abre con formas, D57/D58: los huesos estan para el perfil humanoide y para despues).
    Van al final de los huesos del rig: los indices de los de antes no cambian."""
    rig = basemesh.parent
    world = basemesh.matrix_world
    coords = _mixed_coords(basemesh)
    centers = {}
    joints = sorted(g.name for g in basemesh.vertex_groups if g.name.startswith("joint-"))
    for bone, (group, _) in FACE_JOINTS.items():
        if group not in basemesh.vertex_groups:
            raise ValueError("Paso 9.3: no esta el grupo %s; grupos de articulacion: %s" % (group, ", ".join(joints)))
        index = basemesh.vertex_groups[group].index
        points = [world @ coords[v.index] for v in basemesh.data.vertices if any(g.group == index and g.weight > 0 for g in v.groups)]
        if not points:
            raise ValueError("Paso 9.3: el grupo %s no tiene vertices" % group)
        centers[bone] = sum(points, Vector()) / len(points)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    to_rig = rig.matrix_world.inverted()
    for bone, (_, tail) in FACE_JOINTS.items():
        edit = rig.data.edit_bones.new(bone)
        edit.head = to_rig @ centers[bone]
        edit.tail = edit.head + Vector(tail).normalized() * FACE_BONE_LENGTH
        edit.parent, edit.use_deform = rig.data.edit_bones[FACE_PARENT], True
    bpy.ops.object.mode_set(mode="OBJECT")


def _mixed_coords(basemesh):
    """Posicion de cada vertice con las shape keys mezcladas (MPFB pone los targets como shape keys), como sample()
    de exportar_datos.py; sin shape keys, la de la malla."""
    if basemesh.data.shape_keys is None:
        return [v.co.copy() for v in basemesh.data.vertices]
    key = basemesh.shape_key_add(name="_mezcla_huesos_cara", from_mix=True)
    coords = [d.co.copy() for d in key.data]
    basemesh.shape_key_remove(key)
    return coords


def cross_weights(basemesh, vertex):
    """{grupo: peso} de huesos del lado contrario (sufijo _l en +X, _r en -X) si el vertice esta a mas de CROSS_MIN_X."""
    if abs(vertex.co.x) <= CROSS_MIN_X:
        return {}
    other = "_r" if vertex.co.x > 0 else "_l"
    return {name: w for name, w in bone_weights(basemesh, vertex).items() if name.endswith(other)}


def remove_cross_weights(basemesh):
    """Quita los pesos del lado contrario lejos del centro (vienen asi de MakeHuman). Devuelve cuantos quito."""
    removed = 0
    for vertex in basemesh.data.vertices:
        for name in cross_weights(basemesh, vertex):
            basemesh.vertex_groups[name].remove([vertex.index])
            removed += 1
    return removed


def limit_weights(basemesh):
    """Maximo 4 huesos por vertice y que sumen 1 (regla de CLAUDE.md, seccion 6)."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = basemesh
    basemesh.select_set(True)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="BONE_DEFORM", limit=MAX_INFLUENCES)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="BONE_DEFORM", lock_active=False)


def bone_weights(basemesh, vertex):
    """{hueso: peso} de un vertice, solo huesos del rig y pesos mayores que 0."""
    bones = basemesh.parent.data.bones
    groups = basemesh.vertex_groups
    return {groups[g.group].name: g.weight for g in vertex.groups if g.weight > 0 and groups[g.group].name in bones}
