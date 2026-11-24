extends SceneTree
# Paso AC.3c: la capa del blanco. 730 caras por ojo; capa y cuerpo juntos en los 10 extremos; orden de índices de ojos.json;
# una especie sin ojos.json carga igual; a oscuras no brilla; su bloque común (SH.2b: luz y sombra) es el de toon_soft.
# Con ventana (la prueba a oscuras dibuja).
# Uso: (ulimit -v 4000000; timeout 300 godot [--rendering-method mobile] --path pruebas/godot -s probar_base_ojo.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: el blanco sin formas (EyeMesh._moves devuelve false); EMISSION en eye_layers; borrar ojos.json.

const FACES := 730
const SLIDERS := ["eye_size", "eye_spacing", "eye_position", "eye_tall", "eye_corner"]
const MAX_GAP_MM := 0.001  # PROVISIONAL: capa-cuerpo en los 10 extremos (la ficha pide 0,000 mm)
const MAX_INDEX_MM := 0.01  # ficha §5.4: posición de cada índice frente a la de Blender
const MAX_DARK := 0.01  # ficha §6: canal máximo a oscuras

var repo: String
var species
var updater
var body_material
var eye_mesh
var mesh_baker
var values: Dictionary
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	body_material = load(repo.path_join("godot/addons/creador/body_material.gd"))
	eye_mesh = load(repo.path_join("godot/addons/creador/eye_mesh.gd"))
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
	body_material.apply(species.mesh)
	updater.update(values, false)
	var eyes: Array[MeshInstance3D] = eye_mesh.build(species.mesh, species.skeleton, species.eyes)
	_check(eyes.size() == 2, "una capa por ojo (%d)" % eyes.size())
	if eyes.size() == 2:
		for eye in eyes:
			updater.pieces.append(eye)
		updater.update(values, false)
		_check_faces(eyes)
		_check_order()
		_check_extremes(eyes)
		_check_light()
		await _check_dark(eyes)
	_check_without_eyes()
	_finish()


func _finish() -> void:
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, text: String) -> void:
	print(("  bien  " if ok else "  FALLO ") + text)
	if not ok:
		failures += 1


func _check_faces(eyes: Array[MeshInstance3D]) -> void:
	for eye in eyes:
		var count: int = eye.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
		_check(count == FACES, "%s: %d caras" % [eye.name, count])


## Cada índice de ojos.json debe caer donde lo dejó Blender: uv + centro = posición en el estado anime.
func _check_order() -> void:
	var baked: PackedVector3Array = mesh_baker.bake(species.mesh, species.skeleton)["vertices"]
	var worst := 0.0
	for side: String in ["l", "r"]:
		var eye: Dictionary = species.eyes[side]
		var center := Vector2(eye["centro"][0], eye["centro"][1])
		for n in eye["bolsa"].size():
			var p := baked[int(eye["bolsa"][n])]
			var uv := Vector2(eye["uv"][n][0], eye["uv"][n][1])
			worst = maxf(worst, (Vector2(p.x, p.y) - center - uv).length())
	print("MEDIDA índices de ojos.json frente a Blender: %.5f mm" % (worst * 1000.0))
	_check(worst * 1000.0 <= MAX_INDEX_MM, "Godot conserva el orden de vértices del .glb")


func _check_extremes(eyes: Array[MeshInstance3D]) -> void:
	var worst := 0.0
	for key: String in SLIDERS:
		for value: float in [0.0, 1.0]:
			var state := values.duplicate()
			state[key] = value
			updater.update(state, false)
			var body: PackedVector3Array = mesh_baker.bake(species.mesh, species.skeleton)["vertices"]
			for n in 2:
				var eye: Dictionary = species.eyes["lr"[n]]
				var layer: PackedVector3Array = mesh_baker.bake(eyes[n], species.skeleton)["vertices"]
				for k in layer.size():
					var lift := Vector3(0.0, 0.0, eye["elevacion"][k])
					worst = maxf(worst, (layer[k] - body[int(eye["bolsa"][k])] - lift).length())
	updater.update(values, false)
	print("MEDIDA capa-cuerpo en los 10 extremos: %.5f mm" % (worst * 1000.0))
	_check(worst * 1000.0 <= MAX_GAP_MM, "la capa sigue al cuerpo en los 10 extremos")


