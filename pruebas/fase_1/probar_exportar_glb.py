# SPDX-License-Identifier: GPL-3.0-or-later
"""Pruebas del paso 1.4. Uso: blender -b -P pruebas/fase_1/probar_exportar_glb.py

Exporta los 5 cuerpos de ejemplo a pruebas/fase_1/salida/ y revisa cada .glb por dentro.
"""
import json
import os
import struct
import sys

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import generar_cuerpo as gc  # noqa: E402
from exportar_glb import export_glb, humanoid_names  # noqa: E402

BODIES = ("neutro", "mujer_baja", "hombre_alto_fuerte", "robusto_mayor", "delgada_estilizada")
SOCKETS = {"socket_hand_r": "RightHand", "socket_hand_l": "LeftHand", "socket_back": "UpperChest", "socket_hip": "Hips"}
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def read_glb_json(path):
    with open(path, "rb") as file:
        data = file.read()
    length = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + length])


def check_pose(mesh, sockets):
    """Sobre la escena de Blender (Z arriba, mira a -Y), antes de exportar."""
    bones = mesh.parent.data.bones
    for side, sign in (("Left", 1), ("Right", -1)):
        shoulder, elbow, wrist = (bones[side + part].head_local for part in ("UpperArm", "LowerArm", "Hand"))
        knuckle = bones[side + "MiddleProximal"].head_local
        drop = max(abs(p.z - shoulder.z) + abs(p.y - shoulder.y) for p in (elbow, wrist, knuckle))
        check(f"brazo {side} recto y horizontal", drop < 0.005 and sign * (knuckle.x - shoulder.x) > 0.4, f"desvio {drop:.4f} m")
        across = bones[side + "IndexProximal"].head_local - bones[side + "LittleProximal"].head_local
        check(f"palma {side} hacia abajo", across.y < -0.03 and abs(across.z) < 0.01, f"indice-menique y={across.y:.3f} z={across.z:.3f}")
    points = [v.co for v in mesh.data.vertices]
    place = {s.name: s.matrix_world.translation for s in sockets}
    check("anclaje de espalda detras de la piel", place["socket_back"].y > max(p.y for p in points if abs(p.x) < 0.03 and abs(p.z - place["socket_back"].z) < 0.03))
    check("anclaje de cadera fuera de la piel, a la izquierda", place["socket_hip"].x > max(p.x for p in points if abs(p.z - place["socket_hip"].z) < 0.03))
    for side in ("l", "r"):
        gap = (place["socket_hand_" + side] - bones[("Left" if side == "l" else "Right") + "Hand"].head_local).length
        check(f"anclaje de mano {side} en la palma", 0.02 < gap < 0.12, f"a {gap:.3f} m de la muneca")
    check("los anclajes no estan girados", all(s.matrix_world.to_quaternion().angle < 1e-4 for s in sockets))


def check_glb(path, expected_vertices_min):
    gltf = read_glb_json(path)
    nodes = gltf["nodes"]
    parent = {child: node["name"] for node in nodes for child in node.get("children", [])}
    joints = [nodes[i]["name"] for i in gltf["skins"][0]["joints"]]
    check("53 huesos con nombres del perfil humanoide", sorted(joints) == sorted(humanoid_names().values()), str(len(joints)))
    check("sin extensiones (sin Draco)", not gltf.get("extensionsUsed"), str(gltf.get("extensionsUsed")))
    for socket, bone in SOCKETS.items():
        index = next((i for i, n in enumerate(nodes) if n["name"] == socket), None)
        check(f"{socket} cuelga de {bone}", index is not None and parent.get(index) == bone)
    primitives = gltf["meshes"][0]["primitives"]
    attributes = primitives[0]["attributes"]
    check("una sola malla, sin formas sueltas", len(gltf["meshes"]) == 1 and len(primitives) == 1 and "targets" not in primitives[0])
    check("4 influencias como maximo", "JOINTS_0" in attributes and "JOINTS_1" not in attributes)
    check("lleva el color de la prenda", "COLOR_0" in attributes)
    check("sin animaciones", not gltf.get("animations"))
    position = gltf["accessors"][attributes["POSITION"]]
    size = [hi - lo for lo, hi in zip(position["min"], position["max"])]
    check("metros, Y arriba y pies en el suelo", 1.2 < size[1] < 2.4 and abs(position["min"][1]) < 0.001, f"alto {size[1]:.3f}, suelo {position['min'][1]:.4f}")
    check("pose T (mas ancho que fondo)", size[0] > 3 * size[2], f"ancho {size[0]:.2f}, fondo {size[2]:.2f}")
    check("no se pierden vertices", position["count"] >= expected_vertices_min, str(position["count"]))
    toes = next(n for n in nodes if n["name"] == "LeftToes")["translation"]
    return gltf, toes


os.makedirs(os.path.join(ROOT, "pruebas", "fase_1", "salida"), exist_ok=True)
for body in BODIES:
    print(body)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mesh, sockets = gc.build_character(gc.load_spec(os.path.join(ROOT, "pruebas", "fase_1", "cuerpos", body + ".json")))
    check_pose(mesh, sockets)
    path = os.path.join(ROOT, "pruebas", "fase_1", "salida", body + ".glb")
    export_glb(mesh, sockets, path)
    check_glb(path, len(mesh.data.vertices))

print("RESULTADO:", "TODO BIEN" if not failures else f"{len(failures)} FALLOS: {sorted(set(failures))}")
sys.exit(1 if failures else 0)
