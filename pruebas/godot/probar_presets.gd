extends SceneTree
# Paso 3.7: presets en JSON (preset.gd). Paso 4.7: versión 2, con el acabado. SH.7a: versión 3, con estilo y piel. Sin ventana.
# Paso PL.2: su miniatura (presets/<id>.png). Paso PL.1b: plantillas de serie (TEMPLATES): completas, con la cara y el aspecto de anime.json, y en la ventana sin
# errores del informe en pose T y en «Atacar»; sus proporciones (godot/app/measures.gd) en los rangos de GUIA_ESTILO.md §2.
# Uso: godot --headless --path pruebas/godot -s probar_presets.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR'

const MAX_ROUNDING := 0.0000501  # 4 decimales: el error de redondeo es de 0,00005 como mucho
const STYLE_PRESETS := ["anime_femenino", "anime_masculino", "chibi_oscuro", "chibi_fuera_de_rango"]
const TEMPLATES := ["femenino", "masculino"]  # pasos PL.1b y PL.10; el neutro es anime.json
const FACE := ["cuenca_plana", "boca_anime", "mandibula_anime", "menton_anime", "nariz_anime", "alisado"]
## Rangos de diseno/GUIA_ESTILO.md §2 (aprobados el 2026-11-20 con lo medido; el ± es PROVISIONAL).
const STYLE_RANGES := {
	"femenino": {"heads": [7.01, 7.31], "legs": [0.47, 0.53], "shoulders": [1.68, 1.78], "waist": [0.51, 0.57],
		"hand": [0.57, 0.63], "foot": [0.71, 0.77]},
	"masculino": {"heads": [6.97, 7.27], "legs": [0.49, 0.55], "shoulders": [1.90, 2.00], "waist": [0.46, 0.52],
		"hand": [0.70, 0.76], "foot": [0.90, 0.96]}}

