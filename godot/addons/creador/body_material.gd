class_name BodyMaterial
extends RefCounted
## Material del cuerpo en estilo ilustración: toon.gdshader con el contorno (outline.gdshader) como next_pass.
##
## Uso:
##   BodyMaterial.apply(species.mesh)
##   BodyMaterial.set_garment_visible(species.mesh, false)
##   BodyMaterial.set_outline_width(species.mesh, 2.0)    # píxeles, de 0 (sin contorno) a 10
##   BodyMaterial.set_finish(species.mesh, "rim_width", 0.4)   # acabado (paso 4.7): las claves de FINISH
##   var finish := BodyMaterial.get_finish(species.mesh)       # {softness, rim_strength, rim_width, width_px}
##   BodyMaterial.set_unlit(species.mesh, true)           # sin luces ni contorno: color exacto, para las pruebas de color
##   var copy := BodyMaterial.standalone(species.mesh)    # para un juego sin el addon (shaders incrustados)
##   BodyMaterial.apply(piece_mesh, true)                 # paso AB.6: una pieza (ropa, pelo) sobre el cuerpo
##   BodyMaterial.set_skin_zones(species.mesh, species.skin_zones)   # SH.8: rubor, labios y pecas (null: sin zonas)
##   BodyMaterial.set_style(species.mesh, true)          # SH.7a: estilo anime (toon_soft) en esta malla; false: clásico
##   BodyMaterial.set_skin(species.mesh, "freckles", 3)   # SH.7a: piel del estilo anime (claves de SKIN), solo el cuerpo
## Paso AB.6: una pieza usa una copia del toon que se adelanta PIECE_PULL metros hacia la cámara: tapa la piel que
## asoma a menos de esa distancia al moverse (sin borrar nada). El shader del cuerpo no cambia.
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
const OUTLINE_DEFAULTS := {"outline_color": Color(0.07, 0.05, 0.06), "width_px": 2.5, "outline_tint": 0.0, "face_line": 1.0,
	"skin_color": Color(0.80, 0.80, 0.80), "garment_color": Color(0.20, 0.20, 0.23), "show_garment": true}
const OUTLINE_SYNC := ["skin_color", "garment_color", "show_garment", "skin_zones"]  # SH.4b: los lee también el contorno
const MAX_OUTLINE_PX := 10.0  # el máximo de width_px en outline.gdshader
const PIECE_PULL := 0.005  # metros (paso AB.6)
const PULL_CODE := """uniform float depth_pull = 0.0;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz -= normalize(view.xyz) * depth_pull;
	POSITION = PROJECTION_MATRIX * view;
}

"""
static var _piece_shader: Shader
const SOFT_SHADER := preload("toon_soft.gdshader")
const SOFT_DEFAULTS := {
	"skin_color": Color(0.80, 0.80, 0.80), "garment_color": Color(0.20, 0.20, 0.23), "show_garment": true, "unlit": false,
	"threshold": 0.05, "softness": 0.09, "shade_strength": 1.0, "ground_weight": 0.025,
	"rim_color": Color(1.0, 0.95, 0.92), "rim_strength": 0.075, "rim_width": 0.3, "detail_amount": 0.0,
	"edge_strength": 0.0, "gloss_strength": 0.0, "gloss_size": 0.05, "gloss_softness": 0.05,
	"gloss_color": Color(1.0, 0.96, 0.94), "blush_amount": 0.0, "lips_amount": 0.0, "freckles": 0.0,
	"shadow_receive": 1.0, "face_shadow_receive": 1.0, "face_light": 0.0, "hair_band_strength": 0.0, "hair_band_height": 0.55,
	"hair_band_width": 0.07, "hair_band_softness": 0.05, "hair_band_color": Color(1.0, 0.98, 0.95),
	"hair_head": Transform3D.IDENTITY}
static var soft_enabled := false  # estilo por defecto de apply() (SH.2); cada malla cambia con set_style (SH.7a)
static var _soft_piece_shader: Shader
## Acabado: borde entre tonos, rim (fuerza y ancho) y grosor del contorno, con su rango (el hint_range de los shaders).
const FINISH := {"softness": [0.0, 0.5], "rim_strength": [0.0, 1.0], "rim_width": [0.0, 1.0], "width_px": [0.0, MAX_OUTLINE_PX]}
## SH.7a: piel del estilo anime, solo en el cuerpo (el hint_range de toon_soft). freckles va de uno en uno.
const SKIN := {"edge_strength": [0.0, 1.0], "gloss_strength": [0.0, 1.0], "blush_amount": [0.0, 1.0],
	"lips_amount": [0.0, 1.0], "freckles": [0.0, 10.0], "face_shadow_receive": [0.0, 1.0], "face_light": [0.0, 0.5],
	"outline_tint": [0.0, 1.0], "face_line": [0.0, 1.0], "hair_band": [0.0, 2.0]}
