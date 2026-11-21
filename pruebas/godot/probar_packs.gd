extends SceneTree
# Paso AB.2: biblioteca de piezas (godot/addons/creador/pack_library.gd) con el pack de serie (godot/packs/base) y packs
# rotos hechos aquí en user://packs_prueba. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_packs.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en PackLibrary._add, quitar la comprobación de LICENSES -> falla «licencia CC-BY: rechazado».

const BASE_PIECES := ["tights", "hair", "casquete", "melena", "cuernos", "orejas_gato", "halo"]

## Paso RE.1a: el pack de MakeHuman (ranura de cada pieza y tamaño total del pack).
const MH_SLOTS := {"short02": "pelo", "bob02": "pelo", "long01": "pelo", "ponytail01": "pelo", "afro01": "pelo",
	"bob01": "pelo", "braid01": "pelo", "short01": "pelo", "short03": "pelo", "short04": "pelo",
	"cortu_shaggy_green_hair": "pelo", "cortu_short_messy_hair": "pelo", "cortu_straight_bangs": "pelo",
	"cortu_strawberry_cloud_hair": "pelo", "culturalibre_hair_05": "pelo", "culturalibre_hair_06": "pelo",
	"faydaen_hair_1": "pelo", "toigo_blunt_bob": "pelo", "toigo_blunt_bob_with_bangs": "pelo",
	"toigo_curled_under_bob": "pelo", "toigo_curled_under_bob_with_bangs": "pelo", "toigo_inverted_bob": "pelo",
	"toigo_inverted_bob_with_bangs": "pelo",
	"female_casualsuit01": "ropa_torso", "female_sportsuit01": "ropa_torso", "male_casualsuit02": "ropa_torso",
	"male_casualsuit04": "ropa_torso",
	"cortu_jeans_shorts": "ropa_piernas",
	"toigo_basic_tucked_t-shirt": "ropa_torso", "joepal_crude_t-shirt_female": "ropa_torso",
	"elvs_crude_t-shirt_male": "ropa_torso", "namuhekam_male_polo_shirt": "ropa_torso",
	"toigo_camisole_top": "ropa_torso", "toigo_keyhole_tank_top": "ropa_torso", "toigo_fisherman_sweater": "ropa_torso"}
const MH_SUITS := ["female_casualsuit01", "female_sportsuit01", "male_casualsuit02", "male_casualsuit04"]  # cubren ropa_piernas
const MH_MAX_BYTES := 44000000  # PROVISIONAL: era 30 MB; medido 43,99 MB; lo autorizó el responsable el 2026-11-21 hasta revisar los assets

## Paso RE.1b: los 5 peinados de Quaternius.
const QU_PIECES := ["hair_buns", "hair_buzzed", "hair_buzzed_female", "hair_long", "hair_simple_parted"]
const QU_MAX_BYTES := 8000000  # PROVISIONAL: medido 2,42 MB

## Paso RE.1c: las prendas de OverScore que pasan todos los límites, con su ranura.
const OS_SLOTS := {"os_golf_shorts": "ropa_piernas", "os_short_shorts": "ropa_piernas", "os_vneck_top": "ropa_torso", "os_scrubs_top": "ropa_torso",
	"os_tank_top": "ropa_torso", "os_camisole_top": "ropa_torso"}
const OS_MAX_BYTES := 12000000  # PROVISIONAL: aceptado hasta 12 MB; medido 1,32 MB

var failures := 0
var root_dir: String
var library_script: GDScript
var test_root := "user://packs_prueba"


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	library_script = load(root_dir.path_join("godot/addons/creador/pack_library.gd"))
	_check_base()
	_check_makehuman()
	_check_quaternius()
	_check_overscore()
	_check_conflicts()
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
	var own := _of_pack(library, "base")
	var ids: Array = own.map(func(card: Dictionary) -> String: return card["id"])
	check("trae las %d piezas" % BASE_PIECES.size(), ids.size() == BASE_PIECES.size()
		and BASE_PIECES.all(func(id: String) -> bool: return id in ids), str(ids))
	check("todas CC0-1.0 y con autor", own.all(func(card: Dictionary) -> bool:
		return card["licencia"] == "CC0-1.0" and card["autor"] != ""))
	check("filtro por tipo: pelo = volumen, casquete y melena", _of_pack(library, "base", "pelo").size() == 3)
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


