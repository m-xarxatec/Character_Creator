extends SceneTree
# Paso 5.7: mide cómo se anima el personaje ya importado por el editor, con y sin «Overwrite Axis».
# No se lanza a mano: lo ejecuta pruebas/fase_5/probar_overwrite_axis.sh (crea el proyecto, copia los .glb e importa).
#   -- --preparar   escribe el BoneMap y los ajustes en cada .import, según el nombre del archivo (ver el .sh)
#   sin argumentos  anima cada personaje con la biblioteca y mide el ángulo entre cada tramo de hueso (articulación →
#                   articulación siguiente) y el mismo tramo de la biblioteca: en reposo (diferencia de silueta; el tramo
#                   Hips → Spine se da aparte: la pelvis de la biblioteca está en otro sitio) y cuánto cambia ese ángulo
#                   al animar (0 = se anima igual que la biblioteca); y la distancia de cada articulación a t_con.
# Sin BoneMap (_sin_mapa) el importador no pone Skeleton3D.motion_scale y la cadera se desplaza con la escala de la
# biblioteca: se mide tal cual (solo medida) y con motion_scale = altura de la cadera (_sin_mapa_escala, con límite).
# Que detecta el fallo: importar t_con con retarget_method = 0 (como t_sin) -> falla «t_con se anima bien».

const LIBRARY := "UAL1_Standard"
const KEEP_AS_IS: Array[StringName] = [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head", &"LeftUpperLeg",
	&"LeftLowerLeg", &"LeftFoot", &"LeftToes", &"RightUpperLeg", &"RightLowerLeg", &"RightFoot", &"RightToes"]
const CLIPS := ["Walk", "Sword_Attack", "Sitting_Idle"]
const TIMES := [0.2, 0.5, 0.8]
const SEGMENTS := [["Hips", "Spine"], ["Spine", "Chest"], ["Chest", "UpperChest"], ["Neck", "Head"],
	["Shoulder", "UpperArm"], ["UpperArm", "LowerArm"], ["LowerArm", "Hand"], ["Hand", "MiddleProximal"],
	["UpperLeg", "LowerLeg"], ["LowerLeg", "Foot"], ["Foot", "Toes"]]  # sin lado: se miden Left y Right
const MAX_DEGREES := 5.0  # PROVISIONAL: «se anima bien» (ficha 5.7, §5)
const MAX_JOINT_MM := 1.0  # PROVISIONAL: prototipo sin Overwrite Axis contra t_con (ficha 5.7, §6)

var failures := 0
var joints := {}  # variante -> posiciones de todas las articulaciones en todos los instantes


func _initialize() -> void:
	var names: PackedStringArray = []
	for file in DirAccess.get_files_at("res://"):
		if file.ends_with(".glb"):
			names.append(file.get_basename())
	if OS.get_cmdline_user_args().has("--preparar"):
		for name in names:
			_prepare(name)
		quit()
		return
	await process_frame  # los reproductores no mueven los huesos antes del primer fotograma
	var worst := {}
	for name in names:
		if name != LIBRARY:
			worst[name] = await _measure(name, name)
			if name.ends_with("_sin_mapa"):  # sin BoneMap el importador deja motion_scale en 1: se mide también puesto a mano
				await _measure(name, name + "_escala")
	check("t_con (pose T + Overwrite Axis) se anima como la biblioteca (< %s°)" % MAX_DEGREES, worst.get("t_con", INF) < MAX_DEGREES,
		"%.2f°" % worst.get("t_con", INF))
	for name: String in joints:
		if name != "t_con" and name.begins_with("t_") and joints.has("t_con"):
			var far := 0.0
			for i in joints[name].size():
				far = maxf(far, 1000.0 * joints[name][i].distance_to(joints["t_con"][i]))
			print("  MEDIDA %s: articulaciones contra t_con, máx. %.3f mm" % [name, far])
			if name.begins_with("t_perfil") and not name.ends_with("_sin_mapa"):
				check("%s se anima como t_con (< %s mm)" % [name, MAX_JOINT_MM], far < MAX_JOINT_MM, "%.3f mm" % far)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _prepare(name: String) -> void:
	var library := name == LIBRARY
	var settings := {}
	if library or not name.ends_with("_sin_mapa"):
		var map_path := "res://bonemap_%s.tres" % name
		if not library:  # el personaje ya usa los nombres del perfil
			var map := BoneMap.new()
			map.profile = SkeletonProfileHumanoid.new()
			for i in map.profile.bone_size:
				map.set_skeleton_bone_name(map.profile.get_bone_name(i), map.profile.get_bone_name(i))
			ResourceSaver.save(map, map_path)
		settings = {
			"retarget/bone_map": load(map_path),
			"retarget/rest_fixer/retarget_method": 1 if library or name.contains("_con") else 0,  # 0 = ninguno; 1 = Overwrite Axis
			"retarget/rest_fixer/fix_silhouette/enable": library or name.ends_with("_silueta"),
			"retarget/rest_fixer/fix_silhouette/filter": KEEP_AS_IS,
		}
	var cfg := ConfigFile.new()
	cfg.load("res://%s.glb.import" % name)
	cfg.set_value("params", "_subresources", {"nodes": {"PATH:Armature/Skeleton3D": settings}} if settings else {})
	cfg.save("res://%s.glb.import" % name)
	print("PREPARADO ", name, " ", settings.get("retarget/rest_fixer/retarget_method", "sin mapa"))


