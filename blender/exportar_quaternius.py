# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso RE.1b: exporta los 5 peinados CC0 de Quaternius como piezas que siguen al cuerpo.

Uso: blender -b --disable-autoexec -P blender/exportar_quaternius.py -- godot/datos/humana godot/packs/quaternius \
     "recursos_externos/QU01_quaternius_ubc/extraido/Universal Base Characters[Standard]"
Escribe en <pack> un .glb por peinado (con su .import) y pack.json. Si una medida se pasa de su límite, no escribe nada.

Cada peinado se coloca sobre nuestra cabeza con una escala y un desplazamiento (HAIRS). Cada vértice se liga al
triángulo de piel más cercano: de él saca, por baricéntricas, los pesos y las formas (mismos nombres que cuerpo.glb).
Sin materiales ni texturas: el color lo pone el programa. Todo en pose A, como cuerpo.glb.
"""
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import exportar_datos as ed  # noqa: E402
import exportar_helpers as eh  # noqa: E402
import generar_cuerpo as gc  # noqa: E402
from exportar_glb import export_glb, rename_to_humanoid  # noqa: E402
from exportar_mhclo import MIN_DELTA, full_deltas  # noqa: E402
from limpiar_malla import bake_shapes, remove_masks, remove_non_bone_groups  # noqa: E402
from poner_rig import MAX_INFLUENCES, add_rig, limit_weights  # noqa: E402

HAIR_FOLDER = "Hairstyles/Origin at 0/glTF (Godot)"
BODY_FOLDER = "Base Characters/Godot - UE"
REFERENCES = {  # cuerpo de Quaternius sobre el que se hizo cada peinado y su hueso Head (Blender: Z arriba, frente -Y)
    "F": ("Superhero_Female_FullBody", (0, 0.0109, 1.5496)),
    "M": ("Superhero_Male_FullBody", (0, 0.0174, 1.5998)),
}
# Su cabeza es mayor y está más alta: v' = (v - Head de Quaternius) * s + nuestro Head + (0, dy, dz).
# Valores ajustados con todos los vértices cercanos al cuero cabelludo (Nelder-Mead, 2026-11-21).
HAIRS = {  # id: (archivo, nombre, cuerpo de referencia, s, dy, dz)
    "hair_buns": ("Hair_Buns", "Moños", "F", 0.9382, -0.0029, -0.0596),
    "hair_long": ("Hair_Long", "Pelo largo", "F", 0.9473, -0.0027, -0.0623),
    "hair_buzzed_female": ("Hair_BuzzedFemale", "Rapado (F)", "F", 0.9362, -0.0028, -0.0594),
    "hair_buzzed": ("Hair_Buzzed", "Rapado (M)", "M", 0.9446, 0.0081, -0.0551),
    "hair_simple_parted": ("Hair_SimpleParted", "Raya al lado", "M", 0.9582, 0.0078, -0.0578),
}
PACK = {"formato": "gamemolde-pack", "version": 1, "id": "quaternius", "nombre": "Pack Quaternius",
        "autor": "Quaternius", "licencia": "CC0-1.0",
        "origen": "https://quaternius.com/packs/universalbasecharacters.html"}
COLOR = [0.24, 0.16, 0.12]  # el de los demás peinados
SCALP = 0.015  # metros: un vértice a menos de esto de la cabeza de Quaternius cuenta como cuero cabelludo
UNDER = 0.001  # metros: más hundido que esto cuenta como «bajo la piel»
MAX_RMS = 0.003  # PROVISIONAL: metros; medido entre 1,6 y 2,2 mm
MAX_UNDER_EXTRA = 5.0  # PROVISIONAL: puntos de % bajo la piel por encima del peinado sobre su cuerpo original
WEIGHT_SUM_TOLERANCE = 1e-4  # PROVISIONAL


def world_coords(obj):
    coords = np.empty(len(obj.data.vertices) * 3)
    obj.data.vertices.foreach_get("co", coords)
    matrix = np.array(obj.matrix_world)
    return coords.reshape(-1, 3) @ matrix[:3, :3].T + matrix[:3, 3]


def triangles(obj):
    return np.array([(p.vertices[0], p.vertices[k], p.vertices[k + 1])
                     for p in obj.data.polygons for k in range(1, len(p.vertices) - 1)])


def tree_of(coords, tris):
    return BVHTree.FromPolygons([Vector(c) for c in coords.tolist()], tris.tolist())


def load_references(source):
    """{clave: (vértices, triángulos)} de los cuerpos de Quaternius."""
    found = {}
    for key, (name, _) in REFERENCES.items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.join(source, BODY_FOLDER, name + ".gltf"))
        mesh = max((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
        found[key] = (world_coords(mesh), triangles(mesh))
    return found


def load_hair(path, piece_id):
    """Importa el peinado: una malla sin padre, sin materiales, con su giro y escala ya aplicados."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if len(meshes) != 1:
        raise ValueError(f"{path}: {len(meshes)} mallas, se esperaba 1")
    hair = meshes[0]
    world = hair.matrix_world.copy()
    hair.parent = None
    hair.matrix_world = Matrix.Identity(4)
    hair.data.transform(world)
    for other in new:
        if other is not hair:
            bpy.data.objects.remove(other)
    hair.data.materials.clear()
    hair.vertex_groups.clear()
    hair.name = hair.data.name = piece_id
    return hair


