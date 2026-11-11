class_name GlbExporter
extends RefCounted
## Exporta el personaje del editor a un .glb listo para un juego (paso 3.6.5).
##
## Uso:
##   var error := GlbExporter.save(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], "user://heroe.glb", true)
## - t_pose: true = pose T horneada; false = pose A.
## Hornea (character_baker.gd), pasa los anclajes a nodos (sockets.gd) y escribe con GLTFDocument.
## En el archivo: Character → Armature → huesos, malla y anclajes (misma estructura que los .glb de Blender).
## El personaje del editor no cambia. Sin material propio: la prenda fuera del editor es el paso 3.6.6.

const CharacterBaker := preload("character_baker.gd")
const Sockets := preload("sockets.gd")


## El personaje que se exporta, en memoria (quien llama lo libera). null si no se puede (ver Sockets.error).
static func build(mesh: MeshInstance3D, skeleton: Skeleton3D, socket_names: Array, t_pose: bool) -> Node3D:
	var baked: Node3D = CharacterBaker.bake(mesh, skeleton, t_pose)
	var character: Node3D = Sockets.to_nodes(baked, socket_names)
	baked.free()
	return character


static func save(mesh: MeshInstance3D, skeleton: Skeleton3D, socket_names: Array, path: String, t_pose: bool) -> Error:
	var character := build(mesh, skeleton, socket_names, t_pose)
	if character == null:
		return ERR_INVALID_DATA
	_add_armature_node(character)
	_set_owner(character, character)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(character, state)
	if error == OK:
		error = document.write_to_filesystem(state, path)
	character.free()
	return error


## Mete el esqueleto en un nodo "Armature", como los .glb de Blender: así valen los mismos ajustes de
## importación de Godot (el BoneMap se asigna a la ruta Armature/Skeleton3D).
static func _add_armature_node(character: Node3D) -> void:
	var skeleton := character.get_child(0)
	var armature := Node3D.new()
	armature.name = "Armature"
	character.remove_child(skeleton)
	character.add_child(armature)
	armature.add_child(skeleton)


static func _set_owner(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner(child, owner)
