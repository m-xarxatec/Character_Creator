extends SceneTree
# Paso 0.4: comprueba que el .glb se abre y que su esqueleto encaja con el perfil humanoide.
# Uso: godot --headless --path pruebas/paso_0_4/proyecto -s comprobar.gd

func _init() -> void:
	var scene: Node = load("res://humano.glb").instantiate()
	var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var mesh: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var box := mesh.get_aabb()
	print("HUESOS: ", skel.get_bone_count())
	print("ALTURA (m): ", snappedf(box.size.y, 0.001), "  pies en y=", snappedf(box.position.y, 0.001))
	print("ANCHO x: ", snappedf(box.size.x, 0.001), "  FONDO z: ", snappedf(box.size.z, 0.001))
	# La mano izquierda del personaje debe estar en +X si mira a +Z.
	var hand_l := skel.get_bone_global_rest(skel.find_bone("hand_l")).origin
	var ball_l := skel.get_bone_global_rest(skel.find_bone("ball_l")).origin
	var foot_l := skel.get_bone_global_rest(skel.find_bone("foot_l")).origin
	print("hand_l: ", hand_l, "  punta del pie - talon (z): ", snappedf(ball_l.z - foot_l.z, 0.001))
	# Pesos: 4 u 8 influencias por vertice.
	var arr := mesh.mesh.surface_get_arrays(0)
	var n_verts: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := weights.size() / n_verts
	var worst := 0.0
	for v in n_verts:
		var sum := 0.0
		for i in per:
			sum += weights[v * per + i]
		worst = maxf(worst, absf(sum - 1.0))
	print("VERTICES: ", n_verts, "  influencias por vertice: ", per, "  peor desvio de suma 1: ", worst)
	var profile := SkeletonProfileHumanoid.new()
	print("PERFIL HUMANOIDE: ", profile.bone_size, " huesos")
	scene.free()
	quit()
