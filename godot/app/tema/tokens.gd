extends RefCounted
# Paso IU.1a: los tokens de diseño de la interfaz (diseno/GUIA_INTERFAZ.md §3). Es el ÚNICO archivo de app/ con colores
# y tamaños: los demás los piden aquí (o al tema que crea theme_builder.gd). Los colores salen tal cual de la tabla §3.1.
# Uso: var colors := Tokens.palette(true)   # oscuro (D34: el tema por defecto); false = claro

const CLARO := {
	"fondo": Color("F3F1F8"),
	"panel": Color("FFFFFF"),
	"panel_2": Color("F7F6FB"),
	"borde": Color("E3E0EC"),
	"borde_fuerte": Color("CFCADD"),
	"texto": Color("1E1B2E"),
	"texto_2": Color("4F4A66"),
	"texto_3": Color("6E6987"),
	"acento": Color("6A55E0"),
	"acento_hover": Color("5A46D0"),
	"acento_linea": Color("6A55E0"),
	"acento_suave": Color("EEEBFF"),
	"acento_texto": Color("4B37C4"),
	"exito": Color("17794C"),
	"aviso": Color("946000"),
	"error": Color("D63A40"),
	"forma_fondo": Color("EEEBFF"),
	"forma_texto": Color("4B37C4"),
	"proporcion_fondo": Color("E0F4F6"),
	"proporcion_texto": Color("0B6E78"),
	"crear_fondo": Color("FFF1D6"),
	"crear_texto": Color("8A5A00"),
	"vista_centro": Color("FFFFFF"),
	"vista_borde": Color("E6E1F3"),
	"sombra_suelo": Color(0, 0, 0, 0.18),
	"sombra": Color(0, 0, 0, 0.10),
}

const OSCURO := {
	"fondo": Color("15131D"),
	"panel": Color("1E1B29"),
	"panel_2": Color("262234"),
	"borde": Color("36314A"),
	"borde_fuerte": Color("4A4462"),
	"texto": Color("F2F0FA"),
	"texto_2": Color("C3BED6"),
	"texto_3": Color("9C97B2"),
	"acento": Color("6A55E0"),
	"acento_hover": Color("5A46D0"),
	"acento_linea": Color("8F7DFF"),
	"acento_suave": Color("2D2650"),
	"acento_texto": Color("C9C0FF"),
	"exito": Color("4CC38A"),
	"aviso": Color("F2B544"),
	"error": Color("FF6B70"),
	"forma_fondo": Color("2D2650"),
	"forma_texto": Color("CFC7FF"),
	"proporcion_fondo": Color("12363B"),
	"proporcion_texto": Color("8EE3EC"),
	"crear_fondo": Color("3A2A0A"),
	"crear_texto": Color("F7C873"),
	"vista_centro": Color("2B2640"),
	"vista_borde": Color("14121B"),
	"sombra_suelo": Color(0, 0, 0, 0.35),
	"sombra": Color(0, 0, 0, 0.40),
}

## Tamaños de letra en px (guía §3.2). Nada por debajo de 12.
const LETRA := {"titulo": 18, "cuerpo": 14, "valor": 13, "pequena": 12}
## Peso de Nunito para cada tamaño (eje wght de la fuente variable).
const PESO := {"titulo": 700, "cuerpo": 500, "valor": 600, "pequena": 600}
const ESPACIO := [4, 8, 12, 16, 24, 32]
const RADIO := {"boton": 8, "tarjeta": 12, "flotante": 16, "pastilla": 999}
const ALTO_MINIMO := 32
const ALTO_PRINCIPAL := 36
const MARGEN_PANEL := 16
const PANEL_DERECHO := 360  # paso IU.6: ancho del panel de ajustes
const PANEL_IZQUIERDO := 280  # paso IU.5: ancho del panel de zonas
const FUENTE := "fuentes/nunito.ttf"  # relativa a esta carpeta (las pruebas cargan app/ desde otro proyecto)
const GIZMO_EJES := [Color(0.9, 0.25, 0.25), Color(0.3, 0.8, 0.3), Color(0.3, 0.5, 0.95)]  # X, Y, Z; igual en los dos temas
const GIZMO_ESCALA := Color(0.7, 0.7, 0.7)


static func palette(dark: bool) -> Dictionary:
	return OSCURO if dark else CLARO
