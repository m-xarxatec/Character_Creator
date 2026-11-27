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
# Paso AB.4: set_piece() pone o quita una pieza de los packs (library: godot/packs y user://packs) que sigue al cuerpo
#   (BodyPiece; una por ranura, salvo accesorios), con el mismo toon y contorno. Paso AB.7: se exportan con el cuerpo.
# Paso PE.4b: un peinado que cuelga lleva cadenas de huesos (HairChains) y su simulador (HairPhysics); al quitarlo se
#   quitan. Las colisiones se miden otra vez al dejar quietos los deslizadores (frame_timer).

## Paso IU.7a: clic sin arrastrar en el cuerpo, con touch_zones encendido.
signal zone_touched(zone: String)
signal pieces_changed  # paso AB.13: se puso o se quitó una pieza

const SpeciesData := preload("../addons/creador/species_data.gd")
const CharacterUpdater := preload("../addons/creador/character_updater.gd")
const Preset := preload("../addons/creador/preset.gd")
const BodyMaterial := preload("../addons/creador/body_material.gd")
const GlbExporter := preload("../addons/creador/glb_exporter.gd")
const ShapeWeights := preload("../addons/creador/shape_weights.gd")  # paso 9.7.2
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
const HairScene := preload("../addons/creador/hair_scene.gd")  # paso PE.5
const PackLibrary := preload("../addons/creador/pack_library.gd")  # paso AB.4
const BodyPiece := preload("../addons/creador/body_piece.gd")
const HairChains := preload("../addons/creador/hair_chains.gd")  # paso PE.4b
const HairPhysics := preload("../addons/creador/hair_physics.gd")  # paso PE.4b
const BodyDerived := preload("../addons/creador/body_derived.gd")  # paso AB.9a
const EyeMesh := preload("../addons/creador/eye_mesh.gd")  # paso AC.3c
const RigidPiece := preload("../addons/creador/rigid_piece.gd")  # paso AB.11
const GarmentCut := preload("../addons/creador/garment_cut.gd")  # paso AB.5
## Paso AB.6: capa de cada ranura (más alta = más por fuera): se adelanta BodyMaterial.PIECE_PULL × capa.
const LAYERS := {"ropa_interior": 1, "ropa_torso": 2, "ropa_piernas": 2, "pelo": 2, "ropa_pies": 3, "ropa_exterior": 3,
	"accesorio": 4}
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
## SH.4: sombra proyectada de la luz del editor, solo en estilo anime (el clásico no la usa). Los de las hojas de SH.2.
const SHADOW := {"max_distance": 6.0, "bias": 0.03, "normal_bias": 1.0, "blur": 1.0}
const HAIR_SLOT := "pelo"
const HEAD_CENTER_UP := 0.075  # SH.6b: centro de la cabeza, en metros a lo largo del hueso Head (la mitad de su largo)
const RESTYLE_WAIT := 0.3  # segundos sin cambios antes de recalcular las normales del estilo
const REPORT_INSTANTS := 4  # momentos de un clip que mide el informe

var error := ""
var load_ms := 0
var species  # SpeciesData
var library  # PackLibrary (paso AB.4)
var pieces := {}  # paso AB.4: "pack/pieza" → MeshInstance3D puesta
var accessories := {}  # paso AB.11: "pack/pieza" → BoneAttachment3D de un accesorio rígido
var hair := {}  # SH.6b: "pack/pieza" → MeshInstance3D de las piezas de ranura pelo (llevan la banda de brillo)
var hair_physics := {}  # paso PE.4b: "pack/pieza" → SpringBoneSimulator3D del peinado (si cuelga)
var eyes: Array[MeshInstance3D] = []  # AC.6b: capas y líneas del ojo (EyeMesh), para exportarlas
var updater  # CharacterUpdater
var values: Dictionary
var expression := ""  # paso 9.7.2: la expresión que se prueba («happy»…); "" = ninguna
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
	restyle_timer.timeout.connect(func() -> void: style.refresh_async())  # paso OPT.2: en un hilo
	add_child(restyle_timer)
	frame_timer = Timer.new()
	frame_timer.one_shot = true
	frame_timer.wait_time = RESTYLE_WAIT
	frame_timer.timeout.connect(frame_character)
	frame_timer.timeout.connect(_refit_hair)  # paso PE.4b
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
	var faces := {expression: 1.0} if expression != "" else {}  # paso 9.7.2: la expresión que se prueba
	var rejected: Array[String] = updater.update(values, pose_t or clip != "", faces)  # la animación parte de la pose T
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


## Paso 9.7.2: prueba una expresión de VRM («happy», «blink»…) encima de la cara; "" = ninguna. No se guarda ni se
## exporta (el .glb lleva las expresiones como formas, a 0). Devuelve false si la especie no la tiene.
func set_expression(name: String) -> bool:
	if name != "" and not has_expression(name):
		return false
	expression = name
	set_values(values)
	return true


