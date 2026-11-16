extends RefCounted
## Esqueleto humanoide mínimo, hecho por código, para las pruebas de pose y de IK (fichas A3 y 10.10).
## No necesita datos/ ni ventana.
##
## Uso (desde una prueba):
##   var maker: GDScript = load(<carpeta de esta prueba>.path_join("esqueleto_de_prueba.gd"))
##   var a: Skeleton3D = maker.build(0)        # ejes de todos los huesos = ejes del mundo
##   var b: Skeleton3D = maker.build(7)        # mismas articulaciones, ejes locales girados al azar (semilla 7)
##   var c: Skeleton3D = maker.build(0, 2.0)   # el doble de grande
##   var points: Array[Vector3] = maker.joints(a)   # posición global de cada hueso en la pose actual
## Pose T, metros, Y arriba, mirando a +Z: el brazo izquierdo apunta a +X (como TPose.SIDES).

const BONES := [  # nombre, padre, cabeza en el mundo
	["Root", "", Vector3(0.0, 0.0, 0.0)],
	["Hips", "Root", Vector3(0.0, 1.0, 0.0)],
	["Spine", "Hips", Vector3(0.0, 1.15, 0.0)],
	["Chest", "Spine", Vector3(0.0, 1.3, 0.0)],
	["Neck", "Chest", Vector3(0.0, 1.5, 0.0)],
	["Head", "Neck", Vector3(0.0, 1.6, 0.0)],
	["LeftUpperArm", "Chest", Vector3(0.2, 1.45, 0.0)],
	["LeftLowerArm", "LeftUpperArm", Vector3(0.5, 1.45, 0.0)],
	["LeftHand", "LeftLowerArm", Vector3(0.75, 1.45, 0.0)],
	["LeftMiddleProximal", "LeftHand", Vector3(0.85, 1.45, 0.0)],
	["LeftIndexProximal", "LeftHand", Vector3(0.85, 1.45, 0.03)],  # fuera del eje de la mano, a propósito
	["RightUpperArm", "Chest", Vector3(-0.2, 1.45, 0.0)],
	["RightLowerArm", "RightUpperArm", Vector3(-0.5, 1.45, 0.0)],
	["RightHand", "RightLowerArm", Vector3(-0.75, 1.45, 0.0)],
	["RightMiddleProximal", "RightHand", Vector3(-0.85, 1.45, 0.0)],
	["RightIndexProximal", "RightHand", Vector3(-0.85, 1.45, 0.03)],
	["LeftUpperLeg", "Hips", Vector3(0.1, 0.95, 0.0)],
	["LeftLowerLeg", "LeftUpperLeg", Vector3(0.1, 0.52, 0.0)],
	["LeftFoot", "LeftLowerLeg", Vector3(0.1, 0.08, 0.0)],
	["LeftToes", "LeftFoot", Vector3(0.1, 0.02, 0.14)],
	["RightUpperLeg", "Hips", Vector3(-0.1, 0.95, 0.0)],
	["RightLowerLeg", "RightUpperLeg", Vector3(-0.1, 0.52, 0.0)],
	["RightFoot", "RightLowerLeg", Vector3(-0.1, 0.08, 0.0)],
	["RightToes", "RightFoot", Vector3(-0.1, 0.02, 0.14)],
]


## seed_value 0: sin girar los ejes. Otro valor: cada hueso con sus ejes girados al azar (repetible).
static func build(seed_value: int, size := 1.0) -> Skeleton3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var skeleton := Skeleton3D.new()
	var globals: Array[Transform3D] = []
	for row: Array in BONES:
		var basis := Basis.IDENTITY
		if seed_value != 0:
			var axis := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
			if axis.length() < 0.1:
				axis = Vector3.UP
			basis = Basis(axis.normalized(), rng.randf_range(-PI, PI))
		globals.append(Transform3D(basis, (row[2] as Vector3) * size))
		skeleton.add_bone(row[0])
	for i in BONES.size():
		var parent := skeleton.find_bone(BONES[i][1]) if BONES[i][1] != "" else -1
		if parent >= 0:
			skeleton.set_bone_parent(i, parent)
		skeleton.set_bone_rest(i, globals[i] if parent < 0 else globals[parent].affine_inverse() * globals[i])
	skeleton.reset_bone_poses()
	return skeleton


## Transformación global de cada hueso en la pose actual, encadenada a mano.
static func globals_of(skeleton: Skeleton3D) -> Array[Transform3D]:
	var globals: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(i)
		var local := skeleton.get_bone_pose(i)
		globals.append(local if parent < 0 else globals[parent] * local)
	return globals


## Posición global de cada hueso en la pose actual.
static func joints(skeleton: Skeleton3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for global: Transform3D in globals_of(skeleton):
		points.append(global.origin)
	return points


## Mayor distancia, en mm, entre las articulaciones de dos esqueletos (mismos huesos, mismo orden).
static func worst_mm(a: Skeleton3D, b: Skeleton3D) -> float:
	var pa := joints(a)
	var pb := joints(b)
	var worst := 0.0
	for i in pa.size():
		worst = maxf(worst, 1000.0 * pa[i].distance_to(pb[i]))
	return worst
