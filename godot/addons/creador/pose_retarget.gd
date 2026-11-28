class_name PoseRetarget
extends RefCounted
## Pasa la pose de un esqueleto animado (la fuente) a un personaje con otros huesos de reposo.
##
## Uso:
##   var retarget := PoseRetarget.new(animations.skeleton, species.skeleton, animations.bones, animations.hips)
##   updater.update(values, true)      # el personaje en pose T: es su pose de referencia
##   retarget.capture()                # repetir después de cada update (el reajuste cambia los huesos)
##   retarget.apply()                  # en cada fotograma, después de mover la fuente
## Regla: cada hueso gira, respecto a su pose de referencia, lo mismo que el hueso de la fuente respecto a la suya
## (giros globales). La referencia de la fuente es su reposo, que debe ser una pose T; la del personaje, su pose T.
## El hueso `hips` además se desplaza lo que la fuente, por la proporción entre las alturas de las dos caderas.
## Solo cambia giros (y la posición de `hips`): la escala de Proporción no se toca. Los huesos sin pareja
## (anclajes, o los que falten en otra especie) siguen a su padre. PE.4b: solo mueve los huesos que había al crearlo;
## los que se añadan después (cadenas de pelo, al final) se quedan con su pose.

var source: Skeleton3D
var target: Skeleton3D
var pairs: PackedInt32Array  ## por hueso del personaje: índice en la fuente, o -1
var hips := -1
var source_ref: Array[Quaternion]  ## giro global de cada hueso de la fuente en su reposo
var target_ref: Array[Quaternion]  ## giro global de cada hueso del personaje al llamar a capture()
var target_hips: Vector3
var hips_ratio := 1.0


func _init(source_skeleton: Skeleton3D, target_skeleton: Skeleton3D, bones: Dictionary, hips_bone: String) -> void:
	source = source_skeleton
	target = target_skeleton
	pairs.resize(target.get_bone_count())
	pairs.fill(-1)
	for bone: String in bones:
		var index := target.find_bone(bone)
		if index >= 0:
			pairs[index] = source.find_bone(bones[bone])
	hips = target.find_bone(hips_bone)
	for bone in source.get_bone_count():
		source_ref.append(_rotation(source.get_bone_global_rest(bone)))


## Guarda la pose actual del personaje como referencia (debe estar en pose T).
func capture() -> void:
	target_ref.clear()
	for bone in target.get_bone_count():
		target_ref.append(_rotation(target.get_bone_global_pose(bone)))
	if hips >= 0 and pairs[hips] >= 0:
		target_hips = target.get_bone_global_pose(hips).origin
		hips_ratio = target_hips.y / source.get_bone_global_rest(pairs[hips]).origin.y


func apply() -> void:
	var globals: Array[Quaternion] = []
	for bone in mini(pairs.size(), target_ref.size()):  # en un Skeleton3D el padre siempre va antes que el hijo
		var parent := target.get_bone_parent(bone)
		var parent_rotation := Quaternion.IDENTITY if parent < 0 else globals[parent]
		var pair := pairs[bone]
		if pair < 0:
			globals.append(parent_rotation * target.get_bone_pose_rotation(bone))
			continue
		var turn := _rotation(source.get_bone_global_pose(pair)) * source_ref[pair].inverse()
		globals.append(turn * target_ref[bone])
		target.set_bone_pose_rotation(bone, (parent_rotation.inverse() * globals[bone]).normalized())
		if bone == hips:
			_move_hips(pair, parent)


func _move_hips(pair: int, parent: int) -> void:
	var moved := source.get_bone_global_pose(pair).origin - source.get_bone_global_rest(pair).origin
	var wanted := target_hips + moved * hips_ratio
	var parent_pose := Transform3D.IDENTITY if parent < 0 else target.get_bone_global_pose(parent)
	target.set_bone_pose_position(hips, parent_pose.affine_inverse() * wanted)


static func _rotation(transform: Transform3D) -> Quaternion:
	return transform.basis.get_rotation_quaternion()
