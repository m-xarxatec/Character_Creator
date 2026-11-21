extends SceneTree
# Paso AB.2: biblioteca de piezas (godot/addons/creador/pack_library.gd) con el pack de serie (godot/packs/base) y packs
# rotos hechos aquí en user://packs_prueba. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_packs.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en PackLibrary._add, quitar la comprobación de LICENSES -> falla «licencia CC-BY: rechazado».

const BASE_PIECES := ["tights", "hair", "casquete", "melena", "cuernos", "orejas_gato", "halo"]

var failures := 0
var root_dir: String
var library_script: GDScript
var test_root := "user://packs_prueba"


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	library_script = load(root_dir.path_join("godot/addons/creador/pack_library.gd"))
	_check_base()
	_check_rejected()
	_clean()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_base() -> void:
	var library = library_script.new()
	var warnings: Array = library.scan(PackedStringArray([root_dir.path_join("godot/packs")]))
	check("el pack base se lee sin avisos", warnings.is_empty() and library.packs.has("base"), str(warnings))
	var ids: Array = library.pieces().map(func(card: Dictionary) -> String: return card["id"])
	check("trae las %d piezas" % BASE_PIECES.size(), ids.size() == BASE_PIECES.size()
		and BASE_PIECES.all(func(id: String) -> bool: return id in ids), str(ids))
	check("todas CC0-1.0 y con autor", library.pieces().all(func(card: Dictionary) -> bool:
		return card["licencia"] == "CC0-1.0" and card["autor"] != ""))
	check("filtro por tipo: pelo = volumen, casquete y melena", library.pieces("pelo", "humana").size() == 3)
	check("filtro por especie: ninguna de otra especie", library.pieces("", "otra").is_empty())
	var node: Node3D = library.load_piece("base", "tights")
	check("load_piece(tights): una malla con piel y formas", node != null
		and node.find_children("*", "MeshInstance3D", true, false).size() == 1
		and (node.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.get_blend_shape_count() > 100)
	if node != null:
		node.free()
	check("las derivadas y los generadores no tienen archivo (load_piece da null)",
		library.load_piece("base", "casquete") == null and library.load_piece("base", "cuernos") == null)
	check("una pieza que no existe da null", library.load_piece("base", "no_existe") == null and library.piece("x", "y").is_empty())


## Packs rotos: cada uno en su carpeta; scan los rechaza y dice por qué.
func _check_rejected() -> void:
	_clean()
	var glb := FileAccess.get_file_as_bytes(root_dir.path_join("godot/packs/base/hair.glb"))
	var good := {"formato": "gamemolde-pack", "version": 1, "id": "bueno", "nombre": "Bueno", "autor": "Prueba",
		"licencia": "CC0-1.0", "piezas": [{"id": "falda", "tipo": "ropa", "ranura": "ropa_piernas", "archivo": "falda.glb",
		"sha256": "0".repeat(64), "sigue_al_cuerpo": true}]}
	var cases := {
		"licencia CC-BY": {"licencia": "CC-BY-4.0"},
		"sin autor": {"autor": ""},
		"versión más nueva": {"version": 2},
		"otro formato": {"formato": "otra-cosa"},
		"ranura desconocida": {"piezas": [{"id": "a", "tipo": "ropa", "ranura": "cola", "archivo": "falda.glb"}]},
		"falta el archivo": {"piezas": [{"id": "a", "tipo": "ropa", "ranura": "pelo", "archivo": "no.glb"}]},
	}
	var n := 0
	for label: String in cases:
		var data := good.duplicate(true)
		data.merge(cases[label], true)
		data["id"] = "p%d" % n
		_write_pack("p%d" % n, data, glb)
		n += 1
	_write_pack("bueno", good, glb)
	var library = library_script.new()
	var warnings: Array = library.scan(PackedStringArray([test_root]))
	check("%d packs rotos: %d avisos y fuera" % [cases.size(), cases.size()], warnings.size() == cases.size()
		and library.packs.keys() == ["bueno"], str(library.packs.keys()))
	check("licencia CC-BY: rechazado y el aviso lo dice", warnings.any(func(w: String) -> bool: return w.contains("CC-BY-4.0")))
	check("sha256 que no coincide: load_piece da null", library.load_piece("bueno", "falda") == null)


func _write_pack(folder: String, data: Dictionary, glb: PackedByteArray) -> void:
	var path := test_root.path_join(folder)
	DirAccess.make_dir_recursive_absolute(path)
	var file := FileAccess.open(path.path_join("pack.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	file = FileAccess.open(path.path_join("falda.glb"), FileAccess.WRITE)
	file.store_buffer(glb)
	file.close()


func _clean() -> void:
	if not DirAccess.dir_exists_absolute(test_root):
		return
	for folder: String in DirAccess.get_directories_at(test_root):
		for file: String in DirAccess.get_files_at(test_root.path_join(folder)):
			DirAccess.remove_absolute(test_root.path_join(folder).path_join(file))
		DirAccess.remove_absolute(test_root.path_join(folder))
