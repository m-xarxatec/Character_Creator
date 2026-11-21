extends SceneTree
## TA.3a: comprueba la geometría y los materiales que recibe el visor.
## Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_generador_espada.gd)

const PARTS := ["hoja", "guarda", "mango", "pomo"]
const SCALES := ["escala_punta", "escala_guarda", "escala_mango", "escala_pomo"]
const TRIANGLES := 144
var generator: GDScript
var validator: GDScript
var failures := 0


func _initialize() -> void:
	var folder := ProjectSettings.globalize_path("res://").path_join("../../godot/addons/creador/taller_assets").simplify_path()
	generator = load(folder.path_join("sword_generator.gd"))
	validator = load(folder.path_join("asset_validator.gd"))
	var recipe := {"formato": "gamemolde-asset-receta", "version": 1, "modo": "espada_parametrica",
		"id": "espada", "autor": "Taller", "licencia": "propia"}
	_check_mesh(recipe, Vector3(0.09, 1, 0.018), ["#B9C0C8", "#77747A", "#514336", "#77747A"])
	var edited := recipe.merged({"parametros": {"longitud_m": 0.7, "ancho_hoja_m": 0.12, "grosor_m": 0.024},
		"colores": {"hoja": "#4968AA", "guarda": "#BB8844", "mango": "#224422"}})
	_check_mesh(edited, Vector3(0.12, 0.7, 0.024), ["#4968AA", "#BB8844", "#224422", "#BB8844"])
	_check_scales(edited, load(folder.path_join("asset_recipe.gd")))
	_check_touching_rings(recipe)
	for invalid: Dictionary in [recipe.merged({"modo": "camiseta_basica"}, true),
			recipe.merged({"parametros": {"longitud_m": -1}}),
			recipe.merged({"parametros": {"longitud_m": 1e100}})]:
		var result: Dictionary = generator.generate(invalid)
		_check("entrada rechazada con diagnóstico", not result.error.is_empty() and not result.has("malla"))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _check_mesh(recipe: Dictionary, dimensions: Vector3, colors: Array) -> void:
	var result: Dictionary = generator.generate(recipe)
	_check("genera la espada: " + result.error, result.has("malla") and result.error == "")
	if not result.has("malla"):
		return
	var mesh: ArrayMesh = result.malla
	_check("cuatro superficies", mesh.get_surface_count() == PARTS.size())
	var repeat: Dictionary = generator.generate(recipe)
	_check("recurso independiente", repeat.has("malla") and repeat.malla != mesh)
	if mesh.get_surface_count() != PARTS.size() or not repeat.has("malla"):
		return
	var surfaces := []
	for i in PARTS.size():
		var arrays := mesh.surface_get_arrays(i)
		surfaces.append(arrays)
		var material := mesh.surface_get_material(i) as StandardMaterial3D
		_check("nombre y color de " + PARTS[i], mesh.surface_get_name(i) == PARTS[i]
			and material != null and material.albedo_color.is_equal_approx(Color(colors[i])))
		_check("sólido cerrado " + PARTS[i], validator.validate([arrays], true).error == "")
		_check("arrays reproducibles " + PARTS[i], arrays == repeat.malla.surface_get_arrays(i))
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var box := _bounds(vertices)
		match PARTS[i]:
			"hoja":
				_check("dimensiones y dirección de la hoja", box.size.is_equal_approx(dimensions) and box.position.y > 0)
			"mango":
				_check("origen centrado en el mango", box.has_point(Vector3.ZERO) and box.get_center().is_zero_approx())
			"pomo":
				_check("pomo bajo el agarre", box.end.y < 0)
	var report: Dictionary = validator.validate(surfaces, false)
	_check("conjunto válido de %d triángulos" % TRIANGLES, report.error == "" and report.triangulos == TRIANGLES)
	if report.error == "":
		print("MEDIDA espada: ", report.triangulos, " triángulos, caja en metros ", report.dimensiones_m)


## El aro del mango coincide con el del pomo: siguen siendo dos sólidos cerrados que se tocan.
func _check_touching_rings(recipe: Dictionary) -> void:
	var size := {"longitud_m": 1.0, "ancho_hoja_m": 0.128, "grosor_m": 0.027}
	var scales := {"escala_mango": 0.9, "escala_pomo": 0.8}
	var touching := recipe.merged({"parametros": size}, true)
	_check_variant(touching, generator.generate(touching).malla, scales)
	var result: Dictionary = generator.generate(recipe.merged({"parametros": size.merged(scales)}, true))
	_check("genera con aros coincidentes", result.error == "")
	if result.error != "":
		return
	var surfaces := []
	for i in PARTS.size():
		surfaces.append(result.malla.surface_get_arrays(i))
	_check("los aros coinciden al soldar el conjunto", validator.validate(surfaces, true).error.contains("más de dos caras"))


