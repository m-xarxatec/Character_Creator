extends SceneTree
# Paso 3.7: presets en JSON (preset.gd). Sin ventana.
# Uso: godot --headless --path pruebas/godot -s probar_presets.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'

const MAX_ROUNDING := 0.0000501  # 4 decimales: el error de redondeo es de 0,00005 como mucho
const STYLE_PRESETS := ["anime_femenino", "anime_masculino", "chibi_oscuro", "chibi_fuera_de_rango"]

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
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	_check_round_trip()
	_check_text()
	_check_look()
	_check_values()
	_check_errors()
	_check_style_presets()
	species.scene.free()
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
	check("el texto es legible: 'version' al final, una clave por línea", text.count("\n") > values.size() and text.contains("\"version\": 1"))


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
	_expect_error("versión 2", _with("version", 2), "versión")
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


func _both_sides(values: Dictionary) -> bool:
	for key: String in values:
		if key.ends_with("_l") and not values.has(key.trim_suffix("_l") + "_r"):
			return false
		if key.ends_with("_r") and not values.has(key.trim_suffix("_r") + "_l"):
			return false
	return true
