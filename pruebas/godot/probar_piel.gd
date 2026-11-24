extends SceneTree
# Pasos SH.3c y SH.3d de toon_soft. SH.3c, banda cálida en el borde entre luz y sombra (edge_strength): con 0 no cambia
# nada; encendida, solo cambia la franja del borde: más saturada y algo más roja, sin tocar la luz plena, la sombra plena
# ni los neutros. SH.3d, brillo suave de piel (gloss_strength, D49): aclara el color de la piel donde da la luz, nunca en la
# sombra, la prenda, unlit ni sin luz, y no depende del orden de las luces.
# SH.8, rubor y labios (blush_amount, lips_amount) y SH.8b, pecas (freckles 0–10) sobre las zonas de piel.png: colores
# hermanos de la piel; nada en la prenda, sin textura ni con 0; las pecas solo oscurecen, crecen con el nivel y no pasan
# de su alcance.
# Con ventana. En Forward+ además guarda las hojas (A = apagado, B = banda, C = banda y brillo: valores de COLUMNS).
# Uso: (ulimit -v 4000000; timeout 400 godot [--rendering-method mobile] --path pruebas/godot -s probar_piel.gd [-- --shader=<ruta>] 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')
# --shader=<ruta>: usa el código de ese archivo en lugar de toon_soft (para romper una copia, nunca el núcleo).
# Escribe en pruebas/capturas/shader_piel/: hoja_cuerpo.png y hoja_cara.png (las 4 filas de SH.2, una luz con sombra) y,
# para SH.3e, hoja_suavidad_cuerpo.png y hoja_suavidad_cara.png (columnas: softness de SOFTNESS_COLUMNS, con CHOSEN);
# para SH.8, hoja_rubor_cuerpo.png y hoja_rubor_cara.png (A = CHOSEN, B = con BLUSH) y hoja_pecas_cara.png (primer plano)
# y hoja_pecas_cuerpo.png (columnas: los niveles de FRECKLE_COLUMNS, con BLUSH).
# Que detecta el fallo (sobre una copia): `float band = 4.0 * lit * (1.0 - lit);` (sin edge_strength);
# EDGE_SATURATION = 1.0; `band` sin `* (1.0 - lit)` (la banda llena la luz); el brillo sin `* lit`; sin `* gloss_mask`;
# el brillo sumado después del max() (`DIFFUSE_LIGHT += full * sheen * reach;`); el rubor sin `* skin`;
# `float zone = 1.0;` en freckle_cover; FRECKLE_OPACITY = -0.6 (pecas claras).

const OUT_DIR := "pruebas/capturas/shader_piel"
const SPHERE_SIZE := 48
const CELL := Vector2i(420, 560)
const BACKGROUND := Color8(199, 202, 204)
const EDGE_YAW := 87.13  # grados: dot(NORMAL, LIGHT) = 0,05 = threshold en el centro de la esfera (lit = 0,5)
const COLUMNS := [{}, {"edge_strength": 0.6}, {"edge_strength": 0.6, "gloss_strength": 0.35}]  # PROVISIONAL: B y C los decide el responsable
const KEYS := ["edge_strength", "gloss_strength", "blush_amount", "lips_amount", "freckles"]  # solo en el cuerpo
const CHOSEN := {"edge_strength": 0.6, "gloss_strength": 0.35}  # elegidos por el responsable el 2026-11-23 (para SH.7)
const SOFTNESS_COLUMNS := [0.09, 0.14, 0.20]
const BLUSH := {"blush_amount": 0.35, "lips_amount": 0.45}  # PROVISIONAL: la propuesta de la hoja; lo decide el responsable
const FRECKLE_COLUMNS := [1.0, 3.0, 5.0, 10.0]
const SHOT_CLOSE := [15.0, 2.0, Vector3(0, 1.53, 0), 0.55]
const BIG := 384  # esfera grande para las pecas
const FRECKLE_MIN := 0.003  # PROVISIONAL: fracción mínima de píxeles con pecas cuando deben salir
const FRECKLE_MAX := 0.25  # PROVISIONAL: nada exagerado, ni con 10 en el centro de la cara
const ORDER_FAR := 0.2  # una zona a esta distancia normalizada: sin pecas hasta el nivel 5, con pecas desde el 8  # SH.3e: hoja_suavidad_*, con CHOSEN; softness va en todas las mallas
const GLOSS_TOLERANCE := 3  # /255 PROVISIONAL: con gloss_strength 1 y la luz de frente, centro = color · (1 + gloss_color) en lineal
const SAME := 1  # /255 PROVISIONAL: lo que no debe cambiar
const EDGE_SATURATION_MIN := 0.04  # PROVISIONAL: la banda sube la saturación al menos esto
const EDGE_VALUE_CHANGE := 0.06  # PROVISIONAL: y no cambia el valor (brillo) más que esto
const EDGE_HUE_MAX := 9.0  # grados PROVISIONAL: giro hacia el rojo de la banda (EDGE_HUE_DEGREES = 8; medido 5,5 a 6,5)
const SKINS := {"piel_clara": Color(0.96, 0.80, 0.70), "piel_media": Color(0.72, 0.50, 0.36),
	"piel_oscura": Color(0.30, 0.19, 0.14), "azul_fantasia": Color(0.35, 0.55, 0.85)}
