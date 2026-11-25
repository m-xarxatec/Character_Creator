# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso AC.3b.1: la forma del ojo anime, medida sobre el cuerpo.glb exportado (no sobre el calculo).

Comprueba: 13.380 vertices y 13.378 caras; simetria; 0 cruces y 0 invertidos en reposo y en los 10 extremos; la bolsa
detras de la membrana del lazo; nada se mueve fuera de cabeza y cuello; articulaciones.json identico; indices de ojos.json.
AC.6c.1: cuerpo.glb identico; banda de la ceja (480 puntos apoyados, simetria) y ojos.json igual en lo de antes.
Rotura: en cara_anime._brows, el ojo derecho sin reflejar el lado (side) -> falla la simetria de la ceja.
Uso: (ulimit -v 4000000; timeout 900 blender -b -P pruebas/fase_3/probar_forma_ojo.py 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO')
Sobre otra carpeta de datos: ... -P pruebas/fase_3/probar_forma_ojo.py -- <carpeta de la especie>
"""
import hashlib
import json
import os
import sys

import numpy as np
from mathutils import kdtree
from mathutils.bvhtree import BVHTree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import cara_anime as ca  # noqa: E402
import exportar_datos as ed  # noqa: E402

VERTICES, FACES = 13380, 13378
GLB_VERTICES = 14517
BAG_TRIANGLES, BAG_GLB = 730, 412
MAX_ASYMMETRY_MM = 0.5
MAX_OUTSIDE_MM = 0.5
MAX_INDEX_MM = 0.01
JOINTS_SHA256 = "cb4088677a396768390123d7fea94c0b10a7d3ee77afab7adcb6881195c9cdfc"  # articulaciones.json de AC.3 (las formas de ojo no mueven huesos)
EYES = ("eye_size", "eye_spacing", "eye_position", "eye_tall", "eye_corner")
# AC.6c.1: la banda de la ceja no cambia nada de antes
BODY_SHA256 = "b89bd2f437f90fb5d4d68b0c64b8e82c3b241da2341220c0d2401318b54ab805"  # cuerpo.glb de AC.6b
EYES_OLD_SHA256 = "d66ac57510abde5471367fb9c8b35f699a1af82a613b57bd97e9b7697d355ffa"  # ojos.json de AC.6b (sin "ceja")
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def crossed(points, tris):
    tree = BVHTree.FromPolygons([tuple(p) for p in points], [tuple(int(i) for i in t) for t in tris], all_triangles=True)
    found = set()
    for i, j in tree.overlap(tree):
        if i < j and not set(tris[i].tolist()) & set(tris[j].tolist()):
            found.update((i, j))
    return len(found)


def face_normals(points, tris):
    a, b, c = points[tris[:, 0]], points[tris[:, 1]], points[tris[:, 2]]
    return np.cross(b - a, c - a)


class Counter:
    """Cruces e invertidos respecto al reposo, con los triangulos de MakeHuman y con los del .glb."""

    def __init__(self, anime, sets):
        self.sets = sets
        self.start = [face_normals(anime, t) for t in sets]

    def row(self, points):
        total = [0, 0]
        for tris, start in zip(self.sets, self.start):
            valid = np.linalg.norm(start, axis=1) > 1e-12
            total[0] += crossed(points, tris)
            total[1] += int((((face_normals(points, tris) * start).sum(1) < 0) & valid).sum())
        return total


def read_glb(fit, folder):
    """(reposo, {forma: desplazamiento}, posiciones del .glb, indices) en el orden de los vertices de Blender."""
    path = os.path.join(folder, "cuerpo.glb")
    gltf, rest = ed._glb_parts(path)
    data = rest[8:]
    mesh = gltf["meshes"][0]
    primitive = mesh["primitives"][0]
    names = mesh["extras"]["targetNames"]
    base = ca._accessor(gltf, data, primitive["attributes"]["POSITION"]).astype(float)
    tree = kdtree.KDTree(len(base))
    for i, q in enumerate(base):
        tree.insert(q, i)
    tree.balance()
    first = np.array([tree.find(q)[1] for q in ca.to_godot(fit.points)])
    read = lambda name: ca.from_godot(ca._accessor(gltf, data, primitive["targets"][names.index(name)]["POSITION"]).astype(float)[first])
    anime = fit.points + sum(read(n) for n in ca.PRESET_FACE)
    deltas = {f"{e}_{d}": read(f"{e}_{d}") for e in EYES for d in ("decr", "incr")}
    return anime, deltas, base, ca._accessor(gltf, data, primitive["indices"]).ravel(), gltf, data, primitive, names


def check_eyes_file(fit, folder, anime_glb, indices):
    with open(os.path.join(folder, "ojos.json"), encoding="utf-8") as file:
        eyes = json.load(file)
    check("ojos.json version 1", eyes.get("version") == 1)
    loops = {"l": fit.left.loop, "r": fit.right_loop()}
    worst = 0.0
    for side in "lr":
        eye = eyes[side]
        check(f"lazo {side}: 36 indices", len(eye["lazo"]) == 36)
        wanted = ca.to_godot(fit.anime[loops[side]])
        worst = max(worst, float(np.linalg.norm(anime_glb[eye["lazo"]] - wanted, axis=1).max()) * 1000)
        check(f"bolsa {side}: {BAG_GLB} vertices del .glb", len(eye["bolsa"]) == BAG_GLB, str(len(eye["bolsa"])))
        check(f"uv, altura y elevacion {side} van con la bolsa", len(eye["uv"]) == len(eye["bolsa"]) == len(eye["altura"]) == len(eye["elevacion"]))
        inside = np.isin(indices.reshape(-1, 3), eye["bolsa"]).all(1)
        check(f"bolsa {side}: {BAG_TRIANGLES} triangulos", int(inside.sum()) == BAG_TRIANGLES, str(int(inside.sum())))
    print("MEDIDA lazo de ojos.json frente al calculo: %.4f mm" % worst)
    check("los indices de ojos.json caen en el lazo", worst <= MAX_INDEX_MM, "%.4f mm" % worst)
    check_brows(fit, eyes, anime_glb)


def check_brows(fit, eyes, anime_glb):
    """AC.6c.1: banda de la ceja apoyada, simetrica y sin cambiar las claves de antes de ojos.json."""
    old = {k: ({kk: vv for kk, vv in v.items() if kk != "ceja"} if k in "lr" else v) for k, v in eyes.items()}
    text = (json.dumps(old, sort_keys=True, separators=(",", ":")) + "\n").encode()
    check("ojos.json: las claves de antes no cambian", hashlib.sha256(text).hexdigest() == EYES_OLD_SHA256)
    points = {}
    for side in "lr":
        band = eyes[side].get("ceja")
        check(f"ceja {side}: existe", band is not None)
        if band is None:
            return
        count = ca.BROW_COLUMNS * ca.BROW_ROWS
        ids, bary, offset = np.array(band["ids"]), np.array(band["bary"]), np.array(band["offset"])
        check(f"ceja {side}: {count} vertices, {ca.BROW_ROWS} filas", len(ids) == len(bary) == len(offset)
              == len(band["uv"]) == count and band["filas"] == ca.BROW_ROWS, str(len(ids)))
        check(f"ceja {side}: indices del .glb", int(ids.min()) >= 0 and int(ids.max()) < GLB_VERTICES)
        apoyados = int((ids[:, 0] != ids[:, 1]).sum())  # sin piel, el indice saldria repetido (tira recta)
        check(f"ceja {side}: todos los puntos apoyados en la piel", apoyados == count, f"{apoyados} de {count}")
        check(f"ceja {side}: baricentricas de 0 a 1 que suman 1", float(bary.min()) >= -1e-6
              and float(np.abs(bary.sum(1) - 1.0).max()) <= 1e-5)
        lift = float(np.linalg.norm(offset, axis=1).max()) * 1000
        check(f"ceja {side}: elevacion {ca.STRIP_LIFT * 1000:.2f} mm", abs(lift - ca.STRIP_LIFT * 1000) <= 0.001,
              "%.4f mm" % lift)
        points[side] = (anime_glb[ids] * bary[:, :, None]).sum(1) + offset
        print("MEDIDA ceja %s: %.1f mm de ancho" % (side, band["largo"] * 1000))
    asym = float(np.linalg.norm(points["l"] - points["r"] * ca.FLIP, axis=1).max()) * 1000
    print("MEDIDA simetria de la ceja: %.4f mm" % asym)
    check("ceja: simetria", asym <= MAX_ASYMMETRY_MM, "%.4f mm" % asym)
    brow = ca.to_godot(fit.anime[fit.zones["brow"]])  # la zona brow, solo como medida (ficha AC.6c 5.2)
    for side in "lr":
        eye = eyes[side]
        rim = np.array(eye["lazo"])
        center = anime_glb[rim].mean(0)
        frame = ca.brow_frame(anime_glb, rim, eye["arco_superior"], center, np.array(eye["normal"]))
        mine = brow[np.sign(brow[:, 0]) == np.sign(center[0])] - center
        s, h = mine @ frame[0], mine @ frame[1]
        print("MEDIDA zona brow %s en la caja de la banda: lado %.1f a %.1f mm (banda %.1f a %.1f), arriba %.1f a %.1f mm "
              "(banda %.1f a %.1f)" % (side, s.min() * 1000, s.max() * 1000, frame[2][0] * 1000, frame[2][1] * 1000,
                                       h.min() * 1000, h.max() * 1000, frame[3][0] * 1000, frame[3][1] * 1000))


def main():
    folder = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.path.join(ROOT, "godot", "datos", "humana")
    basemesh = ed.build_base()[0]
    check("vertices de la malla", len(basemesh.data.vertices) == VERTICES, str(len(basemesh.data.vertices)))
    check("caras de la malla", len(basemesh.data.polygons) == FACES, str(len(basemesh.data.polygons)))
    fit = ca.EyeFit(basemesh)
    anime, deltas, base, indices, gltf, data, primitive, names = read_glb(fit, folder)
    check("vertices del .glb", len(base) == GLB_VERTICES, str(len(base)))
    check("TEXCOORD_1 en el .glb", "TEXCOORD_1" in primitive["attributes"])
    glb_anime = base.copy()
    for name in ca.PRESET_FACE:
        glb_anime = glb_anime + ca._accessor(gltf, data, primitive["targets"][names.index(name)]["POSITION"])
    check_eyes_file(fit, folder, glb_anime, indices)
    basemesh.data.calc_loop_triangles()
    tess = np.array([t.vertices[:] for t in basemesh.data.loop_triangles])
    tess = tess[fit.in_head[tess].any(1)]
    counter = Counter(anime, (fit.head, tess))
    states = {"reposo": anime}
    states.update({name: anime + delta for name, delta in deltas.items()})
    worst_cross, worst_flip = 0, 0
    free, border, matrix = fit.left.bag_op
    gap = np.inf
    for name, points in states.items():
        cross, flip = counter.row(points)
        worst_cross, worst_flip = max(worst_cross, cross), max(worst_flip, flip)
        g = ca.to_godot(points)
        gaps = [(matrix @ g[border, 2] - g[free, 2]).min(), (matrix @ g[fit.mirror[border], 2] - g[fit.mirror[free], 2]).min()]
        gap = min(gap, float(min(gaps)) * 1000)
        check(f"{name}: 0 cruces y 0 invertidos", cross == 0 and flip == 0, f"{cross} / {flip}")
    dirty = 0  # dos deslizadores a la vez, en sus extremos: se mide, sin limite (ficha 5.3)
    names = list(deltas)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if a.rsplit("_", 1)[0] != b.rsplit("_", 1)[0] and counter.row(anime + deltas[a] + deltas[b]) != [0, 0]:
                dirty += 1
    print("MEDIDA parejas de deslizadores con cruces o invertidos: %d de 40" % dirty)
    print("MEDIDA holgura bolsa-membrana: %.3f mm" % gap)
    check("bolsa detras de la membrana", gap >= 0.0, "%.3f mm" % gap)
    asym = max(float(np.linalg.norm(d - d[fit.mirror] * ca.FLIP, axis=1).max()) for d in list(deltas.values()) + [anime - anime[fit.mirror] * ca.FLIP]) * 1000
    print("MEDIDA simetria: %.4f mm" % asym)
    check("simetria", asym <= MAX_ASYMMETRY_MM, "%.4f mm" % asym)
    legacy = fit.points + sum(v for k, v in ca.deform(fit.points, fit.edges, fit.zones, ca.STEPS).items() if k in ca.PRESET_FACE)
    outside = max([float(np.linalg.norm(d[~fit.in_head], axis=1).max()) for d in deltas.values()] + [float(np.linalg.norm((anime - legacy)[~fit.in_head], axis=1).max())]) * 1000
    print("MEDIDA fuera de cabeza y cuello: %.4f mm" % outside)
    check("fuera de cabeza y cuello", outside <= MAX_OUTSIDE_MM, "%.4f mm" % outside)
    with open(os.path.join(folder, "articulaciones.json"), "rb") as file:
        check("articulaciones.json identico", hashlib.sha256(file.read()).hexdigest() == JOINTS_SHA256)
    with open(os.path.join(folder, "cuerpo.glb"), "rb") as file:
        check("cuerpo.glb identico (AC.6c.1)", hashlib.sha256(file.read()).hexdigest() == BODY_SHA256)
    print("RESULTADO:", "TODO BIEN" if not failures else f"{len(failures)} FALLOS")


try:
    main()
except Exception as error:  # noqa: BLE001
    import traceback
    traceback.print_exc()
    failures.append(str(error))
    print("  FALLO", error)
    print("RESULTADO: 1 FALLOS")
sys.exit(1 if failures else 0)
