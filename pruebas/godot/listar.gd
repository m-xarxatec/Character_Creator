extends SceneTree
# Lista huesos y animaciones de un .glb. Uso: godot --headless --path . -s listar.gd -- res://archivo.glb

func _init() -> void:
	var path := OS.get_cmdline_user_args()[0]
	var scene: Node = load(path).instantiate()
	var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var names: PackedStringArray = []
	for i in skel.get_bone_count():
		names.append(skel.get_bone_name(i))
	print("HUESOS ", names.size(), ": ", ",".join(names))
	for p: AnimationPlayer in scene.find_children("*", "AnimationPlayer", true, false):
		print("ANIMACIONES ", p.get_animation_list().size(), ": ", ",".join(p.get_animation_list()))
	scene.free()
	quit()
