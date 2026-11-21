extends SceneTree
# Paso 10.1: formato de proyecto .gmolde (project_file.gd). Sin ventana y sin datos/.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_proyecto.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Lee datos/proyecto_v1.gmolde (junto a esta prueba): ese archivo NO SE REGENERA NUNCA. Si un cambio del formato
# hace que deje de abrirse, falta una migración.
# Que detecta el fallo: (1) en to_text, pasar `false` como tercer argumento de JSON.stringify -> falla «otro orden de claves»;
# (2) en migrate, quitar la comprobación `version > VERSION` -> falla «versión más nueva».

var failures := 0
var project_file: GDScript
var here: String


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	here = (get_script() as Script).resource_path.get_base_dir()
	var path := root_dir.path_join("godot/addons/creador/project_file.gd")
	if FileAccess.file_exists(path):
		project_file = load(path)
	if project_file == null:
		print("ERROR: no se encuentra project_file.gd")
		quit(1)
		return
	_check_round_trip()
	_check_same_text()
	_check_versions()
	_check_defaults()
	_check_unknown()
	_check_errors()
	_check_repairs()
	_check_fixed_file()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _preset() -> Dictionary:
	return {"version": 2, "especie": "humana", "nombre": "Prueba", "prenda_visible": true,
		"valores": {"gender": 0.25, "muscle": 0.7}, "colores": {"skin_color": [0.8, 0.6, 0.5], "garment_color": [0.2, 0.2, 0.23]},
		"acabado": {"softness": 0.04, "width_px": 2.5}}


func _project() -> Dictionary:
	var project: Dictionary = project_file.new_project("Prueba", _preset(), "0.2.0")
	var character: Dictionary = project["personajes"][0]
	character["piezas"].append({"pack": "base", "pieza": "coleta_01", "sha256": "abc", "ranura": "pelo", "hueso": "Head",
		"transform": [0, 0.05, 0, 0, 0, 0, 1, 1], "colores": {"principal": [0.2, 0.1, 0.1]}, "parametros": {}})
	character["pose"]["huesos"]["LeftUpperArm"] = [0, 0, 0.382683, 0.92388]
	return project


## Carga un diccionario pasando por texto, como hará el programa.
func _load(data: Dictionary) -> Dictionary:
	return project_file.from_text(JSON.stringify(data))


func _error_of(data: Dictionary) -> String:
	return _load(data)["error"]


func _check_round_trip() -> void:
	var project := _project()
	var text: String = project_file.to_text(project)
	var loaded: Dictionary = project_file.from_text(text)
	check("ida y vuelta: sin error y sin avisos", loaded["error"] == "" and loaded["avisos"].is_empty(),
		"%s %s" % [loaded["error"], loaded["avisos"]])
	check("ida y vuelta: guardar lo cargado da el mismo texto", project_file.to_text(loaded["proyecto"]) == text)
	var character: Dictionary = loaded["proyecto"]["personajes"][0]
	check("ida y vuelta: el preset llega entero", project_file.to_text(character["preset"]) == project_file.to_text(_preset()))
	check("ida y vuelta: la pieza y la pose llegan", character["piezas"][0]["pieza"] == "coleta_01"
		and character["piezas"][0]["transform"].size() == 8 and character["pose"]["huesos"]["LeftUpperArm"].size() == 4)
	var before := JSON.stringify(project)
	project_file.from_dict(project)
	check("from_dict no cambia el diccionario que recibe", JSON.stringify(project) == before)


func _check_same_text() -> void:
	var a := _project()
	var b := {}
	var keys := a.keys()
	keys.reverse()
	for key: String in keys:  # las mismas claves, en otro orden
		b[key] = a[key]
	check("mismo proyecto con otro orden de claves: mismo texto", project_file.to_text(a) == project_file.to_text(b))
	var c := _project()
	c["version"] = 1.0
	c["personajes"][0]["giro_y"] = 0.0
	c["escena"]["camaras"][0]["distancia"] = 3.2000000004
	check("2 y 2.0, y diferencias por debajo de 6 decimales: mismo texto", project_file.to_text(a) == project_file.to_text(c))
	c["escena"]["camaras"][0]["distancia"] = 3.21
	check("un cambio real cambia el texto", project_file.to_text(a) != project_file.to_text(c))
	var text: String = project_file.to_text({"n": 0.1234567891, "entero": 3.0})
	check("números a 6 decimales y enteros sin decimales", text.contains("0.123457") and not text.contains("0.1234567")
		and not text.contains("3.0"), text.replace("\n", " "))


