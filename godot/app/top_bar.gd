extends PanelContainer
# Paso IU.4: barra superior (diseno/GUIA_INTERFAZ.md §2). Fila 1: marca, nombre del archivo (con • si hay cambios) y,
# a la derecha, las acciones (Deshacer, Rehacer, Abrir, Guardar y Exportar). Fila 2: las pestañas principales.
# No hace nada por sí misma: main.gd le da las pestañas y le mueve los botones.
# Uso: bar.setup(titles, icons, soon); bar.add_action(button); bar.set_file("heroe.json", true)

const ThemeBuilder := preload("tema/theme_builder.gd")
const NEW_FILE := "Personaje nuevo"

var tab_bar: TabBar
var file_label: Label
var actions: HBoxContainer


func _init() -> void:
	var rows := VBoxContainer.new()
	add_child(rows)
	var top := HBoxContainer.new()
	rows.add_child(top)
	var brand := Label.new()
	brand.text = "GameMolde"
	brand.theme_type_variation = "TituloZona"
	top.add_child(brand)
	file_label = Label.new()
	file_label.theme_type_variation = "Pista"
	file_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	file_label.text = NEW_FILE
	top.add_child(file_label)
	actions = HBoxContainer.new()
	top.add_child(actions)
	tab_bar = TabBar.new()
	tab_bar.clip_tabs = false
	rows.add_child(tab_bar)


## titles e icons en orden; soon: título → qué llegará (esas pestañas dicen «Pronto»).
func setup(titles: Array, icons: Array, soon: Dictionary) -> void:
	for i in titles.size():
		var title: String = titles[i]
		tab_bar.add_tab(title + ("  ·  Pronto" if soon.has(title) else ""), ThemeBuilder.icon(icons[i]))
		if soon.has(title):
			tab_bar.set_tab_tooltip(i, "Pronto: %s" % soon[title])


## Mueve un botón a la derecha de la fila de arriba (conserva su señal y su atajo).
func add_action(button: Button) -> void:
	if button.get_parent() != null:
		button.get_parent().remove_child(button)
	actions.add_child(button)


func set_file(file_name: String, changed: bool) -> void:
	file_label.text = file_name + ("  •" if changed else "")