func _check_light() -> void:
	var own := FileAccess.get_file_as_string(repo.path_join("godot/addons/creador/eye_layers.gdshader"))
	var soft := FileAccess.get_file_as_string(repo.path_join("godot/addons/creador/toon_soft.gdshader"))
	_check(_common_text(own).contains("void light()") and _common_text(own) == _common_text(soft),
		"bloque común (luz y sombra calculada) igual al de toon_soft")
	_check(not own.contains("EMISSION"), "sin EMISSION")


## SH.2b: el texto entre las marcas «Común» y «Fin del común» ("" si falta alguna).
func _common_text(code: String) -> String:
	var start := code.find("// ==== Común")
	var end := code.find("// ==== Fin del común")
	return code.substr(start, end - start) if start >= 0 and end > start else ""


## Solo la capa, sin luces: no debe verse nada. Con una luz de frente, sí (comprueba que se está dibujando).
func _check_dark(eyes: Array[MeshInstance3D]) -> void:
	species.mesh.visible = false
	var view := SubViewport.new()
	view.size = Vector2i(160, 120)
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	species.scene.reparent(view, false)
	var center := Vector3(species.eyes["l"]["centro"][0], species.eyes["l"]["centro"][1], species.eyes["l"]["centro"][2])
	var camera := Camera3D.new()
	camera.fov = 12.0
	view.add_child(camera)
	camera.position = center + Vector3(0.0, 0.0, 0.3)
	var dark: Array = await _brightest(view)
	var lamp := DirectionalLight3D.new()
	view.add_child(lamp)
	var lit: Array = await _brightest(view)
	print("MEDIDA a oscuras: canal máximo %.4f en %d píxeles; con luz %.3f" % [dark[0], dark[1], lit[0]])
	_check(lit[1] > 200 and lit[0] > 0.5, "la capa se dibuja")
	_check(dark[0] <= MAX_DARK, "a oscuras no brilla")
	species.scene.reparent(root, false)
	view.queue_free()
	species.mesh.visible = true


func _brightest(view: SubViewport) -> Array:
	for i in 6:
		await process_frame
	var image := view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBAF)
	var top := 0.0
	var covered := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a > 0.5:
				covered += 1
				top = maxf(top, maxf(c.r, maxf(c.g, c.b)))
	return [top, covered]


## Una especie sin ojos.json (ni en el manifiesto) carga igual y no tiene capas.
func _check_without_eyes() -> void:
	var source := repo.path_join("godot/datos/humana")
	var copy := OS.get_user_data_dir().path_join("probar_base_ojo/humana")
	DirAccess.make_dir_recursive_absolute(copy.path_join("presets"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("manifiesto.json")))
	manifest["files"].erase("ojos.json")
	for file: String in manifest["files"]:
		DirAccess.copy_absolute(source.path_join(file), copy.path_join(file))
	var out := FileAccess.open(copy.path_join("manifiesto.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(manifest))
	out.close()
	var other = load(repo.path_join("godot/addons/creador/species_data.gd")).new()
	var error: String = other.load_folder(copy)
	_check(error == "", "sin ojos.json carga bien " + error)
	if error == "":
		_check(other.eyes.is_empty(), "sin ojos.json, species.eyes vacío")
		_check(eye_mesh.build(other.mesh, other.skeleton, other.eyes).is_empty(), "sin ojos.json, ninguna capa")
		other.scene.free()
	for file: String in manifest["files"]:
		DirAccess.remove_absolute(copy.path_join(file))
	DirAccess.remove_absolute(copy.path_join("manifiesto.json"))
