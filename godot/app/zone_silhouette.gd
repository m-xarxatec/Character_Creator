extends Control
# Paso IU.5a: silueta de frente dibujada por código; cada zona es una forma que se ilumina al pasar el ratón y se elige
# con un clic (diseno/GUIA_INTERFAZ.md §4). Coordenadas en una caja de 100 × 200 (x = 50 es el centro), escalada y
# centrada en el control. Las partes con dos lados se escriben una vez (la de la izquierda) y se reflejan.
# Global y Glúteos no tienen forma de frente: solo están en la lista (zone_picker.gd).
# Colores: tipo «Silueta» del tema (tema/theme_builder.gd).
# Uso: var s := ZoneSilhouette.new(); s.zone_chosen.connect(…); s.selected_zone = "Cabeza"

signal zone_chosen(zone: String)

const BOX := Vector2(100, 200)
const MARGIN := 0.95  # la silueta ocupa el 95 % del sitio
## Zona → [polígono de un lado, ¿se refleja?]. Orden de búsqueda del clic: de arriba abajo.
const PARTS := [
	["Cuello", [[45, 30], [55, 30], [56, 37], [44, 37]], false],
	["Hombros", [[28, 40], [44, 36], [44, 40], [36, 43], [29, 47]], true],
	["Pecho", [[36, 43], [44, 40], [56, 40], [64, 43], [64, 58], [36, 58]], false],
	["Torso", [[36, 58], [64, 58], [62, 72], [38, 72]], false],
	["Cintura", [[38, 72], [62, 72], [61, 80], [39, 80]], false],
	["Caderas", [[39, 80], [61, 80], [66, 96], [34, 96]], false],
	["Brazos", [[29, 47], [36, 43], [32, 84], [25, 84]], true],
	["Manos", [[25, 84], [32, 84], [32, 94], [24, 94]], true],
	["Dedos", [[24, 94], [32, 94], [31, 104], [25, 104]], true],
	["Piernas", [[34, 96], [49, 96], [47, 176], [38, 176]], true],
	["Pies", [[38, 176], [47, 176], [47, 184], [34, 184]], true],
]
const HEAD_CENTER := Vector2(50, 17)
const HEAD_RADII := Vector2(10, 13)
const HEAD_POINTS := 20
const LINE_WIDTH := 1.5

var shapes: Array = []  # [[zona, PackedVector2Array en la caja]], la cabeza primero
var hover_zone := ""
var selected_zone := "":
	set(value):
		selected_zone = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(0, 300)
	tooltip_text = "Elige una zona"
	mouse_filter = Control.MOUSE_FILTER_STOP
	shapes = build_shapes()


## Las formas de la silueta, con las de dos lados ya reflejadas.
static func build_shapes() -> Array:
	var head := PackedVector2Array()
	for i in HEAD_POINTS:
		var angle := TAU * i / HEAD_POINTS
		head.append(HEAD_CENTER + Vector2(cos(angle), sin(angle)) * HEAD_RADII)
	var result: Array = [["Cabeza", head]]
	for part: Array in PARTS:
		var side := PackedVector2Array()
		for p: Array in part[1]:
			side.append(Vector2(p[0], p[1]))
		result.append([part[0], side])
		if part[2]:
			var mirrored := PackedVector2Array()
			for p: Vector2 in side:
				mirrored.append(Vector2(BOX.x - p.x, p.y))
			result.append([part[0], mirrored])
	return result


## Escala y desplazamiento de la caja 100 × 200 al control.
func _fit() -> Array:
	var scale_factor := minf(size.x / BOX.x, size.y / BOX.y) * MARGIN
	return [scale_factor, (size - BOX * scale_factor) / 2.0]


## Punto del control → punto de la caja.
func to_box(point: Vector2) -> Vector2:
	var fit := _fit()
	return (point - fit[1]) / fit[0]


## Punto de la caja → punto del control (para las pruebas).
func to_control(point: Vector2) -> Vector2:
	var fit := _fit()
	return point * fit[0] + fit[1]


## Zona bajo un punto del control ("" si no hay ninguna).
func zone_at(point: Vector2) -> String:
	var p := to_box(point)
	for shape: Array in shapes:
		if Geometry2D.is_point_in_polygon(p, shape[1]):
			return shape[0]
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var zone := zone_at(event.position)
		if zone != hover_zone:
			hover_zone = zone
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var zone := zone_at(event.position)
		if zone != "":
			selected_zone = zone
			zone_chosen.emit(zone)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover_zone != "":
		hover_zone = ""
		queue_redraw()


func _get_tooltip(at_position: Vector2) -> String:
	var zone := zone_at(at_position)
	return zone if zone != "" else tooltip_text


func _draw() -> void:
	var fit := _fit()
	for shape: Array in shapes:
		var zone: String = shape[0]
		var points := PackedVector2Array()
		for p: Vector2 in shape[1]:
			points.append(p * fit[0] + fit[1])
		var fill := get_theme_color("relleno", "Silueta")
		var line := get_theme_color("borde", "Silueta")
		if zone == selected_zone:
			fill = get_theme_color("relleno_elegida", "Silueta")
			line = get_theme_color("borde_hover", "Silueta")
		elif zone == hover_zone:
			fill = get_theme_color("relleno_hover", "Silueta")
			line = get_theme_color("borde_hover", "Silueta")
		draw_colored_polygon(points, fill)
		points.append(points[0])
		draw_polyline(points, line, LINE_WIDTH, true)