const NEUTRALS := {"blanco": Color(1, 1, 1), "gris": Color(0.5, 0.5, 0.5)}
const ROWS := [
	{"preset": "anime", "skin": Color(0.96, 0.80, 0.70), "hair": ["makehuman", "toigo_blunt_bob_with_bangs"],
		"hair_color": Color(0.20, 0.55, 0.35), "clothes": Color(0.10, 0.10, 0.11)},
	{"preset": "femenino", "skin": Color(0.30, 0.19, 0.14), "hair": ["quaternius", "hair_long"],
		"hair_color": Color(0.30, 0.20, 0.15), "clothes": Color(0.28, 0.33, 0.45)},
	{"preset": "masculino", "skin": Color(0.72, 0.50, 0.36), "hair": ["makehuman", "short02"],
		"hair_color": Color(0.62, 0.46, 0.22), "clothes": Color(0.85, 0.85, 0.82)},
	{"preset": "anime", "skin": Color(0.35, 0.55, 0.85), "hair": ["makehuman", "short02"],
		"hair_color": Color(0.16, 0.20, 0.42), "clothes": Color(0.85, 0.85, 0.82)},
]
const CLOTHES := [["overscore", "os_tank_top"], ["overscore", "os_golf_shorts"]]
const SHOT_BODY := [25.0, 8.0, Vector3(0, 0.95, 0), 4.0]
const SHOT_FACE := [25.0, 4.0, Vector3(0, 1.55, 0), 1.25]

var repo: String
var out: String
var body_material
var preset
var view
var current: Shader
var current_piece: Shader
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	out = repo.path_join(OUT_DIR)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(120, 90)
	_run()


func _run() -> void:
	body_material = load(repo.path_join("godot/addons/creador/body_material.gd"))
	preset = load(repo.path_join("godot/addons/creador/preset.gd"))
	print("MEDIDA renderizador: ", RenderingServer.get_current_rendering_method())
	current = body_material.SOFT_SHADER
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shader="):
			current = Shader.new()
			current.code = FileAccess.get_file_as_string(argument.trim_prefix("--shader="))
	current_piece = Shader.new()
	current_piece.code = current.code.replace("void fragment()", body_material.PULL_CODE + "void fragment()")
	_check(body_material.SOFT_DEFAULTS["edge_strength"] == 0.0, "edge_strength apagado por defecto")
	await _check_edge()
	await _check_gloss()
	await _check_blush()
	await _check_freckles()
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		await _make_sheets()
	print("RESULTADO: TODO BIEN" if failures == 0 else "RESULTADO: %d FALLOS" % failures)
	quit(0 if failures == 0 else 1)


# --- Esfera ---

