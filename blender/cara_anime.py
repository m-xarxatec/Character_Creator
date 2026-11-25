# SPDX-License-Identifier: GPL-3.0-or-later
"""Cara anime deformando la cabeza neutra de MakeHuman (mismos vertices), con una forma por rasgo.

Las formas de datos/ (paso 3.14) salen de aqui: exportar_datos.py llama a feature_shapes() con las filas «cara:<forma>».
Uso (maqueta 3.13a-4): blender -b -P blender/cara_anime.py -- pruebas/fase_3/salida/cara_anime/cara_anime.json
Escribe cada forma (desplazamiento de cada vertice movido, ejes de Godot, metros) y los puntos fijos (ojos, nariz).
Formas: cuenca_plana, boca_anime, mandibula_anime, menton_anime y nariz_anime. Preset «cara anime»: todas a 1, salvo
nariz_anime a 0 (nariz de MakeHuman). Salida determinista y CC0 (ver README.md).
Prueba: pruebas/fase_3/probar_cara_anime.py (la suma de las formas da la cara aprobada en la 3.13a-4).
Ojo anime (AC.3b.1): EyeFit abre la cuenca nueva, corrige lazo, bolsa y corona, y da las 10 formas de ojo, la mascara
del contorno (TEXCOORD_1) y ojos.json. Prueba: pruebas/fase_3/probar_forma_ojo.py.
Tiras del ojo (AC.6a): linea de arriba (con cola para las pestanas), linea de abajo y pliegue, en ojos.json.
Banda de la ceja (AC.6c): rejilla sobre la frente, encima de cada ojo, con el mismo formato (brow_band). Cada vertice
es la mezcla baricentrica de 3 vertices del .glb mas un desplazamiento fijo: asi sigue a las formas y a los huesos.

Zonas: blender/cara_anime_zonas.json, listas de indices de vertice de la malla base de MakeHuman, elegidas una vez
sobre la cabeza neutra: los vertices que mueven los targets CC0 de MakeHuman de cada rasgo (nose, mouth, eyes, chin,
eyebrows; mas de un 15 % de su maximo), solo en la cabeza, con su simetrico y con las bolsas interiores de ojos y boca.
Tambien los puntos fijos: eye_anchor_l/r, nose_tip, nose_ring (borde de la nariz) y chin_tip.

Como deforma:
- relajar: cada vertice de la zona va a la media de sus vecinos, con el borde fijo, hasta quedar como una membrana
  tensa; `keep` devuelve una parte del relieve original. Asi se aplanan las cuencas, la nariz y los labios.
  Con pocas pasadas solo suaviza (cejas, y el escalon entre nariz y boca).
- mandibula / menton: de la boca hacia abajo, estrecha la mandibula (X) y sube el menton (Z), con caida suave.
- Paso 9.6: con bags (la bolsa de la boca, mouth_bag), el relajado no aplasta la bolsa interior: tras cada paso de
  relajar, la bolsa sigue a su borde con un operador armonico (como la bolsa del ojo). La piel que se ve no cambia.
Cada forma es lo que mueven sus pasos, aplicados en el orden de STEPS sobre el resultado del anterior: la suma de
todas a 1 da la cara entera. La nariz va la ultima, para que nariz_anime = 0 deje la nariz sin escalones.
"""
import json
import math
import os
import sys

import numpy as np
from mathutils.bvhtree import BVHTree

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
# Ojo anime (AC.3b, valores aprobados en AC.3b.0)
PRESET_FACE = ("cuenca_plana", "boca_anime", "mandibula_anime", "menton_anime")
HALF_W, HALF_H = 0.013, 0.008  # abertura: 26 x 16 mm
BAG_DEPTH = 0.003
WALL_LID, WALL_BAG = 0.12, 0.30  # parte del radio en la que la bolsa baja hasta su fondo (parpado, bolsa)
RINGS = 5  # anillos de piel que absorben el movimiento del lazo
EYE_PASSES = 700
SOFT_RADIUS = 0.020  # reparto suave de las formas de ojo alrededor del lazo
BAG_MARGIN = 0.0003  # la bolsa queda al menos a esta distancia detras de la membrana del lazo
EYE_SHAPES = ("eye_size", "eye_spacing", "eye_position", "eye_tall", "eye_corner")
OWN_EYE = {"eye_size_decr": ("size", -0.25), "eye_size_incr": ("size", 0.16), "eye_tall_decr": ("tall", -0.20),
           "eye_tall_incr": ("tall", 0.16), "eye_corner_decr": ("corner", -9.0), "eye_corner_incr": ("corner", 9.0)}
EYE_CLIP = {"eye_spacing_incr": 0.70, "eye_position_incr": 0.65}
FLIP = np.array((-1.0, 1.0, 1.0))
TAU = 2.0 * math.pi
# Tiras del ojo (AC.6a; filas en metros, + hacia fuera del lazo; las de AC.4a, ac4a_hoja.gd)
LINE_ROWS = (-0.0028, -0.0022, -0.0016, -0.0011, -0.0006, 0.0, 0.00006, 0.00012, 0.00018, 0.00025, 0.0005, 0.00075,
             0.0010, 0.00125)  # hasta el borde de la linea mas las pestanas
