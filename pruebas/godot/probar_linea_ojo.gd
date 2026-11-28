extends SceneTree
# Paso AC.6a: líneas del ojo (tiras de ojos.json en EyeMesh, eye_line.gdshader). En el estado anime y en los 10 extremos de
# Ojos: la fila 0 de las líneas sigue al lazo; ningún vértice de las tiras queda bajo la primera superficie visible (piel o
# blanco) más que su depth_pull; el grosor de la línea de abajo no cambia más de ±15 %. Al doblar cuello y cabeza, MEDIDA.
# El bloque común de eye_line es el de toon_soft (SH.2b), sin EMISSION.
# Con ventana (el grosor se mide en una captura).
# Uso: (ulimit -v 4000000; timeout 600 godot [--rendering-method mobile] --path pruebas/godot -s probar_linea_ojo.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: hundir 1 mm una fila (EyeMesh._strip_mesh); tiras sin formas; las filas de dentro de la línea de
# abajo sin sus formas (como las filas rectas del prototipo, que la engordaban).

const SLIDERS := ["eye_size", "eye_spacing", "eye_position", "eye_tall", "eye_corner"]
const STRIPS := {"tira_superior": "linea", "tira_inferior": "linea_inferior", "pliegue": "pliegue"}
const MAX_FOLLOW_MM := 0.05  # PROVISIONAL (ficha AC.3b §6): tira–lazo
const MIN_HEIGHT_MM := -0.18  # PROVISIONAL (ficha AC.3b §6): su depth_pull
const MAX_WIDTH_CHANGE := 0.15  # PROVISIONAL (ficha AC.3b §6): grosor de la línea de abajo, ±15 % del de anime
const WIDTH_U := [0.5, 0.76]  # columnas de la línea de abajo en las que se mide el grosor (0,76 = su pico)
const RAY_FROM := 0.005  # metros: el rayo de altura empieza 5 mm por delante
const SKIN_RADIUS := 0.03  # metros: piel alrededor del ojo
const CELL := 0.0005  # metros: rejilla de triángulos para los rayos
const SHOT := Vector2i(400, 400)
const SHOT_SIZE := 0.004  # metros: alto de la cámara ortogonal (0,01 mm por píxel)
const BEND_DEGREES := 25.0
const MM := 1000.0  # Geometry3D.ray_intersects_triangle descarta triángulos de 1 mm (margen de 1e-5): se trabaja en mm
const CULL_MARGIN := 0.05  # metros: la caja de la tira es la del reposo; con la cámara de 4 mm, Godot la recortaría
const WARMUP := 30  # fotogramas antes de la primera captura (el shader tiene que estar listo)

var repo: String
var species
var updater
var mesh_baker
var values: Dictionary
var pieces: Array[MeshInstance3D] = []
var checked_winding := false
var head_turn := Basis.IDENTITY
var view: Dictionary  # la vista de la línea de abajo (se crea una vez: mover mallas con esqueleto de viewport las deja sin dibujar)  # giro de la cabeza respecto al reposo (solo al doblarla)
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	mesh_baker = load(repo.path_join("godot/addons/creador/mesh_baker.gd"))
	species = load(repo.path_join("godot/addons/creador/species_data.gd")).new()
	if species.load_folder(repo.path_join("godot/datos/humana")):
		_check(false, "la especie no carga: " + species.error)
		_finish()
		return
	root.add_child(species.scene)
	var preset = load(repo.path_join("godot/addons/creador/preset.gd")).from_text(species.preset_text(), species.manifest["species"], species.sliders)
	values = preset["valores"]
	updater = load(repo.path_join("godot/addons/creador/character_updater.gd")).new(species)
	load(repo.path_join("godot/addons/creador/body_material.gd")).apply(species.mesh)
	pieces = load(repo.path_join("godot/addons/creador/eye_mesh.gd")).build(species.mesh, species.skeleton, species.eyes)
	pieces.assign(pieces.filter(func(n: Node) -> bool: return not String(n.name).begins_with("ceja_")))  # AC.6c: las cejas, en probar_cejas.gd
	for piece in pieces:
		updater.pieces.append(piece)
	_check_shader()
	_check(pieces.size() == 8, "dos capas y seis líneas (%d)" % pieces.size())
	if pieces.size() == 8:
		_run()
	else:
		_finish()


