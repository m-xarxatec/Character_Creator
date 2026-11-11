# SPDX-License-Identifier: GPL-3.0-or-later
"""Pone el rig "Game engine" de MPFB y deja los pesos listos para juegos."""
import bpy
from bl_ext.blender_org.mpfb.services import HumanService

RIG_NAME = "game_engine"
MAX_INFLUENCES = 4
CROSS_MIN_X = 0.05  # metros: mas lejos del centro, un vertice no lleva pesos de huesos del otro lado


def add_rig(basemesh):
    """Crea el esqueleto ajustado al cuerpo y devuelve el objeto armature."""
    HumanService.add_builtin_rig(basemesh, RIG_NAME, import_weights=True)
    remove_cross_weights(basemesh)
    limit_weights(basemesh)
    return basemesh.parent


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
