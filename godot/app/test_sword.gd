extends RefCounted
# Paso 5.6: espada de prueba hecha con cajas (sin assets ni licencias) para comprobar un anclaje de verdad.
# Va en el personaje EXPORTADO (horneado): ahí los huesos tienen escala 1. En el maniquí vivo la mano lleva la escala de
# Proporción y la espada crecería con ella; por eso no hay casilla en la ventana. Las espadas de verdad: Fase 13.
# Uso: var sword := TestSword.add(character)   # null si no existe el anclaje
# La hoja va a lo largo de +Y del anclaje.

const NAME := "EspadaDePrueba"
const PARTS := [  # tamaño y posición en +Y de cada caja (m)
	[Vector3(0.04, 0.80, 0.01), 0.45],  # hoja
	[Vector3(0.16, 0.02, 0.03), 0.04],  # guarda
	[Vector3(0.03, 0.14, 0.03), -0.04],  # empuñadura
]


static func add(character: Node3D, socket := "socket_hand_r") -> Node3D:
	var holder := character.find_child(socket, true, false) as Node3D
	if holder == null:
		return null
	var sword := Node3D.new()
	sword.name = NAME
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.55, 0.57, 0.6)
	for part: Array in PARTS:
		var box := BoxMesh.new()
		box.size = part[0]
		box.material = material
		var piece := MeshInstance3D.new()
		piece.mesh = box
		piece.position = Vector3(0, part[1], 0)
		sword.add_child(piece)
	holder.add_child(sword)
	return sword


## Punta de la hoja en coordenadas de la espada.
static func tip() -> Vector3:
	return Vector3(0, PARTS[0][1] + PARTS[0][0].y / 2.0, 0)
