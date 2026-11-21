extends SceneTree
## TA.4a: de la imagen al contorno, con imágenes creadas en memoria. Sin ventana.
## Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_mascara_imagen.gd)

const Fixtures := preload("taller_fixtures.gd")
const CLEAR := Color(0, 0, 0, 0)
const DARK := Color8(30, 32, 40)
const LIGHT := Color8(200, 205, 210)
const CROSSING := [Rect2i(64, 52, 1, 24), Rect2i(62, 53, 4, 5), Rect2i(65, 45, 1, 19)]  # se cruza al simplificar 2 px

var analyzer: GDScript
var failures := 0


func _initialize() -> void:
	var folder := ProjectSettings.globalize_path("res://").path_join("../../godot/addons/creador/taller_assets").simplify_path()
	analyzer = load(folder.path_join("image_mask.gd"))
	_check_fixtures()
	_check_shapes()
	_check_alpha()
	_check_color()
	_check_formats()
	_check_sizes()
	_check_contract()
	_check_simplification()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _check_fixtures() -> void:
	var images := Fixtures.images()
	var base := _shape("rectángulo con alfa", images.rectangulo, Rect2i(2, 1, 4, 5), 20.0, [])
	_check("el rectángulo usa el alfa", base.get("fondo") == "alfa")
	_error("imagen sin objeto", images.vacia, {}, "ningún objeto")
	_shape("objeto en el borde", images.borde, Rect2i(0, 3, 3, 2), 6.0, ["borde"])
	var keyed := _shape("fondo uniforme", images.fondo_uniforme, Rect2i(2, 1, 4, 5), 20.0, ["transparencia"])
	_check("color y alfa dan el mismo contorno", keyed.get("fondo") == "color" and keyed.get("contorno") == base.get("contorno"))


func _check_shapes() -> void:
	var result := _shape("L cóncava", _alpha(64, [Rect2i(10, 10, 12, 40), Rect2i(10, 38, 36, 12)]), Rect2i(10, 10, 36, 40), 768.0, [])
	_check("la L conserva sus 6 vértices", result.get("contorno", []).size() == 6)
	result = _shape("anillo", _alpha(64, [Rect2i(10, 10, 40, 40)], [Rect2i(25, 25, 10, 10)]), Rect2i(10, 10, 40, 40), 1600.0, ["hueco"])
	_check("el anillo cuenta un hueco", result.get("huecos") == 1 and result.get("islas") == 1)
	result = _shape("la isla mayor no es la primera", _alpha(64, [Rect2i(2, 2, 4, 4), Rect2i(20, 20, 30, 30)]), Rect2i(20, 20, 30, 30), 900.0, ["piezas"])
	_check("cuenta dos islas", result.get("islas") == 2 and result.get("huecos") == 0)
	result = _shape("isla dentro de un hueco", _alpha(64, [Rect2i(10, 10, 40, 40)], [Rect2i(20, 20, 20, 20)], [Rect2i(28, 28, 4, 4)]),
		Rect2i(10, 10, 40, 40), 1600.0, ["piezas", "hueco"])
	_check("cuenta la isla y el hueco", result.get("islas") == 2 and result.get("huecos") == 1)
	result = _shape("hueco en una isla secundaria", _alpha(64, [Rect2i(4, 4, 30, 30), Rect2i(44, 44, 14, 14)], [Rect2i(48, 48, 4, 4)]),
		Rect2i(4, 4, 30, 30), 900.0, ["piezas"])
	_check("ese hueco no cuenta", result.get("huecos") == 0)
	result = _shape("islas unidas por una esquina", _alpha(64, [Rect2i(10, 10, 10, 10), Rect2i(20, 20, 20, 20)]), Rect2i(20, 20, 20, 20), 400.0, ["piezas"])
	_check("cuentan como dos", result.get("islas") == 2)
	_shape("el mínimo de área", _alpha(16, [Rect2i(3, 3, 2, 2)]), Rect2i(3, 3, 2, 2), 4.0, [])
	_error("un píxel es demasiado poco", _alpha(16, [Rect2i(8, 8, 1, 1)]), {}, "pequeño")
	_error("tres píxeles son demasiado poco", _alpha(16, [Rect2i(8, 8, 3, 1)]), {}, "pequeño")


