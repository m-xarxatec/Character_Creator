extends RefCounted
# Paso 15.2a: qué hay en cada plataforma (ruta/ARQUITECTURA.md §8). Solo este archivo pregunta por la plataforma.
# Uso: const Platform := preload("platform.gd"); Platform.can("exportar_glb")

const PC := "pc"
const ANDROID := "android"  # cualquier móvil
const FEATURES := {  # función → plataformas que la tienen
	"editar_cuerpo": [PC, ANDROID], "editar_cara": [PC, ANDROID],  # Android: D20, a falta de medir (15.1)
	"estudio": [PC, ANDROID], "abrir_proyecto": [PC, ANDROID], "guardar_proyecto": [PC, ANDROID],
	"exportar_glb": [PC], "exportar_vrm": [PC], "banco_de_pruebas": [PC], "importar_pieza": [PC],
	"escultura": [PC], "packs_usuario": [PC]}
const MAX_IMAGE_SIDE := {PC: 8192, ANDROID: 4096}  # píxeles; el de Android, sin verificar en un aparato

static var simulated := ""  # solo pruebas; "" = la plataforma real


## La etiqueta «estudio» (custom feature del preset) prueba el modo móvil en el PC.
static func current() -> String:
	if not simulated.is_empty():
		return simulated
	return ANDROID if OS.has_feature("mobile") or OS.has_feature("estudio") else PC


static func is_mobile() -> bool:
	return current() == ANDROID


## Una función desconocida es «no» y avisa: una errata nunca enseña algo de más.
static func can(feature: String, platform := "") -> bool:
	if not FEATURES.has(feature):
		push_warning("Función de plataforma desconocida: " + feature)
		return false
	return (current() if platform.is_empty() else platform) in FEATURES[feature]


## Lado máximo de una imagen; una plataforma desconocida se queda con el de Android (el menor).
static func max_image_side(platform := "") -> int:
	return MAX_IMAGE_SIDE.get(current() if platform.is_empty() else platform, MAX_IMAGE_SIDE[ANDROID])
