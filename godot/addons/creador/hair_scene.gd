class_name HairScene
extends RefCounted
## Paso PE.5 (ficha `ruta/pasos/PE.5_exportar_pelo.md`): la física del pelo para un juego. Junto a heroe.glb, heroe.tscn
## hereda del .glb (ruta relativa) y cuelga del esqueleto el simulador de HairPhysics, puesto otra vez sobre el personaje
## exportado (en pose T los huesos tienen otros ejes y los anclajes ya no son huesos) con las escalas del editor.
## Uso (body_view.gd):
##   var hair := HairScene.read(simulator)                  # al empezar a exportar: cadenas y escalas del editor
##   var copy := HairScene.measure(hair, character)          # tras GlbExporter.finish y antes de GlbExporter.write
##   HairScene.save(copy, "…/heroe.glb", skeleton_path)      # tras write; skeleton_path = "Armature/" + nombre del esqueleto
##   copy.free()
## Comprobado en Godot 4.7.2: una copia (duplicate) del simulador no rehace sus articulaciones al cambiar de esqueleto;
## al cargar la .tscn, Godot las rehace con valores de serie (el .glb leído ordena los huesos de otra forma), así que lo
## de cada articulación va en curvas del ajuste; un choque solo guarda su posición si su `bone` está resuelto.

const HairPhysics := preload("hair_physics.gd")
const TEMP := "user://pelo_exportado.tscn"


## Lo que hace falta del editor: las cadenas (nombres de la raíz a la punta) y la escala de cada hueso.
static func read(simulator: SpringBoneSimulator3D) -> Dictionary:
	var skeleton := simulator.get_parent() as Skeleton3D
	var scales := {}
	for bone in skeleton.get_bone_count():
		scales[skeleton.get_bone_name(bone)] = skeleton.get_bone_global_pose(bone).basis.get_scale().x
	var chains: Array[PackedStringArray] = []
	for i in simulator.setting_count:
		var chain := PackedStringArray()
		var bone := skeleton.find_bone(simulator.get_end_bone_name(i))
		while bone >= 0 and chain.find(simulator.get_root_bone_name(i)) < 0:
			chain.insert(0, skeleton.get_bone_name(bone))
			bone = skeleton.get_bone_parent(bone)
		chains.append(chain)
	return {"chains": chains, "escalas": scales}


## El simulador puesto y medido en el personaje que se exporta (su cuerpo es el primer hijo del esqueleto), fuera de él.
## Mientras, el personaje entra en el árbol: fuera de él, Godot no crea las articulaciones.
static func measure(hair: Dictionary, character: Node3D) -> SpringBoneSimulator3D:
	var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
	var tree := (Engine.get_main_loop() as SceneTree).root if not character.is_inside_tree() else null
	if tree:
		tree.add_child(character)
	var simulator := HairPhysics.attach(skeleton, hair["chains"], skeleton.get_child(0) as MeshInstance3D, {"escalas": hair["escalas"]})
	for shape in simulator.get_children():
		shape.bone = skeleton.find_bone(shape.bone_name)
	for i in simulator.setting_count:
		_to_curves(simulator, i)
	skeleton.remove_child(simulator)
	if tree:
		tree.remove_child(character)
	return simulator


## Lo de cada articulación, en curvas del ajuste (las curvas sí se aplican cuando Godot rehace las articulaciones).
static func _to_curves(simulator: SpringBoneSimulator3D, i: int) -> void:
	var n := simulator.get_joint_count(i)
	var radius := 0.0
	for j in n:
		radius = maxf(radius, simulator.get_joint_radius(i, j))
	var radii := Curve.new()
	var stiffness := Curve.new()
	for j in n:
		var at := float(j) / maxf(n - 1, 1)
		radii.add_point(Vector2(at, simulator.get_joint_radius(i, j) / radius), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
		stiffness.add_point(Vector2(at, simulator.get_joint_stiffness(i, j) / simulator.get_joint_stiffness(i, 0)), 0.0, 0.0,
			Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	var values := [simulator.get_joint_stiffness(i, 0), simulator.get_joint_drag(i, 0), simulator.get_joint_gravity(i, 0)]
	simulator.set_individual_config(i, false)
	simulator.set_radius(i, radius)
	simulator.set_radius_damping_curve(i, radii)
	simulator.set_stiffness(i, values[0])
	simulator.set_stiffness_damping_curve(i, stiffness)
	simulator.set_drag(i, values[1])
	simulator.set_gravity(i, values[2])


## Escribe <glb sin extensión>.tscn: hereda del .glb y cuelga el simulador de skeleton_path.
static func save(simulator: SpringBoneSimulator3D, glb_path: String, skeleton_path: String) -> Error:
	for node: Node in [simulator] + simulator.get_children():
		if node != simulator:
			node.owner = simulator
		for key in node.get_meta_list():
			node.remove_meta(key)
	var packed := PackedScene.new()
	var error := packed.pack(simulator)
	if error == OK:
		error = ResourceSaver.save(packed, TEMP)
	if error != OK:
		return error
	var text := FileAccess.get_file_as_string(TEMP)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	var name := glb_path.get_file().get_basename()
	var body := text.substr(text.find("\n[")).strip_edges()  # sin la cabecera [gd_scene …]
	var first := body.find("[node ")
	body = body.substr(0, first) + "[node name=\"%s\" instance=ExtResource(\"1_glb\")]\n\n" % name + body.substr(first)
	body = body.replace("[node name=\"%s\" type=\"SpringBoneSimulator3D\"" % simulator.name,
		"[node name=\"%s\" type=\"SpringBoneSimulator3D\" parent=\"%s\"" % [simulator.name, skeleton_path])
	body = body.replace("parent=\".\"", "parent=\"%s/%s\"" % [skeleton_path, simulator.name])
	# sin unique_id ni índices de hueso: al leer el .glb, Godot ordena los huesos de otra forma (se resuelven por nombre)
	body = RegEx.create_from_string("( unique_id=\\d+|\\n(settings/\\d+/root_|settings/\\d+/end_)?bone = -?\\d+)").sub(body, "", true)
	var file := FileAccess.open(glb_path.get_basename() + ".tscn", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("[gd_scene format=3]\n\n[ext_resource type=\"PackedScene\" path=\"%s\" id=\"1_glb\"]\n\n%s\n"
		% [glb_path.get_file(), body])
	return OK
