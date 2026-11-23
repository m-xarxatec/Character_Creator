# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso 6.1: formas propias («Por crear») deformando el cuerpo neutro de MakeHuman (mismos vertices).

exportar_datos.py (paso 6.2) las pedira con own_shapes(basemesh), como las de cara (cara_anime.py).
Formas (cada deslizador da _decr e _incr; alisado, solo una):
- shoulder_height: sube o baja 3 cm hombro, brazo y mano. Vertice: d por su peso en esos huesos (de 0 a 1), con
  3 pasadas de relajacion del desplazamiento en el borde; huesos: la cola del hombro y todo el brazo, d.
- buttocks_height: sube o baja 2,5 cm los gluteos, con caida suave hacia el borde (falloff).
- buttocks_roundness: _incr empuja por la normal, mas en el centro; _decr relaja hacia una membrana tensa.
- alisado: quita relieve de pecho y entrepierna (membrana con borde fijo que conserva una parte del relieve), con
  correcciones «alisado*<esquina de las macros>» que calcula exportar_datos.py (smoothing_corrections):
  el alisado del neutro, fijo, hundia el pezon de los cuerpos que ya lo traen mas plano. Donde un triangulo se da
  la vuelta, el alisado se reduce a la mitad hasta que no quede ninguno (unflip, paso PL.0c).
Todo en ejes de Blender (Z arriba) y simetrico (cada forma se promedia con su reflejo en X).
Salida determinista y CC0 (como la cara, ver README.md).

