extends SceneTree
# Banco de pruebas de huesos: hojas de capturas del personaje EXPORTADO (horneado, con el material .tres del juego).
# Lo usan los pasos 5.5, 5.6, 5.9, 5.12 y 5.13. Necesita ventana (no --headless).
# Uso: (ulimit -v 4000000; timeout 600 godot --path pruebas/godot -s capturar_banco.gd -- --salida=pruebas/capturas/<carpeta> [opciones] 2>&1 | grep -E 'GUARDADO|MEDIDA|RENDERIZADOR|ERROR')
# Opciones (todas con valor por defecto):
#   --cuerpo=anime|neutro|extremo|azar   anime = preset de personaje nuevo; extremo = todo a 1; azar = semilla fija
#   --variantes=t,a                      una columna por variante: pose T horneada y pose A (sin corrección)
#   --poses=reposo,brazos_arriba,…       una hoja por pose: reposo, poses del 5.2, codo_90 o <clip>@<0..1> (p. ej. atacar@0.4)
#   --vistas=frente,tres_cuartos,lado,espalda   también primeros planos: cara, hombro, codo, cadera, mano
#   --espada                             espada de prueba en socket_hand_r (godot/app/test_sword.gd, paso 5.6)
#   --mano=<0..1>                        valor de hand_size_r
#   --rom                                paso 5.9: una hoja por movimiento de rom.json (rom_<id>.png, variante T); filas: pose T,
#                                        extremo «desde» y extremo «hasta»; columnas: frente, tres cuartos, lado y primer plano
#   --preset=<archivo.json>              otro preset para colores, prenda y acabado (y para --cuerpo=anime)
#   vista «juego»: cámara de tercera persona, detrás y por encima (fov 50°, a 3,5 alturas de cadera)
# Hoja: <salida>/<cuerpo>_<pose>.png (una fila por variante, una columna por vista, con su nombre escrito).
# --salida relativa: desde la raíz del repositorio. Colores, prenda y acabado: los del preset de personaje nuevo.

const TILE := Vector2i(360, 540)
const ELBOWS := {"LeftLowerArm": [0, -90, 0], "RightLowerArm": [0, 90, 0]}
const VIEW_ANGLES := {"frente": 0.0, "tres_cuartos": 35.0, "lado": 90.0, "espalda": 180.0}
const CLOSE_UPS := {"cara": "Head", "hombro": "LeftUpperArm", "codo": "LeftLowerArm", "cadera": "LeftUpperLeg", "mano": "RightHand"}
const SEED := 7