func _check_scales(recipe: Dictionary, contract: GDScript) -> void:
	var base: ArrayMesh = generator.generate(recipe).malla
	var neutral := {}
	for key: String in SCALES:
		neutral[key] = 1.0
	_check_variant(recipe, base, neutral)
	_check_variant(recipe, base, {"escala_mango": 1.125})
	_check_variant(recipe, base, {"escala_punta": 0.6, "escala_guarda": 1.4, "escala_mango": 0.8, "escala_pomo": 1.25})
	for key: String in SCALES:
		for factor: float in [0.5, 1.5]:
			_check_variant(recipe, base, {key: factor})
		for invalid: Variant in [0.49, 1.51, INF, NAN, "1", true]:
			var bad := recipe.merged({"parametros": {key: invalid}}, true)
			_check("rechaza escala inválida en " + key, contract.normalize(bad).error.contains(key))
		for mode: String in ["camiseta_basica", "extrusion_imagen"]:
			var other := recipe.merged({"modo": mode, "parametros": {key: 1}, "colores": {}}, true)
			if mode == "extrusion_imagen":
				other.fuente = {"archivo": "fuentes/demo.png", "sha256": "ab".repeat(32)}
			_check("rechaza " + key + " en " + mode, contract.normalize(other).error.contains(key))
	var partial := recipe.merged({"parametros": recipe.parametros.merged({"escala_guarda": 1.25})}, true)
	var normalized: Dictionary = contract.normalize(partial)
	_check("JSON conserva solo las escalas recibidas", normalized.get("receta", {}) == partial
		and contract.normalize(JSON.parse_string(JSON.stringify(partial))) == normalized)


func _check_variant(recipe: Dictionary, base: ArrayMesh, scales: Dictionary) -> void:
	var data := recipe.merged({"parametros": recipe.parametros.merged(scales)}, true)
	var result: Dictionary = generator.generate(data)
	_check("genera " + str(scales), result.error == "")
	if result.error != "":
		return
	var mesh: ArrayMesh = result.malla
	var surfaces := []
	for i in PARTS.size():
		var factor: float = scales.get(SCALES[i], 1.0)
		var arrays := mesh.surface_get_arrays(i)
		surfaces.append(arrays)
		var original := base.surface_get_arrays(i)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var box := _bounds(vertices)
		var reference := _bounds(original[Mesh.ARRAY_VERTEX])
		if factor == 1.0:
			_check("conserva los arrays de " + PARTS[i], arrays == original)
		else:
			match PARTS[i]:
				"hoja":
					_check("longitud de punta", box.is_equal_approx(reference) and is_equal_approx(
						_tip_length(vertices, box.end.y), factor * _tip_length(original[Mesh.ARRAY_VERTEX], reference.end.y)))
				"guarda":
					_check("anchura de guarda", box.size.is_equal_approx(reference.size * Vector3(factor, 1, 1)))
				"mango":
					_check("sección del mango", box.size.is_equal_approx(reference.size * Vector3(factor, 1, factor))
						and box.get_center().is_zero_approx())
				"pomo":
					_check("pomo escalado desde la unión", box.size.is_equal_approx(reference.size * factor)
						and is_equal_approx(box.end.y, reference.end.y))
		_check("superficie cerrada y color de " + PARTS[i], validator.validate([arrays], true).error == ""
			and mesh.surface_get_material(i).albedo_color == base.surface_get_material(i).albedo_color)
	_check("variante de %d triángulos" % TRIANGLES, validator.validate(surfaces, false).get("triangulos", 0) == TRIANGLES)


func _bounds(vertices: PackedVector3Array) -> AABB:
	var box := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices:
		box = box.expand(vertex)
	return box


func _tip_length(vertices: PackedVector3Array, top: float) -> float:
	var shoulder := -INF
	for vertex in vertices:
		if vertex.y < top:
			shoulder = maxf(shoulder, vertex.y)
	return top - shoulder


func _check(label: String, ok: bool) -> void:
	print(("  bien  " if ok else "  FALLO ") + label)
	if not ok:
		failures += 1
