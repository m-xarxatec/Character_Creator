# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso 12.1b-b2: máscara de la piel que tapa cada prenda (para no dibujarla en el editor).

Uso: (ulimit -v 4000000; timeout 600 blender -b -P blender/ocultar_piel.py -- godot/datos/humana godot/packs/<pack> [id ...])
Sin ids, todas las fichas de tipo ropa con .glb. Lee cuerpo.glb y el .glb de cada prenda (los dos en pose A y neutros,
sin pasar por MPFB) y escribe <id>_oculta.png (RGBA de 1024², sobre las UV de cuerpo.glb como piel.png: RGB = 1,
A = oculta), su .import y el campo "oculta" de la ficha en pack.json (solo ese campo; el resto del archivo no cambia).
Oculta = piel con tela encima (rayo por su normal, sin otra piel por medio: 12.1b-b5) a más de HIDE_HEM de piel sin
tapar. Sin manos. La de la axila o el muslo cuyo rayo cruza el costado o la otra pierna antes de la tela no está tapada.
Salida: MEDIDA <id>: tapada N, oculta M (x %), banda B, png K kB, con otra piel por medio S; FALLO si la banda es 0 o si
las UV no cuadran.
"""
import json
import os
import sys

import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import exportar_datos as ed  # noqa: E402
import exportar_helpers as eh  # noqa: E402
import exportar_overscore as eo  # noqa: E402
import exportar_quaternius as eq  # noqa: E402
import generar_zonas_piel as gz  # noqa: E402

HIDE_HEM = 0.04  # metros: la piel a menos de esto de piel sin tapar no se oculta (la prueba mide desde HEM = 0,025)
HAND_PARTS = ("Hand", "Thumb", "Index", "Middle", "Ring", "Little")  # los de generar_zonas_piel
SKIN_GAP = 0.002  # metros: el rayo que busca otra piel sale de esto por encima de la suya (para no tocarse a sí mismo)


def moved_meshes(path):
    """Nodos de malla con transformación (read_glb no las aplica) y mallas o primitivas de más."""
    info = ed._glb_parts(path)[0]
    bad = [n.get("name") for n in info["nodes"]
           if "mesh" in n and any(k in n for k in ("matrix", "translation", "rotation", "scale"))]
    if len(info["meshes"][0]["primitives"]) != 1:
        bad.append("primitivas: %d" % len(info["meshes"][0]["primitives"]))
    return bad


def skin_between(skin, normals, tris, which, heights):
    """bool por cada `which`: otra piel corta su rayo antes de la tela (la tela es de otra parte del cuerpo: la manga
    sobre el costado, la pernera de la otra pierna). Paso 12.1b-b5."""
    tree = eq.tree_of(skin, tris)
    found = np.zeros(len(which), bool)
    for k in np.nonzero(heights > SKIN_GAP)[0].tolist():
        i = which[k]
        origin = Vector((skin[i] + normals[i] * SKIN_GAP).tolist())
        found[k] = tree.ray_cast(origin, Vector(normals[i].tolist()), heights[k] - SKIN_GAP)[0] is not None
    return found


def hidden_skin(skin, normals, tris, free, cloth, cloth_tris):
    """bool por vértice de piel: tela encima (rayo por la normal, sin otra piel por medio) y a más de HIDE_HEM de piel
    sin tapar. free: los que cuentan (sin manos). Devuelve (oculta, tapada, cuántos tenían otra piel por medio)."""
    low, high = cloth.min(0) - eo.BELOW, cloth.max(0) + eo.BELOW
    near = free & (skin >= low).all(1) & (skin <= high).all(1)
    which = np.nonzero(near)[0]
    heights = eo.ray_heights(eq.tree_of(cloth, cloth_tris), skin, normals, which)[0]
    behind = skin_between(skin, normals, tris, which, heights)
    covered = np.zeros(len(skin), bool)
    covered[which[np.isfinite(heights) & ~behind]] = True
    bare = np.nonzero(near & ~covered)[0]
    hidden = covered.copy()
    if len(bare):
        tree = KDTree(len(bare))
        for k, i in enumerate(bare.tolist()):
            tree.insert(skin[i].tolist(), k)
        tree.balance()
        for i in np.nonzero(covered)[0].tolist():
            hidden[i] = tree.find(skin[i].tolist())[2] > HIDE_HEM
    return hidden, covered, int(behind.sum())


def write_mask(path, uv, index, hidden):
    """PNG RGBA de SIZE²: RGB = 1 y A = oculta (interpolada en cada triángulo; pad hacia fuera de las islas).
    Devuelve la imagen (uint8) para comprobarla."""
    values = np.stack([np.ones(len(uv))] * 3 + [hidden.astype(np.float64)], 1)
    image, filled = gz.rasterize(uv, index, values)
    image = gz.pad(image, filled)
    image[..., :3] = 1.0
    image = np.round(np.clip(image, 0, 1) * 255).astype(np.uint8)
    gz.write_png(path, image)
    return image


def uv_failures(image, uv, index, hidden):
    """Vértices interiores (todos sus vecinos con la misma marca) cuyo píxel más cercano no da su marca."""
    mixed = hidden[index].any(1) != hidden[index].all(1)
    interior = np.ones(len(uv), bool)
    interior[index[mixed].ravel()] = False
    used = np.zeros(len(uv), bool)
    used[index.ravel()] = True
    px = np.clip(np.floor(uv * gz.SIZE).astype(int), 0, gz.SIZE - 1)
    alpha = image[px[:, 1], px[:, 0], 3] > 127
    return int((interior & used & (alpha != hidden)).sum())


def update_cards(pack_json, changes):
    """{id: {campo: valor}}: cambia solo esos campos de fichas que ya existen; el resto del archivo no se toca."""
    with open(pack_json, encoding="utf-8") as file:
        text = file.read()
    data = json.loads(text)
    if json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True) + "\n" != text:
        raise ValueError("pack.json no tiene el formato de write_json: reescribirlo cambiaría más que los campos")
    cards = {card["id"]: card for card in data["piezas"]}
    missing = [piece_id for piece_id in changes if piece_id not in cards]
    if missing:
        raise ValueError("fichas que no existen en pack.json: %s" % missing)
    for piece_id, fields in changes.items():
        cards[piece_id].update(fields)
    ed.write_json(pack_json, data)


def body_data(data_folder):
    path = os.path.join(data_folder, "cuerpo.glb")
    mesh, joints = gz.read_glb(path)
    hand = sum(gz.bone_weight(mesh, joints, n) for n in joints if any(part in n for part in HAND_PARTS))
    normals = mesh["NORMAL"] / np.maximum(np.linalg.norm(mesh["NORMAL"], axis=1, keepdims=True), 1e-12)
    return mesh, normals, hand < 0.5, moved_meshes(path)


def mask_for(body, pack_folder, piece_id):
    """(cambio para pack.json o None, fallos)."""
    mesh, normals, free, _ = body
    path = os.path.join(pack_folder, piece_id + ".glb")
    moved = moved_meshes(path)
    if moved:
        print(f"  FALLO {piece_id}: la malla tiene transformación o primitivas de más ({moved}): read_glb no las aplica")
        return None, 1
    cloth, _ = gz.read_glb(path)
    hidden, covered, behind = hidden_skin(mesh["POSITION"], normals, mesh["INDEX"], free, cloth["POSITION"], cloth["INDEX"])
    band = int((covered & ~hidden).sum())
    out = os.path.join(pack_folder, piece_id + "_oculta.png")
    image = write_mask(out + ".tmp", mesh["TEXCOORD_0"], mesh["INDEX"], hidden)  # .tmp: si falla, no pisa la buena
    wrong = uv_failures(image, mesh["TEXCOORD_0"], mesh["INDEX"], hidden)
    failures = 0
    if band == 0:
        print(f"  FALLO {piece_id}: banda 0 (la prueba no tendría piel sin ocultar que medir)")
        failures += 1
    if wrong:
        print(f"  FALLO {piece_id}: {wrong} vértices interiores con la marca cambiada en la imagen (UV)")
        failures += 1
    if failures:
        os.remove(out + ".tmp")
        return None, failures
    os.replace(out + ".tmp", out)
    with open(out + ".import", "w", encoding="utf-8") as file:
        file.write(eh.KEEP_IMPORT)
    tapada, oculta = int(covered.sum()), int(hidden.sum())
    print(f"MEDIDA {piece_id}: tapada {tapada}, oculta {oculta} ({100.0 * oculta / max(tapada, 1):.1f} %),"
          f" banda {band}, png {os.path.getsize(out) / 1024:.0f} kB, con otra piel por medio {behind}")
    return {"oculta": {"archivo": piece_id + "_oculta.png", "sha256": eh.sha256(out)}}, 0


def main(data_folder, pack_folder, ids):
    pack_json = os.path.join(pack_folder, "pack.json")
    with open(pack_json, encoding="utf-8") as file:
        cards = json.load(file)["piezas"]
    if not ids:
        ids = [c["id"] for c in cards if c.get("tipo") == "ropa" and c.get("archivo", "").endswith(".glb")]
    body = body_data(data_folder)
    failures, changes = 0, {}
    if body[3]:
        print(f"  FALLO cuerpo.glb: transformación o primitivas de más ({body[3]})")
        failures += 1
    else:
        for piece_id in ids:
            change, bad = mask_for(body, pack_folder, piece_id)
            failures += bad
            if change:
                changes[piece_id] = change
    if changes:
        update_cards(pack_json, changes)
    print("RESULTADO: TODO BIEN" if not failures else f"RESULTADO: {failures} FALLOS")


if __name__ == "__main__":
    arguments = sys.argv[sys.argv.index("--") + 1:]
    main(arguments[0], arguments[1], arguments[2:])
