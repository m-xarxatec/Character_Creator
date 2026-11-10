extends SceneTree
# Paso 2.3: con todas las formas de datos/ activas, el maniquí se mueve fluido al arrastrar un deslizador.
# Necesita ventana (no --headless): sin ella Godot no usa la tarjeta gráfica.
# Uso: godot --path pruebas/godot -s probar_rendimiento.gd -- <ruta a cuerpo.glb> 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'
# Simula arrastrar "Músculo" de 0 a 1 y vuelta. Peor caso: todas las demás formas a 0,3 (también _decr e _incr
# a la vez, cosa que el editor no hará), para que entren todas las correcciones.

const WARMUP := 60  # fotogramas que no se miden (carga de shaders)
const FRAMES := 600
const MAX_AVERAGE_MS := 1000.0 / 60.0  # media de 60 fps o más
const MAX_P99_MS := 1000.0 / 30.0  # y casi ningún tirón por debajo de 30 fps
const DRAGGED := "muscle"

var mesh: MeshInstance3D
var times: Array[float] = []
var last_usec := 0
var frame := 0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # medir lo que da de sí, no los 60 Hz
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(OS.get_cmdline_user_args()[0], state) != OK:
		print("ERROR: no se pudo abrir el .glb")
		quit(1)
		return
	var scene := doc.generate_scene(state)
	root.add_child(scene)
	mesh = scene.find_children("*", "MeshInstance3D", true, false)[0]
	_add_camera_and_light()
	process_frame.connect(_on_frame)


func _add_camera_and_light() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0.9, 2.6)
	root.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	root.add_child(light)


func _on_frame() -> void:
	var now := Time.get_ticks_usec()
	if frame > WARMUP:
		times.append((now - last_usec) / 1000.0)
	last_usec = now
	frame += 1
	_drag_slider(0.5 + 0.5 * sin(frame * 0.05))
	if frame > WARMUP + FRAMES:
		_report()


# Pesos como en datos/FORMATO.md: macros con decr/incr, correcciones = producto de sus partes.
func _drag_slider(value: float) -> void:
	var weights := {}
	var count := mesh.get_blend_shape_count()
	for i in count:
		var name := String(mesh.mesh.get_blend_shape_name(i))
		if not "*" in name:
			weights[name] = 0.3
	weights[DRAGGED + "_decr"] = maxf(0.0, 1.0 - 2.0 * value)
	weights[DRAGGED + "_incr"] = maxf(0.0, 2.0 * value - 1.0)
	for i in count:
		var name := String(mesh.mesh.get_blend_shape_name(i))
		var weight := 1.0
		for part in name.split("*"):
			weight *= weights.get(part, 0.0)
		mesh.set_blend_shape_value(i, weight)


func _report() -> void:
	process_frame.disconnect(_on_frame)
	times.sort()
	var average: float = times.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / times.size()
	var p99: float = times[int(times.size() * 0.99)]
	print("formas: %d, tarjeta: %s" % [mesh.get_blend_shape_count(), RenderingServer.get_video_adapter_name()])
	print("media %.2f ms (%.0f fps), p99 %.2f ms, peor %.2f ms" % [average, 1000.0 / average, p99, times[-1]])
	var ok := average < MAX_AVERAGE_MS and p99 < MAX_P99_MS
	print(("  bien  " if ok else "  FALLO ") + "fluido al arrastrar un deslizador")
	print("RESULTADO: ", "TODO BIEN" if ok else "1 FALLOS")
	quit(0 if ok else 1)
