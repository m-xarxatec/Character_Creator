extends SceneTree
## TA.4b: del contorno al sólido extruido, con imágenes creadas en memoria. Sin ventana.
## Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_malla_silueta.gd)

const Fixtures := preload("taller_fixtures.gd")
const VOLUME_TOLERANCE := 1e-6  # PROVISIONAL: relativa, por el redondeo a 32 bits (peor medido: 6e-8)
const SQUARE := [Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)]

var analyzer: GDScript
var builder: GDScript
var validator: GDScript
var failures := 0
var worst_volume := 0.0


func _initialize() -> void:
	var folder := ProjectSettings.globalize_path("res://").path_join("../../godot/addons/creador/taller_assets").simplify_path()
	analyzer = load(folder.path_join("image_mask.gd"))
	builder = load(folder.path_join("silhouette_mesh.gd"))
	validator = load(folder.path_join("asset_validator.gd"))
	_check_prism()
	_check_orientation()
	_check_parameters()
	_check_contour_forms()
	_check_invalid()
	_check_real_contours()
	print("MEDIDA peor error relativo de volumen: ", worst_volume)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _check_prism() -> void:
	var contour: PackedVector2Array = analyzer.analyze(Fixtures.images().rectangulo).contorno
	var mesh := _solid("prisma", contour, 1.0, 0.02)
	if mesh == null:
		return
	var counts := {}
	for normal: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]:
		counts[normal] = counts.get(normal, 0) + 1
	_check("prisma con seis direcciones de dos triángulos", counts.size() == 6 and counts.values().all(func(n: int) -> bool: return n == 6))
	var arrays := mesh.surface_get_arrays(0)
	var faces_ok := true
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var z: float = arrays[Mesh.ARRAY_VERTEX][i].z
		var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][i]
		if is_zero_approx(normal.x) and is_zero_approx(normal.y):
			faces_ok = faces_ok and signf(normal.z) == signf(z)
	_check("prisma con el frente hacia +Z y la espalda hacia -Z", faces_ok)


## La L tiene la barra arriba y a todo el ancho, y la columna a la izquierda de la imagen.
func _check_orientation() -> void:
	var mesh := _solid("L", Fixtures.polygons().ele, 1.0, 0.02)
	if mesh == null:
		return
	var below := -INF
	var above := -INF
	for vertex: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if vertex.y < 0.6:
			below = maxf(below, vertex.x)
		elif vertex.y > 0.7:
			above = maxf(above, vertex.x)
	_check("lo de arriba de la imagen queda arriba", is_equal_approx(above, 0.5))
	_check("la izquierda de la imagen queda a la izquierda", is_equal_approx(below, -1.0 / 6.0))


func _check_parameters() -> void:
	var contour: PackedVector2Array = Fixtures.polygons().ele
	var base: ArrayMesh = builder.generate(_recipe(1.0, 0.02), contour).malla
	var repeat: ArrayMesh = builder.generate(_recipe(1.0, 0.02), contour).malla
	_check("recurso independiente", repeat != base)
	_check("arrays reproducibles", repeat.surface_get_arrays(0) == base.surface_get_arrays(0))
	var tall: ArrayMesh = builder.generate(_recipe(2.0, 0.02), contour).malla
	_check("la altura escala X e Y y no Z", tall.get_aabb().size.is_equal_approx(base.get_aabb().size * Vector3(2, 2, 1)))
	var thick: ArrayMesh = builder.generate(_recipe(1.0, 0.1), contour).malla
	_check("el grosor solo cambia Z", thick.get_aabb().size.is_equal_approx(Vector3(base.get_aabb().size.x, base.get_aabb().size.y, 0.1)))
	_check("una sola superficie principal", base.get_surface_count() == 1 and base.surface_get_name(0) == "principal")
	var painted: ArrayMesh = builder.generate(_recipe(1.0, 0.02, "#4968AA"), contour).malla
	_check("usa el color de la receta", painted.surface_get_material(0).albedo_color.is_equal_approx(Color("#4968AA")))