func _run() -> void:
	var follow := 0.0
	var lowest := INF
	var lowest_at := ""
	var widths := {}
	view = await _view()
	for state: Array in _states():
		updater.update(state[1], false)
		var baked := _bake()
		follow = maxf(follow, _follow(baked))
		var height := _lowest(baked)
		if height < lowest:
			lowest = height
			lowest_at = state[0]
		widths[state[0]] = await _widths(baked)
		print("MEDIDA %s: tira-lazo %.4f mm; altura mínima %.3f mm; grosor de la línea de abajo %s mm" % [state[0],
			_follow(baked) * 1000.0, height * 1000.0, ", ".join(widths[state[0]].map(func(w: float) -> String: return "%.3f" % (w * 1000.0)))])
	_restore(view)
	_check(follow * 1000.0 <= MAX_FOLLOW_MM, "la fila 0 de las líneas sigue al lazo (%.4f mm)" % (follow * 1000.0))
	_check(lowest * 1000.0 >= MIN_HEIGHT_MM, "ninguna tira queda bajo la piel o el blanco (%.3f mm en %s)" % [lowest * 1000.0, lowest_at])
	var worst := 0.0
	for key: String in widths:
		for c in WIDTH_U.size():
			worst = maxf(worst, absf(widths[key][c] / widths["anime"][c] - 1.0))
	print("MEDIDA grosor de la línea de abajo: cambio máximo %.1f %%" % (worst * 100.0))
	_check(worst <= MAX_WIDTH_CHANGE, "el grosor de la línea de abajo no cambia más de ±15 %")
	_bend()
	_finish()


func _finish() -> void:
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, text: String) -> bool:
	print(("  bien  " if ok else "  FALLO ") + text)
	if not ok:
		failures += 1
	return ok


func _check_shader() -> void:
	var own := FileAccess.get_file_as_string(repo.path_join("godot/addons/creador/eye_line.gdshader"))
	var soft := FileAccess.get_file_as_string(repo.path_join("godot/addons/creador/toon_soft.gdshader"))
	_check(_common_text(own).contains("void light()") and _common_text(own) == _common_text(soft),
		"bloque común de eye_line igual al de toon_soft")
	_check(not own.contains("EMISSION"), "eye_line sin EMISSION")


func _common_text(code: String) -> String:
	var start := code.find("// ==== Común")
	var end := code.find("// ==== Fin del común")
	return code.substr(start, end - start) if start >= 0 and end > start else ""


## [nombre, valores]: el estado anime y los 10 extremos de Ojos.
func _states() -> Array:
	var out := [["anime", values]]
	for key: String in SLIDERS:
		for value: float in [0.0, 1.0]:
			var state := values.duplicate()
			state[key] = value
			out.append(["%s_%d" % [key, value], state])
	return out


## Vértices horneados del cuerpo y de cada pieza (por nombre).
func _bake() -> Dictionary:
	var out := {"cuerpo": mesh_baker.bake(species.mesh, species.skeleton)}
	for piece in pieces:
		out[String(piece.name)] = mesh_baker.bake(piece, species.skeleton)
	return out


## Mayor distancia entre la fila 0 de las líneas (sin la cola) y su vértice del lazo.
func _follow(baked: Dictionary) -> float:
	var body: PackedVector3Array = baked["cuerpo"]["vertices"]
	var worst := 0.0
	for side: String in ["l", "r"]:
		var eye: Dictionary = species.eyes[side]
		for key: String in ["tira_superior", "tira_inferior"]:
			var strip: Dictionary = eye[key]
			var arc: Array = eye["arco_superior" if key == "tira_superior" else "arco_inferior"]
			var rows := int(strip["filas"])
			var zero := _row_index(strip, 0.0)
			var line: PackedVector3Array = baked["%s_%s" % [STRIPS[key], side]]["vertices"]
			for k in arc.size():
				var rim := body[int(eye["lazo"][int(arc[k])])]
				worst = maxf(worst, line[k * rows + zero].distance_to(rim))
	return worst


