# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso 9.7.1: formas de expresion (expr_*) de cuerpo.glb, medidas sobre el .glb exportado.

Comprueba: las 6 expresiones y las 8 correcciones del parpadeo, al final de las formas; con -- <carpeta de antes>, que
las formas de antes, la malla, articulaciones.json y ojos.json son identicos; simetria (blinkLeft contra el reflejo de
blinkRight); 0 cruces y 0 invertidos en la cabeza con cada expresion a 1 en la cara anime, y con el parpadeo tambien en
los extremos de Ojos › Alto y Tamano (con sus correcciones). MEDIDA: hueco entre los arcos del lazo al parpadear.
Uso: (ulimit -v 4000000; timeout 900 blender -b -P pruebas/fase_3/probar_expresiones.py -- <copia de godot/datos/humana de antes> 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO')
Rotura: en blender/expresiones.py, sin fp.symmetric (falla la simetria); sin las correcciones (el ojo no cierra en los
extremos: lo mide el hueco, y lo comprueba probar_expresiones.gd).
"""
import hashlib
import os
import sys

import numpy as np
from mathutils import kdtree
from mathutils.bvhtree import BVHTree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import cara_anime as ca  # noqa: E402
import exportar_datos as ed  # noqa: E402
import expresiones as ex  # noqa: E402

FOLDER = os.path.join(ROOT, "godot", "datos", "humana")
EXPRESSIONS = ["happy", "angry", "sad", "surprised", "blinkLeft", "blinkRight"]
FIXES = ["%s%s*%s" % (ex.PREFIX, b, f) for b in ex.BLINKS for f in ex.BLINK_FIXES]
MAX_ASYMMETRY_MM = 0.5
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


def inverted(points, tris, start):
    a, b, c = points[tris[:, 0]], points[tris[:, 1]], points[tris[:, 2]]
    now = np.cross(b - a, c - a)
    return int((((now * start).sum(1) < 0) & (np.linalg.norm(start, axis=1) > 1e-12)).sum())


def glb(folder):
    gltf, rest = ed._glb_parts(os.path.join(folder, "cuerpo.glb"))
    return gltf, rest[8:], gltf["meshes"][0]["primitives"][0], gltf["meshes"][0]["extras"]["targetNames"]


def accessor_bytes(gltf, data, index):
    return ca._accessor(gltf, data, index).tobytes()


def same_file(a, b):
    with open(a, "rb") as fa, open(b, "rb") as fb:
        return hashlib.sha256(fa.read()).digest() == hashlib.sha256(fb.read()).digest()


def check_before(before):
    gltf, data, primitive, names = glb(FOLDER)
    old_gltf, old_data, old_primitive, old_names = glb(before)
    check("las formas de antes siguen en su sitio", names[:len(old_names)] == old_names, "%d antes" % len(old_names))
    check("las nuevas son solo expr_*", all(n.startswith(ex.PREFIX) for n in names[len(old_names):]))
    same = all(accessor_bytes(gltf, data, primitive["targets"][i]["POSITION"])
               == accessor_bytes(old_gltf, old_data, old_primitive["targets"][i]["POSITION"]) for i in range(len(old_names)))
    check("las formas de antes, identicas (POSITION)", same)
    attributes = all(accessor_bytes(gltf, data, primitive["attributes"][k]) == accessor_bytes(old_gltf, old_data, old_primitive["attributes"][k])
                     for k in old_primitive["attributes"])
    check("la malla, identica (atributos)", attributes and accessor_bytes(gltf, data, primitive["indices"])
          == accessor_bytes(old_gltf, old_data, old_primitive["indices"]))
    for name in ("articulaciones.json", "ojos.json"):
        check(name + " identico", same_file(os.path.join(FOLDER, name), os.path.join(before, name)))


def main():
    before = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else None
    gltf, data, primitive, names = glb(FOLDER)
    wanted = [ex.PREFIX + e for e in EXPRESSIONS] + FIXES
    check("%d formas de expresion, al final" % len(wanted), names[-len(wanted):] == wanted, str([n for n in names if n.startswith(ex.PREFIX)]))
    if before:
        check_before(before)
    else:
        print("  (sin carpeta de antes: no se comparan las formas de antes ni los .json)")
    basemesh = ed.build_base()[0]
    fit = ca.EyeFit(basemesh)
    base = ca._accessor(gltf, data, primitive["attributes"]["POSITION"]).astype(float)
    tree = kdtree.KDTree(len(base))
    for i, q in enumerate(base):
        tree.insert(q, i)
    tree.balance()
    first = np.array([tree.find(q)[1] for q in ca.to_godot(fit.points)])

    def read(name):
        return ca.from_godot(ca._accessor(gltf, data, primitive["targets"][names.index(name)]["POSITION"]).astype(float)[first])

    anime = fit.points + sum(read(n) for n in ca.PRESET_FACE)
    basemesh.data.calc_loop_triangles()
    tess = np.array([t.vertices[:] for t in basemesh.data.loop_triangles])
    tess = tess[fit.in_head[tess].any(1)]
    a, b, c = anime[tess[:, 0]], anime[tess[:, 1]], anime[tess[:, 2]]
    start = np.cross(b - a, c - a)
    rest_cross = crossed(anime, tess)
    deltas = {n: read(n) for n in wanted}

    for e in EXPRESSIONS[:4]:
        d = deltas[ex.PREFIX + e]
        asym = float(np.linalg.norm(d - d[fit.mirror] * ca.FLIP, axis=1).max()) * 1000
        check("%s: simetrica" % e, asym <= MAX_ASYMMETRY_MM, "%.4f mm" % asym)
    left, right = deltas[ex.PREFIX + "blinkLeft"], deltas[ex.PREFIX + "blinkRight"]
    asym = float(np.linalg.norm(left - right[fit.mirror] * ca.FLIP, axis=1).max()) * 1000
    check("blinkLeft es el reflejo de blinkRight", asym <= MAX_ASYMMETRY_MM, "%.4f mm" % asym)

    states = {e: anime + deltas[ex.PREFIX + e] for e in EXPRESSIONS}
    blink = deltas[ex.PREFIX + "blinkLeft"] + deltas[ex.PREFIX + "blinkRight"]
    states["blink"] = anime + blink
    for fix in ex.BLINK_FIXES:
        slider = read(fix)
        fixes = sum(deltas["%s%s*%s" % (ex.PREFIX, b, fix)] for b in ex.BLINKS)
        states["blink + " + fix] = anime + slider + blink + fixes
        states[fix + " (sin parpadeo)"] = anime + slider
    for name, points in states.items():
        cross = max(0, crossed(points, tess) - rest_cross)
        flip = inverted(points, tess, start)
        check("%s: 0 cruces nuevos y 0 invertidos" % name, cross == 0 and flip == 0, "%d / %d" % (cross, flip))
        if name.startswith("blink"):
            print("MEDIDA %s: hueco entre los arcos del lazo %.3f mm" % (name, gap(fit, points) * 1000))
    print("RESULTADO:", "TODO BIEN" if not failures else "%d FALLOS" % len(failures))


def gap(fit, points):
    """Mayor distancia de un punto del arco de arriba del lazo (sin las esquinas) al arco de abajo, en los dos ojos."""
    worst = 0.0
    for side in (None, fit.mirror):
        loop = np.array(fit.left.loop) if side is None else side[np.array(fit.left.loop)]
        p = points[loop]
        lower = p[ca.LOWER_ARC]
        for k in ca.UPPER_ARC[1:-1]:
            d = min(np.linalg.norm(np.cross(lower[i + 1] - lower[i], lower[i] - p[k])) / max(np.linalg.norm(lower[i + 1] - lower[i]), 1e-9)
                    if 0.0 <= np.dot(p[k] - lower[i], lower[i + 1] - lower[i]) <= np.dot(lower[i + 1] - lower[i], lower[i + 1] - lower[i])
                    else min(np.linalg.norm(p[k] - lower[i]), np.linalg.norm(p[k] - lower[i + 1]))
                    for i in range(len(lower) - 1))
            worst = max(worst, float(d))
    return worst


try:
    main()
except Exception as error:  # noqa: BLE001
    import traceback
    traceback.print_exc()
    failures.append(str(error))
    print("  FALLO", error)
    print("RESULTADO: 1 FALLOS")
sys.exit(1 if failures else 0)
