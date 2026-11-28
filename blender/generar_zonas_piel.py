"""Paso SH.8: genera piel.png, el mapa de zonas de la piel sobre las UV de cuerpo.glb (FORMATO.md).

Uso (desde la raiz del repositorio; solo necesita numpy, que viene con Blender):
    blender -b -P blender/generar_zonas_piel.py -- godot/datos/humana
    python3 blender/generar_zonas_piel.py godot/datos/humana
Lee cuerpo.glb (malla base en pose A, sin formas), articulaciones.json y ojos.json; escribe piel.png (1024 x 1024, RGBA) y
pone su sha256 en manifiesto.json. Hay que volver a lanzarlo si cambian las UV o la forma base de cuerpo.glb.
Canales (0-255, lineales): R = rubor (mejillas, nariz, puntas de las orejas, hombros, codos, rodillas y nudillos);
G = cercania para las pecas, 1 - raiz cuadrada de la distancia normalizada desde el centro de la cara (1 = nariz y
mejillas, 0 = nunca: ojos, labios, palmas, plantas y fuera de la piel; asi, sin textura no hay pecas); B = labios;
A (SH.4) = fuera de la cara: 0 en la cara (delante de la cabeza, sin orejas ni nuca), 1 en el resto; al reves para que
sin textura (negro opaco) todo cuente como fuera de la cara.
Las zonas salen de la geometria (puntos de referencia y distancias), sin pintar nada a mano: el mapa es nuestro (CC0).
Imprime los puntos de referencia encontrados para revisarlos.
"""
import json
import os
import struct
import sys
import zlib

import numpy as np

SIZE = 1024
PAD = 6  # pixeles que cada isla de UV se extiende hacia fuera (para que el filtro no mezcle con el fondo)
FILE = "piel.png"
FRECKLE_REACH = 1.7  # metros: distancia desde el centro de la cara que vale 1 en el orden de las pecas


# --- Lectura de cuerpo.glb (sin bpy) ---

def read_glb(path):
    data = open(path, "rb").read()
    length = struct.unpack("<I", data[12:16])[0]
    info = json.loads(data[20:20 + length])
    blob = data[20 + length + 8:]
    kinds = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
    sizes = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}

    def accessor(index):
        acc = info["accessors"][index]
        view = info["bufferViews"][acc["bufferView"]]
        kind = kinds[acc["componentType"]]
        count, size = acc["count"], sizes[acc["type"]]
        offset = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        item = np.dtype(kind).itemsize * size
        stride = view.get("byteStride", item)
        raw = np.frombuffer(blob, np.uint8, stride * (count - 1) + item, offset)
        rows = np.lib.stride_tricks.as_strided(raw, (count, item), (stride, 1)).copy()
        values = rows.view(kind).reshape(count, size).astype(np.float64)
        return values / np.iinfo(kind).max if acc.get("normalized") else values

    primitive = info["meshes"][0]["primitives"][0]
    mesh = {name: accessor(index) for name, index in primitive["attributes"].items()}
    mesh["INDEX"] = accessor(primitive["indices"]).astype(np.int64).reshape(-1, 3)
    joints = [info["nodes"][j]["name"] for j in info["skins"][0]["joints"]]
    return mesh, joints


def bone_weight(mesh, joints, name):
    return (mesh["WEIGHTS_0"] * (mesh["JOINTS_0"] == joints.index(name))).sum(1)


# --- Puntos de referencia de la cara ---

def landmarks(points, normals, head, eyes):
    eye_y = eyes["l"]["centro"][1]
    eye_x = abs(eyes["l"]["centro"][0])
    front = (head > 0.3) & (normals[:, 2] > 0.2)
    middle = front & (np.abs(points[:, 0]) < 0.002)
    band = middle & (points[:, 1] < eye_y - 0.01) & (points[:, 1] > eye_y - 0.06)
    nose = points[band][np.argmax(points[band][:, 2])]
    below = middle & (points[:, 1] < nose[1] - 0.015) & (points[:, 1] > nose[1] - 0.040) & (points[:, 2] > nose[2] - 0.03)
    mouth = points[below][np.argmin(points[below][:, 2])]
    cheeks = []
    for sign in (1.0, -1.0):
        goal = np.array([sign * eye_x * 1.2, eye_y - 0.03])
        near = front & (np.abs(points[:, 0] - goal[0]) < 0.004) & (np.abs(points[:, 1] - goal[1]) < 0.004)
        cheeks.append(points[near][np.argmax(points[near][:, 2])])
    ears = []
    for sign in (1.0, -1.0):
        side = (head > 0.5) & (sign * points[:, 0] > 0) & (np.abs(points[:, 1] - eye_y) < 0.05)
        widest = np.max(sign * points[side, 0])
        ear = side & (sign * points[:, 0] > widest - 0.012) & (points[:, 2] < eyes["l"]["centro"][2] - 0.04)
        ears.append(points[ear][np.argmax(points[ear][:, 1])])
    return {"nariz": nose, "boca": mouth, "mejillas": cheeks, "orejas": ears, "ojos": [np.array(eyes[s]["centro"]) for s in ("l", "r")]}


