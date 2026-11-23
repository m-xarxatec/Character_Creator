extends SceneTree
# Paso 4.2: vista 3D del maniquí (godot/app/body_view.gd) y cámara orbital (orbit_camera.gd). Sin ventana.
# Borra user://ajustes.cfg al terminar: girar la cámara guarda la pista como vista (IU.10a).
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_vista.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')

const SAME := 0.00001

var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var view: SubViewportContainer = load(root_dir.path_join("godot/app/body_view.gd")).new()
	root.add_child(view)
	await process_frame
	check("carga datos/humana y el preset sin error", view.error == "", view.error)
	print("  MEDIDA carga del maniquí: %d ms" % view.load_ms)
	if view.error == "":
		check("el maniquí está en la escena", view.species.scene.is_inside_tree())
		_check_camera(view.camera)
		_check_live(view)
	view.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ajustes.cfg"))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_camera(camera) -> void:
	var front: Vector3 = camera.position - camera.target
	check("empieza de frente (delante, en +Z)", front.z > 0 and absf(front.x) < SAME, str(front))
	camera.rotate_by(Vector2(-225, 0))  # 90° a un lado
	var side: Vector3 = camera.position - camera.target
	check("arrastrar en x gira 90° alrededor", absf(side.z) < 0.001 and side.x > 0, str(side))
	check("sigue mirando al maniquí", camera.global_transform.basis.z.dot(side.normalized()) > 0.9999)
	camera.rotate_by(Vector2(0, 10000))
	check("ángulo vertical limitado arriba", camera.pitch == camera.MAX_PITCH, str(camera.pitch))
	camera.rotate_by(Vector2(0, -10000))
	check("ángulo vertical limitado abajo", camera.pitch == camera.MIN_PITCH, str(camera.pitch))
	camera.zoom_by(100)
	var far: float = (camera.position - camera.target).length()
	check("zoom limitado lejos", absf(far - camera.MAX_DISTANCE) < 0.001, str(far))
	camera.zoom_by(-100)
	var near: float = (camera.position - camera.target).length()
	check("zoom limitado cerca", absf(near - camera.MIN_DISTANCE) < 0.001, str(near))


func _check_live(view) -> void:
	var skeleton: Skeleton3D = view.species.skeleton
	var head := skeleton.find_bone("Head")
	var preset: Dictionary = view.values.duplicate()
	var before := _poses(skeleton)
	var changed := preset.duplicate()
	changed["head_size"] = 1.0
	check("set_values acepta todas las claves", view.set_values(changed).is_empty())
	var scale := skeleton.get_bone_pose_scale(head)
	check("cabeza al máximo: escala 2,5", scale.is_equal_approx(Vector3.ONE * 2.5), str(scale))
	view.set_values(preset)
	check("volver al preset deja el esqueleto igual", _poses(skeleton) == before)


func _poses(skeleton: Skeleton3D) -> Array:
	var poses := []
	for bone in skeleton.get_bone_count():
		poses.append(skeleton.get_bone_pose(bone))
	return poses
