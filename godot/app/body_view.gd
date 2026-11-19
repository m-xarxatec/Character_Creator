extends SubViewportContainer
# Paso 4.2: vista 3D del maniquí en vivo (pestaña Cuerpo). Carga datos/humana con el preset de personaje nuevo,
# lo pinta con BodyMaterial y lo muestra en pose A (el reposo). El editor (body_editor.gd) llama a set_values().
# Paso 4.5: set_pose_t() (Probar huesos) y export_glb() (los usa body_actions.gd).
# Paso 4.6: se ve con las normales del estilo (style_view.gd); se recalculan al dejar quietas las formas RESTYLE_WAIT s.
# Paso 5.1: set_animation() reproduce un clip de datos/animaciones (AnimationSet) sobre el maniquí (PoseRetarget).
# Paso 5.2: set_animation() también pone las poses fijas del mismo archivo (StaticPose).
# Paso 5.4: check_report() revisa el personaje que se exporta (CharacterChecks) y su malla en la pose o el clip en marcha
# (MeshChecks, sobre una copia horneada en pose T; un clip se mide en REPORT_INSTANTS momentos y queda el peor).
# Paso P.8a: con Ctrl pulsado, el cursor sobre la vista es una mano (desplazar la cámara).
# Paso P.3: frame_character() encuadra el personaje entero (al cargar, RESTYLE_WAIT s después de mover un deslizador, al cambiar la pose o
# la animación y al cambiar el tamaño de la vista); no en cada fotograma.
# Paso 5.9: set_animation(ROM_ID) recorre el rango de movimiento (rom.gd): cada fotograma vuelve a la pose T y gira.

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
const Rom := preload("rom.gd")
const CharacterBaker := preload("../addons/creador/character_baker.gd")
const Sockets := preload("../addons/creador/sockets.gd")
const CharacterChecks := preload("../addons/creador/character_checks.gd")
const MeshChecks := preload("../addons/creador/mesh_checks.gd")
const CharacterBox := preload("character_box.gd")

const SPECIES := "humana"
const DATA_RES := "res://datos"
const ANIMATIONS := "humanoide"
const ROM_ID := "rango_de_movimiento"
const BACKGROUND := Color(0.32, 0.33, 0.36)
const RESTYLE_WAIT := 0.3  # segundos sin cambios antes de recalcular las normales del estilo
const REPORT_INSTANTS := 4  # momentos de un clip que mide el informe

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
var pose_turns := {}  # giros de la pose fija (o del instante del rango de movimiento); vacío si clip es una animación
var rom  # Rom; null si no cargó
var rom_time := 0.0
var t_rotations: Array[Quaternion] = []  # pose T del esqueleto vivo, para volver a ella antes de cada giro del rango
var t_positions: Array[Vector3] = []
var camera: Camera3D
var style: MeshInstance3D  # StyleView
var restyle_timer: Timer
var frame_timer: Timer  # paso P.3: encuadrar al dejar quietos los deslizadores
var character_box  # CharacterBox
var viewport: SubViewport


func _ready() -> void:
	stretch = true
	viewport = SubViewport.new()
	add_child(viewport)
	_add_world()
	restyle_timer = Timer.new()
	restyle_timer.one_shot = true
	restyle_timer.wait_time = RESTYLE_WAIT
	restyle_timer.timeout.connect(func() -> void: style.refresh())
	add_child(restyle_timer)
	frame_timer = Timer.new()
	frame_timer.one_shot = true
	frame_timer.wait_time = RESTYLE_WAIT
	frame_timer.timeout.connect(frame_character)
	add_child(frame_timer)
	var start := Time.get_ticks_msec()
	error = _load_character()
	load_ms = Time.get_ticks_msec() - start
	if error == "":
		frame_character()
		camera.snap()
		viewport.size_changed.connect(frame_character)
	if error:
		push_error(error)
		var label := Label.new()
		label.text = error
		add_child(label)


## Valores de Forma y Proporción juntos, como en el preset. Devuelve las claves que no aplicó.
func set_values(new_values: Dictionary) -> Array[String]:
	values = new_values
	var rejected: Array[String] = updater.update(values, pose_t or clip != "")  # la animación parte de la pose T
	if clip == ROM_ID:
		_save_t_pose()
	if not pose_turns.is_empty():
		StaticPose.apply(species.skeleton, pose_turns, animations.hips, animations.feet)
	elif clip != "":
		retarget.capture()
		retarget.apply()
	frame_timer.start()
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
	frame_character()


## Reproduce en bucle un clip o pone una pose fija (animations.entries()); "" los quita y vuelve a la pose de antes.
## Devuelve false si no existe.
func set_animation(id: String) -> bool:
	var turns: Dictionary = {} if id == "" or animations == null else animations.pose_turns(id)
	if id == ROM_ID and rom != null:
		rom_time = 0.0
		turns = rom.turns_at(0.0)
	elif id != "" and turns.is_empty() and (animations == null or not animations.play(id)):
		return false
	clip = id
	pose_turns = turns
	set_values(values)
	frame_character()
	return true


func _process(delta: float) -> void:
	# Paso P.8a: con Ctrl, el cursor es una mano (Ctrl + arrastrar desplaza la cámara: orbit_camera.gd).
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if Input.is_key_pressed(KEY_CTRL) else CURSOR_ARROW
	if clip == ROM_ID:
		rom_time += delta
		pose_turns = rom.turns_at(rom_time)
		for bone in t_rotations.size():
			species.skeleton.set_bone_pose_rotation(bone, t_rotations[bone])
			species.skeleton.set_bone_pose_position(bone, t_positions[bone])
		StaticPose.apply(species.skeleton, pose_turns, animations.hips, animations.feet)
	elif clip != "" and pose_turns.is_empty():
		animations.advance(delta)
		retarget.apply()