def gauss(points, center, sigma, scale=(1.0, 1.0, 1.0)):
    d = (points - center) / np.array(scale)
    return np.exp(-0.5 * (d * d).sum(1) / (sigma * sigma))


# --- Zonas por vertice ---

def blush(points, normals, head, marks, bones, joints_json):
    face = (head > 0.3) & (normals[:, 2] > 0.0)
    value = np.zeros(len(points))
    for cheek in marks["mejillas"]:
        value = np.maximum(value, face * gauss(points, cheek, 0.014, (1.35, 1.0, 1.0)))
    value = np.maximum(value, 0.6 * face * gauss(points, marks["nariz"], 0.007))
    for ear in marks["orejas"]:
        value = np.maximum(value, 0.8 * (head > 0.3) * gauss(points, ear, 0.009))
    for side, sign in (("Left", 1.0), ("Right", -1.0)):
        shoulder = np.array(joints_json[side + "UpperArm"]["head"])
        value = np.maximum(value, 0.45 * np.clip(normals[:, 1], 0, 1) * gauss(points, shoulder, 0.04))
        elbow = np.array(joints_json[side + "LowerArm"]["head"])
        value = np.maximum(value, 0.55 * bones[side + "Arm"] * np.clip(-normals[:, 2], 0, 1) * gauss(points, elbow, 0.03))
        knee = np.array(joints_json[side + "LowerLeg"]["head"])
        value = np.maximum(value, 0.6 * np.clip(normals[:, 2], 0, 1) * gauss(points, knee, 0.04))
        for finger in ("Index", "Middle", "Ring", "Little"):
            knuckle = np.array(joints_json[side + finger + "Proximal"]["head"])
            back = np.clip(sign * normals[:, 0], 0, 1) ** 0.5
            value = np.maximum(value, 0.5 * back * gauss(points, knuckle, 0.011))
    return np.clip(value, 0, 1)


def lips(points, normals, head, marks):
    eye_x = abs(marks["ojos"][0][0])
    mouth = marks["boca"]
    d = (points - mouth) / np.array([eye_x * 0.62, 0.0105, 0.03])
    value = 1.0 - np.clip(((d * d).sum(1) - 0.55) / 0.45, 0, 1)
    return np.clip(value * (head > 0.3) * (normals[:, 2] > -0.2), 0, 1)


def face(points, normals, head, marks):
    """1 en la cara: cabeza por delante de las orejas, con borde suave."""
    front = np.clip((points[:, 2] - (marks["orejas"][0][2] + 0.015)) / 0.03, 0, 1)
    return np.clip((head - 0.5) / 0.4, 0, 1) * front


def freckle_near(points, normals, head, marks, lip, bones):
    center = (marks["mejillas"][0] + marks["mejillas"][1]) / 2.0
    center[2] = marks["nariz"][2] - 0.01
    order = np.clip(np.linalg.norm(points - center, axis=1) / FRECKLE_REACH, 0, 1)
    never = lip > 0.2
    for eye in marks["ojos"]:
        never |= np.linalg.norm(points - eye, axis=1) < 0.016
    for side, sign in (("Left", 1.0), ("Right", -1.0)):
        never |= (bones[side + "Hand"] > 0.5) & (sign * normals[:, 0] < -0.3)  # palmas (en pose A miran al muslo)
    never |= (bones["Feet"] > 0.5) & (normals[:, 1] < -0.5)  # plantas
    order[never] = 1.0
    return 1.0 - np.sqrt(order)


# --- Rasterizado en UV ---

