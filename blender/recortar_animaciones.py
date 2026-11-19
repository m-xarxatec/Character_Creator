# SPDX-License-Identifier: GPL-3.0-or-later
"""Deja en un .glb solo las animaciones pedidas (paso P.6). Lo demás sale igual byte a byte.

Uso: blender -b -P blender/recortar_animaciones.py -- entrada.glb salida.glb Idle_Loop Walk_Loop …
     (o con python: python blender/recortar_animaciones.py entrada.glb salida.glb Idle_Loop …)
No usa bpy: recorta el JSON y el trozo binario del .glb, sin volver a exportarlo (reexportar cambiaría el esqueleto).
Quita los accessors y bufferViews que ya no usa nadie y renumera los que quedan, en su orden.
"""
import json
import struct
import sys

GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def read_glb(path):
    """Devuelve (json, bin) de un .glb."""
    with open(path, "rb") as file:
        data = file.read()
    magic, version, _ = struct.unpack_from("<III", data, 0)
    if magic != GLB_MAGIC or version != 2:
        raise ValueError("no es un .glb 2.0: " + path)
    json_length, json_type = struct.unpack_from("<II", data, 12)
    bin_start = 20 + json_length
    bin_length, bin_type = struct.unpack_from("<II", data, bin_start)
    if json_type != JSON_CHUNK or bin_type != BIN_CHUNK:
        raise ValueError("trozos inesperados en " + path)
    return json.loads(data[20:bin_start]), data[bin_start + 8:bin_start + 8 + bin_length]


def write_glb(path, gltf, binary):
    text = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    text += b" " * (-len(text) % 4)
    binary += b"\0" * (-len(binary) % 4)
    total = 12 + 8 + len(text) + 8 + len(binary)
    with open(path, "wb") as file:
        file.write(struct.pack("<III", GLB_MAGIC, 2, total))
        file.write(struct.pack("<II", len(text), JSON_CHUNK) + text)
        file.write(struct.pack("<II", len(binary), BIN_CHUNK) + binary)


def accessor_refs(gltf):
    """Lista de (objeto, clave) que apuntan a un accessor. Falla si el archivo usa algo que no se sabe recortar."""
    if any("sparse" in accessor for accessor in gltf["accessors"]) or gltf.get("extensionsUsed"):
        raise ValueError("el .glb usa accessors dispersos o extensiones: no se sabe recortar")
    refs = []
    for mesh in gltf.get("meshes", []):
        for primitive in mesh["primitives"]:
            refs += [(primitive["attributes"], key) for key in primitive["attributes"]]
            if "indices" in primitive:
                refs.append((primitive, "indices"))
            for target in primitive.get("targets", []):
                refs += [(target, key) for key in target]
    for skin in gltf.get("skins", []):
        if "inverseBindMatrices" in skin:
            refs.append((skin, "inverseBindMatrices"))
    for animation in gltf.get("animations", []):
        for sampler in animation["samplers"]:
            refs += [(sampler, "input"), (sampler, "output")]
    return refs


def trim(gltf, binary, keep_names):
    """Devuelve (json, bin) con solo las animaciones de keep_names, en su orden original."""
    gltf = json.loads(json.dumps(gltf))
    found = [animation["name"] for animation in gltf.get("animations", [])]
    missing = [name for name in keep_names if name not in found]
    if missing:
        raise ValueError("no están en el .glb: " + ", ".join(missing))
    if len(gltf["buffers"]) != 1 or any("byteStride" in view for view in gltf["bufferViews"]):
        raise ValueError("se esperaba un solo buffer y bufferViews sin byteStride")
    gltf["animations"] = [animation for animation in gltf["animations"] if animation["name"] in keep_names]
    refs = accessor_refs(gltf)
    old_accessors = sorted({holder[key] for holder, key in refs})
    new_accessor = {old: new for new, old in enumerate(old_accessors)}
    for holder, key in refs:
        holder[key] = new_accessor[holder[key]]
    accessors = [gltf["accessors"][old] for old in old_accessors]
    old_views = sorted({accessor["bufferView"] for accessor in accessors if "bufferView" in accessor})
    if any("bufferView" in item for item in gltf.get("images", [])):
        raise ValueError("el .glb tiene imágenes en bufferViews: no se sabe recortar")
    new_view = {old: new for new, old in enumerate(old_views)}
    for accessor in accessors:
        accessor["bufferView"] = new_view[accessor["bufferView"]]
    views = []
    out = bytearray()
    for old in old_views:
        view = dict(gltf["bufferViews"][old])
        start = view.get("byteOffset", 0)
        out += b"\0" * (-len(out) % 4)
        view["byteOffset"] = len(out)
        out += binary[start:start + view["byteLength"]]
        views.append(view)
    gltf["accessors"] = accessors
    gltf["bufferViews"] = views
    gltf["buffers"][0]["byteLength"] = len(out)
    return gltf, bytes(out)


def main(args):
    if len(args) < 3:
        print(__doc__)
        return 1
    gltf, binary = read_glb(args[0])
    gltf, binary = trim(gltf, binary, args[2:])
    write_glb(args[1], gltf, binary)
    print("RESULTADO: %d animaciones en %s" % (len(gltf["animations"]), args[1]))
    return 0


if __name__ == "__main__":
    ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    sys.exit(main(ARGS))
