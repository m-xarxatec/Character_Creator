# SPDX-License-Identifier: GPL-3.0-or-later
"""Pasos 3.6.5 y 3.6.6: los .glb exportados por el núcleo de Godot se abren bien en Blender y se ve la prenda.

Uso: (ulimit -v 4000000; timeout 300 blender -b -P pruebas/fase_3/probar_glb_en_blender.py 2>&1 | grep -E 'FALLO|RESULTADO|bien')
Con `-- <ruta.glb>...` prueba solo esos archivos (sin la prenda ni las capturas).
Antes: pruebas/godot/probar_exportar.gd (escribe pruebas/fase_3/salida/t/ y a/) y
pruebas/godot/probar_prenda_exportada.gd (escribe pruebas/fase_3/salida/prenda/).
Capturas de la prenda: pruebas/capturas/prenda_blender/.
"""
import glob
import json
import math
import os
import struct
import sys

import bpy
import numpy

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "salida")
SHOTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "capturas", "prenda_blender")
SOCKETS = {"socket_hand_r": "RightHand", "socket_hand_l": "LeftHand", "socket_back": "UpperChest", "socket_hip": "Hips"}
failures = []


def check(name, condition, detail=""):
    print(("  bien  " if condition else "  FALLO ") + name, detail)
    if not condition:
        failures.append(name)


def check_file(path):
    label = os.path.relpath(path, OUT) + ": "
    bpy.ops.wm.read_factory_settings(use_empty=True)
    try:
        result = bpy.ops.import_scene.gltf(filepath=path)
    except Exception as error:  # noqa: BLE001 - cualquier fallo del importador es un fallo de la prueba
        check(label + "se abre sin errores", False, str(error))
        return
    check(label + "se abre sin errores", result == {"FINISHED"}, result)
    rigs = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    # El importador de Blender añade una esfera para dibujar los huesos, en la colección glTF_not_exported.
    meshes = [o for o in bpy.data.objects if o.type == "MESH"
              and not any(c.name == "glTF_not_exported" for c in o.users_collection)]
    check(label + "un esqueleto con 53 huesos", len(rigs) == 1 and len(rigs[0].data.bones) == 53,
          [len(r.data.bones) for r in rigs])
    sockets = {o.name: o for o in bpy.data.objects if o.name.startswith("socket_")}
    hung = all(name in sockets and sockets[name].type == "EMPTY" and sockets[name].parent_type == "BONE"
               and sockets[name].parent_bone == bone for name, bone in SOCKETS.items())
    check(label + "4 vacíos socket_… hijos de su hueso", len(sockets) == 4 and hung,
          {n: (o.type, o.parent_bone) for n, o in sockets.items()})
    check(label + "una malla", len(meshes) == 1, len(meshes))
    if len(meshes) != 1 or len(rigs) != 1:
        return
    mesh = meshes[0]
    bones = set(rigs[0].data.bones.keys())
    most = max(sum(1 for g in v.groups if g.weight > 0 and mesh.vertex_groups[g.group].name in bones)
               for v in mesh.data.vertices)
    check(label + "sin formas, con color por vértice y máximo 4 influencias",
          mesh.data.shape_keys is None and len(mesh.data.color_attributes) >= 1 and most <= 4,
          f"{len(mesh.data.vertices)} vértices, {len(mesh.data.color_attributes)} colores, {most} influencias")
    return mesh


def check_garment(path, shown):
    """La prenda está en la textura del material, en su sitio según las UV, y el color por vértice no tiñe el material
    (RGB blanco, `garment` en el alfa)."""
    label = os.path.relpath(path, OUT) + ": "
    mesh = check_file(path)
    if mesh is None:
        return
    material = mesh.active_material
    nodes = material.node_tree.nodes if material and material.node_tree else []
    images = [n.image for n in nodes if n.type == "TEX_IMAGE" and n.image]
    colors = mesh.data.color_attributes[0]
    tinted = any(min(d.color[:3]) < 0.999 for d in colors.data)
    if not shown:
        check(label + "prenda oculta: material sin textura y color por vértice blanco", not images and not tinted,
              [n.type for n in nodes])
        # Sin textura, Workbench dibuja el color de visor, que el importador deja en gris (el color base va a un nodo
        # Mix con el color por vértice): se pone el `baseColorFactor` del .glb.
        material.diffuse_color = base_color(path)
        render(label, os.path.basename(path), False)
        return
    check(label + "material con una textura de 2048 px y color por vértice blanco",
          len(images) == 1 and tuple(images[0].size) == (2048, 2048) and not tinted,
          ([tuple(i.size) for i in images], [n.type for n in nodes]))
    if len(images) != 1:
        return
    image = images[0]
    pixels = numpy.empty(image.size[0] * image.size[1] * 4, dtype=numpy.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape(image.size[1], image.size[0], 4)  # fila 0 = abajo
    data = mesh.data
    uvs = data.uv_layers.active.data
    per_corner = colors.domain == "CORNER"
    counted, wrong = [0, 0], 0
    for loop in data.loops:
        value = colors.data[loop.index if per_corner else loop.vertex_index].color[3]
        if 0.01 < value < 0.99:
            continue
        u, v = uvs[loop.index].uv
        x = min(image.size[0] - 1, int(u * image.size[0]))
        y = min(image.size[1] - 1, int(v * image.size[1]))
        pixel = pixels[y, x]
        is_garment = value > 0.5
        counted[is_garment] += 1
        wrong += (pixel[2] > pixel[0]) != is_garment  # prenda azulada, piel rojiza
    check(label + "cada esquina de piel o prenda cae en un píxel de su color en la textura",
          wrong == 0 and counted[0] > 1000 and counted[1] > 1000,
          f"{counted[0]} de piel, {counted[1]} de prenda, {wrong} con otro color")
    render(label, os.path.basename(path), True)


def base_color(path):
    """`baseColorFactor` del primer material, leído del JSON del .glb (lineal, como `diffuse_color`)."""
    with open(path, "rb") as file:
        data = file.read()
    length = struct.unpack("<I", data[12:16])[0]
    material = json.loads(data[20:20 + length])["materials"][0]
    return material.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1.0, 1.0, 1.0, 1.0])