var failures := 0
var preset: GDScript
var material: GDScript
var species
var root_dir: String


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	preset = load(addon.path_join("preset.gd"))
	material = load(addon.path_join("body_material.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	_check_round_trip()
	_check_text()
	_check_look()
	_check_finish()
	_check_style()
	_check_brow()
	_check_values()
	_check_errors()
	_check_style_presets()
	_check_new_character()
	_check_templates()
	_check_thumbnails()
	species.scene.free()
	await _check_templates_in_window()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _neutral() -> Dictionary:
	var values: Dictionary = load(root_dir.path_join("godot/addons/creador/shape_weights.gd")).neutral_values(species.sliders)
	values.merge(load(root_dir.path_join("godot/addons/creador/proportions.gd")).neutral_values(species.sliders))
	return values


func _valid_dict() -> Dictionary:
	return preset.to_dict("Prueba", "humana", _neutral(), {"skin_color": Color(0.9, 0.8, 0.7), "garment_color": Color(0.1, 0.2, 0.3)}, true)


func _load(data: Dictionary) -> Dictionary:
	return preset.from_dict(data, "humana", species.sliders)


func _random_values(rng: RandomNumberGenerator) -> Dictionary:
	var values := _neutral()
	for key: String in values:
		values[key] = rng.randf()
	return values


func _check_round_trip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	var worst_value := 0.0
	var worst_color := 0.0
	var all_ok := true
	for i in 20:
		var values := _random_values(rng)
		var colors := {"skin_color": Color(rng.randf(), rng.randf(), rng.randf()), "garment_color": Color(rng.randf(), rng.randf(), rng.randf())}
		var garment := rng.randf() < 0.5
		var loaded: Dictionary = preset.from_text(preset.to_text(preset.to_dict("Azar %d" % i, "humana", values, colors, garment)), "humana", species.sliders)
		if loaded["error"] != "" or loaded["nombre"] != "Azar %d" % i or loaded["prenda_visible"] != garment \
				or loaded["valores"].size() != values.size() or not loaded["desconocidas"].is_empty():
			all_ok = false
			continue
		for key: String in values:
			worst_value = maxf(worst_value, absf(loaded["valores"][key] - values[key]))
		for color_name: String in colors:
			var a: Color = loaded["colores"][color_name]
			var b: Color = colors[color_name]
			worst_color = maxf(worst_color, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
	check("ida y vuelta (20 al azar): nombre, prenda y número de valores", all_ok)
	check("valores máx. %.6f (límite 0,00005 por el redondeo)" % worst_value, worst_value < MAX_ROUNDING)
	check("colores máx. %.6f (límite 0,00005)" % worst_color, worst_color < MAX_ROUNDING)


func _check_text() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var values := _random_values(rng)
	var colors := {"skin_color": Color(0.9, 0.8, 0.7), "garment_color": Color(0.1, 0.2, 0.3)}
	var text: String = preset.to_text(preset.to_dict("Orden", "humana", values, colors, true))
	check("guardar dos veces da el mismo texto", text == preset.to_text(preset.to_dict("Orden", "humana", values, colors, true)))
	var reversed := {}
	var keys := values.keys()
	keys.reverse()
	for key: String in keys:
		reversed[key] = values[key]
	check("el orden en que se meten las claves no cambia el texto", text == preset.to_text(preset.to_dict("Orden", "humana", reversed, colors, true)))
	var loaded: Dictionary = preset.from_text(text, "humana", species.sliders)
	var again: String = preset.to_text(preset.to_dict(loaded["nombre"], "humana", loaded["valores"], loaded["colores"], loaded["prenda_visible"]))
	check("cargar y volver a guardar da el mismo texto", again == text)
	check("el texto es legible: 'version' al final, una clave por línea", text.count("\n") > values.size() and text.contains("\"version\": 3"))


func _check_look() -> void:
	material.apply(species.mesh)
	var loaded := {"colores": {"skin_color": Color(0.5, 0.25, 0.125), "garment_color": Color(0.75, 0.5, 0.25)}, "prenda_visible": false}
	preset.apply_look(species.mesh, loaded)
	check("apply_look: colores", material.get_color(species.mesh, "skin_color").is_equal_approx(loaded["colores"]["skin_color"])
		and material.get_color(species.mesh, "garment_color").is_equal_approx(loaded["colores"]["garment_color"]))
	check("apply_look: prenda oculta", not material.is_garment_visible(species.mesh))
	loaded["prenda_visible"] = true
	preset.apply_look(species.mesh, loaded)
	check("apply_look: prenda visible", material.is_garment_visible(species.mesh))


## Paso 4.7: el acabado viaja en el preset (versión 2) y la versión 1 se sigue leyendo.
func _check_finish() -> void:
	var defaults: Dictionary = material.default_finish()
	check("sin acabado, to_dict guarda el de por defecto", _valid_dict()["acabado"] == defaults, str(_valid_dict()["acabado"]))
	var finish := {"softness": 0.1234, "rim_strength": 0.6, "rim_width": 0.7, "width_px": 4.5}
	var colors := {"skin_color": Color(0.9, 0.8, 0.7), "garment_color": Color(0.1, 0.2, 0.3)}
	var text: String = preset.to_text(preset.to_dict("Acabado", "humana", _neutral(), colors, true, finish))
	var loaded: Dictionary = preset.from_text(text, "humana", species.sliders)
	check("acabado: ida y vuelta", loaded["error"] == "" and loaded["acabado"] == finish, str(loaded.get("acabado")))
	material.apply(species.mesh)
	preset.apply_look(species.mesh, loaded)
	check("apply_look: pone el acabado en el material", material.get_finish(species.mesh) == finish, str(material.get_finish(species.mesh)))
	loaded = _load(_with("acabado", {"rim_width": 7, "width_px": -2}))
	var expected := defaults.duplicate()
	expected["rim_width"] = 1.0
	expected["width_px"] = 0.0
	check("acabado: lo que falta toma el valor por defecto y lo de fuera de rango se recorta", loaded["acabado"] == expected, str(loaded.get("acabado")))
	var old := _without("acabado")
	old.erase("estilo")
	old.erase("piel")
	old["version"] = 1
	loaded = _load(old)
	check("versión 1 (sin acabado): carga con el acabado por defecto", loaded["error"] == "" and loaded["acabado"] == defaults, loaded["error"])
	check("y el preset de la versión 1 no cambia al cargarlo", old["version"] == 1 and not old.has("acabado"))
	_expect_error("versión 1 con acabado", _with("version", 1), "versión")
	_expect_error("acabado que no es objeto", _with("acabado", [0.5]), "tipo de campo")
	_expect_error("acabado desconocido", _with("acabado", {"brillo": 0.5}), "acabado desconocido")
	_expect_error("acabado con texto", _with("acabado", {"softness": "duro"}), "'softness'")
	_expect_error("acabado NaN", _with("acabado", {"rim_width": NAN}), "'rim_width'")


## SH.7a: estilo y piel viajan en el preset (versión 3); la 2 se lee con estilo clásico.
func _check_style() -> void:
	var colors := {"skin_color": Color(0.9, 0.8, 0.7), "garment_color": Color(0.1, 0.2, 0.3)}
	var plain := _valid_dict()
	check("sin estilo ni piel, to_dict guarda estilo clásico y la piel de partida",
		plain["estilo"] == "clasico" and _same(plain["piel"], material.SKIN_START), str([plain["estilo"], plain["piel"]]))
	var skin: Dictionary = material.SKIN_START.duplicate()
	skin.merge({"edge_strength": 0.25, "gloss_strength": 0.5, "blush_amount": 0.75, "lips_amount": 0.125, "freckles": 3.0,
		"face_light": 0.25, "outline_tint": 0.5}, true)
	var finish := {"softness": 0.14, "rim_strength": 0.1, "rim_width": 0.3, "width_px": 1.25}
	var text: String = preset.to_text(preset.to_dict("Anime", "humana", _neutral(), colors, true, finish, "anime", skin))
	var loaded: Dictionary = preset.from_text(text, "humana", species.sliders)
	check("estilo y piel: ida y vuelta", loaded["error"] == "" and loaded["estilo"] == "anime" and _same(loaded["piel"], skin),
		str([loaded.get("error"), loaded.get("piel")]))
	material.apply(species.mesh)
	preset.apply_look(species.mesh, loaded)
	check("apply_look anime: el cuerpo pasa al estilo anime con su piel y su acabado", material.is_soft(species.mesh)
		and _same(material.get_skin(species.mesh), skin) and material.get_finish(species.mesh) == finish, str(material.get_skin(species.mesh)))
	check("apply_look anime: conserva los colores", material.get_color(species.mesh, "skin_color").is_equal_approx(colors["skin_color"]))
	var classic: Dictionary = _load(_valid_dict())
	preset.apply_look(species.mesh, classic)
	check("apply_look clásico: vuelve al estilo clásico", not material.is_soft(species.mesh))
	var anime_only := _with("estilo", "anime")
	anime_only["acabado"] = {}
	anime_only["piel"] = {"freckles": 12, "blush_amount": -1}
	loaded = _load(anime_only)
	var expected: Dictionary = material.SKIN_START.duplicate()
	expected["freckles"] = 10.0
	expected["blush_amount"] = 0.0
	check("piel: lo que falta toma la de partida y lo de fuera de rango se recorta", _same(loaded["piel"], expected), str(loaded.get("piel")))
	check("estilo anime sin acabado: el acabado por defecto del estilo anime", loaded["acabado"] == material.default_finish(true),
		str(loaded.get("acabado")))
	var old := _without("estilo")
	old.erase("piel")
	old["version"] = 2
	loaded = _load(old)
	check("versión 2: carga con estilo clásico y la piel de partida", loaded["error"] == "" and loaded["estilo"] == "clasico"
		and _same(loaded["piel"], material.SKIN_START), loaded["error"])
	check("y el preset de la versión 2 no cambia al cargarlo", old["version"] == 2 and not old.has("estilo"))
	_expect_error("versión 2 con estilo", _with("version", 2), "versión")
	_expect_error("estilo desconocido", _with("estilo", "acuarela"), "estilo")
	_expect_error("estilo que no es texto", _with("estilo", 1), "estilo")
	_expect_error("piel que no es objeto", _with("piel", [0.5]), "tipo de campo")
	_expect_error("piel desconocida", _with("piel", {"bronceado": 0.5}), "piel desconocida")
	_expect_error("piel NaN", _with("piel", {"freckles": NAN}), "'freckles'")


## Mismas claves y valores iguales hasta el redondeo del formato (4 decimales).
## AC.6c.4a: los presets de serie no se tocan (sus sha256); al guardarlos de nuevo llevan además las claves de la ceja.
func _without_brow(data: Dictionary) -> Dictionary:
	data["colores"].erase("brow_color")
	for key: String in material.BROW_SKIN:
		data["piel"].erase(key)
	return data


## AC.6c.4a: Altura, Grosor, Tamaño y Color de la ceja viajan en el preset; un archivo sin ellos se abre con los de serie.
func _check_brow() -> void:
	var colors := {"skin_color": Color(0.9, 0.8, 0.7), "garment_color": Color(0.1, 0.2, 0.3), "brow_color": Color(0.5, 0.25, 0.75)}
	var skin: Dictionary = material.SKIN_START.duplicate()
	skin["brow_lift"] = -0.002
	skin["brow_thickness"] = 3.0
	skin["brow_size"] = 1.25
	var text: String = preset.to_text(preset.to_dict("Cejas", "humana", _neutral(), colors, true, {}, "anime", skin))
	var loaded: Dictionary = preset.from_text(text, "humana", species.sliders)
	check("ceja: ida y vuelta de los 3 valores y el color", loaded["error"] == "" and _same(loaded["piel"], skin)
		and loaded["colores"]["brow_color"].is_equal_approx(colors["brow_color"]), str(loaded.get("error")))
	var plain: Dictionary = preset.to_dict("Sin ceja", "humana", _neutral(), {"skin_color": Color.WHITE, "garment_color": Color.BLACK}, true)
	var serie: Color = material.EXTRA_COLORS["brow_color"]
	check("ceja: sin color, to_dict escribe el de serie", _same_rgb(plain["colores"]["brow_color"], serie))
	var old := _valid_dict()
	old["colores"].erase("brow_color")
	for key: String in material.BROW_SKIN:
		old["piel"].erase(key)
	loaded = _load(old)
	check("ceja: un archivo de antes (sin ella) se abre con los valores de serie", loaded["error"] == ""
		and loaded["colores"]["brow_color"].is_equal_approx(serie) and material.BROW_SKIN.all(
		func(key: String) -> bool: return loaded["piel"][key] == material.SKIN_START[key]), str(loaded.get("error")))
	var wild: Dictionary = material.SKIN_START.duplicate()
	wild["brow_thickness"] = 9.0
	wild["brow_lift"] = -1.0
	loaded = preset.from_text(preset.to_text(preset.to_dict("Fuera", "humana", _neutral(), colors, true, {}, "anime", wild)),
		"humana", species.sliders)
	check("ceja: fuera de rango se recorta", loaded["error"] == "" and loaded["piel"]["brow_thickness"] == 4.0
		and is_equal_approx(loaded["piel"]["brow_lift"], -0.003), str(loaded.get("piel")))
	var bad := _valid_dict()
	bad["colores"]["brow_color"] = [0.5, 2.0, 0.5]
	_expect_error("color de ceja fuera de [0, 1]", bad, "fuera de [0, 1]")


func _same_rgb(rgb: Array, color: Color) -> bool:
	return absf(rgb[0] - color.r) < MAX_ROUNDING and absf(rgb[1] - color.g) < MAX_ROUNDING and absf(rgb[2] - color.b) < MAX_ROUNDING


func _same(a: Dictionary, b: Dictionary) -> bool:
	return a.size() == b.size() and a.keys().all(func(key: String) -> bool: return b.has(key) and absf(a[key] - b[key]) < MAX_ROUNDING)


func _check_values() -> void:
	var data := _valid_dict()
	data["valores"] = {"gender": 0.9, "hand_size_l": 1.7, "hand_size_r": -3, "forma_futura": 0.5, "hand_size": 0.8}
	var loaded := _load(data)
	check("sin error con valores a medias", loaded["error"] == "", loaded["error"])
	check("lo que falta toma el valor neutro", loaded["valores"]["muscle"] == 0.5 and loaded["valores"]["height"] == 0.5)
	check("fuera de [0, 1] se recorta (1,7 → 1; −3 → 0)", loaded["valores"]["hand_size_l"] == 1.0 and loaded["valores"]["hand_size_r"] == 0.0)
	check("clave desconocida: ignorada y listada", "forma_futura" in loaded["desconocidas"] and not loaded["valores"].has("forma_futura"))
	check("sin comodidades: 'hand_size' sin lado es desconocida y no toca ningún lado",
		"hand_size" in loaded["desconocidas"] and loaded["valores"]["hand_size_l"] == 1.0 and loaded["valores"]["hand_size_r"] == 0.0)
	check("los dos lados se cargan por separado", loaded["valores"]["hand_size_l"] != loaded["valores"]["hand_size_r"])
	check("tantos valores como deslizadores Forma y Proporción", loaded["valores"].size() == _neutral().size(), str(loaded["valores"].size()))
	_check_face_missing(loaded["valores"])


## Paso 3.14: un preset sin las claves de cara deja las 5 formas de cara en 0 (cara de MakeHuman).
func _check_face_missing(values: Dictionary) -> void:
	var shapes: GDScript = load(root_dir.path_join("godot/addons/creador/shape_weights.gd"))
	var neutrals: Dictionary = shapes.neutral_values(species.sliders)
	var names: PackedStringArray = shapes.shape_names(species.mesh.mesh)
	var shape_values := {}  # solo los Forma, como hace CharacterUpdater
	for key: String in neutrals:
		shape_values[key] = values[key]
	values = shape_values
	var weights: Dictionary = shapes.weights(values, names, neutrals)
	var face := ["cuenca_plana", "boca_anime", "mandibula_anime", "menton_anime", "nariz_anime"]
	var in_mesh := face.all(func(n: String) -> bool: return n in names)
	var zero := face.all(func(n: String) -> bool: return values[n] == 0.0 and weights[n] == 0.0)
	check("preset sin claves de cara: las 5 formas de cara existen y quedan en 0", in_mesh and zero)
	values["cuenca_plana"] = 1.0
	check("cuenca_plana a 1 → su forma a 1", shapes.weights(values, names, neutrals)["cuenca_plana"] == 1.0)


func _expect_error(label: String, data: Variant, contains: String) -> void:
	var loaded: Dictionary = preset.from_text(data, "humana", species.sliders) if data is String else _load(data)
	check("error: " + label, loaded.has("error") and loaded["error"].contains(contains) and loaded.size() == 1, str(loaded.get("error", "")))


func _with(field: String, value: Variant) -> Dictionary:
	var data := _valid_dict()
	data[field] = value
	return data


func _without(field: String) -> Dictionary:
	var data := _valid_dict()
	data.erase(field)
	return data


func _check_errors() -> void:
	_expect_error("versión 4", _with("version", 4), "versión")
	_expect_error("versión que no es número", _with("version", "1"), "versión")
	_expect_error("otra especie", _with("especie", "elfa"), "especie")
	for field: String in preset.FIELDS:
		_expect_error("falta '%s'" % field, _without(field), "falta el campo")
	_expect_error("campo desconocido", _with("autor", "yo"), "campo desconocido")
	_expect_error("nombre que no es texto", _with("nombre", 3), "tipo de campo")
	_expect_error("prenda_visible que no es booleano", _with("prenda_visible", 1), "tipo de campo")
	_expect_error("valores que no es objeto", _with("valores", [0.5]), "tipo de campo")
	_expect_error("valor que es texto", _with("valores", {"gender": "alto"}), "'gender'")
	_expect_error("valor nulo", _with("valores", {"gender": null}), "'gender'")
	_expect_error("valor NaN", _with("valores", {"gender": NAN}), "'gender'")
	_expect_error("valor infinito", _with("valores", {"gender": INF}), "'gender'")
	var colors: Dictionary = _valid_dict()["colores"]
	_expect_error("falta un color", _with("colores", {"skin_color": colors["skin_color"]}), "falta el color")
	_expect_error("color con 2 canales", _with("colores", {"skin_color": [0.5, 0.5], "garment_color": colors["garment_color"]}), "no es [r, g, b]")
	_expect_error("color fuera de [0, 1]", _with("colores", {"skin_color": [0.5, 1.5, 0.5], "garment_color": colors["garment_color"]}), "fuera de [0, 1]")
	_expect_error("color con texto", _with("colores", {"skin_color": ["a", "b", "c"], "garment_color": colors["garment_color"]}), "fuera de [0, 1]")
	var extra: Dictionary = colors.duplicate()
	extra["pelo"] = [0.1, 0.1, 0.1]
	_expect_error("color desconocido", _with("colores", extra), "color desconocido")
	_expect_error("JSON roto", "{\"version\": ", "JSON no válido")
	_expect_error("JSON que no es objeto", "[1, 2]", "no es un objeto")


func _check_style_presets() -> void:
	for preset_name: String in STYLE_PRESETS:
		var text := FileAccess.get_file_as_string(root_dir.path_join("pruebas/fase_3/estilo/%s.json" % preset_name))
		var data: Dictionary = JSON.parse_string(text)
		if preset_name == "chibi_fuera_de_rango":
			# Su escala fuera de rango la lee solo probar_estilo.gd: el formato del preset no la admite.
			_expect_error("%s trae un campo que el formato no admite" % preset_name, text, "escalas_fuera_de_rango")
			data.erase("escalas_fuera_de_rango")
		var loaded := _load(data)
		var changed := 0
		for key: String in data["valores"]:
			changed += 1 if loaded["valores"].get(key, 0.5) != 0.5 else 0
		check("%s carga sin claves desconocidas; %d valores distintos del neutro" % [preset_name, changed],
			loaded["error"] == "" and loaded["desconocidas"].is_empty() and changed > 8, loaded["error"])
		check("%s: los dos lados de cada deslizador de dos lados están escritos" % preset_name, _both_sides(data["valores"]))


## Paso 3.15: presets/anime.json, el preset de personaje nuevo: completo, cuerpo neutro, cara anime y piel gris.
func _check_new_character() -> void:
	var text: String = species.preset_text()
	var loaded: Dictionary = preset.from_text(text, "humana", species.sliders)
	check("anime.json carga sin error ni claves desconocidas", loaded.get("error") == "" and loaded["desconocidas"].is_empty(),
		str(loaded.get("error")))
	if loaded.get("error") != "":
		return
	var expected := _neutral()
	for key in ["cuenca_plana", "boca_anime", "mandibula_anime", "menton_anime"]:
		expected[key] = 1.0
	expected["nariz_anime"] = 0.0
	expected["alisado"] = 1.0
	var data: Dictionary = JSON.parse_string(text)
	check("anime.json: completo (todas las claves escritas)", data["valores"].size() == expected.size(), str(data["valores"].size()))
	check("anime.json: cuerpo neutro, 4 formas de cara a 1, nariz_anime a 0 y alisado a 1", loaded["valores"] == expected)
	var defaults: Dictionary = material.DEFAULTS
	check("anime.json: colores por defecto (piel gris) y prenda visible",
		loaded["colores"]["skin_color"] == defaults["skin_color"] and loaded["colores"]["garment_color"] == defaults["garment_color"]
		and loaded["prenda_visible"] == defaults["show_garment"])
	check("anime.json: versión 3, estilo anime (SH.7), su acabado y la piel de partida", data["version"] == 3
		and loaded["estilo"] == "anime" and loaded["acabado"] == material.default_finish(true) and _same(loaded["piel"], material.SKIN_START))
	var saved: Dictionary = preset.to_dict(loaded["nombre"], "humana", loaded["valores"], loaded["colores"],
		loaded["prenda_visible"], loaded["acabado"], loaded["estilo"], loaded["piel"])
	check("anime.json: cargar y guardar da el mismo texto (sin las claves de la ceja, AC.6c.4a)",
		preset.to_text(_without_brow(saved)) + "\n" == text)



## Paso PL.1b: cada plantilla es anime.json con otro cuerpo, completa, en el manifiesto, y se guarda igual que se lee.
func _check_templates() -> void:
	var base: Dictionary = preset.from_text(species.preset_text(), "humana", species.sliders)
	for template: String in TEMPLATES:
		var file := "presets/%s.json" % template
		var text := FileAccess.get_file_as_string(root_dir.path_join("godot/datos/humana").path_join(file))
		var loaded: Dictionary = preset.from_text(text, "humana", species.sliders)
		check("%s carga sin error ni claves desconocidas" % file, loaded.get("error") == "" and loaded["desconocidas"].is_empty(),
			str(loaded.get("error")))
		if loaded.get("error") != "":
			continue
		var data: Dictionary = JSON.parse_string(text)
		check("%s: versión 3, completa y en el manifiesto" % file, data["version"] == 3
			and data["valores"].size() == base["valores"].size() and species.manifest["files"].has(file))
		check("%s: cara, alisado, colores, prenda y acabado de anime.json" % file,
			FACE.all(func(key: String) -> bool: return loaded["valores"][key] == base["valores"][key])
			and loaded["colores"] == base["colores"] and loaded["prenda_visible"] == base["prenda_visible"]
			and loaded["acabado"] == base["acabado"] and loaded["estilo"] == base["estilo"] and loaded["piel"] == base["piel"])
		check("%s: cargar y guardar da el mismo texto (sin las claves de la ceja, AC.6c.4a)" % file,
			preset.to_text(_without_brow(preset.to_dict(loaded["nombre"], "humana", loaded["valores"], loaded["colores"],
			loaded["prenda_visible"], loaded["acabado"], loaded["estilo"], loaded["piel"]))) + "\n" == text)



## Paso PL.2: cada preset de serie tiene su miniatura (generar_miniaturas.gd): 256 × 256, fondo transparente, cuerpo en medio.
func _check_thumbnails() -> void:
	for template: String in ["anime"] + TEMPLATES:
		var image := Image.load_from_file(root_dir.path_join("godot/datos/humana/presets/%s.png" % template))
		var ok := image != null and image.get_size() == Vector2i(256, 256) and image.get_pixel(0, 0).a == 0.0 \
			and image.get_pixel(128, 128).a > 0.5
		check("presets/%s.png: 256 × 256, esquinas transparentes y el cuerpo en el centro" % template, ok)

## Paso PL.1b: en la ventana, cada plantilla (y el neutro) sin errores del informe en pose T y en «Atacar».
func _check_templates_in_window() -> void:
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var mesh: MeshInstance3D = main.body_view.species.mesh
	var skeleton: Skeleton3D = main.body_view.species.skeleton
	var attack: int = 1 + main.body_view.animations.entries().map(func(e: Dictionary) -> String: return e["id"]).find("atacar")
	check("la lista de animaciones tiene «Atacar»", attack > 0)
	for template: String in ["anime"] + TEMPLATES:
		var text := FileAccess.get_file_as_string(root_dir.path_join("godot/datos/humana/presets/%s.json" % template))
		main.editor.load_values(preset.from_text(text, "humana", main.body_view.species.sliders)["valores"])
		var p: Dictionary = main.measures.get_script().proportions(mesh, skeleton)
		print("  MEDIDA %s: %.2f cabezas, piernas %.3f, hombros %.2f, cintura %.3f, mano %.3f, pie %.3f" % [template,
			p["heads"], p["legs"], p["shoulders"], p["waist"], p["hand"], p["foot"]])
		if STYLE_RANGES.has(template):
			var ranges: Dictionary = STYLE_RANGES[template]
			var outside := ranges.keys().filter(func(k: String) -> bool: return p[k] < ranges[k][0] or p[k] > ranges[k][1])
			check("%s: proporciones en los rangos de GUIA_ESTILO.md §2" % template, outside.is_empty(), str(outside))
		for pose: String in ["pose T", "Atacar"]:
			main.body_actions.set_pose_t(true)
			main.body_actions.set_animation(attack if pose == "Atacar" else 0)
			var rows: Array = main.report_panel.rows
			var errors := rows.filter(func(r: Dictionary) -> bool: return r["nivel"] == "error")
			var warnings := rows.filter(func(r: Dictionary) -> bool: return r["nivel"] == "aviso")
			check("%s en %s: el informe no tiene errores" % [template, pose], not rows.is_empty() and errors.is_empty(),
				"%d avisos %s" % [warnings.size(), str(errors.map(func(r: Dictionary) -> String: return r["texto"]))])
		main.body_actions.set_animation(0)
		main.body_actions.set_pose_t(false)
	main.free()


func _both_sides(values: Dictionary) -> bool:
	for key: String in values:
		if key.ends_with("_l") and not values.has(key.trim_suffix("_l") + "_r"):
			return false
		if key.ends_with("_r") and not values.has(key.trim_suffix("_r") + "_l"):
			return false
	return true
