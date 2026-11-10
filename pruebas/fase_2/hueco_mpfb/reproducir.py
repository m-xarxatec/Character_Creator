# SPDX-License-Identifier: GPL-3.0-or-later
"""Reproducción mínima del hueco de MPFB en la macro "firmness" (solo usa la API de MPFB).

Uso: blender -b -P pruebas/fase_2/hueco_mpfb/reproducir.py

Crea el mismo cuerpo (mujer, pecho al máximo) con varias firmezas junto a 0,5 y mide cuánto se mueve
la punta del pecho derecho (vértice 1877 de la malla base) respecto a firmeza 0,4997.
Se espera un cambio continuo y casi nulo; dentro del hueco (0,4998-0,4999) salta varios centímetros.
"""
import os
import tomllib

import bpy
import bl_ext.blender_org.mpfb as mpfb
from bl_ext.blender_org.mpfb.services import HumanService, TargetService

NIPPLE = 1877  # punta del pecho derecho en la malla base de MakeHuman (hm08)
FIRMNESS = (0.4997, 0.49985, 0.499896, 0.49990, 0.5001)
MACROS = {"gender": 0.0, "cupsize": 1.0}


def nipple(firmness):
    """Posición del vértice con todas las formas aplicadas, y cuántas formas de pecho cargó MPFB."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    macros = TargetService.get_default_macro_info_dict()
    macros.update(MACROS, firmness=firmness)
    basemesh = HumanService.create_human(macro_detail_dict=macros, feet_on_ground=False)
    mix = basemesh.shape_key_add(name="mix", from_mix=True)
    breast = sum(1 for k in basemesh.data.shape_keys.key_blocks if "cup" in k.name and k.value > 0)
    return mix.data[NIPPLE].co.copy(), breast


def mpfb_version():
    with open(os.path.join(os.path.dirname(mpfb.__file__), "blender_manifest.toml"), "rb") as file:
        return tomllib.load(file)["version"]


print(f"HUECO Blender {bpy.app.version_string}, MPFB {mpfb_version()}, macros {MACROS}")
reference, _ = nipple(FIRMNESS[0])
for value in FIRMNESS:
    position, breast = nipple(value)
    print(f"HUECO firmeza {value:.6f}: punta del pecho movida {(position - reference).length * 1000:7.2f} mm,"
          f" formas de pecho cargadas: {breast}")
