extends SceneTree
# Pasos 9.7.2 a 9.7.4: expresiones (formas expr_* de cuerpo.glb; ficha ruta/pasos/9.7_expresiones.md). Sin ventana.
# 9.7.2: CharacterUpdater.update(values, pose_t, expressions): sin expresiones todo a 0; lo desconocido o no numérico se
#   rechaza; «blink» = blinkLeft + blinkRight. Con cada expresión a 1, en la cara anime, en los 10 extremos de Ojos y en
#   10 cuerpos al azar (semilla 38): 0 triángulos de la cabeza invertidos; el parpadeo cierra (hueco ≤ MAX_GAP_MM); la
#   línea de arriba del ojo sigue al lazo (≤ MAX_FOLLOW_MM, como probar_linea_ojo).
# 9.7.3 (D31): el .glb lleva las expresiones como formas VRM (cuerpo y mallas del ojo); probar una en la vista no cambia
#   el archivo; poner una a 1 en el .glb mueve lo mismo que en el editor en pose T (≤ MAX_GLB_MM), también con Ojos ›
#   Alto al máximo (las correcciones del parpadeo).
# 9.7.4: la lista «Expresión» de la barra (body_actions.gd) pone y quita la expresión.
# Uso: (ulimit -v 4000000; timeout 900 godot --headless --path pruebas/godot -s probar_expresiones.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Roturas: en CharacterUpdater, las expr_* fuera de ShapeWeights.weights (se quedan a 0); en CharacterBaker, hornear
# también las expr_* (el .glb cambia al probar una); skinned_deltas con la traslación (el .glb no da lo mismo).

const EXPRESSIONS := ["happy", "angry", "sad", "surprised", "blinkLeft", "blinkRight"]
const FIXES := ["eye_tall_decr", "eye_tall_incr", "eye_size_decr", "eye_size_incr"]
const SLIDERS := ["eye_size", "eye_spacing", "eye_position", "eye_tall", "eye_corner"]
const MAX_GAP_MM := 0.3  # PROVISIONAL (ficha 9.7 §1): hueco entre los arcos del lazo al parpadear
const MAX_FOLLOW_MM := 0.05  # el de probar_linea_ojo.gd: la fila 0 de la línea, sobre el lazo
const MAX_GLB_MM := 0.1  # el de probar_exportar.gd
const RANDOM_BODIES := 10
const SEED := 38