Zonas: blender/formas_propias_zonas.json, listas de indices de vertice de la piel, elegidas una vez sobre el cuerpo
neutro: los vertices que mueven los targets CC0 de MakeHuman (mas de ZONE_SHARE de su maximo), con su simetrico.
Regenerarlas: (ulimit -v 4000000; timeout 600 blender -b -P blender/formas_propias.py -- --zonas)
Resumen de las formas: (ulimit -v 4000000; timeout 600 blender -b -P blender/formas_propias.py)
Prueba: pruebas/fase_6/probar_formas_propias.py
"""
import gzip
import json
import os
import sys

import numpy as np
from bl_ext.blender_org.mpfb.services import TargetService
from mathutils import kdtree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import exportar_datos as ed  # noqa: E402
from cara_anime import falloff, relax  # noqa: E402

ZONES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "formas_propias_zonas.json")
ZONE_TARGETS = {"buttocks": "buttocks-volume-incr", "chest": "breast-point-incr", "crotch": "bulge-incr"}
# Parte del maximo del target a partir de la que un vertice entra en la zona. Pecho, solo la punta: con 0,15 la
# membrana aplana todo el pecho (14 mm frente a 9; el volumen del pecho es cosa de la macro cupsize).
ZONE_SHARE = {"buttocks": 0.15, "chest": 0.5, "crotch": 0.15}
ARM_PARTS = ("Shoulder", "UpperArm", "LowerArm", "Hand", "Thumb", "Index", "Middle", "Ring", "Little")
SHOULDER_RISE = 0.03  # metros
BUTTOCKS_RISE = 0.025  # metros
BUTTOCKS_PUSH = 0.015  # metros por la normal en el centro de la zona
ROUND_KEEP = 0.8  # buttocks_roundness_decr: parte del relieve que conserva (con 0,5 bajaba 43 mm; _incr sube 15)
SMOOTH_KEEP = 0.2  # alisado: parte del relieve que conserva
BORDER_PASSES = 3
FALLOFF_STEPS = 8
FULL = 3000  # pasadas para llegar a la membrana
UNFLIP_PASSES = 30  # alisado: veces, como mucho, que se reduce a la mitad donde hay triangulos invertidos
SMOOTHING = "alisado"
SHAPES = ("shoulder_height_decr", "shoulder_height_incr", "buttocks_height_decr", "buttocks_height_incr",
          "buttocks_roundness_incr", "buttocks_roundness_decr", SMOOTHING)  # las que da world_shapes, en su orden


def mesh_arrays(basemesh):
    """(puntos en ejes de Blender, aristas, triangulos, matriz del objeto) de la malla."""
    world = np.array(basemesh.matrix_world)
    points = np.array([v.co[:] for v in basemesh.data.vertices]) @ world[:3, :3].T + world[:3, 3]
    edges = np.array(sorted(tuple(sorted(e.vertices[:])) for e in basemesh.data.edges))
    triangles = np.array([(p.vertices[0], p.vertices[k], p.vertices[k + 1])
                          for p in basemesh.data.polygons for k in range(1, len(p.vertices) - 1)])
    return points, edges, triangles, world


def mirror_map(points):
    """Indice del vertice simetrico (reflejo en X) de cada vertice."""
    tree = kdtree.KDTree(len(points))
    for index, point in enumerate(points):
        tree.insert(point, index)
    tree.balance()
    return np.array([tree.find((-p[0], p[1], p[2]))[1] for p in points])


def grow(mask, edges, rings):
    """La zona con rings anillos mas de vecinos."""
    a, b = edges.T
    grown = mask.copy()
    for _ in range(rings):
        step = grown.copy()
        step[a[grown[b]]] = True
        step[b[grown[a]]] = True
        grown = step
    return grown


def depth(mask, edges):
    """De 0 a 1 dentro de la zona: anillos hasta el borde, partido por el maximo (0 fuera)."""
    rings = np.zeros(len(mask))
    reached, ring = ~mask, 0
    while not reached.all() and ring < len(mask):
        ring += 1
        new = grow(reached, edges, 1) & ~reached
        if not new.any():
            break
        rings[new] = ring
        reached |= new
    return rings / max(rings.max(), 1.0)


def vertex_normals(points, triangles):
    a, b, c = (points[triangles[:, i]] for i in range(3))
    faces = np.cross(b - a, c - a)
    normals = np.zeros_like(points)
    for i in range(3):
        np.add.at(normals, triangles[:, i], faces)
    return normals / np.maximum(np.linalg.norm(normals, axis=1), 1e-12)[:, None]


def arm_weight(basemesh, bones):
    """Por vertice: peso en los huesos dados partido por su peso total (de 0 a 1)."""
    names = {g.index: g.name for g in basemesh.vertex_groups}
    share = np.zeros(len(basemesh.data.vertices))
    for vertex in basemesh.data.vertices:
        total = sum(g.weight for g in vertex.groups)
        if total > 0:
            share[vertex.index] = sum(g.weight for g in vertex.groups if names[g.group] in bones) / total
    return share


def arm_bones(rig):
    return {b.name for b in rig.data.bones
            if b.name.startswith(("Left", "Right")) and b.name.removeprefix("Left").removeprefix("Right").startswith(ARM_PARTS)}


def load_zones():
    with open(ZONES, encoding="utf-8") as file:
        return json.load(file)


def zone_mask(zones, names, count):
    return np.isin(np.arange(count), np.concatenate([zones[name] for name in names]))


def symmetric(delta, mirror):
    return (delta + delta[mirror] * np.array([-1.0, 1.0, 1.0])) / 2


def world_shapes(basemesh):
    """{forma: (desplazamiento de cada vertice, {hueso: (d_cabeza, d_cola)})}, en ejes de Blender."""
    points, edges, triangles, _ = mesh_arrays(basemesh)
    zones, mirror = load_zones(), mirror_map(points)
    rig, count = basemesh.parent, len(points)
    still = {b.name: (np.zeros(3), np.zeros(3)) for b in rig.data.bones}
    shapes = {}

    arm = arm_bones(rig)
    weight = arm_weight(basemesh, arm)
    border = (weight > 0) & (weight < 1)
    for end, rise in (("_decr", -SHOULDER_RISE), ("_incr", SHOULDER_RISE)):
        delta = np.zeros((count, 3))
        delta[:, 2] = rise * weight
        delta = relax(delta, edges, border, BORDER_PASSES, 0.0)
        up = np.array([0.0, 0.0, rise])
        joints = dict(still)
        for bone in arm:
            joints[bone] = (np.zeros(3) if bone.endswith("Shoulder") else up, up)
        shapes["shoulder_height" + end] = (symmetric(delta, mirror), joints)

    buttocks = zone_mask(zones, ["buttocks"], count)
    lift = falloff(buttocks, edges, FALLOFF_STEPS)
    push = np.sin(np.pi / 2 * depth(buttocks, edges))
    normals = vertex_normals(points, triangles)
    for end, sign in (("_decr", -1.0), ("_incr", 1.0)):
        delta = np.zeros((count, 3))
        delta[:, 2] = sign * BUTTOCKS_RISE * lift
        shapes["buttocks_height" + end] = (symmetric(delta, mirror), still)
    shapes["buttocks_roundness_incr"] = (symmetric(BUTTOCKS_PUSH * push[:, None] * normals, mirror), still)
    shapes["buttocks_roundness_decr"] = (symmetric(relax(points, edges, buttocks, FULL, ROUND_KEEP) - points, mirror), still)

    shapes[SMOOTHING] = (smoothing(points, edges, triangles, zones, mirror), still)
    return shapes


def smoothing(points, edges, triangles, zones, mirror):
    """Desplazamiento de alisado sobre esos puntos (membrana en pecho y entrepierna, sin escalon en el borde)."""
    smooth = zone_mask(zones, ["chest", "crotch"], len(points))
    moved = relax(points, edges, smooth, FULL, SMOOTH_KEEP)
    moved = relax(moved, edges, grow(smooth, edges, 1), BORDER_PASSES, 0.0)
    return unflip(points, symmetric(moved - points, mirror), triangles, mirror)


def flipped(before, after, triangles):
    """Mascara de los triangulos cuya normal se da la vuelta (producto escalar con la original <= 0)."""
    def normals(points):
        a, b, c = (points[triangles[:, i]] for i in range(3))
        return np.cross(b - a, c - a)
    return np.einsum("ij,ij->i", normals(before), normals(after)) <= 0


def unflip(points, delta, triangles, mirror):
    """delta con la mitad del desplazamiento en los vertices (y sus simetricos) de cada triangulo que se da la
    vuelta, repetido hasta que no quede ninguno o UNFLIP_PASSES veces. Sigue simetrico."""
    delta = delta.copy()
    for _ in range(UNFLIP_PASSES):
        bad = flipped(points, points + delta, triangles)
        if not bad.any():
            break
        verts = np.unique(triangles[bad])
        delta[np.union1d(verts, mirror[verts])] *= 0.5
    return delta


def own_shapes(basemesh):
    """Como world_shapes, con el desplazamiento de los vertices en el espacio de la malla (como feature_shapes)."""
    to_local = np.linalg.inv(np.array(basemesh.matrix_world)[:3, :3])
    return {name: (delta @ to_local.T, joints) for name, (delta, joints) in world_shapes(basemesh).items()}


def choose_zones(basemesh):
    """{zona: indices}: vertices de la piel que mueve su target mas de ZONE_SHARE de su maximo, con su simetrico."""
    points = mesh_arrays(basemesh)[0]
    mirror = mirror_map(points)
    zones = {}
    for zone, target in ZONE_TARGETS.items():
        with gzip.open(TargetService.target_full_path(target), "rt") as file:
            rows = [line.split() for line in file if line.strip() and not line.startswith("#")]
        size = {int(r[0]): np.linalg.norm([float(x) for x in r[1:4]]) for r in rows if int(r[0]) < len(points)}
        top = max(size.values())
        chosen = np.array([i for i, s in size.items() if s > ZONE_SHARE[zone] * top])
        zones[zone] = sorted(int(i) for i in set(chosen) | set(mirror[chosen]))
    return zones


def main():
    basemesh = ed.build_base()[0]
    if "--zonas" in sys.argv:
        zones = choose_zones(basemesh)
        with open(ZONES, "w", encoding="utf-8") as file:
            json.dump(zones, file, sort_keys=True, separators=(",", ":"))
            file.write("\n")
        print("GUARDADO:", ZONES, {name: len(indices) for name, indices in zones.items()})
        return
    for name, (delta, _) in world_shapes(basemesh).items():
        size = np.linalg.norm(delta, axis=1)
        print("FORMA %s: %d vertices movidos; max. %.1f mm" % (name, (size > 1e-6).sum(), 1000 * size.max()))


if __name__ == "__main__":
    main()
