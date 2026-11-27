extends Node3D
## Paso 13.1a: gizmo de mover, girar y escalar, en los ejes de la pieza («Local» en Blender). Se añade al SubViewport
## de la vista después de la cámara (así recibe la entrada antes). Pulsar en un asa la coge; arrastrar emite el
## incremento desde el evento anterior; soltar emite released. Fuera de un asa, el evento sigue (la cámara gira).
## Las cuentas son estáticas y sin cámara: se prueban sin ventana (pruebas/godot/probar_gizmo.gd).
## Uso:
##   const TransformGizmo := preload("transform_gizmo.gd")
##   var gizmo := TransformGizmo.new(); view.viewport.add_child(gizmo)
##   gizmo.target = holder.global_transform * RigidPiece.get_place(holder)   # cada fotograma
##   gizmo.moved_by.connect(func(axis, meters): place = TransformGizmo.moved(frame, place, axis, meters))

signal moved_by(axis: Vector3, meters: float)  # eje en el mundo, unitario
signal turned_by(axis: Vector3, radians: float)
signal scaled_by(factor: float)
signal released

enum Mode { MOVE, TURN, SCALE }

const SIZE_PX := 90.0  # largo de flecha y radio de anillo, en píxeles de pantalla
const PICK_PX := 10.0  # distancia máxima al asa para cogerla
const AXIS_COLORS := [Color(0.9, 0.25, 0.25), Color(0.3, 0.8, 0.3), Color(0.3, 0.5, 0.95)]  # X, Y, Z
const SCALE_COLOR := Color(0.7, 0.7, 0.7)
const RING_SIDES := 48
const MIN_SCALE := 0.05
const MAX_SCALE := 20.0

var mode := Mode.MOVE
var target := Transform3D()  # dónde se dibuja: origen y ejes (se usa basis.orthonormalized())

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _dragging := -1  # asa cogida, o -1
var _last := Vector2.ZERO


func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.no_depth_test = true
	_material.vertex_color_use_as_albedo = true
	_material.render_priority = 10
	var instance := MeshInstance3D.new()
	instance.mesh = _mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(target.origin):
		return
	var colors := _colors()
	var handles := _world_handles(camera)
	for i in handles.size():
		_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
		for point: Vector3 in handles[i]:
			_mesh.surface_set_color(colors[i])
			_mesh.surface_add_vertex(point)
		_mesh.surface_end()


func _unhandled_input(event: InputEvent) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_visible_in_tree() or camera.is_position_behind(target.origin):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = pick(_screen_handles(camera), event.position, PICK_PX)
			_last = event.position
			if _dragging >= 0:
				get_viewport().set_input_as_handled()
		elif _dragging >= 0:
			_dragging = -1
			get_viewport().set_input_as_handled()
			released.emit()
	elif event is InputEventMouseMotion and _dragging >= 0:
		_drag(camera, _last, event.position)
		_last = event.position
		get_viewport().set_input_as_handled()


## Emite el incremento de un arrastre de from a to (en píxeles del viewport).
func _drag(camera: Camera3D, from: Vector2, to: Vector2) -> void:
	var origin := target.origin
	var center := camera.unproject_position(origin)
	if mode == Mode.SCALE:
		scaled_by.emit(factor(center, from, to))
		return
	var axis := _axes()[_dragging]
	if mode == Mode.MOVE:
		moved_by.emit(axis, along(center, camera.unproject_position(origin + axis), from, to))
	else:
		var toward := axis.dot(camera.global_position - origin) > 0.0
		turned_by.emit(axis, angle(center, from, to, toward))


func _axes() -> Array[Vector3]:
	var basis := target.basis.orthonormalized()
	return [basis.x.normalized(), basis.y.normalized(), basis.z.normalized()]


func _colors() -> Array:
	return [SCALE_COLOR] if mode == Mode.SCALE else AXIS_COLORS


