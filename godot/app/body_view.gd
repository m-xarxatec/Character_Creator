extends SubViewportContainer
# Paso 4.2: vista 3D del maniquí en vivo (pestaña Cuerpo). Carga datos/humana con el preset de personaje nuevo,
# lo pinta con BodyMaterial y lo muestra en pose A (el reposo). El editor (body_editor.gd) llama a set_values().
# Paso 4.5: set_pose_t() (Probar huesos) y export_glb() (los usa body_actions.gd).
# datos/ está fuera del proyecto: se busca dos carpetas por encima de este script (vale para el MVP, no para distribuir).

const SpeciesData := preload("../addons/creador/species_data.gd")
const CharacterUpdater := preload("../addons/creador/character_updater.gd")
const Preset := preload("../addons/creador/preset.gd")
const BodyMaterial := preload("../addons/creador/body_material.gd")
const GlbExporter := preload("../addons/creador/glb_exporter.gd")
const OrbitCamera := preload("orbit_camera.gd")

const SPECIES := "humana"
const BACKGROUND := Color(0.32, 0.33, 0.36)

var error := ""
var load_ms := 0
var species  # SpeciesData
var updater  # CharacterUpdater
var values: Dictionary
var pose_t := false
var camera: Camera3D


func _ready() -> void:
	stretch = true
	var viewport := SubViewport.new()
	add_child(viewport)
	_add_world(viewport)
	var start := Time.get_ticks_msec()
	error = _load_character(viewport)
	load_ms = Time.get_ticks_msec() - start
	if error:
		push_error(error)
		var label := Label.new()
		label.text = error
		add_child(label)


## Valores de Forma y Proporción juntos, como en el preset. Devuelve las claves que no aplicó.
func set_values(new_values: Dictionary) -> Array[String]:
	values = new_values
	return updater.update(values, pose_t)


## Probar huesos (paso 4.5): true = pose T; false = reposo (pose A).
func set_pose_t(on: bool) -> void:
	pose_t = on
	set_values(values)


## Exporta en pose T, sea cual sea la pose de la vista (el exportador la fija), con el .tres al lado.
func export_glb(path: String) -> Error:
	var sockets: Array = species.manifest["bones"]["sockets"]
	return GlbExporter.save(species.mesh, species.skeleton, sockets, path, true)


func _add_world(viewport: SubViewport) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)  # desde arriba, delante y a un lado
	viewport.add_child(light)
	camera = OrbitCamera.new()
	viewport.add_child(camera)


func _load_character(viewport: SubViewport) -> String:
	var folder := _data_folder()
	species = SpeciesData.new()
	if species.load_folder(folder):
		return species.error
	var loaded := Preset.from_text(species.preset_text(), SPECIES, species.sliders)
	if loaded["error"]:
		return loaded["error"]
	viewport.add_child(species.scene)
	updater = CharacterUpdater.new(species)
	BodyMaterial.apply(species.mesh)
	Preset.apply_look(species.mesh, loaded)
	set_values(loaded["valores"])
	return ""


func _data_folder() -> String:
	var app_folder := ProjectSettings.globalize_path(get_script().resource_path.get_base_dir())
	return app_folder.path_join("../../datos").path_join(SPECIES).simplify_path()
