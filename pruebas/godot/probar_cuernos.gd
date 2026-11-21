extends SceneTree
# Paso 13.5: generador de cuernos (horn_generator.gd). Sin ventana y sin datos/.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_cuernos.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: (1) quitar el bloque 5 de build_arrays y cambiar `[a, b, c, b, d, c]` por `[a, c, b, b, c, d]`
# -> falla «todas las caras miran hacia fuera»; (2) en la tapa, cambiar `(j + 1) % sides, j` por `j, (j + 1) % sides`
# -> falla la misma comprobación.

const MAX_MM := 0.01  # PROVISIONAL (D26)
const SHAPES := {
	"por defecto": {},
	"recto": {"curva": 0.0},
	"curvo": {"curva": 90.0, "segmentos": 32},
	"carnero": {"largo": 0.5, "curva": 300.0, "espiral": 200.0, "segmentos": 48, "lados": 12, "anillos": 12, "relieve": 0.3},
	"mínimo": {"segmentos": 2, "lados": 3},
	"sin tapa": {"tapa": false},
	"hacia atrás": {"curva": -120.0, "afilado": 2.5},
}

var failures := 0
var horn: GDScript


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var path := root_dir.path_join("godot/addons/creador/horn_generator.gd")
	if FileAccess.file_exists(path):
		horn = load(path)
	if horn == null:
		print("ERROR: no se encuentra horn_generator.gd")
		quit(1)
		return
	for label: String in SHAPES:
		_check_shape(label, SHAPES[label])
	_check_straight()
	_check_curved()
	_check_params()
	_check_mesh()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## Lo que debe cumplir cualquier cuerno.
