class_name SkinPaint
extends RefCounted
## Paso SH.8c: pinta la piel del .glb con el rubor, los labios y las pecas de toon_soft (SH.8 y SH.8b), para que se vean
## en un juego sin nuestro shader. Mismas fórmulas y constantes que toon_soft.gdshader (probar_pintar_piel.gd lo vigila).
##
## Uso (en cualquier hilo; solo Image y números):
##   var image := SkinPaint.skin_image(2048, skin_color, zones_image, {"blush_amount": 0.35, "lips_amount": 0.45, "freckles": 3})
## zones_image: piel.png (RGBA8; R rubor, G cercanía para las pecas, B labios). Devuelve RGB8 en sRGB, del tamaño pedido,
## con todo color piel; GarmentTexture pone la prenda encima.

const FRECKLE_CELLS := 240.0  # = toon_soft
const FRECKLE_FIRST := 0.035
const FRECKLE_OPACITY := 0.6
const BLUSH := [0.97, 12.0, 1.45, 0.96]  # tint_of(color, hue, turn_degrees, saturation, value), = toon_soft
const LIPS := [0.98, 14.0, 1.6, 0.85]
const FRECKLE := [0.07, 10.0, 1.35, 0.72]
const MIN_AMOUNT := 0.002  # por debajo, el píxel se deja como está


static func skin_image(size: int, skin: Color, zones: Image, params: Dictionary) -> Image:
	var data := PackedByteArray()
	data.resize(size * size * 3)
	var base := [skin.r8, skin.g8, skin.b8]
	for i in size * size:
		data[3 * i] = base[0]
		data[3 * i + 1] = base[1]
		data[3 * i + 2] = base[2]
	var source := zones.duplicate() as Image
	source.clear_mipmaps()
	source.convert(Image.FORMAT_RGBA8)
	var blush: float = params.get("blush_amount", 0.0)
	var lips: float = params.get("lips_amount", 0.0)
	var freckles: float = params.get("freckles", 0.0)
	var linear := skin.srgb_to_linear()
	if blush > 0.0 or lips > 0.0:
		_paint_blush(data, size, linear, source, blush, lips)
	if freckles >= 0.5:
		_paint_freckles(data, size, source, freckles)
	return Image.create_from_data(size, size, false, Image.FORMAT_RGB8, data)


## Rubor y labios: cada píxel de piel.png cubre (size / su ancho)² píxeles de la imagen.
static func _paint_blush(data: PackedByteArray, size: int, linear: Color, zones: Image, blush: float, lips: float) -> void:
	var width := zones.get_width()
	var bytes := zones.get_data()
	var step := float(size) / width
	var blush_color := tint_of(linear, BLUSH)
	var lips_color := tint_of(linear, LIPS)
	for zy in zones.get_height():
		for zx in width:
			var k := 4 * (zy * width + zx)
			var r := bytes[k] / 255.0 * blush
			var b := bytes[k + 2] / 255.0 * lips
			if r < MIN_AMOUNT and b < MIN_AMOUNT:
				continue
			var color := linear.lerp(blush_color, r)
			color = color.lerp(tint_of(color, LIPS), b) if b >= MIN_AMOUNT else color
			var out := color.linear_to_srgb()
			for y in range(int(zy * step), int((zy + 1) * step)):
				for x in range(int(zx * step), int((zx + 1) * step)):
					var i := 3 * (y * size + x)
					data[i] = out.r8
					data[i + 1] = out.g8
					data[i + 2] = out.b8


## Pecas: celda a celda (FRECKLE_CELLS por unidad de UV), como freckle_cover de toon_soft.
static func _paint_freckles(data: PackedByteArray, size: int, zones: Image, level: float) -> void:
	var reach := FRECKLE_FIRST * pow(1.0 / FRECKLE_FIRST, (level - 1.0) / 9.0)
	var pixels_per_cell := size / FRECKLE_CELLS
	for cy in int(FRECKLE_CELLS):
		for cx in int(FRECKLE_CELLS):
			var h := hash3(Vector2(cx, cy))
			var center := (Vector2(cx, cy) + Vector2(0.2, 0.2) + 0.6 * Vector2(h.x, h.y)) / FRECKLE_CELLS
			var near := zones.get_pixelv(Vector2i((center * zones.get_width()).floor()).clamp(Vector2i.ZERO,
				zones.get_size() - Vector2i.ONE)).g
			if near <= 0.0:
				continue
			var order := (1.0 - near) * (1.0 - near)
			var zone := 1.0 - smoothstep(reach * 0.7, reach, order)
			var density := lerpf(0.35, 0.12, clampf(order / reach, 0.0, 1.0)) * lerpf(0.5, 1.0, (level - 1.0) / 9.0)
			if zone <= 0.0 or h.z >= density:
				continue
			var radius := lerpf(0.14, 0.28, fposmod(h.z * 17.0, 1.0)) * pixels_per_cell
			var opacity := lerpf(0.5, 1.0, fposmod(h.x * 7.0, 1.0)) * zone * FRECKLE_OPACITY
			var middle := center * size
			for y in range(int(middle.y - radius - 1.0), int(middle.y + radius + 2.0)):
				for x in range(int(middle.x - radius - 1.0), int(middle.x + radius + 2.0)):
					if x < 0 or y < 0 or x >= size or y >= size:
						continue
					var cover := (1.0 - smoothstep(radius - 0.5, radius + 0.5, Vector2(x + 0.5, y + 0.5).distance_to(middle))) * opacity
					if cover <= 0.0:
						continue
					var i := 3 * (y * size + x)
					var here := Color8(data[i], data[i + 1], data[i + 2]).srgb_to_linear()
					var out := here.lerp(tint_of(here, FRECKLE), cover).linear_to_srgb()
					data[i] = out.r8
					data[i + 1] = out.g8
					data[i + 2] = out.b8


## tint_of de toon_soft: color lineal; tint = [matiz objetivo (vueltas), giro máximo (grados), saturación ×, valor ×].
static func tint_of(linear: Color, tint: Array) -> Color:
	var srgb := Color(clampf(linear.r, 0, 1), clampf(linear.g, 0, 1), clampf(linear.b, 0, 1)).linear_to_srgb()
	var hue := srgb.h
	var to_hue := fposmod(tint[0] - hue + 0.5, 1.0) - 0.5
	var limit: float = tint[1] / 360.0
	var turn := clampf(to_hue, -limit, limit) * minf(srgb.s * 4.0, 1.0)
	return Color.from_hsv(fposmod(hue + turn, 1.0), minf(srgb.s * tint[2], 1.0), srgb.v * tint[3]).srgb_to_linear()


## hash3 de toon_soft.
static func hash3(p: Vector2) -> Vector3:
	var q := Vector3(fposmod(p.x * 0.1031, 1.0), fposmod(p.y * 0.1030, 1.0), fposmod(p.x * 0.0973, 1.0))
	var d := q.dot(Vector3(q.y, q.x, q.z) + Vector3(33.33, 33.33, 33.33))
	q += Vector3(d, d, d)
	return Vector3(fposmod((q.x + q.y) * q.z, 1.0), fposmod((q.x + q.z) * q.y, 1.0), fposmod((q.y + q.z) * q.x, 1.0))