## El píxel central de una esfera nueva. lights: [[giro en Y, energía]] (0: de frente; 180: de espalda), creadas en ese
## orden; un número suelto es una luz de energía 1. blocked: una caja que solo proyecta sombra tapa el centro.
func _pixel(color: Color, lights: Variant, params := {}, blocked := false) -> Color:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SPHERE_SIZE, SPHERE_SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 4)
	camera.fov = 30.0
	viewport.add_child(camera)
	for data: Array in (lights if lights is Array else [[lights, 1.0]]):
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(0, data[0], 0)
		light.light_energy = data[1]
		light.shadow_enabled = blocked
		viewport.add_child(light)
	if blocked:
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		box.scale = Vector3(0.3, 0.3, 0.05)
		box.position = Vector3(0, 0, 1.5)
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		viewport.add_child(box)
	var sphere := MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	var material := ShaderMaterial.new()
	material.shader = current
	for name: String in body_material.SOFT_DEFAULTS:
		material.set_shader_parameter(name, body_material.SOFT_DEFAULTS[name])
	material.set_shader_parameter("skin_color", color)
	material.set_shader_parameter("show_garment", false)
	material.set_shader_parameter("ground_weight", 0.0)
	material.set_shader_parameter("rim_strength", 0.0)
	for name: String in params:
		material.set_shader_parameter(name, params[name])
	sphere.material_override = material
	viewport.add_child(sphere)
	for i in 4:
		await process_frame
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	await process_frame
	return image.get_pixel(SPHERE_SIZE / 2, SPHERE_SIZE / 2)


# --- SH.3c: banda cálida ---

func _check_edge() -> void:
	var on := {"edge_strength": 1.0}
	for name: String in SKINS:
		var color: Color = SKINS[name]
		var off_edge: Color = await _pixel(color, EDGE_YAW)
		var on_edge: Color = await _pixel(color, EDGE_YAW, on)
		var turn := _wrap(on_edge.h * 360.0 - off_edge.h * 360.0)
		var to_red := -turn if off_edge.h * 360.0 < 180.0 else turn
		print("MEDIDA %s banda: sin=%s con=%s (saturación %.3f → %.3f, valor %.3f → %.3f, giro hacia el rojo %.1f°)" % [
			name, _bytes(off_edge), _bytes(on_edge), off_edge.s, on_edge.s, off_edge.v, on_edge.v, to_red])
		_check(on_edge.s - off_edge.s >= EDGE_SATURATION_MIN, "%s: la banda satura el borde (+%.3f)" % [name, on_edge.s - off_edge.s])
		_check(absf(on_edge.v - off_edge.v) <= EDGE_VALUE_CHANGE, "%s: la banda no cambia el brillo (%.3f)" % [name, on_edge.v - off_edge.v])
		_check(to_red >= -0.5 and to_red <= EDGE_HUE_MAX, "%s: la banda gira hacia el rojo como mucho %.0f° (%.1f°)" % [name, EDGE_HUE_MAX, to_red])
		for yaw: float in [0.0, 180.0]:
			var off_full: Color = await _pixel(color, yaw)
			var on_full: Color = await _pixel(color, yaw, on)
			_check(_distance(off_full, on_full) <= SAME, "%s: la banda no toca la %s plena (%d/255)" % [
				name, "luz" if yaw == 0.0 else "sombra", _distance(off_full, on_full)])
	for name: String in NEUTRALS:
		var off_edge: Color = await _pixel(NEUTRALS[name], EDGE_YAW)
		var on_edge: Color = await _pixel(NEUTRALS[name], EDGE_YAW, on)
		_check(_distance(off_edge, on_edge) <= SAME, "%s: la banda no cambia los neutros (%d/255)" % [name, _distance(off_edge, on_edge)])


# --- SH.3d: brillo suave de piel ---

