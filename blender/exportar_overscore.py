# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso RE.1c: exporta prendas CC0 de OverScore Proxy 1.5 como piezas que siguen al cuerpo.

Uso: blender -b --disable-autoexec -P blender/exportar_overscore.py -- godot/datos/humana godot/packs/overscore \
     recursos_externos/OGA_overscore_proxy/proxy_1.5.blend [id ...]
Sin ids exporta ENTRAN, las que pasan todos los límites (las demás de GARMENTS se pueden medir pidiéndolas por su id).
Escribe en <pack> un .glb por prenda (con su .import) y pack.json. Si una medida se pasa de su límite, no escribe nada.

El cuerpo de OverScore se registra sobre el nuestro (ICP con campo gaussiano) y cada prenda se lleva con ese campo.
Después se infla lo justo para que la piel no asome (en neutro y en poses de prueba), las de torso suben sobre los 3
shorts, se aplican Mirror y Solidify, y pesos y formas salen de la piel (mismos nombres que cuerpo.glb). Sin materiales: el color lo pone el programa. Todo en pose A, como cuerpo.glb.
"""
import hashlib
import math
import os
import sys
from types import SimpleNamespace

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import exportar_datos as ed  # noqa: E402
import exportar_quaternius as eq  # noqa: E402

SOURCE_SHA256 = "ac0dcdb2979dab7311e6d95ce6b1b20b118ef80d4de1f69aa9e88f733111b5ea"
GARMENTS = {  # id: (objeto del .blend, nombre, ranura)
    "os_golf_shorts": ("Golf Shorts", "Shorts de golf", "ropa_piernas"),
    "os_jean_shorts": ("Jean Shorts", "Shorts vaqueros", "ropa_piernas"),
    "os_short_shorts": ("Short Shorts", "Shorts muy cortos", "ropa_piernas"),
    "os_scallop_tshirt": ("Scallop Trim T-Shirt", "Camiseta con ribete", "ropa_torso"),
    "os_vneck_top": ("V-Neck Top", "Camiseta de pico", "ropa_torso"),
    "os_scrubs_top": ("Scrubs Top", "Casaca sanitaria", "ropa_torso"),
    "os_sports_jersey": ("Sports Jersey", "Camiseta deportiva", "ropa_torso"),
    "os_tank_top": ("Tank Top", "Camiseta de tirantes", "ropa_torso"),
    "os_camisole_top": ("Camisole Top", "Top de tirantes finos", "ropa_torso"),
    "os_hoodie_down": ("Hoodie with Hood Down", "Sudadera con capucha", "ropa_torso"),
    "os_short_sleeve_sweatshirt": ("Short-Sleeve Sweatshirt", "Sudadera de manga corta", "ropa_torso"),
    "os_turtleneck_sweater": ("Turtleneck Sweater", "Suéter de cuello alto", "ropa_torso"),
    "os_long_sleeve_top": ("Long Sleeve Athletic Top", "Camiseta deportiva de manga larga", "ropa_torso"),
}
ENTRAN = ("os_golf_shorts", "os_short_shorts", "os_vneck_top", "os_scrubs_top", "os_tank_top", "os_camisole_top")
PACK = {"formato": "gamemolde-pack", "version": 1, "id": "overscore", "nombre": "Pack OverScore",
        "autor": "overscore_media", "licencia": "CC0-1.0",
        "origen": "https://opengameart.org/content/overscore-proxy-modular-low-poly-female-character-creation-set"}
COLOR = [0.3, 0.32, 0.4]  # el de la ropa de MakeHuman
SIGMAS = (0.10, 0.07, 0.05, 0.035, 0.025, 0.018)  # metros: radios del registro, de mayor a menor
ITERATIONS = 4
FIELD_K = 12  # nodos del registro que mueven cada vértice de la prenda
FIELD_SIGMA = 0.03  # metros
SMOOTH_PASSES = 8
SPREAD = 2  # pasadas que reparten el inflado a los vecinos
MARGIN = 0.003  # metros: la piel queda al menos esto por debajo de la cara interior
MAX_PASSES = 80
MAX_INFLATE = 0.045  # metros: tope del inflado por vértice (sin él, una mano junto al puño lo dispara)
POSE_MARGIN = 0.001  # metros: hueco que se busca en las poses de prueba
POSE_PASSES = 12
GAP_PASSES = 12  # pasadas para recuperar el hueco que keep_half quita junto a la costura
LAYER_STEP = 0.0015  # metros por pasada: la prenda de torso sube sobre los shorts
LAYER_PASSES = 60
AXILLA = 0.06  # metros: tela a menos de esto del brazo y del tronco mezcla los pesos de ambos
ARM_BONES = ("UpperArm", "LowerArm", "Hand", "Thumb", "Index", "Middle", "Ring", "Little")
HAND_BONES = ("Hand", "Thumb", "Index", "Middle", "Ring", "Little")
LOWER_IDS = ("os_golf_shorts", "os_jean_shorts", "os_short_shorts")  # toda prenda de torso debe pasar por encima de las 3
TEST_POSES = {  # (hueso, eje del mundo, grados): movimientos típicos; solo el lado x > 0, Mirror copia el otro
    "ropa_piernas": [("LeftUpperLeg", "X", a) for a in (-40, 40)] + [("LeftUpperLeg", "Y", a) for a in (-15, 15)]
    + [("Spine", "X", a) for a in (-15, 15)] + [("Spine", "Z", a) for a in (-20, 20)],
    "ropa_torso": [("LeftUpperArm", "Y", a) for a in (-25, 25)] + [("LeftUpperArm", "X", a) for a in (-30, 30)]
    + [("Spine", "X", a) for a in (-15, 15)] + [("Spine", "Z", a) for a in (-20, 20)],
}
NEAR = 0.04  # metros: la piel de esta franja alrededor de la prenda cuenta para inflar
BELOW = 0.02  # metros: el rayo sale de esto por debajo de la piel
ABOVE = 0.07  # metros: tela más lejos que esto no cuenta como encima
HEM_CLEAR = 0.025  # metros: el hueco se mide en la piel a más de esto del borde de la tela
MIN_GAP = 0.0025  # PROVISIONAL: metros; OS04 midió 3,00 mm
UNDER_MAX = 2.0  # PROVISIONAL: % de vértices de tela bajo la piel; OS04 midió 1,06 %
UNDER_DEPTH = 0.001  # PROVISIONAL: metros; OS04 midió 0,25 mm
HEM_EXTRA = 0.010  # PROVISIONAL: metros que puede crecer el rango de altura del bajo; OS04 midió 3 mm


def vertex_normals(verts, tris):
    faces = np.cross(verts[tris[:, 1]] - verts[tris[:, 0]], verts[tris[:, 2]] - verts[tris[:, 0]])
    normals = np.zeros_like(verts)
    for k in range(3):
        np.add.at(normals, tris[:, k], faces)
    return normals / np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-12)


def mesh_arrays(mesh):
    verts = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", verts)
    tris = np.array([(p.vertices[0], p.vertices[k], p.vertices[k + 1])
                     for p in mesh.polygons for k in range(1, len(p.vertices) - 1)])
    return verts.reshape(-1, 3), tris


def neighbors_of(count, tris):
    found = [set() for _ in range(count)]
    for a, b, c in tris.tolist():
        found[a].update((b, c))
        found[b].update((a, c))
        found[c].update((a, b))
    return found


def kd_tree(points):
    tree = KDTree(len(points))
    for i, point in enumerate(points.tolist()):
        tree.insert(point, i)
    tree.balance()
    return tree


def nearest_points(tree, points):
    found = np.empty((len(points), 3))
    normals = np.empty((len(points), 3))
    for i, point in enumerate(points.tolist()):
        location, normal, _, _ = tree.find_nearest(Vector(point))
        found[i], normals[i] = location, normal
    return found, normals


def register(source, source_tris, skin, skin_tree):
    """Registro no rígido del cuerpo de OverScore sobre la piel: ICP con campo gaussiano de radio decreciente."""
    current = source.copy()
    sample = skin[::3]
    for sigma in SIGMAS:
        for _ in range(ITERATIONS):
            normals = vertex_normals(current, source_tris)
            location, skin_normal = nearest_points(skin_tree, current)
            target = location - current
            confidence = np.clip((normals * skin_normal).sum(1), 0.05, 1)
            tree = kd_tree(current)
            back, count = np.zeros_like(current), np.zeros(len(current))
            for point in sample.tolist():
                _, j, _ = tree.find(point)
                back[j] += np.array(point) - current[j]
                count[j] += 1
            has = count > 0
            target[has] = 0.5 * target[has] + 0.5 * back[has] / count[has][:, None]
            d2 = ((current[:, None, :] - current[None, :, :]) ** 2).sum(-1).astype(np.float32)
            kernel = np.exp(-d2 / (2 * sigma * sigma)) * confidence[None, :]
            current = current + (kernel @ target) / np.maximum(kernel.sum(1, keepdims=True), 1e-9)
    return current


def load_object(path, name):
    with bpy.data.libraries.load(path, link=False) as (_, target):
        target.objects = [name]
    obj = target.objects[0]
    bpy.context.scene.collection.objects.link(obj)
    return obj


def source_body(path, skin, skin_tree):
    """(cuerpo de OverScore colocado, su versión registrada, escala, desplazamiento)."""
    body = load_object(path, "Base Model")
    bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    verts, tris = mesh_arrays(evaluated.to_mesh())
    evaluated.to_mesh_clear()
    bpy.data.objects.remove(body)
    scale = (skin[:, 2].max() - skin[:, 2].min()) / (verts[:, 2].max() - verts[:, 2].min())
    shift = np.array([0.0, 0.0, -verts[:, 2].min() * scale])
    placed = verts * scale + shift
    band = (placed[:, 2] > 0.85) & (placed[:, 2] < 0.98) & (np.abs(placed[:, 0]) < 0.2)
    band_skin = (skin[:, 2] > 0.85) & (skin[:, 2] < 0.98) & (np.abs(skin[:, 0]) < 0.2)
    shift[1] = 0.5 * (skin[band_skin, 1].min() + skin[band_skin, 1].max()) - 0.5 * (placed[band, 1].min() + placed[band, 1].max())
    placed[:, 1] += shift[1]
    print(f"MEDIDA registro: escala {scale:.4f}; desplazamiento y {shift[1] * 1000:.1f} mm, z {shift[2] * 1000:.1f} mm")
    return placed, register(placed, tris, skin, skin_tree), scale, shift


def carry(points, source, moved):
    """Mueve cada punto con el campo del registro, promediando nodos del mismo lado."""
    side = np.nonzero(source[:, 0] >= -1e-4)[0]
    tree = kd_tree(source[side])
    out = np.empty_like(points)
    for n, point in enumerate(points.tolist()):
        found = tree.find_n(point, FIELD_K)
        distance = np.array([f[2] for f in found])
        weight = np.exp(-(distance * distance) / (2 * FIELD_SIGMA * FIELD_SIGMA)) + 1e-9
        out[n] = np.array(point) + (moved[side[[f[1] for f in found]]] * weight[:, None]).sum(0) / weight.sum()
    return out


def keep_half(verts, seam, floor):
    """La costura en x = 0; los demás, a más de floor, para que Mirror no los suelde con su copia."""
    verts[:, 0] = np.maximum(verts[:, 0], floor)
    verts[seam, 0] = 0.0
    return verts


def smooth_offset(original, placed, tris, seam, floor):
    """Suaviza por las aristas de la prenda lo que el registro ha movido: quita picos sin cambiar la forma."""
    neighbors = neighbors_of(len(placed), tris)
    offset = placed - original
    for _ in range(SMOOTH_PASSES):
        offset = np.array([offset[i] + 0.5 * (np.mean(offset[list(near)], axis=0) - offset[i]) if near else offset[i]
                           for i, near in enumerate(neighbors)])
    return keep_half(original + offset, seam, floor)


def ray_heights(tree, skin, normals, which):
    """Altura de la primera tela sobre cada vértice de piel, a lo largo de su normal (nan si no hay tela)."""
    heights, hits = np.full(len(which), np.nan), np.full(len(which), -1)
    for k, i in enumerate(which.tolist()):
        origin = Vector((skin[i] - normals[i] * BELOW).tolist())
        location, _, index, distance = tree.ray_cast(origin, Vector(normals[i].tolist()), BELOW + ABOVE)
        if location is not None:
            heights[k], hits[k] = distance - BELOW, index
    return heights, hits


def corner_weights(point, a, b, c):
    v0, v1, v2 = b - a, c - a, point - a
    d00, d01, d11, d20, d21 = v0 @ v0, v0 @ v1, v1 @ v1, v2 @ v0, v2 @ v1
    den = d00 * d11 - d01 * d01
    den = den if abs(den) > 1e-18 else 1e-18
    v, w = (d11 * d20 - d01 * d21) / den, (d00 * d21 - d01 * d20) / den
    bary = np.clip([1 - v - w, v, w], 0, 1)
    return bary / bary.sum()


def growth_normals(verts, tris, seam, hem):
    """Hacia dónde crece cada vértice. El bajo crece en horizontal: así no sube ni baja al inflar."""
    normals = vertex_normals(verts, tris)
    normals[seam, 0] = 0.0
    normals[hem, 2] = 0.0
    return normals / np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-9)


def grow_from(grow, tri, cloth, point, need):
    bary = corner_weights(point, cloth[tri[0]], cloth[tri[1]], cloth[tri[2]])
    need /= max(float((bary * bary).sum()), 1e-6)
    for corner, weight in zip(tri.tolist(), bary.tolist()):
        grow[corner] = max(grow[corner], need * weight)


def inflate(verts, normals, tris, ctx):
    """Un escalar por vértice a lo largo de su normal, que solo crece, hasta dejar MARGIN entre piel y tela."""
    low, high = verts.min(0) - NEAR, verts.max(0) + NEAR
    which = np.nonzero(ctx.drives & (ctx.skin[:, 0] >= -0.002) & (ctx.skin >= low).all(1) & (ctx.skin <= high).all(1))[0]
    amount, left, passes = np.zeros(len(verts)), 0, 0
    for passes in range(1, MAX_PASSES + 1):
        current = verts + amount[:, None] * normals
        heights, hits = ray_heights(eq.tree_of(current, tris), ctx.skin, ctx.normals, which)
        bad = np.nonzero(heights < MARGIN)[0]
        left = len(bad)
        if not left:
            break
        grow = np.zeros(len(verts))
        for k in bad.tolist():
            point = ctx.skin[which[k]] + ctx.normals[which[k]] * heights[k]
            grow_from(grow, tris[hits[k]], current, point, MARGIN - heights[k])
        amount = np.minimum(amount + grow * 0.7, MAX_INFLATE)
    return amount, which, passes, left


def skinned(points, weights, matrices):
    out = np.zeros_like(points)
    for j, matrix in enumerate(matrices):
        used = np.nonzero(weights[:, j] > 0)[0]
        if len(used):
            out[used] += weights[used, j][:, None] * (points[used] @ matrix[:3, :3].T + matrix[:3, 3])
    return out


def inflate_poses(verts, normals, tris, amount, which, weights, slot, ctx):
    """Infla también donde la piel asoma en las poses de prueba (solo si piel y tela miran hacia el mismo lado)."""
    posed = []
    for matrices in ctx.poses[slot]:
        skin = skinned(ctx.skin, ctx.weights, matrices)
        posed.append((matrices, skin, vertex_normals(skin, ctx.skin_tris)))
    for _ in range(POSE_PASSES):
        grow = np.zeros(len(verts))
        for matrices, skin, skin_normals in posed:
            cloth = skinned(verts + amount[:, None] * normals, weights, matrices)
            faces = np.cross(cloth[tris[:, 1]] - cloth[tris[:, 0]], cloth[tris[:, 2]] - cloth[tris[:, 0]])
            heights, hits = ray_heights(eq.tree_of(cloth, tris), skin, skin_normals, which)
            for k in np.nonzero(heights < POSE_MARGIN)[0].tolist():
                if faces[hits[k]] @ skin_normals[which[k]] > 0:
                    point = skin[which[k]] + skin_normals[which[k]] * heights[k]
                    grow_from(grow, tris[hits[k]], cloth, point, POSE_MARGIN - heights[k])
        if not grow.any():
            break
        amount = np.minimum(amount + grow * 0.7, MAX_INFLATE)
    return amount


def spread(amount, neighbors):
    for _ in range(SPREAD):
        amount = np.array([max(amount[i], 0.6 * np.mean(amount[list(near)])) if near else amount[i]
                           for i, near in enumerate(neighbors)])
    return np.minimum(amount, MAX_INFLATE)


def clear_layers(verts, normals, tris, amount, lowers):
    """Sube la prenda de torso donde cruza alguno de los shorts, hasta no cruzar ninguno."""
    touched = np.zeros(len(verts), bool)
    for _ in range(LAYER_PASSES):
        tree = eq.tree_of(verts + amount[:, None] * normals, tris)
        hit = {pair[0] for lower in lowers for pair in tree.overlap(lower)}
        if not hit:
            break
        corners = np.unique(tris[sorted(hit)])
        touched[corners] = True
        amount[corners] += LAYER_STEP
    amount[touched] += LAYER_STEP  # holgura: los flotantes de Godot no deben volver a cruzarlas
    return amount


def hem_edges(tris, seam):
    """Aristas de borde de la mitad que no están en la costura de simetría."""
    on_seam = set(seam.tolist())
    count = {}
    for tri in tris.tolist():
        for a, b in ((tri[0], tri[1]), (tri[1], tri[2]), (tri[2], tri[0])):
            key = (min(a, b), max(a, b))
            count[key] = count.get(key, 0) + 1
    return [e for e, n in count.items() if n == 1 and not (e[0] in on_seam and e[1] in on_seam)]


def lowest_hem(edges, verts):
    """Vértices del borde conexo más bajo (el bajo de la prenda)."""
    links = {}
    for a, b in edges:
        links.setdefault(a, set()).add(b)
        links.setdefault(b, set()).add(a)
    best, best_z, seen = [], np.inf, set()
    for start in links:
        if start in seen:
            continue
        group, stack = [], [start]
        seen.add(start)
        while stack:
            vertex = stack.pop()
            group.append(vertex)
            for other in links[vertex] - seen:
                seen.add(other)
                stack.append(other)
        z = float(verts[group, 2].mean())
        if z < best_z:
            best, best_z = group, z
    return best


def hem_distance(points, verts, edges):
    a = verts[[e[0] for e in edges]]
    b = verts[[e[1] for e in edges]]
    a, b = np.vstack([a, a * [-1, 1, 1]]), np.vstack([b, b * [-1, 1, 1]])
    ab = b - a
    out = np.empty(len(points))
    for start in range(0, len(points), 200):
        chunk = points[start:start + 200]
        t = np.clip(((chunk[:, None] - a[None]) * ab[None]).sum(2) / np.maximum((ab * ab).sum(1), 1e-12)[None], 0, 1)
        out[start:start + 200] = np.linalg.norm(chunk[:, None] - (a[None] + t[..., None] * ab[None]), axis=2).min(1)
    return out


def close_gap(placed, normals, tris, amount, which, seam, floor, edges, ctx):
    """keep_half puede acercar la tela a la piel junto a la costura: si el hueco medido baja de MIN_GAP, la sube."""
    away = hem_distance(ctx.skin[which], keep_half(placed + amount[:, None] * normals, seam, floor), edges) > HEM_CLEAR
    for _ in range(GAP_PASSES):
        current = keep_half(placed + amount[:, None] * normals, seam, floor)
        heights, hits = ray_heights(eq.tree_of(current, tris), ctx.skin, ctx.normals, which)
        bad = np.nonzero((heights < MIN_GAP) & away)[0]
        if not len(bad):
            break
        grow = np.zeros(len(placed))
        for k in bad.tolist():
            point = ctx.skin[which[k]] + ctx.normals[which[k]] * heights[k]
            grow_from(grow, tris[hits[k]], current, point, MARGIN - heights[k])
        amount = np.minimum(amount + grow * 0.7, MAX_INFLATE)
    return amount


def apply_modifiers(garment, fitted, inward, scale, piece_id):
    solidify = next(m for m in garment.modifiers if m.type == "SOLIDIFY")
    solidify.thickness = abs(solidify.thickness) * scale
    solidify.offset = 1.0  # con las normales hacia fuera, la tela crece hacia fuera y la cara interior no se mueve
    garment.data.vertices.foreach_set("co", fitted.ravel())
    if inward:
        mesh = bmesh.new()
        mesh.from_mesh(garment.data)
        bmesh.ops.reverse_faces(mesh, faces=mesh.faces)
        mesh.to_mesh(garment.data)
        mesh.free()
    garment.data.update()
    bpy.context.view_layer.update()
    final = bpy.data.meshes.new_from_object(garment.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    final.materials.clear()
    final.shade_smooth()
    obj = bpy.data.objects.new(piece_id, final)
    bpy.context.scene.collection.objects.link(obj)
    bpy.data.objects.remove(garment)
    return obj


def fit_failures(piece_id, obj, half, edges, hem, hem_before, ctx):
    """Comprueba la prenda final contra la piel. Imprime las medidas; devuelve cuántas fallan."""
    verts, tris = mesh_arrays(obj.data)
    low, high = verts.min(0) - NEAR, verts.max(0) + NEAR
    which = np.nonzero((ctx.skin >= low).all(1) & (ctx.skin <= high).all(1))[0]
    heights, _ = ray_heights(eq.tree_of(verts, tris), ctx.skin, ctx.normals, which)
    covered = which[~np.isnan(heights)]
    heights = heights[~np.isnan(heights)]
    inner = hem_distance(ctx.skin[covered], half, edges) > HEM_CLEAR
    gap = float(heights[inner].min())
    gaps = eq.signed_distance(ctx.tree, verts)
    under = 100 * float((gaps < 0).mean())
    depth = float(max(-gaps.min(), 0))
    hem_after = float(np.ptp(half[hem, 2]))
    print(f"MEDIDA {piece_id}: {len(verts)} vértices, {len(tris)} triángulos; hueco mínimo {gap * 1000:.2f} mm, mediano "
          f"{np.median(heights[inner]) * 1000:.1f} mm ({int(inner.sum())} de piel); tela bajo la piel {under:.2f} % "
          f"(hasta {depth * 1000:.2f} mm); rango del bajo {hem_before * 1000:.0f} -> {hem_after * 1000:.0f} mm")
    failed = [(gap < MIN_GAP, f"hueco {gap * 1000:.2f} mm < {MIN_GAP * 1000:.1f}"),
              (under > UNDER_MAX, f"tela bajo la piel {under:.2f} % > {UNDER_MAX:.0f}"),
              (depth > UNDER_DEPTH, f"hundida {depth * 1000:.2f} mm > {UNDER_DEPTH * 1000:.0f}"),
              (hem_after - hem_before > HEM_EXTRA, f"el bajo crece {(hem_after - hem_before) * 1000:.0f} mm > {HEM_EXTRA * 1000:.0f}")]
    for bad, text in failed:
        if bad:
            print(f"  FALLO {piece_id}: {text}")
    return sum(bad for bad, _ in failed)


def side_bind(points, ctx):
    """(esquinas, baricéntricas) en la piel sin cabeza y del mismo lado: la tela no salta a la otra pierna."""
    corners, bary = np.empty((len(points), 3), int), np.empty((len(points), 3))
    masks = (points[:, 0] > 0.002, points[:, 0] < -0.002, np.abs(points[:, 0]) <= 0.002)
    for mask, (tris, tree) in zip(masks, ctx.sides):
        if mask.any():
            corners[mask], bary[mask] = eq.bind(points[mask], ctx.skin, tris, tree)
    return corners, bary


def mixed(corners, bary, weights):
    return (weights[corners] * bary[..., None]).sum(1)


def cloth_weights(points, slot, ctx):
    """Pesos de la piel más cercana; en la axila, mezcla de brazo y tronco según lo cerca que esté de cada uno."""
    corners, bary = side_bind(points, ctx)
    found = mixed(corners, bary, ctx.weights)
    if slot != "ropa_torso":
        return found
    for sign, (arm_tris, arm_tree), (trunk_tris, trunk_tree) in ctx.axilla:
        side = np.nonzero(points[:, 0] * sign > 0.002)[0]
        if not len(side):
            continue
        part = points[side]
        arm_near = np.linalg.norm(nearest_points(arm_tree, part)[0] - part, axis=1)
        trunk_near = np.linalg.norm(nearest_points(trunk_tree, part)[0] - part, axis=1)
        blend = np.clip((AXILLA - np.maximum(arm_near, trunk_near)) / (0.5 * AXILLA), 0, 1)
        close = np.nonzero(blend > 0)[0]
        if not len(close):
            continue
        arm = mixed(*eq.bind(part[close], ctx.skin, arm_tris, arm_tree), ctx.weights)
        trunk = mixed(*eq.bind(part[close], ctx.skin, trunk_tris, trunk_tree), ctx.weights)
        share = (trunk_near[close] ** 2 / np.maximum(arm_near[close] ** 2 + trunk_near[close] ** 2, 1e-12))[:, None]
        found[side[close]] = (1 - blend[close])[:, None] * found[side[close]] + blend[close][:, None] * (share * arm + (1 - share) * trunk)
    return found


def fit_garment(piece_id, path, ctx, lowers):
    """(objeto final, fallos). Todo en la mitad x >= 0: Mirror copia el otro lado después."""
    source, registered, scale, shift = ctx.body
    slot = GARMENTS[piece_id][2]
    garment = load_object(path, GARMENTS[piece_id][0])
    mesh = bmesh.new()
    mesh.from_mesh(garment.data)  # triángulos fijados: la superficie que se comprueba es la que se exporta
    bmesh.ops.triangulate(mesh, faces=mesh.faces, quad_method="SHORT_EDGE", ngon_method="BEAUTY")
    mesh.to_mesh(garment.data)
    mesh.free()
    half, tris = mesh_arrays(garment.data)
    mirror = next(m for m in garment.modifiers if m.type == "MIRROR")
    floor = mirror.merge_threshold
    seam = np.nonzero(2 * np.abs(half[:, 0]) <= floor)[0]  # los que Mirror suelda con su copia
    original = half * scale + shift
    edges = hem_edges(tris, seam)
    hem = lowest_hem(edges, original)  # el mismo conjunto de vértices antes y después
    hem_before = float(np.ptp(original[hem, 2]))
    placed = smooth_offset(original, keep_half(carry(original, source, registered - source), seam, floor), tris, seam, floor)
    placed[hem, 2] = original[hem, 2] + (placed[hem, 2] - original[hem, 2]).mean()  # el bajo baja en bloque
    _, skin_normal = nearest_points(ctx.tree, placed)
    inward = ((vertex_normals(placed, tris) * skin_normal).sum(1) > 0).mean() < 0.5
    if inward:
        tris = tris[:, ::-1]
    normals = growth_normals(placed, tris, seam, hem)
    amount, which, passes, left = inflate(placed, normals, tris, ctx)
    weights = cloth_weights(keep_half(placed + amount[:, None] * normals, seam, floor), slot, ctx)
    amount = inflate_poses(placed, normals, tris, amount, which, weights, slot, ctx)
    amount = spread(amount, neighbors_of(len(placed), tris))
    if slot == "ropa_torso":
        amount = clear_layers(placed, normals, tris, amount, [tree for _, tree in lowers])
    amount = close_gap(placed, normals, tris, amount, which, seam, floor, edges, ctx)
    fitted = keep_half(placed + amount[:, None] * normals, seam, floor)
    print(f"MEDIDA {piece_id}: inflado en {passes} pasadas (quedan {left} puntos), media {amount.mean() * 1000:.1f} mm, máx {amount.max() * 1000:.1f} mm")
    obj = apply_modifiers(garment, fitted, inward, scale, piece_id)
    failures = fit_failures(piece_id, obj, fitted, edges, hem, hem_before, ctx) + (1 if left else 0)
    if slot == "ropa_torso":
        verts, final_tris = mesh_arrays(obj.data)
        tree = eq.tree_of(verts, final_tris)
        for lower_id, lower in lowers:
            crossed = len(tree.overlap(lower))
            print(f"MEDIDA {piece_id} + {lower_id}: {crossed} pares de triángulos cruzados en neutro")
            if crossed:
                print(f"  FALLO {piece_id}: cruza {lower_id} ({crossed} pares)")
                failures += 1
    return obj, failures


def pose_matrices(rig, bones, spec):
    """Matrices de piel (una por hueso, en el orden de bones) con un hueso girado sobre un eje del mundo."""
    name, axis, degrees = spec
    bone = rig.pose.bones[name]
    rest = rig.data.bones[name].matrix_local.to_quaternion()
    bone.rotation_mode = "QUATERNION"
    bone.rotation_quaternion = rest.inverted() @ Matrix.Rotation(math.radians(degrees), 4, axis).to_quaternion() @ rest
    bpy.context.view_layer.update()
    world = rig.matrix_world
    found = [np.array(world @ rig.pose.bones[b].matrix @ rig.data.bones[b].matrix_local.inverted() @ world.inverted())
             for b in bones]
    bone.rotation_quaternion = (1, 0, 0, 0)
    bpy.context.view_layer.update()
    return found


def body_context(basemesh, skin_count, path):
    rig = basemesh.parent
    skin = eq.world_coords(basemesh)[:skin_count]
    tris = eq.triangles(basemesh)
    tris = tris[(tris < skin_count).all(axis=1)]
    weights, bones = eq.body_weights(basemesh, skin_count)
    share = lambda parts: weights[:, [j for j, b in enumerate(bones) if any(p in b for p in parts)]].sum(1)
    head, arm, hand = share(("Head",)) >= 0.5, share(ARM_BONES) >= 0.5, share(HAND_BONES) >= 0.95
    no_head = tris[~head[tris].any(1)]
    x = skin[:, 0]
    def part(mask):
        chosen = no_head[mask[no_head].all(1)]
        return chosen, eq.tree_of(skin, chosen)
    tree = eq.tree_of(skin, tris)
    ctx = SimpleNamespace(skin=skin, skin_tris=tris, weights=weights, bones=bones, tree=tree,
                          normals=vertex_normals(skin, tris), drives=~(head | hand),  # cara y palmas no empujan la tela
                          sides=[part(x >= -0.01), part(x <= 0.01), (no_head, eq.tree_of(skin, no_head))],
                          axilla=[(1, part(arm & (x > 0)), part(~arm & (x > 0))), (-1, part(arm & (x < 0)), part(~arm & (x < 0)))],
                          poses={slot: [pose_matrices(rig, bones, spec) for spec in specs] for slot, specs in TEST_POSES.items()})
    ctx.body = source_body(path, skin, tree)
    return ctx


def attach(piece_id, obj, rig, names, deltas, ctx):
    """Pesos (con la mezcla de la axila) y formas. Devuelve (formas, fallos)."""
    verts, _ = mesh_arrays(obj.data)
    weights = cloth_weights(verts, GARMENTS[piece_id][2], ctx)
    single = np.arange(len(verts))[:, None].repeat(3, axis=1)
    one = np.tile([1.0, 0.0, 0.0], (len(verts), 1))
    eq.set_weights(obj, rig, weights, ctx.bones, single, one)  # los pesos ya vienen mezclados: cada vértice es «su» esquina
    corners, bary = side_bind(verts, ctx)
    return eq.hair_shapes(names, deltas, corners, bary), eq.weight_failures(piece_id, obj)


def export_garments(data_folder, pack_folder, path, chosen):
    with open(path, "rb") as file:
        digest = hashlib.sha256(file.read()).hexdigest()
    if digest != SOURCE_SHA256:
        print(f"RESULTADO: 1 FALLOS (sha256 del .blend distinto: {digest})")
        return
    basemesh, names, deltas, skin_count = eq.prepare_body(data_folder)
    rig = basemesh.parent
    ctx = body_context(basemesh, skin_count, path)
    lowers, done, failures = [], [], 0
    for piece_id in LOWER_IDS + tuple(p for p in chosen if p not in LOWER_IDS):  # los 3 shorts siempre, para las capas
        obj, bad = fit_garment(piece_id, path, ctx, lowers)
        if piece_id in LOWER_IDS:
            verts, tris = mesh_arrays(obj.data)
            lowers.append((piece_id, eq.tree_of(verts, tris)))
        if piece_id in chosen:
            shapes, weight_bad = attach(piece_id, obj, rig, names, deltas, ctx)
            failures += bad + weight_bad
            done.append((piece_id, obj, shapes))
    if failures:
        print(f"RESULTADO: {failures} FALLOS (no se escribe nada)")
        return
    os.makedirs(pack_folder, exist_ok=True)
    cards = []
    for piece_id, obj, shapes in done:
        card = eq.write_piece(obj, shapes, pack_folder, piece_id, GARMENTS[piece_id][1])
        card.update({"tipo": "ropa", "ranura": GARMENTS[piece_id][2], "color": COLOR})
        cards.append(card)
    ed.write_json(os.path.join(pack_folder, "pack.json"), dict(PACK, piezas=cards))
    print("RESULTADO: TODO BIEN")


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    export_garments(args[0], args[1], args[2], args[3:] or list(ENTRAN))


if __name__ == "__main__":
    main()