## Metros que miden SIZE_PX en pantalla a la distancia del origen.
func _length(camera: Camera3D) -> float:
	var height := get_viewport().get_visible_rect().size.y
	var distance := camera.global_position.distance_to(target.origin)
	return SIZE_PX * 2.0 * distance * tan(deg_to_rad(camera.fov) / 2.0) / maxf(height, 1.0)


## Los puntos de cada asa en el mundo: flechas (MOVE), anillos (TURN) o un círculo de cara a la cámara (SCALE).
func _world_handles(camera: Camera3D) -> Array[PackedVector3Array]:
	var origin := target.origin
	var length := _length(camera)
	var axes := _axes()
	var handles: Array[PackedVector3Array] = []
	if mode == Mode.MOVE:
		for axis in axes:
			handles.append(PackedVector3Array([origin, origin + axis * length]))
	elif mode == Mode.TURN:
		for i in 3:
			handles.append(_circle(origin, axes[(i + 1) % 3], axes[(i + 2) % 3], length))
	else:
		handles.append(_circle(origin, camera.global_basis.x, camera.global_basis.y, length / 2.0))
	return handles


func _screen_handles(camera: Camera3D) -> Array[PackedVector2Array]:
	var handles: Array[PackedVector2Array] = []
	for points in _world_handles(camera):
		var screen := PackedVector2Array()
		for point in points:
			screen.append(camera.unproject_position(point))
		handles.append(screen)
	return handles


static func _circle(origin: Vector3, u: Vector3, v: Vector3, radius: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	for k in RING_SIDES + 1:
		var a := TAU * k / RING_SIDES
		points.append(origin + (u * cos(a) + v * sin(a)) * radius)
	return points


## El asa con el punto más cercano a at, si está a ≤ radius; si no, −1.
static func pick(handles: Array[PackedVector2Array], at: Vector2, radius: float) -> int:
	var best := -1
	var best_distance := radius
	for i in handles.size():
		var points := handles[i]
		for k in points.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(at, points[k], points[k + 1])
			if at.distance_to(closest) <= best_distance:
				best_distance = at.distance_to(closest)
				best = i
	return best


## Metros a lo largo del eje: tip_px es origen + eje × 1 m en pantalla. Eje de punta (< 1 px) → 0.
static func along(origin_px: Vector2, tip_px: Vector2, from: Vector2, to: Vector2) -> float:
	var s := tip_px - origin_px
	if s.length() < 1.0:
		return 0.0
	return (to - from).dot(s) / s.length_squared()


## Giro alrededor del eje. En pantalla Y va hacia abajo: con el eje hacia la cámara, el signo se invierte.
static func angle(center_px: Vector2, from: Vector2, to: Vector2, toward_camera: bool) -> float:
	var a := (from - center_px).angle_to(to - center_px)
	return -a if toward_camera else a


## Cuánto escala un arrastre: distancia al centro después / antes, entre 0,5 y 2 por evento.
static func factor(center_px: Vector2, from: Vector2, to: Vector2) -> float:
	var before := (from - center_px).length()
	if before < 1.0:
		return 1.0
	return clampf((to - center_px).length() / before, 0.5, 2.0)


## place movido meters por el eje del mundo; frame = holder.global_transform.
static func moved(frame: Transform3D, place: Transform3D, axis: Vector3, meters: float) -> Transform3D:
	var world := frame * place
	world.origin += axis * meters
	return frame.affine_inverse() * world


## place girado radians alrededor del eje del mundo, sin mover su origen.
static func turned(frame: Transform3D, place: Transform3D, axis: Vector3, radians: float) -> Transform3D:
	var world := frame * place
	world.basis = Basis(axis, radians) * world.basis
	return frame.affine_inverse() * world


## place escalado by, con la escala final entre MIN_SCALE y MAX_SCALE.
static func scaled(place: Transform3D, by: float) -> Transform3D:
	var scale_now := _mean_scale(place.basis)
	var goal := clampf(scale_now * by, MIN_SCALE, MAX_SCALE)
	return Transform3D(place.basis * (goal / scale_now), place.origin)


static func _mean_scale(basis: Basis) -> float:
	var s := basis.get_scale()
	return (s.x + s.y + s.z) / 3.0
