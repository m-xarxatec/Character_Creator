extends SceneTree
# Paso 5.14: el personaje exportado contra el presupuesto de diseno/GUIA_ESTILO.md §7 (PROPUESTA sin aprobar). Sin ventana.
# Uso:
#   godot --headless --path pruebas/godot -s medir_presupuesto.gd -- <archivo.glb o carpeta> 2>&1 | grep -E 'MEDIDA|FUERA|RESULTADO|ERROR'
#   Sin argumentos: exporta anime, extremo y 3 al azar, con y sin prenda, a pruebas/fase_5/salida/presupuesto/, los mide y
#   hace las comprobaciones de la ficha (FALLO si no se cumplen).
# Que detecta el fallo: PC["triangulos"] = 20000 -> aparecen líneas FUERA en la columna PC y falla «PC: 0 FUERA».

const PC := {"triangulos": 40000, "huesos": 75, "materiales": 4, "textura": 2048, "mb": 10.0}
const MOVIL := {"triangulos": 15000, "huesos": 60, "materiales": 2, "textura": 1024, "mb": 4.0}
const SEED := 11

var failures := 0
var root_dir: String


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var path: String = args[0] if args[0].is_absolute_path() else root_dir.path_join(args[0])
		var files := [path] if path.ends_with(".glb") else Array(DirAccess.get_files_at(path)).filter(
			func(f: String) -> bool: return f.ends_with(".glb")).map(func(f: String) -> String: return path.path_join(f))
		for file: String in files:
			_report(file, measure(file))
		print("RESULTADO: medidos %d" % files.size())
		quit()
		return
	_self_check()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


static func measure(path: String) -> Dictionary:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return {"error": "no se puede abrir " + path}
	var scene := document.generate_scene(state)
	var result := {"triangulos": 0, "vertices": 0, "huesos": 0, "materiales": 0, "textura": 0, "mb": 0.0}
	var materials := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var indices: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if arrays[Mesh.ARRAY_INDEX] != null else vertices
			result["triangulos"] += indices / 3
			result["vertices"] += vertices
			var material := mesh.surface_get_material(surface)
			if material != null:
				materials[material] = true
				if material is BaseMaterial3D and (material as BaseMaterial3D).albedo_texture != null:
					var texture := (material as BaseMaterial3D).albedo_texture
					result["textura"] = maxi(result["textura"], maxi(texture.get_width(), texture.get_height()))
	for skeleton in scene.find_children("*", "Skeleton3D", true, false):
		result["huesos"] += (skeleton as Skeleton3D).get_bone_count()
	result["materiales"] = materials.size()
	result["mb"] = FileAccess.get_file_as_bytes(path).size() / 1048576.0
	var tres := path.get_basename() + ".tres"
	result["tres_kb"] = FileAccess.get_file_as_bytes(tres).size() / 1024.0 if FileAccess.file_exists(tres) else 0.0
	scene.free()
	return result


## Imprime la medida y una línea FUERA por cada recurso que pasa de una columna. Devuelve {columna: cuántos FUERA}.
func _report(path: String, values: Dictionary) -> Dictionary:
	var name := path.get_file()
	if values.has("error"):
		print("ERROR: ", values["error"])
		return {"PC": -1, "móvil": -1}
	print("  MEDIDA %s: %d triángulos, %d vértices, %d huesos, %d materiales, textura %d px, %.2f MB (+ .tres de %.1f KB)" % [
		name, values["triangulos"], values["vertices"], values["huesos"], values["materiales"], values["textura"],
		values["mb"], values["tres_kb"]])
	var outside := {}
	for column: String in ["PC", "móvil"]:
		var budget: Dictionary = PC if column == "PC" else MOVIL
		outside[column] = []
		for key: String in budget:
			if values[key] > budget[key]:
				print("  FUERA %s %s %s: %s > %s" % [name, column, key, values[key], budget[key]])
				outside[column].append(key)
	return outside


func _self_check() -> void:
	var addon := root_dir.path_join("godot/addons/creador")
	var species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		failures += 1
		return
	root.add_child(species.scene)
	var material: GDScript = load(addon.path_join("body_material.gd"))
	material.apply(species.mesh)
	var updater = load(addon.path_join("character_updater.gd")).new(species)
	var exporter: GDScript = load(addon.path_join("glb_exporter.gd"))
	var preset: Dictionary = load(addon.path_join("preset.gd")).from_text(species.preset_text(), "humana", species.sliders)
	var out := root_dir.path_join("pruebas/fase_5/salida/presupuesto")
	DirAccess.make_dir_recursive_absolute(out)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var bodies := {"anime": preset["valores"], "extremo": {}, "azar_1": {}, "azar_2": {}, "azar_3": {}}
	for row: Dictionary in species.sliders:
		if row["tipo"] != "Por crear":
			for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
				bodies["extremo"][row["id"] + side] = 1.0
				for body: String in ["azar_1", "azar_2", "azar_3"]:
					bodies[body][row["id"] + side] = rng.randf()
	var outside_all := {"PC": [], "móvil": []}
	for body: String in bodies:
		updater.update(bodies[body], false)
		for garment: bool in [true, false]:
			material.set_garment_visible(species.mesh, garment)
			var path := out.path_join("%s_%s.glb" % [body, "prenda" if garment else "sin_prenda"])
			exporter.save(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], path, true)
			var values := measure(path)
			var outside := _report(path, values)
			for column: String in outside:
				for key: String in outside[column]:
					if not key in outside_all[column]:
						outside_all[column].append(key)
			if body == "anime":
				check("anime %s: 26.756 triángulos, 53 huesos y 1 material (los de la guía)" % ("con prenda" if garment else "sin prenda"),
					values["triangulos"] == 26756 and values["huesos"] == 53 and values["materiales"] == 1, str(values))
				check("anime %s: textura %s" % ["con prenda" if garment else "sin prenda", "2048 px" if garment else "0 px"],
					values["textura"] == (2048 if garment else 0), str(values["textura"]))
	material.set_garment_visible(species.mesh, true)
	outside_all["móvil"].sort()
	check("PC: 0 FUERA", outside_all["PC"].is_empty(), str(outside_all["PC"]))
	check("móvil: FUERA solo en triángulos y textura", outside_all["móvil"] == ["textura", "triangulos"], str(outside_all["móvil"]))
	print("  MEDIDA margen en PC para pelo y ropa: %d triángulos" % (PC["triangulos"] - 26756))
	_check_two_materials(out)
	species.scene.free()


func _check_two_materials(out: String) -> void:
	var scene := Node3D.new()
	for i in 2:
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(i, 0, 1 - i)
		box.mesh.surface_set_material(0, material)
		box.position.x = i
		scene.add_child(box)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_scene(scene, state)
	var path := out.path_join("dos_materiales.glb")
	document.write_to_filesystem(state, path)
	scene.free()
	check("un .glb con 2 materiales cuenta 2", measure(path)["materiales"] == 2, str(measure(path)["materiales"]))
