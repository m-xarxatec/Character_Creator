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
# Paso IU.10a: la primera vez, una pista abajo de la vista (HINT); se oculta al primer giro y no vuelve (settings_file.gd).
# Paso IU.3: fondo degradado del tema detrás (set_dark), sombra de suelo y rejilla (floor_shadow.gd) y luz de vista
# previa (set_light; no se guarda ni se exporta).
# Paso IU.7a: con touch_zones, un clic sin arrastrar en el cuerpo emite zone_touched (zone_ray.gd).
# Paso IU.7b: con touch_zones, al dejar quieto el ratón HOVER_WAIT s sobre el cuerpo, su zona se tiñe (tema/zona.gdshader,
# material_overlay: no va al .glb) y una etiqueta dice «Zona · clic para editar».
# Paso 5.9: set_animation(ROM_ID) recorre el rango de movimiento (rom.gd): cada fotograma vuelve a la pose T y gira.

## Paso IU.7a: clic sin arrastrar en el cuerpo, con touch_zones encendido.
signal zone_touched(zone: String)

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
const SettingsFile := preload("settings_file.gd")
const FloorShadow := preload("floor_shadow.gd")
const ZoneRay := preload("zone_ray.gd")
const HOVER_WAIT := 0.12  # s quieto antes del rayo: así no hay un rayo por cada movimiento del ratón
const ZONE_SHADER := preload("tema/zona.gdshader")
const CLICK_SLOP := 4.0  # px: más movimiento entre pulsar y soltar es un arrastre (girar), no un clic
const Tokens := preload("tema/tokens.gd")
const HINT := "Arrastra para girar · Rueda para acercar · F1 atajos"  # paso IU.10a

const SPECIES := "humana"
const DATA_RES := "res://datos"
const ANIMATIONS := "humanoide"
const ROM_ID := "rango_de_movimiento"
const LIGHT_ANGLES := Vector3(-40, 30, 0)  # desde arriba, delante y a un lado; set_light gira la Y
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
var hint: Label  # paso IU.10a (null si ya se vio)
var background: TextureRect  # paso IU.3: degradado detrás de la imagen 3D
var floor_shadow: MeshInstance3D  # FloorShadow
var light: DirectionalLight3D
var touch_zones := false  # paso IU.7a (apagado por defecto: Ajustes)
var zone_ray  # ZoneRay; se prepara al encender touch_zones (~190 ms, medido): así el primer clic no espera
var press_at := Vector2.INF
var hover_timer: Timer  # paso IU.7b
var hover_at := Vector2.ZERO
var highlighted := ""  # zona teñida ahora; "" = ninguna
var zone_material: ShaderMaterial
var zone_label: Label


func _ready() -> void:
	stretch = true
	viewport = SubViewport.new()
	viewport.transparent_bg = true  # paso IU.3: el degradado de detrás se ve donde no hay personaje
	add_child(viewport)
	_add_zone_label()  # paso IU.7b (antes del fondo: set_dark pone su color)
	_add_background()
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
	hover_timer = Timer.new()
	hover_timer.one_shot = true
	hover_timer.wait_time = HOVER_WAIT
	hover_timer.timeout.connect(func() -> void: highlight(zone_at(hover_at), hover_at))
	add_child(hover_timer)
	var start := Time.get_ticks_msec()
	error = _load_character()
	load_ms = Time.get_ticks_msec() - start
	if error == "":
		frame_character()
		camera.snap()
		viewport.size_changed.connect(frame_character)
		if not SettingsFile.get_hint_seen():
			_add_hint()
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


## Paso IU.10a: pista centrada abajo; no tapa el ratón.
func _add_hint() -> void:
	hint = Label.new()
	hint.text = HINT
	hint.mouse_filter = MOUSE_FILTER_IGNORE
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, 24)
	add_child(hint)
	camera.rotated.connect(_on_first_rotation, CONNECT_ONE_SHOT)


func _on_first_rotation() -> void:
	hint.visible = false
	SettingsFile.set_hint_seen(true)