func _check_gloss() -> void:
	_check(body_material.SOFT_DEFAULTS["gloss_strength"] == 0.0, "gloss_strength apagado por defecto")
	var on := {"gloss_strength": 1.0}
	for name: String in SKINS:
		var color: Color = SKINS[name]
		var off_front: Color = await _pixel(color, 0.0)
		var on_front: Color = await _pixel(color, 0.0, on)
		var tint: Color = body_material.SOFT_DEFAULTS["gloss_color"]
		var expected: Color = (off_front.srgb_to_linear() * (Color(1, 1, 1) + tint.srgb_to_linear())).linear_to_srgb()
		expected = Color(minf(expected.r, 1.0), minf(expected.g, 1.0), minf(expected.b, 1.0))
		print("MEDIDA %s brillo: sin=%s con=%s esperado=%s" % [name, _bytes(off_front), _bytes(on_front), _bytes(expected)])
		_check(_distance(on_front, expected) <= GLOSS_TOLERANCE and _distance(on_front, off_front) > SAME,
			"%s: el brillo aclara el color de la piel ×(1 + gloss_color) donde da la luz (%d/255)" % [name, _distance(on_front, expected)])
		var off_back: Color = await _pixel(color, 180.0)
		var on_back: Color = await _pixel(color, 180.0, on)
		_check(_distance(off_back, on_back) <= SAME, "%s: sin brillo en la sombra (%d/255)" % [name, _distance(off_back, on_back)])
	var skin: Color = SKINS["piel_media"]
	var lit_center: Color = await _pixel(skin, 0.0)
	var off_blocked: Color = await _pixel(skin, 0.0, {}, true)
	var on_blocked: Color = await _pixel(skin, 0.0, on, true)
	print("MEDIDA sombra proyectada: con luz=%s tapado=%s tapado con brillo=%s" % [_bytes(lit_center), _bytes(off_blocked), _bytes(on_blocked)])
	_check(off_blocked.get_luminance() < lit_center.get_luminance() - 0.05, "la caja proyecta sombra sobre el centro")
	_check(_distance(off_blocked, on_blocked) <= SAME, "sin brillo en la sombra proyectada (%d/255)" % _distance(off_blocked, on_blocked))
	var garment := {"show_garment": true, "garment_color": skin}
	var off_garment: Color = await _pixel(skin, 0.0, garment)
	var on_garment: Color = await _pixel(skin, 0.0, {"show_garment": true, "garment_color": skin, "gloss_strength": 1.0})
	_check(_distance(off_garment, on_garment) <= SAME, "sin brillo en la prenda (%d/255)" % _distance(off_garment, on_garment))
	var exact: Color = await _pixel(skin, 0.0, {"unlit": true, "gloss_strength": 1.0})
	_check(_distance(exact, skin) <= SAME, "unlit con brillo: color exacto (%d/255)" % _distance(exact, skin))
	var dark: Color = await _pixel(skin, [], on)
	_check(maxi(maxi(dark.r8, dark.g8), dark.b8) <= SAME, "sin luz, sin brillo (%s)" % _bytes(dark))
	var main_first: Color = await _pixel(skin, [[0.0, 1.0], [180.0, 0.5]], on)
	var back_first: Color = await _pixel(skin, [[180.0, 0.5], [0.0, 1.0]], on)
	var weak_first: Color = await _pixel(skin, [[20.0, 0.4], [0.0, 1.0]], on)
	var strong_first: Color = await _pixel(skin, [[0.0, 1.0], [20.0, 0.4]], on)
	_check(_distance(main_first, back_first) <= SAME and _distance(weak_first, strong_first) <= SAME,
		"el brillo no depende del orden de las luces (%d y %d/255)" % [_distance(main_first, back_first), _distance(weak_first, strong_first)])


# --- SH.8: rubor, labios y pecas ---

## Textura de zonas constante (R rubor, G cercanía para las pecas, B labios).
func _zones(r: float, g: float, b: float) -> ImageTexture:
	var image := Image.create(4, 4, false, Image.FORMAT_RGB8)
	image.fill(Color(r, g, b))
	return ImageTexture.create_from_image(image)


