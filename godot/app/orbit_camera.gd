extends Camera3D
# Paso 4.2: cámara que gira alrededor del maniquí. Arrastrar con el botón izquierdo la gira; la rueda acerca y aleja.
# Giro y zoom también por código (rotate_by, zoom_by) para las pruebas sin ventana.

const MIN_PITCH := -10.0  # grados: un poco por debajo de la cintura, sin darse la vuelta
const MAX_PITCH := 60.0
const MIN_DISTANCE := 1.0  # metros
const MAX_DISTANCE := 5.0
const DEGREES_PER_PIXEL := 0.4
const ZOOM_STEP := 1.1  # cada paso de rueda multiplica o divide la distancia

var target := Vector3(0, 1.0, 0)  # a media altura del cuerpo
var yaw := 0.0  # grados; 0 = de frente (el personaje mira a +Z)
var pitch := 10.0
var distance := 3.2


func _ready() -> void:
	fov = 35.0
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		rotate_by(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1)


## pixels: lo que se ha arrastrado el ratón (x gira alrededor, y sube o baja).
func rotate_by(pixels: Vector2) -> void:
	yaw = fposmod(yaw - pixels.x * DEGREES_PER_PIXEL, 360.0)
	pitch = clampf(pitch + pixels.y * DEGREES_PER_PIXEL, MIN_PITCH, MAX_PITCH)
	_place()


## steps > 0 aleja, < 0 acerca.
func zoom_by(steps: float) -> void:
	distance = clampf(distance * pow(ZOOM_STEP, steps), MIN_DISTANCE, MAX_DISTANCE)
	_place()


func _place() -> void:
	var y := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	position = target + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * distance
	look_at(target)
