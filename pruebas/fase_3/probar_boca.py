# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso 9.6: la bolsa interior de la boca ya no se aplasta (cara_anime.mouth_bag + deform con bags).

Comprueba: la bolsa (vertices de la zona mouth tapados vistos de frente) es simetrica y esta dentro de la zona; con la
bolsa, deform da exactamente lo mismo en todo lo demas (la piel que se ve no cambia); la bolsa conserva su fondo
(profundidad anime / neutra >= MIN_DEPTH); 0 cruces nuevos y 0 invertidos en la cabeza con la cara anime. Con
-- <copia de godot/datos/humana de antes>, ademas: en cuerpo.glb solo cambian vertices de la bolsa, y articulaciones.json
y ojos.json son identicos. MEDIDA: lo que se movia la bolsa antes (hasta 58 mm, IDEAS.md) y ahora; cruces e invertidos
con la boca abierta (jawOpen de faceunits01 a 0,5 y a 1), para el 9.8.
Uso: (ulimit -v 4000000; timeout 900 blender -b -P pruebas/fase_3/probar_boca.py [-- <carpeta de antes>] 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO')
Rotura: deform sin bags en EyeFit._socket_shapes -> falla «la bolsa conserva su fondo».
Paso 9.8b (D58), con la carpeta de antes: COLOR_0 con verde 0 en la bolsa y 1 en el resto; lo demas del color, igual.
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
MIN_DEPTH = 0.9  # PROVISIONAL (ficha 9.6 §1): fondo de la bolsa en la cara anime, en partes del de la neutra
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


def normals(points, tris):
    a, b, c = points[tris[:, 0]], points[tris[:, 1]], points[tris[:, 2]]
    return np.cross(b - a, c - a)


def inverted(points, tris, start):
    return int((((normals(points, tris) * start).sum(1) < 0) & (np.linalg.norm(start, axis=1) > 1e-12)).sum())


def depth(points, bag, mouth):
    """Fondo de la bolsa: de lo mas adelantado de la zona mouth (-Y) a lo mas profundo de la bolsa (+Y)."""
    return float(points[bag, 1].max() - points[mouth, 1].min())


def same_file(a, b):
    with open(a, "rb") as fa, open(b, "rb") as fb:
        return hashlib.sha256(fa.read()).digest() == hashlib.sha256(fb.read()).digest()


def check_before(before, fit, bag):
    """En cuerpo.glb solo cambian vertices de la bolsa (y sus copias de costura); los .json, identicos."""
    gltf, rest = ed._glb_parts(os.path.join(FOLDER, "cuerpo.glb"))
    old_gltf, old_rest = ed._glb_parts(os.path.join(before, "cuerpo.glb"))
    data, old_data = rest[8:], old_rest[8:]
    primitive = gltf["meshes"][0]["primitives"][0]
    old_primitive = old_gltf["meshes"][0]["primitives"][0]
    names = gltf["meshes"][0]["extras"]["targetNames"]
    old_names = old_gltf["meshes"][0]["extras"]["targetNames"]
    check("las mismas formas, en el mismo orden", names == old_names)
    base = ca._accessor(gltf, data, primitive["attributes"]["POSITION"]).astype(float)
    tree = kdtree.KDTree(len(bag))
    for i, q in enumerate(ca.to_godot(fit.points[bag])):
        tree.insert(q, i)
    tree.balance()
    in_bag = np.array([tree.find(q)[2] < 1e-5 for q in base])
    outside, inside = 0.0, 0.0
    for i in range(min(len(names), len(old_names))):
        new = ca._accessor(gltf, data, primitive["targets"][i]["POSITION"]).astype(float)
        old = ca._accessor(old_gltf, old_data, old_primitive["targets"][i]["POSITION"]).astype(float)
        diff = np.linalg.norm(new - old, axis=1)
        outside = max(outside, float(diff[~in_bag].max()))
        inside = max(inside, float(diff[in_bag].max()) if in_bag.any() else 0.0)
    print("MEDIDA cuerpo.glb contra el de antes: fuera de la bolsa %.6f mm, en la bolsa %.2f mm" % (outside * 1000, inside * 1000))
    check_mouth_color(gltf, data, primitive, old_gltf, old_data, old_primitive, in_bag)
    check("cuerpo.glb: fuera de la bolsa no cambia nada", outside == 0.0, "%.6f mm" % (outside * 1000))
    for name in ("articulaciones.json", "ojos.json"):
        check(name + " identico", same_file(os.path.join(FOLDER, name), os.path.join(before, name)))


def color(gltf, data, index):
    values = ca._accessor(gltf, data, index).astype(float)
    kind = gltf["accessors"][index]["componentType"]
    return values / {5121: 255.0, 5123: 65535.0}.get(kind, 1.0)


def check_mouth_color(gltf, data, primitive, old_gltf, old_data, old_primitive, in_bag):
    """Paso 9.8b (D58): en COLOR_0, verde 0 en la bolsa y 1 en el resto; rojo (la prenda) y alfa, como antes."""
    new = color(gltf, data, primitive["attributes"]["COLOR_0"])
    old = color(old_gltf, old_data, old_primitive["attributes"]["COLOR_0"])
    check("9.8b: verde 0 en la bolsa de la boca y 1 en el resto", bool((new[in_bag, 1] == 0.0).all() and (new[~in_bag, 1] == 1.0).all()))
    keep = [c for c in range(new.shape[1]) if c != 1]
    check("9.8b: el resto del color (la prenda), como antes", bool(np.abs(new[:, keep] - old[:, keep]).max() < 1e-6))


def main():
    before = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else None
    basemesh = ed.build_base()[0]
    fit = ca.EyeFit(basemesh)
    bag, border, _ = fit.mouth
    mouth = np.array(fit.zones["mouth"])
    print("MEDIDA bolsa de la boca: %d vertices (frontera %d) de %d de la zona mouth" % (len(bag), len(border), len(mouth)))
    check("bolsa: simetrica", set(bag.tolist()) == {int(fit.mirror[v]) for v in bag})
    check("bolsa: dentro de la zona mouth", set(bag.tolist()) <= set(mouth.tolist()))

    points, edges, zones = fit.points, fit.edges, fit.zones
    legacy = ca.deform(points, edges, zones, ca.STEPS)
    fixed = ca.deform(points, edges, zones, ca.STEPS, (fit.mouth,))
    others = np.ones(len(points), bool)
    others[bag] = False
    worst = max(float(np.abs(fixed[n] - legacy[n])[others].max()) for n in legacy)
    check("con la bolsa, lo demas sale identico", worst == 0.0, "%.9f m" % worst)
    for n in legacy:
        print("MEDIDA %s: la bolsa se movia hasta %.1f mm; ahora %.1f mm" % (n, np.linalg.norm(legacy[n][bag], axis=1).max() * 1000,
                                                                          np.linalg.norm(fixed[n][bag], axis=1).max() * 1000))
    neutral_depth = depth(points, bag, mouth)
    old_anime = points + sum(legacy[n] for n in ca.PRESET_FACE)
    ratio_old = depth(old_anime, bag, mouth) / neutral_depth
    ratio = depth(fit.anime, bag, mouth) / neutral_depth
    print("MEDIDA fondo de la bolsa: neutra %.1f mm; anime antes x%.2f, ahora x%.2f" % (neutral_depth * 1000, ratio_old, ratio))
    check("la bolsa conserva su fondo (x%.2f o mas)" % MIN_DEPTH, ratio >= MIN_DEPTH, "x%.2f" % ratio)

    tess = fit.head
    start = normals(points, tess)
    rest = crossed(points, tess)
    for name, state in (("anime antes", old_anime), ("anime", fit.anime)):
        cross, flip = max(0, crossed(state, tess) - rest), inverted(state, tess, start)
        if name == "anime":
            check("cara anime: 0 cruces nuevos y 0 invertidos en la cabeza", cross == 0 and flip == 0, "%d / %d" % (cross, flip))
        else:
            print("MEDIDA %s: %d cruces nuevos, %d invertidos" % (name, cross, flip))
    jaw = fit.face_delta(ex.unit_deltas(basemesh, ["jawOpen"])["jawOpen"]) @ np.array(basemesh.matrix_world)[:3, :3].T  # a mundo
    for amount in (0.5, 1.0):
        state = fit.anime + amount * jaw
        print("MEDIDA boca abierta (jawOpen %.1f): %d cruces nuevos, %d invertidos" % (amount, max(0, crossed(state, tess) - rest),
                                                                                    inverted(state, tess, start)))
    if before:
        check_before(before, fit, bag)
    else:
        print("  (sin carpeta de antes: no se compara cuerpo.glb)")
    print("RESULTADO:", "TODO BIEN" if not failures else "%d FALLOS" % len(failures))


try:
    main()
except Exception as error:  # noqa: BLE001
    import traceback
    traceback.print_exc()
    failures.append(str(error))
    print("  FALLO", error)
    print("RESULTADO: 1 FALLOS")
sys.exit(1 if failures else 0)