var root_dir: String
var options := {}
var species
var updater
var animations
var exporter: GDScript
var static_pose: GDScript
var retarget_script: GDScript
var material_script: GDScript
var view: SubViewport
var camera: Camera3D
var caption: Label


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var addon := root_dir.path_join("godot/addons/creador")
	exporter = load(addon.path_join("glb_exporter.gd"))
	static_pose = load(addon.path_join("static_pose.gd"))
	retarget_script = load(addon.path_join("pose_retarget.gd"))
	material_script = load(addon.path_join("body_material.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	animations = load(addon.path_join("animation_set.gd")).new()
	var error: String = animations.load_file(root_dir.path_join("godot/datos/animaciones/humanoide.json"))
	if error:
		print("ERROR: ", error)
		quit(1)
		return
	print("RENDERIZADOR ", RenderingServer.get_current_rendering_method())
	_make_view()
	view.add_child(species.scene)
	view.add_child(animations.scene)
	species.scene.visible = false
	animations.scene.visible = false
	material_script.apply(species.mesh)
	var preset_script: GDScript = load(addon.path_join("preset.gd"))
	preset_script.apply_look(species.mesh, preset_script.from_text(_preset_text(), "humana", species.sliders))
	updater = load(addon.path_join("character_updater.gd")).new(species)
	updater.update(_values(options.get("cuerpo", "anime")), false)
	var out := _absolute(options.get("salida", "pruebas/capturas/banco"))
	DirAccess.make_dir_recursive_absolute(out)
	if options.has("rom"):
		await _rom_sheets(out)
		quit()
		return
	var variants: PackedStringArray = options.get("variantes", "t,a").split(",")
	var views: PackedStringArray = options.get("vistas", "frente,tres_cuartos,lado,espalda").split(",")
	for pose: String in options.get("poses", "reposo").split(","):
		var sheet := Image.create(TILE.x * views.size(), TILE.y * variants.size(), false, Image.FORMAT_RGBA8)
		for row in variants.size():
			var character: Node3D = exporter.build(species.mesh, species.skeleton, species.manifest["bones"]["sockets"],
				variants[row] == "t")
			var mesh: MeshInstance3D = character.find_children("*", "MeshInstance3D", true, false)[0]
			mesh.material_override = material_script.standalone(species.mesh)
			view.add_child(character)
			if options.has("espada"):
				load(root_dir.path_join("godot/app/test_sword.gd")).add(character)
			await process_frame
			_pose(character, pose)
			for column in views.size():
				var text := "%s · %s · %s" % [variants[row].to_upper(), pose, views[column]]
				await _shoot(character, views[column], text, sheet, Vector2i(column, row))
			character.free()
		var path := out.path_join("%s_%s.png" % [options.get("cuerpo", "anime"), pose.replace("@", "_")])
		sheet.save_png(path)
		print("GUARDADO ", path)
	quit()


## Paso 5.9: una hoja por movimiento del rango de movimiento, sobre la variante T.
func _rom_sheets(out: String) -> void:
	var rom = load(root_dir.path_join("godot/app/rom.gd")).new()
	var error: String = rom.load_file(root_dir.path_join("godot/datos/animaciones/rom.json"))
	if error:
		print("ERROR: ", error)
		return
	for move: Dictionary in rom.moves:
		var bone: String = ("Left" if int(move["lados"]) == 2 else "") + move["hueso"]
		var views := ["frente", "tres_cuartos", "lado", "hueso:" + bone]
		var rows := [["pose T", 0.0], ["desde %d°" % move["desde"], 0.25], ["hasta %d°" % move["hasta"], 0.75]]
		var sheet := Image.create(TILE.x * views.size(), TILE.y * rows.size(), false, Image.FORMAT_RGBA8)
		for row in rows.size():
			var character: Node3D = exporter.build(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], true)
			var mesh: MeshInstance3D = character.find_children("*", "MeshInstance3D", true, false)[0]
			mesh.material_override = material_script.standalone(species.mesh)
			view.add_child(character)
			await process_frame
			var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
			static_pose.apply(skeleton, rom.turns(move["id"], rows[row][1]), animations.hips, [])
			for column in views.size():
				var text := "%s · %s · %s" % [move["id"], rows[row][0], views[column].trim_prefix("hueso:")]
				await _shoot(character, views[column], text, sheet, Vector2i(column, row))
			character.free()
		var path := out.path_join("rom_%s.png" % move["id"])
		sheet.save_png(path)
		print("GUARDADO ", path)


## Encuadra, espera al dibujo y pega la captura en su casilla de la hoja.
func _shoot(character: Node3D, view_name: String, text: String, sheet: Image, cell: Vector2i) -> void:
	_aim(character, view_name)
	caption.text = text
	for f in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(image, Rect2i(Vector2i.ZERO, TILE), cell * TILE)


func _absolute(path: String) -> String:
	return path if path.is_absolute_path() else root_dir.path_join(path).simplify_path()


func _preset_text() -> String:
	return FileAccess.get_file_as_string(_absolute(options["preset"])) if options.has("preset") else species.preset_text()


func _values(body: String) -> Dictionary:
	var values := {}
	if body == "anime":
		var preset: Dictionary = load(root_dir.path_join("godot/addons/creador/preset.gd")).from_text(
			_preset_text(), "humana", species.sliders)
		values = preset["valores"]
	elif body != "neutro":
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		for row: Dictionary in species.sliders:
			if row["tipo"] != "Por crear":
				for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
					values[row["id"] + side] = 1.0 if body == "extremo" else rng.randf()
	if options.has("mano"):
		values["hand_size_r"] = float(options["mano"])
	return values


func _make_view() -> void:
	view = SubViewport.new()
	view.size = TILE
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	camera = Camera3D.new()
	camera.fov = 35.0
	view.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	view.add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.75, 0.78, 0.82)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.6, 0.65, 0.8)
	world.environment.ambient_light_energy = 0.25
	view.add_child(world)
	caption = Label.new()
	caption.position = Vector2(8, 4)
	caption.add_theme_color_override("font_color", Color.BLACK)
	view.add_child(caption)


func _pose(character: Node3D, pose: String) -> void:
	var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
	if pose == "reposo":
		return
	if pose.contains("@"):
		var parts := pose.split("@")
		var retarget = retarget_script.new(animations.skeleton, skeleton, animations.bones, animations.hips)
		retarget.capture()
		animations.play(parts[0])
		animations.seek(animations.length() * float(parts[1]))
		retarget.apply()
		return
	var turns: Dictionary = ELBOWS if pose == "codo_90" else animations.pose_turns(pose)
	static_pose.apply(skeleton, turns, animations.hips, animations.feet)


## Cámara: vistas de cuerpo entero alrededor del personaje, o primer plano de un hueso.
func _aim(character: Node3D, name: String) -> void:
	var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
	var box := AABB(skeleton.get_bone_global_pose(0).origin, Vector3.ZERO)  # huesos en la pose: la caja de la malla es la de reposo
	for bone in skeleton.get_bone_count():
		box = box.expand(skeleton.get_bone_global_pose(bone).origin)
	box = box.grow(0.12 * box.size.y)
	if name == "juego":
		var hips: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
		camera.fov = 50.0
		camera.look_at_from_position(Vector3(0, hips.y * 2.6, -hips.y * 3.5), hips + Vector3(0, hips.y * 0.4, 0))
		return
	camera.fov = 35.0
	if CLOSE_UPS.has(name) or name.begins_with("hueso:"):  # «hueso:<nombre>»: primer plano de cualquier hueso
		var bone: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone(CLOSE_UPS.get(name, name.trim_prefix("hueso:")))).origin
		camera.look_at_from_position(bone + Vector3(0.15, 0.1, 0.6) * box.size.y / 1.7, bone)
		return
	var height := box.size.y
	var target := box.get_center()
	var angle := deg_to_rad(VIEW_ANGLES.get(name, 0.0))
	var half := tan(deg_to_rad(camera.fov) / 2.0)  # fov vertical; el horizontal es más estrecho (imagen vertical)
	var width := maxf(box.size.x, box.size.z)
	var distance := maxf(height / (2.0 * half), width / (2.0 * half * TILE.x / TILE.y)) + width / 2.0
	camera.look_at_from_position(target + Vector3(sin(angle), 0.08, cos(angle)) * distance, target)

