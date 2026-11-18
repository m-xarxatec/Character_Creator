extends VBoxContainer
# Paso P.2: el informe de deformación (report_panel.gd) en un apartado plegable bajo la vista 3D, fuera de los
# deslizadores. Plegado al empezar; la cabecera dice siempre el resumen, con el color del peor nivel.
# Uso: var section := ReportSection.new(); section.show_results(results)  /  section.clear()

const ReportPanel := preload("report_panel.gd")
const TITLE := "Informe de deformación"
const IDLE := "pulsa Probar huesos o elige una animación"

var header: Button
var panel: ScrollContainer  # ReportPanel


func _init() -> void:
	header = Button.new()
	header.toggle_mode = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.tooltip_text = "Avisa si alguna articulación se deforma demasiado en la pose o la animación"
	header.toggled.connect(set_open)
	add_child(header)
	panel = ReportPanel.new()
	panel.name = "Informe"
	panel.custom_minimum_size.y = 180
	panel.summary.visible = false  # ya lo dice la cabecera
	add_child(panel)
	set_open(false)
	clear()


func set_open(on: bool) -> void:
	header.set_pressed_no_signal(on)
	panel.visible = on
	_title(_summary_text())


func show_results(results: Array) -> void:
	panel.show_results(results)
	_title(panel.summary.text)


func clear() -> void:
	panel.show_results([])
	panel.summary.text = IDLE
	_title(IDLE)


func _summary_text() -> String:
	return panel.summary.text if panel.summary.text != "" else IDLE


func _title(summary: String) -> void:
	header.text = "%s  %s — %s" % ["▾" if panel.visible else "▸", TITLE, summary]
	var worst := ""
	for level: String in ["error", "aviso", "bien"]:
		if worst == "" and panel.rows.any(func(r: Dictionary) -> bool: return r["nivel"] == level):
			worst = level
	for state: String in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		if worst == "":
			header.remove_theme_color_override(state)
		else:
			header.add_theme_color_override(state, ReportPanel.LEVEL_COLORS[worst].lightened(0.35))