var repo: String
var species
var updater
var mesh_baker: GDScript
var shape_weights: GDScript
var values: Dictionary
var eyes: Array[MeshInstance3D] = []
var head_triangles := PackedInt32Array()
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := repo.path_join("godot/addons/creador")
	mesh_baker = load(addon.path_join("mesh_baker.gd"))
	shape_weights = load(addon.path_join("shape_weights.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(repo.path_join("godot/datos/humana")):
		_check(false, "la especie no carga: " + species.error)
		_finish()
		return
	root.add_child(species.scene)
	values = load(addon.path_join("preset.gd")).from_text(species.preset_text(), species.manifest["species"], species.sliders)["valores"]
	updater = load(addon.path_join("character_updater.gd")).new(species)
	load(addon.path_join("body_material.gd")).apply(species.mesh)
	eyes = load(addon.path_join("eye_mesh.gd")).build(species.mesh, species.skeleton, species.eyes)
	for eye in eyes:
		updater.pieces.append(eye)
	var names: PackedStringArray = shape_weights.shape_names(species.mesh.mesh)
	var wanted := EXPRESSIONS.map(func(e: String) -> String: return "expr_" + e)
	for side: String in ["blinkLeft", "blinkRight"]:
		for fix: String in FIXES:
			wanted.append("expr_%s*%s" % [side, fix])
	var found := Array(names).filter(func(n: String) -> bool: return n.begins_with("expr_"))
	if not _check(found == wanted, "cuerpo.glb trae las %d formas expr_* (si no: regenerar con exportar_datos.py)" % wanted.size()):
		print("  ", found)
		_finish()
		return
	_head_triangles()
	_check_update()
	_check_faces()
	await _check_glb()
	await _check_bar()
	_finish()


func _finish() -> void:
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, text: String) -> bool:
	print(("  bien  " if ok else "  FALLO ") + text)
	if not ok:
		failures += 1
	return ok


func _weight(shape: String) -> float:
	var names: PackedStringArray = shape_weights.shape_names(species.mesh.mesh)
	return species.mesh.get_blend_shape_value(names.find(shape))


## 9.7.2: la llamada de estado completo, los rechazos y «blink».
func _check_update() -> void:
	updater.update(values, false, {"happy": 1.0})
	updater.update(values, false)
	_check(EXPRESSIONS.all(func(e: String) -> bool: return _weight("expr_" + e) == 0.0), "sin expresiones, todas a 0 (y sin estado de antes)")
	var rejected: Array[String] = updater.update(values, false, {"guiño": 1.0, "happy": NAN, "sad": "mucho"})
	_check(rejected.has("guiño") and rejected.has("happy") and rejected.has("sad") and _weight("expr_happy") == 0.0,
		"se rechazan la desconocida, NaN y el texto: %s" % [rejected])
	updater.update(values, false, {"blink": 1.0})
	_check(_weight("expr_blinkLeft") == 1.0 and _weight("expr_blinkRight") == 1.0, "«blink» pone los dos ojos")
	updater.update(values, false, {"surprised": 3.0})
	_check(_weight("expr_surprised") == 1.0, "se recorta a [0, 1]")
	var tall := values.duplicate()
	tall["eye_tall"] = 1.0
	updater.update(tall, false, {"blinkLeft": 1.0})
	_check(is_equal_approx(_weight("expr_blinkLeft*eye_tall_incr"), 1.0) and _weight("expr_blinkRight*eye_tall_incr") == 0.0,
		"la corrección del parpadeo entra con el producto de sus partes")
	updater.update(values, false)


## 9.7.2: cada expresión a 1 sobre muchas caras: sin triángulos invertidos, el parpadeo cierra y la línea sigue al lazo.
func _check_faces() -> void:
	var flipped := 0
	var flipped_at := []
	var gap := 0.0
	var gap_at := ""
	var follow := 0.0
	for state: Array in _states():
		updater.update(state[1], false)
		var neutral: PackedVector3Array = mesh_baker.bake(species.mesh, species.skeleton)["vertices"]
		for e: String in ["happy", "angry", "sad", "surprised", "blink"]:
			updater.update(state[1], false, {e: 1.0})
			var baked: Dictionary = mesh_baker.bake(species.mesh, species.skeleton)
			var n := _inverted(neutral, baked["vertices"])
			if n > 0:
				flipped += n
				flipped_at.append("%s + %s (%d)" % [state[0], e, n])
			if e == "blink":
				var g := _gap(baked["vertices"])
				if g > gap:
					gap = g
					gap_at = state[0]
				follow = maxf(follow, _follow(baked["vertices"]))
	updater.update(values, false)
	_check(flipped == 0, "0 triángulos de la cabeza invertidos con cada expresión %s" % [flipped_at])
	print("MEDIDA parpadeo: hueco máximo entre los arcos del lazo %.3f mm (%s)" % [gap * 1000.0, gap_at])
	_check(gap * 1000.0 <= MAX_GAP_MM, "el parpadeo cierra el ojo (≤ %.1f mm)" % MAX_GAP_MM)
	_check(follow * 1000.0 <= MAX_FOLLOW_MM, "al parpadear, la línea de arriba sigue al lazo (%.4f mm)" % (follow * 1000.0))


## [nombre, valores]: anime, los 10 extremos de Ojos y 10 cuerpos al azar.
func _states() -> Array:
	var out := [["anime", values]]
	for key: String in SLIDERS:
		for value: float in [0.0, 1.0]:
			var state := values.duplicate()
			state[key] = value
			out.append(["%s_%d" % [key, value], state])
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in RANDOM_BODIES:
		var state := values.duplicate()
		for key: String in state:
			state[key] = rng.randf()
		out.append(["azar_%d" % i, state])
	return out


## Triángulos con algún vértice de la cabeza (StyleNormals.head_weights > 0).
func _head_triangles() -> void:
	var arrays: Array = species.mesh.mesh.surface_get_arrays(0)
	var head: PackedFloat32Array = load(repo.path_join("godot/addons/creador/style_normals.gd")).head_weights(arrays,
		species.mesh.skin, species.skeleton)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, indices.size(), 3):
		if head[indices[t]] > 0.0 or head[indices[t + 1]] > 0.0 or head[indices[t + 2]] > 0.0:
			head_triangles.append_array([indices[t], indices[t + 1], indices[t + 2]])


