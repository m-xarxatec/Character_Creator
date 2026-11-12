class_name BodyMaterial
extends RefCounted
## Material del cuerpo en estilo ilustración: toon.gdshader con el contorno (outline.gdshader) como next_pass.
##
## Uso:
##   BodyMaterial.apply(species.mesh)
##   BodyMaterial.set_garment_visible(species.mesh, false)
##   BodyMaterial.set_outline_width(species.mesh, 2.0)    # píxeles, de 0 (sin contorno) a 10
##   BodyMaterial.set_unlit(species.mesh, true)           # sin luces ni contorno: color exacto, para las pruebas de color
##   var copy := BodyMaterial.standalone(species.mesh)    # para un juego sin el addon (shaders incrustados)
## El interruptor de la prenda, los colores y el grosor son parámetros del material: el exportador (paso 3.6) lee
## is_garment_visible() y get_color(). Si la malla no tiene este material, valen DEFAULTS (prenda visible).
## DEFAULTS y OUTLINE_DEFAULTS son los valores por defecto de toon.gdshader y outline.gdshader: apply() los pone
## todos, y hacen falta aquí porque con --headless Godot no los lee del shader (probar_material.gd comprueba que coinciden).

const SHADER := preload("toon.gdshader")
const OUTLINE_SHADER := preload("outline.gdshader")
const DEFAULTS := {
	"skin_color": Color(0.80, 0.80, 0.80), "garment_color": Color(0.20, 0.20, 0.23), "show_garment": true, "unlit": false,
	"mid_shade": 0.9, "shadow_shade": 0.73, "mid_threshold": 0.45,
	"shadow_threshold": 0.0, "softness": 0.04, "rim_color": Color(1.0, 0.95, 0.92), "rim_strength": 0.25, "rim_width": 0.3}
const OUTLINE_DEFAULTS := {"outline_color": Color(0.07, 0.05, 0.06), "width_px": 2.5}
const MAX_OUTLINE_PX := 10.0  # el máximo de width_px en outline.gdshader


static func apply(mesh: MeshInstance3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for name: String in DEFAULTS:
		material.set_shader_parameter(name, DEFAULTS[name])
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	for name: String in OUTLINE_DEFAULTS:
		outline.set_shader_parameter(name, OUTLINE_DEFAULTS[name])
	material.next_pass = outline
	material.set_meta("outline", outline)  # para devolver el contorno al salir de unlit
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


## Sin luces, sin rim y sin contorno: cada píxel con su color exacto. Al apagarlo vuelve el contorno con su grosor.
static func set_unlit(mesh: MeshInstance3D, unlit: bool) -> void:
	var material := mesh.material_override as ShaderMaterial
	material.set_shader_parameter("unlit", unlit)
	material.next_pass = null if unlit else material.get_meta("outline")


static func is_unlit(mesh: MeshInstance3D) -> bool:
	return _parameter(mesh, "unlit")


## Grosor del contorno en píxeles, recortado a [0, 10]; rechaza NaN e infinito (devuelve false y no cambia nada).
static func set_outline_width(mesh: MeshInstance3D, pixels: float) -> bool:
	if not is_finite(pixels):
		return false
	((mesh.material_override as ShaderMaterial).get_meta("outline") as ShaderMaterial).set_shader_parameter(
		"width_px", clampf(pixels, 0.0, MAX_OUTLINE_PX))
	return true


static func get_outline_width(mesh: MeshInstance3D) -> float:
	var material := mesh.material_override as ShaderMaterial
	if material == null or material.shader != SHADER or not material.has_meta("outline"):
		return OUTLINE_DEFAULTS["width_px"]
	return (material.get_meta("outline") as ShaderMaterial).get_shader_parameter("width_px")


## Copia para un juego sin el addon (el exportador la guarda como .tres): los dos shaders van incrustados, sin ruta,
## con los valores de la malla y con luces (sin `unlit`). Si la malla no tiene este material, valen los valores por defecto.
static func standalone(mesh: MeshInstance3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _embedded(SHADER)
	for name: String in DEFAULTS:
		material.set_shader_parameter(name, _parameter(mesh, name))
	material.set_shader_parameter("unlit", false)
	var outline := ShaderMaterial.new()
	outline.shader = _embedded(OUTLINE_SHADER)
	outline.set_shader_parameter("outline_color", OUTLINE_DEFAULTS["outline_color"])
	outline.set_shader_parameter("width_px", get_outline_width(mesh))
	material.next_pass = outline
	return material


static func _embedded(shader: Shader) -> Shader:
	var copy := Shader.new()
	copy.code = shader.code
	return copy


static func _parameter(mesh: MeshInstance3D, name: String) -> Variant:
	var material := mesh.material_override as ShaderMaterial
	var value: Variant = material.get_shader_parameter(name) if material and material.shader == SHADER else null
	return value if value != null else DEFAULTS[name]
