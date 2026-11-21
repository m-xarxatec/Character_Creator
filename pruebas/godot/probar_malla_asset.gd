extends SceneTree
# TA.1b — Contrato de geometría y datos sintéticos del Taller. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_malla_asset.gd)

const Fixtures := preload("taller_fixtures.gd")
const O := Vector3.ZERO
const X := Vector3.RIGHT
const Y := Vector3.UP
const Z := Vector3.BACK  # +Z

var validator: GDScript
var failures := 0


func _initialize() -> void:
	var folder := ProjectSettings.globalize_path("res://").path_join("../../godot/addons/creador/taller_assets")
	validator = load(folder.path_join("asset_validator.gd").simplify_path())
	if validator == null or not validator.can_instantiate():
		print("FALLO al cargar el validador")
		quit(1)
		return
	_check_surfaces()
	_check_solids()
	_check_fixtures()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _surface(points: Array, normal: Vector3, indices: Variant = null) -> Array:
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = PackedVector3Array(points)
	var normals := PackedVector3Array()
	normals.resize(points.size())
	normals.fill(normal)
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_INDEX] = indices
	return surface


func _check_surfaces() -> void:
	var front := _surface([O, Y, X], Z)
	var indexed := _surface([O, X, Y, Vector3(8, 9, 10)], Z, PackedInt32Array([0, 2, 1]))
	var flat := {"error": "", "triangulos": 1, "dimensiones_m": X + Y}
	_check("frontal horaria no indexada", validator.validate([front], false) == flat)
	_check("frontal indexada, medidas solo de los vértices usados", validator.validate([indexed], false) == flat)
	var empty_indices := front.duplicate(true)
	empty_indices[Mesh.ARRAY_INDEX] = PackedInt32Array()
	_check("índices vacíos equivalen a ternas consecutivas", validator.validate([empty_indices], false) == flat)
	_reject("lista vacía", [], false, "superficies")
	_reject("superficie sin slots", [[]], false, "ARRAY_MAX")
	_reject("superficie de tipo erróneo", [null], false, "ARRAY_MAX")
	_reject("superficie sin vértices", [_surface([], Z)], false, "vértices")
	_reject("tres puntos colineales", [_surface([O, X, 2 * X], Z)], false, "área")
	_reject("terna sin índice incompleta", [_surface([O, Y, X, Z], Z)], false, "terna")
	var side := 1.0e-25
	var tiny := _surface([O, Y * side, X * side], Z)
	_check("área positiva a escala pequeña", validator.validate([tiny], false)
		== {"error": "", "triangulos": 1, "dimensiones_m": (X + Y) * side})
	var huge := _surface([Vector3(-3e38, 0, 0), Y, Vector3(3e38, 0, 0)], Z)
	_reject("dimensiones no representables en metros", [huge], false, "dimensiones")
	for pair: Array in [[Mesh.ARRAY_INDEX, PackedInt32Array([-1, 1, 2]), "Índice"],
			[Mesh.ARRAY_INDEX, PackedInt32Array([0, 1, 3]), "Índice"],
			[Mesh.ARRAY_INDEX, PackedInt32Array([0, 1]), "terna"],
			[Mesh.ARRAY_INDEX, [0, 1, 2], "índices"],
			[Mesh.ARRAY_VERTEX, [O, Y, X], "vértices"],
			[Mesh.ARRAY_VERTEX, PackedVector3Array([O, Vector3(NAN, 0, 0), X]), "no finito"],
			[Mesh.ARRAY_NORMAL, null, "normal por vértice"],
			[Mesh.ARRAY_NORMAL, PackedVector3Array([Z]), "normal por vértice"],
			[Mesh.ARRAY_NORMAL, PackedVector3Array([Z, O, Z]), "nula"],
			[Mesh.ARRAY_NORMAL, PackedVector3Array([Z, Z, Vector3.INF]), "no finita"],
			[Mesh.ARRAY_NORMAL, PackedVector3Array([Z, -Z, Z]), "invertida"]]:
		var invalid := front.duplicate(true)
		invalid[pair[0]] = pair[1]
		_reject("segunda superficie: " + pair[2], [front, invalid], false, pair[2], "Superficie 1")


