class_name Proportions
extends RefCounted
## Deslizadores Proporción: escala uniforme de un hueso (y de sus hijos), según deslizadores.csv.
##
## Uso:
##   var values := Proportions.neutral_values(species.sliders)   # {"height": 0.5, "hand_size_l": 0.5, …}
##   ShapeWeights.set_value(values, "hand_size_l", 0.8, true)     # mismo recorte, simetría y rechazo de NaN
##   Proportions.apply(species.skeleton, Proportions.scales(values, species.sliders))
## En el CSV, decr e incr son "escala:Hueso=x". Valor 0 → x de decr, 0,5 → 1, 1 → x de incr (en línea recta por tramos).
## Con dos lados, _l es el hueso Left… y _r el Right…. La escala va en la pose, no en el reposo.


## Todos los deslizadores Proporción en su valor neutro.
static func neutral_values(sliders: Array) -> Dictionary:
	var values := {}
	for row: Dictionary in sliders:
		if row["tipo"] == "Proporción":
			for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
				values[row["id"] + side] = 0.5
	return values


## {hueso: escala} de cada valor.
static func scales(values: Dictionary, sliders: Array) -> Dictionary:
	var result := {}
	for row: Dictionary in sliders:
		if row["tipo"] != "Proporción":
			continue
		var low := _parse(row["decr"])
		var high := _parse(row["incr"])
		for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
			var v: float = values.get(row["id"] + side, 0.5)
			var scale := lerpf(low[1], 1.0, 2.0 * v) if v < 0.5 else lerpf(1.0, high[1], 2.0 * v - 1.0)
			result[_bone(low[0], side)] = scale
	return result


## Pone la escala de cada hueso en su pose (igual en los tres ejes).
static func apply(skeleton: Skeleton3D, scales: Dictionary) -> void:
	for bone: String in scales:
		skeleton.set_bone_pose_scale(skeleton.find_bone(bone), Vector3.ONE * scales[bone])


## "escala:Root=0.85" → ["Root", 0.85]
static func _parse(text: String) -> Array:
	var parts := text.trim_prefix("escala:").split("=")
	return [parts[0], float(parts[1])]


static func _bone(bone: String, side: String) -> String:
	return {"": bone, "_l": "Left" + bone, "_r": "Right" + bone}[side]