func _row_index(strip: Dictionary, row: float) -> int:
	for r in int(strip["filas"]):
		if is_equal_approx(float(strip["uv"][r][1]), row):
			return r
	return -1


## Altura mínima de los vértices de las tiras sobre la primera superficie visible (piel o blanco), por la normal del ojo.
func _lowest(baked: Dictionary) -> float:
	var lowest := INF
	for side: String in ["l", "r"]:
		var normal := _eye_normal(side)
		var grid := _grid(baked, side, normal)
		for key: String in STRIPS:
			for p: Vector3 in baked["%s_%s" % [STRIPS[key], side]]["vertices"]:
				var hit := _first_hit(p + normal * RAY_FROM, -normal, grid)
				if hit < INF:
					lowest = minf(lowest, hit - RAY_FROM)  # negativa: una superficie queda por delante del vértice
	return lowest


## Normal del ojo (la de ojos.json, con la que Blender apoya las tiras), girada con la cabeza si se ha doblado.
func _eye_normal(side: String) -> Vector3:
	var eye: Dictionary = species.eyes[side]
	return head_turn * Vector3(eye["normal"][0], eye["normal"][1], eye["normal"][2])


## Triángulos visibles alrededor del ojo (piel del cuerpo y blanco), en una rejilla sobre el plano del ojo.
func _grid(baked: Dictionary, side: String, normal: Vector3) -> Dictionary:
	var eye: Dictionary = species.eyes[side]
	var center := Vector3.ZERO  # el del lazo horneado (al doblar la cabeza, el de ojos.json queda lejos)
	for v: float in eye["lazo"]:
		center += baked["cuerpo"]["vertices"][int(v)] / eye["lazo"].size()
	var across := Vector3.UP.cross(normal).normalized()
	var up := normal.cross(across)
	var cells := {}
	var agree := [0, 0]  # caras cuya normal por orden coincide con la de sus vértices (comprueba el convenio)
	var sources := [[baked["cuerpo"], species.mesh], [baked["ojo_" + side], pieces.filter(func(n): return n.name == "ojo_" + side)[0]]]
	for source: Array in sources:
		var vertices: PackedVector3Array = source[0]["vertices"]
		var normals: PackedVector3Array = source[0]["normals"]
		var indices: PackedInt32Array = (source[1] as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var a := vertices[indices[t]]
			if a.distance_to(center) > SKIN_RADIUS:
				continue
			var b := vertices[indices[t + 1]]
			var c := vertices[indices[t + 2]]
			var face := (c - a).cross(b - a).normalized()  # delantera por el orden de los vértices (Godot: horario; cull_back)
			agree[0] += 1 if face.dot(normals[indices[t]] + normals[indices[t + 1]] + normals[indices[t + 2]]) > 0.0 else 0
			agree[1] += 1
			var low := Vector2(INF, INF)
			var high := Vector2(-INF, -INF)
			for q: Vector3 in [a, b, c]:
				var flat := Vector2(q.dot(across), q.dot(up)) / CELL
				low = low.min(flat)
				high = high.max(flat)
			for x in range(floori(low.x), floori(high.x) + 1):
				for y in range(floori(low.y), floori(high.y) + 1):
					var key := Vector2i(x, y)
					if not cells.has(key):
						cells[key] = []
					cells[key].append([a, b, c, face])
	if side == "l" and head_turn == Basis.IDENTITY and not checked_winding:
		checked_winding = true
		print("MEDIDA caras con la normal por orden igual a la de sus vértices: %d de %d" % agree)
	return {"cells": cells, "across": across, "up": up}


## Distancia al primer triángulo de cara al rayo (INF si no toca ninguno).
func _first_hit(from: Vector3, direction: Vector3, grid: Dictionary) -> float:
	var key := Vector2i(floori(from.dot(grid["across"]) / CELL), floori(from.dot(grid["up"]) / CELL))
	var best := INF
	for tri: Array in grid["cells"].get(key, []):
		if (tri[3] as Vector3).dot(direction) >= 0.0:
			continue  # de espaldas: desde fuera no se ve
		var hit: Variant = Geometry3D.ray_intersects_triangle(from * MM, direction, tri[0] * MM, tri[1] * MM, tri[2] * MM)
		if hit != null:
			best = minf(best, (from * MM).distance_to(hit) / MM)
	return best


## Grosor (m) de la línea de abajo del ojo izquierdo en las columnas WIDTH_U, medido en una captura ortogonal de frente.
func _widths(baked: Dictionary) -> Array:
	var eye: Dictionary = species.eyes["l"]
	var strip: Dictionary = eye["tira_inferior"]
	var rows := int(strip["filas"])
	var normal := Vector3(eye["normal"][0], eye["normal"][1], eye["normal"][2])
	var line: PackedVector3Array = baked["linea_inferior_l"]["vertices"]
	var out := []
	for u: float in WIDTH_U:
		var column := _column(strip, u)
		var inner := line[column * rows]
		var outer := line[column * rows + rows - 1]
		var middle := line[column * rows + _row_index(strip, 0.0)]
		view["camera"].look_at_from_position(middle + normal * 0.05, middle, Vector3.UP)
		var image: Image = await _shot(view["viewport"])
		var a: Vector2 = view["camera"].unproject_position(inner)
		var b: Vector2 = view["camera"].unproject_position(outer)
		var covered := 0
		var steps := int(a.distance_to(b) * 4.0)
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps)
			if Rect2(Vector2.ZERO, SHOT).has_point(p) and image.get_pixelv(Vector2i(p)).a > 0.5:
				covered += 1
		var meters_per_px: float = SHOT_SIZE / SHOT.y
		out.append(covered * (a.distance_to(b) / steps) * meters_per_px)
	return out