func _inverted(before: PackedVector3Array, after: PackedVector3Array) -> int:
	var count := 0
	for t in range(0, head_triangles.size(), 3):
		var a := head_triangles[t]
		var b := head_triangles[t + 1]
		var c := head_triangles[t + 2]
		var n0 := (before[b] - before[a]).cross(before[c] - before[a])
		var n1 := (after[b] - after[a]).cross(after[c] - after[a])
		if n0.length() > 1e-12 and n0.dot(n1) < 0.0:
			count += 1
	return count


## Mayor distancia de un punto del arco de arriba del lazo (sin las esquinas) al arco de abajo, en los dos ojos.
func _gap(body: PackedVector3Array) -> float:
	var worst := 0.0
	for side: String in ["l", "r"]:
		var eye: Dictionary = species.eyes[side]
		var lower := PackedVector3Array()
		for k: float in eye["arco_inferior"]:
			lower.append(body[int(eye["lazo"][int(k)])])
		var upper: Array = eye["arco_superior"]
		for n in range(1, upper.size() - 1):
			var p := body[int(eye["lazo"][int(upper[n])])]
			var best := INF
			for i in lower.size() - 1:
				best = minf(best, p.distance_to(Geometry3D.get_closest_point_to_segment(p, lower[i], lower[i + 1])))
			worst = maxf(worst, best)
	return worst


## La fila 0 de la línea de arriba (sin la cola) sobre su vértice del lazo, horneadas con la misma pose.
func _follow(body: PackedVector3Array) -> float:
	var worst := 0.0
	for side: String in ["l", "r"]:
		var eye: Dictionary = species.eyes[side]
		var strip: Dictionary = eye["tira_superior"]
		var rows := int(strip["filas"])
		var zero := -1
		for r in rows:
			if is_equal_approx(float(strip["uv"][r][1]), 0.0):
				zero = r
		var line: MeshInstance3D = eyes.filter(func(n: Node) -> bool: return n.name == "linea_" + side)[0]
		var points: PackedVector3Array = mesh_baker.bake(line, species.skeleton)["vertices"]
		var arc: Array = eye["arco_superior"]
		for k in arc.size():
			worst = maxf(worst, points[k * rows + zero].distance_to(body[int(eye["lazo"][int(arc[k])])]))
	return worst


## 9.7.3: el .glb lleva las expresiones como formas, no hornea la que se prueba y mueve lo mismo que el editor.
func _check_glb() -> void:
	var exporter: GDScript = load(repo.path_join("godot/addons/creador/glb_exporter.gd"))
	var material: GDScript = load(repo.path_join("godot/addons/creador/body_material.gd"))
	var folder := OS.get_user_data_dir().path_join("probar_expresiones")
	DirAccess.make_dir_recursive_absolute(folder)
	var tall := values.duplicate()
	tall["eye_tall"] = 1.0
	for body: Array in [["anime", values], ["alto", tall]]:
		updater.update(body[1], false)
		var plain := folder.path_join("%s.glb" % body[0])
		var with_face := folder.path_join("%s_probando.glb" % body[0])
		_check(_export(exporter, material, plain) == OK, "%s: exportar" % body[0])
		updater.update(body[1], false, {"happy": 1.0})
		_check(_export(exporter, material, with_face) == OK, "%s: exportar probando «happy»" % body[0])
		_check(FileAccess.get_sha256(plain) == FileAccess.get_sha256(with_face), "%s: probar una expresión no cambia el .glb" % body[0])
		var scene := _load_glb(plain)
		if not _check(scene != null, "%s: el .glb se lee" % body[0]):
			continue
		root.add_child(scene)
		await process_frame
		var meshes := scene.find_children("*", "MeshInstance3D", true, false)
		var exported: MeshInstance3D = meshes.filter(func(m: Node) -> bool: return m.name == species.mesh.name)[0]
		_check(_names(exported.mesh) == EXPRESSIONS, "%s: el cuerpo lleva las 6 formas VRM %s" % [body[0], _names(exported.mesh)])
		var eye_ok := true
		for m: MeshInstance3D in meshes:
			if m != exported and not _names(m.mesh).all(func(n: String) -> bool: return n in EXPRESSIONS):
				eye_ok = false
		var ojo: Array = meshes.filter(func(m: Node) -> bool: return m.name == "ojo_l")
		_check(eye_ok and not ojo.is_empty() and "blinkLeft" in _names(ojo[0].mesh), "%s: las mallas del ojo llevan las suyas" % body[0])
		var skeleton := scene.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var worst := 0.0
		for e: String in EXPRESSIONS:
			worst = maxf(worst, _compare(body[1], e, exported, skeleton))
		print("MEDIDA %s: expresiones del .glb contra el editor en pose T: máx. %.4f mm" % [body[0], worst * 1000.0])
		_check(worst * 1000.0 <= MAX_GLB_MM, "%s: en el .glb mueven lo mismo que en el editor" % body[0])
		scene.queue_free()
		await process_frame
	updater.update(values, false)