func _check_versions() -> void:
	var project := _project()
	project["version"] = project_file.VERSION + 1
	check("versión más nueva: se rechaza con el mensaje «actualiza el programa»", _error_of(project).contains("actualiza el programa"),
		_error_of(project))
	for bad: Variant in [0, 1.5, -1, "1", null]:
		project["version"] = bad
		check("versión %s: se rechaza" % [bad], _error_of(project) != "")
	project = _project()
	project.erase("version")
	check("sin versión: se rechaza", _error_of(project) != "")
	project = _project()
	project["formato"] = "otra-cosa"
	check("otro formato: se rechaza", _error_of(project).contains("no es un proyecto"))
	check("un preset suelto no es un proyecto", _error_of(_preset()).contains("no es un proyecto"))


func _check_defaults() -> void:
	var minimal := {"formato": project_file.FORMAT, "version": 1, "personajes": [{"preset": {"version": 2, "especie": "humana"}}]}
	var loaded := _load(minimal)
	check("proyecto mínimo: carga", loaded["error"] == "", loaded["error"])
	if loaded["error"] != "":
		return
	var project: Dictionary = loaded["proyecto"]
	var character: Dictionary = project["personajes"][0]
	check("proyecto mínimo: id p1, sin piezas, pose vacía", character["id"] == "p1" and character["piezas"].is_empty()
		and character["pose"]["huesos"].is_empty() and character["pose"]["cadera"].size() == 3)
	check("proyecto mínimo: escena por defecto con una luz y una cámara", project["escena"]["luces"].size() == 1
		and project["escena"]["camaras"].size() == 1 and project["escena"]["camara_activa"] == 0)
	check("proyecto mínimo: nombre y miniatura vacíos", project["nombre"] == "" and project["miniatura"] == "")
	check("proyecto mínimo: completo, da el mismo texto que al volver a cargarlo",
		project_file.to_text(project_file.from_text(project_file.to_text(project))["proyecto"]) == project_file.to_text(project))


func _check_unknown() -> void:
	var project := _project()
	project["futuro"] = {"a": 1}
	project["personajes"][0]["otro"] = "x"
	project["personajes"][0]["piezas"][0]["nuevo"] = [1, 2]
	project["escena"]["niebla"] = 0.5
	var loaded := _load(project)
	check("campos desconocidos: carga con 4 avisos", loaded["error"] == "" and loaded["avisos"].size() == 4, str(loaded["avisos"]))
	var text: String = project_file.to_text(loaded.get("proyecto", {}))
	check("campos desconocidos: se conservan al guardar", text.contains("\"futuro\"") and text.contains("\"otro\"")
		and text.contains("\"nuevo\"") and text.contains("\"niebla\""))


const BROKEN := ["sin personajes", "personajes no es una lista", "más personajes que el máximo", "id repetido",
	"personaje sin preset", "preset sin especie", "pieza sin hueso", "transform de 7 números", "giro de pose de 3 números",
	"giro de pose con texto", "cadera de 2 números", "nombre que no es texto", "luz de tipo desconocido",
	"cámara con distancia 0", "sin cámaras", "fondo de tipo desconocido"]


## Estropea el proyecto de una manera concreta.
func _break(p: Dictionary, label: String) -> void:
	var character: Dictionary = p["personajes"][0]
	match label:
		"sin personajes":
			p["personajes"] = []
		"personajes no es una lista":
			p["personajes"] = {}
		"más personajes que el máximo":
			for n in project_file.MAX_CHARACTERS:
				p["personajes"].append(project_file.new_character("x%d" % n, _preset()))
		"id repetido":
			p["personajes"].append(project_file.new_character("p1", _preset()))
		"personaje sin preset":
			character.erase("preset")
		"preset sin especie":
			character["preset"].erase("especie")
		"pieza sin hueso":
			character["piezas"][0].erase("hueso")
		"transform de 7 números":
			character["piezas"][0]["transform"] = [0, 0, 0, 0, 0, 0, 1]
		"giro de pose de 3 números":
			character["pose"]["huesos"]["Hips"] = [0, 0, 1]
		"giro de pose con texto":
			character["pose"]["huesos"]["Hips"] = [0, 0, "a", 1]
		"cadera de 2 números":
			character["pose"]["cadera"] = [0, 0]
		"nombre que no es texto":
			p["nombre"] = 7
		"luz de tipo desconocido":
			p["escena"]["luces"][0]["tipo"] = "láser"
		"cámara con distancia 0":
			p["escena"]["camaras"][0]["distancia"] = 0
		"sin cámaras":
			p["escena"]["camaras"] = []
		"fondo de tipo desconocido":
			p["escena"]["fondo"]["tipo"] = "vídeo"
		_:
			print("ERROR: caso sin escribir: ", label)