LOWER_ROWS = (-0.00075, -0.0005, -0.00025, -0.00002, 0.0, 0.00006, 0.00012, 0.00018, 0.00025, 0.0005, 0.00075)
CREASE_ROWS = (0.0020, 0.0022, 0.0024)
TAIL, TAIL_STEP = 3, 0.001  # columnas de cola de la linea de arriba (pestanas) y metros por columna
STRIP_LIFT = 0.00012  # elevacion sobre la superficie en la que se apoya cada vertice
RAY_FROM = 0.005  # el rayo de apoyo empieza 5 mm por delante
MAX_SNAP = 0.0045  # solo se apoya en una superficie a menos de 4,5 mm del punto
SKIN_RADIUS = 0.025  # piel en la que se apoyan las tiras: a menos de 25 mm del centro del ojo
# Banda de la ceja (AC.6c; caja y rejilla aprobadas en AC.6c.0, ruta/pasos/AC.6c_cejas.md 5.2)
BROW_COLUMNS, BROW_ROWS = 32, 15
BROW_BEFORE, BROW_AFTER = 0.008, 0.012  # en el lado: desde 8 mm antes de la esquina interior a 12 mm despues de la exterior
BROW_LOW, BROW_HIGH = 0.002, 0.028  # hacia arriba: de 2 a 28 mm sobre lo alto del lazo
BROW_RAY_FROM = 0.030  # la rejilla va en el plano del centro del ojo y el rayo empieza 30 mm por delante
BROW_MAX_SNAP = 0.030  # vale cualquier piel entre el origen del rayo y 30 mm detras del plano (el prototipo no tenia limite)
BROW_RADIUS = 0.050  # piel en la que se apoya la banda: a menos de 50 mm del centro del ojo
BLINK_GAP = 0.0002  # paso 9.7.1: al parpadear, el arco de arriba del lazo queda 0,2 mm por encima del de abajo
UPPER_ARC, LOWER_ARC = list(range(0, 21)), list(range(20, 36)) + [0]  # posiciones en EyeSide.loop (las de eye_data)
# Bolsa de la boca (paso 9.6): lo de la zona mouth que no se ve de frente con la boca cerrada
MOUTH_RAY = 0.10  # el rayo de visibilidad empieza 10 cm por delante (-Y de Blender) de cada vertice
MOUTH_EPS = 0.0002  # tapado: algo corta el rayo a mas de 0,2 mm por delante del vertice


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


def deform(points, edges, zones, steps, bags=()):
    """Aplica los pasos [(nombre, zona, pasadas, relieve)] en orden: {nombre: desplazamiento sumado de sus pasos}.
    Ejes de Blender: X a los lados, Z arriba.
    bags (paso 9.6): [(libres, frontera, matriz)] de _harmonic. Todo se calcula como sin ellas, y luego en las filas de
    los libres: en los pasos de relajar, el movimiento de su frontera (matriz @ frontera: no se aplastan); en mandibula
    y menton, el mismo calculo sobre su posicion sin aplastar. Las demas filas salen identicas a las de sin bags."""
    masks = {name: np.isin(np.arange(len(points)), zones[name]) for name in ("eyes", "nose", "mouth", "brow", "chin")}
    mouth_z = points[masks["mouth"], 2].mean()
    chin_z = points[zones["chin_tip"], 2]
    weight = falloff(masks["chin"], edges, FALLOFF_STEPS)
    moved = points.copy()
    fixed = points.copy()  # paso 9.6: con las bolsas sin aplastar
    down = down_fixed = None
    deltas = {}
    for name, zone, passes, keep in steps:
        before = moved.copy()
        if zone in ("jaw", "chin"):
            if zone == "jaw":  # el menton usa el mismo «down»: separar X y Z no cambia el resultado
                down = np.clip((mouth_z - moved[:, 2]) / (mouth_z - chin_z), 0.0, 1.0) * weight
                down_fixed = np.clip((mouth_z - fixed[:, 2]) / (mouth_z - chin_z), 0.0, 1.0) * weight
            moved, fixed_step = _jaw_chin(moved, zone, down, mouth_z, chin_z), _jaw_chin(fixed, zone, down_fixed, mouth_z, chin_z) - fixed
            step = moved - before
            for free, _, _ in bags:
                step[free] = fixed_step[free]
        else:
            mask = np.any([masks[z] for z in zone.split("+")], axis=0)
            moved = relax(moved, edges, mask, passes, keep)
            step = moved - before
            for free, border, matrix in bags:
                if mask[free].any():
                    step[free] = matrix @ step[border]
        fixed = fixed + step
        deltas[name] = deltas.get(name, 0.0) + step
    return deltas


def _jaw_chin(points, zone, down, mouth_z, chin_z):
    """Paso de mandibula (estrecha X) o de menton (sube Z) sobre una copia de points."""
    out = points.copy()
    if zone == "jaw":
        out[:, 0] *= 1.0 - JAW_NARROW * down
    else:
        out[:, 2] += CHIN_SHORTEN * (mouth_z - chin_z) * down
    return out


def neutral_head():
    """(puntos de la malla neutra en ejes de Blender, aristas ordenadas, zonas)."""
    return mesh_head(ed.build_base()[0])


def mesh_head(basemesh):
    """Como neutral_head, con la malla neutra ya creada (ed.build_base)."""
    with open(ZONES, encoding="utf-8") as file:
        zones = json.load(file)
    world = np.array(basemesh.matrix_world)
    points = np.array([v.co[:] for v in basemesh.data.vertices]) @ world[:3, :3].T + world[:3, 3]
    edges = np.array(sorted(tuple(sorted(e.vertices[:])) for e in basemesh.data.edges))
    return points, edges, zones


def to_godot(p):
    p = np.asarray(p)
    return np.stack((p[..., 0], p[..., 2], -p[..., 1]), axis=-1)


def from_godot(p):
    p = np.asarray(p)
    return np.stack((p[..., 0], -p[..., 2], p[..., 1]), axis=-1)


def _surface(c, x, z):
    return c[0] + c[1] * x + c[2] * z + c[3] * x * x + c[4] * z * z + c[5] * x * z


def _rim_plane(loop):
    """Superficie suave que pasa por la parte mas profunda del borde."""
    x, z = loop[:, 0], loop[:, 2]
    c = np.linalg.lstsq(np.column_stack((np.ones(len(x)), x, z, x * x, z * z, x * z)), loop[:, 1], rcond=None)[0]
    c[0] += float((loop[:, 1] - _surface(c, x, z)).max())
    return c


def _ordered_ring(points, loop, outer_sign):
    """El lazo en sentido antihorario (X, Z), empezando por su esquina exterior."""
    x, z = points[loop, 0], points[loop, 2]
    area = 0.5 * (np.dot(x, np.roll(z, -1)) - np.dot(z, np.roll(x, -1)))
    ring = list(loop) if area > 0 else list(reversed(loop))
    start = int(np.argmax(points[ring, 0] * outer_sign))
    return ring[start:] + ring[:start]


def _edge(a, b):
    return (a, b) if a < b else (b, a)


def _adjacency(tris):
    adj = {}
    for tri in tris:
        for k in range(3):
            a, b = int(tri[k]), int(tri[(k + 1) % 3])
            adj.setdefault(a, set()).add(b)
            adj.setdefault(b, set()).add(a)
    return adj


