extends SceneTree
# Maqueta 3.13a-2: ¿las normales de elipsoide del .glb llegan a Godot sin el addon?
# Compara las normales leídas con las enviadas (<archivo>_normales.json), emparejando los vértices por posición.
# Antes: probar_normales_cara.gd (escribe pruebas/fase_3/salida/normales/).
# Uso, leyendo con GLTFDocument:
#   (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_normales_leidas.gd -- ../fase_3/salida/normales/cara.glb 2>&1 | grep -E 'FALLO|RESULTADO|ERROR|bien')
# Con el importador del editor (res://cara.glb en un proyecto vacío): lo lanza pruebas/fase_3/probar_normales_importador.sh.

const LIMIT_DEG := 1.0  # límite inicial de la maqueta
const GRID := 10000.0  # empareja posiciones a 0,1 mm

var failures := 0


func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var scene: Node
	if path.begins_with("res://"):
		scene = (load(path) as PackedScene).instantiate()
	else:
		path = ProjectSettings.globalize_path("res://").path_join(path).simplify_path()
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(path, state) != OK:
			print("ERROR: no se pudo leer ", path)
			quit(1)
			return
		scene = document.generate_scene(state)
	var sent: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.get_basename() + "_normales.json"))
	var by_position := {}
	var positions: Array = sent["positions"]
	var normals: Array = sent["normals"]
	for i in positions.size() / 3:
		var key := Vector3i((Vector3(positions[3 * i], positions[3 * i + 1], positions[3 * i + 2]) * GRID).round())
		if not by_position.has(key):
			by_position[key] = []
		by_position[key].append([Vector3(normals[3 * i], normals[3 * i + 1], normals[3 * i + 2]), sent["head_weight"][i]])

	var instance := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arrays := instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var read: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var missing := 0
	var worst := 0.0
	var total := 0.0
	var head_worst := 0.0
	var head_count := 0
	for i in vertices.size():
		var key := Vector3i((vertices[i] * GRID).round())
		if not by_position.has(key):
			missing += 1
			continue
		var best := INF
		var weight := 0.0
		for candidate: Array in by_position[key]:
			var angle := rad_to_deg(read[i].angle_to(candidate[0]))
			if angle < best:
				best = angle
				weight = candidate[1]
		worst = maxf(worst, best)
		total += best
		if weight > 0.5:
			head_worst = maxf(head_worst, best)
			head_count += 1
	check("todos los vértices tienen pareja", missing == 0, "%d de %d sin pareja" % [missing, vertices.size()])
	check("normales iguales a las enviadas", worst <= LIMIT_DEG,
		"máx. %.4f° / media %.4f° (cabeza: máx. %.4f° en %d vértices; límite %.1f°)" % [
			worst, total / maxi(vertices.size() - missing, 1), head_worst, head_count, LIMIT_DEG])
	scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