func _check_blush() -> void:
	for key: String in ["blush_amount", "lips_amount", "freckles"]:
		_check(body_material.SOFT_DEFAULTS[key] == 0.0, key + " apagado por defecto")
	for name: String in SKINS:
		var color: Color = SKINS[name]
		var plain: Color = await _pixel(color, 0.0)
		var blush: Color = await _pixel(color, 0.0, {"skin_zones": _zones(1, 0, 0), "blush_amount": 1.0})
		var lips: Color = await _pixel(color, 0.0, {"skin_zones": _zones(0, 0, 1), "lips_amount": 1.0})
		print("MEDIDA %s: piel=%s rubor=%s labios=%s (sat. %.3f/%.3f/%.3f valor %.3f/%.3f/%.3f)" % [name, _bytes(plain), _bytes(blush),
			_bytes(lips), plain.s, blush.s, lips.s, plain.v, blush.v, lips.v])
		_check(blush.s > plain.s + 0.03 and blush.v > plain.v - 0.08 and blush.v <= plain.v + 0.004,
			"%s: el rubor satura y apenas oscurece" % name)
		_check(lips.s > plain.s + 0.03 and lips.v < plain.v - 0.03, "%s: los labios saturan y oscurecen" % name)
		var turn := _wrap(blush.h * 360.0 - plain.h * 360.0)
		_check((turn < 0.0) == (plain.h * 360.0 < 180.0) or absf(turn) < 0.5, "%s: el rubor gira hacia el rosa (%.1f°)" % [name, turn])
	for name: String in NEUTRALS:
		var plain: Color = await _pixel(NEUTRALS[name], 0.0)
		var all: Color = await _pixel(NEUTRALS[name], 0.0, {"skin_zones": _zones(1, 0, 1), "blush_amount": 1.0, "lips_amount": 1.0})
		var spread := maxi(maxi(all.r8, all.g8), all.b8) - mini(mini(all.r8, all.g8), all.b8)
		_check(spread <= 2, "%s: con rubor y labios sigue neutro, sin matiz (máx. - mín. = %d/255)" % [name, spread])
	var skin: Color = SKINS["piel_media"]
	var everything := {"skin_zones": _zones(1, 1, 1), "blush_amount": 1.0, "lips_amount": 1.0, "freckles": 10.0}
	var bare: Color = await _pixel(skin, 0.0, {"show_garment": true, "garment_color": skin})
	var dressed := everything.duplicate()
	dressed.merge({"show_garment": true, "garment_color": skin})
	var covered: Color = await _pixel(skin, 0.0, dressed)
	_check(_distance(bare, covered) <= SAME, "nada en la prenda (%d/255)" % _distance(bare, covered))
	var no_map := everything.duplicate()
	no_map.erase("skin_zones")
	var plain: Color = await _pixel(skin, 0.0)
	var without: Color = await _pixel(skin, 0.0, no_map)
	_check(_distance(plain, without) <= SAME, "sin textura de zonas no cambia nada (%d/255)" % _distance(plain, without))


## Fracción de píxeles de la esfera grande que las pecas cambian, y si alguno se aclara.
func _freckle_share(near: float, level: float) -> Array:
	var params := {"skin_zones": _zones(0, near, 0), "freckles": level}
	var off: Image = await _big({"skin_zones": _zones(0, near, 0)})
	var on: Image = await _big(params)
	var changed := 0
	var lighter := 0
	var inside := 0
	for y in BIG:
		for x in BIG:
			var a := off.get_pixel(x, y)
			if a.a == 0.0:
				continue
			inside += 1
			var b := on.get_pixel(x, y)
			changed += 1 if a.get_luminance() - b.get_luminance() > 4.0 / 255.0 else 0
			lighter += 1 if b.get_luminance() - a.get_luminance() > 2.0 / 255.0 else 0
	return [float(changed) / maxi(inside, 1), lighter]


