extends RefCounted
# Paso IU.1a: crea el Theme de la interfaz por código a partir de tokens.gd (diseno/GUIA_INTERFAZ.md §4 y §5.2).
# Todo con StyleBoxFlat. Las variaciones (VARIATIONS) se usan con `control.theme_type_variation = "BotonPrincipal"`.
# La fuente es Nunito variable (D30): un FontVariation por peso, cargada del archivo (Keep File) para que valga también
# cuando las pruebas cargan app/ desde otro proyecto.
# Paso IU.2: iconos de iconos/ (Tabler v3.50.0, MIT, en blanco) por su nombre en español; el tema los tiñe.
# Uso: theme = ThemeBuilder.build(true)   # oscuro (D34); false = claro
#      button.icon = ThemeBuilder.icon("guardar")

const Tokens := preload("tokens.gd")
const VARIATIONS := {
	"BotonPrincipal": "Button", "BotonFantasma": "Button", "Chip": "Button", "Tarjeta": "PanelContainer",
	"TituloZona": "Label", "InsigniaForma": "Label", "InsigniaProporcion": "Label", "InsigniaCrear": "Label",
	"Pista": "Label", "NivelBien": "Button", "NivelAviso": "Button", "NivelError": "Button", "BarraNeutro": "HSlider",
	"Fondo": "Panel", "BarraEstado": "PanelContainer", "EtiquetaZona": "Label",
}
## Paso IU.6a: agarrador de la barra (guía §4): círculo blanco con borde del acento; 18 px y 20 px al pasar el ratón.
const GRABBER_SVG := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\"><circle cx=\"%f\" cy=\"%f\" r=\"%f\" fill=\"#%s\" stroke=\"#%s\" stroke-width=\"2\"/></svg>"
const GRABBER_SIZE := 18
const GRABBER_HOVER_SIZE := 20
## Casilla (CheckBox): las de Godot apenas se ven en oscuro; se dibujan con los tokens. Marcada: acento con ✓ blanco.
const CHECK_SVG := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"18\" height=\"18\" opacity=\"%s\"><rect x=\"1.5\" y=\"1.5\" width=\"15\" height=\"15\" rx=\"4\" fill=\"#%s\" stroke=\"#%s\" stroke-width=\"1.5\"/>%s</svg>"
const CHECK_MARK := "<path d=\"M5 9.5l2.8 2.8L13 6.5\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
## Nivel del informe → token de su color (cabecera del informe y cuadrado de cada fila).
const LEVELS := {"NivelBien": "exito", "NivelAviso": "aviso", "NivelError": "error"}
## Insignia de tipo → tokens de fondo y de letra.
const BADGES := {"InsigniaForma": "forma", "InsigniaProporcion": "proporcion", "InsigniaCrear": "crear"}
const BUTTON_STATES := ["normal", "hover", "pressed", "disabled", "focus"]
## Paso IU.2: los iconos que existen (iconos/<nombre>.svg). Cambiar un icono = cambiar su archivo, no el nombre.
const ICONS := ["cuerpo", "cara", "pelo", "ropa", "accesorios", "exportar", "pronto", "oscuro", "reproducir", "deshacer",
	"rehacer", "abrir", "guardar", "vistas", "simetria", "prenda", "claro", "pausa", "rejilla", "luz", "restablecer",
	"buscar", "bien", "aviso", "error", "licencias", "teclado", "estilo", "plegar", "desplegar", "ajustes", "dado"]
const ICON_SIZE := 24

static var _icons := {}  # nombre → ImageTexture (se cargan una vez)


static func build(dark := true) -> Theme:
	var c: Dictionary = Tokens.palette(dark)
	var theme := Theme.new()
	theme.default_font = font("cuerpo")
	theme.default_font_size = Tokens.LETRA["cuerpo"]
	for name: String in VARIATIONS:
		theme.set_type_variation(name, VARIATIONS[name])
	_buttons(theme, c)
	_variations(theme, c)
	_tabs(theme, c)
	_slider(theme, c)
	_panels(theme, c)
	_fields(theme, c)
	_tooltip(theme, c)
	_grid(theme)
	_silhouette(theme, c)
	_scroll(theme, c)
	_popups(theme, c)
	_section_title(theme, c, dark)
	return theme


## Nunito con el peso de ese papel (titulo, cuerpo, valor, pequena).
static func font(role: String) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = _font_file()
	var weight := TextServerManager.get_primary_interface().name_to_tag("weight")
	variation.variation_opentype = {weight: Tokens.PESO[role]}
	return variation