def signed_distance(tree, points):
    found = np.empty(len(points))
    for i, point in enumerate(points):
        location, normal, _, distance = tree.find_nearest(Vector(point))
        found[i] = distance if (Vector(point) - location).dot(normal) >= 0 else -distance
    return found


def fit_failures(piece_id, original, placed, reference_tree, skin_tree):
    """Compara el hueco al cuero cabelludo con el del original. Imprime las medidas; devuelve cuántas fallan."""
    points, index = np.unique(original.round(5), axis=0, return_index=True)
    before = signed_distance(reference_tree, points)
    after = signed_distance(skin_tree, placed[index])
    scalp = np.abs(before) < SCALP
    rms = float(np.sqrt(np.mean((after[scalp] - before[scalp]) ** 2)))
    under_before = 100 * float((before < -UNDER).mean())
    under_after = 100 * float((after < -UNDER).mean())
    print(f"MEDIDA {piece_id}: RMS del hueco {rms * 1000:.2f} mm; bajo la piel {under_after:.1f} % "
          f"(original {under_before:.1f} %); máximo hundido {-after.min() * 1000:.1f} mm")
    bad = 0
    if rms > MAX_RMS:
        print(f"  FALLO {piece_id}: RMS {rms * 1000:.2f} mm > {MAX_RMS * 1000:.0f} mm")
        bad += 1
    if under_after > under_before + MAX_UNDER_EXTRA:
        print(f"  FALLO {piece_id}: {under_after:.1f} % bajo la piel > {under_before:.1f} + {MAX_UNDER_EXTRA:.0f}")
        bad += 1
    return bad


def bind(points, coords, tris, tree):
    """(vértices del triángulo de piel más cercano, baricéntricas) de cada punto. Misma posición, mismo ligado."""
    unique, inverse = np.unique(points.round(5), axis=0, return_inverse=True)
    inverse = inverse.ravel()
    nearest = np.empty((len(unique), 3))
    hits = np.empty(len(unique), dtype=int)
    for i, point in enumerate(unique):
        location, _, hit, _ = tree.find_nearest(Vector(point))
        nearest[i], hits[i] = location, hit
    corners = tris[hits]
    a, b, c = coords[corners[:, 0]], coords[corners[:, 1]], coords[corners[:, 2]]
    v0, v1, v2 = b - a, c - a, nearest - a
    d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
    d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
    den = np.where(np.abs(d00 * d11 - d01 * d01) < 1e-18, 1e-18, d00 * d11 - d01 * d01)
    v, w = (d11 * d20 - d01 * d21) / den, (d00 * d21 - d01 * d20) / den
    bary = np.clip(np.stack([1 - v - w, v, w], axis=1), 0, 1)
    bary /= bary.sum(1, keepdims=True)
    return corners[inverse], bary[inverse]


def body_weights(basemesh, skin):
    """(matriz vértice de piel × hueso, nombres de los huesos)."""
    bones = [g.name for g in basemesh.vertex_groups if g.name in basemesh.parent.data.bones]
    column = {basemesh.vertex_groups[name].index: i for i, name in enumerate(bones)}
    weights = np.zeros((skin, len(bones)), dtype=np.float32)
    for vertex in basemesh.data.vertices[:skin]:
        for group in vertex.groups:
            if group.group in column:
                weights[vertex.index, column[group.group]] = group.weight
    return weights, bones


def set_weights(hair, rig, weights, bones, corners, bary):
    """Baricéntricos de los pesos del cuerpo, con 4 influencias como máximo y suma 1."""
    mixed = (weights[corners] * bary[..., None]).sum(1)
    for j, name in enumerate(bones):
        used = np.nonzero(mixed[:, j] > 0)[0]
        if len(used):
            group = hair.vertex_groups.new(name=name)
            for i in used.tolist():
                group.add([i], float(mixed[i, j]), "REPLACE")
    hair.parent = rig
    hair.matrix_world = Matrix.Identity(4)
    hair.modifiers.new("Armature", "ARMATURE").object = rig
    remove_non_bone_groups(hair)
    limit_weights(hair)