## Paso 9.7.4: si la especie tiene esa expresión (sus formas expr_* están en el cuerpo).
func has_expression(name: String) -> bool:
	var names := ShapeWeights.shape_names(species.mesh.mesh)
	var parts: Array = ShapeWeights.EXPRESSION_GROUPS.get(name, [name])
	return parts.all(func(p: String) -> bool: return ShapeWeights.EXPRESSION_PREFIX + p in names)


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
	if not hair.is_empty() and species != null and BodyMaterial.is_soft(species.mesh):  # SH.6b: la banda sigue a la cabeza
		var head := head_transform()
		for mesh: MeshInstance3D in hair.values():
			(mesh.material_override as ShaderMaterial).set_shader_parameter("hair_head", head)
	# Paso P.8a: con Ctrl, el cursor es una mano (Ctrl + arrastrar desplaza la cámara: orbit_camera.gd).
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if Input.is_key_pressed(KEY_CTRL) else CURSOR_ARROW
	if clip == ROM_ID:
		rom_time += delta
		pose_turns = rom.turns_at(rom_time)
		for bone in mini(t_rotations.size(), species.skeleton.get_bone_count()):  # PE.4b: el pelo quita y pone huesos
			species.skeleton.set_bone_pose_rotation(bone, t_rotations[bone])
			species.skeleton.set_bone_pose_position(bone, t_positions[bone])
		StaticPose.apply(species.skeleton, pose_turns, animations.hips, animations.feet)
	elif clip != "" and pose_turns.is_empty():
		animations.advance(delta)
		retarget.apply()


## Exporta en pose T, sea cual sea la pose de la vista (el exportador la fija), con el .tres al lado.
func export_glb(path: String, use_cache := true) -> Error:
	var job := start_export(use_cache)
	GlbExporter.compute_bake(job)
	GlbExporter.after_bake(job)
	GlbExporter.compute(job)
	return finish_export(job, path)


## Paso P.1: exportar en partes (body_actions.gd hace en un hilo GlbExporter.compute_bake y GlbExporter.compute, con
## GlbExporter.after_bake entre las dos, paso OPT.3b). start_export lee el personaje tal como está ahora; lo que cambie
## después no entra en el archivo.
## OPT.3a: con las formas de la caché de la vista; use_cache = false las pide a la malla (para comparar en las pruebas).
func start_export(use_cache := true) -> Dictionary:
	var cache: Variant = style.shape_cache() if use_cache and style != null else null
	var job := GlbExporter.start(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], true, pieces.values(),
		accessories.values(), eyes, species.eyes, cache)  # AC.6b: con los ojos
	job["hair"] = HairScene.read(hair_physics.values()[0]) if not hair_physics.is_empty() else {}  # PE.5: un solo peinado
	return job


## Paso PE.5: con un peinado con cadenas, también <archivo>.tscn con la física del pelo (HairScene).
func finish_export(job: Dictionary, path: String) -> Error:
	var character := GlbExporter.finish(job)
	var hair: SpringBoneSimulator3D = HairScene.measure(job["hair"], character) if character and job["hair"] else null
	var skeleton_path := "Armature/" + String(character.find_children("*", "Skeleton3D", true, false)[0].name) if hair else ""
	var error := GlbExporter.write(character, job["toon"], path)
	if hair:
		if error == OK:
			error = HairScene.save(hair, path, skeleton_path)
		hair.free()
	return error


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
	environment.ambient_light_energy = 0.0  # SH.3b: toon_soft suma el ambiente; 0 mantiene el aspecto de SH.2
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
	library = PackLibrary.new()  # paso AB.4
	for warning: String in library.scan(PackedStringArray([folder.path_join("../../packs").simplify_path(), "user://packs"])):
		push_warning(warning)
	BodyMaterial.apply(species.mesh)
	BodyMaterial.set_skin_zones(species.mesh, species.skin_zones)
	Preset.apply_look(species.mesh, loaded)
	_set_shadow(BodyMaterial.is_soft(species.mesh))
	set_values(loaded["valores"])
	eyes = EyeMesh.build(species.mesh, species.skeleton, species.eyes)
	for eye in eyes:  # siguen a las formas; no son piezas del pack
		updater.pieces.append(eye)
		BodyPiece.follow(eye, species.mesh)
		if String(eye.name).begins_with("ceja_"):  # AC.6c.4a
			_copy_brow(eye)
	style = StyleView.new()
	style.setup(species.mesh, species.skeleton)
	style.refresh()
	floor_shadow = FloorShadow.new()
	viewport.add_child(floor_shadow)
	floor_shadow.setup(species.skeleton)
	_load_animations(folder.path_join("../animaciones").path_join(ANIMATIONS + ".json").simplify_path())
	return ""


