class_name SkinHide
extends RefCounted
## Paso 12.1b: une las máscaras de piel oculta de las piezas puestas (PNG RGBA sobre las UV del cuerpo; A = oculta).
## Sin interfaz. La unión mezcla «encima» con blend_rect (A = 1 − (1 − a₁)(1 − a₂), comprobado en Godot 4.7.2).
## Uso:
##   var mask := SkinHide.union([library.hide_image("makehuman", "cortu_jeans_shorts"), …])  # null si no hay ninguna
##   BodyMaterial.set_hide_mask(species.mesh, mask)
##   var hidden := SkinHide.hidden_vertices(species.mesh, mask)  # 1 por vértice oculto (prueba y 12.5)


## Las máscaras unidas en una textura (sin mipmaps: el shader la lee con filter_nearest); null si no hay ninguna.
## Sale del tamaño de la primera; las de otro tamaño (un pack de usuario) se reescalan al más cercano, en una copia.
static func union(images: Array[Image]) -> ImageTexture:
	var result: Image = null
	for image in images:
		if image == null:
			continue
		if result == null:
			result = Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
			result.fill(Color(0, 0, 0, 0))
		var mask := image
		if mask.get_size() != result.get_size():
			mask = image.duplicate()
			mask.resize(result.get_width(), result.get_height(), Image.INTERPOLATE_NEAREST)
		result.blend_rect(mask, Rect2i(Vector2i.ZERO, mask.get_size()), Vector2i.ZERO)
	return null if result == null else ImageTexture.create_from_image(result)


## 1 en los vértices de `mesh` (superficie 0) cuya UV cae en un píxel con A > 0,5 (lo mismo que descarta el shader).
static func hidden_vertices(mesh: MeshInstance3D, mask: Texture2D) -> PackedByteArray:
	var uvs: PackedVector2Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var hidden := PackedByteArray()
	hidden.resize(uvs.size())
	hidden.fill(0)
	if mask == null:
		return hidden
	var image := mask.get_image()
	var size := image.get_size()
	for i in uvs.size():
		var x := clampi(int(uvs[i].x * size.x), 0, size.x - 1)
		var y := clampi(int(uvs[i].y * size.y), 0, size.y - 1)
		hidden[i] = 1 if image.get_pixel(x, y).a > 0.5 else 0
	return hidden
