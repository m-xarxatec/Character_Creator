# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso 6.1: las formas propias (blender/formas_propias.py) cumplen las medidas de su ficha.

Uso: (ulimit -v 4000000; timeout 900 blender -b -P pruebas/fase_6/probar_formas_propias.py 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO')
Con «-- --capturas» guarda ademas las hojas del juicio visual en pruebas/capturas/formas_propias/:
  <deslizador>.png  filas (de arriba abajo) neutro, _decr y _incr al 100 %; columnas frente, perfil y espalda
  alisado.png       torso sin prenda; filas antes y despues; columnas frente y tres cuartos
  complexion.png    como alisado.png, con gender y firmness a 0 y a 1 (paso PL.0); filas: cada cuerpo antes y despues
                    (despues = alisado con sus correcciones, paso PL.0b)
Sombreado normal (difuso), que marca mas el relieve que el toon.
"""
import itertools
import os
import sys

import bpy
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import exportar_datos as ed  # noqa: E402
import formas_propias as fp  # noqa: E402
import render_vistas as rv  # noqa: E402

CAPTURES = os.path.join(ROOT, "pruebas", "capturas", "formas_propias")
DATA = os.path.join(ROOT, "godot", "datos", "humana")
MOVED_MM = 0.01
SYMMETRY_MM = 0.01
JOINT_MM = 0.1
RIGID_MM = 1.0  # PROVISIONAL
SMOOTH_DROP = 0.5  # PROVISIONAL: la curvatura media de cada zona baja al menos esto
VOLUME_SHARE = 0.02  # PROVISIONAL (del volumen del cuerpo entero; la ficha dice «del torso»)
COMPLEXION = ("gender", "breast_firmness")  # PL.0: estos a 0 o a 1 y las demas macros neutras
EXTREME = ("muscle", "weight", "breast_volume")  # 6.2: todas las formas en estos a 0 y a 1
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def flips(before, after, triangles):
    """Triangulos cuya normal se da la vuelta (producto escalar con la original <= 0)."""
    def normals(points):
        a, b, c = (points[triangles[:, i]] for i in range(3))
        return np.cross(b - a, c - a)
    return int((np.einsum("ij,ij->i", normals(before), normals(after)) <= 0).sum())


def curvature(points, edges, mask):
    """Media de |punto - media de sus vecinos| en la zona (curvatura media discreta, sin pesos)."""
    a, b = edges.T
    count = np.bincount(a, minlength=len(points)) + np.bincount(b, minlength=len(points))
    total = np.zeros_like(points)
    for axis in range(3):
        total[:, axis] = (np.bincount(a, weights=points[b, axis], minlength=len(points))
                          + np.bincount(b, weights=points[a, axis], minlength=len(points)))
    return np.linalg.norm(points - total / count[:, None], axis=1)[mask].mean()


def volume(points, triangles):
    a, b, c = (points[triangles[:, i]] for i in range(3))
    return np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6


def check_shapes(basemesh, shapes):
    points, edges, triangles, _ = fp.mesh_arrays(basemesh)
    mirror = fp.mirror_map(points)
    print("  MEDIDA reflejo de la malla neutra: %.4f mm" % (1000 * np.abs(points[mirror] * [-1, 1, 1] - points).max()))
    zones, count = fp.load_zones(), len(points)
    arm = fp.arm_bones(basemesh.parent)
    buttocks = fp.zone_mask(zones, ["buttocks"], count)
    allowed = {"shoulder_height": fp.arm_weight(basemesh, arm) > 0,
               "buttocks_height": fp.grow(buttocks, edges, fp.FALLOFF_STEPS), "buttocks_roundness": buttocks,
               "alisado": fp.grow(fp.zone_mask(zones, ["chest", "crotch"], count), edges, 1)}
    for name, (delta, _) in shapes.items():
        size = 1000 * np.linalg.norm(delta, axis=1)
        print("  MEDIDA %s: %d vertices movidos, max. %.1f mm" % (name, (size > MOVED_MM).sum(), size.max()))
        mirrored = 1000 * np.abs(delta - delta[mirror] * [-1, 1, 1]).max()
        check(f"{name}: simetrica", mirrored < SYMMETRY_MM, "%.5f mm" % mirrored)
        region = next(value for key, value in allowed.items() if name.startswith(key))
        outside = int(((size > MOVED_MM) & ~region).sum())
        check(f"{name}: solo mueve su zona y su borde", outside == 0, f"{outside} vertices fuera")
        flipped = flips(points, points + delta, triangles)
        check(f"{name}: ningun triangulo se da la vuelta", flipped == 0, f"{flipped}")

    delta, joints = shapes["shoulder_height_incr"]
    for side in ("Left", "Right"):
        rise = 1000 * joints[side + "UpperArm"][0][2]
        check(f"shoulder_height_incr: la articulacion del brazo {side} sube 30 mm", abs(rise - 30) <= JOINT_MM, "%.3f mm" % rise)
        still = 1000 * np.linalg.norm(joints[side + "Shoulder"][0])
        check(f"shoulder_height_incr: la cabeza del hombro {side} no se mueve", still <= JOINT_MM, "%.3f mm" % still)
    rigid = fp.arm_weight(basemesh, {b for b in arm if not b.endswith("Shoulder")}) > 0.999
    error = 1000 * np.abs(delta[rigid] - [0, 0, fp.SHOULDER_RISE]).max()
    check(f"shoulder_height_incr: el brazo ({rigid.sum()} vertices con peso 1) sube rigido (< {RIGID_MM} mm)",
          error < RIGID_MM, "%.4f mm" % error)

    check_smoothing("alisado", points, shapes["alisado"][0], edges, triangles)


def check_smoothing(label, points, delta, edges, triangles):
    """Medidas del alisado del 6.2: curvatura de pecho y entrepierna y volumen del cuerpo."""
    zones, smoothed = fp.load_zones(), points + delta
    for zone in ("chest", "crotch"):
        mask = fp.zone_mask(zones, [zone], len(points))
        before, after = curvature(points, edges, mask), curvature(smoothed, edges, mask)
        drop = 1 - after / before
        check(f"{label}: la curvatura de {zone} baja al menos un {100 * SMOOTH_DROP:.0f} %", drop >= SMOOTH_DROP,
              "%.4f -> %.4f mm (%.1f %%)" % (1000 * before, 1000 * after, 100 * drop))
    change = volume(smoothed, triangles) / volume(points, triangles) - 1
    check(f"{label}: el volumen del cuerpo cambia menos de un {100 * VOLUME_SHARE:.0f} %", abs(change) < VOLUME_SHARE,
          "%.3f %%" % (100 * change))


def smoothing_bodies():
    """{esquina: muestra} con las macros de SMOOTHING_SLIDERS a 0, 0,5 o 1, como en exportar_datos.py."""
    return ed.corner_bodies([s for s in ed.macro_sliders(ed.read_sliders(DATA)) if s[0] in ed.SMOOTHING_SLIDERS])


def smoothing_at(delta, extra, corner):
    """alisado en esa esquina: delta mas las correcciones cuyas partes tiene (peso 1; las demas pesan 0), como la app."""
    parts = {f"{i}_{'incr' if side else 'decr'}" for i, side in corner}
    return delta + sum(d for n, (d, _) in extra.items() if set(n.split("*")[1:]) <= parts)


def complexion_corners():
    """Esquinas de PL.0: COMPLEXION a 0 o a 1 y las demas macros neutras."""
    return [tuple(zip(COMPLEXION, sides)) for sides in itertools.product((0, 1), repeat=len(COMPLEXION))]


def check_complexion(bodies, delta, extra, edges, triangles):
    """PL.0: el alisado, con sus correcciones, cumple las medidas del 6.2 con complexion y firmeza a 0 y a 1."""
    for corner in complexion_corners():
        label = "alisado con " + ", ".join(f"{i}={side}" for i, side in corner)
        skin, smoothing = bodies[corner][0], smoothing_at(delta, extra, corner)
        flipped = flips(skin, skin + smoothing, triangles)
        check(f"{label}: ningun triangulo se da la vuelta", flipped == 0, f"{flipped}")
        check_smoothing(label, skin, smoothing, edges, triangles)


def check_extremes(shapes, bodies, extra, triangles):
    """Cada forma al 100 % sobre los cuerpos de las esquinas (espacio de la malla); alisado, con sus correcciones
    (exportar_datos.smoothing_corrections). Cuentan todas las formas en las 8 de EXTREME (6.2) y alisado en las 32
    de SMOOTHING_SLIDERS (PL.0b); ahi las demas solo se miden (shoulder_height_decr: IDEAS.md)."""
    for ids in (EXTREME, [i for i, _ in max(bodies, key=len)]):
        worst = 0
        for sides in itertools.product((0, 1), repeat=len(ids)):
            corner = tuple(zip(ids, sides))
            skin = bodies[corner][0]
            for name, (delta, _) in shapes.items():
                if name == fp.SMOOTHING:
                    delta = smoothing_at(delta, extra, corner)
                flipped = flips(skin, skin + delta, triangles)
                if flipped:
                    print("  MEDIDA %s con %s: %d triangulos invertidos" % (name, dict(corner), flipped))
                if ids == EXTREME or name == fp.SMOOTHING:
                    worst = max(worst, flipped)
        what = "todas las formas" if ids == EXTREME else "alisado"
        check(f"macros extremas ({2 ** len(ids)} cuerpos, {what}): ningun triangulo se da la vuelta", worst == 0,
              f"peor {worst}")


def captures(bodies):
    basemesh = ed.build_base()[0]
    shapes = fp.own_shapes(basemesh)
    base = np.empty(len(basemesh.data.vertices) * 3)
    basemesh.data.vertices.foreach_get("co", base)
    basemesh.shape_key_add(name="Basis", from_mix=False)
    keys = {}
    for name, (delta, _) in shapes.items():
        keys[name] = basemesh.shape_key_add(name=name, from_mix=False)
        keys[name].data.foreach_set("co", base + delta.ravel())
    scene = bpy.context.scene
    rv._setup_render(scene)
    rv._apply_preview_material(basemesh)
    camera = rv._add_camera(scene, basemesh)
    os.makedirs(CAPTURES, exist_ok=True)

    def sheet(states, angles, path):
        rows = []
        for state in states:
            for name, key in keys.items():
                key.value = 1.0 if name == state else 0.0
            rows.append(np.concatenate([rv._render_tile(scene, camera, angle) for angle in angles], axis=1))
        rv._save_sheet(np.concatenate(rows[::-1], axis=0), path)  # Blender guarda de abajo arriba
        print("GUARDADO:", path)

    for slider in ("shoulder_height", "buttocks_height", "buttocks_roundness"):
        sheet([None, slider + "_decr", slider + "_incr"], [a for _, a in rv.VIEWS], os.path.join(CAPTURES, slider + ".png"))
    garment = basemesh.data.color_attributes["garment"]
    garment.data.foreach_set("color", np.zeros(len(garment.data) * 4))
    points, _, _, _ = fp.mesh_arrays(basemesh)
    zones = fp.load_zones()
    camera.data.ortho_scale = 0.8
    camera["center_z"] = float((points[zones["chest"], 2].mean() + points[zones["crotch"], 2].mean()) / 2)
    sheet([None, "alisado"], [0, 45], os.path.join(CAPTURES, "alisado.png"))
    center = camera["center_z"]
    rows = []
    for corner, (skin, smoothing) in bodies.items():  # cada cuerpo, bajado o subido para que su torso quede en el centro
        lift = center - (skin[zones["chest"], 2].mean() + skin[zones["crotch"], 2].mean()) / 2
        for name, delta in ((f"{corner}", 0), (f"{corner} alisado", smoothing)):
            keys[name] = basemesh.shape_key_add(name=name, from_mix=False)
            keys[name].data.foreach_set("co", (skin + delta + [0, 0, lift]).ravel())
            rows.append(name)
    sheet(rows, [0, 45], os.path.join(CAPTURES, "complexion.png"))


def main():
    basemesh = ed.build_base()[0]
    shapes = fp.world_shapes(basemesh)
    again = fp.world_shapes(basemesh)
    same = all(np.array_equal(shapes[n][0], again[n][0])
               and all(np.array_equal(shapes[n][1][b][i], again[n][1][b][i]) for b in shapes[n][1] for i in (0, 1))
               for n in shapes)
    check("dos ejecuciones dan los mismos desplazamientos", same)
    check("las formas son las de SHAPES", tuple(shapes) == fp.SHAPES, list(shapes))
    _, edges, triangles, _ = fp.mesh_arrays(basemesh)
    local = fp.own_shapes(basemesh)
    check_shapes(basemesh, shapes)
    bodies = smoothing_bodies()
    extra = ed.smoothing_corrections(edges, triangles, bodies)
    print("  MEDIDA correcciones de alisado: %d; max. %.1f mm" % (
        len(extra), 1000 * max(np.linalg.norm(d, axis=1).max() for d, _ in extra.values())))
    delta = local[fp.SMOOTHING][0]
    check_complexion(bodies, delta, extra, edges, triangles)
    if "--capturas" in sys.argv:
        captures({c: (bodies[c][0], smoothing_at(delta, extra, c)) for c in complexion_corners()})
    check_extremes(local, bodies, extra, triangles)
    print("RESULTADO:", "TODO BIEN" if not failures else f"{len(failures)} FALLOS")


main()
