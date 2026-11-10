extends SceneTree
# Pone al humano a reproducir animaciones de Quaternius y guarda una hoja de capturas.
# Necesita ventana (no --headless). Uso: godot --path . -s probar_animacion.gd

const SHOTS := [["Idle", 0.5], ["Walk", 0.0], ["Walk", 0.3], ["Walk", 0.6], ["Sword_Attack", 0.4], ["Sitting_Idle", 0.5]]
const TILE := Vector2i(400, 600)

func _initialize() -> void:
	# Vista propia de tamano fijo: asi la captura no depende del tamano de la ventana.
	var view := SubViewport.new()
	view.size = TILE
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var human: Node3D = load("res://humano.glb").instantiate()
	view.add_child(human)
	var source: Node = load("res://UAL1_Standard.glb").instantiate()
	var source_player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
	var player := AnimationPlayer.new()
	human.add_child(player)
	player.add_animation_library("", source_player.get_animation_library(""))
	var skel: Skeleton3D = human.find_children("*", "Skeleton3D", true, false)[0]

	var cam := Camera3D.new()
	cam.fov = 35.0
	view.add_child(cam)
	cam.look_at_from_position(Vector3(1.7, 1.1, 2.9), Vector3(0, 0.85, 0))
	var light := DirectionalLight3D.new()
	view.add_child(light)
	light.rotation_degrees = Vector3(-40, 30, 0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.78, 0.82)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.65, 0.8)
	env.environment.ambient_light_energy = 0.25
	view.add_child(env)

	var sheet := Image.create(TILE.x * 3, TILE.y * 2, false, Image.FORMAT_RGBA8)
	for i in SHOTS.size():
		var anim: String = SHOTS[i][0]
		player.play(anim)
		player.seek(SHOTS[i][1] * player.current_animation_length, true)
		player.pause()
		for f in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := view.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((i % 3) * TILE.x, (i / 3) * TILE.y))
		var foot_y := minf(_bone_y(skel, "LeftToes"), _bone_y(skel, "RightToes"))
		print("%s t=%.1f | cadera y=%.2f | cabeza y=%.2f | pie mas bajo y=%.2f" % [anim, SHOTS[i][1], _bone_y(skel, "Hips"), _bone_y(skel, "Head"), foot_y])
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path("res://../capturas"))
	sheet.save_png(ProjectSettings.globalize_path("res://../capturas/animaciones.png"))
	print("GUARDADO capturas/animaciones.png")
	source.free()
	quit()

func _bone_y(skel: Skeleton3D, bone: String) -> float:
	return (skel.global_transform * skel.get_bone_global_pose(skel.find_bone(bone))).origin.y
