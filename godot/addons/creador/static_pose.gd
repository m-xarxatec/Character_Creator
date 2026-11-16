class_name StaticPose
extends RefCounted
## Pone al personaje en una pose fija escrita como datos (las poses extremas del banco de pruebas, paso 5.2).
##
## Uso:
##   updater.update(values, true)                                           # parte siempre de la pose T
##   StaticPose.apply(species.skeleton, animations.pose_turns("sentadilla"), animations.hips, animations.feet)
## turns: hueso → [x, y, z], giro en grados sobre los ejes del personaje (X a su izquierda, Y arriba, Z al frente;
## orden de Godot, YXZ). El giro de un hueso arrastra a sus hijos y el de cada hijo se suma al de su padre:
## muslo -95 y pantorrilla +110 dejan la pantorrilla a +15. Los huesos que no existen se ignoran.
## Después baja o sube `hips` para que el hueso más bajo de `feet` quede a la altura que tenía en la pose T.
## Solo cambia giros (y la posición de `hips`): la escala de Proporción no se toca.


static func apply(skeleton: Skeleton3D, turns: Dictionary, hips_bone: String, feet: Array) -> void:
	var floor_height := _lowest(skeleton, feet)
	var reference: Array[Quaternion] = []  # giro global de cada hueso en la pose T, leído antes de mover nada
	for bone in skeleton.get_bone_count():
		reference.append(skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion())
	var total: Array[Quaternion] = []  # giro acumulado de cada hueso respecto a la pose T
	var globals: Array[Quaternion] = []
	for bone in skeleton.get_bone_count():  # en un Skeleton3D el padre siempre va antes que el hijo
		var parent := skeleton.get_bone_parent(bone)
		var own := _turn(turns.get(skeleton.get_bone_name(bone), [0, 0, 0]))
		total.append(own if parent < 0 else total[parent] * own)
		globals.append(total[bone] * reference[bone])
		var parent_rotation := Quaternion.IDENTITY if parent < 0 else globals[parent]
		skeleton.set_bone_pose_rotation(bone, (parent_rotation.inverse() * globals[bone]).normalized())
	var hips := skeleton.find_bone(hips_bone)
	if hips >= 0 and not feet.is_empty():
		var wanted := skeleton.get_bone_global_pose(hips).origin + Vector3.UP * (floor_height - _lowest(skeleton, feet))
		var parent := skeleton.get_bone_parent(hips)
		var parent_pose := Transform3D.IDENTITY if parent < 0 else skeleton.get_bone_global_pose(parent)
		skeleton.set_bone_pose_position(hips, parent_pose.affine_inverse() * wanted)


static func _turn(degrees: Array) -> Quaternion:
	return Quaternion.from_euler(Vector3(deg_to_rad(degrees[0]), deg_to_rad(degrees[1]), deg_to_rad(degrees[2])))


static func _lowest(skeleton: Skeleton3D, feet: Array) -> float:
	var lowest := INF
	for name: String in feet:
		var bone := skeleton.find_bone(name)
		if bone >= 0:
			lowest = minf(lowest, skeleton.get_bone_global_pose(bone).origin.y)
	return lowest
