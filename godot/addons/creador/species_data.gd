class_name SpeciesData
extends RefCounted
## Carga la carpeta de una especie de datos/ (ver datos/FORMATO.md) y monta la malla y el esqueleto.
##
## Uso:
##   var species := SpeciesData.new()
##   if species.load_folder("res://datos/humana"): push_error(species.error)
##   else: add_child(species.scene)
## Comprueba la versión y el sha256 de cada archivo; si algo falla, deja el error y no carga nada.
## Abre el .glb con GLTFDocument (en tiempo de ejecución): vale en el editor y dentro de un juego.

const VERSION := 1

var error := ""
var manifest: Dictionary
var scene: Node3D
var skeleton: Skeleton3D
var mesh: MeshInstance3D
var joints: Dictionary  ## el diccionario "bones" de articulaciones.json
var sliders: Array[Dictionary]  ## una fila de deslizadores.csv por elemento: {columna: valor}


## Devuelve el error ("" si todo va bien); también queda en error.
func load_folder(folder: String) -> String:
	error = _load(folder)
	if error and scene:
		scene.free()
		scene = null
	return error


func _load(folder: String) -> String:
	manifest = _read_json(folder.path_join("manifiesto.json"))
	if manifest.is_empty():
		return "No se puede leer manifiesto.json en " + folder
	if manifest.get("version") != float(VERSION):
		return "Versión %s de datos/; se esperaba %d" % [manifest.get("version"), VERSION]
	for file: String in manifest["files"]:
		if FileAccess.get_sha256(folder.path_join(file)) != manifest["files"][file]["sha256"]:
			return "El sha256 de %s no coincide con el manifiesto" % file
	joints = _read_json(folder.path_join("articulaciones.json")).get("bones", {})
	sliders = _read_csv(folder.path_join("deslizadores.csv"))
	return _load_scene(folder.path_join("cuerpo.glb"))


func _load_scene(path: String) -> String:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return "No se puede abrir " + path
	scene = document.generate_scene(state)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	if skeletons.size() != 1 or meshes.size() != 1:
		return "cuerpo.glb debe tener un esqueleto y una malla"
	skeleton = skeletons[0]
	mesh = meshes[0]
	var bones: Array = manifest["bones"]["deform"] + manifest["bones"]["sockets"]
	if skeleton.get_bone_count() != bones.size() or bones.any(func(b: String) -> bool: return skeleton.find_bone(b) < 0):
		return "Los huesos de cuerpo.glb no son los del manifiesto"
	return ""


static func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _read_csv(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return rows
	var header := file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() == header.size():
			var row := {}
			for i in header.size():
				row[header[i]] = line[i]
			rows.append(row)
	return rows