SKIN = (0.9, 0.6, 0.5)  # los de probar_prenda_exportada.gd
GARMENT = (0.1, 0.2, 0.6)
DARK = 0.3  # la prenda más oscura tiene un canal a 0,6


def render(label, name, shown):
    """Captura de frente con Workbench (luz plana, color de la textura: los colores salen tal cual, sin luces;
    el material ya tiene luz desde el 3.11a) y cuenta los colores."""
    scene = bpy.context.scene
    camera = bpy.data.objects.new("camara", bpy.data.cameras.new("camara"))
    scene.collection.objects.link(camera)
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.0
    camera.location = (0.0, -3.0, 0.9)  # el personaje mira a -Y en Blender (+Z en glTF)
    camera.rotation_euler = (math.radians(90), 0.0, 0.0)
    scene.camera = camera
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "TEXTURE" if shown else "MATERIAL"  # sin textura, TEXTURE dibuja gris
    scene.view_settings.view_transform = "Standard"  # sin AgX: los colores salen tal cual
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.film_transparent = True
    os.makedirs(SHOTS, exist_ok=True)
    scene.render.filepath = os.path.join(SHOTS, os.path.splitext(name)[0] + ".png")
    try:
        result = bpy.ops.render.render(write_still=True)
    except Exception as error:  # noqa: BLE001 - sin captura no se puede revisar a ojo
        result = str(error)
    check(label + "captura guardada", result == {"FINISHED"} and os.path.exists(scene.render.filepath), result)
    if result != {"FINISHED"}:
        return
    shot = bpy.data.images.load(scene.render.filepath)
    pixels = numpy.empty(len(shot.pixels), dtype=numpy.float32)
    shot.pixels.foreach_get(pixels)
    pixels = pixels.reshape(-1, 4)
    body = pixels[pixels[:, 3] > 0.99][:, :3]
    # Cada píxel, al color más cercano. Lo que se busca es la piel teñida de negro por el color por vértice: 0 píxeles
    # oscuros (todos los canales < DARK). Los que quedan lejos de los dos colores (mezcla en el borde de la prenda)
    # solo se miden.
    distance = numpy.stack([numpy.abs(body - numpy.array(c)).max(axis=1) for c in (SKIN, GARMENT)])
    nearest = distance.argmin(axis=0)
    far = int((distance.min(axis=0) > 0.2).sum())
    dark = int((body.max(axis=1) < DARK).sum())
    counts = [int((nearest == 0).sum()), int((nearest == 1).sum())]
    check(label + ("captura: piel y prenda" if shown else "captura: todo piel") + ", sin píxeles oscuros",
          counts[0] > 1000 and (counts[1] > 1000 if shown else counts[1] == 0) and dark == 0,
          f"{counts[0]} px de piel, {counts[1]} de prenda, {dark} oscuros; medida: {far} a más de 0,2 de los dos")


paths = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if paths:  # solo los .glb dados (p. ej. los de probar_aleatorios.gd): sin la prenda ni las capturas
    for file in paths:
        check_file(os.path.abspath(file))
else:
    files = sorted(glob.glob(os.path.join(OUT, "t", "*.glb")) + glob.glob(os.path.join(OUT, "a", "*.glb")))
    check("hay 4 .glb que probar", len(files) == 4, len(files))
    for file in files:
        check_file(file)
    for name, shown in (("visible.glb", True), ("oculta.glb", False)):
        check_garment(os.path.join(OUT, "prenda", name), shown)
print(f"RESULTADO: {len(failures)} fallos" + (f" ({', '.join(failures)})" if failures else ""))
sys.exit(1 if failures else 0)
