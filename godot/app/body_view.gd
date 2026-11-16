extends SubViewportContainer
# Paso 4.2: vista 3D del maniquí en vivo (pestaña Cuerpo). Carga datos/humana con el preset de personaje nuevo,
# lo pinta con BodyMaterial y lo muestra en pose A (el reposo). El editor (body_editor.gd) llama a set_values().
# Paso 4.5: set_pose_t() (Probar huesos) y export_glb() (los usa body_actions.gd).
# Paso 4.6: se ve con las normales del estilo (style_view.gd); se recalculan al dejar quietas las formas RESTYLE_WAIT s.
# Paso 5.1: set_animation() reproduce un clip de datos/animaciones (AnimationSet) sobre el maniquí (PoseRetarget).
# Paso 5.2: set_animation() también pone las poses fijas del mismo archivo (StaticPose).
# datos/ está fuera del proyecto: se busca dos carpetas por encima de este script (vale para el MVP, no para distribuir).

const SpeciesData := preload("../addons/creador/species_data.gd")
const CharacterUpdater := preload("../addons/creador/character_updater.gd")
const Preset := preload("../addons/creador/preset.gd")
const BodyMaterial := preload("../addons/creador/body_material.gd")
const GlbExporter := preload("../addons/creador/glb_exporter.gd")
const AnimationSet := preload("../addons/creador/animation_set.gd")
const PoseRetarget := preload("../addons/creador/pose_retarget.gd")
const StaticPose := preload("../addons/creador/static_pose.gd")
const OrbitCamera := preload("orbit_camera.gd")
const StyleView := preload("style_view.gd")

const SPECIES := "humana"
const ANIMATIONS := "humanoide"
const BACKGROUND := Color(0.32, 0.33, 0.36)
const RESTYLE_WAIT := 0.3  # segundos sin cambios antes de recalcular las normales del estilo

var error := ""
var load_ms := 0
var species  # SpeciesData
var updater  # CharacterUpdater
var values: Dictionary
var pose_t := false
var animations  # AnimationSet; null si no cargó (animation_error dice por qué)
var animation_error := ""
var retarget  # PoseRetarget
var clip := ""  # id del clip o de la pose fija en marcha; "" = sin animación
var pose_turns := {}  # giros de la pose fija; vacío si clip es una animación
var camera: Camera3D
var style: MeshInstance3D  # StyleView
var restyle_timer: Timer


func _ready() -> void:
	stretch = true
	var viewport := SubViewport.new()
	add_child(viewport)
	_add_world(viewport)
	restyle_timer = Timer.new()
	restyle_timer.one_shot = true
	restyle_timer.wait_time = RESTYLE_WAIT
	restyle_timer.timeout.connect(func() -> void: style.refresh())
	add_child(restyle_timer)
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
	var rejected: Array[String] = updater.update(values, pose_t or clip != "")  # la animación parte de la pose T
	if not pose_turns.is_empty():
		StaticPose.apply(species.skeleton, pose_turns, animations.hips, animations.feet)
	elif clip != "":
		retarget.capture()
		retarget.apply()
	if style != null:
		if style.show_if_current():
			restyle_timer.stop()
		else:
			restyle_timer.start()
	return rejected


## Probar huesos (paso 4.5): true = pose T; false = reposo (pose A).
func set_pose_t(on: bool) -> void:
	pose_t = on
	set_values(values)


## Reproduce en bucle un clip o pone una pose fija (animations.entries()); "" los quita y vuelve a la pose de antes.
## Devuelve false si no existe.
func set_animation(id: String) -> bool:
	var turns: Dictionary = {} if id == "" or animations == null else animations.pose_turns(id)
	if id != "" and turns.is_empty() and (animations == null or not animations.play(id)):
		return false
	clip = id
	pose_turns = turns
	set_values(values)
	return true


func _process(delta: float) -> void:
	if clip != "" and pose_turns.is_empty():
		animations.advance(delta)
		retarget.apply()


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
	style = StyleView.new()
	style.setup(species.mesh, species.skeleton)
	style.refresh()
	_load_animations(viewport, folder.path_join("../animaciones").path_join(ANIMATIONS + ".json").simplify_path())
	return ""


# Sin animaciones el editor sigue funcionando: solo se queda sin la lista de clips.
func _load_animations(viewport: SubViewport, path: String) -> void:
	var loaded := AnimationSet.new()
	animation_error = loaded.load_file(path)
	if animation_error:
		push_warning(animation_error)
		return
	animations = loaded
	viewport.add_child(animations.scene)
	retarget = PoseRetarget.new(animations.skeleton, species.skeleton, animations.bones, animations.hips)


func _data_folder() -> String:
	var app_folder := ProjectSettings.globalize_path(get_script().resource_path.get_base_dir())
	return app_folder.path_join("../../datos").path_join(SPECIES).simplify_path()
