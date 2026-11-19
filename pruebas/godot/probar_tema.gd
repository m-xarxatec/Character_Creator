extends SceneTree
# Paso IU.1a: tokens y tema de la interfaz (godot/app/tema/). Sin ventana. Comprobaciones de diseno/GUIA_INTERFAZ.md §8:
# (1) claro y oscuro con las mismas claves; (2) contrastes WCAG ≥ 4,5 del texto y ≥ 3 del agarrador (D43);
# (3) estilo para cada control de la guía §5.2 y todas las variaciones; (4) ninguna letra por debajo de 12 px.
# (5) IU.1b: sin colores ni estilos a mano fuera de tema/; (6) IU.1c: botón de tema; (7) IU.2: iconos.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_tema.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: poner texto_3 a #B0B0B0 en tokens.gd -> falla la (2).

const TEXT_MIN := 4.5
const GRABBER_MIN := 3.0
## Texto sobre fondo que tiene que leerse (guía §3.1).
const TEXT_PAIRS := [
	["texto", "panel"], ["texto_2", "panel"], ["texto_3", "panel"], ["texto", "fondo"], ["texto_2", "fondo"],
	["texto_3", "fondo"], ["acento_texto", "acento_suave"], ["exito", "panel"], ["aviso", "panel"], ["error", "panel"],
	["forma_texto", "forma_fondo"], ["proporcion_texto", "proporcion_fondo"], ["crear_texto", "crear_fondo"],
]
## Tipo → estilos que el tema tiene que traer (guía §5.2, nombres comprobados en Godot 4.7.2).
const STYLES := {
	"Button": ["normal", "hover", "pressed", "disabled", "focus"],
	"TabContainer": ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled", "panel"],
	"TabBar": ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled"],
	"HSlider": ["slider", "grabber_area", "grabber_area_highlight"],
	"PanelContainer": ["panel"], "Tarjeta": ["panel"],
	"LineEdit": ["normal", "focus", "read_only"],
	"TooltipPanel": ["panel"],
	"VScrollBar": ["scroll", "grabber", "grabber_highlight"], "HScrollBar": ["scroll", "grabber", "grabber_highlight"],
	"PopupMenu": ["panel", "hover"], "AcceptDialog": ["panel"], "Fondo": ["panel"],
	"BotonPrincipal": ["normal", "hover", "pressed"], "BotonFantasma": ["normal", "hover", "pressed"],
	"Chip": ["normal", "hover", "pressed"],
	"InsigniaForma": ["normal"], "InsigniaProporcion": ["normal"], "InsigniaCrear": ["normal"],
}

## (5) Lo que no se puede escribir en app/ fuera de tema/, y los archivos que pueden (con su motivo).
const LOOSE_COLOR_WORDS := ["Color(", "add_theme_color_override", "add_theme_font_size_override",
	"add_theme_stylebox_override"]
const LOOSE_COLOR_EXCEPTIONS := ["body_view.gd", "test_sword.gd"]  # fondo de la vista (hasta IU.3) y material 3D

var failures := 0