def _harmonic(free, adj):
    """(ids libres, ids frontera, matriz): valores libres = matriz @ valores frontera (media de vecinos)."""
    index = {v: i for i, v in enumerate(free)}
    border = sorted({o for v in free for o in adj[v] if o not in index})
    border_index = {v: i for i, v in enumerate(border)}
    A = np.zeros((len(free), len(free)))
    B = np.zeros((len(free), len(border)))
    for v, i in index.items():
        for o in adj[v]:
            A[i, i] += 1.0
            if o in index:
                A[i, index[o]] -= 1.0
            else:
                B[i, border_index[o]] += 1.0
    return np.array(free), np.array(border), np.linalg.solve(A, B)


def mouth_bag(points, head, edges, zones, mirror):
    """Paso 9.6: la bolsa interior de la boca y su operador armonico (libres, frontera, matriz). Bolsa: los vertices de
    la zona mouth tapados vistos de frente (un rayo desde MOUTH_RAY por delante, -Y, corta otra cara antes), la mayor
    pieza conexa, con su simetrico. Asi no entra la piel de las comisuras, que queda detras de los labios pero se ve."""
    tree = BVHTree.FromPolygons([tuple(map(float, p)) for p in points], [tuple(int(i) for i in t) for t in head],
                                all_triangles=True)
    hidden = set()
    for v in zones["mouth"]:
        origin = points[v] - np.array((0.0, MOUTH_RAY, 0.0))
        hit = tree.ray_cast(tuple(map(float, origin)), (0.0, 1.0, 0.0), MOUTH_RAY)
        if hit[0] is not None and hit[3] < MOUTH_RAY - MOUTH_EPS:
            hidden.add(int(v))
    adj = {}
    for a, b in edges:
        adj.setdefault(int(a), set()).add(int(b))
        adj.setdefault(int(b), set()).add(int(a))
    pieces, seen = [], set()
    for start in sorted(hidden):
        if start in seen:
            continue
        piece, stack = [], [start]
        seen.add(start)
        while stack:
            v = stack.pop()
            piece.append(v)
            for o in adj[v]:
                if o in hidden and o not in seen:
                    seen.add(o)
                    stack.append(o)
        pieces.append(piece)
    if not pieces:
        raise ValueError("Bolsa de la boca: ningun vertice de la zona mouth queda tapado")
    largest = max(pieces, key=len)
    bag = sorted(set(largest) | {int(mirror[v]) for v in largest})
    return _harmonic(bag, adj)


def _poly_radius(poly, c, angle):
    """Distancia de c al borde del poligono en la direccion angle."""
    d = (math.cos(angle), math.sin(angle))
    best = None
    for i in range(len(poly)):
        p, q = poly[i], poly[(i + 1) % len(poly)]
        ex, ey = q[0] - p[0], q[1] - p[1]
        den = d[0] * ey - d[1] * ex
        if abs(den) < 1e-14:
            continue
        wx, wy = p[0] - c[0], p[1] - c[1]
        t = (wx * ey - wy * ex) / den
        s = (wx * d[1] - wy * d[0]) / den
        if t > 0.0 and -1e-9 <= s <= 1.0 + 1e-9 and (best is None or t > best):
            best = t
    return best


def head_triangles(basemesh, triangles):
    """Triangulos con algun vertice en los huesos Head o Neck."""
    groups = {basemesh.vertex_groups[name].index for name in ("Head", "Neck")}
    weight = np.array([sum(g.weight for g in v.groups if g.group in groups) for v in basemesh.data.vertices])
    return triangles[(weight > 0)[triangles].any(1)], weight > 0


