extends AcceptDialog
# Paso 4.4: aviso al activar la simetría si los lados difieren. Lista los deslizadores distintos y deja elegir:
# Mantener como está (por defecto: Intro, cerrar o Esc), Igualar a la izquierda o Igualar a la derecha.
# Uso: dialog.chosen.connect(…); dialog.ask(editor.differing_sides())

signal chosen(side: String)  ## "" = mantener; "_l" o "_r" = igualar a ese lado

const LEFT := "Igualar a la izquierda"
const RIGHT := "Igualar a la derecha"

var _asking := false  # para responder una sola vez aunque Godot avise al ocultarse


func _ready() -> void:
	title = "Simetría"
	ok_button_text = "Mantener como está"
	add_button(LEFT, false, "_l")
	add_button(RIGHT, false, "_r")
	confirmed.connect(_choose.bind(""))
	canceled.connect(_choose.bind(""))
	custom_action.connect(_choose)


## differences: lo que devuelve BodyEditor.differing_sides().
func ask(differences: Array[Dictionary]) -> void:
	var lines := PackedStringArray(["Los dos lados no son iguales en:"])
	for item: Dictionary in differences:
		lines.append("%s › %s: izq. %s / der. %s" % [item["zona"], item["nombre"], _number(item["_l"]), _number(item["_r"])])
	dialog_text = "\n".join(lines)
	_asking = true
	popup_centered()


func _choose(side: String) -> void:
	if not _asking:
		return
	_asking = false
	hide()
	chosen.emit(side)


static func _number(value: float) -> String:
	return ("%.2f" % value).replace(".", ",")
