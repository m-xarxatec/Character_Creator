extends ScrollContainer
# Paso 5.4: informe del banco de pruebas de huesos (pestaña Cuerpo). Una fila por resultado de CharacterChecks (5.3) y
# MeshChecks (5.10): cuadrado de color por nivel, texto y, si hay huesos, un botón con su zona de deslizadores.
# Orden: errores, avisos y «bien». Arriba, el resumen. Al pulsar la zona: zone_chosen(zona).
# La tabla hueso → zona vive aquí porque las zonas son de la tabla de la especie humana; con una segunda especie
# pasará al manifiesto.
# Uso: panel.show_results(results)

signal zone_chosen(zone: String)

## Paso IU.1b: nivel → variación del tema (tema/theme_builder.gd); su font_color es el color del nivel.
const LEVEL_VARIATIONS := {"bien": "NivelBien", "aviso": "NivelAviso", "error": "NivelError"}
const LEVEL_ORDER := ["error", "aviso", "bien"]
## Trozo del nombre del hueso (sin Left/Right) → zona de deslizadores.csv. Gana el primero que encaja: UpperChest antes que Chest.
const BONE_ZONES := [["Head", "Cabeza"], ["Eye", "Cabeza"], ["Jaw", "Cabeza"], ["Neck", "Cuello"],
	["Shoulder", "Hombros"], ["UpperArm", "Brazos"], ["LowerArm", "Brazos"], ["Hand", "Manos"], ["Thumb", "Dedos"],
	["Index", "Dedos"], ["Middle", "Dedos"], ["Ring", "Dedos"], ["Little", "Dedos"], ["UpperChest", "Pecho"],
	["Chest", "Torso"], ["Spine", "Cintura"], ["Hips", "Caderas"], ["UpperLeg", "Piernas"], ["LowerLeg", "Piernas"],
	["Foot", "Pies"], ["Toes", "Pies"]]

var rows: Array[Dictionary] = []  # lo que se enseña, en orden (para las pruebas)
var summary: Label
var list: VBoxContainer
var zone_buttons: Array[Button] = []  # uno por fila con zona, en el orden de las filas


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(column)
	summary = Label.new()
	column.add_child(summary)
	list = VBoxContainer.new()
	column.add_child(list)


static func zone_of(bones: PackedStringArray) -> String:
	if bones.is_empty():
		return ""
	var bone := bones[0].trim_prefix("Left").trim_prefix("Right")
	for pair: Array in BONE_ZONES:
		if bone.contains(pair[0]):
			return pair[1]
	return ""


func show_results(results: Array) -> void:
	for child in list.get_children():  # queue_free: el botón pulsado puede estar emitiendo su señal
		list.remove_child(child)
		child.queue_free()
	zone_buttons.clear()
	rows.clear()
	for level: String in LEVEL_ORDER:
		for result: Dictionary in results:
			if result["nivel"] == level:
				rows.append(result)
	var errors := rows.filter(func(r: Dictionary) -> bool: return r["nivel"] == "error").size()
	var warnings := rows.filter(func(r: Dictionary) -> bool: return r["nivel"] == "aviso").size()
	summary.text = "Todo bien" if errors + warnings == 0 else "%d errores, %d avisos" % [errors, warnings]
	for result in rows:
		list.add_child(_row(result))


## Color de un nivel según el tema en uso (cambia al pasar de oscuro a claro).
func level_color(level: String) -> Color:
	return get_theme_color("font_color", LEVEL_VARIATIONS.get(level, LEVEL_VARIATIONS["error"]))


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and list != null:
		for row: Node in list.get_children():
			var square := row.get_child(0) as ColorRect
			if square != null and square.has_meta("nivel"):
				square.color = level_color(square.get_meta("nivel"))


func _row(result: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	var square := ColorRect.new()
	square.set_meta("nivel", result["nivel"])
	square.color = level_color(result["nivel"])
	square.custom_minimum_size = Vector2(12, 12)
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(square)
	var text := Label.new()
	text.text = result["texto"]
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var zone := zone_of(result["huesos"]) if result["nivel"] != "bien" else ""
	if zone != "":
		var button := Button.new()
		button.text = zone
		button.pressed.connect(func() -> void: zone_chosen.emit(zone))
		row.add_child(button)
		zone_buttons.append(button)
	return row
