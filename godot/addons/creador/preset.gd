class_name Preset

## Preset de un personaje: valores de los deslizadores, colores y prenda, en un Dictionary o en texto JSON.
## No decide carpetas ni nombres de archivo.
##
## Uso:
##   var data := Preset.to_dict("Mi preset", "humana", values, colors, true)   # values: Forma y Proporción juntos
##   var text := Preset.to_text(data)                                           # claves ordenadas: mismo valor, mismo texto
##   var loaded := Preset.from_text(text, "humana", species.sliders)
##   if loaded["error"]: push_error(loaded["error"])
##   else: Preset.apply_look(species.mesh, loaded)
## Cargado: {error, nombre, valores, colores: {skin_color: Color, …}, prenda_visible, desconocidas}.
##
## Formato (version 1: la del formato del preset, no la del manifiesto de datos/):
##   {"version": 1, "especie": "humana", "nombre": "…", "prenda_visible": true,
##    "valores": {"gender": 0.5, "hand_size_l": 0.5, "hand_size_r": 0.5, …},
##    "colores": {"skin_color": [r, g, b], "garment_color": [r, g, b]}}
## Carga estricta: los seis campos son obligatorios y no hay otros; los deslizadores de dos lados llevan _l y _r.
## Números a 4 decimales. De "valores": el que falta toma su valor neutro, el desconocido se ignora y se lista en
## "desconocidas" (así un preset viejo sigue cargando cuando se añaden formas) y el de fuera de [0, 1] se recorta.
## Si algo más falla, error y nada más.

const BodyMaterial := preload("body_material.gd")
const Proportions := preload("proportions.gd")
const ShapeWeights := preload("shape_weights.gd")

const VERSION := 1
const FIELDS := ["version", "especie", "nombre", "valores", "colores", "prenda_visible"]
const COLORS := ["skin_color", "garment_color"]
const DECIMALS := 0.0001


static func to_dict(preset_name: String, species_id: String, values: Dictionary, colors: Dictionary, garment_visible: bool) -> Dictionary:
	var rounded := {}
	for key: String in values:
		rounded[key] = snappedf(values[key], DECIMALS)
	var rgb := {}
	for color_name: String in colors:
		var c: Color = colors[color_name]
		rgb[color_name] = [snappedf(c.r, DECIMALS), snappedf(c.g, DECIMALS), snappedf(c.b, DECIMALS)]
	return {"version": VERSION, "especie": species_id, "nombre": preset_name, "valores": rounded, "colores": rgb,
		"prenda_visible": garment_visible}


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
			or typeof(data["valores"]) != TYPE_DICTIONARY or typeof(data["colores"]) != TYPE_DICTIONARY:
		return _fail("tipo de campo no válido")
	var values := _load_values(data["valores"], sliders)
	if values.has("error"):
		return values
	var colors := _load_colors(data["colores"])
	if colors.has("error"):
		return colors
	return {"error": "", "nombre": data["nombre"], "valores": values["valores"], "desconocidas": values["desconocidas"],
		"colores": colors["colores"], "prenda_visible": data["prenda_visible"]}


## Pone los colores y el interruptor de la prenda en el material del cuerpo (BodyMaterial.apply ya hecho).
static func apply_look(mesh: MeshInstance3D, loaded: Dictionary) -> void:
	for color_name: String in loaded["colores"]:
		BodyMaterial.set_color(mesh, color_name, loaded["colores"][color_name])
	BodyMaterial.set_garment_visible(mesh, loaded["prenda_visible"])


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
