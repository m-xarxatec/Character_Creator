# SPDX-License-Identifier: GPL-3.0-or-later
"""Pone el rig "Game engine" de MPFB y deja los pesos listos para juegos."""
import bpy
from bl_ext.blender_org.mpfb.services import HumanService

RIG_NAME = "game_engine"
MAX_INFLUENCES = 4


def add_rig(basemesh):
    """Crea el esqueleto ajustado al cuerpo y devuelve el objeto armature."""
    HumanService.add_builtin_rig(basemesh, RIG_NAME, import_weights=True)
    limit_weights(basemesh)
    return basemesh.parent


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
