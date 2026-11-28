class_name WorldPose
extends RefCounted
## Pose como giros en el mundo respecto al reposo (ficha A3; ruta/ARQUITECTURA.md §2.3).
##
## Uso:
##   WorldPose.apply(skeleton, {"LeftUpperArm": Quaternion(Vector3.BACK, PI / 2)})
##   var deltas := WorldPose.capture(skeleton)          # la pose actual, lista para guardar
##   WorldPose.copy(animated_skeleton, character_skeleton)   # banco de pruebas: copia una animación
##   var data := WorldPose.to_data(deltas)              # {hueso: [x, y, z, w]} para JSON; from_data lo lee
##   var flipped := WorldPose.mirror(deltas)            # pose en espejo (izquierda <-> derecha)
##   WorldPose.turn(skeleton, bone, skeleton.global_basis.inverse() * axis_world, radians)   # paso 10.3a: el estudio
## Un delta es «cuánto ha girado el hueso en el mundo respecto a su reposo». No depende de los ejes locales
## del hueso: la misma pose vale para dos esqueletos con ejes distintos si los dos están en la misma pose de reposo.
## Un hueso sin delta sigue a su padre (conserva su giro local de reposo).
## apply parte siempre del reposo: aplicarla dos veces da lo mismo. Solo escribe el giro de la pose;
## no toca posición ni escala (la escala de Proporción se conserva).
## No se usa get_bone_global_pose(): puede devolver un valor viejo (ver la cabecera de mesh_baker.gd).

const MIN_DEG := 0.01  # capture no guarda un hueso que gira menos que esto respecto a su padre
const DECIMALS := 0.000001
const SIDES := ["Left", "Right"]


## deltas: {nombre de hueso: Quaternion o [x, y, z, w]}. Los nombres que el esqueleto no tiene se ignoran.
static func apply(skeleton: Skeleton3D, deltas: Dictionary) -> void:
	var rest := _rest_bases(skeleton)
	var world_delta: Array[Basis] = []
	var posed: Array[Basis] = []
	for i in skeleton.get_bone_count():  # en un Skeleton3D el padre siempre va antes que el hijo
		var parent := skeleton.get_bone_parent(i)
		var delta := Basis.IDENTITY if parent < 0 else world_delta[parent]
		var bone := skeleton.get_bone_name(i)
		if deltas.has(bone):
			delta = Basis(_quaternion(deltas[bone]))
		world_delta.append(delta)
		posed.append(delta * rest[i])  # el giro en el mundo va a la izquierda
		var local := posed[i] if parent < 0 else posed[parent].inverse() * posed[i]
		skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())


## Gira el hueso (y con él sus hijos) radians alrededor de axis, en el espacio del esqueleto, sobre su cabeza.
## Parte de la pose actual (no del reposo) y solo cambia el giro de pose de ese hueso.
static func turn(skeleton: Skeleton3D, bone: int, axis: Vector3, radians: float) -> void:
	var posed := _posed_bases(skeleton)
	var new_global := Basis(axis.normalized(), radians) * posed[bone]
	var parent := skeleton.get_bone_parent(bone)
	var local := new_global if parent < 0 else posed[parent].inverse() * new_global
	skeleton.set_bone_pose_rotation(bone, local.get_rotation_quaternion())


## La pose actual como deltas. Solo guarda los huesos que giran respecto a su padre más de MIN_DEG.
static func capture(skeleton: Skeleton3D) -> Dictionary:
	var all := _all_deltas(skeleton)
	var deltas := {}
	for i in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(i)
		var parent_delta := Basis.IDENTITY if parent < 0 else all[parent]
		if rad_to_deg(angle_between(parent_delta, all[i])) > MIN_DEG:
			deltas[skeleton.get_bone_name(i)] = all[i].get_rotation_quaternion()
	return deltas


## La pose actual con TODOS los huesos: {nombre: Quaternion}. Para modificar una pose (IK, mezcla) y volver a aplicarla.
## Ojo: con todos los huesos escritos, ninguno «sigue a su padre»; quien gire un hueso debe girar también sus descendientes.
static func all_deltas(skeleton: Skeleton3D) -> Dictionary:
	var all := _all_deltas(skeleton)
	var deltas := {}
	for i in skeleton.get_bone_count():
		deltas[skeleton.get_bone_name(i)] = all[i].get_rotation_quaternion()
	return deltas


