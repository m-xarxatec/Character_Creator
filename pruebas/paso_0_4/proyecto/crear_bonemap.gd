extends SceneTree
# Crea el BoneMap humanoide de cada .glb y lo apunta en su archivo .import.
# Uso: godot --headless --path . -s crear_bonemap.gd   (y despues: godot --headless --path . --import)

const FILES := ["humano.glb", "UAL1_Standard.glb"]
const KEEP_AS_IS: Array[StringName] = [&"Hips", &"Spine", &"Chest", &"UpperChest", &"Neck", &"Head", &"LeftUpperLeg", &"LeftLowerLeg", &"LeftFoot", &"LeftToes", &"RightUpperLeg", &"RightLowerLeg", &"RightFoot", &"RightToes"]
const FINGERS := {"Thumb": "thumb", "Index": "index", "Middle": "middle", "Ring": "ring", "Little": "pinky"}

func _init() -> void:
	for file: String in FILES:
		_map_file(file)
	quit()

# Tabla: hueso del perfil humanoide de Godot -> nombre estilo Unreal (el de MPFB y el de Quaternius).
func _table() -> Dictionary:
	var t := {
		"Root": "root", "Hips": "pelvis", "Spine": "spine_01", "Chest": "spine_02",
		"UpperChest": "spine_03", "Neck": "neck_01", "Head": "head",
	}
	for side: Array in [["Left", "_l"], ["Right", "_r"]]:
		var s: String = side[0]
		var x: String = side[1]
		t[s + "Shoulder"] = "clavicle" + x
		t[s + "UpperArm"] = "upperarm" + x
		t[s + "LowerArm"] = "lowerarm" + x
		t[s + "Hand"] = "hand" + x
		t[s + "UpperLeg"] = "thigh" + x
		t[s + "LowerLeg"] = "calf" + x
		t[s + "Foot"] = "foot" + x
		t[s + "Toes"] = "ball" + x
		for finger: String in FINGERS:
			var parts := ["Metacarpal", "Proximal", "Distal"] if finger == "Thumb" else ["Proximal", "Intermediate", "Distal"]
			for i in 3:
				t[s + finger + parts[i]] = "%s_0%d%s" % [FINGERS[finger], i + 1, x]
	return t

func _map_file(file: String) -> void:
	# Se lee el .glb original (no el importado) para ver los nombres de hueso sin renombrar.
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_file("res://" + file, state)
	var scene: Node = doc.generate_scene(state)
	var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var real := {}  # nombre en minusculas -> nombre real del hueso
	for i in skel.get_bone_count():
		real[skel.get_bone_name(i).to_lower()] = skel.get_bone_name(i)
	var profile := SkeletonProfileHumanoid.new()
	var map := BoneMap.new()
	map.profile = profile
	var table := _table()
	var missing: PackedStringArray = []
	for i in profile.bone_size:
		var bone := profile.get_bone_name(i)
		if table.has(bone) and real.has(table[bone]):
			map.set_skeleton_bone_name(bone, real[table[bone]])
		else:
			missing.append(bone + (" (OBLIGATORIO)" if profile.is_required(i) else ""))
	var map_path := "res://bonemap_%s.tres" % file.get_basename()
	ResourceSaver.save(map, map_path)
	var cfg := ConfigFile.new()
	cfg.load("res://%s.import" % file)
	var node_key := "PATH:" + str(scene.get_path_to(skel))
	cfg.set_value("params", "_subresources", {"nodes": {node_key: {
		"retarget/bone_map": load(map_path),
		# Lleva la pose de reposo a pose T (MPFB sale en pose A y sin esto los brazos se rompen).
		"retarget/rest_fixer/fix_silhouette/enable": true,
		# Solo se corrigen los brazos: enderezar columna y piernas deforma la barriga.
		"retarget/rest_fixer/fix_silhouette/filter": KEEP_AS_IS,
	}}})
	cfg.save("res://%s.import" % file)
	print(file, " -> ", node_key, " | asignados ", profile.bone_size - missing.size(), "/", profile.bone_size, " | sin asignar: ", ", ".join(missing))
	scene.free()