func _check_shape(label: String, params: Dictionary) -> void:
	var p: Dictionary = horn.clamped(params)
	var data: Dictionary = horn.build_arrays(params)
	var vertices: PackedVector3Array = data["vertices"]
	var normals: PackedVector3Array = data["normals"]
	var indices: PackedInt32Array = data["indices"]
	var centers: PackedVector3Array = data["centers"]
	var expected: int = p["segmentos"] * p["lados"] + 1 + (1 if p["tapa"] else 0)
	check("%s: %d vértices, y normales y UV para todos" % [label, expected], vertices.size() == expected
		and normals.size() == expected and data["uvs"].size() == expected, "%d" % vertices.size())
	var triangles: int = 2 * p["lados"] * (p["segmentos"] - 1) + p["lados"] + (p["lados"] if p["tapa"] else 0)
	check("%s: %d triángulos" % [label, triangles], indices.size() == 3 * triangles, "%d" % (indices.size() / 3))

	var unit := true
	var finite := true
	for i in vertices.size():
		unit = unit and absf(normals[i].length() - 1.0) < 0.0001
		finite = finite and is_finite(vertices[i].x) and is_finite(vertices[i].y) and is_finite(vertices[i].z)
	check("%s: normales de longitud 1 y posiciones finitas" % label, unit and finite)

	var outward := 0
	var flat := 0
	var edges := {}
	for i in range(0, indices.size(), 3):
		var face: Vector3 = horn.facing(vertices, indices, i)
		if face.length() < 1e-12:
			flat += 1
		elif face.dot(normals[indices[i]] + normals[indices[i + 1]] + normals[indices[i + 2]]) > 0.0:
			outward += 1
		for k in 3:
			var a := indices[i + k]
			var b := indices[i + (k + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			edges[key] = edges.get(key, 0) + 1
	check("%s: todas las caras miran hacia fuera y ninguna tiene área 0" % label, outward == triangles and flat == 0,
		"%d de %d hacia fuera, %d planas" % [outward, triangles, flat])
	var open_edges := 0
	var bad_edges := 0
	for key: Vector2i in edges:
		if edges[key] == 1:
			open_edges += 1
		elif edges[key] != 2:
			bad_edges += 1
	var expected_open: int = 0 if p["tapa"] else p["lados"]
	check("%s: malla cerrada (cada arista en 2 caras)%s" % [label, "" if p["tapa"] else ", salvo el borde de la base"],
		open_edges == expected_open and bad_edges == 0, "%d aristas abiertas, %d con más de 2 caras" % [open_edges, bad_edges])

	var length := 0.0
	for k in centers.size() - 1:
		length += centers[k].distance_to(centers[k + 1])
	check("%s: la línea central mide el largo pedido (< %s mm)" % [label, MAX_MM], absf(length - p["largo"]) * 1000.0 < MAX_MM,
		"%.6f m" % length)
	var reach: float = p["largo"] + p["radio"] * (1.0 + p["relieve"])
	var farthest := 0.0
	for v: Vector3 in vertices:
		farthest = maxf(farthest, v.length())
	check("%s: cabe en una esfera de radio largo + radio" % label, farthest <= reach + 0.00001, "%.4f de %.4f m" % [farthest, reach])
	var again: Dictionary = horn.build_arrays(params)
	check("%s: mismos parámetros, misma malla" % label, again["vertices"] == vertices and again["indices"] == indices
		and again["normals"] == normals)


func _check_straight() -> void:
	var data: Dictionary = horn.build_arrays({"curva": 0.0, "largo": 0.4, "radio": 0.05, "lados": 16})
	var vertices: PackedVector3Array = data["vertices"]
	var normals: PackedVector3Array = data["normals"]
	var sides := 16
	var tip := vertices[12 * sides]
	check("recto: la punta está en (0, largo, 0) (< %s mm)" % MAX_MM, 1000.0 * tip.distance_to(Vector3(0, 0.4, 0)) < MAX_MM)
	var base_radius := 0.0
	var leaning := true
	for j in sides:
		base_radius = maxf(base_radius, absf(Vector2(vertices[j].x, vertices[j].z).length() - 0.05))
		leaning = leaning and absf(vertices[j].y) < 0.000001 and normals[j].y > 0.0 \
			and normals[j].dot(Vector3(vertices[j].x, 0, vertices[j].z).normalized()) > 0.9
	check("recto: el anillo de la base es un círculo de radio 0,05 en y = 0", base_radius * 1000.0 < MAX_MM)
	check("recto: las normales de un cono apuntan hacia fuera y algo hacia la punta", leaning)
	var half := Vector2(vertices[6 * sides].x, vertices[6 * sides].z).length()
	check("recto, afilado 1: a media altura el radio es la mitad", absf(half - 0.025) * 1000.0 < MAX_MM, "%.5f m" % half)


func _check_curved() -> void:
	var data: Dictionary = horn.build_arrays({"curva": 90.0, "segmentos": 64, "largo": 1.0})
	var centers: PackedVector3Array = data["centers"]
	var first := (centers[1] - centers[0]).normalized()
	var last := (centers[64] - centers[63]).normalized()
	var degrees := rad_to_deg(first.angle_to(last))
	check("curvo 90°: la dirección gira (63/64) × 90° de la base a la punta", absf(degrees - 90.0 * 63.0 / 64.0) < 0.01, "%.4f°" % degrees)
	check("curvo: se queda en el plano x = 0 y avanza hacia +Z", absf(centers[64].x) < 0.00001 and centers[64].z > 0.3)
	var spiral: Dictionary = horn.build_arrays({"curva": 90.0, "segmentos": 64, "largo": 1.0, "espiral": 180.0})
	var spiral_centers: PackedVector3Array = spiral["centers"]
	check("con espiral: la punta sale del plano x = 0", absf(spiral_centers[64].x) > 0.01)
	var ridged: Dictionary = horn.build_arrays({"curva": 0.0, "anillos": 4, "relieve": 0.5, "segmentos": 64, "lados": 8})
	var plain: Dictionary = horn.build_arrays({"curva": 0.0, "anillos": 0, "segmentos": 64, "lados": 8})
	var ridged_vertices: PackedVector3Array = ridged["vertices"]
	var plain_vertices: PackedVector3Array = plain["vertices"]
	var k := 8 * 8  # anillo 8 de 64: t = 1/8, justo en la cima de la primera cresta (4 crestas)
	var ratio := Vector2(ridged_vertices[k].x, ridged_vertices[k].z).length() / Vector2(plain_vertices[k].x, plain_vertices[k].z).length()
	check("con anillos: en la cima de una cresta el radio crece un 50 % (relieve 0,5)", absf(ratio - 1.5) < 0.001, "%.4f" % ratio)


func _check_params() -> void:
	var p: Dictionary = horn.clamped({"segmentos": 1000, "lados": 1, "largo": -3, "radio": "gordo", "curva": NAN, "otro": 5})
	check("parámetros fuera de rango: se recortan", p["segmentos"] == 64 and p["lados"] == 3 and is_equal_approx(p["largo"], 0.02))
	check("parámetros que no son números: toman el valor por defecto", is_equal_approx(p["radio"], 0.03) and is_equal_approx(p["curva"], 60.0))
	check("parámetros desconocidos: se descartan", not p.has("otro") and p.size() == horn.PARAMS.size() + 1)
	check("clamped de lo ya recortado no cambia nada", horn.clamped(p) == p)
	check("segmentos y lados son enteros", typeof(p["segmentos"]) == TYPE_INT and typeof(horn.clamped({"lados": 7.6})["lados"]) == TYPE_INT
		and horn.clamped({"lados": 7.6})["lados"] == 8)


func _check_mesh() -> void:
	var mesh: ArrayMesh = horn.build({"segmentos": 10, "lados": 6})
	check("build: una superficie de triángulos con 10 × 6 + 2 vértices", mesh.get_surface_count() == 1
		and mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES and mesh.surface_get_array_len(0) == 62)
	var start := Time.get_ticks_usec()
	for n in 20:
		horn.build_arrays({"segmentos": 64, "lados": 32})
	print("  MEDIDA el cuerno más denso (64 × 32): %.2f ms" % ((Time.get_ticks_usec() - start) / 20000.0))
