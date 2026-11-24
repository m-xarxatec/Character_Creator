class_name Preset

## Preset de un personaje: valores de los deslizadores, colores, prenda y acabado, en un Dictionary o en texto JSON.
## No decide carpetas ni nombres de archivo.
##
## Uso:
##   var data := Preset.to_dict("Mi preset", "humana", values, colors, true, BodyMaterial.get_finish(species.mesh),
##       "anime", BodyMaterial.get_skin(species.mesh))
##   # values: Forma y Proporción juntos; sin acabado, el del estilo; sin estilo, "clasico"; sin piel, SKIN_START
##   var text := Preset.to_text(data)                                           # claves ordenadas: mismo valor, mismo texto
##   var loaded := Preset.from_text(text, "humana", species.sliders)
##   if loaded["error"]: push_error(loaded["error"])
##   else: Preset.apply_look(species.mesh, loaded)
## Cargado: {error, nombre, valores, colores: {skin_color: Color, …}, prenda_visible, acabado: {softness: 0.04, …},
## estilo, piel: {edge_strength: 0.6, …}, desconocidas}.
##
## Formato (version 3: la del formato del preset, no la del manifiesto de datos/):
##   {"version": 3, "especie": "humana", "nombre": "…", "prenda_visible": true,
##    "valores": {"gender": 0.5, "hand_size_l": 0.5, "hand_size_r": 0.5, …},
##    "colores": {"skin_color": [r, g, b], "garment_color": [r, g, b]},
##    "acabado": {"softness": 0.04, "rim_strength": 0.25, "rim_width": 0.3, "width_px": 2.5},
##    "estilo": "clasico", "piel": {"edge_strength": 0.6, "gloss_strength": 0.35, …}}
## Carga estricta: los nueve campos son obligatorios y no hay otros; los deslizadores de dos lados llevan _l y _r.
## "acabado" (paso 4.7; claves y rangos en BodyMaterial.FINISH): el que falta toma su valor por defecto (el del
## estilo), el de fuera de rango se recorta y el desconocido es un error.
## "estilo" (SH.7a): "clasico" o "anime". "piel" (SH.7a; claves y rangos en BodyMaterial.SKIN): como "acabado"; el que
## falta toma BodyMaterial.SKIN_START. Solo se usa con estilo "anime".
## Se siguen leyendo la versión 1 (sin "acabado": el acabado por defecto) y la 2 (sin "estilo" ni "piel": estilo
## clásico). Siempre se guarda la 3.
## Números a 4 decimales. De "valores": el que falta toma su valor neutro, el desconocido se ignora y se lista en
## "desconocidas" (así un preset viejo sigue cargando cuando se añaden formas) y el de fuera de [0, 1] se recorta.
## Si algo más falla, error y nada más.

const BodyMaterial := preload("body_material.gd")
const Proportions := preload("proportions.gd")
const ShapeWeights := preload("shape_weights.gd")

const VERSION := 3
const FIELDS := ["version", "especie", "nombre", "valores", "colores", "prenda_visible", "acabado", "estilo", "piel"]
const STYLES := ["clasico", "anime"]
const COLORS := ["skin_color", "garment_color"]
const DECIMALS := 0.0001


static func to_dict(preset_name: String, species_id: String, values: Dictionary, colors: Dictionary, garment_visible: bool,
		finish := {}, style := "clasico", skin := {}) -> Dictionary:
	var rounded := {}
	for key: String in values:
		rounded[key] = snappedf(values[key], DECIMALS)
	var rgb := {}
	for color_name: String in colors:
		var c: Color = colors[color_name]
		rgb[color_name] = [snappedf(c.r, DECIMALS), snappedf(c.g, DECIMALS), snappedf(c.b, DECIMALS)]
	var rounded_finish: Dictionary = BodyMaterial.default_finish(style == "anime")
	for key: String in rounded_finish:
		rounded_finish[key] = snappedf(finish.get(key, rounded_finish[key]), DECIMALS)
	var rounded_skin: Dictionary = BodyMaterial.SKIN_START.duplicate()
	for key: String in rounded_skin:
		rounded_skin[key] = snappedf(skin.get(key, rounded_skin[key]), DECIMALS)
	return {"version": VERSION, "especie": species_id, "nombre": preset_name, "valores": rounded, "colores": rgb,
		"prenda_visible": garment_visible, "acabado": rounded_finish, "estilo": style, "piel": rounded_skin}


static func to_text(data: Dictionary) -> String:
	return JSON.stringify(data, "\t", true)