func _export(exporter: GDScript, material: GDScript, path: String) -> Error:
	var character: Node3D = exporter.build(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], true, [], [],
		eyes, species.eyes)
	return exporter.write(character, material.standalone(species.mesh), path)


func _load_glb(path: String) -> Node:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state)


func _names(mesh: Mesh) -> Array:
	var out := []
	for i in mesh.get_blend_shape_count():
		out.append(String(mesh.get_blend_shape_name(i)))
	return out


## Mayor diferencia entre lo que mueve la expresión en el editor (pose T) y en el .glb (la forma a 1).
func _compare(state: Dictionary, e: String, exported: MeshInstance3D, skeleton: Skeleton3D) -> float:
	updater.update(state, true)
	var editor_0: PackedVector3Array = mesh_baker.bake(species.mesh, species.skeleton)["vertices"]
	updater.update(state, true, {e: 1.0})
	var editor_1: PackedVector3Array = mesh_baker.bake(species.mesh, species.skeleton)["vertices"]
	var index := _names(exported.mesh).find(e)
	exported.set_blend_shape_value(index, 0.0)
	var glb_0: PackedVector3Array = mesh_baker.bake(exported, skeleton)["vertices"]
	exported.set_blend_shape_value(index, 1.0)
	var glb_1: PackedVector3Array = mesh_baker.bake(exported, skeleton)["vertices"]
	exported.set_blend_shape_value(index, 0.0)
	updater.update(state, false)
	if glb_0.size() != editor_0.size():
		return INF
	var worst := 0.0
	for i in glb_0.size():
		worst = maxf(worst, ((glb_1[i] - glb_0[i]) - (editor_1[i] - editor_0[i])).length())
	return worst


## 9.7.4: la lista «Expresión» de la barra, en el programa.
func _check_bar() -> void:
	for eye in eyes:
		eye.get_parent().remove_child(eye)
		eye.free()
	eyes.clear()
	species.scene.free()
	var main: Control = load(repo.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame
	var bar = main.body_actions
	var list: OptionButton = bar.expression_list
	_check(list.item_count == 8 and not list.disabled, "la lista tiene «Sin expresión» y las 7 (%d)" % list.item_count)
	var happy := -1
	for i in list.item_count:
		if list.get_item_metadata(i) == "happy":
			happy = i
	bar.set_expression(happy)
	var body: MeshInstance3D = main.body_view.species.mesh
	var names: PackedStringArray = shape_weights.shape_names(body.mesh)
	_check(main.body_view.expression == "happy" and body.get_blend_shape_value(names.find("expr_happy")) == 1.0,
		"elegir «Alegría» la pone en la cara")
	bar.set_expression(0)
	_check(main.body_view.expression == "" and body.get_blend_shape_value(names.find("expr_happy")) == 0.0,
		"«Sin expresión» la quita")
	main.free()