func _column(strip: Dictionary, u: float) -> int:
	var rows := int(strip["filas"])
	var best := 0
	for k in strip["uv"].size() / rows:
		if absf(float(strip["uv"][k * rows][0]) - u) < absf(float(strip["uv"][best * rows][0]) - u):
			best = k
	return best


## Vista solo con la línea de abajo del ojo izquierdo, cámara ortogonal y una luz de frente.
func _view() -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = SHOT
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	species.scene.reparent(viewport, false)
	for node in species.skeleton.get_children():
		if node is MeshInstance3D:
			node.visible = node.name == "linea_inferior_l"
			node.extra_cull_margin = CULL_MARGIN if node.visible else 0.0
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = SHOT_SIZE
	camera.near = 0.001
	viewport.add_child(camera)
	viewport.add_child(DirectionalLight3D.new())
	for i in WARMUP:
		await process_frame
	return {"viewport": viewport, "camera": camera}


func _restore(view: Dictionary) -> void:
	species.scene.reparent(root, false)
	for node in species.skeleton.get_children():
		if node is MeshInstance3D:
			node.visible = true
			node.extra_cull_margin = 0.0
	view["viewport"].queue_free()


func _shot(viewport: SubViewport) -> Image:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBAF)
	return image


## Cuello y cabeza doblados BEND_DEGREES hacia delante, en el estado anime: separación tira–lazo (solo MEDIDA).
func _bend() -> void:
	updater.update(values, false)
	var skeleton: Skeleton3D = species.skeleton
	var head := skeleton.find_bone("Head")
	var rest: Basis = mesh_baker.global_poses(skeleton)[head].basis
	for bone_name: String in ["Neck", "Head"]:
		var bone := skeleton.find_bone(bone_name)
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(Vector3.RIGHT, deg_to_rad(BEND_DEGREES)))
	head_turn = (mesh_baker.global_poses(skeleton)[head].basis * rest.inverse()).orthonormalized()
	var baked := _bake()
	print("MEDIDA cuello y cabeza doblados %d°: tira-lazo %.4f mm; altura mínima %.3f mm" % [BEND_DEGREES, _follow(baked) * 1000.0, _lowest(baked) * 1000.0])
	skeleton.reset_bone_poses()
	head_turn = Basis.IDENTITY