## Icono por su nombre (ICONS), 24 px, blanco: el botón lo tiñe con icon_*_color. null si no existe.
static func icon(icon_name: String) -> Texture2D:
	if not _icons.has(icon_name):
		var path := (Tokens as Script).resource_path.get_base_dir().path_join("iconos/%s.svg" % icon_name)
		if not FileAccess.file_exists(path):
			push_error("No existe el icono «%s»" % icon_name)
			return null
		var image := Image.new()
		image.load_svg_from_string(FileAccess.get_file_as_string(path), 1.0)
		_icons[icon_name] = ImageTexture.create_from_image(image)
	return _icons[icon_name]


## Paso IU.12: un icono blanco teñido de un color (para los que Godot no tiñe, como el right_icon de LineEdit).
static func tinted(icon_name: String, color: Color) -> ImageTexture:
	var image := icon(icon_name).get_image()
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, Color(color, image.get_pixel(x, y).a))
	return ImageTexture.create_from_image(image)


static func _font_file() -> FontFile:
	var file := FontFile.new()
	file.load_dynamic_font((Tokens as Script).resource_path.get_base_dir().path_join(Tokens.FUENTE))
	return file


static func box(color: Color, radius: int, margin := 8, border := Color.TRANSPARENT, border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.anti_aliasing = true
	return style


static func _set_boxes(theme: Theme, type: String, boxes: Dictionary) -> void:
	for state: String in boxes:
		theme.set_stylebox(state, type, boxes[state])


static func _set_colors(theme: Theme, type: String, colors: Dictionary) -> void:
	for key: String in colors:
		theme.set_color(key, type, colors[key])


static func _focus(c: Dictionary, radius: int) -> StyleBoxFlat:
	var style := box(Color.TRANSPARENT, radius, 8, c["acento_linea"], 2)
	style.draw_center = false
	return style


static func _buttons(theme: Theme, c: Dictionary) -> void:
	var r: int = Tokens.RADIO["boton"]
	for type: String in ["Button", "OptionButton", "ColorPickerButton", "CheckBox", "CheckButton"]:
		_set_boxes(theme, type, {
			"normal": box(c["panel"], r, 8, c["borde_fuerte"], 1), "hover": box(c["panel_2"], r, 8, c["borde_fuerte"], 1),
			"pressed": box(c["acento_suave"], r, 8, c["acento_linea"], 1), "disabled": box(c["panel_2"], r, 8, c["borde"], 1),
			"focus": _focus(c, r)})
		_set_colors(theme, type, {"font_color": c["texto"], "font_hover_color": c["texto"],
			"font_pressed_color": c["acento_texto"], "font_hover_pressed_color": c["acento_texto"],
			"font_focus_color": c["texto"], "font_disabled_color": c["texto_3"],
			"icon_normal_color": c["texto_2"], "icon_hover_color": c["texto"], "icon_pressed_color": c["acento_texto"],
			"icon_hover_pressed_color": c["acento_texto"], "icon_focus_color": c["texto"],
			"icon_disabled_color": c["texto_3"]})
	for type: String in ["CheckBox", "CheckButton"]:  # sin caja: solo el icono y el texto
		var empty := StyleBoxEmpty.new()
		_set_boxes(theme, type, {"normal": empty, "hover": empty, "pressed": empty, "hover_pressed": empty,
			"disabled": empty})
	for state: String in ["", "_disabled"]:
		var alpha := "1" if state == "" else "0.45"
		theme.set_icon("checked" + state, "CheckBox", _svg(CHECK_SVG % [alpha, c["acento"].to_html(false),
			c["acento"].to_html(false), CHECK_MARK]))
		theme.set_icon("unchecked" + state, "CheckBox", _svg(CHECK_SVG % [alpha, c["panel_2"].to_html(false),
			c["texto_3"].to_html(false), ""]))
	theme.set_constant("h_separation", "Button", Tokens.ESPACIO[1])


static func _variations(theme: Theme, c: Dictionary) -> void:
	var r: int = Tokens.RADIO["boton"]
	_set_boxes(theme, "BotonPrincipal", {"normal": box(c["acento"], r, 10), "hover": box(c["acento_hover"], r, 10),
		"pressed": box(c["acento_hover"], r, 10), "disabled": box(c["borde_fuerte"], r, 10), "focus": _focus(c, r)})
	_set_colors(theme, "BotonPrincipal", {"font_color": Color.WHITE, "font_hover_color": Color.WHITE,
		"font_pressed_color": Color.WHITE, "font_focus_color": Color.WHITE, "icon_normal_color": Color.WHITE,
		"icon_hover_color": Color.WHITE, "icon_pressed_color": Color.WHITE, "icon_focus_color": Color.WHITE})
	var empty := box(Color.TRANSPARENT, r)
	_set_boxes(theme, "BotonFantasma", {"normal": empty, "hover": box(c["panel_2"], r), "pressed": box(c["acento_suave"], r),
		"disabled": empty, "focus": _focus(c, r)})
	var pill: int = Tokens.RADIO["pastilla"]
	_set_boxes(theme, "Chip", {"normal": box(c["panel"], pill, 10, c["borde_fuerte"], 1), "hover": box(c["panel_2"], pill, 10,
		c["borde_fuerte"], 1), "pressed": box(c["acento_suave"], pill, 10, c["acento_linea"], 1), "focus": _focus(c, pill)})
	theme.set_stylebox("panel", "Tarjeta", box(c["panel"], Tokens.RADIO["tarjeta"], Tokens.ESPACIO[2], c["borde"], 1))
	theme.set_font("font", "TituloZona", font("titulo"))
	theme.set_font_size("font_size", "TituloZona", Tokens.LETRA["titulo"])
	theme.set_color("font_color", "TituloZona", c["texto"])
	theme.set_color("font_color", "Pista", c["texto_3"])
	for name: String in BADGES:
		var badge := box(c[BADGES[name] + "_fondo"], pill, 2)
		badge.content_margin_left = Tokens.ESPACIO[1]
		badge.content_margin_right = Tokens.ESPACIO[1]
		theme.set_stylebox("normal", name, badge)
		theme.set_color("font_color", name, c[BADGES[name] + "_texto"])
		theme.set_font("font", name, font("pequena"))
		theme.set_font_size("font_size", name, Tokens.LETRA["pequena"])
	theme.set_color("font_color", "Label", c["texto_2"])
	for name: String in LEVELS:
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color",
				"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:  # IU.8: también el icono
			theme.set_color(key, name, c[LEVELS[name]])


static func _tabs(theme: Theme, c: Dictionary) -> void:
	var selected := box(c["panel"], 0, 10)
	selected.border_color = c["acento_linea"]
	selected.border_width_bottom = 3
	for type: String in ["TabContainer", "TabBar"]:
		_set_boxes(theme, type, {"tab_selected": selected, "tab_unselected": box(c["fondo"], 0, 10),
			"tab_hovered": box(c["panel_2"], 0, 10), "tab_disabled": box(c["fondo"], 0, 10), "tab_focus": _focus(c, 0)})
		_set_colors(theme, type, {"font_selected_color": c["texto"], "font_unselected_color": c["texto_2"],
			"font_hovered_color": c["texto"], "font_disabled_color": c["texto_3"], "icon_selected_color": c["acento_linea"],
			"icon_unselected_color": c["texto_2"], "icon_hovered_color": c["texto"], "icon_disabled_color": c["texto_3"]})
	theme.set_stylebox("panel", "TabContainer", box(c["fondo"], 0, Tokens.ESPACIO[2]))
	theme.set_stylebox("tabbar_background", "TabContainer", box(c["fondo"], 0, 0))


static func _slider(theme: Theme, c: Dictionary) -> void:
	var pill: int = Tokens.RADIO["pastilla"]
	var track := box(c["borde"], pill, 2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", box(c["acento"], pill, 2))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(c["acento_hover"], pill, 2))
	theme.set_icon("grabber", "HSlider", _grabber(GRABBER_SIZE, c))  # IU.12: el de Godot es blanco y en claro no se ve
	theme.set_icon("grabber_highlight", "HSlider", _grabber(GRABBER_HOVER_SIZE, c))
	# BarraNeutro: la pista y el relleno los dibuja la fila (slider_row.gd) desde el neutro; aquí, transparentes.
	var empty := StyleBoxEmpty.new()
	empty.content_margin_top = 2
	empty.content_margin_bottom = 2
	for style: String in ["slider", "grabber_area", "grabber_area_highlight"]:
		theme.set_stylebox(style, "BarraNeutro", empty)
	theme.set_icon("grabber", "BarraNeutro", _grabber(GRABBER_SIZE, c))
	theme.set_icon("grabber_highlight", "BarraNeutro", _grabber(GRABBER_HOVER_SIZE, c))
	_set_colors(theme, "BarraNeutro", {"pista": c["borde"], "relleno": c["acento"], "marca": c["texto_3"]})


static func _grabber(px: int, c: Dictionary) -> ImageTexture:
	var half := px / 2.0
	return _svg(GRABBER_SVG % [px, px, half, half, half - 1.5, Color.WHITE.to_html(false), c["acento"].to_html(false)])


static func _svg(svg: String) -> ImageTexture:
	var image := Image.new()
	image.load_svg_from_string(svg, 1.0)
	return ImageTexture.create_from_image(image)


static func _panels(theme: Theme, c: Dictionary) -> void:
	for type: String in ["PanelContainer", "Panel"]:
		theme.set_stylebox("panel", type, box(c["panel"], Tokens.RADIO["tarjeta"], Tokens.MARGEN_PANEL))
	theme.set_stylebox("panel", "Fondo", box(c["fondo"], 0, 0))  # paso IU.6c: detrás de toda la ventana
	var status := box(c["panel"], 0, Tokens.ESPACIO[0], c["borde"], 0)  # paso IU.8b: barra de estado, fina
	status.border_width_top = 1
	status.content_margin_left = Tokens.ESPACIO[3]
	status.content_margin_right = Tokens.ESPACIO[3]
	theme.set_stylebox("panel", "BarraEstado", status)


static func _fields(theme: Theme, c: Dictionary) -> void:
	var r: int = Tokens.RADIO["boton"]
	_set_boxes(theme, "LineEdit", {"normal": box(c["panel_2"], r, 8, c["borde_fuerte"], 1),
		"focus": _focus(c, r), "read_only": box(c["panel_2"], r, 8, c["borde"], 1)})
	_set_colors(theme, "LineEdit", {"font_color": c["texto"], "font_placeholder_color": c["texto_3"],
		"caret_color": c["acento_linea"], "selection_color": c["acento_suave"],
		"clear_button_color": c["texto_2"], "clear_button_color_pressed": c["acento_linea"]})
	theme.set_icon("buscar", "LineEdit", tinted("buscar", c["texto_2"]))  # IU.12: Godot no tiñe el right_icon


## Paso IU.5: colores de la silueta de zonas (zone_silhouette.gd los pide al tipo «Silueta»).
static func _silhouette(theme: Theme, c: Dictionary) -> void:
	_set_colors(theme, "Silueta", {"relleno": c["panel_2"], "borde": c["borde_fuerte"], "relleno_hover": c["acento_suave"],
		"borde_hover": c["acento_linea"], "relleno_elegida": c["acento"]})


static func _grid(theme: Theme) -> void:
	theme.set_constant("h_separation", "GridContainer", Tokens.ESPACIO[4])
	theme.set_constant("v_separation", "GridContainer", Tokens.ESPACIO[1])


static func _tooltip(theme: Theme, c: Dictionary) -> void:
	theme.set_stylebox("panel", "TooltipPanel", box(c["texto"], Tokens.RADIO["boton"], 8))
	theme.set_color("font_color", "TooltipLabel", c["panel"])
	theme.set_font_size("font_size", "TooltipLabel", Tokens.LETRA["valor"])
	theme.set_stylebox("normal", "EtiquetaZona", box(c["texto"], Tokens.RADIO["boton"], 6))  # IU.12: como la ayuda
	theme.set_color("font_color", "EtiquetaZona", c["panel"])
	theme.set_font_size("font_size", "EtiquetaZona", Tokens.LETRA["valor"])


static func _scroll(theme: Theme, c: Dictionary) -> void:
	for type: String in ["VScrollBar", "HScrollBar"]:
		_set_boxes(theme, type, {"scroll": box(Color.TRANSPARENT, 999, 3), "grabber": box(c["borde_fuerte"], 999, 3),
			"grabber_highlight": box(c["texto_3"], 999, 3), "grabber_pressed": box(c["texto_3"], 999, 3)})


static func _popups(theme: Theme, c: Dictionary) -> void:
	var floating := box(c["panel"], Tokens.RADIO["flotante"], Tokens.ESPACIO[3], c["borde"], 1)
	floating.shadow_color = c["sombra"]
	floating.shadow_size = 16
	floating.shadow_offset = Vector2(0, 4)
	theme.set_stylebox("panel", "AcceptDialog", floating)
	theme.set_stylebox("panel", "PopupMenu", box(c["panel"], Tokens.RADIO["boton"], 6, c["borde"], 1))
	theme.set_stylebox("hover", "PopupMenu", box(c["panel_2"], Tokens.RADIO["boton"], 6))
	_set_colors(theme, "PopupMenu", {"font_color": c["texto"], "font_hover_color": c["texto"],
		"font_disabled_color": c["texto_3"]})


## Paso 13.1b: título de sección de un desplegable (hoy «Huesos»), subrayado por el separador sin texto que le sigue.
## En claro, además, letra oscura y sin las rayas de los lados (con el color de serie de Godot casi no se veía).
static func _section_title(theme: Theme, c: Dictionary, dark: bool) -> void:
	var line := StyleBoxLine.new()
	line.color = c["texto_3"] if dark else c["texto"]
	theme.set_stylebox("separator", "PopupMenu", line)
	if dark:
		return
	theme.set_color("font_separator_color", "PopupMenu", c["texto"])
	for side: String in ["labeled_separator_left", "labeled_separator_right"]:
		theme.set_stylebox(side, "PopupMenu", StyleBoxEmpty.new())

