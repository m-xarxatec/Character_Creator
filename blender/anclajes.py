# SPDX-License-Identifier: GPL-3.0-or-later
"""Puntos de anclaje (sockets): objetos vacios pegados a un hueso, para colgar armas y accesorios.

En el personaje exportado no son huesos (solo se exportan huesos de deformacion); en datos/ si
(los convierte exportar_datos.py). Valen en pose A o T, con la misma orientacion que el mundo:
asi en Godot quedan con Y arriba y Z hacia delante.
"""
import bpy
from mathutils import Matrix, Vector

MARGIN = 0.02  # metros de separacion de la piel
SLICE = 0.03  # media altura de la rebanada de malla que se mide
HIP_GROUPS = ("Hips", "LeftUpperLeg")


def add_sockets(basemesh):
    """Crea los 4 anclajes y los devuelve. Usa los nombres de hueso del perfil humanoide."""
    rig = basemesh.parent
    bones = rig.data.bones
    points = [v.co for v in basemesh.data.vertices]
    chest = (bones["UpperChest"].head_local + bones["UpperChest"].tail_local) / 2
    hips = bones["Hips"].head_local
    back_y = max(p.y for p in points if abs(p.x) < SLICE and abs(p.z - chest.z) < SLICE)
    # Solo piel de cadera y muslo: en pose A las manos cuelgan a esta altura.
    hip_groups = {basemesh.vertex_groups[name].index for name in HIP_GROUPS}
    side_x = max(v.co.x for v in basemesh.data.vertices
                 if abs(v.co.z - hips.z) < SLICE and any(g.group in hip_groups and g.weight > 0 for g in v.groups))
    return [
        _socket(rig, "socket_hand_r", "RightHand", _palm(bones, "Right")),
        _socket(rig, "socket_hand_l", "LeftHand", _palm(bones, "Left")),
        _socket(rig, "socket_back", "UpperChest", Vector((0.0, back_y + MARGIN, chest.z))),
        _socket(rig, "socket_hip", "Hips", Vector((side_x + MARGIN, hips.y, hips.z))),  # cadera izquierda
    ]


def _palm(bones, side):
    """Centro de la palma, un poco por debajo de la mano."""
    wrist = bones[side + "Hand"].head_local
    knuckle = bones[side + "MiddleProximal"].head_local
    return (wrist + knuckle) / 2 - Vector((0.0, 0.0, MARGIN))


def _socket(rig, name, bone, position):
    socket = bpy.data.objects.new(name, None)
    socket.empty_display_size = 0.05
    rig.users_collection[0].objects.link(socket)
    socket.parent = rig
    socket.parent_type = "BONE"
    socket.parent_bone = bone
    bpy.context.view_layer.update()
    socket.matrix_world = Matrix.Translation(position)
    return socket
