# SPDX-License-Identifier: GPL-3.0-or-later
"""Exporta el personaje a .glb segun las reglas de CLAUDE.md (seccion 6)."""
import bpy

MESH_NAME = "Body"
RIG_NAME = "Armature"


def humanoid_names():
    """{nombre del rig Game engine: nombre en el SkeletonProfileHumanoid de Godot}."""
    names = {
        "Root": "Root", "pelvis": "Hips", "spine_01": "Spine", "spine_02": "Chest",
        "spine_03": "UpperChest", "neck_01": "Neck", "head": "Head",
    }
    fingers = {"thumb": ("Thumb", ("Metacarpal", "Proximal", "Distal")), "pinky": ("Little", None)}
    for suffix, side in (("_l", "Left"), ("_r", "Right")):
        limbs = {"clavicle": "Shoulder", "upperarm": "UpperArm", "lowerarm": "LowerArm", "hand": "Hand",
                 "thigh": "UpperLeg", "calf": "LowerLeg", "foot": "Foot", "ball": "Toes"}
        for old, new in limbs.items():
            names[old + suffix] = side + new
        for finger in ("thumb", "index", "middle", "ring", "pinky"):
            label, parts = fingers.get(finger, (finger.capitalize(), None))
            for number, part in enumerate(parts or ("Proximal", "Intermediate", "Distal"), start=1):
                names[f"{finger}_0{number}{suffix}"] = side + label + part
    return names


def rename_to_humanoid(basemesh):
    """Renombra huesos (Blender renombra solo los grupos de vertices) y los objetos."""
    rig = basemesh.parent
    names = humanoid_names()
    unknown = [bone.name for bone in rig.data.bones if bone.name not in names]
    if unknown:
        raise ValueError(f"Huesos sin nombre humanoide: {unknown}")
    for bone in list(rig.data.bones):
        bone.name = names[bone.name]
    basemesh.name = basemesh.data.name = MESH_NAME
    rig.name = rig.data.name = RIG_NAME


def export_glb(basemesh, sockets, path, morph=False, deform_only=True):
    """Escribe el .glb: Y arriba, mirando a +Z, sin Draco, 4 influencias y el color 'garment'.

    morph: incluye las shape keys como formas. deform_only=False: incluye huesos sin peso (anclajes de datos/).
    """
    bpy.ops.object.select_all(action="DESELECT")
    for obj in (basemesh, basemesh.parent, *sockets):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = basemesh
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_draco_mesh_compression_enable=False,
        export_def_bones=deform_only,
        export_influence_nb=4,
        export_all_influences=False,
        export_animations=False,
        export_morph=morph,
        export_materials="NONE",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_active_vertex_color_when_no_material=True,
    )