## Exporta en pose T, sea cual sea la pose de la vista (el exportador la fija), con el .tres al lado.
func export_glb(path: String) -> Error:
	var job := start_export()
	GlbExporter.compute(job)
	return finish_export(job, path)


## Paso P.1: exportar en partes (body_actions.gd hace GlbExporter.compute en un hilo entre las dos).
## start_export lee el personaje tal como está ahora; lo que cambie después no entra en el archivo.
func start_export() -> Dictionary:
	return GlbExporter.prepare(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], true)


func finish_export(job: Dictionary, path: String) -> Error:
	return GlbExporter.write(GlbExporter.finish(job), job["toon"], path)


## Informe del banco de pruebas (paso 5.4): comprobaciones del personaje que se exporta y, si hay una pose fija o un
## clip, las medidas de malla en esa pose. Tarda (hornea): llamarlo al pedir el informe, no en cada fotograma.
func check_report() -> Array[Dictionary]:
	var baked: Node3D = CharacterBaker.bake(species.mesh, species.skeleton, true)
	var character: Node3D = Sockets.to_nodes(baked, species.manifest["bones"]["sockets"])
	baked.free()
	if character == null:
		return [{"id": "anclajes", "nivel": "error", "texto": "No se pudo hornear el personaje", "huesos": PackedStringArray()}]
	var results: Array[Dictionary] = CharacterChecks.run(character, species.manifest)
	if clip != "":
		character.visible = false
		viewport.add_child(character)  # StaticPose lee poses globales: dentro del árbol están al día
		results.append_array(_pose_report(character))
	character.free()
	return results


func _pose_report(character: Node3D) -> Array[Dictionary]:
	var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
	var mesh: MeshInstance3D = character.find_children("*", "MeshInstance3D", true, false)[0]
	if not pose_turns.is_empty():
		StaticPose.apply(skeleton, pose_turns, animations.hips, animations.feet)
		return MeshChecks.run(mesh, skeleton)
	var copy := PoseRetarget.new(animations.skeleton, skeleton, animations.bones, animations.hips)
	copy.capture()
	var now: float = animations.player.current_animation_position
	var samples: Array[Dictionary] = []
	for i in REPORT_INSTANTS:
		animations.seek(animations.length() * i / REPORT_INSTANTS)
		copy.apply()
		samples.append_array(MeshChecks.run(mesh, skeleton))
	animations.seek(now)
	retarget.apply()
	return _worst_findings(samples)


## De varias mediciones: cada hallazgo (medida y huesos) una vez, con su peor valor; y, de cada medida sin hallazgos,
## su «bien» de mayor valor.
static func _worst_findings(samples: Array[Dictionary]) -> Array[Dictionary]:
	var found := {}
	for result in samples:
		var key: String = result["id"] + ("|" + ",".join(result["huesos"]) if result["nivel"] != "bien" else "")
		if not found.has(key) or result["valor"] > found[key]["valor"]:
			found[key] = result
	var results: Array[Dictionary] = []
	for key: String in found:
		if key.contains("|") or not found.keys().any(func(k: String) -> bool: return k.begins_with(key + "|")):
			results.append(found[key])
	return results


## Encuadra el personaje en la pose de ahora (caja de una muestra de vértices, character_box.gd).
func frame_character() -> void:
	if species == null or species.mesh == null:
		return
	if character_box == null:
		character_box = CharacterBox.new(species.mesh)
	var to_world: Transform3D = species.mesh.global_transform if species.mesh.is_inside_tree() else Transform3D.IDENTITY
	var box: AABB = to_world * character_box.measure(species.mesh, species.skeleton)
	var size := Vector2(viewport.size)
	camera.frame(box, size.x / size.y if size.y > 0 else 1.0)


func _add_world() -> void:
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


func _load_character() -> String:
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
	_load_animations(folder.path_join("../animaciones").path_join(ANIMATIONS + ".json").simplify_path())
	return ""


# Sin animaciones el editor sigue funcionando: solo se queda sin la lista de clips.
func _load_animations(path: String) -> void:
	var loaded := AnimationSet.new()
	animation_error = loaded.load_file(path)
	if animation_error:
		push_warning(animation_error)
		return
	animations = loaded
	viewport.add_child(animations.scene)
	retarget = PoseRetarget.new(animations.skeleton, species.skeleton, animations.bones, animations.hips)
	var loaded_rom := Rom.new()
	var rom_error := loaded_rom.load_file(path.get_base_dir().path_join("rom.json"))
	if rom_error:
		push_warning(rom_error)
	else:
		rom = loaded_rom


func _save_t_pose() -> void:
	t_rotations.clear()
	t_positions.clear()
	for bone in species.skeleton.get_bone_count():
		t_rotations.append(species.skeleton.get_bone_pose_rotation(bone))
		t_positions.append(species.skeleton.get_bone_pose_position(bone))


# Paso A2: primero res://datos (dentro del proyecto y del .pck); si no está (las pruebas cargan este script desde
# otro proyecto), la carpeta datos/ junto a app/.
func _data_folder() -> String:
	var packed := DATA_RES.path_join(SPECIES)
	if FileAccess.file_exists(packed.path_join("manifiesto.json")):
		return packed
	var app_folder := ProjectSettings.globalize_path(get_script().resource_path.get_base_dir())
	return app_folder.path_join("../datos").path_join(SPECIES).simplify_path()
