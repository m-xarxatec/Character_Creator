extends RefCounted
## Paso 13.1a: los huesos donde se puede colgar una pieza y su nombre en español (lado = el del personaje).
## Solo datos; lo usan «Colocar» (13.1b) y el estudio de poses (10.3c).
## Uso:
##   const BoneLabels := preload("bone_labels.gd")
##   for bone in BoneLabels.SOCKETS + BoneLabels.BONES: option.add_item(BoneLabels.label(bone))

const SOCKETS := ["socket_hand_r", "socket_hand_l", "socket_back", "socket_hip"]
## Los 25 humanoides sin dedos ni Root, de la cabeza a los pies.
const BONES := [
	"Head", "Jaw", "LeftEye", "RightEye", "Neck", "UpperChest", "Chest", "Spine", "Hips",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
]
const LABELS := {
	"socket_hand_r": "Anclaje: mano derecha", "socket_hand_l": "Anclaje: mano izquierda",
	"socket_back": "Anclaje: espalda", "socket_hip": "Anclaje: cadera",
	"Head": "Cabeza", "Jaw": "Mandíbula", "LeftEye": "Ojo izquierdo", "RightEye": "Ojo derecho", "Neck": "Cuello",
	"UpperChest": "Pecho", "Chest": "Torso", "Spine": "Cintura", "Hips": "Caderas",
	"RightShoulder": "Hombro derecho", "RightUpperArm": "Brazo derecho", "RightLowerArm": "Antebrazo derecho",
	"RightHand": "Mano derecha",
	"LeftShoulder": "Hombro izquierdo", "LeftUpperArm": "Brazo izquierdo", "LeftLowerArm": "Antebrazo izquierdo",
	"LeftHand": "Mano izquierda",
	"RightUpperLeg": "Muslo derecho", "RightLowerLeg": "Pantorrilla derecha", "RightFoot": "Pie derecho",
	"RightToes": "Dedos del pie derecho",
	"LeftUpperLeg": "Muslo izquierdo", "LeftLowerLeg": "Pantorrilla izquierda", "LeftFoot": "Pie izquierdo",
	"LeftToes": "Dedos del pie izquierdo",
}


## El nombre en español; uno que no está en la tabla se devuelve tal cual.
static func label(bone: String) -> String:
	return LABELS.get(bone, bone)
