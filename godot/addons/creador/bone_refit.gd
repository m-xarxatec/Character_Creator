class_name BoneRefit
extends RefCounted
## Reajuste de huesos sin Blender, según datos/FORMATO.md (sección «articulaciones.json»).
##
## Uso:
##   var joints := BoneRefit.positions(bones, weights)  # {hueso: [cabeza, cola]}
##   var basis := BoneRefit.refit_basis(base_basis, base_head, base_tail, head, tail)
## - bones: el diccionario "bones" de articulaciones.json.
## - weights: {forma: peso}; las formas que faltan pesan 0.
## - base_basis: giro del hueso en el cuerpo base (en el esqueleto, su reposo global).
## Ejes y unidades de Godot. Los deslizadores Proporción se aplican después (escala del hueso).

## Eje de referencia del giro: el +Y de Blender.
const REFERENCE := Vector3(0.0, 0.0, -1.0)


## Cabeza y cola de cada hueso: base + Σ (peso de la forma × su desplazamiento).
static func positions(bones: Dictionary, weights: Dictionary) -> Dictionary:
	var result := {}
	for bone: String in bones:
		var data: Dictionary = bones[bone]
		var head := _vector(data["head"])
		var tail := _vector(data["tail"])
		var deltas: Dictionary = data["deltas"]
		for shape: String in deltas:
			var weight: float = weights.get(shape, 0.0)
			if weight != 0.0:
				head += weight * _vector(deltas[shape]["head"])
				tail += weight * _vector(deltas[shape]["tail"])
		result[bone] = [head, tail]
	return result


## Nuevo giro del hueso: mantiene fijo su giro sobre el propio eje (roll).
static func refit_basis(base: Basis, base_head: Vector3, base_tail: Vector3, head: Vector3, tail: Vector3) -> Basis:
	return arc(REFERENCE, tail - head) * arc(REFERENCE, base_tail - base_head).inverse() * base


## Giro mínimo que lleva la dirección from a la dirección to.
static func arc(from: Vector3, to: Vector3) -> Basis:
	var a := from.normalized()
	var b := to.normalized()
	var w := 1.0 + a.dot(b)
	if w < 1e-6:  # direcciones opuestas: media vuelta sobre un eje perpendicular cualquiera
		var other := Vector3.RIGHT if absf(a.x) < 0.9 else Vector3.UP
		return Basis(a.cross(other).normalized(), PI)
	var c := a.cross(b)
	return Basis(Quaternion(c.x, c.y, c.z, w).normalized())


static func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
