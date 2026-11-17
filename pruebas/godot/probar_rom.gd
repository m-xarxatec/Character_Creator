extends SceneTree
# Paso 5.9: rango de movimiento (godot/app/rom.gd y godot/datos/animaciones/rom.json) sobre el personaje exportado. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_rom.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en rom.gd (move_turns), usar el mismo eje en los dos lados -> falla la simetría en los
# movimientos alrededor de Y y de Z.

const ANGLE_DEG := 0.1  # PROVISIONAL (D26)
const MIRROR_MM := 0.1  # PROVISIONAL (D26)
const TIPS := {"UpperArm": "Hand", "LowerArm": "Hand", "Hand": "MiddleProximal", "UpperLeg": "Foot", "LowerLeg": "Foot",
	"Foot": "Toes"}  # el punto que se compara en espejo

var failures := 0
var rom_script: GDScript
var rom
var static_pose: GDScript
var mesh_checks: GDScript
var skeleton: Skeleton3D
var mesh: MeshInstance3D


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	rom_script = load(root_dir.path_join("godot/app/rom.gd"))
	static_pose = load(addon.path_join("static_pose.gd"))
	mesh_checks = load(addon.path_join("mesh_checks.gd"))
	rom = rom_script.new()
	var error: String = rom.load_file(root_dir.path_join("godot/datos/animaciones/rom.json"))
	check("rom.json carga", error == "", error)
	var species = load(addon.path_join("species_data.gd")).new()
	if error or species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", error if error else species.error)
		quit(1)
		return
	root.add_child(species.scene)
	load(addon.path_join("character_updater.gd")).new(species).update({}, false)
	var character: Node3D = load(addon.path_join("glb_exporter.gd")).build(species.mesh, species.skeleton,
		species.manifest["bones"]["sockets"], true)
	root.add_child(character)
	await process_frame
	skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	mesh = character.find_children("*", "MeshInstance3D", true, false)[0]
	_check_bones()
	_check_angle()
	for move: Dictionary in rom.moves:
		_check_move(move)
	character.free()
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	if not ok or label.begins_with("·"):
		print(("  bien  " if ok else "  FALLO ") + label.trim_prefix("·"), " ", detail)
	if not ok:
		failures += 1


func _check_bones() -> void:
	var missing := []
	for move: Dictionary in rom.moves:
		for bone: String in rom_script.move_turns(move, 1.0):
			if skeleton.find_bone(bone) < 0:
				missing.append(bone)
	check("·todos los huesos de rom.json existen (%d movimientos)" % rom.moves.size(), missing.is_empty(), str(missing))


func _check_angle() -> void:
	var values := [rom_script.angle(-80, 90, 0.0), rom_script.angle(-80, 90, 0.25), rom_script.angle(-80, 90, 0.75),
		rom_script.angle(-80, 90, 1.0)]
	check("·angle: en t = 0, 0,25, 0,75 y 1 da 0, desde, hasta y 0", values == [0.0, -80.0, 90.0, 0.0], str(values))


func _global_rotation(bone: String) -> Quaternion:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).basis.get_rotation_quaternion()


func _check_move(move: Dictionary) -> void:
	var sides: Array = ["Left", "Right"] if int(move["lados"]) == 2 else [""]
	var axis := Vector3(move["eje"][0], move["eje"][1], move["eje"][2])
	var reference := {}
	for side: String in sides:
		reference[side] = _global_rotation(side + move["hueso"])
	for t: float in [0.25, 0.75]:
		var wanted: float = move["desde"] if t == 0.25 else move["hasta"]
		skeleton.reset_bone_poses()
		static_pose.apply(skeleton, rom.turns(move["id"], t), "Hips", [])
		var worst := 0.0
		for side: String in sides:
			var side_axis := Vector3(axis.x, -axis.y, -axis.z) if side == "Right" else axis
			var expected := Quaternion(side_axis, deg_to_rad(wanted))
			var turned: Quaternion = _global_rotation(side + move["hueso"]) * reference[side].inverse()
			worst = maxf(worst, rad_to_deg(turned.angle_to(expected)))
		check("%s %s: el hueso gira %s° (± %s°)" % [move["id"], "desde" if t == 0.25 else "hasta", wanted, ANGLE_DEG],
			worst < ANGLE_DEG, "%.4f°" % worst)
		if sides.size() == 2 and TIPS.has(move["hueso"]):
			var left := skeleton.get_bone_global_pose(skeleton.find_bone("Left" + TIPS[move["hueso"]])).origin
			var right := skeleton.get_bone_global_pose(skeleton.find_bone("Right" + TIPS[move["hueso"]])).origin
			var mirror := 1000.0 * right.distance_to(Vector3(-left.x, left.y, left.z))
			check("%s %s: el lado derecho es el espejo del izquierdo (< %s mm)" % [move["id"], t, MIRROR_MM], mirror < MIRROR_MM,
				"%.4f mm" % mirror)
		var results: Array[Dictionary] = mesh_checks.run(mesh, skeleton)
		var worst_of := {}
		for result in results:
			if not worst_of.has(result["id"]) or result["valor"] > worst_of[result["id"]]["valor"]:
				worst_of[result["id"]] = result
		var posed: PackedVector3Array = load(ProjectSettings.globalize_path("res://").path_join(
			"../../godot/addons/creador/mesh_baker.gd").simplify_path()).bake(mesh, skeleton)["vertices"]
		var nan := 0
		for p in posed:
			if is_nan(p.x) or is_nan(p.y) or is_nan(p.z):
				nan += 1
		check("%s %s: sin vértices NaN ni triángulos degenerados nuevos" % [move["id"], t],
			nan == 0 and worst_of["degenerados"]["valor"] == 0.0, "%d NaN, %d degenerados" % [nan, worst_of["degenerados"]["valor"]])
		print("  MEDIDA %s %s (%s°): sección %.1f %% (%s), estiramiento ×%.2f, cruce %.0f mm" % [move["id"],
			"desde" if t == 0.25 else "hasta", wanted, worst_of["seccion"]["valor"], ",".join(worst_of["seccion"]["huesos"]),
			worst_of["estiramiento"]["valor"], worst_of["cruce"]["valor"]])
	skeleton.reset_bone_poses()
