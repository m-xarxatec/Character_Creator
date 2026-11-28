class_name BodyPiece
extends RefCounted
## Paso AB.4: una pieza que sigue al cuerpo («sigue_al_cuerpo» en pack.json; las de AB.3) puesta sobre el personaje.
## «Sigue al cuerpo» = el mismo Skeleton3D y las mismas formas: la malla de la pieza pasa a colgar del esqueleto del
## cuerpo (la mueve la GPU, como al cuerpo, también con la pose T y las animaciones) y follow() le copia los pesos de
## forma del cuerpo (por nombre) y sus bind poses (las que SkeletonRefit acaba de reajustar). Nada se copia por vértice.
## Uso:
##   var mesh := BodyPiece.attach(library.load_piece("base", "tights"), species.skeleton)  # o null
##   BodyPiece.follow(mesh, species.mesh)   # después de cada CharacterUpdater.update (lo hace el updater)
##   BodyPiece.detach(mesh)

const ShapeWeights := preload("shape_weights.gd")
const HairChains := preload("hair_chains.gd")


## Saca la malla de la escena de la pieza y la cuelga de skeleton, con sus binds apuntando a sus huesos (por nombre).
## null si la escena no trae una sola malla con piel o si usa un hueso que el esqueleto no tiene. Libera la escena.
static func attach(piece: Node3D, skeleton: Skeleton3D) -> MeshInstance3D:
	if piece == null:
		return null
	var meshes := piece.find_children("*", "MeshInstance3D", true, false)
	var mesh: MeshInstance3D = meshes[0] if meshes.size() == 1 else null
	if mesh == null or mesh.skin == null:
		piece.free()
		return null
	var own := mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
	var skin: Skin = mesh.skin.duplicate()
	for i in skin.get_bind_count():
		var bone_name := String(skin.get_bind_name(i))
		if bone_name == "" and own != null:
			bone_name = own.get_bone_name(skin.get_bind_bone(i))
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			piece.free()
			return null
		skin.set_bind_bone(i, bone)
		skin.set_bind_name(i, bone_name)
	var place := mesh.transform  # respecto a su esqueleto, que está donde el del cuerpo (mismo rig)
	mesh.get_parent().remove_child(mesh)
	mesh.owner = null
	piece.free()
	mesh.skin = skin
	mesh.transform = place
	hang(mesh, skeleton)
	return mesh


## Cuelga una malla suelta (por ejemplo, de BodyDerived) del esqueleto del cuerpo.
static func hang(mesh: MeshInstance3D, skeleton: Skeleton3D) -> void:
	skeleton.add_child(mesh)
	mesh.skeleton = NodePath("..")


## Copia a la pieza los pesos de forma y las bind poses del cuerpo.
static func follow(piece: MeshInstance3D, body: MeshInstance3D) -> void:
	var weights := {}
	for i in body.mesh.get_blend_shape_count():
		weights[String(body.mesh.get_blend_shape_name(i))] = body.get_blend_shape_value(i)
	ShapeWeights.apply(piece, weights)  # las formas que la pieza no tiene (no la mueven) se ignoran
	var skeleton := body.get_node(body.skeleton) as Skeleton3D
	var poses := {}  # hueso → bind pose del cuerpo
	for j in body.skin.get_bind_count():
		var bone := body.skin.get_bind_bone(j)
		if bone < 0:
			bone = skeleton.find_bone(body.skin.get_bind_name(j))
		poses[bone] = body.skin.get_bind_pose(j)
	for i in piece.skin.get_bind_count():
		var bone := piece.skin.get_bind_bone(i)
		if poses.has(bone):
			piece.skin.set_bind_pose(i, poses[bone])
		elif bone >= 0 and HairChains.is_chain_bone(skeleton.get_bone_name(bone)):  # paso PE.3b: con su reposo de ahora
			piece.skin.set_bind_pose(i, skeleton.get_bone_global_rest(bone).affine_inverse())


static func detach(piece: MeshInstance3D) -> void:
	if piece != null and is_instance_valid(piece):
		piece.get_parent().remove_child(piece)
		piece.free()
