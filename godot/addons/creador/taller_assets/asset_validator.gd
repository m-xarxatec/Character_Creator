extends RefCounted
## TA.1b — Comprueba las superficies triangulares de una pieza antes de construir su ArrayMesh.
## Uso: AssetValidator.validate(surfaces, true) -> {error, triangulos, dimensiones_m} o {error}.


static func validate(surfaces: Array, closed: bool) -> Dictionary:
	if surfaces.is_empty():
		return {"error": "La pieza no tiene superficies"}
	var position_ids := {}
	var edges := {}
	var triangles := 0
	var origin := Vector3.ZERO
	var low := Vector3.INF
	var high := -Vector3.INF
	var signed_volume_six := 0.0
	for s in surfaces.size():
		var problem := _surface_error(surfaces[s])
		if not problem.is_empty():
			return {"error": "Superficie %d: %s" % [s, problem]}
		var arrays: Array = surfaces[s]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var indexed := not indices.is_empty()
		var count := indices.size() if indexed else vertices.size()
		for offset in range(0, count, 3):
			var i := indices[offset] if indexed else offset
			var j := indices[offset + 1] if indexed else offset + 1
			var k := indices[offset + 2] if indexed else offset + 2
			var a := vertices[i]
			var b := vertices[j]
			var c := vertices[k]
			# Godot usa caras horarias. Operar en escalares de 64 bits evita que el área
			# de un triángulo pequeño desaparezca al guardarla en un Vector3 de 32 bits.
			var bx := b.x - a.x
			var by := b.y - a.y
			var bz := b.z - a.z
			var cx := c.x - a.x
			var cy := c.y - a.y
			var cz := c.z - a.z
			var nx := cy * bz - cz * by
			var ny := cz * bx - cx * bz
			var nz := cx * by - cy * bx
			if nx == 0.0 and ny == 0.0 and nz == 0.0:
				return {"error": "Superficie %d, triángulo %d: área nula" % [s, offset / 3]}
			for index: int in [i, j, k]:
				var n := normals[index]
				if nx * n.x + ny * n.y + nz * n.z < 0.0:
					return {"error": "Superficie %d, triángulo %d: normal invertida en vértice %d" % [s, offset / 3, index]}
			low = low.min(a).min(b).min(c)
			high = high.max(a).max(b).max(c)
			if closed:
				if triangles == 0:
					origin = a
				signed_volume_six += nx * (a.x - origin.x) + ny * (a.y - origin.y) + nz * (a.z - origin.z)
				var ia := _position_id(position_ids, a)
				var ib := _position_id(position_ids, b)
				var ic := _position_id(position_ids, c)
				_add_edge(edges, ia, ib)
				_add_edge(edges, ib, ic)
				_add_edge(edges, ic, ia)
			triangles += 1
	if closed:
		for edge: Vector2i in edges:
			var usage: Vector2i = edges[edge]
			if usage.x == 1:
				return {"error": "Arista abierta %s" % edge}
			if usage.x > 2:
				return {"error": "Arista %s compartida por más de dos caras" % edge}
			if usage.y != 0:
				return {"error": "Las caras recorren la arista %s en el mismo sentido" % edge}
		if signed_volume_six <= 0.0:
			return {"error": "El volumen orientado del sólido debe ser positivo"}
	var size := high - low
	if not size.is_finite():
		return {"error": "Las dimensiones de la pieza no son finitas"}
	return {"error": "", "triangulos": triangles, "dimensiones_m": size}


static func _surface_error(arrays: Variant) -> String:
	if not arrays is Array or arrays.size() != Mesh.ARRAY_MAX:
		return "Se esperan los slots de Mesh.ARRAY_MAX"
	if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
		return "Se esperaba un array de vértices"
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return "Faltan vértices"
	if not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or arrays[Mesh.ARRAY_NORMAL].size() != vertices.size():
		return "Se necesita una normal por vértice"
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in vertices.size():
		if not vertices[i].is_finite():
			return "Vértice %d no finito" % i
		if not normals[i].is_finite() or normals[i] == Vector3.ZERO:
			return "Normal %d no finita o nula" % i
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	var count := vertices.size()
	if indices != null:
		if not indices is PackedInt32Array:
			return "Se esperaba un array de índices enteros"
		if not indices.is_empty():
			count = indices.size()
		for i in indices.size():
			if indices[i] < 0 or indices[i] >= vertices.size():
				return "Índice fuera de rango en la posición %d" % i
	if count % 3 != 0:
		return "La última terna de vértices o índices está incompleta"
	return ""


static func _position_id(ids: Dictionary, point: Vector3) -> int:
	if not ids.has(point):
		ids[point] = ids.size()
	return ids[point]


static func _add_edge(edges: Dictionary, start: int, end: int) -> void:
	var key := Vector2i(mini(start, end), maxi(start, end))
	# x cuenta las caras incidentes; y se anula cuando sus sentidos son opuestos.
	var usage: Vector2i = edges.get(key, Vector2i.ZERO)
	usage.x += 1
	usage.y += 1 if start < end else -1
	edges[key] = usage
