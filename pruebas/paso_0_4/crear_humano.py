"""Paso 0.4: crea un humano con MPFB, le pone el rig Game engine y lo exporta a .glb.

Uso: blender -b -P pruebas/paso_0_4/crear_humano.py -- salida.glb
"""
import sys

import bpy
from bl_ext.blender_org.mpfb.services import HumanService

out_path = sys.argv[sys.argv.index("--") + 1]

# Escena vacía: fuera el cubo, la cámara y la luz por defecto.
bpy.ops.wm.read_factory_settings(use_empty=True)

basemesh = HumanService.create_human()  # escala 0.1 = metros
HumanService.add_builtin_rig(basemesh, "game_engine", import_weights=True)

rig = basemesh.parent
print("RIG:", rig.name, "huesos:", len(rig.data.bones))
print("HUESOS:", ",".join(b.name for b in rig.data.bones))

bpy.ops.export_scene.gltf(
    filepath=out_path,
    export_format="GLB",
    export_apply=True,       # aplica las máscaras que ocultan la malla auxiliar
    export_yup=True,         # Y hacia arriba, como Godot
    export_animations=False,
    export_draco_mesh_compression_enable=False,
)
print("EXPORTADO:", out_path)