func _of_pack(library, pack_id: String, type := "") -> Array:
	return library.pieces(type, "humana").filter(func(card: Dictionary) -> bool: return card["pack"] == pack_id)


## Paso RE.1a: PackLibrary.conflicts. Mismo sitio, o un traje y unos shorts; no una camiseta y unos shorts.
func _check_conflicts() -> void:
	var library = library_script.new()
	library.scan(PackedStringArray([root_dir.path_join("godot/packs")]))
	var suit: Dictionary = library.piece("makehuman", "female_casualsuit01")
	var shirt: Dictionary = library.piece("makehuman", "toigo_camisole_top")
	var shorts: Dictionary = library.piece("makehuman", "cortu_jeans_shorts")
	var hair: Dictionary = library.piece("makehuman", "short02")
	var horns: Dictionary = library.piece("base", "cuernos")
	check("choque: traje con shorts (y al revés)", library_script.conflicts(suit, shorts) and library_script.conflicts(shorts, suit))
	check("choque: traje con camiseta (misma ranura)", library_script.conflicts(suit, shirt) and library_script.conflicts(shirt, suit))
	check("sin choque: camiseta con shorts", not library_script.conflicts(shirt, shorts) and not library_script.conflicts(shorts, shirt))
	check("sin choque: pelo con traje, y accesorios con todo", not library_script.conflicts(hair, suit)
		and not library_script.conflicts(horns, suit) and not library_script.conflicts(shorts, horns))
	check("una pieza con su misma ranura choca (dos peinados)", library_script.conflicts(hair, library.piece("makehuman", "bob01")))


func _is_clean(card: Dictionary) -> bool:
	var human: bool = "humana" in card["especies"]
	return card["licencia"] == "CC0-1.0" and card["autor"] != "" and human and card["sigue_al_cuerpo"] and card["nombre"] != ""


## Paso RE.1a: assets CC0 de MakeHuman (pelo y ropa) que siguen al cuerpo.
func _check_makehuman() -> void:
	var library = library_script.new()
	var warnings: Array = library.scan(PackedStringArray([root_dir.path_join("godot/packs")]))
	check("el pack makehuman se lee sin avisos", warnings.is_empty() and library.packs.has("makehuman"), str(warnings))
	var cards := _of_pack(library, "makehuman")
	var ids: Array = cards.map(func(card: Dictionary) -> String: return card["id"])
	ids.sort()
	var expected: Array = MH_SLOTS.keys()
	expected.sort()
	check("trae las %d piezas" % MH_SLOTS.size(), ids == expected, str(ids))
	check("todas CC0-1.0, con autor, humanas y que siguen al cuerpo", cards.all(_is_clean))
	check("los trajes completos cubren ropa_piernas y nada más lo hace", cards.all(func(card: Dictionary) -> bool:
		return (card["cubre"] == ["ropa_piernas"]) == (card["id"] in MH_SUITS)))
	check("cada pieza en su ranura", cards.all(func(card: Dictionary) -> bool: return MH_SLOTS.get(card["id"], "") == card["ranura"]))
	var total := 0
	var loaded := true
	for card: Dictionary in cards:
		var node: Node3D = library.load_piece("makehuman", card["id"])
		var meshes: Array = [] if node == null else node.find_children("*", "MeshInstance3D", true, false)
		loaded = loaded and meshes.size() == 1 and (meshes[0] as MeshInstance3D).skin != null \
			and (meshes[0] as MeshInstance3D).mesh.get_blend_shape_count() > 0
		if node != null:
			node.free()
		total += FileAccess.get_file_as_bytes(root_dir.path_join("godot/packs/makehuman").path_join(card["archivo"])).size()
	check("load_piece abre las %d (sha256 bien) con piel y formas" % MH_SLOTS.size(), loaded)
	print("  MEDIDA pack makehuman: %.2f MB" % (total / 1e6))
	check("el pack pesa menos de %d MB" % (MH_MAX_BYTES / 1000000), total < MH_MAX_BYTES)


