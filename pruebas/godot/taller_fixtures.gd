extends RefCounted
## TA.1b — Siluetas e imágenes de referencia del Taller, construidas en memoria.
## Uso: TallerFixtures.polygons() y TallerFixtures.images().


static func polygons() -> Dictionary:
	return {
		"cuadrado": PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(2, 2), Vector2(0, 2)]),
		"ele": PackedVector2Array([Vector2(0, 0), Vector2(3, 0), Vector2(3, 1),
			Vector2(1, 1), Vector2(1, 3), Vector2(0, 3)]),
	}


static func images() -> Dictionary:
	return {
		"rectangulo": _image(Color.TRANSPARENT, Rect2i(2, 1, 4, 5)),
		"vacia": _image(Color.TRANSPARENT, Rect2i()),
		"borde": _image(Color.TRANSPARENT, Rect2i(0, 3, 3, 2)),
		"fondo_uniforme": _image(Color.BLUE, Rect2i(2, 1, 4, 5)),
	}


static func _image(background: Color, rect: Rect2i) -> Image:
	var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(background)
	if rect.has_area():
		image.fill_rect(rect, Color.WHITE)
	return image
