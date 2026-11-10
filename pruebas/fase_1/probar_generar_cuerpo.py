# SPDX-License-Identifier: GPL-3.0-or-later
"""Pruebas del paso 1.1. Uso: blender -b -P pruebas/fase_1/probar_generar_cuerpo.py"""
import glob
import os
import sys

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import generar_cuerpo as gc  # noqa: E402

failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def build(raw):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return gc.measure(gc.create_body(gc.validate_spec(raw)))


def rejected(raw):
    try:
        gc.validate_spec(raw)
    except gc.BodyError:
        return True
    return False


print("Los 5 cuerpos de ejemplo")
for path in sorted(glob.glob(os.path.join(ROOT, "pruebas", "fase_1", "cuerpos", "*.json"))):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    m = gc.measure(gc.create_body(gc.load_spec(path)))
    ok = abs(m["lowest"]) < 0.001 and 1.2 < m["height"] < 2.4
    check(os.path.basename(path), ok, f"altura {m['height']:.3f} m, pies en {m['lowest']:.4f}")

print("Los valores cambian el cuerpo como se espera")
neutral = build({"version": 1})
check("neutro mide ~1,66 m", abs(neutral["height"] - 1.659) < 0.01, f"{neutral['height']:.3f}")
check("mismo JSON, mismo cuerpo", build({"version": 1}) == neutral)
check("height sube la altura", build({"version": 1, "macros": {"height": 0.9}})["height"] > neutral["height"] + 0.05)
# El fondo de la caja lo marcan sobre todo manos y pies, por eso el cambio con el peso es pequeno.
thin = build({"version": 1, "macros": {"weight": 0.0}})
heavy = build({"version": 1, "macros": {"weight": 1.0}})
check("weight sube el fondo", thin["depth"] < neutral["depth"] < heavy["depth"], f"{thin['depth']:.3f} < {neutral['depth']:.3f} < {heavy['depth']:.3f}")
legs = build({"version": 1, "targets": {"lowerlegs-height-incr": 1.0}})
check("target de piernas sube la altura", legs["height"] > neutral["height"] + 0.01, f"{legs['height']:.3f}")
check("y los pies siguen en el suelo", abs(legs["lowest"]) < 0.001, f"{legs['lowest']:.4f}")
check("target a 0 no cambia nada", abs(build({"version": 1, "targets": {"lowerlegs-height-incr": 0.0}})["height"] - neutral["height"]) < 1e-5)

print("Los JSON malos se rechazan")
check("sin version", rejected({}))
check("version futura", rejected({"version": 2}))
check("clave desconocida", rejected({"version": 1, "ropa": {}}))
check("macro desconocida", rejected({"version": 1, "macros": {"altura": 0.5}}))
check("valor fuera de 0..1", rejected({"version": 1, "macros": {"height": 1.5}}))
check("valor que no es numero", rejected({"version": 1, "macros": {"height": "alto"}}))
check("edad menor que adulto", rejected({"version": 1, "macros": {"age": 0.3}}))
check("target inventado", rejected({"version": 1, "targets": {"no-existe": 0.5}}))
check("target por prefijo", rejected({"version": 1, "targets": {"hip-scale": 0.5}}))
check("target de genitales", rejected({"version": 1, "targets": {"penis-length-incr": 0.5}}))
check("otra especie", rejected({"version": 1, "species": "dragon"}))
snapped = gc.validate_spec({"version": 1, "macros": {"firmness": 0.49985, "muscle": 0.4997}})["macros"]
check("firmeza en el hueco de MPFB pasa a 0,5", snapped["firmness"] == 0.5, snapped["firmness"])
check("fuera del hueco no se toca", snapped["muscle"] == 0.4997, snapped["muscle"])

print("RESULTADO:", "TODO BIEN" if not failures else f"{len(failures)} FALLOS: {failures}")
sys.exit(1 if failures else 0)
