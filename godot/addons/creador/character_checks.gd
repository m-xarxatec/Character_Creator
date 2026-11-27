class_name CharacterChecks
extends RefCounted
## Revisa un personaje horneado (el de GlbExporter.build) contra las reglas del personaje exportado (paso 5.3). No cambia nada.
##
## Uso:
##   var results := CharacterChecks.run(character, species.manifest)
##   CharacterChecks.worst(results)   # "bien", "aviso" o "error"
## Cada resultado: {"id": String, "nivel": "bien" | "aviso" | "error", "texto": String, "huesos": PackedStringArray}
## Una entrada por comprobación, también cuando pasa. `huesos`: los afectados, para señalar la zona (paso 5.4).
## Los huesos se comparan con el manifiesto (56 en la humana desde el paso 9.3) y con SkeletonProfileHumanoid (todos
## deben ser suyos); no se exigen los 56 del perfil, para que otra especie pueda tener menos (D10).

const WEIGHT_SUM_EPS := 1e-4  # Godot guarda los pesos en 16 bits: la suma es 1 ± 0,00005 (FORMATO.md)
const SCALE_EPS := 1e-4
const BUDGET := {"triangulos": 40000, "huesos": 75}  # PC, GUIA_ESTILO.md §7: PROPUESTA sin aprobar, por eso solo avisa
const LEVELS := ["bien", "aviso", "error"]
## Pasos 9.7.3 y 9.8: las formas que el .glb puede llevar (expresiones y visemas de VRM 1.0, FORMATO.md).
const EXPRESSIONS := ["happy", "angry", "sad", "surprised", "blinkLeft", "blinkRight", "aa", "ih", "ou", "ee", "oh"]
const MeshChecks := preload("mesh_checks.gd")  # paso P.5b: num() pone la coma decimal
const HairChains := preload("hair_chains.gd")  # paso PE.5: los x_pelo_* cuelgan de Head o de otro x_pelo_*


