# SPDX-License-Identifier: GPL-3.0-or-later
"""Renderiza un personaje de frente, perfil y espalda en una sola imagen, para revisarlo a ojo.

Uso: blender -b -P blender/render_vistas.py -- cuerpo.json salida.png
"""
import math
import os
import sys
import tempfile

import bpy
import numpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generar_cuerpo as gc  # noqa: E402

TILE = 600  # pixeles por vista (cuadrada)
VIEWS = (("frente", 0), ("perfil", 90), ("espalda", 180))  # grados alrededor de Z; el personaje mira a -Y
SKIN = (0.92, 0.78, 0.68, 1.0)
GARMENT = (0.12, 0.12, 0.15, 1.0)
BACKGROUND = (0.80, 0.82, 0.86, 1.0)


def render_views(mesh, out_path):
    scene = bpy.context.scene
    _setup_render(scene)
    _apply_preview_material(mesh)
    camera = _add_camera(scene, mesh)
    tiles = [_render_tile(scene, camera, angle) for _, angle in VIEWS]
    _save_sheet(numpy.concatenate(tiles, axis=1), out_path)


def _setup_render(scene):
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = scene.render.resolution_y = TILE
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("Fondo")
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = BACKGROUND
    background.inputs["Strength"].default_value = 0.5
    # Luz principal por delante y otra mas suave por detras, para que la espalda no quede a oscuras.
    for name, energy, turn in (("Sol", 3.0, 25), ("Contraluz", 1.5, 205)):
        sun = bpy.data.objects.new(name, bpy.data.lights.new(name, "SUN"))
        sun.data.energy = energy
        sun.rotation_euler = (math.radians(50), 0.0, math.radians(turn))
        scene.collection.objects.link(sun)


def _apply_preview_material(mesh):
    """Piel clara y prenda oscura, con el mismo corte en 0,5 que usara el shader de Godot."""
    material = bpy.data.materials.new("Vista previa")
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    garment = nodes.new("ShaderNodeVertexColor")
    garment.layer_name = "garment"
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].color = SKIN
    ramp.color_ramp.elements[1].position = 0.5
    ramp.color_ramp.elements[1].color = GARMENT
    shader = nodes.new("ShaderNodeBsdfDiffuse")
    output = nodes.new("ShaderNodeOutputMaterial")
    links.new(garment.outputs["Color"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], shader.inputs["Color"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    mesh.data.materials.clear()
    mesh.data.materials.append(material)


def _add_camera(scene, mesh):
    size = gc.measure(mesh)
    data = bpy.data.cameras.new("Camara")
    data.type = "ORTHO"
    data.ortho_scale = max(size["height"], size["width"]) * 1.08
    camera = bpy.data.objects.new("Camara", data)
    camera["center_z"] = size["height"] / 2
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera


def _render_tile(scene, camera, degrees):
    angle = math.radians(degrees)
    camera.location = (5 * math.sin(angle), -5 * math.cos(angle), camera["center_z"])
    camera.rotation_euler = (math.radians(90), 0.0, angle)
    with tempfile.TemporaryDirectory() as folder:
        scene.render.filepath = os.path.join(folder, "vista.png")
        bpy.ops.render.render(write_still=True)
        image = bpy.data.images.load(scene.render.filepath)
        pixels = numpy.array(image.pixels[:], dtype=numpy.float32).reshape(TILE, TILE, 4)
        bpy.data.images.remove(image)
    return pixels


def _save_sheet(pixels, out_path):
    height, width = pixels.shape[:2]
    sheet = bpy.data.images.new("Vistas", width, height, alpha=True)
    sheet.pixels = pixels.ravel()
    sheet.filepath_raw = out_path
    sheet.file_format = "PNG"
    sheet.save()


def main():
    args = sys.argv[sys.argv.index("--") + 1:]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mesh, _ = gc.build_character(gc.load_spec(args[0]))
    out_path = os.path.abspath(args[1])
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    render_views(mesh, out_path)
    print("GUARDADO:", out_path)


if __name__ == "__main__":
    try:
        main()
    except gc.BodyError as error:
        print("ERROR:", error)
        sys.exit(1)
