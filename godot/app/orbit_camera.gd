extends Camera3D
# Paso 4.2: cámara que gira alrededor del maniquí. Arrastrar con el botón izquierdo la gira; la rueda acerca y aleja.
# Giro y zoom también por código (rotate_by, zoom_by) para las pruebas sin ventana.
# Paso P.3: frame(caja, aspecto) encuadra el personaje entero; la cámara llega poco a poco (snap() de golpe). El zoom de
# la rueda es relativo a ese encuadre.
# Paso P.8a: Ctrl + arrastrar desplaza la cámara en el plano de la pantalla (pan, aparte de target: el encuadre no lo
# borra); Inicio la vuelve a centrar.

const MIN_PITCH := -10.0  # grados: un poco por debajo de la cintura, sin darse la vuelta
const MAX_PITCH := 60.0
const MIN_DISTANCE := 1.0  # metros
const MAX_DISTANCE := 8.0
const DEGREES_PER_PIXEL := 0.4
const ZOOM_STEP := 1.1  # cada paso de rueda multiplica o divide la distancia
const FRAME_MARGIN := 1.15  # aire alrededor del personaje
const EASE := 8.0  # rapidez del movimiento hacia el encuadre nuevo (1/s)
const MAX_PAN := 1.5  # metros: lo más lejos que se puede desplazar el punto mirado

var target := Vector3(0, 1.0, 0)  # a media altura del cuerpo
var yaw := 0.0  # grados; 0 = de frente (el personaje mira a +Z)
var pitch := 10.0
var distance := 3.2
var zoom := 1.0  # 1 = encuadrado; la rueda lo cambia
var fit_distance := 3.2  # la del encuadre que se ve ahora (va hacia goal_distance)
var goal_target := target
var goal_distance := 3.2
var pan := Vector3.ZERO  # paso P.8a: desplazamiento del punto mirado


func _ready() -> void:
	fov = 35.0
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if event.ctrl_pressed:
			pan_by(event.relative)
		else:
			rotate_by(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		recenter()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1)


func _process(delta: float) -> void:
	if target.is_equal_approx(goal_target) and is_equal_approx(fit_distance, goal_distance):
		return
	var t := 1.0 - exp(-EASE * delta)
	target = target.lerp(goal_target, t)
	fit_distance = lerpf(fit_distance, goal_distance, t)
	if target.distance_to(goal_target) < 0.0005 and absf(fit_distance - goal_distance) < 0.0005:
		snap()
	else:
		_update_distance()


## Encuadra la caja (el personaje en la pose de ahora). aspect = ancho / alto de la vista.
func frame(box: AABB, aspect: float) -> void:
	var half := tan(deg_to_rad(fov) / 2.0)
	var radius := maxf(box.size.x, box.size.z) / 2.0
	var fit := maxf(box.size.y / 2.0 / half, radius / (half * maxf(aspect, 0.1)))
	goal_target = box.get_center()
	goal_distance = fit * FRAME_MARGIN + radius / 2.0


## Llega al encuadre de golpe.
func snap() -> void:
	target = goal_target
	fit_distance = goal_distance
	_update_distance()


func _update_distance() -> void:
	distance = clampf(fit_distance * zoom, MIN_DISTANCE, MAX_DISTANCE)
	_place()


## pixels: lo que se ha arrastrado el ratón (x gira alrededor, y sube o baja).
func rotate_by(pixels: Vector2) -> void:
	yaw = fposmod(yaw - pixels.x * DEGREES_PER_PIXEL, 360.0)
	pitch = clampf(pitch + pixels.y * DEGREES_PER_PIXEL, MIN_PITCH, MAX_PITCH)
	_place()


## pixels: lo que se ha arrastrado el ratón con Ctrl. Lo que hay bajo el ratón lo sigue; la cámara no gira.
func pan_by(pixels: Vector2) -> void:
	var height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var meters := 2.0 * distance * tan(deg_to_rad(fov) / 2.0) / height
	pan = (pan + (-pixels.x * basis.x + pixels.y * basis.y) * meters).limit_length(MAX_PAN)
	_place()


## Quita el desplazamiento (tecla Inicio).
func recenter() -> void:
	pan = Vector3.ZERO
	_place()


## steps > 0 aleja, < 0 acerca.
func zoom_by(steps: float) -> void:
	zoom = clampf(zoom * pow(ZOOM_STEP, steps), MIN_DISTANCE / fit_distance, MAX_DISTANCE / fit_distance)
	_update_distance()


func _place() -> void:
	var y := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	position = target + pan + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * distance
	look_at(target + pan)