## Paso AB.4: pone (on) o quita una pieza que sigue al cuerpo. Quita la que ocupe su ranura o choque con ella (PackLibrary.conflicts).
## Devuelve false si no se pudo poner (no existe, no sigue al cuerpo o su archivo no vale).
func set_piece(pack_id: String, piece_id: String, on: bool) -> bool:
	var key := pack_id.path_join(piece_id)
	var known: Dictionary = library.piece(pack_id, piece_id)
	if known.has("generador") or accessories.has(key):  # paso AB.11
		return _set_accessory(key, known, on)
	if not on or pieces.has(key):
		if not on and pieces.has(key):
			updater.pieces.erase(pieces[key])
			if hair_physics.has(key):  # paso PE.4b: primero el simulador, luego la malla y al final sus huesos
				hair_physics[key].free()
				hair_physics.erase(key)
				BodyPiece.detach(pieces[key])
				HairChains.remove(species.skeleton)
			else:
				BodyPiece.detach(pieces[key])
			pieces.erase(key)
			hair.erase(key)
			pieces_changed.emit()
		return true
	var card: Dictionary = library.piece(pack_id, piece_id)
	if card.is_empty() or not card["sigue_al_cuerpo"]:
		return false
	var mesh: MeshInstance3D
	if card.has("derivada"):  # paso AB.9a: hecha con caras del cuerpo
		mesh = BodyDerived.build(species.mesh, species.skeleton, card["derivada"]["mascara"], card["derivada"]["separacion"])
		if mesh != null:
			BodyPiece.hang(mesh, species.skeleton)
	elif card.has("corte"):  # paso AB.5: recortada de otra pieza (las mallas)
		var whole: MeshInstance3D = BodyPiece.attach(library.load_piece(pack_id, card["corte"]["de"]), species.skeleton)
		if whole != null:
			mesh = GarmentCut.cut(whole, species.skeleton, species.joints, card["corte"])
			BodyPiece.detach(whole)
		if mesh != null:
			mesh.name = piece_id.capitalize()
			BodyPiece.hang(mesh, species.skeleton)
	else:
		mesh = BodyPiece.attach(library.load_piece(pack_id, piece_id), species.skeleton)
	if mesh == null:
		return false
	if card["ranura"] != PackLibrary.MULTI_SLOT:
		for other: String in pieces.keys():
			if PackLibrary.conflicts(library.piece(other.get_base_dir(), other.get_file()), card):
				set_piece(other.get_base_dir(), other.get_file(), false)
	BodyMaterial.apply(mesh, true, BodyMaterial.is_soft(species.mesh))  # AB.6: se adelanta y tapa la piel que asoma
	(mesh.material_override as ShaderMaterial).set_shader_parameter("depth_pull",
		BodyMaterial.PIECE_PULL * LAYERS.get(card["ranura"], 1))
	var color: Color = library.color_of(card)  # el de partida, de pack.json
	BodyMaterial.set_color(mesh, "skin_color", color)
	BodyMaterial.set_color(mesh, "garment_color", color)
	var finish: Dictionary = BodyMaterial.get_finish(species.mesh)
	for name: String in finish:
		BodyMaterial.set_finish(mesh, name, finish[name])
	_copy_line(mesh)
	pieces[key] = mesh
	if card["ranura"] == HAIR_SLOT:
		hair[key] = mesh
		_copy_band(mesh)
	updater.pieces.append(mesh)
	BodyPiece.follow(mesh, species.mesh)
	if card["ranura"] == HAIR_SLOT:  # paso PE.4b: cadenas y simulador (con el cuerpo de ahora)
		var simulator := HairPhysics.attach(species.skeleton, HairChains.build(mesh, species.skeleton), species.mesh)
		if simulator != null:
			hair_physics[key] = simulator
	pieces_changed.emit()
	return true


## Paso PE.4b: con el cuerpo nuevo, colisiones medidas otra vez y simulación reiniciada (al dejar los deslizadores).
func _refit_hair() -> void:
	for simulator: SpringBoneSimulator3D in hair_physics.values():
		HairPhysics.refit(simulator, species.mesh)


## Paso AB.11: pone o quita un accesorio rígido (RigidPiece, colgado de su hueso). Varios a la vez (ranura accesorio).
func _set_accessory(key: String, card: Dictionary, on: bool) -> bool:
	if not on:
		if accessories.has(key):
			accessories[key].get_parent().remove_child(accessories[key])
			accessories[key].free()
			accessories.erase(key)
			pieces_changed.emit()
		return true
	if accessories.has(key):
		return true
	var holder: BoneAttachment3D = RigidPiece.build(card, species.skeleton)
	if holder == null:
		return false
	for mesh in RigidPiece.meshes(holder):
		BodyMaterial.apply(mesh, true, BodyMaterial.is_soft(species.mesh))
		BodyMaterial.set_color(mesh, "skin_color", library.color_of(card))
		BodyMaterial.set_color(mesh, "garment_color", library.color_of(card))
		_copy_line(mesh)
	accessories[key] = holder
	pieces_changed.emit()
	return true


