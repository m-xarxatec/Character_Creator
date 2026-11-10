class_name ShapeWeights
extends RefCounted
## Deslizadores Forma: de sus valores a los pesos de las formas, según datos/FORMATO.md.
##
## Uso:
##   var values := ShapeWeights.neutral_values(species.sliders)   # {"gender": 0.5, "arm_muscle_l": 0.5, …}
##   ShapeWeights.set_value(values, "arm_muscle_l", 0.8, true)      # con simetría, también arm_muscle_r
##   var missing := ShapeWeights.apply(species.mesh, ShapeWeights.weights(values, shape_names))
## Clave de cada valor: el id del CSV, con _l / _r si el deslizador tiene dos lados. Valores de 0 a 1; 0,5 = neutro.
## Pesos: _decr = max(0, 1−2v), _incr = max(0, 2v−1); cada corrección (a*b*…), el producto de sus partes.


## Todos los deslizadores Forma en su valor neutro.
static func neutral_values(sliders: Array) -> Dictionary:
	var values := {}
	for row: Dictionary in sliders:
		if row["tipo"] == "Forma":
			for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
				values[row["id"] + side] = 0.5
	return values


## Guarda un valor recortado a [0, 1]; con simetría, también en el otro lado.
## Rechaza NaN e infinito (devuelve false y no cambia nada).
static func set_value(values: Dictionary, key: String, value: float, symmetry: bool) -> bool:
	if not is_finite(value) or not values.has(key):
		return false
	values[key] = clampf(value, 0.0, 1.0)
	var other := _other_side(key)
	if symmetry and values.has(other):
		values[other] = values[key]
	return true


## {forma: peso} de todas las formas de shape_names (las que no mueve ningún valor, 0).
static func weights(values: Dictionary, shape_names: PackedStringArray) -> Dictionary:
	var result := {}
	for name in shape_names:
		result[name] = 0.0
	for key: String in values:
		var v: float = values[key]
		result[_shape(key, "decr")] = maxf(0.0, 1.0 - 2.0 * v)
		result[_shape(key, "incr")] = maxf(0.0, 2.0 * v - 1.0)
	for name in shape_names:
		if "*" in name:
			var product := 1.0
			for part in name.split("*"):
				product *= result[part]
			result[name] = product
	return result


## Pone los pesos en la malla. Devuelve las formas de weights que la malla no tiene (debería estar vacío).
static func apply(mesh: MeshInstance3D, weights: Dictionary) -> PackedStringArray:
	var missing := PackedStringArray()
	var found := {}
	for i in mesh.mesh.get_blend_shape_count():
		var name := String(mesh.mesh.get_blend_shape_name(i))
		found[name] = true
		mesh.set_blend_shape_value(i, weights.get(name, 0.0))
	for name: String in weights:
		if not found.has(name):
			missing.append(name)
	return missing


## Nombres de las formas de una malla.
static func shape_names(mesh: Mesh) -> PackedStringArray:
	var names := PackedStringArray()
	for i in mesh.get_blend_shape_count():
		names.append(mesh.get_blend_shape_name(i))
	return names


static func _shape(key: String, direction: String) -> String:
	if key.ends_with("_l") or key.ends_with("_r"):
		return "%s_%s%s" % [key.left(-2), direction, key.right(2)]
	return "%s_%s" % [key, direction]


static func _other_side(key: String) -> String:
	if key.ends_with("_l"):
		return key.left(-2) + "_r"
	if key.ends_with("_r"):
		return key.left(-2) + "_l"
	return ""
