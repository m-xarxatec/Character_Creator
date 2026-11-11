# SPDX-License-Identifier: GPL-3.0-or-later
"""Maqueta 3.13a-4: ¿la suma de las formas por rasgo a 1 da la cara anime aprobada (una sola forma)?

Mide, en los vertices que mueve alguna de las dos, cuanto se aparta la suma de la aprobada: maximo y media en mm.
Sin limite todavia (se propone con la medida delante).
Uso: (ulimit -v 4000000; timeout 300 blender -b -P pruebas/fase_3/probar_cara_anime.py 2>&1 | grep -E 'medida|RESULTADO')
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "blender"))
import cara_anime as ca  # noqa: E402


def main():
    points, edges, zones = ca.neutral_head()
    total = sum(ca.deform(points, edges, zones, ca.STEPS).values())
    approved = sum(ca.deform(points, edges, zones, ca.APPROVED).values())
    moved = (np.abs(total).max(axis=1) > ca.MIN_DELTA) | (np.abs(approved).max(axis=1) > ca.MIN_DELTA)
    gap = 1000 * np.linalg.norm(total - approved, axis=1)[moved]
    print("medida suma de las formas contra la cara aprobada: máx. %.2f mm / media %.3f mm en %d vértices"
          % (gap.max(), gap.mean(), moved.sum()))
    print("RESULTADO: medido (sin límite aprobado)")


main()