## Paso RE.1b: peinados CC0 de Quaternius, en la ranura de pelo y con su sha256.
func _check_quaternius() -> void:
	var library = library_script.new()
	var warnings: Array = library.scan(PackedStringArray([root_dir.path_join("godot/packs")]))
	check("el pack quaternius se lee sin avisos", warnings.is_empty() and library.packs.has("quaternius"), str(warnings))
	var cards := _of_pack(library, "quaternius")
	var ids: Array = cards.map(func(card: Dictionary) -> String: return card["id"])
	ids.sort()
	check("Quaternius: trae los %d peinados" % QU_PIECES.size(), ids == QU_PIECES, str(ids))
	check("Quaternius: todos CC0-1.0, de Quaternius, humanos y que siguen al cuerpo", cards.all(func(card: Dictionary) -> bool:
		return _is_clean(card) and card["autor"] == "Quaternius"))
	check("Quaternius: todos en la ranura y el tipo pelo", cards.all(func(card: Dictionary) -> bool:
		return card["ranura"] == "pelo" and card["tipo"] == "pelo"))
	var total := 0
	var loaded := true
	for card: Dictionary in cards:
		var node: Node3D = library.load_piece("quaternius", card["id"])
		var meshes: Array = [] if node == null else node.find_children("*", "MeshInstance3D", true, false)
		loaded = loaded and meshes.size() == 1 and (meshes[0] as MeshInstance3D).skin != null \
			and (meshes[0] as MeshInstance3D).mesh.get_blend_shape_count() > 0
		if node != null:
			node.free()
		total += FileAccess.get_file_as_bytes(root_dir.path_join("godot/packs/quaternius").path_join(card["archivo"])).size()
	check("Quaternius: load_piece abre los %d (sha256 bien) con piel y formas" % QU_PIECES.size(), loaded)
	print("  MEDIDA pack quaternius: %.2f MB" % (total / 1e6))
	check("Quaternius: el pack pesa menos de %d MB" % (QU_MAX_BYTES / 1000000), total < QU_MAX_BYTES)


## Paso RE.1c: prendas CC0 de OverScore, cada una en su ranura y con su sha256.
func _check_overscore() -> void:
	var library = library_script.new()
	var warnings: Array = library.scan(PackedStringArray([root_dir.path_join("godot/packs")]))
	check("el pack overscore se lee sin avisos", warnings.is_empty() and library.packs.has("overscore"), str(warnings))
	var cards := _of_pack(library, "overscore")
	check("OverScore: trae las %d prendas" % OS_SLOTS.size(), cards.size() == OS_SLOTS.size()
		and cards.all(func(card: Dictionary) -> bool: return OS_SLOTS.get(card["id"], "") == card["ranura"] and card["tipo"] == "ropa"))
	check("OverScore: todas CC0-1.0, de overscore_media, humanas y que siguen al cuerpo", cards.all(func(card: Dictionary) -> bool:
		return _is_clean(card) and card["autor"] == "overscore_media"))
	check("OverScore: ninguna cubre otra ranura", cards.all(func(card: Dictionary) -> bool: return card["cubre"].is_empty()))
	var total := 0
	var loaded := true
	for card: Dictionary in cards:
		var node: Node3D = library.load_piece("overscore", card["id"])
		var meshes: Array = [] if node == null else node.find_children("*", "MeshInstance3D", true, false)
		loaded = loaded and meshes.size() == 1 and (meshes[0] as MeshInstance3D).skin != null \
			and (meshes[0] as MeshInstance3D).mesh.get_blend_shape_count() > 0
		if node != null:
			node.free()
		total += FileAccess.get_file_as_bytes(root_dir.path_join("godot/packs/overscore").path_join(card["archivo"])).size()
	check("OverScore: load_piece las abre (sha256 bien) con piel y formas", loaded)
	print("  MEDIDA pack overscore: %.2f MB" % (total / 1e6))
	check("OverScore: el pack pesa menos de %d MB" % (OS_MAX_BYTES / 1000000), total < OS_MAX_BYTES)


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