const OUTLINE_SKIN := ["outline_tint", "face_line"]  # SH.4b: van al material del contorno
## Al pasar el cuerpo al estilo anime: banda y brillo elegidos (D52); rubor y labios, la propuesta de la hoja de SH.8.
## D54: sin sombra proyectada en la cara (la A); luz en la cara, línea teñida y línea en la cara, propuestas de SH.4b y X.7.
## hair_band (SH.6b): la vista lo copia como hair_band_strength a las piezas de pelo; en el cuerpo no hace nada.
const SKIN_START := {"edge_strength": 0.6, "gloss_strength": 0.35, "blush_amount": 0.35, "lips_amount": 0.45, "freckles": 0.0,
	"face_shadow_receive": 0.0, "face_light": 0.15, "outline_tint": 0.8, "face_line": 0.5, "hair_band": 0.6}
const SOFT_OUTLINE_PX := 1.25  # grosor de la línea del estilo anime: el de la base aprobada en SH.1
const EXPORT_ZONES_SIZE := 256  # SH.5: el mapa de zonas va reducido dentro del .tres (1024² en texto: 14 MB; 256²: 0,9 MB)
const KEEP_ON_SWITCH := ["skin_color", "garment_color", "show_garment", "depth_pull", "skin_zones"]


static func apply(mesh: MeshInstance3D, piece := false, soft := soft_enabled) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = piece_shader(soft) if piece else body_shader(soft)
	var defaults := SOFT_DEFAULTS if soft else DEFAULTS
	for name: String in defaults:
		material.set_shader_parameter(name, defaults[name])
	if piece:
		material.set_shader_parameter("depth_pull", PIECE_PULL)
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	for name: String in OUTLINE_DEFAULTS:
		outline.set_shader_parameter(name, OUTLINE_DEFAULTS[name])
	for name: String in OUTLINE_SYNC:
		outline.set_shader_parameter(name, defaults.get(name))
	material.next_pass = outline
	material.set_meta("outline", outline)  # para devolver el contorno al salir de unlit
	mesh.material_override = material
	return material


## SH.4b: un parámetro en el material y, si lo lee también el contorno (OUTLINE_SYNC), en el contorno.
static func _set_both(mesh: MeshInstance3D, name: String, value: Variant) -> void:
	var material := mesh.material_override as ShaderMaterial
	material.set_shader_parameter(name, value)
	if name in OUTLINE_SYNC and material.has_meta("outline"):
		(material.get_meta("outline") as ShaderMaterial).set_shader_parameter(name, value)


## SH.7a: cambia el estilo de la malla (soft: anime, toon_soft; si no, clásico) sin perder colores, prenda, unlit,
## adelanto de pieza ni zonas de piel. El acabado vuelve al del estilo nuevo y, en el cuerpo anime, la piel a SKIN_START.
## piece: si la malla es una pieza (usa la copia con depth_pull). Si ya está en ese estilo, no cambia nada.
static func set_style(mesh: MeshInstance3D, soft: bool, piece := false) -> void:
	if is_soft(mesh) == soft and mesh.material_override != null:
		return
	if mesh.material_override == null:
		apply(mesh, piece, soft)
	# El mismo ShaderMaterial (y su contorno), con otro shader: quien guarde una referencia (StyleView) ve el cambio.
	var material := mesh.material_override as ShaderMaterial
	var kept := {}
	var unlit: bool = material.get_shader_parameter("unlit") == true
	for name: String in KEEP_ON_SWITCH:
		var value: Variant = material.get_shader_parameter(name)
		if value != null:
			kept[name] = value
	material.shader = piece_shader(soft) if piece else body_shader(soft)
	var defaults := SOFT_DEFAULTS if soft else DEFAULTS
	for name: String in defaults:
		material.set_shader_parameter(name, defaults[name])
	for name: String in kept:
		_set_both(mesh, name, kept[name])
	var finish := default_finish(soft)
	for name: String in finish:
		set_finish(mesh, name, finish[name])
	var outline := material.get_meta("outline") as ShaderMaterial
	for name: String in OUTLINE_SKIN:
		outline.set_shader_parameter(name, OUTLINE_DEFAULTS[name])
	if soft and not piece:
		for name: String in SKIN_START:
			set_skin(mesh, name, SKIN_START[name])
	set_unlit(mesh, unlit)