func _initialize() -> void:
	var tema := ProjectSettings.globalize_path("res://").path_join("../../godot/app/tema").simplify_path()
	var Tokens: GDScript = load(tema.path_join("tokens.gd"))
	var Builder: GDScript = load(tema.path_join("theme_builder.gd"))
	check("(1) claro y oscuro tienen las mismas claves", _keys(Tokens.CLARO) == _keys(Tokens.OSCURO),
		str(_keys(Tokens.CLARO)) + " / " + str(_keys(Tokens.OSCURO)))
	for dark: bool in [true, false]:
		var mode := "oscuro" if dark else "claro"
		var c: Dictionary = Tokens.palette(dark)
		var worst := [99.0, ""]
		for pair: Array in TEXT_PAIRS + [["blanco", "acento"]]:
			var front: Color = Color.WHITE if pair[0] == "blanco" else c[pair[0]]
			var ratio := contrast(front, c[pair[1]])
			if ratio < worst[0]:
				worst = [ratio, "%s/%s" % pair]
		print("  MEDIDA %s: peor contraste de texto %.2f (%s)" % [mode, worst[0], worst[1]])
		check("(2) %s: todo el texto ≥ %.1f:1" % [mode, TEXT_MIN], worst[0] >= TEXT_MIN, "%.2f %s" % worst)
		var grabber := contrast(c["acento"], c["panel"])
		check("(2) %s: agarrador del deslizador ≥ %.0f:1 (D43)" % [mode, GRABBER_MIN], grabber >= GRABBER_MIN, "%.2f" % grabber)
		var theme: Theme = Builder.build(dark)
		var missing: Array[String] = []
		for type: String in STYLES:
			for style: String in STYLES[type]:
				if not theme.has_stylebox(style, type):
					missing.append(type + "." + style)
		check("(3) %s: estilo para cada control de la guía" % mode, missing.is_empty(), str(missing))
		var variations := Array(theme.get_type_variation_list("Button")) + Array(theme.get_type_variation_list("Label")) \
			+ Array(theme.get_type_variation_list("PanelContainer")) + Array(theme.get_type_variation_list("HSlider")) + Array(theme.get_type_variation_list("Panel"))
		check("(3) %s: todas las variaciones" % mode, variations.size() == Builder.VARIATIONS.size()
			and Builder.VARIATIONS.keys().all(func(v: String) -> bool: return v in variations), str(variations))
		var sizes: Array = [theme.default_font_size]
		for type: String in theme.get_font_size_type_list():
			for size_name: String in theme.get_font_size_list(type):
				sizes.append(theme.get_font_size(size_name, type))
		check("(4) %s: ninguna letra por debajo de 12 px" % mode, sizes.min() >= 12 and Tokens.LETRA.values().min() >= 12,
			str(sizes))
		check("%s: la fuente es Nunito" % mode, theme.default_font is FontVariation
			and theme.default_font.base_font.get_font_name().begins_with("Nunito"), theme.default_font.base_font.get_font_name())
	# La fuente es variable: el peso (eje wght) tiene que cambiar el ancho del texto, si no los títulos no serían negrita.
	var thin: float = Builder.font("cuerpo").get_string_size("Exportar personaje", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var bold: float = Builder.font("titulo").get_string_size("Exportar personaje", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	print("  MEDIDA ancho de «Exportar personaje» a 14 px: peso 500 %.1f px, peso 700 %.1f px" % [thin, bold])
	check("el peso de Nunito cambia (500 < 700)", thin > 0.0 and bold > thin)
	_check_loose_colors(tema.get_base_dir())
	_check_icons(tema, Builder)
	await _check_theme_button(tema.get_base_dir())
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


## (5) IU.1b: en app/, fuera de tema/, nadie escribe colores ni estilos a mano (guía §5.4).
func _check_loose_colors(app: String) -> void:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(app):
		if not file.ends_with(".gd") or file in LOOSE_COLOR_EXCEPTIONS:
			continue
		var lines := FileAccess.get_file_as_string(app.path_join(file)).split("\n")
		for i in lines.size():
			for word: String in LOOSE_COLOR_WORDS:
				if lines[i].contains(word):
					found.append("%s:%d %s" % [file, i + 1, word])
	check("(5) ningún color ni estilo escrito a mano fuera de tema/", found.is_empty(), str(found))


## (7) IU.2: cada icono de la lista existe, es propio (sin imágenes, textos ni enlaces) y se carga a 24 px; y cada
## icon("…") del código está en la lista.
func _check_icons(tema: String, Builder: GDScript) -> void:
	var bad: Array[String] = []
	for icon_name: String in Builder.ICONS:
		var path := tema.path_join("iconos/%s.svg" % icon_name)
		var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var texture: Texture2D = Builder.icon(icon_name) if text != "" else null
		if text == "" or text.contains("<image") or text.contains("<text") or text.contains("href") 				or text.contains("currentColor") or texture == null or texture.get_size() != Vector2(24, 24):
			bad.append(icon_name)
	check("(7) los %d iconos existen, en blanco y a 24 px" % Builder.ICONS.size(), bad.is_empty(), str(bad))
	var unknown: Array[String] = []
	var call := RegEx.create_from_string("\\bicon\\(\"([a-z_]+)\"\\)")  # \b: no cuenta get_theme_icon(…) de Godot
	var app := tema.get_base_dir()
	for file: String in DirAccess.get_files_at(app):
		if file.ends_with(".gd"):
			for found: RegExMatch in call.search_all(FileAccess.get_file_as_string(app.path_join(file))):
				if not found.get_string(1) in Builder.ICONS:
					unknown.append("%s: %s" % [file, found.get_string(1)])
	check("(7) cada icon(\"…\") del código está en la lista", unknown.is_empty(), str(unknown))


## (6) IU.1c: oscuro por defecto; el botón cambia a claro, lo recuerda y un arranque nuevo empieza en claro.
func _check_theme_button(app: String) -> void:
	var Settings: GDScript = load(app.path_join("settings_file.gd"))
	var Main: GDScript = load(app.path_join("main.gd"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	var main: Control = Main.new()
	root.add_child(main)
	await process_frame
	check("(6) sin ajustes arranca en oscuro y el botón ofrece el claro", main.dark and main.theme_button.tooltip_text.contains("claro")
		and main.theme_button.is_visible_in_tree())
	main.theme_button.pressed.emit()
	check("(6) el botón cambia a claro y lo guarda", not main.dark and not Settings.get_dark()
		and main.theme_button.tooltip_text.contains("oscuro") and main.theme != null)
	main.free()
	main = Main.new()
	root.add_child(main)
	await process_frame
	check("(6) al volver a abrir sigue en claro", not main.dark)
	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))


## Contraste WCAG 2 entre dos colores (1 a 21).
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(color: Color) -> float:
	var channels: Array[float] = []
	for v: float in [color.r, color.g, color.b]:
		channels.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


func _keys(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
