class_name ShapeTransfer
extends RefCounted
## Transfiere a una prenda las formas y los pesos del cuerpo, para que le siga (paso 12.1; ruta/pasos/12_ropa.md).
## Código propio (MIT), escrito desde la geometría; no viene de MPFB ni de MakeHuman.
## Es para la HERRAMIENTA que crea un pack (se lanza una vez por prenda), no para el editor en cada fotograma.
##
## Uso:
##   var bound := ShapeTransfer.bind(body_vertices, body_normals, body_indices, garment_vertices, garment_normals, 0.05)
##   var deltas := ShapeTransfer.transfer_shapes(bound, garment_vertices, body_vertices, body_indices, body_shapes)
##   var skin := ShapeTransfer.transfer_weights(bound, body_indices, body_bones, body_weights)
##   var mask := ShapeTransfer.covered(body_vertices, body_normals, garment_vertices, garment_indices, 0.03)
## Todo son listas (PackedVector3Array…) en reposo y en el mismo espacio; no hay nodos.
## - bind: ata cada vértice de la prenda a un punto de un triángulo del cuerpo y guarda dónde está respecto a él
##   (cuánto a lo largo de dos direcciones del triángulo y cuánto por encima).
## - transfer_shapes: para cada forma del cuerpo, mueve el triángulo y recoloca el vértice con el mismo desplazamiento
##   respecto al triángulo ya movido. La prenda conserva su separación de la piel.
## - body_shapes: {forma: PackedVector3Array} con los DESPLAZAMIENTOS (forma − base), un valor por vértice del cuerpo.
## Trampa de axilas y entrepierna: el punto más cercano puede estar en otra parte del cuerpo (el brazo, para un vértice
## del costado). Por eso bind solo acepta triángulos que miran hacia el mismo lado que la normal de la prenda.

const MIN_FACING := 0.0  # coseno mínimo entre la normal del triángulo y la de la prenda
const BEHIND := 0.003  # cuánto puede estar un vértice de la prenda por DEBAJO de la piel y seguir atándose (m)
const MIN_SHAPE_MM := 0.01  # una forma que mueve la prenda menos que esto no se guarda
const MIN_AREA := 1e-12


## Ata cada vértice de la prenda al cuerpo. max_distance: a partir de qué distancia un vértice se queda sin atar (m).
## Devuelve {
##   "triangles": PackedInt32Array   # índice del triángulo del cuerpo (0 = el primero de body_indices), o −1 si no se ató
##   "weights": PackedVector3Array   # coordenadas baricéntricas del punto más cercano
##   "offsets": PackedVector3Array   # (a lo largo del lado, de través, por encima) respecto a ese punto, en metros
##   "signs": PackedFloat32Array     # +1 o −1: orientación del triángulo respecto a las normales del cuerpo
##   "doubtful": PackedInt32Array    # vértices atados sin cumplir el criterio de la normal (revisar a mano)
##   "unbound": PackedInt32Array     # vértices sin atar (más lejos que max_distance)
## }
static func bind(body_vertices: PackedVector3Array, body_normals: PackedVector3Array, body_indices: PackedInt32Array,
		garment_vertices: PackedVector3Array, garment_normals: PackedVector3Array, max_distance: float) -> Dictionary:
	var cell := maxf(max_distance, 0.01)
	var grid := _grid(body_vertices, body_indices, cell)
	var triangles := PackedInt32Array()
	var weights := PackedVector3Array()
	var offsets := PackedVector3Array()
	var signs := PackedFloat32Array()
	var doubtful := PackedInt32Array()
	var unbound := PackedInt32Array()
	for g in garment_vertices.size():
		var point := garment_vertices[g]
		var best := -1
		var best_distance := max_distance
		var best_weights := Vector3.ZERO
		var fallback := -1
		var fallback_distance := max_distance
		var fallback_weights := Vector3.ZERO
		var home := Vector3i((point / cell).floor())
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					var candidates: PackedInt32Array = grid.get(home + Vector3i(x, y, z), PackedInt32Array())
					for triangle in candidates:
						var a := body_vertices[body_indices[3 * triangle]]
						var b := body_vertices[body_indices[3 * triangle + 1]]
						var c := body_vertices[body_indices[3 * triangle + 2]]
						var bary := closest_weights(point, a, b, c)
						var closest := a * bary.x + b * bary.y + c * bary.z
						var distance := point.distance_to(closest)
						if distance >= fallback_distance and distance >= best_distance:
							continue
						if distance < fallback_distance:
							fallback = triangle
							fallback_distance = distance
							fallback_weights = bary
						var normal := _facing(body_vertices, body_normals, body_indices, triangle)
						if normal == Vector3.ZERO:
							continue
						if distance < best_distance and normal.dot(garment_normals[g]) > MIN_FACING \
								and (point - closest).dot(normal) > -BEHIND:
							best = triangle
							best_distance = distance
							best_weights = bary
		if best < 0 and fallback >= 0:
			best = fallback
			best_weights = fallback_weights
			doubtful.append(g)
		if best < 0:
			unbound.append(g)
			triangles.append(-1)
			weights.append(Vector3.ZERO)
			offsets.append(Vector3.ZERO)
			signs.append(1.0)
			continue
		var a := body_vertices[body_indices[3 * best]]
		var b := body_vertices[body_indices[3 * best + 1]]
		var c := body_vertices[body_indices[3 * best + 2]]
		var sign_value := _sign(body_vertices, body_normals, body_indices, best)
		var frame := _frame(a, b, c, sign_value)
		var from_surface := point - (a * best_weights.x + b * best_weights.y + c * best_weights.z)
		triangles.append(best)
		weights.append(best_weights)
		offsets.append(Vector3(from_surface.dot(frame.x), from_surface.dot(frame.y), from_surface.dot(frame.z)))
		signs.append(sign_value)
	return {"triangles": triangles, "weights": weights, "offsets": offsets, "signs": signs, "doubtful": doubtful, "unbound": unbound}


