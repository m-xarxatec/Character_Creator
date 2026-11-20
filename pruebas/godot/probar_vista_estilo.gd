extends SceneTree
# Paso 4.6: la vista enseña el maniquí con las normales del estilo (godot/app/style_view.gd). Sin ventana.
# Paso OPT.2: al dejar quieto un deslizador se recalcula en un hilo (refresh_async). Detecta el fallo: sin mirar _generation.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_vista_estilo.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')

const SAME := 0.00001  # metros
const SAME_DEG := 0.1  # mismo criterio que probar_normales_estilo.gd
const MAIN_MS := 20  # PROVISIONAL (paso OPT.2): lo que refresh_async deja al hilo principal (formas ya en caché)
const THREAD_WAIT := 3.0  # s: tope para esperar al hilo

var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var view: SubViewportContainer = load(root_dir.path_join("godot/app/body_view.gd")).new()
	root.add_child(view)
	await process_frame
	check("carga sin error", view.error == "", view.error)
	if view.error == "":
		await _check_style(view, root_dir)
	view.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_style(view, root_dir: String) -> void:
	var style: MeshInstance3D = view.style
	var source: MeshInstance3D = view.species.mesh
	check("al cargar se ve la copia con estilo", style.visible and not source.visible)
	check("mismo esqueleto, piel y material", style.get_node(style.skeleton) == view.species.skeleton
		and style.skin == source.skin and style.material_override == source.material_override)
	print("  MEDIDA cálculo al cargar: %d ms" % style.last_ms)
	_check_arrays("preset", view, root_dir)

	var preset: Dictionary = view.values.duplicate()
	var scaled := preset.duplicate()
	scaled["head_size"] = 1.0
	view.set_values(scaled)
	check("Proporción: la copia sigue a la vista, sin recalcular", style.visible and view.restyle_timer.is_stopped())
	view.set_pose_t(true)
	check("pose T: la copia sigue a la vista, sin recalcular", style.visible and view.restyle_timer.is_stopped())
	view.set_pose_t(false)

	var key := _shape_key(view)
	check("hay un deslizador de Forma", key != "")
	if key == "":
		return
	var shaped := preset.duplicate()
	shaped[key] = 1.0
	view.set_values(shaped)
	check("Forma '%s': mientras cambia se ve la malla original" % key, source.visible and not style.visible)
	check("y el temporizador está en marcha", not view.restyle_timer.is_stopped())
	var old_mesh := style.mesh
	await create_timer(view.RESTYLE_WAIT).timeout
	var waited := await _wait_thread(style)  # paso OPT.2: el recálculo va en un hilo
	check("al dejarlo quieto vuelve la copia, recalculada (en un hilo)", style.visible and not source.visible
		and style.mesh != old_mesh, "%d ms" % waited)
	print("  MEDIDA recálculo en el hilo: %d ms" % style.last_ms)
	_check_arrays("forma cambiada", view, root_dir)
	var moved := _max_distance(style.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], old_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	check("la forma ha movido la copia", moved > 0.001, "%.4f m" % moved)
	view.set_values(preset)
	check("volver al preset: original a la vista hasta recalcular", source.visible)
	view.restyle_timer.stop()
	var start := Time.get_ticks_usec()
	style.refresh_async()
	var call_ms := (Time.get_ticks_usec() - start) / 1000.0
	print("  MEDIDA refresh_async en el hilo principal: %.1f ms" % call_ms)
	check("refresh_async apenas ocupa el hilo principal (< %d ms)" % MAIN_MS, call_ms < MAIN_MS, "%.1f ms" % call_ms)
	view.set_values(shaped)  # cambia antes de que acabe el hilo: su resultado ya no vale
	view.restyle_timer.stop()
	style.refresh()
	await _wait_thread(style)
	check("si cambia a mitad, el resultado viejo del hilo no pisa al nuevo", style.visible
		and style._weights == style._shape_weights())



## Espera a que el hilo de StyleView termine (o THREAD_WAIT); devuelve los ms esperados.
func _wait_thread(style) -> int:
	var start := Time.get_ticks_msec()
	while not style._tasks.is_empty() and Time.get_ticks_msec() - start < THREAD_WAIT * 1000.0:
		await process_frame
	await process_frame
	return Time.get_ticks_msec() - start

## La copia = la malla original con sus formas aplicadas + StyleNormals.apply, y lo demás igual.
func _check_arrays(label: String, view, root_dir: String) -> void:
	var MeshBaker = load(root_dir.path_join("godot/addons/creador/mesh_baker.gd"))
	var StyleNormals = load(root_dir.path_join("godot/addons/creador/style_normals.gd"))
	var source: MeshInstance3D = view.species.mesh
	var arrays := source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	MeshBaker._add_shapes(source, vertices, normals)
	var expected: PackedVector3Array = StyleNormals.apply(vertices, normals, arrays[Mesh.ARRAY_INDEX],
		StyleNormals.head_weights(arrays, source.skin, view.species.skeleton))
	var styled: Array = view.style.mesh.surface_get_arrays(0)
	var distance := _max_distance(styled[Mesh.ARRAY_VERTEX], vertices)
	check("%s: vértices = original con formas" % label, distance < SAME, "%.7f m" % distance)
	var angle := _max_angle(styled[Mesh.ARRAY_NORMAL], expected)
	check("%s: normales = StyleNormals" % label, angle < SAME_DEG, "%.6f°" % angle)
	var plain := _max_angle(styled[Mesh.ARRAY_NORMAL], normals)
	check("%s: y no son las de la malla sin estilo" % label, plain > 5.0, "%.1f°" % plain)
	check("%s: mismos índices, huesos, pesos y color" % label, styled[Mesh.ARRAY_INDEX] == arrays[Mesh.ARRAY_INDEX]
		and styled[Mesh.ARRAY_BONES] == arrays[Mesh.ARRAY_BONES] and styled[Mesh.ARRAY_WEIGHTS] == arrays[Mesh.ARRAY_WEIGHTS]
		and styled[Mesh.ARRAY_COLOR] == arrays[Mesh.ARRAY_COLOR])
	check("%s: la copia no tiene formas" % label, view.style.mesh.get_blend_shape_count() == 0)


## Un deslizador de Forma: el primero que, al máximo, cambia algún peso de forma.
func _shape_key(view) -> String:
	var source: MeshInstance3D = view.species.mesh
	var preset: Dictionary = view.values.duplicate()
	var before := _weights(source)
	for key: String in preset:
		var changed := preset.duplicate()
		changed[key] = 1.0
		view.set_values(changed)
		var differs := _weights(source) != before
		view.set_values(preset)
		if differs:
			return key
	return ""


func _weights(mesh: MeshInstance3D) -> Array:
	var weights := []
	for shape in mesh.mesh.get_blend_shape_count():
		weights.append(mesh.get_blend_shape_value(shape))
	return weights


func _max_distance(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var worst := INF if a.size() != b.size() else 0.0
	for i in mini(a.size(), b.size()):
		worst = maxf(worst, a[i].distance_to(b[i]))
	return worst


func _max_angle(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var worst := INF if a.size() != b.size() else 0.0
	for i in mini(a.size(), b.size()):
		worst = maxf(worst, rad_to_deg(a[i].normalized().angle_to(b[i].normalized())))
	return worst
