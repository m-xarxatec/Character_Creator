class_name TwoBoneIK
extends RefCounted
## Cinemática inversa de dos huesos (brazo o pierna), analítica y propia (paso 10.10). Sin nodos de IK de Godot.
##
## Uso:
##   # La mano izquierda va a `target`; el codo se dobla hacia `pole`. Todo en el espacio del esqueleto.
##   var reached := TwoBoneIK.apply(skeleton, "LeftUpperArm", "LeftLowerArm", "LeftHand", target, pole)
##   # Pierna: TwoBoneIK.apply(skeleton, "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", target, knee_pole)
##   # Solo el cálculo, sin esqueleto:
##   var solved := TwoBoneIK.solve(shoulder, elbow, wrist, target, pole)   # {upper, lower, mid, tip, reached}
## - Parte de la pose actual: mueve solo la cadena (y sus descendientes) y deja el resto como está.
## - Si el objetivo está fuera de alcance, la cadena queda (casi) estirada apuntando a él y devuelve false.
## - keep_tip_rotation = true: la mano (o el pie) y sus dedos conservan su giro en el mundo; false: siguen al antebrazo.
## - La pose se escribe con WorldPose (giros en el mundo), así que no depende de los ejes locales de los huesos.
## - Las longitudes se miden en la pose actual: vale también con escalas de Proporción.

const WorldPose := preload("res://../../godot/addons/creador/world_pose.gd")  # el del núcleo (10.3a); ruta válida desde pruebas/godot

const EPS := 0.000001
const STRAIGHT := 0.9999  # la cadena nunca se estira del todo: evita que el codo pierda su plano
const REACH_MM := 0.001  # «alcanzado» = el objetivo no hubo que recortarlo más que esto (en metros × 1000)


## Giros en el mundo que llevan la punta al objetivo.
## root, mid, tip: posición actual de hombro, codo y muñeca. pole: punto hacia el que se dobla el codo.
## Devuelve {"upper": Basis, "lower": Basis, "mid": Vector3, "tip": Vector3, "reached": bool}:
## - upper gira el hueso superior (y todo lo que cuelga de él) alrededor de root;
## - lower es el giro TOTAL del hueso inferior respecto a su pose actual (ya incluye upper);
## - mid y tip: dónde quedan el codo y la muñeca.
static func solve(root: Vector3, mid: Vector3, tip: Vector3, target: Vector3, pole: Vector3) -> Dictionary:
	var a := root.distance_to(mid)
	var b := mid.distance_to(tip)
	if a < EPS or b < EPS:
		return {"upper": Basis.IDENTITY, "lower": Basis.IDENTITY, "mid": mid, "tip": tip, "reached": false}
	var to_target := target - root
	var wanted := to_target.length()
	var direction := (mid - root) / a
	if wanted > EPS:
		direction = to_target / wanted
	elif root.distance_to(tip) > EPS:
		direction = (tip - root).normalized()
	var margin := (a + b) * (1.0 - STRAIGHT)
	var distance := clampf(wanted, absf(a - b) + margin, a + b - margin)
	# Ley del coseno: ángulo en root entre la dirección al objetivo y el hueso superior.
	var cos_root := clampf((a * a + distance * distance - b * b) / (2.0 * a * distance), -1.0, 1.0)
	var sin_root := sqrt(1.0 - cos_root * cos_root)
	var bend := _perpendicular(pole - root, direction)
	if bend == Vector3.ZERO:
		bend = _perpendicular(mid - root, direction)  # sin polo útil: se conserva el lado actual del codo
	if bend == Vector3.ZERO:
		bend = _perpendicular(Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT, direction)
	var new_mid := root + direction * (a * cos_root) + bend * (a * sin_root)
	var new_tip := root + direction * distance
	var upper := _arc(mid - root, new_mid - root)
	var lower := _arc(upper * (tip - mid), new_tip - new_mid) * upper
	return {"upper": upper, "lower": lower, "mid": new_mid, "tip": new_tip,
		"reached": absf(wanted - distance) * 1000.0 < REACH_MM}


## Lleva la punta de la cadena al objetivo. Devuelve true si llega. Si falta algún hueso, no hace nada y devuelve false.
static func apply(skeleton: Skeleton3D, upper_name: String, lower_name: String, tip_name: String, target: Vector3,
		pole: Vector3, keep_tip_rotation := true) -> bool:
	var upper := skeleton.find_bone(upper_name)
	var lower := skeleton.find_bone(lower_name)
	var tip := skeleton.find_bone(tip_name)
	if upper < 0 or lower < 0 or tip < 0:
		return false
	var globals := _globals(skeleton)
	var solved := solve(globals[upper].origin, globals[lower].origin, globals[tip].origin, target, pole)
	var deltas: Dictionary = WorldPose.all_deltas(skeleton)
	var turns: Array[Basis] = []  # giro en el mundo que recibe cada hueso; lo hereda de su padre
	for i in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(i)
		var turn := Basis.IDENTITY if parent < 0 else turns[parent]
		if i == upper:
			turn = solved["upper"]
		elif i == lower:
			turn = solved["lower"]
		elif i == tip and keep_tip_rotation:
			turn = Basis.IDENTITY
		turns.append(turn)
		var bone := skeleton.get_bone_name(i)
		deltas[bone] = (turn * Basis(deltas[bone] as Quaternion)).get_rotation_quaternion()
	WorldPose.apply(skeleton, deltas)
	return solved["reached"]


## Transformación global de cada hueso en la pose actual (con posición y escala), encadenada a mano.
static func _globals(skeleton: Skeleton3D) -> Array[Transform3D]:
	var globals: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(i)
		var local := skeleton.get_bone_pose(i)
		globals.append(local if parent < 0 else globals[parent] * local)
	return globals


## Parte de v perpendicular a axis (unitario), normalizada. Vector3.ZERO si v es casi paralelo a axis.
static func _perpendicular(v: Vector3, axis: Vector3) -> Vector3:
	var side := v - axis * v.dot(axis)
	return side.normalized() if side.length() > 0.0001 else Vector3.ZERO


## Giro mínimo que lleva la dirección from a la dirección to (misma fórmula que BoneRefit.arc; copiada aquí
## para que este archivo solo dependa de world_pose.gd).
static func _arc(from: Vector3, to: Vector3) -> Basis:
	var a := from.normalized()
	var b := to.normalized()
	var w := 1.0 + a.dot(b)
	if w < 1e-6:
		var other := Vector3.RIGHT if absf(a.x) < 0.9 else Vector3.UP
		return Basis(a.cross(other).normalized(), PI)
	var c := a.cross(b)
	return Basis(Quaternion(c.x, c.y, c.z, w).normalized())