## Copia la pose de source a target: mismos nombres de hueso y misma pose de reposo (por ejemplo, los dos en T).
## Los huesos que target no tiene se ignoran; los que source no tiene siguen a su padre.
## hips: el desplazamiento de la cadera se copia en el mundo, en proporción a la altura de la cadera en reposo.
static func copy(source: Skeleton3D, target: Skeleton3D, hips := "Hips") -> void:
	var all := _all_deltas(source)
	var deltas := {}
	for i in source.get_bone_count():
		var bone := source.get_bone_name(i)
		if target.find_bone(bone) >= 0:
			deltas[bone] = all[i].get_rotation_quaternion()
	apply(target, deltas)
	var s := source.find_bone(hips)
	var t := target.find_bone(hips)
	if s < 0 or t < 0:
		return
	var source_height := source.get_bone_global_rest(s).origin.y
	if absf(source_height) < 0.0001:
		return
	var ratio := target.get_bone_global_rest(t).origin.y / source_height
	var moved := source.get_bone_pose_position(s) - source.get_bone_rest(s).origin
	var world := _parent_basis(source, s) * moved  # desplazamiento en el mundo
	var local := _parent_basis(target, t).inverse() * (world * ratio)
	target.set_bone_pose_position(t, target.get_bone_rest(t).origin + local)


## Pose en espejo respecto al plano X = 0: intercambia Left y Right y refleja cada giro.
## Vale porque los deltas están en el mundo y el reposo es simétrico.
static func mirror(deltas: Dictionary) -> Dictionary:
	var result := {}
	for bone: String in deltas:
		var q := _quaternion(deltas[bone])
		result[_other_side(bone)] = Quaternion(q.x, -q.y, -q.z, q.w)
	return result


## Para guardar en JSON: {hueso: [x, y, z, w]} con 6 decimales y w >= 0 (q y -q son el mismo giro).
static func to_data(deltas: Dictionary) -> Dictionary:
	var data := {}
	for bone: String in deltas:
		var q := _quaternion(deltas[bone]).normalized()
		if q.w < 0.0:
			q = -q
		data[bone] = [snappedf(q.x, DECIMALS), snappedf(q.y, DECIMALS), snappedf(q.z, DECIMALS), snappedf(q.w, DECIMALS)]
	return data


## Lo contrario de to_data. Devuelve {} si algún valor no es una lista de 4 números finitos o es un giro nulo.
static func from_data(data: Dictionary) -> Dictionary:
	var deltas := {}
	for bone: Variant in data:
		var values: Variant = data[bone]
		if typeof(bone) != TYPE_STRING or typeof(values) != TYPE_ARRAY or values.size() != 4:
			return {}
		for value: Variant in values:
			if (typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT) or not is_finite(value):
				return {}
		var q := Quaternion(values[0], values[1], values[2], values[3])
		if q.length() < 0.5:
			return {}
		deltas[bone] = q.normalized()
	return deltas


## Ángulo entre dos giros, en radianes. Con atan2: Quaternion.get_angle() usa acos y con números de 32 bits
## no distingue ángulos de menos de unas centésimas de grado.
static func angle_between(a: Basis, b: Basis) -> float:
	var q := (a.inverse() * b).get_rotation_quaternion()
	return 2.0 * atan2(Vector3(q.x, q.y, q.z).length(), absf(q.w))


static func _quaternion(value: Variant) -> Quaternion:
	if typeof(value) == TYPE_QUATERNION:
		return (value as Quaternion).normalized()
	return Quaternion(value[0], value[1], value[2], value[3]).normalized()


static func _other_side(bone: String) -> String:
	for i in SIDES.size():
		if bone.begins_with(SIDES[i]):
			return SIDES[1 - i] + bone.substr(SIDES[i].length())
	return bone


## Giro de reposo global de cada hueso, sin escala.
static func _rest_bases(skeleton: Skeleton3D) -> Array[Basis]:
	var bases: Array[Basis] = []
	for i in skeleton.get_bone_count():
		bases.append(skeleton.get_bone_global_rest(i).basis.orthonormalized())
	return bases


## Giro global de cada hueso en la pose actual, encadenado a mano y sin escala.
static func _posed_bases(skeleton: Skeleton3D) -> Array[Basis]:
	var bases: Array[Basis] = []
	for i in skeleton.get_bone_count():
		var local := Basis(skeleton.get_bone_pose_rotation(i))
		var parent := skeleton.get_bone_parent(i)
		bases.append(local if parent < 0 else bases[parent] * local)
	return bases


## Delta en el mundo de todos los huesos, por índice: pose = delta * reposo.
static func _all_deltas(skeleton: Skeleton3D) -> Array[Basis]:
	var rest := _rest_bases(skeleton)
	var posed := _posed_bases(skeleton)
	var deltas: Array[Basis] = []
	for i in skeleton.get_bone_count():
		deltas.append(posed[i] * rest[i].inverse())
	return deltas


## Giro global, en la pose actual, del padre del hueso (identidad si no tiene padre).
static func _parent_basis(skeleton: Skeleton3D, bone: int) -> Basis:
	var parent := skeleton.get_bone_parent(bone)
	return Basis.IDENTITY if parent < 0 else _posed_bases(skeleton)[parent]