static func run(character: Node3D, manifest: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var skeletons := character.find_children("*", "Skeleton3D", true, false)
	var meshes := character.find_children("*", "MeshInstance3D", true, false)
	if skeletons.size() != 1 or meshes.size() != 1:
		results.append(_result("estructura", "error", "Hacen falta un esqueleto y una malla; hay %d y %d" % [skeletons.size(), meshes.size()]))
		return results
	var skeleton: Skeleton3D = skeletons[0]
	var mesh: MeshInstance3D = meshes[0]
	results.append(_weight_sums(mesh, skeleton))
	results.append(_four_influences(mesh))
	results.append(_profile_bones(skeleton))
	results.append(_manifest_bones(skeleton, manifest["bones"]["deform"]))
	results.append(_unit_scale(skeleton))
	results.append(_sockets(skeleton, manifest["bones"]["sockets"]))
	results.append(_no_shapes(mesh))
	results.append(_budget(mesh, skeleton))
	return results


static func worst(results: Array) -> String:
	var level := 0
	for result in results:
		level = maxi(level, LEVELS.find(result["nivel"]))
	return LEVELS[level]


static func _result(id: String, level: String, text: String, bones := PackedStringArray()) -> Dictionary:
	return {"id": id, "nivel": level, "texto": text, "huesos": bones}


static func _bone_of(mesh: MeshInstance3D, skeleton: Skeleton3D, bind: int) -> String:
	var bone := mesh.skin.get_bind_bone(bind) if mesh.skin and bind < mesh.skin.get_bind_count() else -1
	return skeleton.get_bone_name(bone) if bone >= 0 and bone < skeleton.get_bone_count() else "?"


static func _weight_sums(mesh: MeshInstance3D, skeleton: Skeleton3D) -> Dictionary:
	var count := 0
	var worst_sum := 1.0
	var bones := PackedStringArray()
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
		for v in weights.size() / 4:
			var total := weights[4 * v] + weights[4 * v + 1] + weights[4 * v + 2] + weights[4 * v + 3]
			if absf(total - 1.0) < WEIGHT_SUM_EPS:
				continue
			count += 1
			if absf(total - 1.0) > absf(worst_sum - 1.0):
				worst_sum = total
			for k in range(4 * v, 4 * v + 4):
				var name := _bone_of(mesh, skeleton, indices[k])
				if weights[k] > 0.0 and not name in bones:
					bones.append(name)
	if count == 0:
		return _result("pesos_suman_1", "bien", "Los pesos de cada vértice suman 1")
	return _result("pesos_suman_1", "error", "%d vértices cuyos pesos no suman 1 (peor: %s)" % [count, MeshChecks.num(worst_sum, 4)], bones)


static func _four_influences(mesh: MeshInstance3D) -> Dictionary:
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var bones: int = (arrays[Mesh.ARRAY_BONES] as PackedInt32Array).size() if arrays[Mesh.ARRAY_BONES] != null else 0
		var weights: int = (arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array).size() if arrays[Mesh.ARRAY_WEIGHTS] != null else 0
		if bones != 4 * vertices or weights != 4 * vertices:
			return _result("cuatro_influencias", "error", "%d influencias por vértice; deben ser 4" % (bones / maxi(vertices, 1)))
	return _result("cuatro_influencias", "bien", "4 influencias por vértice")


## Cada hueso es del perfil y cuelga del hueso que dice el perfil (saltando los del perfil que el personaje no tiene).
static func _profile_bones(skeleton: Skeleton3D) -> Dictionary:
	var profile := SkeletonProfileHumanoid.new()
	var wrong := PackedStringArray()
	for bone in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(bone)
		var index := profile.find_bone(name)
		if HairChains.is_chain_bone(name):
			var parent := skeleton.get_bone_name(skeleton.get_bone_parent(bone)) if skeleton.get_bone_parent(bone) >= 0 else ""
			if parent != "Head" and not HairChains.is_chain_bone(parent):
				wrong.append(name)
			continue
		if index < 0:
			wrong.append(name)
			continue
		var expected := String(profile.get_bone_parent(index))
		while expected != "" and skeleton.find_bone(expected) < 0:
			expected = String(profile.get_bone_parent(profile.find_bone(expected)))
		var parent := skeleton.get_bone_parent(bone)
		var actual := skeleton.get_bone_name(parent) if parent >= 0 else ""
		if actual != expected:
			wrong.append(name)
	if wrong.is_empty():
		return _result("huesos_del_perfil", "bien", "Los %d huesos son del perfil humanoide, con su padre" % skeleton.get_bone_count())
	return _result("huesos_del_perfil", "error", "%d huesos fuera del perfil humanoide o con otro padre" % wrong.size(), wrong)


static func _manifest_bones(skeleton: Skeleton3D, deform: Array) -> Dictionary:
	var odd := PackedStringArray()
	for bone in skeleton.get_bone_count():
		if not skeleton.get_bone_name(bone) in deform and not HairChains.is_chain_bone(skeleton.get_bone_name(bone)):
			odd.append(skeleton.get_bone_name(bone))
	var extra := odd.size()
	for name: String in deform:
		if skeleton.find_bone(name) < 0:
			odd.append(name)
	if odd.is_empty():
		return _result("huesos_del_manifiesto", "bien", "Los %d huesos de deformación del manifiesto" % deform.size())
	return _result("huesos_del_manifiesto", "error",
		"%d huesos que sobran y %d que faltan respecto al manifiesto" % [extra, odd.size() - extra], odd)


static func _unit_scale(skeleton: Skeleton3D) -> Dictionary:
	var wrong := PackedStringArray()
	for bone in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(bone)
		var pose := skeleton.get_bone_pose(bone)
		if rest.basis.get_scale().distance_to(Vector3.ONE) > SCALE_EPS or pose.basis.get_scale().distance_to(Vector3.ONE) > SCALE_EPS \
				or not pose.is_equal_approx(rest):
			wrong.append(skeleton.get_bone_name(bone))
	if wrong.is_empty():
		return _result("escala_1", "bien", "Todos los huesos con escala 1 y en reposo")
	return _result("escala_1", "error", "%d huesos con escala distinta de 1 o fuera del reposo" % wrong.size(), wrong)


static func _sockets(skeleton: Skeleton3D, sockets: Array) -> Dictionary:
	var missing := PackedStringArray()
	var bones := PackedStringArray()
	for socket: String in sockets:
		var holder := skeleton.find_child(socket + "_attachment", true, false) as BoneAttachment3D
		var node := holder.get_node_or_null(NodePath(socket)) as Node3D if holder else null
		if node == null or node.scale.distance_to(Vector3.ONE) > SCALE_EPS or skeleton.find_bone(holder.bone_name) < 0:
			missing.append(socket)
			if holder:
				bones.append(holder.bone_name)
	if missing.is_empty():
		return _result("anclajes", "bien", "Los %d anclajes, con escala 1" % sockets.size())
	return _result("anclajes", "error", "Anclajes que faltan o están mal: " + ", ".join(missing), bones)


## Pasos 9.7.3 y 9.8 (D31): solo pueden quedar las expresiones de VRM (sin el prefijo expr_ de los datos).
static func _no_shapes(mesh: MeshInstance3D) -> Dictionary:
	var count: int = mesh.mesh.get_blend_shape_count() if mesh.mesh is ArrayMesh else 0
	var loose := 0
	for i in count:
		if not String(mesh.mesh.get_blend_shape_name(i)) in EXPRESSIONS:
			loose += 1
	if loose == 0:
		return _result("sin_formas", "bien", "Sin formas sueltas: todo horneado" + (" (y %d expresiones)" % count if count > 0 else ""))
	return _result("sin_formas", "error", "La malla lleva %d formas sin hornear; el personaje no está horneado" % loose)


static func _budget(mesh: MeshInstance3D, skeleton: Skeleton3D) -> Dictionary:
	var triangles := 0
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		triangles += indices.size() / 3 if indices.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	var bones := 0  # paso PE.5: el pelo no cuenta como hueso del cuerpo
	for bone in skeleton.get_bone_count():
		bones += int(not HairChains.is_chain_bone(skeleton.get_bone_name(bone)))
	var text := "%d triángulos (presupuesto %d) y %d huesos (%d)" % [triangles, BUDGET["triangulos"], bones, BUDGET["huesos"]]
	var over := triangles > BUDGET["triangulos"] or bones > BUDGET["huesos"]
	return _result("presupuesto", "aviso" if over else "bien", text)
