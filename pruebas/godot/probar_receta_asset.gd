extends SceneTree
# TA.1a — Contrato de receta v1 en memoria. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_receta_asset.gd)

var validator: GDScript
var failures := 0


func _initialize() -> void:
	var folder := ProjectSettings.globalize_path("res://").path_join("../../godot/addons/creador/taller_assets")
	validator = load(folder.path_join("asset_recipe.gd").simplify_path())
	var sword := _recipe("espada_parametrica")
	var image := _recipe("extrusion_imagen")
	image.licencia = "CC0-1.0"
	image.fuente = {"archivo": "fuentes/dibujo.png", "sha256": "a1".repeat(32)}
	var shirt := _recipe("camiseta_basica")
	_round_trip(sword, {"longitud_m": 1.0, "ancho_hoja_m": 0.09, "grosor_m": 0.018},
		{"hoja": "#B9C0C8", "guarda": "#77747A", "mango": "#514336"}, "longitud_m", "hoja", 0.75)
	_round_trip(image, {"altura_m": 1.0, "grosor_m": 0.02}, {"principal": "#FFFFFF"}, "altura_m", "principal")
	_round_trip(shirt, {"holgura_m": 0.0}, {"principal": "#FFFFFF"}, "holgura_m", "principal")

	var future := sword.merged({"version": 2, "nuevo": {"etiquetas": ["demo"]}}, true)
	var saved := future.duplicate(true)
	_reject("rechaza versión futura", sword.merged({"version": 2}, true), "version")
	_reject("identifica versión antes de campos futuros", future, "version")
	_check("conserva los datos de una versión futura", future == saved)
	for key in sword:
		var missing := sword.duplicate()
		missing.erase(key)
		_reject("requiere " + key, missing, key)
	for patch: Dictionary in [{"version": "1"}, {"version": 1.5}, {"formato": 1}, {"modo": "otro"},
			{"id": ""}, {"id": "pieza/1"}, {"id": "Ñ"}, {"autor": " "}, {"licencia": "desconocida"},
			{"parametros": []}, {"colores": null}, {"extra": true}, {"fuente": image.fuente}]:
		_reject("rechaza " + str(patch), sword.merged(patch, true), patch.keys()[0])
	for value: Variant in [NAN, INF, -1, 0, true, "1"]:
		_reject("dimensión inválida " + str(value), sword.merged({"parametros": {"longitud_m": value}}), "longitud_m")
	for color: Variant in ["#fff", "112233", "#-12345", "#FF00xx", 123]:
		_reject("color inválido " + str(color), shirt.merged({"colores": {"principal": color}}), "principal")
	_check_sword_limits(sword, image)
	_reject("dimensión de otro modo", shirt.merged({"parametros": {"altura_m": 2}}), "altura_m")
	_reject("color de otra región", shirt.merged({"colores": {"hoja": "#123456"}}), "hoja")
	_reject("requiere imagen", _recipe("extrusion_imagen"), "fuente")
	for key in image.fuente:
		var incomplete := image.duplicate(true)
		incomplete.fuente.erase(key)
		_reject("requiere fuente." + key, incomplete, key)
	_reject("fuente con clave desconocida", image.merged({"fuente": image.fuente.merged({"otra": 1})}, true), "otra")
	for path in ["/fuentes/a.png", "C:/a.png", "fuentes/../a.png", "fuentes/sub/a.png", "fuentes/C:a.png",
			"fuentes/sub\\a.png", "fuentes/.png", "fuentes/a.jpg", "fuentes/a\nb.png"]:
		_reject("ruta inválida " + path.c_escape(), image.merged({"fuente": image.fuente.merged({"archivo": path}, true)}, true), "archivo")
	for digest in ["a".repeat(63), "x".repeat(64)]:
		_reject("hash inválido", image.merged({"fuente": image.fuente.merged({"sha256": digest}, true)}, true), "sha256")
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _recipe(mode: String) -> Dictionary:
	return {"formato": "gamemolde-asset-receta", "version": 1, "id": "pieza_1", "modo": mode,
		"autor": "Taller", "licencia": "propia"}


## TA.3c: los extremos de la hoja valen, lo que queda fuera no, y grosor_m de la extrusión no hereda el límite.
func _check_sword_limits(sword: Dictionary, image: Dictionary) -> void:
	var limits := {"longitud_m": [0.5, 1.5], "ancho_hoja_m": [0.045, 0.135], "grosor_m": [0.009, 0.027]}
	for key: String in limits:
		for value: float in limits[key]:
			var inside: Dictionary = validator.normalize(sword.merged({"parametros": {key: value}}))
			_check("admite %s = %s" % [key, value], inside.error == "" and inside.receta.parametros[key] == value)
		for value: float in [limits[key][0] * 0.999, limits[key][1] * 1.001, 1e6]:
			_reject("rechaza %s = %s" % [key, value], sword.merged({"parametros": {key: value}}), key)
	_check_extrusion_limits(sword, image)


## TA.4c: la pieza desde imagen tiene sus límites, y el grosor de cada modo no hereda el del otro.
func _check_extrusion_limits(sword: Dictionary, image: Dictionary) -> void:
	var limits := {"altura_m": [0.10, 3.00], "grosor_m": [0.002, 0.200]}
	for key: String in limits:
		for value: float in limits[key]:
			var inside: Dictionary = validator.normalize(image.merged({"parametros": {key: value}}))
			_check("extrusión admite %s = %s" % [key, value], inside.error == "" and inside.receta.parametros[key] == value)
		for value: float in [limits[key][0] * 0.999, limits[key][1] * 1.001, 1e6]:
			_reject("extrusión rechaza %s = %s" % [key, value], image.merged({"parametros": {key: value}}), key)
	var thick: Dictionary = validator.normalize(image.merged({"parametros": {"grosor_m": 0.1}}))
	_check("la extrusión admite un grosor que la espada no", thick.error == "")
	_reject("la espada conserva su límite de grosor", sword.merged({"parametros": {"grosor_m": 0.1}}), "grosor_m")


func _round_trip(data: Dictionary, params: Dictionary, colors: Dictionary, size_key: String, color_key: String,
		size_value := 0.125) -> void:
	var result: Dictionary = validator.normalize(data)
	var expected := data.merged({"parametros": params, "colores": colors})
	_check("valores iniciales de " + data.modo, result == {"error": "", "receta": expected})
	var edited := data.duplicate(true)
	edited.parametros = {size_key: size_value}
	edited.colores = {color_key: "#a012bc"}
	var original := edited.duplicate(true)
	result = validator.normalize(edited)
	expected = expected.duplicate(true)
	expected.parametros[size_key] = size_value
	expected.colores[color_key] = "#A012BC"
	_check("valores editados de " + data.modo, result == {"error": "", "receta": expected})
	if not result.has("receta"):
		return
	var recipe: Dictionary = result.receta
	_check("normalización idempotente", validator.normalize(recipe) == result)
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(recipe))
	_check("ida y vuelta JSON de " + data.modo, validator.normalize(decoded) == result)
	recipe.colores[color_key] = "#000000"
	recipe.parametros[size_key] = 5
	if recipe.has("fuente"):
		recipe.fuente.archivo = "fuentes/otra.png"
	_check("resultado independiente de la entrada", edited == original)


func _reject(label: String, data: Dictionary, field: String) -> void:
	var result: Dictionary = validator.normalize(data)
	_check(label, result.size() == 1 and str(result.get("error", "")).contains(field))


func _check(label: String, ok: bool) -> void:
	print(("  bien  " if ok else "  FALLO ") + label)
	if not ok:
		failures += 1