class EyeSide:
    """Topologia del ojo izquierdo: lazo limpio (sin orejas), bolsa, anillos de piel y operadores armonicos."""

    def __init__(self, rim, head, points, anime):
        self.ring_all = _ordered_ring(points, rim, 1.0)
        tris = [tuple(int(v) for v in t) for t in head]
        center = anime[self.ring_all].mean(0)
        near = [t for t in tris if max(np.linalg.norm(anime[v] - center) for v in t) < 0.075]
        blocked = {_edge(self.ring_all[i], self.ring_all[(i + 1) % len(self.ring_all)]) for i in range(len(self.ring_all))}
        by_edge = {}
        for n, t in enumerate(near):
            for k in range(3):
                by_edge.setdefault(_edge(t[k], t[(k + 1) % 3]), []).append(n)
        seed = min(range(len(near)), key=lambda n: np.linalg.norm(anime[list(near[n])].mean(0) - center))
        seen, stack = {seed}, [seed]
        while stack:
            t = near[stack.pop()]
            for k in range(3):
                e = _edge(t[k], t[(k + 1) % 3])
                if e not in blocked:
                    for other in by_edge[e]:
                        if other not in seen:
                            seen.add(other)
                            stack.append(other)
        rim_set, position = set(self.ring_all), {v: i for i, v in enumerate(self.ring_all)}
        ears = {n for n, t in enumerate(near) if n not in seen and all(v in rim_set for v in t)}
        tips = set()
        for n in ears:  # triangulos de piel con los 3 vertices en el lazo: sus puntas pasan a la bolsa
            ids = sorted(position[v] for v in near[n])
            tips.update(range(ids[0] + 1, ids[2]))
        self.loop = [v for i, v in enumerate(self.ring_all) if i not in tips]
        self.bag_adj = _adjacency([near[n] for n in sorted(seen | ears)])
        self.skin_adj = _adjacency([near[n] for n in range(len(near)) if n not in seen and n not in ears])
        loop_set = set(self.loop)
        self.inner = sorted(v for v in self.bag_adj if v not in loop_set)
        inner_set = set(self.inner)
        self.ring = {v: 0 for v in self.loop}
        now = list(self.loop)
        for step in range(1, 16):
            following = []
            for v in now:
                for o in sorted(self.skin_adj.get(v, ())):
                    if o not in self.ring and o not in inner_set:
                        self.ring[o] = step
                        following.append(o)
            now = following
        self.crown = sorted(v for v, r in self.ring.items() if 1 <= r <= RINGS)
        self.outer = sorted(v for v, r in self.ring.items() if r == RINGS + 1)
        self.bag_op = _harmonic(self.inner, self.bag_adj)
        allowed = set(self.loop) | set(self.crown) | set(self.outer)
        self.crown_op = _harmonic(self.crown, {v: [o for o in self.skin_adj[v] if o in allowed] for v in self.crown})
        self.soft = None

    def frame(self, g):
        c = g[self.ring_all].mean(0)
        pts = g[self.ring_all] - c
        n = np.cross(pts, np.roll(pts, -1, axis=0)).sum(0)
        n /= np.linalg.norm(n)
        if n[2] < 0.0:
            n = -n
        u = np.cross((0.0, 1.0, 0.0), n)
        u /= np.linalg.norm(u)
        return c, u, np.cross(n, u), n

    def solve(self, anime):
        """Bolsa y corona en el plano del lazo: la corona, en (angulo, radio relativo al lazo, altura)."""
        g = to_godot(anime)
        c, u, v, n = self.frame(g)
        basis = np.stack((u, v, n))
        out = (g - c) @ basis.T
        loop_set = set(self.loop)
        for _ in range(EYE_PASSES):
            for w in self.inner:
                out[w, :2] = out[list(self.bag_adj[w]), :2].mean(0)
        poly = [tuple(out[w, :2]) for w in self.loop]
        cc = (sum(q[0] for q in poly) / len(poly), sum(q[1] for q in poly) / len(poly))
        ang, rho, height = {}, {}, {}
        for w in self.loop + self.outer + self.crown:
            q = out[w]
            ang[w] = math.atan2(q[1] - cc[1], q[0] - cc[0])
            r = _poly_radius(poly, cc, ang[w])
            rho[w] = 1.0 if w in loop_set else max(math.hypot(q[0] - cc[0], q[1] - cc[1]) / r, 1.01)
            height[w] = float(q[2])
        near = {w: [o for o in self.skin_adj[w] if o in ang] for w in self.crown}
        for _ in range(EYE_PASSES):
            for w in self.crown:
                ids = near[w]
                ang[w] += sum((ang[o] - ang[w] + math.pi) % TAU - math.pi for o in ids) / len(ids)
                rho[w] = sum(rho[o] for o in ids) / len(ids)
                height[w] = sum(height[o] for o in ids) / len(ids)
        for w in self.crown:
            r = _poly_radius(poly, cc, ang[w]) * rho[w]
            out[w] = (cc[0] + r * math.cos(ang[w]), cc[1] + r * math.sin(ang[w]), height[w])
        result = g.copy()
        ids = self.inner + self.crown
        result[ids] = c + out[ids] @ basis
        free, border, matrix = self.bag_op  # la bolsa, detras de la membrana del lazo (Z de mundo: la UV no cambia)
        result[free, 2] = np.minimum(result[free, 2], matrix @ result[border, 2] - BAG_MARGIN)
        return from_godot(result)

    def soft_zone(self, points):
        """Piel a menos de SOFT_RADIUS del lazo, en su plano: (ids, f, ids a, ids b, t). f = 1 en el lazo y 0 en el radio."""
        if self.soft is None:
            g = to_godot(points)
            c, u, v, _ = self.frame(g)
            local = (g - c) @ np.stack((u, v)).T
            ids = np.array(sorted(w for w, r in self.ring.items() if r >= 1))
            loop = np.array(self.loop)
            a, b = local[loop], local[np.roll(loop, -1)]
            e = b - a
            t = np.clip(((local[ids][:, None, :] - a) * e).sum(2) / (e * e).sum(1), 0.0, 1.0)
            d = np.linalg.norm(local[ids][:, None, :] - (a + t[..., None] * e), axis=2)
            best = d.argmin(1)
            row = np.arange(len(ids))
            dist, frac = d[row, best], t[row, best]
            keep = dist < SOFT_RADIUS
            x = dist[keep] / SOFT_RADIUS
            self.soft = (ids[keep], 1.0 - x * x * (3.0 - 2.0 * x), loop[best[keep]], np.roll(loop, -1)[best[keep]], frac[keep])
        return self.soft