static func from_text(text: String, species_id: String, sliders: Array) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("JSON no válido (línea %d): %s" % [json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail("el preset no es un objeto")
	return from_dict(json.data, species_id, sliders)


static func from_dict(data: Dictionary, species_id: String, sliders: Array) -> Dictionary:
	data = _migrate(data)
	for field: String in FIELDS:
		if not data.has(field):
			return _fail("falta el campo '%s'" % field)
	for field: Variant in data:
		if not field in FIELDS:
			return _fail("campo desconocido '%s'" % field)
	if not _is_number(data["version"]) or data["version"] != VERSION:
		return _fail("versión %s; este código lee la %d" % [data["version"], VERSION])
	if typeof(data["especie"]) != TYPE_STRING or data["especie"] != species_id:
		return _fail("especie %s; se esperaba '%s'" % [data["especie"], species_id])
	if typeof(data["nombre"]) != TYPE_STRING or typeof(data["prenda_visible"]) != TYPE_BOOL \
			or typeof(data["valores"]) != TYPE_DICTIONARY or typeof(data["colores"]) != TYPE_DICTIONARY \
			or typeof(data["acabado"]) != TYPE_DICTIONARY or typeof(data["piel"]) != TYPE_DICTIONARY:
		return _fail("tipo de campo no válido")
	if typeof(data["estilo"]) != TYPE_STRING or not data["estilo"] in STYLES:
		return _fail("estilo '%s' desconocido" % data["estilo"])
	var values := _load_values(data["valores"], sliders)
	if values.has("error"):
		return values
	var colors := _load_colors(data["colores"])
	if colors.has("error"):
		return colors
	var finish := _load_finish(data["acabado"], data["estilo"] == "anime")
	if finish.has("error"):
		return finish
	var skin := _load_skin(data["piel"])
	if skin.has("error"):
		return skin
	return {"error": "", "nombre": data["nombre"], "valores": values["valores"], "desconocidas": values["desconocidas"],
		"colores": colors["colores"], "prenda_visible": data["prenda_visible"], "acabado": finish["acabado"],
		"estilo": data["estilo"], "piel": skin["piel"]}


## Pone el estilo, los colores, el interruptor de la prenda, el acabado y la piel en el material del cuerpo
## (BodyMaterial.apply ya hecho). Las piezas las pasa al estilo quien las tiene (BodyView.set_anime_style).
static func apply_look(mesh: MeshInstance3D, loaded: Dictionary) -> void:
	var anime: bool = loaded.get("estilo", "clasico") == "anime"
	BodyMaterial.set_style(mesh, anime)
	for color_name: String in loaded["colores"]:
		BodyMaterial.set_color(mesh, color_name, loaded["colores"][color_name])
	BodyMaterial.set_garment_visible(mesh, loaded["prenda_visible"])
	var finish: Dictionary = loaded.get("acabado", {})
	for key: String in finish:
		BodyMaterial.set_finish(mesh, key, finish[key])
	if anime:
		var skin: Dictionary = loaded.get("piel", BodyMaterial.SKIN_START)
		for key: String in skin:
			BodyMaterial.set_skin(mesh, key, skin[key])


## Un preset viejo pasa a la versión 3: la 1 recibe "acabado" vacío (valores por defecto) y la 1 y la 2, estilo
## "clasico" y "piel" vacía. El original no cambia.
static func _migrate(data: Dictionary) -> Dictionary:
	var version: Variant = data.get("version")
	var newer := data.has("estilo") or data.has("piel")
	if not _is_number(version) or newer or not ((version == 1 and not data.has("acabado"))
			or (version == 2 and data.has("acabado"))):
		return data
	var migrated := data.duplicate()
	if version == 1:
		migrated["acabado"] = {}
	migrated["estilo"] = "clasico"
	migrated["piel"] = {}
	migrated["version"] = VERSION
	return migrated


static func _load_skin(source: Dictionary) -> Dictionary:
	var skin: Dictionary = BodyMaterial.SKIN_START.duplicate()
	for key: Variant in source:
		if not skin.has(key):
			return _fail("piel desconocida '%s'" % key)
		if not _is_number(source[key]) or not is_finite(source[key]):
			return _fail("piel no válida en '%s'" % key)
		var limits: Array = BodyMaterial.SKIN[key]
		skin[key] = clampf(source[key], limits[0], limits[1])
	return {"piel": skin}


static func _load_finish(source: Dictionary, soft := false) -> Dictionary:
	var finish: Dictionary = BodyMaterial.default_finish(soft)
	for key: Variant in source:
		if not finish.has(key):
			return _fail("acabado desconocido '%s'" % key)
		if not _is_number(source[key]) or not is_finite(source[key]):
			return _fail("acabado no válido en '%s'" % key)
		var limits: Array = BodyMaterial.FINISH[key]
		finish[key] = clampf(source[key], limits[0], limits[1])
	return {"acabado": finish}


static func _load_values(source: Dictionary, sliders: Array) -> Dictionary:
	var values: Dictionary = ShapeWeights.neutral_values(sliders)
	values.merge(Proportions.neutral_values(sliders))
	var unknown: Array[String] = []
	for key: String in source:
		if not values.has(key):
			unknown.append(key)
		elif not _is_number(source[key]) or not ShapeWeights.set_value(values, key, source[key], false):
			return _fail("valor no válido en '%s'" % key)
	return {"valores": values, "desconocidas": unknown}


static func _load_colors(source: Dictionary) -> Dictionary:
	var colors := {}
	for color_name: String in COLORS:
		if not source.has(color_name):
			return _fail("falta el color '%s'" % color_name)
		var rgb: Variant = source[color_name]
		if typeof(rgb) != TYPE_ARRAY or rgb.size() != 3:
			return _fail("el color '%s' no es [r, g, b]" % color_name)
		for channel: Variant in rgb:
			if not _is_number(channel) or not is_finite(channel) or channel < 0.0 or channel > 1.0:
				return _fail("el color '%s' tiene un valor fuera de [0, 1]" % color_name)
		colors[color_name] = Color(rgb[0], rgb[1], rgb[2])
	if source.size() != COLORS.size():
		return _fail("color desconocido en 'colores'")
	return {"colores": colors}


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _fail(message: String) -> Dictionary:
	return {"error": message}
