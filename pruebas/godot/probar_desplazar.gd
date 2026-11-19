extends SceneTree
# Paso P.8a: Ctrl + arrastrar desplaza la cámara en el plano de la pantalla, sin girarla (godot/app/orbit_camera.gd).
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_desplazar.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en _place, mirar a target en vez de a target + pan -> la cámara gira al desplazar.

const EPS := 1e-4
const DRAG_PX := 20  # sin ventana la vista es pequeña: 20 px no llegan a MAX_PAN

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var camera: Camera3D = load(godot_dir.path_join("app/orbit_camera.gd")).new()
	root.add_child(camera)
	await process_frame
	camera.snap()
	var basis_before: Basis = camera.basis
	var position_before: Vector3 = camera.position
	var angles := Vector2(camera.yaw, camera.pitch)
	camera.pan_by(Vector2(DRAG_PX, 0))
	var moved: Vector3 = camera.position - position_before
	check("desplazar no gira la cámara (misma orientación, mismo yaw y pitch)",
		camera.basis.is_equal_approx(basis_before) and Vector2(camera.yaw, camera.pitch) == angles)
	check("arrastrar a la derecha mueve la cámara a su izquierda", moved.dot(basis_before.x) < -EPS, str(moved))
	check("la cámara y el punto mirado se mueven lo mismo", moved.is_equal_approx(camera.pan), str(camera.pan))
	var height: float = camera.get_viewport().get_visible_rect().size.y
	var expected: float = DRAG_PX * 2.0 * camera.distance * tan(deg_to_rad(camera.fov) / 2.0) / height
	check("lo que hay bajo el ratón lo sigue (%.4f m por %d px)" % [expected, DRAG_PX], absf(moved.length() - expected) < EPS,
		"%.4f" % moved.length())

	camera.recenter()
	camera.snap()
	camera._unhandled_input(_drag(Vector2(0, 50), true))
	check("arrastre con Ctrl: desplaza hacia arriba sin girar", camera.pan.dot(basis_before.y) > EPS
		and Vector2(camera.yaw, camera.pitch) == angles)
	var pan_before: Vector3 = camera.pan
	camera._unhandled_input(_drag(Vector2(40, 0), false))
	check("arrastre sin Ctrl: gira como siempre y no desplaza", camera.yaw != angles.x and camera.pan == pan_before)

	camera.frame(AABB(Vector3(-0.3, 0, -0.2), Vector3(0.6, 1.2, 0.4)), 1.5)
	camera.snap()
	check("encuadrar de nuevo conserva el desplazamiento", camera.pan == pan_before)
	camera.pan_by(Vector2(100000, 0))
	check("no pasa de MAX_PAN", camera.pan.length() <= camera.MAX_PAN + EPS, "%.3f" % camera.pan.length())
	var key := InputEventKey.new()
	key.keycode = KEY_HOME
	key.pressed = true
	camera._unhandled_input(key)
	check("Inicio vuelve a centrar", camera.pan == Vector3.ZERO)
	camera.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _drag(relative: Vector2, ctrl: bool) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.ctrl_pressed = ctrl
	return event


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