class EyeFit:
    """La cuenca corregida con los dos ojos, en el estado anime (preset), y las formas de ojo que la respetan."""

    def __init__(self, basemesh):
        import formas_propias as fp  # aqui y no arriba: formas_propias importa este archivo
        self.points, self.edges, self.zones = mesh_head(basemesh)
        triangles = np.asarray(fp.mesh_arrays(basemesh)[2])
        self.head, self.in_head = head_triangles(basemesh, triangles)
        self.mirror = np.asarray(fp.mirror_map(self.points))
        self.mouth = mouth_bag(self.points, self.head, self.edges, self.zones, self.mirror)  # paso 9.6
        self.kept = self._kept_zones()
        self.shapes = self._socket_shapes()
        before = self.points + sum(self.shapes[n] for n in PRESET_FACE)
        self.left = EyeSide(self.zones["rim_l"], self.head, self.points, before)
        solved = self.left.solve(before)
        self.anime = before.copy()
        ids = np.array(self.left.inner + self.left.crown)
        self.anime[ids] = solved[ids]
        self.anime[self.mirror[ids]] = solved[ids] * FLIP
        self.shapes["cuenca_plana"] = self.shapes["cuenca_plana"] + self.anime - before

    def _kept_zones(self):
        rims = set(self.zones["rim_l"] + self.zones["rim_r"] + self.zones["inner_l"] + self.zones["inner_r"])
        kept = dict(self.zones)
        kept["eyes"] = [v for v in self.zones["eyes"] if v not in rims]
        kept["brow"] = [v for v in self.zones["brow"] if v not in rims]
        return kept

    def _opening(self, inner):
        """El lazo en la elipse sobre la cara aplanada, y la bolsa como membrana."""
        points, edges = self.points, self.edges
        flat = points + deform(points, edges, self.zones, [("cuenca_plana", "eyes", FULL, 0.0)])["cuenca_plana"]
        tree = BVHTree.FromPolygons([tuple(map(float, p)) for p in flat], [tuple(int(i) for i in t) for t in self.head],
                                    all_triangles=True)
        ring = _ordered_ring(points, self.zones["rim_l"], 1.0)
        loop = points[ring]
        arcs = np.linalg.norm(np.roll(loop, -1, axis=0) - loop, axis=1)
        angle = TAU * np.concatenate(([0.0], np.cumsum(arcs)[:-1])) / arcs.sum()
        x = loop[:, 0].mean() + HALF_W * np.cos(angle)
        z = loop[:, 2].mean() + HALF_H * np.sin(angle)
        start_y = float(flat[:, 1].min() - 0.1)
        y = np.empty(len(ring))
        for i in range(len(ring)):
            hit = tree.ray_cast((float(x[i]), start_y, float(z[i])), (0.0, 1.0, 0.0), 1.0)
            y[i] = hit[0][1] if hit[0] is not None else loop[i, 1]
        for _ in range(5):
            y = (np.roll(y, 1) + 2.0 * y + np.roll(y, -1)) / 4.0
        moved = points.copy()
        moved[ring] = np.column_stack((x, y, z))
        mask = np.zeros(len(points), bool)
        mask[inner] = True
        return relax(moved, edges, mask, FULL, 0.0), ring

    def _with_wall(self, opening, ring, inner, right, wall):
        """La bolsa con su fondo a BAG_DEPTH; el ojo derecho es el reflejo del izquierdo."""
        moved = opening.copy()
        rx, rz = moved[inner, 0] - moved[ring, 0].mean(), moved[inner, 2] - moved[ring, 2].mean()
        t = np.clip((1.0 - np.hypot(rx / HALF_W, rz / HALF_H)) / wall, 0.0, 1.0)
        weight = t * t * (3.0 - 2.0 * t)
        plane = _rim_plane(moved[ring])
        moved[inner, 1] = (1.0 - weight) * moved[inner, 1] + weight * (_surface(plane, moved[inner, 0], moved[inner, 2]) + BAG_DEPTH)
        moved[right] = moved[self.mirror[right]] * FLIP
        return moved

    def _socket_shapes(self):
        """Formas de STEPS sobre la cuenca nueva: cuenca_plana lleva la apertura, la bolsa y las cejas."""
        points, edges, zones, kept = self.points, self.edges, self.zones, self.kept
        inner = np.array(zones["inner_l"])
        right = np.array(zones["rim_r"] + zones["inner_r"])
        opening, ring = self._opening(inner)
        lid = np.isin(np.arange(len(points)), kept["eyes"])
        spread = points + relax(self._with_wall(opening, ring, inner, right, WALL_LID) - points, edges, lid, FULL, 0.0)
        bag = np.array(zones["inner_l"] + zones["inner_r"])
        spread[bag] = self._with_wall(opening, ring, inner, right, WALL_BAG)[bag]
        socket = spread + deform(spread, edges, kept, [("cuenca_plana", "brow", 3, 0.0)])["cuenca_plana"]
        deltas = deform(socket, edges, kept, [s for s in STEPS if s[0] != "cuenca_plana"], (self.mouth,))  # 9.6
        deltas["cuenca_plana"] = socket - points
        return deltas

    def _extend(self, delta):
        """El movimiento del lazo y del anillo 6, repartido por la bolsa y la corona de cada ojo."""
        out = delta.copy()
        for side in (None, self.mirror):
            for free, border, matrix in (self.left.bag_op, self.left.crown_op):
                f, b = (free, border) if side is None else (side[free], side[border])
                out[f] = matrix @ out[b]
        return out

    def _soften(self, delta):
        """Lineal: junto al lazo cada punto sigue al punto del lazo mas cercano; a SOFT_RADIUS, vuelve a su movimiento."""
        out = delta.copy()
        zone, f, a, b, t = self.left.soft_zone(self.anime)
        free, border, matrix = self.left.bag_op
        for side in (None, self.mirror):
            z, i, j, bf, bb = (zone, a, b, free, border) if side is None else (side[zone], side[a], side[b], side[free], side[border])
            target = (1.0 - t)[:, None] * delta[i] + t[:, None] * delta[j]
            out[z] = (1.0 - f)[:, None] * delta[z] + f[:, None] * target
            out[bf] = matrix @ delta[bb]
        return out

    def _own_delta(self, name):
        kind, value = OWN_EYE[name]
        g = to_godot(self.anime)
        _, _, _, n = self.left.frame(g)
        loop = np.array(self.left.loop)
        p = g[loop]
        mid = p.mean(0)
        if kind == "size":
            rel = p - mid
            world = value * (rel - (rel @ n)[:, None] * n)
        elif kind == "tall":
            world = np.zeros_like(p)
            world[:, 1] = value * (p[:, 1] - mid[1])
        else:
            a = math.radians(value)
            rx, ry = p[:, 0] - mid[0], p[:, 1] - mid[1]
            world = np.column_stack((rx * math.cos(a) - ry * math.sin(a) - rx, rx * math.sin(a) + ry * math.cos(a) - ry, np.zeros(len(p))))
        delta = np.zeros_like(self.anime)
        delta[loop] = from_godot(world)
        delta[self.mirror[loop]] = from_godot(world) * FLIP
        return self._extend(delta)

    def face_delta(self, raw):
        """Paso 9.7.1: un desplazamiento de la cara (una unidad ARKit) con la bolsa del ojo siguiendo al lazo y la piel
        de alrededor suavizada, como las formas de ojo de MakeHuman (eye_delta)."""
        return self._soften(self._extend(raw))

    def blink_delta(self, state, side):
        """Paso 9.7.1: parpadeo propio del ojo side ("l" o "r") sobre state (puntos, en el espacio de fit). Cada punto
        del arco de arriba del lazo baja hasta el del arco de abajo con su misma x en el plano del ojo, BLINK_GAP por
        encima; las esquinas y el arco de abajo no se mueven. El derecho se calcula sobre el reflejo (mismo ojo)."""
        flipped = side == "r"
        g = to_godot(state[self.mirror] * FLIP if flipped else state)
        c, u, v, _ = self.left.frame(g)
        loop = np.array(self.left.loop)
        p = g[loop]
        lower = p[LOWER_ARC]
        xs = (lower - c) @ u
        world = np.zeros_like(p)
        for k in UPPER_ARC[1:-1]:
            target = _line_point(lower, xs, float((p[k] - c) @ u))
            if target is not None:
                world[k] = target + v * BLINK_GAP - p[k]
        delta = np.zeros_like(state)
        delta[loop] = from_godot(world)
        if flipped:
            mirrored = np.zeros_like(delta)
            mirrored[self.mirror] = delta * FLIP
            delta = mirrored
        return self.face_delta(delta)

    def eye_delta(self, name, raw):
        """raw: el desplazamiento de la piel que da MakeHuman para esa forma."""
        return self._soften(self._own_delta(name) if name in OWN_EYE else self._extend(raw * EYE_CLIP.get(name, 1.0)))

    def fix_eye_shapes(self, shapes):
        """Sustituye en shapes {forma: (desplazamiento, huesos)} las formas de ojo: los huesos no cambian."""
        for name, (delta, joints) in list(shapes.items()):
            if "*" not in name and name.startswith(EYE_SHAPES):
                shapes[name] = (self.eye_delta(name, delta), joints)

    def mask(self):
        """Mascara del contorno, por vertice: 1 en bolsa, lazo y anillos 1-5; 0,5 en el anillo 6; 0 en el resto."""
        values = np.zeros(len(self.points))
        ids = np.array(self.left.loop + self.left.inner + self.left.crown)
        for side in (ids, self.mirror[ids]):
            values[side] = 1.0
        outer = np.array(self.left.outer)
        values[outer] = values[self.mirror[outer]] = 0.5
        return values

    def right_loop(self):
        loop = self.left.loop
        return [int(self.mirror[loop[(len(loop) - i) % len(loop)]]) for i in range(len(loop))]


