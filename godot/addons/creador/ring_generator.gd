class_name RingGenerator
extends RefCounted
## Paso AB.11: generador de aros (toro) por parámetros, sin assets: halo, coronas sencillas, pendientes.
## El aro está en el plano XZ, centrado en el origen (el eje mira a +Y). Metros. Mismo patrón que HornGenerator.
## Uso:
##   var mesh := RingGenerator.build({"radio": 0.09, "grosor": 0.008})

const PARAMS := {  # nombre: [por defecto, mínimo, máximo]
	"radio": [0.09, 0.005, 1.0],  # del centro del aro al centro del tubo
	"grosor": [0.008, 0.001, 0.2],  # radio del tubo
	"segmentos": [32, 3, 128],  # alrededor del aro
	"lados": [8, 3, 32],  # alrededor del tubo
}


static func clamped(params: Dictionary) -> Dictionary:
	var clean := {}
	for key: String in PARAMS:
		var limits: Array = PARAMS[key]
		var value: Variant = params.get(key, limits[0])
		if (typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT) or not is_finite(value):
			value = limits[0]
		clean[key] = clampi(roundi(value), limits[1], limits[2]) if typeof(limits[0]) == TYPE_INT \
			else clampf(value, limits[1], limits[2])
	return clean


static func build(params: Dictionary) -> ArrayMesh:
	var p := clamped(params)
	var segments: int = p["segmentos"]
	var sides: int = p["lados"]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for k in segments:
		var around := TAU * k / segments
		var out := Vector3(cos(around), 0.0, sin(around))
		for j in sides:
			var turn := TAU * j / sides
			var normal := out * cos(turn) + Vector3.UP * sin(turn)
			vertices.append(out * p["radio"] + normal * p["grosor"])
			normals.append(normal)
			uvs.append(Vector2(float(k) / segments, float(j) / sides))
	var indices := PackedInt32Array()
	for k in segments:
		for j in sides:
			var a := k * sides + j
			var b := k * sides + (j + 1) % sides
			var c := ((k + 1) % segments) * sides + j
			var d := ((k + 1) % segments) * sides + (j + 1) % sides
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	# Godot dibuja la cara en sentido horario vista desde fuera: si la primera mira hacia dentro, se da la vuelta a todas.
	var face := (vertices[indices[2]] - vertices[indices[0]]).cross(vertices[indices[1]] - vertices[indices[0]])
	if face.dot(normals[indices[0]]) < 0.0:
		for i in range(0, indices.size(), 3):
			var keep := indices[i + 1]
			indices[i + 1] = indices[i + 2]
			indices[i + 2] = keep
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
