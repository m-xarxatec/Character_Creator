class_name TPose
extends RefCounted
## Pose T: pone los brazos en T como pose del esqueleto (el reposo no se toca).
##
## Uso:
##   TPose.apply(species.skeleton)   # después de cada reajuste, que pisa la pose; parte del reposo
## Solo giran brazo, antebrazo y mano: quedan en línea recta hacia los lados, con la palma hacia abajo
## (el índice delante y el meñique detrás). Los dedos y el anclaje siguen a la mano. La escala no se toca.
## Misma lógica que blender/pose_t.py, código propio de este proyecto (no viene de MPFB), portada aquí bajo MIT
## con permiso del autor (2026-11-11).

const Refit := preload("bone_refit.gd")
const SIDES := {"Left": Vector3.RIGHT, "Right": Vector3.LEFT}  # hacia dónde apunta cada brazo
const FORWARD := Vector3.BACK  # el personaje mira a +Z


static func apply(skeleton: Skeleton3D) -> void:
	var globals := _rest_globals(skeleton)
	for side: String in SIDES:
		var target: Vector3 = SIDES[side]
		var upper := skeleton.find_bone(side + "UpperArm")
		var lower := skeleton.find_bone(side + "LowerArm")
		var hand := skeleton.find_bone(side + "Hand")
		var middle := skeleton.find_bone(side + "MiddleProximal")
		var index := skeleton.find_bone(side + "IndexProximal")
		var little := skeleton.find_bone(side + "LittleProximal")
		_aim(skeleton, globals, upper, globals[lower].origin - globals[upper].origin, target)
		_aim(skeleton, globals, lower, globals[hand].origin - globals[lower].origin, target)
		_aim(skeleton, globals, hand, globals[middle].origin - globals[hand].origin, target)
		var across := globals[index].origin - globals[little].origin
		_aim(skeleton, globals, hand, across - target * across.dot(target), FORWARD)  # gira solo sobre el brazo
		for bone: int in [upper, lower, hand]:
			var local := globals[skeleton.get_bone_parent(bone)].affine_inverse() * globals[bone]
			skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion())


## Reposo global de cada hueso con la escala de su pose: se parte siempre del reposo, no de la pose actual,
## así que aplicarla dos veces da exactamente lo mismo.
static func _rest_globals(skeleton: Skeleton3D) -> Array[Transform3D]:
	var globals: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():  # en un Skeleton3D el padre siempre va antes que el hijo
		var rest := skeleton.get_bone_rest(bone)
		var local := Transform3D(rest.basis * Basis.from_scale(skeleton.get_bone_pose_scale(bone)), rest.origin)
		var parent := skeleton.get_bone_parent(bone)
		globals.append(local if parent < 0 else globals[parent] * local)
	return globals


## Gira el hueso y sus descendientes alrededor de su cabeza para que current apunte a target.
static func _aim(skeleton: Skeleton3D, globals: Array[Transform3D], bone: int, current: Vector3, target: Vector3) -> void:
	var pivot := globals[bone].origin
	var turn := Transform3D(Basis.IDENTITY, pivot) * Transform3D(Refit.arc(current, target), Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -pivot)
	var pending: Array[int] = [bone]
	while not pending.is_empty():
		var current_bone: int = pending.pop_back()
		globals[current_bone] = turn * globals[current_bone]
		pending.append_array(skeleton.get_bone_children(current_bone))
