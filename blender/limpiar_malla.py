# SPDX-License-Identifier: GPL-3.0-or-later
"""Deja la malla lista para exportar: formas horneadas, sin malla auxiliar y sin mascaras.

Llamar al final (despues del rig y de la prenda base, que necesitan la malla auxiliar).
"""
import bmesh
from bl_ext.blender_org.mpfb.services import TargetService

SKIN_GROUP = "body"


def clean_mesh(basemesh):
    """Devuelve cuantos vertices quedan (solo piel)."""
    bake_shapes(basemesh)
    remove_masks(basemesh)
    remove_helpers(basemesh)
    remove_non_bone_groups(basemesh)
    return len(basemesh.data.vertices)


def bake_shapes(basemesh):
    """Fija en la malla la mezcla actual de formas y borra las shape keys."""
    if basemesh.data.shape_keys:
        TargetService.bake_targets(basemesh)


def remove_masks(basemesh):
    """Las mascaras solo ocultaban la malla auxiliar; al borrarla de verdad ya sobran."""
    for modifier in [m for m in basemesh.modifiers if m.type == "MASK"]:
        basemesh.modifiers.remove(modifier)


def remove_helpers(basemesh):
    """Borra todo vertice que no sea piel (cubos de articulacion, faldas y pelo de ajuste, ojos, dientes...)."""
    skin = basemesh.vertex_groups[SKIN_GROUP].index
    keep = {v.index for v in basemesh.data.vertices if any(g.group == skin for g in v.groups)}
    mesh = bmesh.new()
    mesh.from_mesh(basemesh.data)
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if v.index not in keep], context="VERTS")
    mesh.to_mesh(basemesh.data)
    mesh.free()
    basemesh.data.update()


def remove_non_bone_groups(basemesh):
    """Solo quedan los grupos de vertices que son huesos del rig."""
    bones = basemesh.parent.data.bones
    for group in [g for g in basemesh.vertex_groups if g.name not in bones]:
        basemesh.vertex_groups.remove(group)
