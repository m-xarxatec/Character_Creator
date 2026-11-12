class_name GarmentTexture
extends RefCounted
## Hornea la prenda base en una textura con las UV de la malla, para verla fuera del editor (paso 3.6.6).
##
## Uso:
##   var image := GarmentTexture.bake(array_mesh, 2048, skin_color, garment_color)
## Cada píxel dentro de un triángulo interpola el color `garment` (rojo) y corta en 0,5, como toon.gdshader.
## Fuera de los triángulos: color piel, y la prenda se alarga PADDING píxeles para que no salgan rayas en las costuras UV.
## Todo en CPU: vale sin tarjeta gráfica y con --headless.

const PADDING := 8

enum { EMPTY, SKIN, GARMENT }


static func bake(mesh: Mesh, size: int, skin: Color, garment: Color) -> Image:
	var arrays := mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var labels := PackedByteArray()
	labels.resize(size * size)
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		_fill_triangle(labels, size, uvs[a] * size, uvs[b] * size, uvs[c] * size, colors[a].r, colors[b].r, colors[c].r)
	_pad_garment(labels, size)
	return _to_image(labels, size, skin, garment)


## Marca los píxeles cuyo centro cae dentro del triángulo (coordenadas en píxeles).
static func _fill_triangle(labels: PackedByteArray, size: int, a: Vector2, b: Vector2, c: Vector2,
		ga: float, gb: float, gc: float) -> void:
	var area := (b - a).cross(c - a)
	if absf(area) < 1e-12:
		return
	var low := a.min(b).min(c).floor()
	var high := a.max(b).max(c).ceil()
	var all_skin := ga < 0.5 and gb < 0.5 and gc < 0.5
	for y in range(maxi(0, int(low.y)), mini(size, int(high.y) + 1)):
		for x in range(maxi(0, int(low.x)), mini(size, int(high.x) + 1)):
			var p := Vector2(x + 0.5, y + 0.5)
			var wa := (b - p).cross(c - p) / area
			var wb := (c - p).cross(a - p) / area
			var wc := 1.0 - wa - wb
			if wa < -1e-6 or wb < -1e-6 or wc < -1e-6:
				continue
			var value := SKIN if all_skin or wa * ga + wb * gb + wc * gc < 0.5 else GARMENT
			labels[y * size + x] = value


## Alarga la prenda sobre los píxeles vacíos, para que el filtrado de la textura no mezcle piel en sus costuras.
static func _pad_garment(labels: PackedByteArray, size: int) -> void:
	var front: Array[int] = []
	for i in labels.size():
		if labels[i] == GARMENT:
			front.append(i)
	for step in PADDING:
		var next: Array[int] = []
		for i in front:
			var x := i % size
			for j: int in [i - 1 if x > 0 else -1, i + 1 if x < size - 1 else -1, i - size, i + size]:
				if j >= 0 and j < labels.size() and labels[j] == EMPTY:
					labels[j] = GARMENT
					next.append(j)
		front = next


static func _to_image(labels: PackedByteArray, size: int, skin: Color, garment: Color) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	image.fill(skin)
	for i in labels.size():
		if labels[i] == GARMENT:
			image.set_pixel(i % size, i / size, garment)
	return image
