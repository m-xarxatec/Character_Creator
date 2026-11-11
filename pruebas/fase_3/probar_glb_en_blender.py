# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso 3.6.5: los .glb exportados por el núcleo de Godot se abren bien en Blender.

Uso: (ulimit -v 4000000; timeout 300 blender -b -P pruebas/fase_3/probar_glb_en_blender.py 2>&1 | grep -E 'FALLO|RESULTADO|bien')
Antes: pruebas/godot/probar_exportar.gd (escribe pruebas/fase_3/salida/t/ y a/).
"""
import glob
import os
import sys

import bpy

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "salida")
SOCKETS = {"socket_hand_r": "RightHand", "socket_hand_l": "LeftHand", "socket_back": "UpperChest", "socket_hip": "Hips"}
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def check_file(path):
    label = os.path.relpath(path, OUT) + ": "
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        result = bpy.ops.import_scene.gltf(filepath=path)
    except Exception as error:  # noqa: BLE001 - cualquier fallo del importador es un fallo de la prueba
        check(label + "se abre sin errores", False, str(error))
        return
    check(label + "se abre sin errores", result == {"FINISHED"}, result)
    rigs = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    # El importador de Blender añade una esfera para dibujar los huesos, en la colección glTF_not_exported.
    meshes = [o for o in bpy.data.objects if o.type == "MESH"
              and not any(c.name == "glTF_not_exported" for c in o.users_collection)]
    check(label + "un esqueleto con 53 huesos", len(rigs) == 1 and len(rigs[0].data.bones) == 53,
          [len(r.data.bones) for r in rigs])
    sockets = {o.name: o for o in bpy.data.objects if o.name.startswith("socket_")}
    hung = all(name in sockets and sockets[name].type == "EMPTY" and sockets[name].parent_type == "BONE"
               and sockets[name].parent_bone == bone for name, bone in SOCKETS.items())
    check(label + "4 vacíos socket_… hijos de su hueso", len(sockets) == 4 and hung,
          {n: (o.type, o.parent_bone) for n, o in sockets.items()})
    check(label + "una malla", len(meshes) == 1, len(meshes))
    if len(meshes) != 1 or len(rigs) != 1:
        return
    mesh = meshes[0]
    bones = set(rigs[0].data.bones.keys())
    most = max(sum(1 for g in v.groups if g.weight > 0 and mesh.vertex_groups[g.group].name in bones)
               for v in mesh.data.vertices)
    check(label + "sin formas, con color por vértice y máximo 4 influencias",
          mesh.data.shape_keys is None and len(mesh.data.color_attributes) >= 1 and most <= 4,
          f"{len(mesh.data.vertices)} vértices, {len(mesh.data.color_attributes)} colores, {most} influencias")


files = sorted(glob.glob(os.path.join(OUT, "t", "*.glb")) + glob.glob(os.path.join(OUT, "a", "*.glb")))
check("hay 4 .glb que probar", len(files) == 4, len(files))
for file in files:
    check_file(file)
print(f"RESULTADO: {len(failures)} fallos" + (f" ({', '.join(failures)})" if failures else ""))
sys.exit(1 if failures else 0)