func _check_alpha() -> void:
	var soft := _picture(Vector2i(40, 40), CLEAR, [[Rect2i(8, 8, 24, 24), Color(1, 1, 1, 0.4)], [Rect2i(12, 12, 16, 16), Color.WHITE]])
	_shape("umbral 0,5 deja el núcleo", soft, Rect2i(12, 12, 16, 16), 256.0, [], {"umbral_alfa": 0.5})
	_shape("umbral 0,3 incluye el halo", soft, Rect2i(8, 8, 24, 24), 576.0, [], {"umbral_alfa": 0.3})
	var window := _picture(Vector2i(40, 40), Color.WHITE, [[Rect2i(10, 10, 20, 10), CLEAR]])
	_shape("invertir con alfa", window, Rect2i(10, 10, 20, 10), 200.0, [], {"invertir": true})
	var almost := _picture(Vector2i(32, 32), DARK, [[Rect2i(8, 8, 12, 16), LIGHT]])
	almost.set_pixel(1, 1, Color(DARK, 0.9))
	var result := _shape("un alfa que no separa sigue el color", almost, Rect2i(8, 8, 12, 16), 192.0, ["transparencia"])
	_check("ese caso usa el color", result.get("fondo") == "color")


func _check_color() -> void:
	var noisy := _noisy_background()
	_shape("ruido dentro de la tolerancia", noisy, Rect2i(20, 10, 24, 40), 960.0, ["transparencia"])
	_error("ruido fuera de la tolerancia", noisy, {"tolerancia": 0.01}, "no es uniforme")
	_error("esquinas distintas", _picture(Vector2i(32, 32), Color.BLUE, [[Rect2i(16, 0, 16, 32), Color.RED]]), {}, "no es uniforme")
	_error("una imagen de un solo color", _picture(Vector2i(16, 16), Color.BLUE, []), {}, "ningún objeto")
	var result := _shape("invertir con color", Fixtures.images().fondo_uniforme, Rect2i(0, 0, 8, 8), 64.0, ["transparencia", "borde", "hueco"],
		{"invertir": true})
	_check("al invertir, el rectángulo es un hueco", result.get("huecos") == 1)


func _check_formats() -> void:
	var images := Fixtures.images()
	var rgb: Image = images.fondo_uniforme.duplicate()
	rgb.convert(Image.FORMAT_RGB8)
	var result := _shape("formato RGB8", rgb, Rect2i(2, 1, 4, 5), 20.0, ["transparencia"])
	_check("RGB8 usa el color", result.get("fondo") == "color")
	var gray_alpha: Image = images.rectangulo.duplicate()
	gray_alpha.convert(Image.FORMAT_LA8)
	result = _shape("formato LA8", gray_alpha, Rect2i(2, 1, 4, 5), 20.0, [])
	_check("LA8 usa el alfa", result.get("fondo") == "alfa")
	var gray := Image.create_empty(16, 16, false, Image.FORMAT_L8)
	gray.fill(Color(0.1, 0.1, 0.1))
	gray.fill_rect(Rect2i(4, 3, 6, 8), Color.WHITE)
	result = _shape("formato L8", gray, Rect2i(4, 3, 6, 8), 48.0, ["transparencia"])
	_check("L8 usa el color", result.get("fondo") == "color")
	for image: Image in [rgb, gray_alpha, gray]:
		var format := image.get_format()
		var bytes := image.get_data()
		analyzer.analyze(image)
		_check("el original no cambia de formato ni de datos", image.get_format() == format and image.get_data() == bytes)