## Color principal de una pieza puesta.
## SH.7a: estilo anime (true) o clásico en el cuerpo, las piezas y los accesorios, sin perder colores. Las piezas
## copian el acabado del cuerpo, como al ponerlas.
func set_anime_style(on: bool) -> void:
	BodyMaterial.set_style(species.mesh, on)
	var finish: Dictionary = BodyMaterial.get_finish(species.mesh)
	var meshes: Array = pieces.values()
	for holder in accessories.values():
		meshes.append_array(RigidPiece.meshes(holder))
	for mesh: MeshInstance3D in meshes:
		BodyMaterial.set_style(mesh, on, true)
		for name: String in finish:
			BodyMaterial.set_finish(mesh, name, finish[name])
	sync_lines()
	_set_shadow(on)


## SH.4b: las piezas y los accesorios llevan la línea teñida como el cuerpo (cada una, del color de la pieza).
## SH.6b: y las de pelo, la banda de brillo (la fuerza de la piel del cuerpo, hair_band). AC.6c.4a: y las cejas.
func sync_lines() -> void:
	var meshes: Array = pieces.values()
	for holder in accessories.values():
		meshes.append_array(RigidPiece.meshes(holder))
	for mesh: MeshInstance3D in meshes:
		_copy_line(mesh)
	for mesh: MeshInstance3D in hair.values():
		_copy_band(mesh)
	for mesh: MeshInstance3D in eyes:  # AC.6c.4a: las cejas
		if String(mesh.name).begins_with("ceja_"):
			_copy_brow(mesh)


func _copy_band(mesh: MeshInstance3D) -> void:
	var strength: float = BodyMaterial.get_skin(species.mesh)["hair_band"] if BodyMaterial.is_soft(species.mesh) else 0.0
	(mesh.material_override as ShaderMaterial).set_shader_parameter("hair_band_strength", strength)


## AC.6c.4a: Altura, Grosor, Tamaño y Color de la ceja, del material del cuerpo a la ceja (EyeTexture los lee de ella).
func _copy_brow(mesh: MeshInstance3D) -> void:
	var skin: Dictionary = BodyMaterial.get_skin(species.mesh)
	var material := mesh.material_override as ShaderMaterial
	for key: String in BodyMaterial.BROW_SKIN:
		material.set_shader_parameter(key, skin[key])
	material.set_shader_parameter("brow_color", BodyMaterial.get_color(species.mesh, "brow_color"))


## SH.6b: mundo → cabeza, con origen en su centro (para la banda del pelo).
func head_transform() -> Transform3D:
	var skeleton: Skeleton3D = species.skeleton
	var bone: int = skeleton.find_bone("Head")
	var pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	return pose.translated_local(Vector3(0, HEAD_CENTER_UP, 0)).affine_inverse()


func _copy_line(mesh: MeshInstance3D) -> void:
	var tint: float = BodyMaterial.get_skin(species.mesh)["outline_tint"] if BodyMaterial.is_soft(species.mesh) else 0.0
	((mesh.material_override as ShaderMaterial).get_meta("outline") as ShaderMaterial).set_shader_parameter("outline_tint", tint)


## SH.4: la luz del editor proyecta sombra (con SHADOW) o no.
func _set_shadow(on: bool) -> void:
	light.shadow_enabled = on
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = SHADOW["max_distance"]
	light.shadow_bias = SHADOW["bias"]
	light.shadow_normal_bias = SHADOW["normal_bias"]
	light.shadow_blur = SHADOW["blur"]


func is_anime_style() -> bool:
	return BodyMaterial.is_soft(species.mesh)


func piece_color(key: String) -> Color:
	var meshes := meshes_of(key)
	return BodyMaterial.get_color(meshes[0], "skin_color") if not meshes.is_empty() else Color.WHITE


func set_piece_color(key: String, color: Color) -> void:
	for mesh in meshes_of(key):
		BodyMaterial.set_color(mesh, "skin_color", color)
		BodyMaterial.set_color(mesh, "garment_color", color)


## Paso AB.11: ¿está puesta? (pieza que sigue al cuerpo o accesorio rígido)
func is_on(key: String) -> bool:
	return pieces.has(key) or accessories.has(key)


## Paso AB.11: las mallas de una pieza puesta (una, o las del accesorio).
func meshes_of(key: String) -> Array[MeshInstance3D]:
	if pieces.has(key):
		return [pieces[key]]
	return RigidPiece.meshes(accessories[key]) if accessories.has(key) else []


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