func _check_contour_forms() -> void:
	var square := PackedVector2Array(SQUARE)
	var reversed := square.duplicate()
	reversed.reverse()
	_solid("sentido contrario", reversed, 1.0, 0.02)
	_solid("otro vértice inicial", PackedVector2Array([SQUARE[2], SQUARE[3], SQUARE[0], SQUARE[1]]), 1.0, 0.02)
	var extra := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 0), Vector2(3, 0), Vector2(4, 0),
		Vector2(4, 2), Vector2(4, 4), Vector2(0, 4), Vector2(0, 1), Vector2(0, 0)])
	var copy := extra.duplicate()
	var mesh: ArrayMesh = builder.generate(_recipe(1.0, 0.02), extra).get("malla")
	_check("quita puntos repetidos y en línea", mesh != null and mesh.get_faces().size() / 3 == 12)
	_check("no cambia el contorno recibido", extra == copy)


func _check_invalid() -> void:
	var cases := {
		"vacío": [],
		"dos puntos": [Vector2.ZERO, Vector2.ONE],
		"línea": [Vector2(0, 0), Vector2(5, 5), Vector2(10, 10)],
		"pico": [Vector2(0, 0), Vector2(10, 0), Vector2(20, 0), Vector2(10, 0), Vector2(10, 10), Vector2(0, 10)],
		"lazo": [Vector2(0, 0), Vector2(10, 10), Vector2(10, 0), Vector2(0, 10)],
		"cruce que se triangula": [Vector2(13, 5), Vector2(5, 11), Vector2(3, 17), Vector2(9, 8), Vector2(8, 19)],
		"vértice sobre arista": [Vector2(0, 0), Vector2(10, 0), Vector2(10, 10), Vector2(5, 0), Vector2(0, 10)],
		"vértice repetido": [Vector2(0, 0), Vector2(4, 0), Vector2(2, 2), Vector2(4, 4), Vector2(0, 4), Vector2(2, 2)],
		"NaN": [Vector2(0, 0), Vector2(NAN, 0), Vector2(4, 4)],
		"infinito": [Vector2(0, 0), Vector2(INF, 0), Vector2(4, 4)],
	}
	for label: String in cases:
		var result: Dictionary = builder.generate(_recipe(1.0, 0.02), PackedVector2Array(cases[label]))
		_check("rechaza " + label, not result.error.is_empty() and not result.has("malla"))
	var square := PackedVector2Array(SQUARE)
	var other := _recipe(1.0, 0.02)
	other.modo = "espada_parametrica"
	other.erase("fuente")
	other.erase("colores")
	other.parametros = {}
	_check("rechaza otro modo", builder.generate(other, square).error.contains("extrusion_imagen"))
	for size: Array in [[-1.0, 0.02], [1.0, 0.0], [1e-60, 0.02], [1.0, 1e-60], [1e100, 0.02]]:
		var result: Dictionary = builder.generate(_recipe(size[0], size[1]), square)
		_check("rechaza medidas %s" % str(size), not result.error.is_empty() and not result.has("malla"))


func _check_real_contours() -> void:
	var images := {"espada": _sword(), "anillo": _rects(64, [Rect2i(10, 10, 40, 40)], [Rect2i(25, 25, 10, 10)]),
		"cruz fina": _rects(128, [Rect2i(64, 52, 1, 24), Rect2i(62, 53, 4, 5), Rect2i(65, 45, 1, 19)]),
		"escalera": _stairs(1024, 120)}
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for n in 24:
		var side: int = [64, 128, 256][n % 3]
		images["mancha %d" % n] = _blob(side, rng)
	for label: String in images:
		for epsilon: float in [0.0, 1.0, 2.0, 4.0]:
			var analysis: Dictionary = analyzer.analyze(images[label], {"simplificacion": epsilon})
			if analysis.error != "":
				_check("%s analiza con %s px: %s" % [label, epsilon, analysis.error], false)
				continue
			_solid("%s con %s px" % [label, epsilon], analysis.contorno, 1.5, 0.04)