def add_mask_uv(basemesh, values):
    """Guarda la mascara del contorno en una segunda capa UV (TEXCOORD_1). Va por vertice: no parte ningun vertice."""
    mesh = basemesh.data
    layer = mesh.uv_layers.new(name="mascara_ojo")
    corners = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", corners)
    uv = np.zeros(len(corners) * 2, dtype=np.float32)
    uv[0::2] = values[corners]
    layer.uv.foreach_set("vector", uv)
    mesh.uv_layers.active_index = 0


def _accessor(gltf, data, index):
    """Valores de un accessor del .glb como array de numpy (tambien los dispersos, como las formas)."""
    accessor = gltf["accessors"][index]
    kind = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}[accessor["componentType"]]
    size = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
    if "bufferView" in accessor:
        view = gltf["bufferViews"][accessor["bufferView"]]
        if view.get("byteStride", size * kind().nbytes) != size * kind().nbytes:
            raise ValueError("accessor intercalado")
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        out = np.frombuffer(data, kind, accessor["count"] * size, start).reshape(-1, size).copy()
    else:
        out = np.zeros((accessor["count"], size), kind)
    sparse = accessor.get("sparse")
    if sparse:
        ids, values = sparse["indices"], sparse["values"]
        id_kind = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32}[ids["componentType"]]
        id_start = gltf["bufferViews"][ids["bufferView"]].get("byteOffset", 0) + ids.get("byteOffset", 0)
        value_start = gltf["bufferViews"][values["bufferView"]].get("byteOffset", 0) + values.get("byteOffset", 0)
        where = np.frombuffer(data, id_kind, sparse["count"], id_start)
        out[where] = np.frombuffer(data, kind, sparse["count"] * size, value_start).reshape(-1, size)
    return out


def _line_point(points, xs, x):
    """Punto de la polilinea points (3D) con coordenada x (xs: la de cada punto); None si x queda fuera."""
    for i in range(len(points) - 1):
        if (x - xs[i]) * (x - xs[i + 1]) <= 0.0 and xs[i] != xs[i + 1]:
            return points[i] + (points[i + 1] - points[i]) * (x - xs[i]) / (xs[i + 1] - xs[i])
    return None


def _line_y(line, x):
    """Altura del poligono abierto line en x (el primer tramo que contiene x); nan si queda fuera."""
    for i in range(len(line) - 1):
        a, b = line[i], line[i + 1]
        if (x - a[0]) * (x - b[0]) <= 0.0 and a[0] != b[0]:
            return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
    return float("nan")


def _style_normals(anime, weights, joints, head, ids):
    """Normales del estilo en ids (StyleNormals.face: elipsoide de la caja de la cabeza), en el estado anime."""
    head_weight = (weights * (joints == head)).sum(1)
    box = anime[head_weight > 0.5]
    low, high = box.min(0), box.max(0)
    center, radii = (low + high) / 2.0, (high - low) / 2.0
    offset = anime[ids] - center
    r = np.tile(radii, (len(ids), 1))
    r[offset[:, 2] > 0.0, 2] *= 0.6  # StyleNormals.FACE_DEPTH
    ellipsoid = offset / (r * r)
    return ellipsoid / np.linalg.norm(ellipsoid, axis=1)[:, None], head_weight


def _style_normal(anime, weights, joints, head, rim):
    """La normal del estilo en el lazo: la media de las del elipsoide, en el estado anime."""
    normals, head_weight = _style_normals(anime, weights, joints, head, rim)
    total = normals.sum(0)
    return total / np.linalg.norm(total), float(head_weight[rim].min())


def _hit(point, normal, surface, ray_from=RAY_FROM):
    """Primera cara visible de surface desde fuera: rayo desde point + normal * ray_from hacia -normal (Moller-Trumbore).
    surface: {"tris": (T, 3) indices del .glb, "pos": posiciones, "out": normal de cada cara hacia fuera}.
    Devuelve (distancia, indices, baricentricas, normal de la cara) o None si no toca ninguna."""
    tris, pos = surface["tris"], surface["pos"]
    origin, direction = point + normal * ray_from, -normal
    a, b, c = pos[tris[:, 0]], pos[tris[:, 1]], pos[tris[:, 2]]
    e1, e2 = b - a, c - a
    h = np.cross(direction, e2)
    det = (e1 * h).sum(1)
    ok = np.abs(det) > 1e-14
    det = np.where(ok, det, 1.0)
    s = origin - a
    u = (s * h).sum(1) / det
    q = np.cross(s, e1)
    v = (q * direction).sum(1) / det
    t = (e2 * q).sum(1) / det
    ok &= (u >= 0.0) & (v >= 0.0) & (u + v <= 1.0) & (t > 0.0) & ((surface["out"] * direction).sum(1) < 0.0)
    if not ok.any():
        return None
    best = np.flatnonzero(ok)[np.argmin(t[ok])]
    return t[best], tris[best], np.array((1.0 - u[best] - v[best], u[best], v[best])), surface["out"][best]


def _support(point, normal, surfaces, ray_from=RAY_FROM, max_snap=MAX_SNAP):
    """La primera cara visible entre varias superficies (piel y blanco): (superficie, indices, baricentricas, normal),
    o None si no hay ninguna o queda a mas de max_snap del punto. ray_from y max_snap propios: la banda de la ceja."""
    hits = [(hit, surface) for surface in surfaces for hit in [_hit(point, normal, surface, ray_from)] if hit is not None]
    if not hits:
        return None
    hit, surface = min(hits, key=lambda pair: pair[0][0])
    return None if abs(hit[0] - ray_from) > max_snap else (surface, *hit[1:])


