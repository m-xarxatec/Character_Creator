extends SceneTree
# Paso SH.8c: SkinPaint pinta el rubor, los labios y las pecas en la textura del .glb (estilo anime). Constantes iguales
# a las de toon_soft; con todo a 0 la piel es lisa; el rubor y los labios caen en sus zonas con el color de tint_of; las
# pecas solo oscurecen, crecen con el nivel y nunca salen donde G = 0. El .glb exportado en anime las lleva; el
# clásico sale como antes. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 600 godot --headless --path pruebas/godot -s probar_pintar_piel.gd 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')
# Que detecta el fallo (en una copia, con -- --paint=<ruta>): FRECKLE_OPACITY = -0.6; `_paint_blush` sin `* blush`;
# `var reach := 1.0` (el nivel 1 cubre todo).

const SIZE := 512  # para la prueba; el exportador usa 2048
const SKIN := Color(0.96, 0.80, 0.70)
const TOLERANCE := 2  # /255

var repo: String
var paint
var species
var zones: Image
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	paint = load(repo.path_join("godot/addons/creador/skin_paint.gd"))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--paint="):  # una copia rota (no cambia la exportación, que usa la del núcleo)
			paint = GDScript.new()
			paint.source_code = FileAccess.get_file_as_string(argument.trim_prefix("--paint="))
			paint.reload()
	species = load(repo.path_join("godot/addons/creador/species_data.gd")).new()
	species.load_folder(repo.path_join("godot/datos/humana"))
	zones = species.skin_zones.get_image()
	_check_constants()
	_check_paint()
	await _check_export()
	print("RESULTADO: TODO BIEN" if failures == 0 else "RESULTADO: %d FALLOS" % failures)
	quit(0 if failures == 0 else 1)


func _check_constants() -> void:
	var code := FileAccess.get_file_as_string(repo.path_join("godot/addons/creador/toon_soft.gdshader"))
	var same: bool = code.contains("const float FRECKLE_CELLS = %.1f;" % paint.FRECKLE_CELLS) \
		and code.contains("const float FRECKLE_FIRST = %s;" % str(paint.FRECKLE_FIRST)) \
		and code.contains("const float FRECKLE_OPACITY = %s;" % str(paint.FRECKLE_OPACITY))
	for tint: Array in [paint.BLUSH, paint.LIPS, paint.FRECKLE]:
		same = same and code.contains("tint_of(color, %s, %.1f, %s, %s)" % [str(tint[0]), tint[1], str(tint[2]), str(tint[3])])
	_check(same, "las constantes y los tint_of son los de toon_soft")


## El píxel de piel.png con más valor en el canal, en coordenadas UV (centro del píxel).
func _peak(channel: int) -> Vector2:
	var best := -1.0
	var at := Vector2.ZERO
	for y in range(0, zones.get_height(), 2):
		for x in range(0, zones.get_width(), 2):
			var value: float = zones.get_pixel(x, y)[channel]
			if value > best:
				best = value
				at = Vector2(x + 0.5, y + 0.5) / zones.get_width()
	return at


func _at(image: Image, uv: Vector2) -> Color:
	return image.get_pixelv(Vector2i(uv * image.get_width()))


