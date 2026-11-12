class_name BodyMaterial
extends RefCounted
## Material del cuerpo (body.gdshader) y el interruptor de la prenda base.
##
## Uso:
##   BodyMaterial.apply(species.mesh)
##   BodyMaterial.set_garment_visible(species.mesh, false)
## El interruptor es un parámetro del material: el exportador (paso 3.6) lo lee con is_garment_visible() y los colores con get_color().
## Si la malla no tiene este material, valen DEFAULTS (prenda visible).

const SHADER := preload("body.gdshader")
## Los mismos valores por defecto que body.gdshader. Hacen falta aquí: con --headless, Godot no los lee del shader.
const DEFAULTS := {"show_garment": true, "skin_color": Color(0.93, 0.80, 0.70), "garment_color": Color(0.20, 0.20, 0.23)}


static func apply(mesh: MeshInstance3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for name: String in DEFAULTS:
		material.set_shader_parameter(name, DEFAULTS[name])
	mesh.material_override = material
	return material


static func set_garment_visible(mesh: MeshInstance3D, visible: bool) -> void:
	(mesh.material_override as ShaderMaterial).set_shader_parameter("show_garment", visible)


static func is_garment_visible(mesh: MeshInstance3D) -> bool:
	return _parameter(mesh, "show_garment")


## name: "skin_color" o "garment_color".
static func get_color(mesh: MeshInstance3D, name: String) -> Color:
	return _parameter(mesh, name)


## name: "skin_color" o "garment_color".
static func set_color(mesh: MeshInstance3D, name: String, color: Color) -> void:
	(mesh.material_override as ShaderMaterial).set_shader_parameter(name, color)


static func _parameter(mesh: MeshInstance3D, name: String) -> Variant:
	var material := mesh.material_override as ShaderMaterial
	var value: Variant = material.get_shader_parameter(name) if material and material.shader == SHADER else null
	return value if value != null else DEFAULTS[name]