func _check_sizes() -> void:
	_error("más de 4096 px", Image.create_empty(4097, 2, false, Image.FORMAT_RGBA8), {}, "4096")
	var large := _picture(Vector2i(2048, 2048), CLEAR, [[Rect2i(400, 300, 1000, 1400), Color.WHITE]])
	var bytes := large.get_data()
	var result := _shape("2048 px se reduce en proporción", large, Rect2i(200, 150, 500, 700), 350000.0, ["reducido"])
	_check("la copia de trabajo mide 1024 px", result.get("tamano") == Vector2i(1024, 1024))
	_check("la imagen grande no cambia", large.get_size() == Vector2i(2048, 2048) and large.get_data() == bytes)
	var wide := _picture(Vector2i(3000, 1000), CLEAR, [[Rect2i(300, 200, 2400, 600), Color.WHITE]])
	result = analyzer.analyze(wide)
	_check("una imagen apaisada conserva la proporción", result.get("tamano") == Vector2i(1024, 341), str(result.get("tamano")))
	_check("con aviso de reducción", _has(result.get("avisos", []), "reducido"))
	var start := Time.get_ticks_usec()
	analyzer.analyze(_picture(Vector2i(1024, 1024), DARK, [[Rect2i(300, 100, 400, 800), LIGHT]]))
	print("MEDIDA analizar 1024 × 1024 con fondo de color: %.0f ms" % ((Time.get_ticks_usec() - start) / 1000.0))


func _check_contract() -> void:
	_error("imagen nula", null, {}, "vacía")
	_error("imagen sin datos", Image.new(), {}, "vacía")
	var image: Image = Fixtures.images().rectangulo
	for options: Dictionary in [{"otra": 1}, {"umbral_alfa": -0.1}, {"umbral_alfa": 1.1}, {"tolerancia": NAN}, {"tolerancia": INF},
			{"tolerancia": "0.2"}, {"simplificacion": -1}, {"simplificacion": 4.5}, {"simplificacion": true}, {"invertir": 1}]:
		_error("opción inválida " + str(options), image, options, str(options.keys()[0]))
	var options := {"tolerancia": 0.2, "simplificacion": 2}
	var first: Dictionary = analyzer.analyze(image, options)
	_check("dos análisis son idénticos", first == analyzer.analyze(image, options) and first.error == "")
	_check("no cambia las opciones recibidas", options == {"tolerancia": 0.2, "simplificacion": 2})


func _check_simplification() -> void:
	var crossing := _alpha(128, CROSSING)
	var exact: Dictionary = analyzer.analyze(crossing, {"simplificacion": 0.0})
	var fallback: Dictionary = analyzer.analyze(crossing, {"simplificacion": 2.0})
	_check("si simplificar lo cruza, vuelve al exacto", fallback.error == "" and fallback.contorno == exact.contorno
		and _has(fallback.avisos, "cruzaba"))
	var blade := _picture(Vector2i(128, 128), CLEAR, [])
	for y in range(8, 120):
		var half := int((y - 8) * 0.2) + 2
		blade.fill_rect(Rect2i(64 - half, y, half * 2, 1), Color.WHITE)
	var ragged := _alpha(128, [Rect2i(20, 20, 60, 6), Rect2i(40, 20, 3, 80), Rect2i(40, 90, 50, 2), Rect2i(70, 60, 2, 40)])
	for picture: Image in [crossing, blade, ragged]:
		for amount: float in [0.0, 1.0, 2.0, 3.0, 4.0]:
			var result: Dictionary = analyzer.analyze(picture, {"simplificacion": amount})
			_check("contorno válido con %s px" % amount, result.error == "" and _valid(result.contorno, result.tamano), result.error)
	var coarse: Dictionary = analyzer.analyze(blade, {"simplificacion": 2.0})
	var fine: Dictionary = analyzer.analyze(blade, {"simplificacion": 0.0})
	_check("simplificar quita vértices", coarse.contorno.size() < fine.contorno.size(), "%d < %d" % [coarse.contorno.size(), fine.contorno.size()])
	var stairs := Image.create_empty(1024, 1024, false, Image.FORMAT_RGBA8)
	for y in 1024:
		stairs.fill_rect(Rect2i(0, y, y + 1, 1), Color.WHITE)
	_error("demasiados vértices", stairs, {"simplificacion": 0.0}, "demasiado detallado")
	var simple: Dictionary = analyzer.analyze(stairs)
	_check("simplificando entra en el límite", simple.error == "" and simple.contorno.size() <= 1000 and _valid(simple.contorno, simple.tamano))