## Devuelve lo máximo que un tramo se aparta, al animar, de su diferencia en reposo con la biblioteca (grados).
func _measure(file: String, name: String) -> float:
	var human: Node3D = (load("res://%s.glb" % file) as PackedScene).instantiate()
	var source: Node3D = (load("res://%s.glb" % LIBRARY) as PackedScene).instantiate()
	root.add_child(human)
	root.add_child(source)
	var skeleton: Skeleton3D = human.find_children("*", "Skeleton3D", true, false)[0]
	var source_skeleton: Skeleton3D = source.find_children("*", "Skeleton3D", true, false)[0]
	if skeleton.name != source_skeleton.name:  # sin BoneMap el importador no lo renombra: las pistas no lo encontrarían
		skeleton.name = source_skeleton.name
		skeleton.unique_name_in_owner = true
	if name.ends_with("_escala"):  # lo que hace el importador con BoneMap: la altura de la cadera en reposo
		skeleton.motion_scale = skeleton.get_bone_global_rest(skeleton.find_bone("Hips")).origin.y
	var source_player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
	var player := AnimationPlayer.new()
	human.add_child(player)
	player.add_animation_library("", source_player.get_animation_library(""))
	for p: AnimationPlayer in [player, source_player]:  # a mano: si no, el clip sigue avanzando entre una medida y otra
		p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rest := _angles(skeleton, source_skeleton)
	var worst := 0.0
	var total := 0.0
	var count := 0
	var where := ""
	joints[name] = PackedVector3Array()
	for clip: String in CLIPS:
		if not player.has_animation(clip):
			check("la biblioteca tiene el clip " + clip, false)
			continue
		for time: float in TIMES:
			for p: AnimationPlayer in [player, source_player]:
				p.play(clip)
				p.seek(time * p.current_animation_length, true)
				p.advance(0)
			await process_frame
			var angles := _angles(skeleton, source_skeleton)
			for segment: String in angles:
				var extra := absf(angles[segment] - rest[segment])
				total += extra
				count += 1
				if extra > worst:
					worst = extra
					where = "%s en %s a %.1f" % [segment, clip, time]
			for bone in skeleton.get_bone_count():
				joints[name].append((_to_scene(skeleton) * skeleton.get_bone_global_pose(bone)).origin)
	var rest_worst := 0.0
	var rest_where := ""
	for segment: String in rest:
		if rest[segment] > rest_worst and segment != "Hips":
			rest_worst = rest[segment]
			rest_where = segment
	print("  MEDIDA %s: silueta en reposo contra la biblioteca, máx. %.2f° (%s; Hips %.2f°); al animar se aparta de eso máx. %.2f°, media %.2f° (%s)"
		% [name, rest_worst, rest_where, rest.get("Hips", 0.0), worst, total / maxi(count, 1), where])
	human.free()
	source.free()
	return worst


## {tramo: grados} entre la dirección del tramo en el personaje y en la biblioteca.
func _angles(skeleton: Skeleton3D, source: Skeleton3D) -> Dictionary:
	var angles := {}
	for segment: Array in SEGMENTS:
		for side: String in ["Left", "Right", ""]:
			var mine = _direction(skeleton, side + segment[0], side + segment[1])
			var theirs = _direction(source, side + segment[0], side + segment[1])
			if mine != null and theirs != null:
				angles[side + segment[0]] = rad_to_deg(mine.angle_to(theirs))
	return angles


func _direction(skeleton: Skeleton3D, from: String, to: String) -> Variant:
	var a := skeleton.find_bone(from)
	var b := skeleton.find_bone(to)
	if a < 0 or b < 0:
		return null
	return _to_scene(skeleton).basis * (skeleton.get_bone_global_pose(b).origin - skeleton.get_bone_global_pose(a).origin)


## Transformación del esqueleto respecto a la raíz de su escena (global_transform no vale en _initialize: sin árbol).
func _to_scene(node: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	while node != null and node.get_parent() != root:
		transform = node.transform * transform
		node = node.get_parent() as Node3D
	return transform