func _check_freckles() -> void:
	var levels := {}
	for level: float in [0.0, 1.0, 5.0, 10.0]:
		levels[level] = await _freckle_share(1.0, level)
	print("MEDIDA pecas en el centro de la cara (nivel 0/1/5/10): %s" % [levels.values().map(func(v: Array) -> String: return "%.2f %%" % (v[0] * 100.0))])
	_check(levels[0.0][0] == 0.0, "nivel 0: sin pecas")
	_check(levels[1.0][0] >= FRECKLE_MIN, "nivel 1: alguna peca en la nariz y las mejillas (%.2f %%)" % (levels[1.0][0] * 100.0))
	_check(levels[1.0][0] < levels[5.0][0] and levels[5.0][0] < levels[10.0][0], "más nivel, más pecas también en el centro")
	_check(levels[10.0][0] <= FRECKLE_MAX, "nivel 10: nada exagerado (%.2f %% de la piel)" % (levels[10.0][0] * 100.0))
	var lighter: int = levels.values().reduce(func(total: int, v: Array) -> int: return total + v[1], 0)
	_check(lighter == 0, "las pecas solo oscurecen (%d píxeles más claros)" % lighter)
	var far := 1.0 - sqrt(ORDER_FAR)
	var below: Array = await _freckle_share(far, 5.0)
	var above: Array = await _freckle_share(far, 8.0)
	_check(below[0] == 0.0 and above[0] >= FRECKLE_MIN, "una zona lejana: sin pecas con 5, con pecas con 8 (%.2f / %.2f %%)" % [below[0] * 100.0, above[0] * 100.0])
	var never: Array = await _freckle_share(0.0, 10.0)
	_check(never[0] == 0.0, "zona prohibida (G = 0): sin pecas con 10")


## Una esfera que llena la imagen (BIG píxeles), con la luz de frente.
func _big(params: Dictionary) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(BIG, BIG)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 2.2)
	camera.fov = 30.0
	viewport.add_child(camera)
	viewport.add_child(DirectionalLight3D.new())
	var sphere := MeshInstance3D.new()
	sphere.mesh = SphereMesh.new()
	var material := ShaderMaterial.new()
	material.shader = current
	for name: String in body_material.SOFT_DEFAULTS:
		material.set_shader_parameter(name, body_material.SOFT_DEFAULTS[name])
	material.set_shader_parameter("skin_color", SKINS["piel_clara"])
	material.set_shader_parameter("show_garment", false)
	for name: String in params:
		material.set_shader_parameter(name, params[name])
	sphere.material_override = material
	viewport.add_child(sphere)
	for i in 4:
		await process_frame
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	await process_frame
	return image


func _wrap(degrees: float) -> float:
	return fposmod(degrees + 180.0, 360.0) - 180.0


func _bytes(color: Color) -> String:
	return "(%d,%d,%d)" % [color.r8, color.g8, color.b8]


func _distance(a: Color, b: Color) -> int:
	return maxi(maxi(absi(a.r8 - b.r8), absi(a.g8 - b.g8)), absi(a.b8 - b.b8))


# --- Hojas: una columna por cada entrada de COLUMNS ---

func _make_sheets() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	body_material.soft_enabled = true  # antes de crear BodyView
	view = load(repo.path_join("godot/app/body_view.gd")).new()
	view.size = CELL
	root.add_child(view)
	await _wait(5)
	view.stretch = false
	view.viewport.size = CELL
	view.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.camera.instant = true
	_set_shadow()
	var columns: Array[Dictionary] = []
	columns.append_array(COLUMNS)
	for softness: float in SOFTNESS_COLUMNS:
		var params := CHOSEN.duplicate()
		params["softness"] = softness
		columns.append(params)
	var blush := CHOSEN.duplicate()
	blush.merge(BLUSH)
	columns.append_array([CHOSEN, blush])
	for level: float in FRECKLE_COLUMNS:
		var params := blush.duplicate()
		params["freckles"] = level
		columns.append(params)
	var cells: Array[Image] = []
	var faces: Array[Image] = []
	var closes: Array[Image] = []
	for row: Dictionary in ROWS:
		if not await _dress(row):
			return
		for params: Dictionary in columns:
			_use(params)
			await _wait(4)
			cells.append(await _shot(SHOT_BODY))
			faces.append(await _shot(SHOT_FACE))
			closes.append(await _shot(SHOT_CLOSE) if params.has("freckles") else faces[-1])
	var first_blush := COLUMNS.size() + SOFTNESS_COLUMNS.size()
	var groups := {"hoja": [0, COLUMNS.size(), faces], "hoja_suavidad": [COLUMNS.size(), SOFTNESS_COLUMNS.size(), faces],
		"hoja_rubor": [first_blush, 2, faces], "hoja_pecas": [first_blush + 2, FRECKLE_COLUMNS.size(), closes]}
	for group: String in groups:
		var first: int = groups[group][0]
		var count: int = groups[group][1]
		for kind: Array in [["_cuerpo", cells], ["_cara", groups[group][2]]]:
			var picked: Array[Image] = []
			for r in ROWS.size():
				for c in count:
					picked.append(kind[1][r * columns.size() + first + c])
			var file: String = group + kind[0] + ".png"
			_save_sheet(picked, file, count)
			_check(FileAccess.file_exists(out.path_join(file)), "existe " + file)


