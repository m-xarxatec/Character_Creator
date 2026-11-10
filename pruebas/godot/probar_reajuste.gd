extends SceneTree
# Paso 2.4: el reajuste de huesos del núcleo (bone_refit.gd) da lo mismo que MPFB.
# Antes: blender -b -P pruebas/fase_2/referencia_reajuste.py  (escribe pruebas/fase_2/salida/referencia_reajuste.json)
# Uso: godot --headless --path pruebas/godot -s probar_reajuste.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'

const MAX_MM := 1.0
const MAX_DEG := 1.0
const CONTINUITY_MM := 0.1

var failures := 0
var refit: GDScript
var bones: Dictionary


func _init() -> void:
	var root := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	refit = load(root.path_join("godot/addons/creador/bone_refit.gd"))
	bones = _read(root.path_join("datos/humana/articulaciones.json"))["bones"]
	var reference := _read(root.path_join("pruebas/fase_2/salida/referencia_reajuste.json"))
	check("6 cuerpos de referencia", reference["bodies"].size() == 6)
	for body: Dictionary in reference["bodies"]:
		_check_body(body, reference["base"])
	_check_continuity(reference["continuity"])
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _check_body(body: Dictionary, base: Dictionary) -> void:
	var joints: Dictionary = refit.positions(bones, body["weights"])
	var actual: Dictionary = body["bones"]
	var mm := {}
	var deg := {}
	for bone: String in actual:
		var head: Vector3 = joints[bone][0]
		var tail: Vector3 = joints[bone][1]
		var real: Dictionary = actual[bone]
		mm[bone] = 1000.0 * maxf(head.distance_to(_vector(real["head"])), tail.distance_to(_vector(real["tail"])))
		var data: Dictionary = bones[bone]
		var predicted: Basis = refit.refit_basis(_basis(base[bone]), _vector(data["head"]), _vector(data["tail"]), head, tail)
		deg[bone] = _angle(predicted, _basis(real["basis"]))
	var name: String = body["name"]
	check(name + ": 57 huesos", actual.size() == 57 and joints.size() == 57)
	check(name + ": posición < %s mm" % MAX_MM, _max(mm) < MAX_MM, _summary(mm, "mm"))
	check(name + ": giro < %s°" % MAX_DEG, _max(deg) < MAX_DEG, _summary(deg, "°"))


func _check_continuity(triples: Array) -> void:
	var worst := 0.0
	var where := ""
	for triple: Dictionary in triples:
		var joints := []
		for weights: Dictionary in triple["weights"]:
			joints.append(refit.positions(bones, weights))
		for bone: String in bones:
			for end in 2:
				var middle: Vector3 = joints[1][bone][end]
				var gap := 1000.0 * maxf(middle.distance_to(joints[0][bone][end]), middle.distance_to(joints[2][bone][end]))
				if gap > worst:
					worst = gap
					where = "%s, %s" % [triple["name"], bone]
	check("continuidad en 0,5 (%d tríos): < %s mm" % [triples.size(), CONTINUITY_MM], worst < CONTINUITY_MM,
		"máximo %.4f mm (%s)" % [worst, where])


func _angle(a: Basis, b: Basis) -> float:
	var q := (a.inverse() * b).orthonormalized().get_rotation_quaternion()
	return rad_to_deg(2.0 * acos(minf(1.0, absf(q.w))))


func _max(values: Dictionary) -> float:
	return values.values().max()


func _summary(values: Dictionary, unit: String) -> String:
	var worst: String = values.find_key(_max(values))
	var total := 0.0
	for v: float in values.values():
		total += v
	return "máximo %.4f %s (%s), media %.4f %s" % [_max(values), unit, worst, total / values.size(), unit]


func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])


func _basis(columns: Array) -> Basis:
	return Basis(_vector(columns[0]), _vector(columns[1]), _vector(columns[2]))