## Dónde queda cada vértice de la prenda cuando el cuerpo pasa a moved_body (mismas listas que en bind, ya movidas).
## Un vértice sin atar se queda donde estaba.
static func follow(bound: Dictionary, garment_vertices: PackedVector3Array, moved_body: PackedVector3Array,
		body_indices: PackedInt32Array) -> PackedVector3Array:
	var triangles: PackedInt32Array = bound["triangles"]
	var weights: PackedVector3Array = bound["weights"]
	var offsets: PackedVector3Array = bound["offsets"]
	var signs: PackedFloat32Array = bound["signs"]
	var result := PackedVector3Array()
	result.resize(garment_vertices.size())
	for g in garment_vertices.size():
		var triangle := triangles[g]
		if triangle < 0:
			result[g] = garment_vertices[g]
			continue
		var a := moved_body[body_indices[3 * triangle]]
		var b := moved_body[body_indices[3 * triangle + 1]]
		var c := moved_body[body_indices[3 * triangle + 2]]
		var frame := _frame(a, b, c, signs[g])
		result[g] = a * weights[g].x + b * weights[g].y + c * weights[g].z \
			+ frame.x * offsets[g].x + frame.y * offsets[g].y + frame.z * offsets[g].z
	return result


## {forma: PackedVector3Array de desplazamientos de la prenda}. Solo las formas que mueven la prenda más de MIN_SHAPE_MM.
## body_shapes: {forma: PackedVector3Array de desplazamientos del cuerpo}.
static func transfer_shapes(bound: Dictionary, garment_vertices: PackedVector3Array, body_vertices: PackedVector3Array,
		body_indices: PackedInt32Array, body_shapes: Dictionary) -> Dictionary:
	var rest := follow(bound, garment_vertices, body_vertices, body_indices)  # casi igual a garment_vertices; quita el redondeo
	var result := {}
	for shape: String in body_shapes:
		var shape_deltas: PackedVector3Array = body_shapes[shape]
		var moved_body := body_vertices.duplicate()
		for i in moved_body.size():
			moved_body[i] += shape_deltas[i]
		var moved := follow(bound, garment_vertices, moved_body, body_indices)
		var deltas := PackedVector3Array()
		deltas.resize(moved.size())
		var largest := 0.0
		for g in moved.size():
			deltas[g] = moved[g] - rest[g]
			largest = maxf(largest, deltas[g].length())
		if largest * 1000.0 >= MIN_SHAPE_MM:
			result[shape] = deltas
	return result


