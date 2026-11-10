# SPDX-License-Identifier: GPL-3.0-or-later
"""Pasa el personaje de la pose A de MakeHuman a pose T y la deja como pose de reposo.

Solo se mueven los brazos: brazo, antebrazo y mano quedan en linea recta hacia los lados,
con la palma hacia abajo. En Blender el personaje mira a -Y y Z es arriba.
"""
import bpy
from mathutils import Matrix, Vector

SIDES = (("_l", 1.0), ("_r", -1.0))  # sufijo del hueso y hacia donde apunta el brazo en X
FORWARD = Vector((0.0, -1.0, 0.0))


def apply_t_pose(basemesh):
    rig = basemesh.parent
    for suffix, direction in SIDES:
        _straighten_arm(rig, suffix, Vector((direction, 0.0, 0.0)))
    _pose_to_rest(basemesh, rig)


def _straighten_arm(rig, suffix, target):
    pose = rig.pose.bones
    upper, lower, hand = pose["upperarm" + suffix], pose["lowerarm" + suffix], pose["hand" + suffix]
    _aim(upper, lambda: upper.tail - upper.head, target)
    _aim(lower, lambda: lower.tail - lower.head, target)
    _aim(hand, lambda: pose["middle_01" + suffix].head - hand.head, target)
    # Palma hacia abajo: el indice queda delante y el menique detras.
    _aim(hand, lambda: _flat(pose["index_01" + suffix].head - pose["pinky_01" + suffix].head, target), FORWARD)


def _aim(pose_bone, current, target):
    """Gira el hueso (y sus hijos) alrededor de su cabeza para que el vector current() apunte a target."""
    rotation = current().normalized().rotation_difference(target).to_matrix().to_4x4()
    pivot = Matrix.Translation(pose_bone.head)
    pose_bone.matrix = pivot @ rotation @ pivot.inverted() @ pose_bone.matrix
    bpy.context.view_layer.update()


def _flat(vector, axis):
    """Quita de vector la parte que va a lo largo de axis (para girar solo alrededor del brazo)."""
    return vector - axis * vector.dot(axis)


def _pose_to_rest(basemesh, rig):
    """Fija la deformacion en la malla y convierte la pose actual en la pose de reposo."""
    modifier = next(m for m in basemesh.modifiers if m.type == "ARMATURE")
    _activate(basemesh)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    _activate(rig)
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    basemesh.modifiers.new("Armature", "ARMATURE").object = rig


def _activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
