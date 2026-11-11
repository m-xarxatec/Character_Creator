# SPDX-License-Identifier: GPL-3.0-or-later
"""Maqueta 3.13a-4: cara anime deformando la cabeza neutra de MakeHuman (mismos vertices), con una forma por rasgo.

Uso: blender -b -P blender/cara_anime.py -- pruebas/fase_3/salida/cara_anime/cara_anime.json
Escribe cada forma (desplazamiento de cada vertice movido, ejes de Godot, metros) y los puntos fijos (ojos, nariz).
Formas: cuenca_plana, boca_anime, mandibula_anime, menton_anime y nariz_anime. Preset «cara anime»: todas a 1, salvo
nariz_anime a 0 (nariz de MakeHuman). Salida determinista y CC0 (ver README.md).
Prueba: pruebas/fase_3/probar_cara_anime.py (la suma de las formas da la cara aprobada en la 3.13a-4).

Zonas: blender/cara_anime_zonas.json, listas de indices de vertice de la malla base de MakeHuman, elegidas una vez
sobre la cabeza neutra: los vertices que mueven los targets CC0 de MakeHuman de cada rasgo (nose, mouth, eyes, chin,
eyebrows; mas de un 15 % de su maximo), solo en la cabeza, con su simetrico y con las bolsas interiores de ojos y boca.
Tambien los puntos fijos: eye_anchor_l/r, nose_tip, nose_ring (borde de la nariz) y chin_tip.

Como deforma:
- relajar: cada vertice de la zona va a la media de sus vecinos, con el borde fijo, hasta quedar como una membrana
  tensa; `keep` devuelve una parte del relieve original. Asi se aplanan las cuencas, la nariz y los labios.
  Con pocas pasadas solo suaviza (cejas, y el escalon entre nariz y boca).
- mandibula / menton: de la boca hacia abajo, estrecha la mandibula (X) y sube el menton (Z), con caida suave.
Cada forma es lo que mueven sus pasos, aplicados en el orden de STEPS sobre el resultado del anterior: la suma de
todas a 1 da la cara entera. La nariz va la ultima, para que nariz_anime = 0 deje la nariz sin escalones.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import exportar_datos as ed  # noqa: E402

ZONES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cara_anime_zonas.json")
FULL = 3000  # pasadas para llegar a la membrana
# (forma, zona o paso, pasadas, parte del relieve que se conserva), en este orden; "a+b" = las dos zonas juntas
STEPS = (("cuenca_plana", "eyes", FULL, 0.0), ("cuenca_plana", "brow", 3, 0.0), ("boca_anime", "mouth", FULL, 0.4),
         ("mandibula_anime", "jaw", 0, 0.0), ("menton_anime", "chin", 0, 0.0),
         ("nariz_anime", "nose", FULL, 0.3), ("nariz_anime", "nose+mouth", 3, 0.0))
# La cara aprobada en la 3.13a-4 (una sola forma, otro orden): solo para la prueba de la suma.
APPROVED = tuple(("cara", *step) for step in (("eyes", FULL, 0.0), ("nose", FULL, 0.3), ("mouth", FULL, 0.4),
                                              ("brow", 3, 0.0), ("nose+mouth", 3, 0.0), ("jaw", 0, 0.0), ("chin", 0, 0.0)))
JAW_NARROW = 0.25  # cuanto se estrecha la mandibula a la altura del menton
CHIN_SHORTEN = 0.25  # cuanto sube el menton, en partes de la distancia boca-menton
FALLOFF_STEPS = 8
MIN_DELTA = 1e-6  # metros


def relax(points, edges, mask, steps, keep):
    """Membrana: los vertices de mask van a la media de sus vecinos (el resto no se mueve)."""
    a, b = edges[mask[edges[:, 0]] | mask[edges[:, 1]]].T
    count = np.bincount(a, minlength=len(points)) + np.bincount(b, minlength=len(points))
    moved = points.copy()
    for _ in range(steps):
        total = np.zeros_like(moved)
        for axis in range(3):
            total[:, axis] = (np.bincount(a, weights=moved[b, axis], minlength=len(points))
                              + np.bincount(b, weights=moved[a, axis], minlength=len(points)))
        moved[mask] = total[mask] / count[mask][:, None]
    return moved + keep * (points - moved)


def falloff(mask, edges, steps):
    """Peso de 0 a 1: la zona, con el borde difuminado por la malla."""
    a, b = edges.T
    count = np.bincount(a, minlength=len(mask)) + np.bincount(b, minlength=len(mask))
    weight = mask.astype(float)
    for _ in range(steps):
        total = np.bincount(a, weights=weight[b], minlength=len(mask)) + np.bincount(b, weights=weight[a], minlength=len(mask))
        weight = (weight + total) / (count + 1)
    return weight


def deform(points, edges, zones, steps):
    """Aplica los pasos [(nombre, zona, pasadas, relieve)] en orden: {nombre: desplazamiento sumado de sus pasos}.
    Ejes de Blender: X a los lados, Z arriba."""
    masks = {name: np.isin(np.arange(len(points)), zones[name]) for name in ("eyes", "nose", "mouth", "brow", "chin")}
    mouth_z = points[masks["mouth"], 2].mean()
    chin_z = points[zones["chin_tip"], 2]
    weight = falloff(masks["chin"], edges, FALLOFF_STEPS)
    moved = points.copy()
    down = None
    deltas = {}
    for name, zone, passes, keep in steps:
        before = moved.copy()
        if zone == "jaw":  # el menton usa el mismo «down»: separar X y Z no cambia el resultado
            down = np.clip((mouth_z - moved[:, 2]) / (mouth_z - chin_z), 0.0, 1.0) * weight
            moved[:, 0] *= 1.0 - JAW_NARROW * down
        elif zone == "chin":
            moved[:, 2] += CHIN_SHORTEN * (mouth_z - chin_z) * down
        else:
            mask = np.any([masks[z] for z in zone.split("+")], axis=0)
            moved = relax(moved, edges, mask, passes, keep)
        deltas[name] = deltas.get(name, 0.0) + (moved - before)
    return deltas


def neutral_head():
    """(puntos de la malla neutra en ejes de Blender, aristas ordenadas, zonas)."""
    with open(ZONES, encoding="utf-8") as file:
        zones = json.load(file)
    basemesh, _ = ed.build_base()
    world = np.array(basemesh.matrix_world)
    points = np.array([v.co[:] for v in basemesh.data.vertices]) @ world[:3, :3].T + world[:3, 3]
    edges = np.array(sorted(tuple(sorted(e.vertices[:])) for e in basemesh.data.edges))
    return points, edges, zones


def main():
    out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
    points, edges, zones = neutral_head()
    deltas = deform(points, edges, zones, STEPS)
    shapes = {name: [[int(i)] + ed.godot(points[i]) + ed.godot(delta[i])
                     for i in np.flatnonzero(np.abs(delta).max(axis=1) > MIN_DELTA)] for name, delta in deltas.items()}
    data = {"version": 3, "vertex_count": len(points), "shapes": shapes,
            "preset": {name: (0.0 if name == "nariz_anime" else 1.0) for name in shapes},
            "points": {name: ed.godot(points[zones[name]]) for name in ("eye_anchor_l", "eye_anchor_r", "nose_tip")},
            "nose_ring": [ed.godot(points[i]) for i in zones["nose_ring"]]}
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as file:
        json.dump(data, file, sort_keys=True, separators=(",", ":"))
        file.write("\n")
    for name, delta in deltas.items():
        print("GUARDADO: %s (%d vertices movidos; max. %.1f mm)"
              % (name, len(shapes[name]), 1000 * np.linalg.norm(delta, axis=1).max()))


if __name__ == "__main__":
    main()