## SH.7a: true si la malla lleva el estilo anime (toon_soft, del cuerpo o de pieza).
static func is_soft(mesh: MeshInstance3D) -> bool:
	var material := mesh.material_override as ShaderMaterial
	return material != null and material.shader != null and (material.shader == SOFT_SHADER
		or material.shader == _soft_piece_shader)


## SH.7a: un valor de la piel anime (clave de SKIN), recortado a su rango; freckles, a entero. Rechaza la clave
## desconocida, NaN e infinito (devuelve false y no cambia nada).
static func set_skin(mesh: MeshInstance3D, name: String, value: float) -> bool:
	if not SKIN.has(name) or not is_finite(value):
		return false
	var clamped := clampf(value, SKIN[name][0], SKIN[name][1])
	var material := mesh.material_override as ShaderMaterial
	if name in OUTLINE_SKIN:
		material = material.get_meta("outline")
	material.set_shader_parameter(name, roundf(clamped) if name == "freckles" else clamped)
	return true


## SH.7a: {clave de SKIN: valor} de la malla; si no está en estilo anime, SKIN_START.
static func get_skin(mesh: MeshInstance3D) -> Dictionary:
	var skin := SKIN_START.duplicate()
	if is_soft(mesh):
		var material := mesh.material_override as ShaderMaterial
		for name: String in SKIN:
			var source: ShaderMaterial = material.get_meta("outline") if name in OUTLINE_SKIN else material
			var value: Variant = source.get_shader_parameter(name)
			skin[name] = value if value != null else SKIN_START[name]
	return skin


## Paso SH.8: el mapa de zonas de la piel (SpeciesData.skin_zones). Solo lo usa toon_soft; con null no hay zonas.
static func set_skin_zones(mesh: MeshInstance3D, zones: Texture2D) -> void:
	_set_both(mesh, "skin_zones", zones)


static func set_garment_visible(mesh: MeshInstance3D, visible: bool) -> void:
	_set_both(mesh, "show_garment", visible)


static func is_garment_visible(mesh: MeshInstance3D) -> bool:
	return _parameter(mesh, "show_garment")


## name: "skin_color" o "garment_color".
static func get_color(mesh: MeshInstance3D, name: String) -> Color:
	return _parameter(mesh, name)


## name: "skin_color" o "garment_color".
static func set_color(mesh: MeshInstance3D, name: String, color: Color) -> void:
	_set_both(mesh, name, color)


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
	if material == null or (material.shader != SHADER and material.shader != SOFT_SHADER) or not material.has_meta("outline"):
		return OUTLINE_DEFAULTS["width_px"]
	return (material.get_meta("outline") as ShaderMaterial).get_shader_parameter("width_px")


## Un valor del acabado (clave de FINISH), recortado a su rango. Rechaza la clave desconocida, NaN e infinito
## (devuelve false y no cambia nada).
static func set_finish(mesh: MeshInstance3D, name: String, value: float) -> bool:
	if not FINISH.has(name) or not is_finite(value):
		return false
	if name == "width_px":
		return set_outline_width(mesh, value)
	(mesh.material_override as ShaderMaterial).set_shader_parameter(name, clampf(value, FINISH[name][0], FINISH[name][1]))
	return true


## Los valores del acabado de la malla: {clave de FINISH: valor}.
static func get_finish(mesh: MeshInstance3D) -> Dictionary:
	var finish := {}
	for name: String in FINISH:
		finish[name] = get_outline_width(mesh) if name == "width_px" else _parameter(mesh, name)
	return finish


## El acabado por defecto del estilo (el de los shaders; soft: el del estilo anime, con SOFT_OUTLINE_PX).
static func default_finish(soft := false) -> Dictionary:
	var finish := {}
	for name: String in FINISH:
		if name == "width_px":
			finish[name] = SOFT_OUTLINE_PX if soft else OUTLINE_DEFAULTS[name]
		else:
			finish[name] = SOFT_DEFAULTS[name] if soft else DEFAULTS[name]
	return finish


