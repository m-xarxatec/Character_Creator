extends RefCounted
# Paso 10.2: guardar y abrir el personaje de la vista como proyecto .gmolde (addons/creador/project_file.gd), con una
# miniatura de la vista. Lo que el proyecto traiga y el editor aún no usa (piezas, pose, escena, otros personajes,
# campos desconocidos) se conserva al volver a guardar. Sin interfaz: los botones están en body_actions.gd.
# Uso:
#   var project := ProjectIO.build(path, body_view, editor.values, last_project)  # last_project: el abierto, o {}
#   var error := ProjectIO.write(path, project)
#   var loaded := ProjectIO.read(path, body_view)  # {error, proyecto, preset (como Preset.from_dict), avisos}
#   var icon := ProjectIO.thumbnail(path)          # Texture2D o null (para «Recientes»)
#   var warnings := ProjectIO.wear_pieces(body_view, project["personajes"][0]["piezas"])  # paso AB.13, al abrir
# Paso AB.13: el bloque «piezas» guarda las piezas puestas (pack, pieza, sha256, ranura y color); las que este programa
# no tiene se conservan tal cual.

const ProjectFile := preload("../addons/creador/project_file.gd")
const Preset := preload("../addons/creador/preset.gd")
const PresetFile := preload("preset_file.gd")
const BodyMaterial := preload("../addons/creador/body_material.gd")
const PackLibrary := preload("../addons/creador/pack_library.gd")
const EXTENSION := "gmolde"
const THUMB := 256  # px de la miniatura: cuadrada, con fondo transparente (la vista lo tiene)
const FOLDER := "user://proyectos"  # carpeta por defecto de Guardar y Abrir


static func is_project(path: String) -> bool:
	return path.get_extension().to_lower() == EXTENSION


## Carpeta por defecto como ruta del sistema (la crea si falta).
static func default_folder() -> String:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	return ProjectSettings.globalize_path(FOLDER)


## El proyecto que se guardaría: el último (o uno nuevo) con el personaje de la vista y una miniatura nueva.
static func build(path: String, view: SubViewportContainer, values: Dictionary, last_project: Dictionary) -> Dictionary:
	var title := path.get_file().get_basename()
	var preset := PresetFile.to_dict(title, view, values)
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	var project: Dictionary
	if last_project.is_empty():
		project = ProjectFile.new_project(title, preset, version)
	else:
		project = last_project.duplicate(true)
		project["personajes"][0]["preset"] = preset
	project["programa"] = version
	project["nombre"] = title
	var kept: Array = project["personajes"][0]["piezas"].filter(func(piece: Dictionary) -> bool:
		return view.library == null or view.library.piece(piece["pack"], piece["pieza"]).is_empty())
	project["personajes"][0]["piezas"] = worn_pieces(view) + kept
	project["miniatura"] = _capture(view)
	return project


static func write(path: String, project: Dictionary) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(ProjectFile.to_text(project) + "\n")
	file.close()
	return OK


## {error, proyecto, preset, avisos}. El editor enseña el primer personaje; lo demás sale en los avisos.
static func read(path: String, view: SubViewportContainer) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "no existe el archivo"}
	var loaded := ProjectFile.from_text(FileAccess.get_file_as_string(path))
	if loaded["error"] != "":
		return loaded
	var project: Dictionary = loaded["proyecto"]
	var character: Dictionary = project["personajes"][0]
	var preset := Preset.from_dict(character["preset"], view.SPECIES, view.species.sliders)
	if preset["error"] != "":
		return {"error": "el personaje: " + preset["error"]}
	var warnings: Array[String] = loaded["avisos"].duplicate()
	for key: String in preset["desconocidas"]:
		warnings.append("el personaje tiene un ajuste que este programa no conoce: '%s' (se ignora)" % key)
	if project["personajes"].size() > 1:
		warnings.append("el editor enseña solo el primer personaje; los otros %d se conservan" % (project["personajes"].size() - 1))
	return {"error": "", "proyecto": project, "preset": preset, "avisos": warnings}


## Paso AB.13: las piezas puestas en la vista, como el bloque «piezas» del proyecto (siguen al cuerpo: hueso Root).
static func worn_pieces(view: SubViewportContainer) -> Array:
	var worn := []
	for key: String in view.pieces.keys() + view.accessories.keys():
		var card: Dictionary = view.library.piece(key.get_base_dir(), key.get_file())
		var color: Color = view.piece_color(key)
		worn.append({"pack": key.get_base_dir(), "pieza": key.get_file(), "sha256": card.get("sha256", ""),
			"ranura": card.get("ranura", ""), "hueso": "Root", "transform": [0, 0, 0, 0, 0, 0, 1, 1],
			"colores": {"principal": [color.r, color.g, color.b]}, "parametros": {}})
	return worn


## Paso AB.13: quita las piezas de la vista y pone las del proyecto, con su color. Devuelve avisos de las que faltan.
static func wear_pieces(view: SubViewportContainer, pieces: Array) -> Array[String]:
	for key: String in view.pieces.keys() + view.accessories.keys():
		view.set_piece(key.get_base_dir(), key.get_file(), false)
	var warnings: Array[String] = []
	for piece: Dictionary in pieces:
		if not view.set_piece(piece["pack"], piece["pieza"], true):
			warnings.append("falta la pieza %s del pack %s (se conserva en el archivo)" % [piece["pieza"], piece["pack"]])
			continue
		var color: Variant = piece["colores"].get("principal")
		if color is Array and color.size() == 3:
			view.set_piece_color(String(piece["pack"]).path_join(piece["pieza"]), PackLibrary.to_color(color))
	return warnings


## La miniatura guardada en un proyecto, o null.
static func thumbnail(path: String) -> Texture2D:
	if not is_project(path) or not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if text.length() > ProjectFile.MAX_TEXT or json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	var encoded: Variant = json.data.get("miniatura")
	if typeof(encoded) != TYPE_STRING or encoded == "":
		return null
	var image := Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(encoded)) != OK:
		return null
	return ImageTexture.create_from_image(image)


## PNG de la vista recortado al centro, en base64. Sin ventana (pruebas) no hay imagen: "".
static func _capture(view: SubViewportContainer) -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var image: Image = view.viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return ""
	var side := mini(image.get_width(), image.get_height())
	image = image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))
	image.resize(THUMB, THUMB, Image.INTERPOLATE_LANCZOS)
	return Marshalls.raw_to_base64(image.save_png_to_buffer())
