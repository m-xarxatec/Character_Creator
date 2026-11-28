extends PanelContainer
# Paso IU.8b: barra de estado (diseno/GUIA_INTERFAZ.md §2 y §4): la pastilla del informe (icono + texto; al pulsarla
# avisa con report_pressed para abrir el desplegable del P.2), la altura y las cabezas de alto, y el presupuesto
# (triángulos y huesos). Números con coma decimal y punto de miles. No calcula nada: main.gd le da los datos.
# Uso: bar.set_report(report_panel.rows); bar.set_measures({height, heads}); bar.set_budget(26756, 56)

signal report_pressed

const ThemeBuilder := preload("tema/theme_builder.gd")
const LEVELS := {"error": "NivelError", "aviso": "NivelAviso", "bien": "NivelBien"}  # del peor al mejor
const IDLE := "Informe: pulsa Probar huesos"

var report_button: Button
var measures_label: Label
var budget_label: Label


func _init() -> void:
	theme_type_variation = "BarraEstado"
	var line := HBoxContainer.new()
	add_child(line)
	report_button = Button.new()
	report_button.flat = true
	report_button.tooltip_text = "Abrir el informe de deformación"
	report_button.pressed.connect(func() -> void: report_pressed.emit())
	line.add_child(report_button)
	measures_label = Label.new()
	measures_label.theme_type_variation = "Pista"
	measures_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(measures_label)
	budget_label = Label.new()
	budget_label.theme_type_variation = "Pista"
	line.add_child(budget_label)
	set_report([])


## rows: las filas del informe ({nivel, …}); vacío = aún no se ha probado.
func set_report(rows: Array) -> void:
	var count := {"error": 0, "aviso": 0, "bien": 0}
	for row: Dictionary in rows:
		count[row["nivel"]] = count.get(row["nivel"], 0) + 1
	if rows.is_empty():
		report_button.text = IDLE
		report_button.icon = null
		report_button.theme_type_variation = ""
		return
	var worst := "bien"
	for level: String in LEVELS:
		if count[level] > 0:
			worst = level
			break
	report_button.theme_type_variation = LEVELS[worst]
	report_button.icon = ThemeBuilder.icon(worst)
	if worst == "bien":
		report_button.text = "Informe: todo bien"
	else:
		var parts: Array[String] = []
		if count["error"] > 0:
			parts.append(_plural(count["error"], "error", "errores"))
		if count["aviso"] > 0:
			parts.append(_plural(count["aviso"], "aviso", "avisos"))
		report_button.text = "Informe: " + ", ".join(parts)


## m: {height (m), heads}.
func set_measures(m: Dictionary) -> void:
	measures_label.text = "%s m  ·  %s cabezas" % [_decimal(m["height"], 2), _decimal(m["heads"], 1)]


func set_budget(triangles: int, bones: int) -> void:
	budget_label.text = "%s triángulos  ·  %d huesos" % [thousands(triangles), bones]


## 26756 → «26.756».
static func thousands(n: int) -> String:
	var digits := str(n)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += "."
		out += digits[i]
	return out


static func _decimal(value: float, decimals: int) -> String:
	return ("%.*f" % [decimals, value]).replace(".", ",")


static func _plural(n: int, one: String, many: String) -> String:
	return "%d %s" % [n, one if n == 1 else many]