def _faces(tris, pos):
    """Caras con su normal delantera por el orden de sus vertices (glTF: antihorario), como las ve Godot (cull_back):
    una cara vista por detras no tapa nada."""
    face = np.cross(pos[tris[:, 1]] - pos[tris[:, 0]], pos[tris[:, 2]] - pos[tris[:, 0]])
    face /= np.maximum(np.linalg.norm(face, axis=1), 1e-20)[:, None]
    return {"tris": tris, "pos": pos, "out": face}


def eye_strip(arc, anime, style, rows, center, surfaces, ahead, tail=0):
    """Tira sobre el arco del lazo (de la esquina interior a la exterior), mas tail columnas de cola.
    Cada vertice: lazo[k] + frente[k] * fila (+ la cola), apoyado de frente (rayo por ahead, la normal del ojo) en la
    primera superficie visible (piel o blanco del ojo) y elevado STRIP_LIFT. La fila 0 es el propio lazo. Si no hay superficie,
    queda recto. uv = (u por longitud de arco, de 0 a 1 en la esquina exterior; fila en metros)."""
    points = anime[arc]
    lengths = np.concatenate(([0.0], np.cumsum(np.linalg.norm(np.diff(points, axis=0), axis=1))))
    total = float(lengths[-1])
    tail_dir = (points[-1] - points[-2]) / np.linalg.norm(points[-1] - points[-2])
    ids, bary, offset, uv = [], [], [], []
    for k in range(len(arc) + tail):
        at = min(k, len(arc) - 1)
        j = k - at  # columna de cola (0 sobre el lazo)
        tangent = points[min(at + 1, len(arc) - 1)] - points[max(at - 1, 0)]
        front = np.cross(tangent, style[at])
        front /= np.linalg.norm(front)
        if np.dot(front, points[at] - center) < 0.0:
            front = -front
        for row in rows:
            target = points[at] + front * (max(row, 0.0) if j else row) + tail_dir * TAIL_STEP * j
            hit = _support(target, ahead, surfaces) if row != 0.0 or j else None
            if hit is None:
                ids.append([int(arc[at])] * 3)
                bary.append([1.0, 0.0, 0.0])
                offset.append(target - points[at])
            else:
                on, corners, weights, out = hit
                ids.append([int(i) for i in corners])
                bary.append(list(weights))
                offset.append(on["lift"][corners].T @ weights + out * STRIP_LIFT)
            uv.append([(lengths[at] + j * TAIL_STEP) / total, row])
    return {"ids": ids, "bary": [[round(float(x), 6) for x in b] for b in bary],
            "offset": [[round(float(x), 8) for x in o] for o in offset],
            "uv": [[round(float(x), 7) for x in t] for t in uv], "filas": len(rows), "largo": round(total, 7)}


def brow_frame(anime, rim, upper, center, ahead):
    """Caja de la banda de la ceja (AC.6c), desde el marco del ojo: (lado, arriba, (s0, s1), (h0, h1)) en metros desde
    center. lado: de la esquina interior a la exterior, sin la parte de ahead; arriba: ahead x lado, hacia +Y."""
    inner, outer = anime[rim[upper[0]]], anime[rim[upper[-1]]]
    side = outer - inner
    side = side - ahead * np.dot(side, ahead)
    side /= np.linalg.norm(side)
    up = np.cross(ahead, side)
    up /= np.linalg.norm(up)
    if up[1] < 0.0:
        up = -up
    top = float(((anime[rim] - center) @ up).max())
    return side, up, (float((inner - center) @ side) - BROW_BEFORE, float((outer - center) @ side) + BROW_AFTER), \
        (top + BROW_LOW, top + BROW_HIGH)


def brow_band(center, frame, ahead, skin, columns=BROW_COLUMNS, rows=BROW_ROWS):
    """Banda de la ceja (AC.6c): columnas de la parte interior a la exterior, filas de abajo arriba, apoyadas en la piel
    con un rayo por ahead (la normal del ojo) y elevadas STRIP_LIFT. Mismo formato que eye_strip; uv = (u de 0 a 1,
    metros sobre la base de la banda); largo = ancho de la banda. Si un punto no encuentra piel, para (ValueError)."""
    side, up, (s0, s1), (h0, h1) = frame
    ids, bary, offset, uv = [], [], [], []
    for k in range(columns):
        s = s0 + (s1 - s0) * k / (columns - 1)
        for r in range(rows):
            h = h0 + (h1 - h0) * r / (rows - 1)
            hit = _support(center + side * s + up * h, ahead, (skin,), BROW_RAY_FROM, BROW_MAX_SNAP)
            if hit is None:
                raise ValueError("Banda de la ceja: el punto (%d, %d) no encuentra piel" % (k, r))
            _, corners, weights, out = hit
            ids.append([int(i) for i in corners])
            bary.append(list(weights))
            offset.append(out * STRIP_LIFT)  # la piel no tiene elevacion propia
            uv.append([k / (columns - 1), h - h0])
    return {"ids": ids, "bary": [[round(float(x), 6) for x in b] for b in bary],
            "offset": [[round(float(x), 8) for x in o] for o in offset],
            "uv": [[round(float(x), 7) for x in t] for t in uv], "filas": rows, "largo": round(s1 - s0, 7)}


def _brows(anime, tris, eyes, bag):
    """Las dos bandas de la ceja (AC.6c). eyes: {lado: (lazo, arco_superior, centro, normal)}. La derecha es el reflejo
    de la izquierda (caja, ejes y direccion del rayo), apoyada en su propia piel; las columnas siguen de dentro afuera."""
    in_bag = np.zeros(len(anime), bool)
    in_bag[bag] = True
    rim, upper, center, ahead = eyes["l"]
    side, up, s_range, h_range = brow_frame(anime, rim, upper, center, ahead)
    frames = {"l": (center, (side, up, s_range, h_range), ahead),
              "r": (center * FLIP, (side * FLIP, up * FLIP, s_range, h_range), ahead * FLIP)}
    out = {}
    for name, (c, frame, normal) in frames.items():
        near = np.linalg.norm(anime[tris[:, 0]] - c, axis=1) < BROW_RADIUS
        skin = _faces(tris[near & ~in_bag[tris].all(1)], anime)
        out[name] = brow_band(c, frame, normal, skin)
    return out