## Copia para un juego sin el addon (el exportador la guarda como .tres): los dos shaders van incrustados, sin ruta,
## con los valores de la malla y con luces (sin `unlit`). Si la malla no tiene este material, valen los valores por defecto.
## SH.5: si la malla está en estilo anime, la copia es de toon_soft, con su piel y el mapa de zonas (se guarda dentro).
static func standalone(mesh: MeshInstance3D) -> ShaderMaterial:
	var soft := mesh.material_override != null and is_soft(mesh)
	var material := ShaderMaterial.new()
	material.shader = _embedded(SOFT_SHADER if soft else SHADER)
	for name: String in (SOFT_DEFAULTS if soft else DEFAULTS):
		material.set_shader_parameter(name, _parameter(mesh, name))
	if soft:
		material.set_shader_parameter("skin_zones", _small_zones((mesh.material_override as ShaderMaterial).get_shader_parameter("skin_zones")))
	material.set_shader_parameter("unlit", false)
	var outline := ShaderMaterial.new()
	outline.shader = _embedded(OUTLINE_SHADER)
	outline.set_shader_parameter("outline_color", OUTLINE_DEFAULTS["outline_color"])
	outline.set_shader_parameter("width_px", get_outline_width(mesh))
	for name: String in ["skin_color", "garment_color", "show_garment"]:
		outline.set_shader_parameter(name, material.get_shader_parameter(name))
	if soft:  # SH.4b: la línea teñida y la de la cara viajan en el .tres
		var source := (mesh.material_override as ShaderMaterial).get_meta("outline") as ShaderMaterial
		for name: String in OUTLINE_SKIN:
			outline.set_shader_parameter(name, source.get_shader_parameter(name))
		outline.set_shader_parameter("skin_zones", material.get_shader_parameter("skin_zones"))
	material.next_pass = outline
	material.set_meta("outline", outline)  # como apply(): set_unlit la necesita para devolver el contorno
	return material


## SH.5: copia de EXPORT_ZONES_SIZE² del mapa de zonas, con mipmaps (en caché: reducirla cuesta ~100 ms).
## Sin imagen (sin renderizador), la misma textura.
static var _small_cache := {}  # id de la textura → la copia reducida


static func _small_zones(zones: Texture2D) -> Texture2D:
	if zones != null and _small_cache.has(zones.get_instance_id()):
		return _small_cache[zones.get_instance_id()]
	var image: Image = zones.get_image() if zones != null else null
	if image == null:
		return zones
	image = image.duplicate()
	image.clear_mipmaps()
	image.resize(EXPORT_ZONES_SIZE, EXPORT_ZONES_SIZE, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var small := ImageTexture.create_from_image(image)
	_small_cache[zones.get_instance_id()] = small
	return small


static func _embedded(shader: Shader) -> Shader:
	var copy := Shader.new()
	copy.code = shader.code
	return copy


static func _parameter(mesh: MeshInstance3D, name: String) -> Variant:
	var material := mesh.material_override as ShaderMaterial
	var ours := material != null and (material.shader == SHADER or material.shader == _piece_shader
		or material.shader == SOFT_SHADER or material.shader == _soft_piece_shader)  # paso AB.6: piezas
	var value: Variant = material.get_shader_parameter(name) if ours else null
	if value != null:
		return value
	return SOFT_DEFAULTS[name] if (ours and is_soft(mesh) and SOFT_DEFAULTS.has(name)) or not DEFAULTS.has(name) else DEFAULTS[name]


## Paso AB.6: toon.gdshader con PULL_CODE antes de fragment() (se hace una vez). soft: la copia de toon_soft.
static func piece_shader(soft := soft_enabled) -> Shader:
	if soft:
		if _soft_piece_shader == null:
			_soft_piece_shader = Shader.new()
			_soft_piece_shader.code = SOFT_SHADER.code.replace("void fragment()", PULL_CODE + "void fragment()")
		return _soft_piece_shader
	if _piece_shader == null:
		_piece_shader = Shader.new()
		_piece_shader.code = SHADER.code.replace("void fragment()", PULL_CODE + "void fragment()")
	return _piece_shader


## SOFT_SHADER si soft; si no, SHADER.
static func body_shader(soft := soft_enabled) -> Shader:
	return SOFT_SHADER if soft else SHADER