func _check_paint() -> void:
	var plain: Image = paint.skin_image(SIZE, SKIN, zones, {})
	var stats := plain.get_used_rect()
	_check(_distance(plain.get_pixel(10, 10), SKIN) <= 1 and _distance(_at(plain, _peak(0)), SKIN) <= 1 and stats.size.x == SIZE,
		"todo a 0: piel lisa")
	var start := Time.get_ticks_msec()
	var blush: Image = paint.skin_image(SIZE, SKIN, zones, {"blush_amount": 1.0})
	print("MEDIDA rubor %d px: %d ms" % [SIZE, Time.get_ticks_msec() - start])
	var cheek := _peak(0)
	var peak_r: float = zones.get_pixelv(Vector2i(cheek * zones.get_width())).r
	var expected: Color = SKIN.srgb_to_linear().lerp(paint.tint_of(SKIN.srgb_to_linear(), paint.BLUSH), peak_r).linear_to_srgb()
	print("MEDIDA mejilla: piel %s, con rubor %s, esperado %s" % [_bytes(SKIN), _bytes(_at(blush, cheek)), _bytes(expected)])
	_check(_distance(_at(blush, cheek), expected) <= TOLERANCE, "rubor: en la mejilla, el color de tint_of")
	var half: Image = paint.skin_image(SIZE, SKIN, zones, {"blush_amount": 0.5})
	var expected_half: Color = SKIN.srgb_to_linear().lerp(paint.tint_of(SKIN.srgb_to_linear(), paint.BLUSH), peak_r * 0.5).linear_to_srgb()
	_check(_distance(_at(half, cheek), expected_half) <= TOLERANCE, "rubor 0,5: la mitad de camino", _bytes(_at(half, cheek)))
	var lips: Image = paint.skin_image(SIZE, SKIN, zones, {"lips_amount": 1.0})
	var mouth := _peak(2)
	_check(_at(lips, mouth).v < SKIN.v - 0.05 and _at(lips, mouth).s > SKIN.s, "labios: más oscuros y saturados en la boca")
	var counts := {}
	for level: float in [0.0, 1.0, 5.0, 10.0]:
		start = Time.get_ticks_msec()
		var image: Image = paint.skin_image(SIZE, SKIN, zones, {"freckles": level})
		var ms := Time.get_ticks_msec() - start
		var changed := 0
		var lighter := 0
		var forbidden := 0
		var outside := 0  # nivel 1: pecas más allá de su alcance (cercanía G < 1 - sqrt(FRECKLE_FIRST))
		for y in SIZE:
			for x in SIZE:
				var p := image.get_pixel(x, y)
				if _distance(p, SKIN) > 1:
					changed += 1
					lighter += 1 if p.get_luminance() > SKIN.get_luminance() else 0
					var zone_x := int(float(x) / SIZE * zones.get_width())
					var zone_y := int(float(y) / SIZE * zones.get_height())
					var near: float = zones.get_pixel(zone_x, zone_y).g
					forbidden += 1 if near == 0.0 else 0
					outside += 1 if near < 1.0 - sqrt(paint.FRECKLE_FIRST) - 0.05 else 0
		counts[level] = changed
		print("MEDIDA pecas nivel %d: %d píxeles (%d ms); más claros %d; donde G = 0: %d" % [level, changed, ms, lighter, forbidden])
		_check(lighter == 0, "pecas nivel %d: solo oscurecen" % level)
		_check(forbidden <= changed / 50, "pecas nivel %d: casi nada donde G = 0 (%d, borde de píxel)" % [level, forbidden])
		if level == 1.0:
			_check(outside <= changed / 20, "pecas nivel 1: solo en la nariz y las mejillas (%d fuera)" % outside)
	_check(counts[0.0] == 0 and counts[1.0] > 0 and counts[1.0] < counts[5.0] and counts[5.0] < counts[10.0],
		"pecas: 0 nada; más nivel, más pecas")


## El .glb exportado en estilo anime lleva el rubor en su textura; en clásico, la piel lisa de siempre.
func _check_export() -> void:
	var main: Control = load(repo.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var view = main.body_view
	var material = load(repo.path_join("godot/addons/creador/body_material.gd"))
	material.set_color(view.species.mesh, "skin_color", SKIN)
	material.set_garment_visible(view.species.mesh, false)
	view.set_anime_style(false)
	var classic: Image = _exported_texture(view, "user://pintar_clasico.glb")
	view.set_anime_style(true)
	material.set_skin(view.species.mesh, "blush_amount", 1.0)
	material.set_skin(view.species.mesh, "freckles", 5)
	var start := Time.get_ticks_msec()
	var anime: Image = _exported_texture(view, "user://pintar_anime.glb")
	print("MEDIDA exportar en anime (con la piel pintada a 2048 px): %d ms" % (Time.get_ticks_msec() - start))
	var cheek := _peak(0)
	_check(classic == null or _distance(_at(classic, cheek), SKIN) <= 1, "clásico: el .glb sin rubor (como antes)")
	_check(anime != null and _at(anime, cheek).s > SKIN.s + 0.05, "anime: el .glb lleva el rubor en la mejilla",
		_bytes(_at(anime, cheek)) if anime != null else "sin textura")
	main.free()


func _exported_texture(view, path: String) -> Image:
	var error: Error = view.export_glb(path)
	if error != OK:
		_check(false, "exportar %s (error %d)" % [path, error])
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		return null
	for material: Material in state.get_materials():
		if material is StandardMaterial3D and material.resource_name == "cuerpo" and material.albedo_texture != null:
			var image: Image = material.albedo_texture.get_image()
			image.convert(Image.FORMAT_RGB8)
			return image
	return null


func _bytes(color: Color) -> String:
	return "(%d,%d,%d)" % [color.r8, color.g8, color.b8]


func _distance(a: Color, b: Color) -> int:
	return maxi(maxi(absi(a.r8 - b.r8), absi(a.g8 - b.g8)), absi(a.b8 - b.b8))


func _check(ok: bool, text: String, detail := "") -> bool:
	print(("  bien  " if ok else "  FALLO ") + text + (" " + detail if detail != "" else ""))
	failures += 0 if ok else 1
	return ok
