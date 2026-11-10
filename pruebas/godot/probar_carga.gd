extends SceneTree
# Paso 3.1: el núcleo carga datos/humana/ y monta la malla y el esqueleto (species_data.gd).
# Uso: godot --headless --path pruebas/godot -s probar_carga.gd 2>&1 | grep -E 'FALLO|AVISO|RESULTADO|ERROR'
# Las copias estropeadas van a user://prueba_carga/ (fuera del proyecto).

const MAX_MM := 0.01
const SKIN_VERTICES := 13380

var failures := 0
var loader: GDScript


func _init() -> void:
	var root := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	loader = load(root.path_join("godot/addons/creador/species_data.gd"))
	var folder := root.path_join("datos/humana")
	var species = loader.new()
	species.load_folder(folder)
	check("carga datos/humana sin errores", species.error == "", species.error)
	if species.error == "":
		_check_species(species)
		species.scene.free()
	_check_rejects(folder)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_species(species) -> void:
	var skeleton: Skeleton3D = species.skeleton
	var mesh: Mesh = species.mesh.mesh
	check("57 huesos (53 + 4 anclajes)", skeleton.get_bone_count() == 57, str(skeleton.get_bone_count()))
	check("159 formas", mesh.get_blend_shape_count() == 159, str(mesh.get_blend_shape_count()))
	check("articulaciones.json: 57 huesos", species.joints.size() == 57)
	check("deslizadores.csv: 40 filas", species.sliders.size() == 40, str(species.sliders.size()))
	var arrays := mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] else PackedColorArray()
	var reds := Array(colors).map(func(c: Color) -> float: return c.r)
	check("color garment: hay piel y prenda", reds.size() > 0 and reds.min() < 0.1 and reds.max() > 0.9)
	_check_vertices(mesh)
	_check_rests(species)


func _check_vertices(mesh: Mesh) -> void:
	var unique := {}
	for s in mesh.get_surface_count():
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			unique[Vector3i((v * 1e5).round())] = true
	var label := "vértices únicos por posición: %d (MakeHuman: %d)" % [unique.size(), SKIN_VERTICES]
	print(("  bien  " if unique.size() == SKIN_VERTICES else "  AVISO ") + label)


func _check_rests(species) -> void:
	var skeleton: Skeleton3D = species.skeleton
	var to_scene := Transform3D.IDENTITY
	var node: Node = skeleton
	while node != species.scene:
		to_scene = (node as Node3D).transform * to_scene
		node = node.get_parent()
	var worst := 0.0
	var where := ""
	for bone: String in species.joints:
		var rest := to_scene * skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin
		var head: Array = species.joints[bone]["head"]
		var mm := 1000.0 * rest.distance_to(Vector3(head[0], head[1], head[2]))
		if mm > worst:
			worst = mm
			where = bone
	check("reposo del esqueleto = cabeza en articulaciones.json (< %s mm)" % MAX_MM, worst < MAX_MM,
		"máximo %.4f mm (%s)" % [worst, where])


func _check_rejects(folder: String) -> void:
	var copy := _copy(folder, "sha")
	var csv := FileAccess.open(copy.path_join("deslizadores.csv"), FileAccess.READ_WRITE)
	csv.seek_end()
	csv.store_string("\n")
	csv.close()
	var species = loader.new()
	species.load_folder(copy)
	check("rechaza un archivo cambiado (sha256)", species.error.contains("sha256") and species.scene == null, species.error)
	copy = _copy(folder, "version")
	var path := copy.path_join("manifiesto.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	manifest["version"] = 2
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(manifest))
	species = loader.new()
	species.load_folder(copy)
	check("rechaza la versión 2", species.error.contains("Versión") and species.scene == null, species.error)


func _copy(folder: String, name: String) -> String:
	var copy := OS.get_user_data_dir().path_join("prueba_carga").path_join(name)
	DirAccess.make_dir_recursive_absolute(copy)
	for file in DirAccess.get_files_at(folder):
		DirAccess.copy_absolute(folder.path_join(file), copy.path_join(file))
	return copy
