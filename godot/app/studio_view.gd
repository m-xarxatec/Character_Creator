extends RefCounted
# Paso 10.3b: el estudio de poses sobre la vista (body_view.gd). Al entrar hornea el personaje como «Exportar», sin
# escribir archivo, y lo pone en lugar del vivo con la última pose; al salir la guarda (WorldPose) y vuelve el vivo.
# Sin física de pelo ni sombra de suelo. Con el mismo acabado que Cuerpo (_paint). Todavía sin pestaña ni panel.
# Uso:
#   var studio := StudioView.new()
#   studio.enter(body_view)          # OK o ERR_CANT_CREATE
#   WorldPose.turn(studio.skeleton, studio.skeleton.find_bone("Head"), Vector3.UP, 0.5)
#   studio.follow_head()             # la banda del pelo sigue a la cabeza
#   studio.leave()                   # studio.pose se queda con la pose, para la próxima vez

const GlbExporter := preload("../addons/creador/glb_exporter.gd")
const WorldPose := preload("../addons/creador/world_pose.gd")
const BodyView := preload("body_view.gd")

var view: SubViewportContainer  # BodyView
var character: Node3D  # horneado, o null fuera del estudio
var skeleton: Skeleton3D  # el del horneado
var hair: Array[MeshInstance3D] = []  # las mallas de pelo del horneado (banda)
var head_axes := Basis.IDENTITY  # _head_axes(), al entrar
var pose := {"huesos": {}, "cadera": [0, 0, 0]}  # lo que se guarda; sobrevive a salir


func enter(body_view: SubViewportContainer) -> Error:
	if character != null:
		return OK
	view = body_view
	var job: Dictionary = view.start_export()
	job.erase("paint")  # el cuerpo lleva encima el toon de la vista: sin su textura del .glb (de 1,7 s a 0,8 s, medido)
	job["garment_visible"] = false
	GlbExporter.compute_bake(job)
	GlbExporter.after_bake(job)
	GlbExporter.compute(job)
	character = GlbExporter.finish(job)
	if character == null:
		return ERR_CANT_CREATE
	skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	_paint()
	view.viewport.add_child(character)
	head_axes = _head_axes()
	_show_live(false)
	WorldPose.apply(skeleton, WorldPose.from_data(pose["huesos"]))
	follow_head()
	return OK


func leave() -> void:
	if character == null:
		return
	pose["huesos"] = WorldPose.to_data(WorldPose.capture(skeleton))
	character.free()
	character = null
	skeleton = null
	hair.clear()
	_show_live(true)


## Vuelve a la pose T.
func reset_pose() -> void:
	pose["huesos"] = {}
	if skeleton != null:
		for bone in skeleton.get_bone_count():
			skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
		follow_head()


## La banda del pelo, a la cabeza del horneado (como hace la vista con la suya en cada fotograma). Tras girar huesos.
func follow_head() -> void:
	var head := BodyView.head_of(skeleton, head_axes)
	for mesh: MeshInstance3D in hair:
		(mesh.material_override as ShaderMaterial).set_shader_parameter("hair_head", head)


## Los ejes del hueso Head del vivo (con la escala de sus Proporciones) respecto a los del horneado, en reposo y en el
## mundo: con ellos la banda cae donde en Cuerpo. En reposo, para que no dependa de la animación del vivo.
func _head_axes() -> Basis:
	var live: Skeleton3D = view.species.skeleton
	var basis := Basis.IDENTITY
	var bone := live.find_bone("Head")
	while bone >= 0:
		basis = live.get_bone_rest(bone).basis.scaled_local(live.get_bone_pose_scale(bone)) * basis
		bone = live.get_bone_parent(bone)
	var baked := skeleton.global_basis * skeleton.get_bone_global_rest(skeleton.find_bone("Head")).basis
	return baked.inverse() * live.global_basis * basis


func _show_live(on: bool) -> void:
	view.species.scene.visible = on
	view.floor_shadow.visible = on


## El acabado de Cuerpo sobre el horneado: cada malla lleva una copia del material de la vista (cuerpo, piezas y
## accesorios), con su máscara de piel oculta, contorno, adelanto por capa, línea teñida y banda del pelo. Copia y no el
## mismo: la vista pone en el suyo la cabeza del vivo (hair_head). Los ojos se quedan con el material del .glb.
func _paint() -> void:
	var meshes := character.find_children("*", "MeshInstance3D", true, false)
	(meshes[0] as MeshInstance3D).material_override = _copy(view.species.mesh.material_override)
	for key: String in view.pieces.keys() + view.accessories.keys():
		for live: MeshInstance3D in view.meshes_of(key):
			var baked := character.find_child(live.name, true, false) as MeshInstance3D
			baked.material_override = _copy(live.material_override)
			if live in view.hair.values():
				hair.append(baked)


## El material con su contorno (next_pass y la meta «outline» de BodyMaterial), los dos copiados.
static func _copy(material: ShaderMaterial) -> ShaderMaterial:
	var copy := _clone(material)
	var outline := _clone(material.get_meta("outline"))
	copy.set_meta("outline", outline)
	copy.next_pass = outline if material.next_pass != null else null
	return copy


## Shader y parámetros en un material nuevo. Sin duplicate(): recorre get_property_list(), y ahí Godot borra del
## ORIGINAL hair_head (Transform3D en un mat4).
static func _clone(material: ShaderMaterial) -> ShaderMaterial:
	var copy := ShaderMaterial.new()
	copy.shader = material.shader
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		var value: Variant = material.get_shader_parameter(uniform["name"])
		if value != null:
			copy.set_shader_parameter(uniform["name"], value)
	return copy
