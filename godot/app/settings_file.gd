extends RefCounted
# Paso P.5c: ajustes del programa que sobreviven al cerrarlo, en user://ajustes.cfg (vale en Linux, Windows, Android y
# dentro del build, donde res:// es de solo lectura): la última carpeta de los diálogos (P.5c) y el tema (IU.1c).
# Un archivo roto o que falta da los valores por defecto.
# Uso:
#   SettingsFile.set_folder(path.get_base_dir())
#   var folder := SettingsFile.get_folder()   # "" si no hay o ya no existe
#   var dark := SettingsFile.get_dark()       # true si no hay ajuste (D34: oscuro por defecto)

const PATH := "user://ajustes.cfg"


static func get_folder() -> String:
	var folder: String = str(_read("archivos", "carpeta", ""))
	return folder if folder != "" and DirAccess.dir_exists_absolute(folder) else ""


static func set_folder(folder: String) -> void:
	_write("archivos", "carpeta", folder)


static func get_dark() -> bool:
	return _read("interfaz", "oscuro", true) == true


static func set_dark(dark: bool) -> void:
	_write("interfaz", "oscuro", dark)


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