def weight_failures(piece_id, hair):
    worst_sum, worst_count = 0.0, 0
    for vertex in hair.data.vertices:
        used = [g.weight for g in vertex.groups if g.weight > 0]
        worst_sum = max(worst_sum, abs(sum(used) - 1))
        worst_count = max(worst_count, len(used))
    print(f"MEDIDA {piece_id}: hasta {worst_count} influencias; error de la suma {worst_sum:.6f}")
    if worst_count > MAX_INFLUENCES or worst_sum > WEIGHT_SUM_TOLERANCE:
        print(f"  FALLO {piece_id}: pesos fuera de regla")
        return 1
    return 0


def hair_shapes(names, deltas, corners, bary):
    """{forma: desplazamiento} en el orden de cuerpo.glb, sin las que lo mueven menos de MIN_DELTA."""
    shapes = {}
    for name in names:
        moved = (deltas[name][corners] * bary[..., None]).sum(1)
        if np.linalg.norm(moved, axis=1).max() >= MIN_DELTA:
            shapes[name] = (moved, None)
    return shapes


def write_piece(hair, shapes, pack_folder, piece_id, label):
    out = os.path.join(pack_folder, f"{piece_id}.glb")
    ed.add_shape_keys(hair, shapes)
    export_glb(hair, [], out, morph=True, deform_only=True, morph_normals=False)
    ed.write_full_names(out, list(shapes))
    with open(out + ".import", "w", encoding="utf-8") as file:
        file.write(eh.KEEP_IMPORT)
    print(f"PIEZA: {piece_id}: {len(hair.data.vertices)} vertices, {len(shapes)} formas, "
          f"{os.path.getsize(out) / 1e6:.2f} MB")
    return {"id": piece_id, "nombre": label, "tipo": "pelo", "ranura": "pelo", "especies": ["humana"],
            "archivo": f"{piece_id}.glb", "sha256": eh.sha256(out), "miniatura": "",
            "anclaje": {"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]}, "sigue_al_cuerpo": True, "fisica": [],
            "colores": ["principal"], "color": COLOR}


def prepare_body(data_folder):
    """(cuerpo neutro con rig y nombres humanoides, nombres de las formas, sus desplazamientos, vértices de piel)."""
    rows = ed.read_sliders(data_folder)
    names = ed.target_names(os.path.join(data_folder, "cuerpo.glb"))
    measured, bodies = eh.measure(rows)
    skin_only, skin = eh.skin_shapes(rows, bodies)
    ed.keep_small_macro_weights()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    basemesh = gc.create_body(gc.validate_spec({"version": gc.FORMAT_VERSION}))
    add_rig(basemesh)
    bake_shapes(basemesh)
    remove_masks(basemesh)
    rename_to_humanoid(basemesh)
    coords = np.empty(len(basemesh.data.vertices) * 3)
    basemesh.data.vertices.foreach_get("co", coords)
    deltas = full_deltas(names, measured, skin_only, coords.reshape(-1, 3), skin)
    return basemesh, names, deltas, skin


def export_hairs(data_folder, pack_folder, source):
    references = load_references(source)
    basemesh, names, deltas, skin = prepare_body(data_folder)
    rig = basemesh.parent
    head = np.array(rig.matrix_world @ rig.data.bones["Head"].head_local)
    coords = world_coords(basemesh)[:skin]
    tris = triangles(basemesh)
    tris = tris[(tris < skin).all(axis=1)]
    skin_tree = tree_of(coords, tris)
    weights, bones = body_weights(basemesh, skin)
    reference_trees = {key: tree_of(*value) for key, value in references.items()}
    hairs, failures = [], 0
    for piece_id, (file, label, key, scale, dy, dz) in HAIRS.items():
        hair = load_hair(os.path.join(source, HAIR_FOLDER, file + ".gltf"), piece_id)
        original = world_coords(hair)
        placed = (original - np.array(REFERENCES[key][1])) * scale + head + np.array([0, dy, dz])
        hair.data.vertices.foreach_set("co", placed.ravel())
        hair.data.update()
        failures += fit_failures(piece_id, original, placed, reference_trees[key], skin_tree)
        corners, bary = bind(placed, coords, tris, skin_tree)
        set_weights(hair, rig, weights, bones, corners, bary)
        failures += weight_failures(piece_id, hair)
        hairs.append((piece_id, label, hair, hair_shapes(names, deltas, corners, bary)))
    if failures:
        print(f"RESULTADO: {failures} FALLOS (no se escribe nada)")
        return
    os.makedirs(pack_folder, exist_ok=True)
    cards = [write_piece(hair, shapes, pack_folder, piece_id, label) for piece_id, label, hair, shapes in hairs]
    ed.write_json(os.path.join(pack_folder, "pack.json"), dict(PACK, piezas=cards))
    print("RESULTADO: TODO BIEN")


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    export_hairs(args[0], args[1], args[2])


if __name__ == "__main__":
    main()
