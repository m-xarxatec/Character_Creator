extends RefCounted
## TA.4a: saca de una imagen sencilla el contorno de su objeto principal y avisa de lo que ese contorno no representa.
## El contorno va en píxeles de la copia de trabajo, con origen arriba a la izquierda e Y hacia abajo.
## Uso: ImageMask.analyze(image, {"tolerancia": 0.2})  # {error, contorno, tamano, fondo, islas, huecos, avisos} o {error}

const DEFAULTS := {"umbral_alfa": 0.5, "tolerancia": 0.1, "simplificacion": 1.0, "invertir": false}
const RANGES := {"umbral_alfa": [0.0, 1.0], "tolerancia": [0.0, 1.0], "simplificacion": [0.0, 4.0]}
const MAX_SOURCE_SIDE := 4096  # PROVISIONAL: 64 MB en RGBA8
const WORK_SIDE := 1024  # PROVISIONAL
const MIN_AREA := 4.0  # PROVISIONAL, en px²
const MAX_VERTICES := 1000  # PROVISIONAL: unos 4000 triángulos en la malla


static func analyze(image: Image, options := {}) -> Dictionary:
	var settings := _settings(options)
	if settings.has("error"):
		return settings
	if image == null or image.is_empty():
		return {"error": "La imagen está vacía o no se pudo leer."}
	if maxi(image.get_width(), image.get_height()) > MAX_SOURCE_SIDE:
		return {"error": "La imagen mide más de %d px por lado." % MAX_SOURCE_SIDE}
	var warnings := PackedStringArray()
	var work := _working_copy(image, warnings)
	if work.get_format() != Image.FORMAT_RGBA8:
		return {"error": "No se pudo leer el formato de la imagen."}
	var data := work.get_data()
	var limit := floori(settings.umbral_alfa * 255.0)
	var uses_alpha := work.detect_alpha() != Image.ALPHA_NONE and _has_transparency(data, limit)
	var key := PackedInt32Array()  # color del fondo; vacío si manda el alfa
	if not uses_alpha:
		limit = floori(settings.tolerancia * 255.0)
		key = _background_color(data, work.get_size(), limit)
		if key.is_empty():
			return {"error": "El fondo no es uniforme: usa un PNG con transparencia o sube la tolerancia."}
		warnings.append("La imagen no tiene transparencia: el fondo se ha tomado del color de sus esquinas.")
	var masks := _masks(data, work.get_size(), key, limit, settings.invertir)
	var result := _find_contour(masks[0], masks[1], work.get_size(), settings.simplificacion, warnings)
	if result.error == "":
		result.tamano = work.get_size()
		result.fondo = "alfa" if uses_alpha else "color"
		result.avisos = warnings
	return result


static func _settings(options: Dictionary) -> Dictionary:
	var settings := DEFAULTS.duplicate()
	for key in options:
		if not DEFAULTS.has(key):
			return {"error": "Opción desconocida '%s'" % str(key)}
		var value: Variant = options[key]
		if key == "invertir":
			if not value is bool:
				return {"error": "invertir debe ser verdadero o falso"}
		elif typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(value) \
				or value < RANGES[key][0] or value > RANGES[key][1]:
			return {"error": "%s fuera de rango" % key}
		settings[key] = value
	return settings


## Copia en RGBA8 y con el lado mayor limitado. El original no cambia.
static func _working_copy(image: Image, warnings: PackedStringArray) -> Image:
	var work: Image = image.duplicate()
	if work.is_compressed():
		work.decompress()
	work.clear_mipmaps()
	work.convert(Image.FORMAT_RGBA8)
	var side := maxi(work.get_width(), work.get_height())
	if side > WORK_SIDE:
		var factor := float(WORK_SIDE) / side
		work.resize(maxi(roundi(work.get_width() * factor), 1), maxi(roundi(work.get_height() * factor), 1),
			Image.INTERPOLATE_BILINEAR)
		warnings.append("La imagen se ha reducido a %d × %d px para procesarla." % [work.get_width(), work.get_height()])
	return work


## Un alfa que no baja del umbral no separa nada: esa imagen sigue el camino del color.
static func _has_transparency(data: PackedByteArray, limit: int) -> bool:
	for i in range(3, data.size(), 4):
		if data[i] <= limit:
			return true
	return false


## Media RGB de las cuatro esquinas, o vacío si alguna se aleja más que el límite.
static func _background_color(data: PackedByteArray, size: Vector2i, limit: int) -> PackedInt32Array:
	var corners := [0, (size.x - 1) * 4, (size.y - 1) * size.x * 4, (size.x * size.y - 1) * 4]
	var key := PackedInt32Array([0, 0, 0])
	for at: int in corners:
		for channel in 3:
			key[channel] += data[at + channel]
	for channel in 3:
		key[channel] = roundi(key[channel] / 4.0)
	for at: int in corners:
		for channel in 3:
			if absi(data[at + channel] - key[channel]) > limit:
				return PackedInt32Array()
	return key


