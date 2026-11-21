class_name EyePiece
extends RefCounted
## Paso 9.4: ojos anime sin assets. Dos parches de la piel de la cara (uno por ojo; BodyDerived.subset: siguen a todas
## las formas, también a la cara anime) con coordenadas de ojo en UV (0,5; 0,5 = el centro; la x va hacia fuera de la
## cara en los dos lados) y un dibujo pintado por código (paint): pestañas, iris con degradado, pupila y brillo.
## Los centros salen de la caja de los vértices de la cabeza (fracciones; no números de la humana) y del punto de la
## piel más adelantado allí.
## Uso:
##   var eyes := EyePiece.build(species.mesh, species.skeleton)   # MeshInstance3D suelta, o null
##   EyePiece.set_iris(eyes, Color(0.2, 0.45, 0.8))               # material con el dibujo (y el color del iris)
## Al exportar, el dibujo va como textura (meta "textura"; glb_exporter.gd).

const BodyDerived := preload("body_derived.gd")
const SHADER := preload("eye.gdshader")
const SIZE := 128  # px del dibujo
const CENTER := Vector2(0.38, 0.518)  # centro del ojo en la caja de la cabeza: x hacia el borde, y desde abajo
const RADIUS := Vector2(0.27, 0.068)  # medio ancho (fracción del medio ancho) y medio alto (fracción del alto)
const MARGIN := 1.35  # el parche es algo mayor que el ojo
const DEPTH := 0.02  # metros por detrás del centro que aún entran (deja fuera el interior de la cuenca)


static func build(body: MeshInstance3D, skeleton: Skeleton3D) -> MeshInstance3D:
	var arrays := body.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var head := BodyDerived.mask(arrays, body.skin, skeleton, {"huesos": ["Head"], "peso": 0.5, "zonas": []})
	var box := AABB()
	var found := false
	for i in vertices.size():
		if head[i]:
			box = box.expand(vertices[i]) if found else AABB(vertices[i], Vector3.ZERO)
			found = true
	if not found:
		return null
	var half := Vector2(box.size.x * 0.5 * RADIUS.x, box.size.y * RADIUS.y)  # radios del ojo, en metros
	var centers: Array[Vector3] = []
	for side in [1.0, -1.0]:
		var target := Vector2(box.get_center().x + side * CENTER.x * box.size.x * 0.5, box.position.y + CENTER.y * box.size.y)
		var best := Vector3(target.x, target.y, -INF)
		for i in vertices.size():
			if head[i] and absf(vertices[i].x - target.x) < half.y and absf(vertices[i].y - target.y) < half.y \
					and vertices[i].z > best.z:
				best = Vector3(target.x, target.y, vertices[i].z)
		centers.append(best)
	var keep := PackedByteArray()
	keep.resize(vertices.size())
	for i in vertices.size():
		if head[i]:
			for c in centers:
				var d := Vector2((vertices[i].x - c.x) / half.x, (vertices[i].y - c.y) / half.y) / MARGIN
				if d.length() <= 1.0 and vertices[i].z > c.z - DEPTH:
					keep[i] = 1
	var piece := BodyDerived.subset(body, keep, 0.0)
	if piece == null:
		return null
	piece.name = "Ojos"
	_set_uvs(piece, centers, half)
	return piece


## UV de cada vértice del parche: el ojo de su lado, con la x hacia fuera de la cara.
static func _set_uvs(piece: MeshInstance3D, centers: Array[Vector3], half: Vector2) -> void:
	var mesh := piece.mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var shapes := mesh.surface_get_blend_shape_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs := PackedVector2Array()
	for p in vertices:
		var c: Vector3 = centers[0] if p.x * centers[0].x >= 0.0 else centers[1]
		var out := signf(c.x) if c.x != 0.0 else 1.0
		uvs.append(Vector2(0.5 + 0.5 * out * (p.x - c.x) / (half.x * MARGIN), 0.5 - 0.5 * (p.y - c.y) / (half.y * MARGIN)))
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var names: Array[StringName] = []
	for s in mesh.get_blend_shape_count():
		names.append(mesh.get_blend_shape_name(s))
	var rebuilt := ArrayMesh.new()
	rebuilt.blend_shape_mode = mesh.blend_shape_mode
	for shape_name in names:
		rebuilt.add_blend_shape(shape_name)
	rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
	piece.mesh = rebuilt


## Pone el material con el dibujo del ojo (iris de ese color). Guarda la imagen en la meta "textura" para exportar.
static func set_iris(piece: MeshInstance3D, iris: Color) -> void:
	var texture := ImageTexture.create_from_image(paint(iris))
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("eye_texture", texture)
	material.set_meta("iris", iris)
	piece.material_override = material
	piece.set_meta("textura", texture)


static func get_iris(piece: MeshInstance3D) -> Color:
	var material := piece.material_override
	return material.get_meta("iris") if material != null and material.has_meta("iris") else Color(0.25, 0.45, 0.8)


## El dibujo del ojo (SIZE × SIZE, alfa 0 fuera de su forma). x hacia fuera de la cara; y hacia abajo.
static func paint(iris: Color) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var lash := Color(0.08, 0.06, 0.07)
	var white := Color(0.97, 0.97, 0.98)
	for py in SIZE:
		for px in SIZE:
			var p := Vector2((px + 0.5) / SIZE * 2.0 - 1.0, (py + 0.5) / SIZE * 2.0 - 1.0) * MARGIN  # ±1 = el ojo
			image.set_pixel(px, py, _eye_color(p, iris, lash, white))
	return image


## Color del ojo en p (x: −1 dentro … 1 fuera; y: −1 arriba … 1 abajo).
static func _eye_color(p: Vector2, iris: Color, lash: Color, white: Color) -> Color:
	var top := -0.95 + 0.35 * p.x * p.x  # párpado de arriba: arco
	var bottom := 0.9 - 0.2 * p.x * p.x  # párpado de abajo, más plano
	var outer_tail := p.x > 0.75 and p.y < top + 0.25 and p.y > top - 0.35 + (p.x - 0.75) * 0.8  # rabillo hacia fuera
	if absf(p.x) > 1.0 and not outer_tail:
		return Color(0, 0, 0, 0)
	if (p.y >= top - 0.22 and p.y < top + 0.08) or outer_tail:
		return lash  # pestañas de arriba, gruesas
	if p.y < top or p.y > bottom:
		return Color(0, 0, 0, 0)
	if p.y > bottom - 0.08:
		return lash.lerp(white, 0.4)  # línea fina abajo
	var center := Vector2(-0.05, 0.05)
	var q := (p - center) / Vector2(0.58, 0.78)  # iris: óvalo vertical
	var d := q.length()
	if Vector2(p.x - 0.18, p.y + 0.38).length() < 0.16:
		return white  # brillo grande
	if Vector2(p.x + 0.25, p.y - 0.42).length() < 0.07:
		return white  # brillo pequeño
	if d < 0.32:
		return lash  # pupila
	if d < 1.0:
		var shade := clampf((p.y - center.y + 0.7) / 1.4, 0.0, 1.0)  # más oscuro arriba, más claro abajo
		var color := iris.darkened(0.45).lerp(iris.lightened(0.25), shade)
		return color.darkened(0.35) if d > 0.88 else color  # borde del iris
	return white
