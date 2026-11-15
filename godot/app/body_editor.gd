extends RefCounted
# Paso 4.4: estado de edición de la pestaña Cuerpo (valores, simetría e historial para deshacer y rehacer). Sin interfaz.
# Uso:
#   var editor := BodyEditor.new(species.sliders, values)        # values: los del preset (se copian)
#   editor.changed.connect(func() -> void: body_view.set_values(editor.values))
#   editor.set_value("height", 0.7)                              # suelto: cada llamada es un cambio para Deshacer
#   editor.begin_change(); editor.set_value(…); …; editor.end_change()   # un arrastre entero = un solo cambio
#   editor.undo(); editor.redo()
# Con simetría, mover un lado pone el mismo valor en el otro (ShapeWeights.set_value del núcleo).
# Deshacer solo deshace valores (no la simetría) y guarda hasta MAX_HISTORY cambios.

signal changed  ## los valores han cambiado: deslizador, deshacer, rehacer, igualar o restablecer

const ShapeWeights := preload("../addons/creador/shape_weights.gd")
const MAX_HISTORY := 200
const SIDES := ["_l", "_r"]

var values: Dictionary
var symmetry := true
var rows: Array  ## filas de deslizadores.csv
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _before := {}  ## valores al empezar el cambio en curso ({} si no hay ninguno)


func _init(slider_rows: Array, start_values: Dictionary) -> void:
	rows = slider_rows
	values = start_values.duplicate()


func begin_change() -> void:
	if _before.is_empty():
		_before = values.duplicate()


func end_change() -> void:
	if not _before.is_empty() and _before != values:
		_push(_before)
	_before = {}


## Recorta a [0, 1]. false (y nada cambia) si la clave no existe o el valor no es un número válido.
func set_value(key: String, value: float) -> bool:
	var alone := _before.is_empty()
	begin_change()
	var ok := ShapeWeights.set_value(values, key, value, symmetry)
	if alone:
		end_change()
	if ok:
		changed.emit()
	return ok


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> bool:
	if _undo.is_empty():
		return false
	_redo.append(values.duplicate())
	values = _undo.pop_back()
	changed.emit()
	return true


func redo() -> bool:
	if _redo.is_empty():
		return false
	_undo.append(values.duplicate())
	values = _redo.pop_back()
	changed.emit()
	return true


## Todos los deslizadores de la zona a su neutro (columna neutro de la tabla). Un solo cambio.
func reset_zone(zone: String) -> void:
	var edited := values.duplicate()
	for row: Dictionary in rows:
		if row["zona"] == zone:
			for key: String in _keys(row):
				edited[key] = float(row["neutro"])
	_replace(edited)


## Deslizadores de dos lados con valores distintos, en el orden de la tabla: [{zona, nombre, _l, _r}].
func differing_sides() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for row: Dictionary in rows:
		var keys := _keys(row)
		if keys.size() == 2 and values[keys[0]] != values[keys[1]]:
			found.append({"zona": row["zona"], "nombre": row["nombre"], "_l": values[keys[0]], "_r": values[keys[1]]})
	return found


## Copia el lado side ("_l" o "_r") al otro en todos los deslizadores de dos lados. Un solo cambio.
func match_side(side: String) -> void:
	var other: String = SIDES[1 - SIDES.find(side)]
	var edited := values.duplicate()
	for row: Dictionary in rows:
		if _keys(row).size() == 2:
			edited[row["id"] + other] = values[row["id"] + side]
	_replace(edited)


## Claves de la fila que existen en values ([] en Por crear).
func _keys(row: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for side: String in (SIDES if row["lados"] == "2" else [""]):
		if values.has(row["id"] + side):
			keys.append(row["id"] + side)
	return keys


func _replace(edited: Dictionary) -> void:
	if edited == values:
		return
	_push(values)
	values = edited
	changed.emit()


func _push(snapshot: Dictionary) -> void:
	_undo.append(snapshot)
	if _undo.size() > MAX_HISTORY:
		_undo.pop_front()
	_redo.clear()
