extends AcceptDialog
# Paso P.8b: ventana «Comandos» con los atajos de teclado y ratón. COMMANDS es la única lista: un atajo nuevo es una
# fila más aquí. La abre el botón «Comandos» de la barra de abajo o F1 (main.gd).
# Uso: var dialog := CommandsDialog.new(); add_child(dialog); dialog.popup_centered()

## [teclas, qué hace], en el orden en que se enseñan.
const COMMANDS := [
	["F1", "Ver esta lista"],  # paso IU.10b: la primera, es la puerta a las demás
	["Ctrl + S", "Guardar (proyecto o preset)"],
	["Ctrl + O", "Abrir (proyecto o preset)"],
	["Ctrl + E", "Exportar .glb"],
	["Ctrl + Z", "Deshacer"],
	["Ctrl + Y  ·  Ctrl + Mayús + Z", "Rehacer"],
	["Arrastrar", "Girar la cámara alrededor del personaje"],
	["Ctrl + arrastrar", "Mover la cámara (arriba, abajo, a los lados)"],
	["Rueda del ratón", "Acercar y alejar"],
	["Inicio", "Volver a centrar la cámara"],
	["C (mantener)", "Comparar: ver cómo estaba al abrir o guardar"],  # paso PL.7
]

var grid: GridContainer


func _init() -> void:
	title = "Comandos"
	ok_button_text = "Cerrar"
	grid = GridContainer.new()
	grid.columns = 2
	for command: Array in COMMANDS:
		var keys := Label.new()
		keys.text = command[0]
		keys.theme_type_variation = "TituloZona"
		grid.add_child(keys)
		var text := Label.new()
		text.text = command[1]
		grid.add_child(text)
	add_child(grid)