## Pesos de hueso de la prenda: mezcla de los tres vértices del triángulo, los 4 mayores, divididos por su suma.
## body_bones y body_weights: 4 por vértice, como en Mesh.ARRAY_BONES y ARRAY_WEIGHTS.
## Devuelve {"bones": PackedInt32Array, "weights": PackedFloat32Array}, 4 por vértice de la prenda.
## Un vértice sin atar queda con peso 1 en el hueso 0: hay que revisarlo (bound["unbound"]).
static func transfer_weights(bound: Dictionary, body_indices: PackedInt32Array, body_bones: PackedInt32Array,
		body_weights: PackedFloat32Array) -> Dictionary:
	var triangles: PackedInt32Array = bound["triangles"]
	var bary: PackedVector3Array = bound["weights"]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for g in triangles.size():
		var mixed := {}  # hueso -> peso
		if triangles[g] >= 0:
			for corner in 3:
				var vertex := body_indices[3 * triangles[g] + corner]
				for k in range(4 * vertex, 4 * vertex + 4):
					if body_weights[k] > 0.0:
						mixed[body_bones[k]] = mixed.get(body_bones[k], 0.0) + bary[g][corner] * body_weights[k]
		var order := mixed.keys()
		order.sort_custom(func(first: int, second: int) -> bool:
			return mixed[first] > mixed[second] or (mixed[first] == mixed[second] and first < second))
		var total := 0.0
		for k in mini(4, order.size()):
			total += mixed[order[k]]
		for k in 4:
			if k < order.size() and total > 0.0:
				bones.append(order[k])
				weights.append(mixed[order[k]] / total)
			else:
				bones.append(0)
				weights.append(1.0 if k == 0 and total <= 0.0 else 0.0)
	return {"bones": bones, "weights": weights}


## Qué vértices del cuerpo tapa la prenda: 1 si un rayo desde el vértice, hacia fuera por su normal, toca la prenda
## a menos de max_distance; 0 si no. Sirve para la máscara de piel oculta (12.3) y para contar piel que asoma.
## Es lento (cada vértice del cuerpo contra los triángulos cercanos de la prenda): solo para la herramienta y las pruebas.
static func covered(body_vertices: PackedVector3Array, body_normals: PackedVector3Array, garment_vertices: PackedVector3Array,
		garment_indices: PackedInt32Array, max_distance: float) -> PackedByteArray:
	var cell := maxf(max_distance, 0.01)
	var grid := _grid(garment_vertices, garment_indices, cell)
	var mask := PackedByteArray()
	mask.resize(body_vertices.size())
	for i in body_vertices.size():
		var from := body_vertices[i]
		var direction := body_normals[i].normalized()
		var checked := {}
		for step in 2:  # la celda del vértice y la del final del rayo, con sus vecinas
			var home := Vector3i(((from + direction * (max_distance * step)) / cell).floor())
			for x in range(-1, 2):
				for y in range(-1, 2):
					for z in range(-1, 2):
						var candidates: PackedInt32Array = grid.get(home + Vector3i(x, y, z), PackedInt32Array())
						for triangle in candidates:
							if mask[i] == 1 or checked.has(triangle):
								continue
							checked[triangle] = true
							var hit: Variant = Geometry3D.ray_intersects_triangle(from, direction,
								garment_vertices[garment_indices[3 * triangle]], garment_vertices[garment_indices[3 * triangle + 1]],
								garment_vertices[garment_indices[3 * triangle + 2]])
							if hit != null and from.distance_to(hit) <= max_distance:
								mask[i] = 1
	return mask


## Cuántos vértices del cuerpo que la prenda tapaba en reposo (mask) dejan de estar tapados con el cuerpo y la prenda movidos.
## Es la medida de «piel que asoma» de la Fase 12: debe dar 0.
static func poking(mask: PackedByteArray, moved_body: PackedVector3Array, moved_normals: PackedVector3Array,
		moved_garment: PackedVector3Array, garment_indices: PackedInt32Array, max_distance: float) -> int:
	var now := covered(moved_body, moved_normals, moved_garment, garment_indices, max_distance)
	var count := 0
	for i in mask.size():
		if mask[i] == 1 and now[i] == 0:
			count += 1
	return count


