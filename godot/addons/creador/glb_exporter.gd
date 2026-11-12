class_name GlbExporter
extends RefCounted
## Exporta el personaje del editor a un .glb listo para un juego (paso 3.6.5).
##
## Uso:
##   var error := GlbExporter.save(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], "user://heroe.glb", true)
## - t_pose: true = pose T horneada; false = pose A.
## Hornea (character_baker.gd), pasa los anclajes a nodos (sockets.gd) y escribe con GLTFDocument.
## En el archivo: Character → Armature → huesos, malla y anclajes (misma estructura que los .glb de Blender).
## El personaje del editor no cambia.
## Material: StandardMaterial3D con luz, sin brillo (metálico 0, rugosidad 1; paso 3.11a), para que reciba sombra fuera
## del editor, con la prenda horneada en una textura (garment_texture.gd). Con la prenda oculta, sin textura: todo color piel.
## El estilo toon no viaja en el .glb: en Godot lo pone el núcleo.
## Color por vértice: en el archivo, `garment` va en el alfa y el RGB es blanco. La norma glTF multiplica el material
## por el color por vértice (Blender lo hace): con `garment` en el RGB, la piel saldría negra.

const CharacterBaker := preload("character_baker.gd")
const Sockets := preload("sockets.gd")
const BodyMaterial := preload("body_material.gd")
const GarmentTexture := preload("garment_texture.gd")
const TEXTURE_SIZE := 2048  # 1 píxel ≈ 0,9 mm en el borde de la prenda (medido en el paso 3.6.6)


## El personaje que se exporta, en memoria (quien llama lo libera). null si no se puede (ver Sockets.error).
static func build(mesh: MeshInstance3D, skeleton: Skeleton3D, socket_names: Array, t_pose: bool) -> Node3D:
	var baked: Node3D = CharacterBaker.bake(mesh, skeleton, t_pose)
	var character: Node3D = Sockets.to_nodes(baked, socket_names)
	baked.free()
	if character != null:
		var exported := character.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var material := _material(mesh, exported.mesh)
		exported.mesh = _garment_in_alpha(exported.mesh)
		exported.mesh.surface_set_material(0, material)
	return character


static func _garment_in_alpha(source: Mesh) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in colors.size():
		colors[i] = Color(1.0, 1.0, 1.0, colors[i].r)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _material(editor_mesh: MeshInstance3D, mesh: Mesh) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "cuerpo"
	material.metallic = 0.0  # PBR sin brillo
	material.roughness = 1.0
	var skin := BodyMaterial.get_color(editor_mesh, "skin_color")
	if BodyMaterial.is_garment_visible(editor_mesh):
		var image := GarmentTexture.bake(mesh, TEXTURE_SIZE, skin, BodyMaterial.get_color(editor_mesh, "garment_color"))
		material.albedo_texture = ImageTexture.create_from_image(image)
	else:
		material.albedo_color = skin
	return material


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