## Paso IU.7a: clic sin arrastrar (menos de CLICK_SLOP px) → rayo → zone_touched. Ctrl y la rueda no cuentan.
func _gui_input(event: InputEvent) -> void:
	if not touch_zones or species == null:
		return
	if event is InputEventMouseMotion:
		_on_mouse_moved(event)
		return
	if not event is InputEventMouseButton:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or event.ctrl_pressed:
		return
	if event.pressed:
		press_at = event.position
	elif press_at.distance_to(event.position) < CLICK_SLOP:
		var zone := zone_at(event.position)
		if zone != "":
			zone_touched.emit(zone)


## Paso IU.7b: con un botón pulsado (girar, desplazar) no hay tinta; quieto, se lanza el rayo al acabar el Timer.
func _on_mouse_moved(event: InputEventMouseMotion) -> void:
	hover_at = event.position
	if event.button_mask != 0:
		hover_timer.stop()
		highlight("", hover_at)
	else:
		hover_timer.start()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover_timer != null:
		hover_timer.stop()
		highlight("", hover_at)


## Paso IU.7b: tiñe la zona (o nada con "") y pone la etiqueta junto a at (coordenadas de la vista).
func highlight(zone: String, at: Vector2) -> void:
	highlighted = zone
	zone_label.visible = zone != ""
	var overlay: Material = null
	if zone != "":
		var mask := PackedFloat32Array()
		mask.resize(64)
		for bind in mini(zone_ray.bind_zones.size(), 64):
			mask[bind] = 1.0 if zone_ray.bind_zones[bind] == zone else 0.0
		zone_material.set_shader_parameter("zone_mask", mask)
		overlay = zone_material
		zone_label.text = "%s · clic para editar" % zone
		zone_label.position = at + Vector2(18, 18)
	species.mesh.material_overlay = overlay
	style.material_overlay = overlay


func _add_zone_label() -> void:
	zone_material = ShaderMaterial.new()
	zone_material.shader = ZONE_SHADER
	zone_label = Label.new()
	zone_label.theme_type_variation = "EtiquetaZona"  # IU.12: con fondo, que la malla no la tape
	zone_label.mouse_filter = MOUSE_FILTER_IGNORE
	zone_label.visible = false
	add_child(zone_label)


## Paso IU.7a: enciende o apaga el clic en el cuerpo; al encenderlo prepara el rayo.
func set_touch_zones(on: bool) -> void:
	touch_zones = on
	if not on and species != null and species.mesh != null:
		hover_timer.stop()
		highlight("", hover_at)
	if on and zone_ray == null and species != null and species.mesh != null:
		zone_ray = ZoneRay.new(species.mesh)


## Zona del cuerpo bajo un punto de la vista; "" si no toca. Lee la pose y las formas de ahora.
func zone_at(at: Vector2) -> String:
	if zone_ray == null:
		zone_ray = ZoneRay.new(species.mesh)
	zone_ray.refresh(species.mesh, species.skeleton)
	return zone_ray.pick(camera.project_ray_origin(at), camera.project_ray_normal(at))


## Paso IU.3: colores del degradado de detrás (tokens vista_centro → vista_borde).
func set_dark(dark: bool) -> void:
	var colors := Tokens.palette(dark)
	var gradient: Gradient = background.texture.gradient
	gradient.colors = PackedColorArray([colors["vista_centro"], colors["vista_borde"]])
	zone_material.set_shader_parameter("tint", colors["acento"])  # paso IU.7b


## Paso IU.3: luz de vista previa: giro en grados alrededor del personaje y energía. Solo se ve aquí.
func set_light(turn_degrees: float, energy: float) -> void:
	light.rotation_degrees = LIGHT_ANGLES + Vector3(0, turn_degrees, 0)
	light.light_energy = energy


func _add_background() -> void:
	var texture := GradientTexture2D.new()
	texture.gradient = Gradient.new()
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.05, 1.05)
	background = TextureRect.new()
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.show_behind_parent = true
	background.mouse_filter = MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	set_dark(SettingsFile.get_dark())


func _add_world() -> void:
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	light = DirectionalLight3D.new()
	light.rotation_degrees = LIGHT_ANGLES
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
	floor_shadow = FloorShadow.new()
	viewport.add_child(floor_shadow)
	floor_shadow.setup(species.skeleton)
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
