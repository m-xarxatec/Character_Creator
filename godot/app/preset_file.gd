extends RefCounted
# Paso 7.0: guardar y abrir el preset del personaje de la vista (valores, colores, prenda y acabado), en el formato
# de addons/creador/preset.gd. Sin interfaz: los botones están en body_actions.gd.
# Uso:
#   var error := PresetFile.save(path, body_view, editor.values)   # el nombre del preset = el del archivo
#   var text := PresetFile.to_text("", body_view, editor.values)    # paso P.4: para comparar
#   var loaded := PresetFile.read(path, body_view)                  # {"error": ""…} como Preset.from_text
#   if loaded["error"] == "": PresetFile.apply(loaded, body_view, editor)

const Preset := preload("../addons/creador/preset.gd")
const BodyMaterial := preload("../addons/creador/body_material.gd")
const COLORS := ["skin_color", "garment_color"]


static func save(path: String, view: SubViewportContainer, values: Dictionary) -> Error:
	var text := to_text(path.get_file().get_basename(), view, values)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text + "\n")
	file.close()
	return OK


## El preset del personaje de la vista, como texto (paso P.4: también sirve para saber si hay cambios).
static func to_text(preset_name: String, view: SubViewportContainer, values: Dictionary) -> String:
	var mesh: MeshInstance3D = view.species.mesh
	var colors := {}
	for key: String in COLORS:
		colors[key] = BodyMaterial.get_color(mesh, key)
	return Preset.to_text(Preset.to_dict(preset_name, view.SPECIES, values, colors,
		BodyMaterial.is_garment_visible(mesh), BodyMaterial.get_finish(mesh)))


static func read(path: String, view: SubViewportContainer) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "no existe el archivo"}
	return Preset.from_text(FileAccess.get_file_as_string(path), view.SPECIES, view.species.sliders)


## Valores al editor (un cambio para Deshacer) y aspecto al material.
static func apply(loaded: Dictionary, view: SubViewportContainer, editor) -> void:
	Preset.apply_look(view.species.mesh, loaded)
	editor.load_values(loaded["valores"])
