extends RefCounted
# Paso P.5c: ajustes del programa que sobreviven al cerrarlo, en user://ajustes.cfg (vale en Linux, Windows, Android y
# dentro del build, donde res:// es de solo lectura): la última carpeta de los diálogos (P.5c), el tema (IU.1c), el
# tamaño de la interfaz y «Reducir animaciones» (IU.9).
# Un archivo roto o que falta da los valores por defecto.
# Uso:
#   SettingsFile.set_folder(path.get_base_dir())
#   var folder := SettingsFile.get_folder()   # "" si no hay o ya no existe
#   var dark := SettingsFile.get_dark()       # true si no hay ajuste (D34: oscuro por defecto)
#   var scale := SettingsFile.get_ui_scale()  # uno de SCALES; sin ajuste, el más cercano al de la pantalla
#   var reduce := SettingsFile.get_reduce_motion()  # false si no hay ajuste

const PATH := "user://ajustes.cfg"
const SCALES := [0.9, 1.0, 1.1, 1.25, 1.5]  # paso IU.9: lista fija (con un deslizador la ventana cambiaría al arrastrar)


static func get_folder() -> String:
	var folder: String = str(_read("archivos", "carpeta", ""))
	return folder if folder != "" and DirAccess.dir_exists_absolute(folder) else ""


static func set_folder(folder: String) -> void:
	_write("archivos", "carpeta", folder)


static func get_dark() -> bool:
	return _read_bool("oscuro", true)


static func set_dark(dark: bool) -> void:
	_write("interfaz", "oscuro", dark)


## Paso IU.9: el tamaño de SCALES más cercano al guardado; si no hay o no es un número, al de la pantalla.
static func get_ui_scale() -> float:
	var value: Variant = _read("interfaz", "tamano", null)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		value = DisplayServer.screen_get_scale()
	return nearest_scale(float(value))


static func set_ui_scale(scale: float) -> void:
	_write("interfaz", "tamano", nearest_scale(scale))


static func nearest_scale(scale: float) -> float:
	var best: float = SCALES[0]
	for candidate: float in SCALES:
		if absf(candidate - scale) < absf(best - scale):
			best = candidate
	return best


static func get_reduce_motion() -> bool:
	return _read_bool("reducir_animaciones", false)


static func set_reduce_motion(on: bool) -> void:
	_write("interfaz", "reducir_animaciones", on)


## Un ajuste de [interfaz] que debe ser bool; si no lo es (archivo roto o a mano), el valor por defecto.
static func _read_bool(key: String, fallback: bool) -> bool:
	var value: Variant = _read("interfaz", key, fallback)
	return value if typeof(value) == TYPE_BOOL else fallback


static func _read(section: String, key: String, fallback: Variant) -> Variant:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return fallback
	return config.get_value(section, key, fallback)


static func _write(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(PATH)  # si no existe, se empieza vacío
	config.set_value(section, key, value)
	config.save(PATH)
