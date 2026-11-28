class_name ShapeWeights
extends RefCounted
## Deslizadores Forma: de sus valores a los pesos de las formas, según datos/FORMATO.md.
##
## Uso:
##   var neutrals := ShapeWeights.neutral_values(species.sliders)   # {"gender": 0.5, "cuenca_plana": 0.0, …}
##   var values := neutrals.duplicate()
##   ShapeWeights.set_value(values, "arm_muscle_l", 0.8, true)        # con simetría, también arm_muscle_r
##   var missing := ShapeWeights.apply(species.mesh, ShapeWeights.weights(values, shape_names, neutrals))
## Clave de cada valor: el id del CSV, con _l / _r si el deslizador tiene dos lados. Valores de 0 a 1; el neutro n,
## de la columna neutro. Pesos: _decr = max(0, (n−v)/n), _incr = max(0, (v−n)/(1−n)); una forma de un lado (sin decr,
## se llama como su id) lleva el peso de _incr; cada corrección (a*b*…), el producto de sus partes.
## Paso 9.7.2: las formas de expresión (expr_<nombre VRM>, FORMATO.md) no son deslizadores: sus pesos salen de
## expression_weights() y entran en weights() antes de las correcciones (las del parpadeo, expr_blinkLeft*eye_tall_incr…).

const EXPRESSION_PREFIX := "expr_"
const EXPRESSION_GROUPS := {"blink": ["blinkLeft", "blinkRight"]}  # VRM 1.0: «blink» son los dos ojos


## Todos los deslizadores Forma en su valor neutro (columna neutro del CSV).
static func neutral_values(sliders: Array) -> Dictionary:
	var values := {}
	for row: Dictionary in sliders:
		if row["tipo"] == "Forma":
			for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
				values[row["id"] + side] = float(row["neutro"])
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


## {forma: peso} de todas las formas de shape_names (las que no mueve ningún valor, 0). neutrals: neutral_values().
## expressions (paso 9.7.2): {forma expr_*: peso}, de expression_weights().
static func weights(values: Dictionary, shape_names: PackedStringArray, neutrals: Dictionary,
		expressions := {}) -> Dictionary:
	var result := {}
	for name in shape_names:
		result[name] = 0.0
	for key: String in values:
		var v: float = values[key]
		var n: float = neutrals[key]
		var incr := maxf(0.0, (v - n) / (1.0 - n)) if n < 1.0 else 0.0
		if result.has(key):  # forma de un lado
			result[key] = incr
			continue
		result[_shape(key, "decr")] = maxf(0.0, (n - v) / n) if n > 0.0 else 0.0
		result[_shape(key, "incr")] = incr
	result.merge(expressions, true)
	for name in shape_names:
		if "*" in name:
			var product := 1.0
			for part in name.split("*"):
				product *= result[part]
			result[name] = product
	return result


## Paso 9.7.2: si es una forma de expresión (expr_*).
static func is_expression(shape_name: String) -> bool:
	return shape_name.begins_with(EXPRESSION_PREFIX)


## Paso 9.7.2: {nombre VRM: valor} → {forma expr_*: peso}, recortado a [0, 1]. «blink» suma a blinkLeft y blinkRight.
## Un nombre sin forma en shape_names, o con un valor que no es un número finito, va a rejected y no se aplica.
static func expression_weights(expressions: Dictionary, shape_names: PackedStringArray, rejected: Array[String]) -> Dictionary:
	var out := {}
	for key: Variant in expressions:
		var value: Variant = expressions[key]
		var parts: Array = EXPRESSION_GROUPS.get(key, [key]) if typeof(key) == TYPE_STRING else []
		var known := not parts.is_empty() and parts.all(func(part: String) -> bool: return EXPRESSION_PREFIX + part in shape_names)
		if not known or not (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) or not is_finite(value):
			rejected.append(str(key))
			continue
		for part: String in parts:
			var shape := EXPRESSION_PREFIX + part
			out[shape] = clampf(out.get(shape, 0.0) + float(value), 0.0, 1.0)
	return out


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
