extends RefCounted
## TA.4b: convierte el contorno de una imagen en un sólido extruido.
## Uso: SilhouetteMesh.generate(data, contorno) devuelve {error, malla} o {error}.
## Contorno en píxeles con Y abajo (ImageMask.analyze). Malla en metros, Y arriba y frente +Z,
## centrada en X y Z, con la base en Y = 0.

const Recipe := preload("asset_recipe.gd")
const Validator := preload("asset_validator.gd")


static func generate(data: Dictionary, contour: PackedVector2Array) -> Dictionary:
	var result := Recipe.normalize(data)
	if result.error != "":
		return result
	var recipe: Dictionary = result.receta
	if recipe.modo != "extrusion_imagen":
		return {"error": "Se necesita una receta de extrusion_imagen"}
	var outline := _clean(contour)
	if outline.size() < 3:
		return {"error": "El contorno no forma una superficie válida"}
	if not _is_simple(outline):
		return {"error": "El contorno se cruza o se toca consigo mismo"}
	if _signed_area(outline) < 0.0:
		outline.reverse()
	var triangles := Geometry2D.triangulate_polygon(outline)
	if triangles.size() != (outline.size() - 2) * 3:
		return {"error": "No se pudo triangular el contorno: prueba otra simplificación"}
	var flat := _to_meters(outline, recipe.parametros.altura_m)
	var arrays := _solid(flat, triangles, recipe.parametros.grosor_m * 0.5)
	result = Validator.validate([arrays], true)
	if result.error != "":
		return {"error": result.error}
	var mesh := ArrayMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(recipe.colores.principal)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_name(0, "principal")
	mesh.surface_set_material(0, material)
	return {"error": "", "malla": mesh}


## Quita puntos repetidos y en línea. Un valor no finito o un retroceso devuelve un contorno vacío.
static func _clean(points: PackedVector2Array) -> PackedVector2Array:
	var unique := PackedVector2Array()
	for point in points:
		if not point.is_finite():
			return PackedVector2Array()
		if unique.is_empty() or point != unique[-1]:
			unique.append(point)
	if unique.size() > 1 and unique[0] == unique[-1]:
		unique.remove_at(unique.size() - 1)
	var kept := PackedVector2Array()
	for i in unique.size():
		var entering := unique[i] - unique[i - 1]
		var leaving := unique[(i + 1) % unique.size()] - unique[i]
		if entering.x * leaving.y - entering.y * leaving.x != 0.0:
			kept.append(unique[i])
		elif entering.x * leaving.x + entering.y * leaving.y < 0.0:
			return PackedVector2Array()
	return kept


## Positiva cuando el contorno gira en sentido horario en la imagen (Y abajo).
static func _signed_area(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		total += a.x * b.y - b.x * a.y
	return total * 0.5


## `triangulate_polygon` no delata todos los cruces. Compara solo las aristas que solapan en X.
static func _is_simple(points: PackedVector2Array) -> bool:
	var n := points.size()
	var starts := PackedVector2Array()
	for i in n:
		starts.append(Vector2(minf(points[i].x, points[(i + 1) % n].x), i))
	starts.sort()
	for s in n:
		var i := int(starts[s].y)
		var a := points[i]
		var b := points[(i + 1) % n]
		var right := maxf(a.x, b.x)
		for t in range(s + 1, n):
			if starts[t].x > right:
				break
			var j := int(starts[t].y)
			if (j - i + n) % n != 1 and (i - j + n) % n != 1 and _meet(a, b, points[j], points[(j + 1) % n]):
				return false
	return true


## Las dos aristas ya solapan en X: se tocan si también solapan en Y y cada una separa a la otra.
static func _meet(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	if maxf(a.y, b.y) < minf(c.y, d.y) or maxf(c.y, d.y) < minf(a.y, b.y):
		return false
	return _turn(a, b, c) * _turn(a, b, d) <= 0.0 and _turn(c, d, a) * _turn(c, d, b) <= 0.0


static func _turn(a: Vector2, b: Vector2, c: Vector2) -> float:
	return signf((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x))


## Invierte Y, conserva la proporción de la imagen y deja la base en el suelo.
static func _to_meters(outline: PackedVector2Array, height: float) -> PackedVector2Array:
	var left: float = outline[0].x
	var right: float = left
	var top: float = outline[0].y
	var bottom: float = top
	for point in outline:
		left = minf(left, point.x)
		right = maxf(right, point.x)
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	var factor := height / (bottom - top)
	var center := (left + right) * 0.5
	var flat := PackedVector2Array()
	for point in outline:
		flat.append(Vector2((point.x - center) * factor, (bottom - point.y) * factor))
	return flat


static func _solid(flat: PackedVector2Array, triangles: PackedInt32Array, half: float) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for t in range(0, triangles.size(), 3):
		var a := flat[triangles[t]]
		var b := flat[triangles[t + 1]]
		var c := flat[triangles[t + 2]]
		if (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) > 0.0:
			var swap := b
			b = c
			c = swap
		_face(vertices, normals, [_at(a, half), _at(b, half), _at(c, half)], Vector3.BACK)
		_face(vertices, normals, [_at(a, -half), _at(c, -half), _at(b, -half)], Vector3.FORWARD)
	for i in flat.size():
		var p := flat[i]
		var q := flat[(i + 1) % flat.size()]
		var normal := Vector3(p.y - q.y, q.x - p.x, 0).normalized()
		_face(vertices, normals, [_at(p, half), _at(q, -half), _at(q, half)], normal)
		_face(vertices, normals, [_at(p, half), _at(p, -half), _at(q, -half)], normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	return arrays


static func _at(point: Vector2, z: float) -> Vector3:
	return Vector3(point.x, point.y, z)


static func _face(vertices: PackedVector3Array, normals: PackedVector3Array, corners: Array, normal: Vector3) -> void:
	for corner: Vector3 in corners:
		vertices.append(corner)
		normals.append(normal)
