class_name SkeletonRefit
extends RefCounted
## Reajusta el esqueleto de un personaje a sus formas: reposo, pose y bind poses (paso 3.4).
##
## Uso:
##   var base := SkeletonRefit.capture_base(species.skeleton)   # una vez, al cargar
##   SkeletonRefit.apply(species.skeleton, species.mesh.skin, species.joints, weights, base)
## - joints: el diccionario "bones" de articulaciones.json; weights: {forma: peso} (ShapeWeights.weights).
## Cada hueso va a su sitio nuevo (bone_refit.gd) y su bind pose cambia a la vez: la malla no se mueve,
## solo la mueven las formas. La pose queda igual al reposo en posición y giro; la escala (Proporción) no se toca.
## Supone malla, esqueleto y articulaciones.json en el mismo espacio (lo comprueba species_data.gd).

const Refit := preload("bone_refit.gd")


## {hueso: giro de reposo global} del esqueleto recién cargado.
static func capture_base(skeleton: Skeleton3D) -> Dictionary:
	var base := {}
	for i in skeleton.get_bone_count():
		base[skeleton.get_bone_name(i)] = skeleton.get_bone_global_rest(i).basis
	return base


static func apply(skeleton: Skeleton3D, skin: Skin, joints: Dictionary, weights: Dictionary, base: Dictionary) -> void:
	var positions: Dictionary = Refit.positions(joints, weights)
	var globals: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		var data: Dictionary = joints[bone]
		var head: Vector3 = positions[bone][0]
		var basis: Basis = Refit.refit_basis(base[bone], _vector(data["head"]), _vector(data["tail"]), head, positions[bone][1])
		globals.append(Transform3D(basis, head))
	for i in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(i)
		var rest := globals[i] if parent < 0 else globals[parent].affine_inverse() * globals[i]
		skeleton.set_bone_rest(i, rest)
		skeleton.set_bone_pose_position(i, rest.origin)
		skeleton.set_bone_pose_rotation(i, rest.basis.get_rotation_quaternion())
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(i))
		skin.set_bind_pose(i, globals[bone].affine_inverse())


static func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])
