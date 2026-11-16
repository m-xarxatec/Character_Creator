class_name HornGenerator
extends RefCounted
## Generador de cuernos por parámetros, sin assets (paso 13.5). Es el patrón para colas, púas y cristales.
##
## Uso:
##   var mesh := HornGenerator.build({"largo": 0.3, "curva": 90.0, "espiral": 180.0, "anillos": 6})
##   var data := HornGenerator.build_arrays(params)     # {vertices, normals, uvs, indices}, sin crear la malla
##   var clean := HornGenerator.clamped(params)         # los parámetros que se usan de verdad (para guardar en el proyecto)
## La base está en el origen y el cuerno crece hacia +Y; se curva hacia +Z, hacia delante del personaje (con "espiral" 0). Metros.
## En el proyecto se guardan los parámetros, no la malla: se regenera al abrir (mismos parámetros, misma malla).
## Vértices: segmentos × lados + 1 (la punta) + 1 (el centro de la tapa, si "tapa" es true).

const PARAMS := {  # nombre: [por defecto, mínimo, máximo]
	"largo": [0.25, 0.02, 1.5],  # longitud de la línea central
	"radio": [0.03, 0.005, 0.3],  # radio en la base
	"afilado": [1.0, 0.2, 3.0],  # 1 = cono; menos = grueso hasta cerca de la punta; más = fino enseguida
	"curva": [60.0, -360.0, 360.0],  # grados que gira la dirección del cuerno de la base a la punta
	"espiral": [0.0, -1080.0, 1080.0],  # grados que gira el plano de la curva a lo largo del cuerno
	"segmentos": [12, 2, 64],  # anillos de vértices a lo largo
	"lados": [8, 3, 32],  # vértices por anillo
	"anillos": [0, 0, 40],  # número de bultos (crestas) a lo largo
	"relieve": [0.15, 0.0, 0.5],  # altura de las crestas, como fracción del radio
}


## Parámetros completos y dentro de rango. Lo desconocido se descarta; lo que falta o no es un número toma su valor por defecto.
static func clamped(params: Dictionary) -> Dictionary:
	var clean := {}
	for key: String in PARAMS:
		var limits: Array = PARAMS[key]
		var value: Variant = params.get(key, limits[0])
		if (typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT) or not is_finite(value):
			value = limits[0]
		if typeof(limits[0]) == TYPE_INT:
			clean[key] = clampi(roundi(value), limits[1], limits[2])
		else:
			clean[key] = clampf(value, limits[1], limits[2])
	clean["tapa"] = params.get("tapa", true) == true
	return clean


static func build(params: Dictionary) -> ArrayMesh:
	var data := build_arrays(params)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_TEX_UV] = data["uvs"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## {"vertices": PackedVector3Array, "normals": PackedVector3Array, "uvs": PackedVector2Array, "indices": PackedInt32Array,
##  "centers": PackedVector3Array (la línea central, segmentos + 1 puntos; para pruebas y para poner huesos)}
static func build_arrays(params: Dictionary) -> Dictionary:
	var p := clamped(params)
	var segments: int = p["segmentos"]
	var sides: int = p["lados"]
	var advance: float = p["largo"] / segments
	var bend := deg_to_rad(p["curva"]) / segments

	# 1. Línea central con un marco que no se retuerce (transporte paralelo): tangente, normal y binormal.
	var centers := PackedVector3Array()
	var tangents: Array[Vector3] = []
	var sideways: Array[Vector3] = []
	var position := Vector3.ZERO
	var tangent := Vector3.UP
	var normal := Vector3.RIGHT
	for k in segments + 1:
		centers.append(position)
		tangents.append(tangent)
		sideways.append(normal)
		var t := float(k) / segments
		var binormal := tangent.cross(normal)
		var spin := deg_to_rad(p["espiral"]) * t
		var axis := (normal * cos(spin) + binormal * sin(spin)).normalized()  # perpendicular a la tangente
		var turn := Basis(axis, bend)
		position += tangent * advance  # avanza con la tangente de este punto y después gira
		tangent = (turn * tangent).normalized()
		normal = (turn * normal).normalized()

	# 2. Radio de cada anillo. La punta (k = segmentos) tiene radio 0 y es un solo vértice.
	var radii := PackedFloat32Array()
	for k in segments + 1:
		radii.append(_radius(p, float(k) / segments))

	# 3. Vértices y normales.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for k in segments:
		var before := radii[maxi(k - 1, 0)]
		var after := radii[k + 1]
		var slope := (after - before) / (advance * (2.0 if k > 0 else 1.0))  # cuánto cambia el radio al avanzar
		var binormal := tangents[k].cross(sideways[k])
		for j in sides:
			var angle := TAU * j / sides
			var radial := sideways[k] * cos(angle) + binormal * sin(angle)
			vertices.append(centers[k] + radial * radii[k])
			normals.append((radial - tangents[k] * slope).normalized())
			uvs.append(Vector2(float(j) / sides, float(k) / segments))
	var tip := vertices.size()
	vertices.append(centers[segments])
	normals.append(tangents[segments])
	uvs.append(Vector2(0.5, 1.0))

	# 4. Triángulos: tiras entre anillos, abanico en la punta y tapa en la base.
	var indices := PackedInt32Array()
	for k in segments - 1:
		for j in sides:
			var a := k * sides + j
			var b := k * sides + (j + 1) % sides
			var c := a + sides
			var d := b + sides
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var last := (segments - 1) * sides
	for j in sides:
		indices.append_array(PackedInt32Array([last + j, last + (j + 1) % sides, tip]))
	if p["tapa"]:
		var center := vertices.size()
		vertices.append(Vector3.ZERO)
		normals.append(Vector3.DOWN)
		uvs.append(Vector2(0.5, 0.0))
		for j in sides:
			indices.append_array(PackedInt32Array([(j + 1) % sides, j, center]))

	# 5. Godot dibuja la cara cuyos vértices van en el sentido de las agujas del reloj vista desde fuera.
	# En vez de fiarse del orden de arriba, se comprueba con el primer triángulo y, si mira hacia dentro, se da la vuelta a todos.
	if facing(vertices, indices, 0).dot(normals[indices[0]] + normals[indices[1]] + normals[indices[2]]) < 0.0:
		for i in range(0, indices.size(), 3):
			var swap := indices[i + 1]
			indices[i + 1] = indices[i + 2]
			indices[i + 2] = swap
	return {"vertices": vertices, "normals": normals, "uvs": uvs, "indices": indices, "centers": centers}


## Hacia dónde mira el triángulo que empieza en indices[first], con el criterio de Godot (sentido de las agujas del reloj).
## Sin normalizar: su longitud es el doble del área.
static func facing(vertices: PackedVector3Array, indices: PackedInt32Array, first: int) -> Vector3:
	var a := vertices[indices[first]]
	var b := vertices[indices[first + 1]]
	var c := vertices[indices[first + 2]]
	return (c - a).cross(b - a)


## Radio a la fracción t del largo (0 = base, 1 = punta).
static func _radius(p: Dictionary, t: float) -> float:
	var radius: float = p["radio"] * pow(1.0 - t, p["afilado"])
	if p["anillos"] > 0:
		radius *= 1.0 + p["relieve"] * 0.5 * (1.0 - cos(TAU * p["anillos"] * t))
	return radius
