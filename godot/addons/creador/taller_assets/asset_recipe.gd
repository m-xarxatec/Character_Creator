extends RefCounted
## TA.1a — Valida la receta editable del Taller. Dimensiones en metros, Y arriba y frente +Z.
## Uso: var result := AssetRecipe.normalize(data)  # {error, receta} o {error}

const FORMAT := "gamemolde-asset-receta"
const REQUIRED := ["formato", "version", "id", "modo", "autor", "licencia"]
const HEX := "0123456789abcdefABCDEF"
const DEFAULTS := {
	"espada_parametrica": {
		"parametros": {"longitud_m": 1.0, "ancho_hoja_m": 0.09, "grosor_m": 0.018},
		"colores": {"hoja": "#B9C0C8", "guarda": "#77747A", "mango": "#514336"}},
	"extrusion_imagen": {
		"parametros": {"altura_m": 1.0, "grosor_m": 0.02}, "colores": {"principal": "#FFFFFF"}},
	"camiseta_basica": {
		"parametros": {"holgura_m": 0.0}, "colores": {"principal": "#FFFFFF"}},
}


static func normalize(data: Dictionary) -> Dictionary:
	for field: String in REQUIRED:
		if not data.has(field):
			return {"error": "Falta el campo '%s'" % field}
	if not data.formato is String or data.formato != FORMAT:
		return {"error": "formato de receta desconocido"}
	if typeof(data.version) not in [TYPE_INT, TYPE_FLOAT] or data.version != 1:
		return {"error": "El campo 'version' debe valer 1"}
	if not data.id is String or not _uses_alphabet(data.id, "abcdefghijklmnopqrstuvwxyz0123456789_"):
		return {"error": "id debe contener letras minúsculas ASCII, dígitos o guion bajo"}
	if not data.modo is String or not DEFAULTS.has(data.modo):
		return {"error": "modo de receta desconocido"}
	if not data.autor is String or data.autor.strip_edges().is_empty():
		return {"error": "Falta el nombre del autor"}
	if data.licencia not in ["propia", "CC0-1.0"]:
		return {"error": "licencia debe ser propia o CC0-1.0"}

	var fields := REQUIRED + ["parametros", "colores"]
	if data.modo == "extrusion_imagen":
		fields.append("fuente")
		var source_error := _source_error(data.get("fuente"))
		if not source_error.is_empty():
			return {"error": source_error}
	for key in data:
		if key not in fields:
			return {"error": "Campo desconocido '%s'" % str(key)}

	var defaults: Dictionary = DEFAULTS[data.modo]
	var recipe := {}
	for field: String in REQUIRED:
		recipe[field] = data[field]
	recipe.version = 1
	if data.has("fuente"):
		recipe.fuente = data.fuente.duplicate()
	for group: String in defaults:
		var values: Variant = data.get(group, {})
		if not values is Dictionary:
			return {"error": "%s debe ser un objeto" % group}
		var normalized: Dictionary = defaults[group].duplicate()
		for key in values:
			var field := "%s.%s" % [group, str(key)]
			if not normalized.has(key):
				return {"error": "Campo desconocido '%s'" % field}
			var value: Variant = values[key]
			if group == "colores":
				if not _is_rgb(value):
					return {"error": "%s debe ser un color #RRGGBB" % field}
				normalized[key] = value.to_upper()
			else:
				if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(value):
					return {"error": "%s debe ser un número finito" % field}
				if value < 0 or (value == 0 and key != "holgura_m"):
					return {"error": "Dimensión fuera de rango en %s" % field}
				normalized[key] = float(value)
		recipe[group] = normalized
	return {"error": "", "receta": recipe}


static func _source_error(source: Variant) -> String:
	if not source is Dictionary:
		return "Se necesita el objeto fuente de la imagen"
	for key in source:
		if key not in ["archivo", "sha256"]:
			return "Campo desconocido 'fuente.%s'" % str(key)
	var path: Variant = source.get("archivo")
	if not path is String or not path.begins_with("fuentes/"):
		return "fuente.archivo debe estar en fuentes/"
	var filename: String = path.trim_prefix("fuentes/")
	if not filename.is_valid_filename() or filename.length() <= 4 or filename.get_extension().to_lower() != "png":
		return "fuente.archivo debe ser un nombre de archivo PNG dentro de fuentes/"
	for i in filename.length():
		if filename.unicode_at(i) < 32:
			return "fuente.archivo contiene un carácter de control"
	var hash_value: Variant = source.get("sha256")
	if not hash_value is String or hash_value.length() != 64 or not _uses_alphabet(hash_value, HEX):
		return "fuente.sha256 debe contener 64 dígitos hexadecimales"
	return ""


static func _uses_alphabet(value: String, alphabet: String) -> bool:
	for ch in value:
		if not alphabet.contains(ch):
			return false
	return not value.is_empty()


static func _is_rgb(value: Variant) -> bool:
	return value is String and value.length() == 7 and value.begins_with("#") and _uses_alphabet(value.substr(1), HEX)