func _noisy_background() -> Image:
	var image := _picture(Vector2i(64, 64), DARK, [])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in 64:
		for x in 64:
			var noise := rng.randi_range(-10, 10)
			image.set_pixel(x, y, Color8(30 + noise, 32 + noise, 40 + noise))
	image.set_pixel(0, 0, Color8(22, 24, 32))
	image.set_pixel(63, 63, Color8(38, 40, 48))
	image.fill_rect(Rect2i(20, 10, 24, 40), LIGHT)
	return image


func _alpha(side: int, solid: Array, clear := [], over := []) -> Image:
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	for rect: Rect2i in solid:
		image.fill_rect(rect, Color.WHITE)
	for rect: Rect2i in clear:
		image.fill_rect(rect, CLEAR)
	for rect: Rect2i in over:
		image.fill_rect(rect, Color.WHITE)
	return image


func _picture(size: Vector2i, background: Color, paint: Array) -> Image:
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(background)
	for item: Array in paint:
		image.fill_rect(item[0], item[1])
	return image


## Comprueba caja, área, validez y exactamente los avisos esperados.
func _shape(label: String, image: Image, box: Rect2i, area: float, warnings: Array, options := {}) -> Dictionary:
	var result: Dictionary = analyzer.analyze(image, options)
	_check(label + ": sin error", result.error == "", result.error)
	if result.error != "":
		return result
	var contour: PackedVector2Array = result.contorno
	_check(label + ": caja", _bounds(contour) == Rect2(box), str(_bounds(contour)))
	_check(label + ": área", is_equal_approx(_area(contour), area), str(_area(contour)))
	_check(label + ": contorno válido", _valid(contour, result.tamano))
	var matched: bool = result.avisos.size() == warnings.size()
	for text: String in warnings:
		matched = matched and _has(result.avisos, text)
	_check(label + ": avisos", matched, str(result.avisos))
	return result


func _error(label: String, image: Image, options: Dictionary, text: String) -> void:
	var result: Dictionary = analyzer.analyze(image, options)
	_check(label, result.size() == 1 and str(result.get("error", "")).contains(text), str(result.get("error", "")))


func _has(warnings: Variant, text: String) -> bool:
	for warning: String in warnings:
		if warning.contains(text):
			return true
	return false


func _bounds(polygon: PackedVector2Array) -> Rect2:
	var box := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		box = box.expand(point)
	return box


func _area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) / 2.0


func _valid(contour: PackedVector2Array, size: Vector2i) -> bool:
	if contour.size() < 3 or not Geometry2D.is_polygon_clockwise(contour):
		return false
	for point in contour:
		if point.x < 0 or point.y < 0 or point.x > size.x or point.y > size.y:
			return false
	return _is_simple(contour) and not Geometry2D.triangulate_polygon(contour).is_empty()


## Comprobación propia, exacta en coordenadas enteras: incluye toques y solapes colineales.
func _is_simple(polygon: PackedVector2Array) -> bool:
	var n := polygon.size()
	for i in n:
		var a := polygon[i]
		var b := polygon[(i + 1) % n]
		for j in range(i + 1, n):
			var c := polygon[j]
			var d := polygon[(j + 1) % n]
			if j == i + 1:
				if (a - b).cross(d - b) == 0.0 and (a - b).dot(d - b) > 0.0:
					return false
			elif i == 0 and j == n - 1:
				if (b - a).cross(c - a) == 0.0 and (b - a).dot(c - a) > 0.0:
					return false
			elif _segments_touch(a, b, c, d):
				return false
	return true


func _segments_touch(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var side_c := signf((b - a).cross(c - a))
	var side_d := signf((b - a).cross(d - a))
	var side_a := signf((d - c).cross(a - c))
	var side_b := signf((d - c).cross(b - c))
	if side_c * side_d < 0 and side_a * side_b < 0:
		return true
	return (side_c == 0 and _on_segment(a, b, c)) or (side_d == 0 and _on_segment(a, b, d)) \
		or (side_a == 0 and _on_segment(c, d, a)) or (side_b == 0 and _on_segment(c, d, b))


func _on_segment(a: Vector2, b: Vector2, point: Vector2) -> bool:
	return point.x >= minf(a.x, b.x) and point.x <= maxf(a.x, b.x) and point.y >= minf(a.y, b.y) and point.y <= maxf(a.y, b.y)


func _check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail if not ok else "")
	if not ok:
		failures += 1
