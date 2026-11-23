"""Lectura mínima de .glb (sin dependencias salvo numpy)."""
import json, struct
import numpy as np

COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
SIZE = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read(path):
    raw = open(path, "rb").read()
    n = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + n])
    m = struct.unpack_from("<I", raw, 20 + n)[0]
    return doc, raw[28 + n:28 + n + m]


def _raw(doc, buf, view, ctype, count, k, extra=0):
    v = doc["bufferViews"][view]
    dt = np.dtype(COMP[ctype])
    return np.frombuffer(buf, dt, count * k, v.get("byteOffset", 0) + extra).reshape(count, k)


def accessor(doc, buf, i):
    a = doc["accessors"][i]
    if "bufferView" not in a:   # disperso: ceros + valores sueltos
        k = SIZE[a["type"]]
        out = np.zeros((a["count"], k), np.float32)
        sp = a.get("sparse")
        if sp:
            ix = _raw(doc, buf, sp["indices"]["bufferView"], sp["indices"]["componentType"], sp["count"], 1,
                      sp["indices"].get("byteOffset", 0)).ravel()
            out[ix] = _raw(doc, buf, sp["values"]["bufferView"], a["componentType"], sp["count"], k,
                           sp["values"].get("byteOffset", 0))
        return out
    v = doc["bufferViews"][a["bufferView"]]
    k = SIZE[a["type"]]
    dt = np.dtype(COMP[a["componentType"]])
    off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = v.get("byteStride", 0)
    if stride and stride != dt.itemsize * k:
        rows = [np.frombuffer(buf, dt, k, off + r * stride) for r in range(a["count"])]
        out = np.array(rows)
    else:
        out = np.frombuffer(buf, dt, a["count"] * k, off).reshape(a["count"], k)
    if a.get("normalized"):
        out = out.astype(np.float32) / np.iinfo(dt).max
    return out


def mesh_data(doc, buf, targets=True):
    p = doc["meshes"][0]["primitives"][0]
    at = p["attributes"]
    d = {name: accessor(doc, buf, at[name]) for name in at}
    d["indices"] = accessor(doc, buf, p["indices"]).ravel()
    if targets:
        names = doc["meshes"][0].get("extras", {}).get("targetNames", [])
        d["targets"] = {names[i] if i < len(names) else str(i): accessor(doc, buf, t["POSITION"])
                        for i, t in enumerate(p.get("targets", []))}
    return d


def joint_names(doc):
    return [doc["nodes"][j]["name"] for j in doc["skins"][0]["joints"]]