## Coordenadas baricéntricas (peso de a, de b y de c) del punto del triángulo más cercano a point.
## Algoritmo clásico por regiones (vértices, aristas, interior).
static func closest_weights(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab := b - a
	var ac := c - a
	var ap := point - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return Vector3(1.0, 0.0, 0.0)
	var bp := point - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return Vector3(0.0, 1.0, 0.0)
	var vc := d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		var on_ab := d1 / (d1 - d3)
		return Vector3(1.0 - on_ab, on_ab, 0.0)
	var cp := point - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return Vector3(0.0, 0.0, 1.0)
	var vb := d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		var on_ac := d2 / (d2 - d6)
		return Vector3(1.0 - on_ac, 0.0, on_ac)
	var va := d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		var on_bc := (d4 - d3) / ((d4 - d3) + (d5 - d6))
		return Vector3(0.0, 1.0 - on_bc, on_bc)
	var total := va + vb + vc
	if absf(total) < 1e-20:  # triángulo sin área
		return Vector3(1.0, 0.0, 0.0)
	return Vector3(va / total, vb / total, vc / total)


## Tres direcciones unitarias del triángulo: a lo largo del lado a-b, de través y por encima (hacia fuera si sign_value es
## el de _sign). Con un triángulo sin área, devuelve la identidad.
static func _frame(a: Vector3, b: Vector3, c: Vector3, sign_value: float) -> Basis:
	var along := b - a
	var up := along.cross(c - a) * sign_value
	if along.length_squared() < MIN_AREA or up.length_squared() < MIN_AREA * MIN_AREA:
		return Basis.IDENTITY
	along = along.normalized()
	up = up.normalized()
	return Basis(along, up.cross(along), up)


## +1 si (b − a) × (c − a) apunta hacia el mismo lado que las normales de los tres vértices; −1 si apunta al contrario.
## Así no importa en qué sentido estén ordenados los vértices del triángulo.
static func _sign(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, triangle: int) -> float:
	var i0 := indices[3 * triangle]
	var i1 := indices[3 * triangle + 1]
	var i2 := indices[3 * triangle + 2]
	var face := (vertices[i1] - vertices[i0]).cross(vertices[i2] - vertices[i0])
	return 1.0 if face.dot(normals[i0] + normals[i1] + normals[i2]) >= 0.0 else -1.0


## Normal unitaria del triángulo, hacia fuera. Vector3.ZERO si no tiene área.
static func _facing(vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, triangle: int) -> Vector3:
	var i0 := indices[3 * triangle]
	var face := (vertices[indices[3 * triangle + 1]] - vertices[i0]).cross(vertices[indices[3 * triangle + 2]] - vertices[i0])
	if face.length_squared() < MIN_AREA * MIN_AREA:
		return Vector3.ZERO
	return face.normalized() * _sign(vertices, normals, indices, triangle)


## Rejilla de celdas cúbicas: {celda: PackedInt32Array de triángulos cuya caja toca la celda}.
static func _grid(vertices: PackedVector3Array, indices: PackedInt32Array, cell: float) -> Dictionary:
	var grid := {}
	for triangle in indices.size() / 3:
		var a := vertices[indices[3 * triangle]]
		var b := vertices[indices[3 * triangle + 1]]
		var c := vertices[indices[3 * triangle + 2]]
		var low := Vector3i((Vector3(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)), minf(a.z, minf(b.z, c.z))) / cell).floor())
		var high := Vector3i((Vector3(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)), maxf(a.z, maxf(b.z, c.z))) / cell).floor())
		for x in range(low.x, high.x + 1):
			for y in range(low.y, high.y + 1):
				for z in range(low.z, high.z + 1):
					var key := Vector3i(x, y, z)
					if not grid.has(key):
						grid[key] = PackedInt32Array()
					var list: PackedInt32Array = grid[key]
					list.append(triangle)
					grid[key] = list  # los PackedArray dentro de un Dictionary se copian al leerlos: hay que volver a guardarlo
	return grid
