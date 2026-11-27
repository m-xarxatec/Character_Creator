extends RefCounted
# Paso 10.3b: el estudio de poses sobre la vista (body_view.gd). Al entrar hornea el personaje como «Exportar», sin
# escribir archivo, y lo pone en lugar del vivo con la última pose; al salir la guarda (WorldPose) y vuelve el vivo.
# Sin física de pelo ni sombra de suelo. Todavía sin pestaña ni panel.
# Uso:
#   var studio := StudioView.new()
#   studio.enter(body_view)          # OK o ERR_CANT_CREATE
#   WorldPose.turn(studio.skeleton, studio.skeleton.find_bone("Head"), Vector3.UP, 0.5)
#   studio.leave()                   # studio.pose se queda con la pose, para la próxima vez

const GlbExporter := preload("../addons/creador/glb_exporter.gd")
const BodyMaterial := preload("../addons/creador/body_material.gd")
const WorldPose := preload("../addons/creador/world_pose.gd")

var view: SubViewportContainer  # BodyView
var character: Node3D  # horneado, o null fuera del estudio
var skeleton: Skeleton3D  # el del horneado
var pose := {"huesos": {}, "cadera": [0, 0, 0]}  # lo que se guarda; sobrevive a salir


func enter(body_view: SubViewportContainer) -> Error:
	if character != null:
		return OK
	view = body_view
	var job: Dictionary = view.start_export()
	GlbExporter.compute_bake(job)
	GlbExporter.after_bake(job)
	GlbExporter.compute(job)
	character = GlbExporter.finish(job)
	if character == null:
		return ERR_CANT_CREATE
	skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	_paint()
	view.viewport.add_child(character)
	_show_live(false)
	WorldPose.apply(skeleton, WorldPose.from_data(pose["huesos"]))
	return OK


func leave() -> void:
	if character == null:
		return
	pose["huesos"] = WorldPose.to_data(WorldPose.capture(skeleton))
	character.free()
	character = null
	skeleton = null
	_show_live(true)


## Vuelve a la pose T.
func reset_pose() -> void:
	pose["huesos"] = {}
	if skeleton != null:
		for bone in skeleton.get_bone_count():
			skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())


func _show_live(on: bool) -> void:
	view.species.scene.visible = on
	view.floor_shadow.visible = on


## Los materiales del editor sobre el horneado: el cuerpo (la primera malla), como el .tres; piezas y accesorios, el
## toon de pieza con su color del .glb. Los ojos se quedan con el material del .glb.
func _paint() -> void:
	var meshes := character.find_children("*", "MeshInstance3D", true, false)
	(meshes[0] as MeshInstance3D).material_override = BodyMaterial.standalone(view.species.mesh)
	var eye_names: Array = view.eyes.map(func(eye: MeshInstance3D) -> StringName: return eye.name)
	var soft: bool = BodyMaterial.is_soft(view.species.mesh)
	for mesh: MeshInstance3D in meshes.slice(1):
		if mesh.name in eye_names:
			continue
		var color: Color = (mesh.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color
		BodyMaterial.apply(mesh, true, soft)
		BodyMaterial.set_color(mesh, "skin_color", color)
		BodyMaterial.set_color(mesh, "garment_color", color)