func _dress(row: Dictionary) -> bool:
	var text := FileAccess.get_file_as_string(repo.path_join("godot/datos/humana/presets/%s.json" % row["preset"]))
	var loaded: Dictionary = preset.from_text(text, view.SPECIES, view.species.sliders)
	if loaded["error"]:
		return _check(false, "preset " + row["preset"] + ": " + str(loaded["error"]))
	preset.apply_look(view.species.mesh, loaded)
	view.set_values(loaded["valores"])
	body_material.set_color(view.species.mesh, "skin_color", row["skin"])
	body_material.set_color(view.species.mesh, "garment_color", row["clothes"])
	if not _put_piece(row["hair"], row["hair_color"]):
		return false
	for piece: Array in CLOTHES:
		if not _put_piece(piece, row["clothes"]):
			return false
	view.style.refresh()
	await _wait(10)
	return true


func _put_piece(piece: Array, color: Color) -> bool:
	var placed: bool = view.set_piece(piece[0], piece[1], true)
	if placed:
		view.set_piece_color(String(piece[0]).path_join(piece[1]), color)
	return placed or _check(false, "pieza %s/%s" % piece)


func _meshes() -> Array:
	var list: Array = [view.species.mesh]
	list.append_array(view.pieces.values())
	return list


## Valores de la base de SH.1 en todas las mallas (softness, el de la columna) y, solo en el cuerpo, los de KEYS.
func _use(params: Dictionary) -> void:
	for mesh: MeshInstance3D in _meshes():
		var material: ShaderMaterial = mesh.material_override
		var piece: bool = mesh != view.species.mesh
		material.shader = current_piece if piece else current
		for key: String in ["softness", "threshold", "ground_weight", "rim_strength", "rim_width", "shade_strength"]:
			material.set_shader_parameter(key, params.get(key, body_material.SOFT_DEFAULTS[key]) if key == "softness" else body_material.SOFT_DEFAULTS[key])
		for key: String in KEYS:
			material.set_shader_parameter(key, params.get(key, body_material.SOFT_DEFAULTS[key]) if not piece else body_material.SOFT_DEFAULTS[key])
		(material.get_meta("outline") as ShaderMaterial).set_shader_parameter("width_px", 1.25)


func _set_shadow() -> void:
	view.light.shadow_enabled = true
	view.light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	view.light.directional_shadow_max_distance = 6.0
	view.light.shadow_bias = 0.03
	view.light.shadow_normal_bias = 1.0


func _shot(shot: Array) -> Image:
	var camera = view.camera
	camera.yaw = shot[0]
	camera.pitch = shot[1]
	camera.zoom = 1.0
	camera.goal_target = shot[2]
	camera.target = shot[2]
	camera.goal_distance = shot[3]
	camera.fit_distance = shot[3]
	camera.distance = shot[3]
	camera.snap()
	await _wait(12)
	var image: Image = view.viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var cell := Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	cell.fill(BACKGROUND)
	cell.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return cell


func _save_sheet(cells: Array[Image], file: String, columns: int) -> void:
	var sheet := Image.create(CELL.x * columns, CELL.y * ROWS.size(), false, Image.FORMAT_RGBA8)
	for i in cells.size():
		sheet.blit_rect(cells[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % columns, i / columns) * CELL)
	sheet.save_png(out.path_join(file))


func _check(ok: bool, text: String) -> bool:
	print(("  bien  " if ok else "  FALLO ") + text)
	failures += 0 if ok else 1
	return ok


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame
