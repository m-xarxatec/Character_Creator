extends RefCounted
# TA.5b: miniatura de 256 px de una pieza del Taller, en ¾ y con fondo transparente.
# Uso: var image: Image = await AssetThumbnail.render(nodo_en_el_arbol, malla)  # null sin ventana

const SIDE := 256
const YAW := deg_to_rad(35.0)
const PITCH := deg_to_rad(12.0)
const MARGIN := 1.12


static func render(parent: Node, mesh: Mesh) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var viewport := _viewport(mesh)
	parent.add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	if image != null:
		image.convert(Image.FORMAT_RGBA8)
	return image


static func _viewport(mesh: Mesh) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIDE, SIDE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	viewport.add_child(instance)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	viewport.add_child(light)
	viewport.add_child(_camera(mesh.get_aabb()))
	return viewport


## Cámara ortogonal que encuadra la caja entera desde ¾.
static func _camera(box: AABB) -> Camera3D:
	var direction := Vector3(sin(YAW) * cos(PITCH), sin(PITCH), cos(YAW) * cos(PITCH))
	var basis := Basis.looking_at(-direction)
	var center := box.get_center()
	var extent := 0.0
	for i in 8:
		var corner := box.get_endpoint(i) - center
		extent = maxf(extent, maxf(absf(corner.dot(basis.x)), absf(corner.dot(basis.y))))
	var distance := box.size.length() + 1.0
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(extent * 2.0 * MARGIN, 0.01)
	camera.far = distance * 2.0
	camera.transform = Transform3D(basis, center + direction * distance)
	return camera