## [sólido, complemento], llenados en una sola pasada.
static func _masks(data: PackedByteArray, size: Vector2i, key: PackedInt32Array, limit: int, invert: bool) -> Array[BitMap]:
	var count := size.x * size.y
	var solid := PackedByteArray()
	solid.resize(count * 2)
	solid.fill(0)
	var inverse := solid.duplicate()
	var uses_alpha := key.is_empty()
	var red := 0 if uses_alpha else key[0]
	var green := 0 if uses_alpha else key[1]
	var blue := 0 if uses_alpha else key[2]
	for i in count:
		var at := i * 4
		var on: bool
		if uses_alpha:
			on = data[at + 3] > limit
		else:
			on = absi(data[at] - red) > limit or absi(data[at + 1] - green) > limit or absi(data[at + 2] - blue) > limit
		if on != invert:
			solid[i * 2 + 1] = 255
		else:
			inverse[i * 2 + 1] = 255
	return [_bitmap(solid, size), _bitmap(inverse, size)]


static func _bitmap(bytes: PackedByteArray, size: Vector2i) -> BitMap:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(Image.create_from_data(size.x, size.y, false, Image.FORMAT_LA8, bytes), 0.5)
	return bitmap


static func _find_contour(solid: BitMap, inverse: BitMap, size: Vector2i, simplification: float,
		warnings: PackedStringArray) -> Dictionary:
	var rect := Rect2i(Vector2i.ZERO, size)
	var islands := solid.opaque_to_polygons(rect, 0.0)
	if islands.is_empty():
		return {"error": "La imagen no contiene ningún objeto."}
	var index := _largest(islands)
	var main := islands[index]
	if absf(_area(main)) < MIN_AREA:
		return {"error": "El objeto es demasiado pequeño."}
	if islands.size() > 1:
		warnings.append("Hay %d piezas separadas: se usa solo la mayor." % islands.size())
	if _touches_border(main, size):
		warnings.append("El objeto toca el borde de la imagen: puede estar recortado.")
	var holes := _count_holes(inverse, rect, main)
	if holes > 0:
		warnings.append("El objeto tiene %d hueco(s): se rellenan porque aún no se admiten agujeros." % holes)
	var contour := _simplified(solid, rect, simplification, islands, index, warnings)
	if contour.size() > MAX_VERTICES:
		return {"error": "Contorno demasiado detallado (%d puntos; máximo %d): prueba otra simplificación."
			% [contour.size(), MAX_VERTICES]}
	if contour.is_empty():
		return {"error": "No se pudo obtener un contorno válido."}
	return {"error": "", "contorno": contour, "islas": islands.size(), "huecos": holes}


## El contorno simplificado o, si simplificar lo estropea, el exacto. Vacío si tampoco el exacto sirve.
static func _simplified(solid: BitMap, rect: Rect2i, simplification: float, islands: Array[PackedVector2Array], index: int,
		warnings: PackedStringArray) -> PackedVector2Array:
	var reduced := solid.opaque_to_polygons(rect, simplification)
	if reduced.size() == islands.size() and (reduced[index].size() > MAX_VERTICES or _is_usable(reduced[index])):
		return reduced[index]
	warnings.append("Simplificar cruzaba el contorno: se usa el contorno exacto.")
	if islands[index].size() > MAX_VERTICES or _is_usable(islands[index]):
		return islands[index]
	return PackedVector2Array()


static func _largest(polygons: Array[PackedVector2Array]) -> int:
	var best := 0
	var best_area := -1.0
	for i in polygons.size():
		var area := absf(_area(polygons[i]))
		if area > best_area:
			best = i
			best_area = area
	return best


static func _area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		total += a.x * b.y - b.x * a.y
	return total / 2.0


static func _touches_border(polygon: PackedVector2Array, size: Vector2i) -> bool:
	for point in polygon:
		if point.x <= 0.0 or point.y <= 0.0 or point.x >= size.x or point.y >= size.y:
			return true
	return false


## Regiones de fondo encerradas por el objeto principal.
static func _count_holes(inverse: BitMap, rect: Rect2i, main: PackedVector2Array) -> int:
	var holes := 0
	for region: PackedVector2Array in inverse.opaque_to_polygons(rect, 0.0):
		if not _touches_border(region, rect.size) and Geometry2D.is_point_in_polygon(_inner_point(region), main):
			holes += 1
	return holes


## Centro del píxel de arriba a la izquierda de la región: siempre es parte de ella.
static func _inner_point(region: PackedVector2Array) -> Vector2:
	var corner := region[0]
	for point in region:
		if point.y < corner.y or (point.y == corner.y and point.x < corner.x):
			corner = point
	return corner + Vector2(0.5, 0.5)


static func _is_usable(polygon: PackedVector2Array) -> bool:
	return polygon.size() >= 3 and _area(polygon) != 0.0 and _is_simple(polygon) \
		and not Geometry2D.triangulate_polygon(polygon).is_empty()


## Sin aristas que vuelvan sobre sí mismas ni que se toquen. La API no ve los solapes colineales: por eso lo primero.
static func _is_simple(polygon: PackedVector2Array) -> bool:
	var n := polygon.size()
	for i in n:
		var a := polygon[i]
		var b := polygon[(i + 1) % n]
		var c := polygon[(i + 2) % n]
		if (b - a).cross(c - b) == 0.0 and (b - a).dot(c - b) <= 0.0:
			return false
		for j in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue
			if Geometry2D.segment_intersects_segment(a, b, polygon[j], polygon[(j + 1) % n]) != null:
				return false
	return true