# Dos superficies de material con normales planas y vértices duplicados entre caras.
func _tetrahedron(faces: Array) -> Array:
	var surfaces := []
	for group: Array in [faces.slice(0, 2), faces.slice(2)]:
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		for face: Array in group:
			var outward: Vector3 = (face[2] - face[0]).cross(face[1] - face[0]).normalized()
			for point: Vector3 in face:
				vertices.append(point)
				normals.append(outward)
		var surface := []
		surface.resize(Mesh.ARRAY_MAX)
		surface[Mesh.ARRAY_VERTEX] = vertices
		surface[Mesh.ARRAY_NORMAL] = normals
		surfaces.append(surface)
	return surfaces


func _check_solids() -> void:
	var faces := [[O, X, Y], [O, Z, X], [O, Y, Z], [X, Z, Y]]
	var solid := _tetrahedron(faces)
	var original := var_to_bytes(solid)
	var expected := {"error": "", "triangulos": 4, "dimensiones_m": Vector3.ONE}
	_check("tetraedro cerrado con costura de material", validator.validate(solid, true) == expected)
	_check("el resultado es repetible y conserva los arrays", validator.validate(solid, true) == expected
		and original == var_to_bytes(solid))
	var mesh := ArrayMesh.new()
	for surface: Array in solid:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface)
	_check("ArrayMesh admite las dos superficies validadas", mesh.get_surface_count() == 2 and mesh.get_aabb().size == Vector3.ONE)
	var missing := _tetrahedron(faces.slice(1))
	_reject("rechaza sólido abierto", missing, true, "Arista abierta")
	_check("admite la misma pieza como superficie abierta", validator.validate(missing, false)
		== {"error": "", "triangulos": 3, "dimensiones_m": Vector3.ONE})
	_reject("tercera cara sobre una arista", _tetrahedron(faces + [faces[0]]), true, "más de dos")
	var flipped := faces.duplicate(true)
	flipped[0].reverse()
	_reject("una cara invertida incluso con sus normales invertidas", _tetrahedron(flipped), true, "mismo sentido")
	for i in range(1, flipped.size()):
		flipped[i].reverse()
	_reject("todas las caras y sus normales invertidas", _tetrahedron(flipped), true, "volumen orientado")


func _check_fixtures() -> void:
	var polygons := Fixtures.polygons()
	for name: String in ["cuadrado", "ele"]:
		var polygon: PackedVector2Array = polygons[name]
		var indices := Geometry2D.triangulate_polygon(polygon)
		var area := 0.0
		for i in range(0, indices.size(), 3):
			var a := polygon[indices[i]]
			area += absf((polygon[indices[i + 1]] - a).cross(polygon[indices[i + 2]] - a)) * 0.5
		_check("polígono " + name, indices.size() == 3 * (polygon.size() - 2) and area == (4.0 if name == "cuadrado" else 5.0))
	_check("la L deja libre su esquina", not Geometry2D.is_point_in_polygon(Vector2(2, 2), polygons.ele))
	var images := Fixtures.images()
	for name: String in ["rectangulo", "vacia", "borde", "fondo_uniforme"]:
		var image: Image = images[name]
		var matches := image.get_size() == Vector2i(8, 8)
		for y in image.get_height():
			for x in image.get_width():
				var object_pixel := x >= 2 and x < 6 and y >= 1 and y < 6
				if name == "vacia":
					object_pixel = false
				elif name == "borde":
					object_pixel = x < 3 and y >= 3 and y < 5
				var background := Color.BLUE if name == "fondo_uniforme" else Color.TRANSPARENT
				matches = matches and image.get_pixel(x, y) == (Color.WHITE if object_pixel else background)
		_check("píxeles de " + name, matches)


func _reject(label: String, data: Array, closed: bool, reason: String, context := "") -> void:
	var original := var_to_bytes(data)
	var result: Dictionary = validator.validate(data, closed)
	var message: String = result.get("error", "")
	_check(label, result.size() == 1 and message.contains(reason) and (context == "" or message.contains(context))
		and original == var_to_bytes(data), str(result))


func _check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail if not ok else "")
	if not ok:
		failures += 1