## Comprobación propia: no usa nada interno del generador salvo el validador común.
func _solid(label: String, contour: PackedVector2Array, height: float, depth: float) -> ArrayMesh:
	var result: Dictionary = builder.generate(_recipe(height, depth), contour)
	_check("genera " + label, result.get("error") == "" and result.has("malla"))
	if not result.has("malla"):
		return null
	var mesh: ArrayMesh = result.malla
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	_check("%s cerrado" % label, validator.validate([arrays], true).error == "")
	_check("%s con 4n - 4 triángulos" % label, vertices.size() / 3 == 4 * _corners(contour) - 4)
	var outline := _bounds(contour)
	var box := mesh.get_aabb()
	var wanted := Vector3(outline.size.x / outline.size.y * height, height, depth)
	_check("%s con su tamaño" % label, box.size.is_equal_approx(wanted))
	_check("%s centrado y en el suelo" % label, is_zero_approx(box.position.y) and is_zero_approx(box.get_center().x) and is_zero_approx(box.get_center().z))
	var scale_factor := height / outline.size.y
	var expected := _area(contour) * scale_factor * scale_factor * depth
	var error := absf(_volume(vertices) - expected) / expected
	worst_volume = maxf(worst_volume, error)
	_check("%s con su volumen hacia fuera" % label, error <= VOLUME_TOLERANCE)
	return mesh


func _recipe(height: float, depth: float, color := "#FFFFFF") -> Dictionary:
	return {"formato": "gamemolde-asset-receta", "version": 1, "id": "silueta", "modo": "extrusion_imagen",
		"autor": "Taller", "licencia": "propia", "fuente": {"archivo": "fuentes/silueta.png", "sha256": "ab".repeat(32)},
		"parametros": {"altura_m": height, "grosor_m": depth}, "colores": {"principal": color}}


func _corners(contour: PackedVector2Array) -> int:
	var count := 0
	for i in contour.size():
		var a := contour[i] - contour[i - 1]
		var b := contour[(i + 1) % contour.size()] - contour[i]
		if a.x * b.y - a.y * b.x != 0.0:
			count += 1
	return count


func _bounds(contour: PackedVector2Array) -> Rect2:
	var box := Rect2(contour[0], Vector2.ZERO)
	for point in contour:
		box = box.expand(point)
	return box


func _area(contour: PackedVector2Array) -> float:
	var total := 0.0
	for i in contour.size():
		var a := contour[i]
		var b := contour[(i + 1) % contour.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


## Con caras horarias, un sólido bien orientado da volumen positivo.
func _volume(v: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(0, v.size(), 3):
		var a := v[i]
		var b := v[i + 2]
		var c := v[i + 1]
		total += a.x * (b.y * c.z - b.z * c.y) - a.y * (b.x * c.z - b.z * c.x) + a.z * (b.x * c.y - b.y * c.x)
	return total / 6.0


func _rects(side: int, solid: Array, clear := []) -> Image:
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	for rect: Rect2i in solid:
		image.fill_rect(rect, Color.WHITE)
	for rect: Rect2i in clear:
		image.fill_rect(rect, Color(0, 0, 0, 0))
	return image


func _sword() -> Image:
	var image := _rects(256, [Rect2i(121, 192, 14, 40)])
	for y in range(10, 178):
		var half := 12 if y > 54 else int(12.0 * (y - 10) / 44.0) + 1
		image.fill_rect(Rect2i(128 - half, y, half * 2, 1), Color.WHITE)
	for y in range(178, 192):
		var half := 50 - absi(y - 185) * 3
		image.fill_rect(Rect2i(128 - half, y, half * 2, 1), Color.WHITE)
	return image


func _stairs(side: int, steps: int) -> Image:
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var step := (side - 40) / steps
	for i in steps:
		image.fill_rect(Rect2i(20, 20 + i * step, 20 + (i + 1) * step, step), Color.WHITE)
	return image


func _blob(side: int, rng: RandomNumberGenerator) -> Image:
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var middle := Vector2(side, side) * 0.5
	for k in rng.randi_range(3, 8):
		var center := middle + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)) * side
		var radius := rng.randf_range(0.1, 0.22) * side
		for y in range(maxi(0, int(center.y - radius)), mini(side, int(center.y + radius) + 1)):
			for x in range(maxi(0, int(center.x - radius)), mini(side, int(center.x + radius) + 1)):
				if Vector2(x, y).distance_to(center) <= radius:
					image.set_pixel(x, y, Color.WHITE)
	return image


func _check(label: String, ok: bool) -> void:
	if not ok:
		print("  FALLO ", label)
		failures += 1
	else:
		print("  bien  ", label)
