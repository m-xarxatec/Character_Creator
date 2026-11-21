extends RefCounted
## TA.3a: crea las cuatro superficies de la espada virtual a partir de una receta v1.
## Uso: SwordGenerator.generate(data) devuelve {error, malla} o {error}.

const Recipe := preload("asset_recipe.gd")
const Validator := preload("asset_validator.gd")
const PARTS := ["hoja", "guarda", "mango", "pomo"]


static func generate(data: Dictionary) -> Dictionary:
	var result := Recipe.normalize(data)
	if result.error != "":
		return result
	var recipe: Dictionary = result.receta
	if recipe.modo != "espada_parametrica":
		return {"error": "Se necesita una receta de espada_parametrica"}
	var length: float = recipe.parametros.longitud_m
	var width: float = recipe.parametros.ancho_hoja_m
	var depth: float = recipe.parametros.grosor_m
	var tip_scale: float = recipe.parametros.get("escala_punta", 1.0)
	var guard_scale: float = recipe.parametros.get("escala_guarda", 1.0)
	var guard_width := width * guard_scale
	var grip_scale: float = recipe.parametros.get("escala_mango", 1.0)
	var grip_width := width * grip_scale
	var pommel_scale: float = recipe.parametros.get("escala_pomo", 1.0)
	var grip := length * 0.09  # semialtura del mango, centrado en el origen
	var base := grip + length * 0.025
	# Cada perfil enumera sus anillos de abajo arriba: radios X/Z y altura Y.
	var surfaces := [
		_surface(4, [Vector3(width * 0.5, base, depth * 0.5),
			Vector3(width * 0.42, base + length * (1.0 - 0.16 * tip_scale), depth * 0.4),
			Vector3(0, base + length, 0)]),
		_surface(8, [Vector3(guard_width * 1.35, grip, depth * 1.25),
			Vector3(guard_width * 1.65, grip + length * 0.012, depth * 1.6),
			Vector3(guard_width * 1.45, base, depth * 1.25)], 0.25 if guard_scale != 1.0 else 0.0),
		_surface(8, [Vector3(grip_width * 0.24, -grip, grip_width * 0.21),
			Vector3(grip_width * 0.24, grip, grip_width * 0.21)], 0.5 if grip_scale != 1.0 else 0.0),
		_surface(8, [Vector3(width * 0.18 * pommel_scale, -grip - length * 0.055 * pommel_scale, depth * 0.8 * pommel_scale),
			Vector3(width * 0.42 * pommel_scale, -grip - length * 0.027 * pommel_scale, depth * 1.65 * pommel_scale),
			Vector3(width * 0.27 * pommel_scale, -grip, depth * 1.12 * pommel_scale)], 0.75 if pommel_scale != 1.0 else 0.0)]
	for i in surfaces.size():
		result = Validator.validate([surfaces[i]], true)
		if result.error != "":
			return {"error": "%s: %s" % [PARTS[i], result.error]}
	result = Validator.validate(surfaces, true)
	if result.error != "":
		return result
	var mesh := ArrayMesh.new()
	for i in surfaces.size():
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(recipe.colores["guarda" if PARTS[i] == "pomo" else PARTS[i]])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surfaces[i])
		mesh.surface_set_name(i, PARTS[i])
		mesh.surface_set_material(i, material)
	return {"error": "", "malla": mesh}


static func _surface(sides: int, profile: Array, edge_split := 0.0) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var previous := PackedVector3Array()
	for level in profile.size():
		var section: Vector3 = profile[level]
		var ring := PackedVector3Array()
		for i in sides:
			var angle := TAU * i / sides
			ring.append(Vector3(cos(angle) * section.x, section.y, sin(angle) * section.z))
		# Las tapas de piezas contiguas pueden coincidir al cambiar las proporciones.
		# Subdividir sus bordes en fracciones distintas conserva la silueta y
		# evita que el validador suelde sus aristas. El abanico también cambia de centro.
		var center := Vector3(0, section.y, 0)
		if edge_split != 0.0:
			var corners := ring
			ring = PackedVector3Array()
			for i in sides:
				ring.append(corners[i])
				ring.append(corners[i].lerp(corners[(i + 1) % sides], edge_split))
			center.x = section.x * edge_split * 0.25
			center.z = section.z * (1.0 - edge_split) * 0.25
		for i in ring.size():
			var j := (i + 1) % ring.size()
			if level == 0:
				_face(vertices, normals, center, ring[j], ring[i])
			else:
				_face(vertices, normals, previous[i], previous[j], ring[i])
				if section.x != 0 or section.z != 0:
					_face(vertices, normals, previous[j], ring[j], ring[i])
					if level == profile.size() - 1:
						_face(vertices, normals, center, ring[i], ring[j])
		previous = ring
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	return arrays


static func _face(vertices: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var area := (c - a).cross(b - a)
	var normal := area.normalized() if area.is_finite() else Vector3.ZERO
	for vertex: Vector3 in [a, b, c]:
		vertices.append(vertex)
		normals.append(normal)
