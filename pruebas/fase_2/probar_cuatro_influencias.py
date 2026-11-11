# SPDX-License-Identifier: GPL-3.0-or-later
"""Vigila cuánto cambia la malla deformada al recortar los pesos de MPFB a 4 por vértice (regla de CLAUDE.md).

Uso: blender -b -P pruebas/fase_2/probar_cuatro_influencias.py 2>&1 | grep -E 'FALLO|RESULTADO|bien'
Cuerpo «largo» con el tronco girado o doblado 45°: compara los pesos originales de MPFB con los recortados
por blender/poner_rig.py. El paso 2.5 cambiará pesos: esta prueba avisa si el recorte empeora.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import referencia_reajuste as ref  # noqa: E402

MAX_MM = 5.0  # medido: 2,72 / 3,89 / 3,04 mm. Aprobado el 2026-11-11
CHECKED = ("giro de tronco 45° (Spine)", "giro de tronco 45° (Chest)", "tronco hacia delante 45° (Chest)")
failures = []

rows = ref.ed.read_sliders(ref.DATA)
measure = ref.four_weights_measure(ref.bodies(rows)["largo"], rows)
print(f"  {measure['over_four']} de {measure['vertices']} vértices tenían más de 4 influencias (hasta {measure['most']})")
for label, pose in measure["poses"].items():
    checked = label in CHECKED
    ok = not checked or pose["max_mm"] < MAX_MM
    limit = f" (< {MAX_MM} mm)" if checked else " (informativo)"
    print(("  bien  " if ok else "  FALLO ") + label + limit,
          f"máximo {pose['max_mm']:.3f} mm, media {pose['mean_mm']:.4f} mm, {pose['over_0_1_mm']} vértices > 0,1 mm")
    if not ok:
        failures.append(label)
print(f"RESULTADO: {len(failures)} fallos" + (f" ({', '.join(failures)})" if failures else ""))
sys.exit(1 if failures else 0)
