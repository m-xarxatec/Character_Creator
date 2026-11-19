# SPDX-License-Identifier: GPL-3.0-or-later
"""Prueba del paso P.6. Uso: blender -b -P pruebas/fase_7/probar_recorte.py  (o python pruebas/fase_7/probar_recorte.py)

Compara godot/datos/animaciones/UAL1_Standard.glb (recortado) con la copia completa de pruebas/godot/:
solo las animaciones de humanoide.json, y todo lo que queda igual byte a byte. Además, recortar otra vez el original
da el mismo archivo (el de datos/ sale de blender/recortar_animaciones.py).
"""
import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import recortar_animaciones as ra  # noqa: E402

FULL = os.path.join(ROOT, "pruebas", "godot", "UAL1_Standard.glb")
TRIMMED = os.path.join(ROOT, "godot", "datos", "animaciones", "UAL1_Standard.glb")
CLIPS = os.path.join(ROOT, "godot", "datos", "animaciones", "humanoide.json")
MAX_BYTES = 1_500_000  # aprobado el 2026-11-19 (medido 1 464 396): el .glb no puede crecer (GitHub)
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def accessor_bytes(gltf, binary, index):
    """Bytes de un accessor, con su tipo, para comparar datos sin mirar los índices."""
    accessor = gltf["accessors"][index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    start = view.get("byteOffset", 0)
    meta = {key: value for key, value in accessor.items() if key != "bufferView"}
    return json.dumps(meta, sort_keys=True).encode() + binary[start:start + view["byteLength"]]


def sampler_data(gltf, binary, animation):
    return [(accessor_bytes(gltf, binary, s["input"]), accessor_bytes(gltf, binary, s["output"]), s["interpolation"])
            for s in animation["samplers"]]


def without_accessors(item):
    """Copia de un objeto del JSON con los índices de accessor a None (para comparar lo demás)."""
    copy = json.loads(json.dumps(item))
    for holder, key in ra.accessor_refs({"accessors": [], **copy}):
        holder[key] = None
    return copy


def main():
    full_json, full_bin = ra.read_glb(FULL)
    json_, bin_ = ra.read_glb(TRIMMED)
    with open(CLIPS, encoding="utf-8") as file:
        clips = json.load(file)
    wanted = [clip["animation"] for clip in clips["clips"]]
    names = [animation["name"] for animation in json_["animations"]]
    check("solo las animaciones de humanoide.json", sorted(names) == sorted(wanted), names)
    full_by_name = {animation["name"]: animation for animation in full_json["animations"]}
    for animation in json_["animations"]:
        original = full_by_name[animation["name"]]
        check("canales de %s" % animation["name"], animation["channels"] == original["channels"])
        check("datos de %s, byte a byte" % animation["name"],
              sampler_data(json_, bin_, animation) == sampler_data(full_json, full_bin, original))
    for key in ("asset", "scene", "scenes", "nodes", "materials"):
        check("%s igual" % key, json_.get(key) == full_json.get(key))
    parts = {"meshes": json_["meshes"], "skins": json_["skins"]}
    full_parts = {"meshes": full_json["meshes"], "skins": full_json["skins"]}
    check("malla y skin iguales (salvo índices)", without_accessors(parts) == without_accessors(full_parts))
    mesh_refs = [(h, k) for h, k in ra.accessor_refs({"accessors": [], **parts})]
    full_refs = [(h, k) for h, k in ra.accessor_refs({"accessors": [], **full_parts})]
    check("datos de malla y skin, byte a byte",
          [accessor_bytes(json_, bin_, h[k]) for h, k in mesh_refs]
          == [accessor_bytes(full_json, full_bin, h[k]) for h, k in full_refs])
    size = os.path.getsize(TRIMMED)
    check("tamaño < %d bytes" % MAX_BYTES, size < MAX_BYTES, "(%d bytes; completo %d)" % (size, os.path.getsize(FULL)))
    again_json, again_bin = ra.trim(full_json, full_bin, wanted)
    again = os.path.join(ROOT, "pruebas", "fase_7", "salida", "recorte_otra_vez.glb")
    os.makedirs(os.path.dirname(again), exist_ok=True)
    ra.write_glb(again, again_json, again_bin)
    with open(again, "rb") as a, open(TRIMMED, "rb") as b:
        check("recortar otra vez da el mismo archivo", a.read() == b.read())
    with open(TRIMMED, "rb") as file:
        digest = hashlib.sha256(file.read()).hexdigest()
    check("sha256 de humanoide.json", clips["sha256"] == digest, digest)
    print("RESULTADO:", "TODO BIEN" if not failures else "%d FALLOS: %s" % (len(failures), ", ".join(failures)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