func _check_errors() -> void:
	for label: String in BROKEN:
		var project := _project()
		var before: String = project_file.to_text(project)
		_break(project, label)
		var loaded := _load(project)
		check("error: " + label, project_file.to_text(project) != before and loaded["error"] != "" and loaded["proyecto"].is_empty(),
			loaded["error"])
	check("error: JSON roto", project_file.from_text("{\"formato\": ")["error"].contains("JSON no válido"))
	check("error: una lista no es un proyecto", project_file.from_text("[1, 2]")["error"] != "")
	check("error: texto enorme", project_file.from_text(" ".repeat(project_file.MAX_TEXT + 1))["error"].contains("demasiado grande"))


func _check_repairs() -> void:
	var project := _project()
	project["escena"]["camara_activa"] = 5
	var loaded := _load(project)
	check("cámara activa que no existe: pasa a 0 con un aviso", loaded["error"] == "" and loaded["avisos"].size() == 1
		and loaded["proyecto"]["escena"]["camara_activa"] == 0)
	project = _project()
	project["miniatura"] = "A".repeat(project_file.MAX_THUMBNAIL + 1)
	loaded = _load(project)
	check("miniatura demasiado grande: se quita con un aviso", loaded["error"] == "" and loaded["avisos"].size() == 1
		and loaded["proyecto"]["miniatura"] == "")


## El archivo fijo de la versión 1 se abre en esta versión del programa y en todas las siguientes.
func _check_fixed_file() -> void:
	var path := here.path_join("datos/proyecto_v1.gmolde")
	if not FileAccess.file_exists(path):
		check("archivo fijo proyecto_v1.gmolde: existe", false, path)
		return
	var loaded: Dictionary = project_file.from_text(FileAccess.get_file_as_string(path))
	check("archivo fijo v1: se abre sin error", loaded["error"] == "", loaded["error"])
	if loaded["error"] != "":
		return
	var project: Dictionary = loaded["proyecto"]
	var character: Dictionary = project["personajes"][0]
	check("archivo fijo v1: queda en la versión actual", project["version"] == project_file.VERSION)
	check("archivo fijo v1: nombre con tilde", project["nombre"] == "Heroína de prueba")
	check("archivo fijo v1: un personaje con su preset", project["personajes"].size() == 1
		and character["preset"]["especie"] == "humana" and is_equal_approx(character["preset"]["valores"]["hand_size_r"], 0.7))
	check("archivo fijo v1: la pieza coleta_01 en Head", character["piezas"].size() == 1 and character["piezas"][0]["pieza"] == "coleta_01"
		and character["piezas"][0]["hueso"] == "Head" and is_equal_approx(character["piezas"][0]["transform"][1], 0.05))
	check("archivo fijo v1: pose de 2 huesos y cadera", character["pose"]["huesos"].size() == 2
		and is_equal_approx(character["pose"]["huesos"]["LeftUpperArm"][3], 0.92388) and is_equal_approx(character["pose"]["cadera"][1], -0.05))
	check("archivo fijo v1: 2 luces, 2 cámaras, activa la segunda, fondo transparente", project["escena"]["luces"].size() == 2
		and project["escena"]["camaras"].size() == 2 and project["escena"]["camara_activa"] == 1
		and project["escena"]["fondo"]["transparente"] == true)
	check("archivo fijo v1: la animación de la luz se conserva", project["escena"]["luces"][1]["animacion"]["tipo"] == "pulso"
		and project["escena"]["luces"][0]["animacion"] == null)