def eye_data(fit, glb_path, preset_values):
    """Contenido de ojos.json: indices del .glb y datos fijos de cada ojo, en el estado anime (FORMATO.md)."""
    from mathutils import kdtree
    gltf, rest = ed._glb_parts(glb_path)
    data = rest[8:]
    mesh = gltf["meshes"][0]
    primitive = mesh["primitives"][0]
    base = _accessor(gltf, data, primitive["attributes"]["POSITION"]).astype(float)
    names = mesh["extras"]["targetNames"]
    anime = base.copy()
    for key, value in preset_values.items():
        if key in names and value:
            anime += value * _accessor(gltf, data, primitive["targets"][names.index(key)]["POSITION"])
    joints = _accessor(gltf, data, primitive["attributes"]["JOINTS_0"]).astype(int)
    tris = _accessor(gltf, data, primitive["indices"]).astype(int).reshape(-1, 3)
    weights = _accessor(gltf, data, primitive["attributes"]["WEIGHTS_0"])
    weights = weights.astype(float) / (1.0 if weights.dtype == np.float32 else np.iinfo(weights.dtype).max)
    bones = [gltf["nodes"][n]["name"] for n in gltf["skins"][0]["joints"]]
    head = bones.index("Head")
    tree = kdtree.KDTree(len(base))
    for i, q in enumerate(base):
        tree.insert(q, i)
    tree.balance()
    wanted = to_godot(fit.points)

    def copies(v):
        return sorted(hit[1] for hit in tree.find_range(wanted[v], 1e-5))

    out = {"version": 1}
    free, border, matrix = fit.left.bag_op
    lift_left = matrix @ to_godot(fit.anime)[border, 2] - to_godot(fit.anime)[free, 2]
    loops = {"l": fit.left.loop, "r": fit.right_loop()}
    corners = {"l": [0, 20], "r": [0, 16]}
    upper = {"l": list(range(20, -1, -1)), "r": list(range(16, 36)) + [0]}
    lower = {"l": list(range(20, 36)) + [0], "r": list(range(16, -1, -1))}
    frames = {}  # AC.6c: marco de cada ojo para la banda de la ceja
    for side in "lr":
        loop = loops[side]
        inner = free if side == "l" else fit.mirror[free]
        lift = {int(v): float(z) for v, z in zip(inner, lift_left)}
        rim = np.array([copies(v)[0] for v in loop])
        center = anime[rim].mean(0)
        normal, smallest = _style_normal(anime, weights, joints, head, rim)
        if smallest < 0.999:
            raise ValueError("El lazo no va entero con el hueso Head: la normal de estilo no es la del elipsoide")
        top = (anime[rim[upper[side]]] - center)[:, :2]
        bottom = (anime[rim[lower[side]]] - center)[:, :2]
        bag, uv, height, rise = [], [], [], []
        for v in list(loop) + [int(x) for x in inner]:
            for copy in copies(v):
                p = anime[copy, :2] - center[:2]
                y_top, y_bottom = _line_y(top, p[0]), _line_y(bottom, p[0])
                h = np.clip((p[1] - y_bottom) / max(y_top - y_bottom, 0.0001), 0.0, 1.0)
                bag.append(int(copy))
                uv.append([round(float(p[0]), 7), round(float(p[1]), 7)])
                height.append(round(float(h), 5))
                rise.append(round(lift.get(int(v), 0.0), 7))
        order = np.argsort(bag)
        frames[side] = (rim, upper[side], center, normal)
        strips = _strips(anime, tris, (weights, joints, head), rim, (upper[side], lower[side]), center,
                         dict(zip(bag, rise)))
        out[side] = {**strips, "lazo": [int(i) for i in rim], "esquinas": corners[side], "arco_superior": upper[side], "arco_inferior": lower[side],
                     "bolsa": [bag[i] for i in order], "uv": [uv[i] for i in order], "altura": [height[i] for i in order],
                     "elevacion": [rise[i] for i in order], "centro": [round(float(c), 7) for c in center],
                     "normal": [round(float(c), 7) for c in normal]}
    for side, band in _brows(anime, tris, frames, out["l"]["bolsa"] + out["r"]["bolsa"]).items():
        out[side]["ceja"] = band
    return out


def _strips(anime, tris, bones, rim, arcs, center, rise):
    """Las tres tiras de un ojo (AC.6a): linea de arriba con su cola, linea de abajo y pliegue."""
    in_bag = np.zeros(len(anime), bool)
    in_bag[list(rise)] = True
    bag_tris = tris[in_bag[tris].all(1)]
    near = np.linalg.norm(anime[tris[:, 0]] - center, axis=1) < SKIN_RADIUS
    skin = _faces(tris[near & ~in_bag[tris].all(1)], anime)
    eye_normal = _style_normal(anime, *bones, rim)[0]
    skin["lift"] = np.zeros((len(anime), 3))
    lift = np.zeros((len(anime), 3))
    for v, z in rise.items():
        lift[v, 2] = z  # el blanco va subido a la membrana del lazo (elevacion)
    bag = _faces(bag_tris, anime + lift)
    bag["lift"] = lift
    upper, lower = rim[arcs[0]], rim[arcs[1]]
    style_upper = _style_normals(anime, *bones, upper)[0]
    style_lower = _style_normals(anime, *bones, lower)[0]
    surfaces = (skin, bag)
    return {"tira_superior": eye_strip(upper, anime, style_upper, LINE_ROWS, center, surfaces, eye_normal, TAIL),
            "tira_inferior": eye_strip(lower, anime, style_lower, LOWER_ROWS, center, surfaces, eye_normal),
            "pliegue": eye_strip(upper, anime, style_upper, CREASE_ROWS, center, surfaces, eye_normal)}


def feature_shapes(basemesh, fit=None):
    """{forma: desplazamiento de cada vertice, en el espacio de la malla}, con la cuenca del ojo anime (AC.3b)."""
    deltas = (fit or EyeFit(basemesh)).shapes
    to_local = np.linalg.inv(np.array(basemesh.matrix_world)[:3, :3])
    return {name: delta @ to_local.T for name, delta in deltas.items()}


def main():
    out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
    basemesh = ed.build_base()[0]
    points, _, zones = mesh_head(basemesh)
    deltas = EyeFit(basemesh).shapes
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