def rasterize(uv, index, values):
    """Interpola los valores de cada vertice (n x canales) dentro de cada triangulo, en el espacio de UV."""
    channels = values.shape[1]
    image = np.zeros((SIZE, SIZE, channels))
    filled = np.zeros((SIZE, SIZE), bool)
    pixels = uv * SIZE - 0.5
    for a, b, c in index:
        p = pixels[[a, b, c]]
        low = np.floor(p.min(0)).astype(int)
        high = np.ceil(p.max(0)).astype(int)
        low = np.clip(low, 0, SIZE - 1)
        high = np.clip(high, 0, SIZE - 1)
        xs, ys = np.meshgrid(np.arange(low[0], high[0] + 1), np.arange(low[1], high[1] + 1))
        q = np.stack([xs.ravel(), ys.ravel()], 1).astype(np.float64)
        v0, v1 = p[1] - p[0], p[2] - p[0]
        det = v0[0] * v1[1] - v0[1] * v1[0]
        if abs(det) < 1e-12:
            continue
        w = q - p[0]
        l1 = (w[:, 0] * v1[1] - w[:, 1] * v1[0]) / det
        l2 = (v0[0] * w[:, 1] - v0[1] * w[:, 0]) / det
        l0 = 1.0 - l1 - l2
        inside = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        if not inside.any():
            continue
        q = q[inside].astype(int)
        mixed = l0[inside, None] * values[a] + l1[inside, None] * values[b] + l2[inside, None] * values[c]
        image[q[:, 1], q[:, 0]] = mixed
        filled[q[:, 1], q[:, 0]] = True
    return image, filled


def pad(image, filled):
    """Extiende cada isla PAD pixeles con la media de sus vecinos ya rellenos."""
    for _ in range(PAD):
        total = np.zeros_like(image)
        count = np.zeros(filled.shape)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            shifted = np.roll(np.roll(filled, dy, 0), dx, 1)
            total += np.roll(np.roll(image * filled[..., None], dy, 0), dx, 1)
            count += shifted
        grow = (~filled) & (count > 0)
        image[grow] = total[grow] / count[grow, None]
        filled = filled | grow
    return image


def write_png(path, rgba):
    """PNG RGBA de 8 bits sin dependencias. glTF: v = 0 arriba, igual que las filas del PNG."""
    rows = b"".join(b"\x00" + row.tobytes() for row in rgba)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", rgba.shape[1], rgba.shape[0], 8, 6, 0, 0, 0)
    with open(path, "wb") as file:
        file.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def update_manifest(folder):
    import hashlib
    path = os.path.join(folder, "manifiesto.json")
    with open(path, encoding="utf-8") as file:
        manifest = json.load(file)
    with open(os.path.join(folder, FILE), "rb") as file:
        manifest["files"][FILE] = {"sha256": hashlib.sha256(file.read()).hexdigest()}
    with open(path, "w", encoding="utf-8") as file:
        json.dump(manifest, file, ensure_ascii=False, indent=1, sort_keys=True)
        file.write("\n")


def main(folder):
    mesh, joints = read_glb(os.path.join(folder, "cuerpo.glb"))
    with open(os.path.join(folder, "articulaciones.json"), encoding="utf-8") as file:
        joints_json = json.load(file)["bones"]
    with open(os.path.join(folder, "ojos.json"), encoding="utf-8") as file:
        eyes = json.load(file)
    points, normals = mesh["POSITION"], mesh["NORMAL"]
    head = bone_weight(mesh, joints, "Head")
    hand_parts = ("Hand", "Thumb", "Index", "Middle", "Ring", "Little")
    bones = {
        "LeftArm": bone_weight(mesh, joints, "LeftUpperArm") + bone_weight(mesh, joints, "LeftLowerArm"),
        "RightArm": bone_weight(mesh, joints, "RightUpperArm") + bone_weight(mesh, joints, "RightLowerArm"),
        "Feet": sum(bone_weight(mesh, joints, n) for n in joints if n.endswith("Foot") or n.endswith("Toes")),
    }
    for side in ("Left", "Right"):
        bones[side + "Hand"] = sum(bone_weight(mesh, joints, n) for n in joints
            if n.startswith(side) and any(part in n for part in hand_parts))
    marks = landmarks(points, normals, head, eyes)
    for name, value in marks.items():
        print("REFERENCIA", name, np.round(np.array(value), 4).tolist())
    lip = lips(points, normals, head, marks)
    values = np.stack([blush(points, normals, head, marks, bones, joints_json),
        freckle_near(points, normals, head, marks, lip, bones), lip, 1.0 - face(points, normals, head, marks)], 1)
    image, filled = rasterize(mesh["TEXCOORD_0"], mesh["INDEX"], values)
    image = pad(image, filled)
    image[..., 3][~filled & (image[..., 3] == 0)] = 1.0  # fondo: fuera de la cara
    write_png(os.path.join(folder, FILE), np.round(np.clip(image, 0, 1) * 255).astype(np.uint8))
    update_manifest(folder)
    print("GUARDADO", os.path.join(folder, FILE), "pixeles con piel: %.1f %%" % (100.0 * filled.mean()))


if __name__ == "__main__":
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    main(arguments[0] if arguments else os.path.join("godot", "datos", "humana"))
