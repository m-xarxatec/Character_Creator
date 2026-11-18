extends SceneTree
# Paso 5.8: capturas y medidas de la variante T: (a) hombro y axila en la estocada; (b) las dos manos en reposo.
# Necesita ventana (no --headless). No juzga: mide y guarda las hojas.
# Uso: (ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s probar_variante_t.gd -- [--salida=pruebas/capturas/variante_t] 2>&1 | grep -E 'FALLO|MEDIDA|GUARDADO|RESULTADO|ERROR')
# Por cada cuerpo (neutro y extremo = todo a 1):
#   <cuerpo>_hombro.png  toon · sin luces · toon sin las normales del estilo · hundimiento T · hundimiento A
#   <cuerpo>_manos.png   fila izquierda y fila derecha: desde delante, desde arriba y desde el lado
# Hundimiento: en los vértices cuyo hueso de más peso es RightUpperArm, RightShoulder o UpperChest, distancia al eje de
# ese hueso en reposo menos la misma distancia en la pose (positivo = la piel se acerca al hueso). Azul = 0 o menos,
# rojo = 2 cm o más, gris = resto de la malla. La variante A se anima desde su pose T, como tras corregir la silueta al importar.
# Que detecta el fallo: --girar (gira la mano derecha 20° sobre el brazo antes de medir) -> falla el ángulo de la palma.

const TILE := Vector2i(480, 480)
const SEED := 7
const STEPS := 50
const SINK_BONES := {"RightUpperArm": "RightLowerArm", "RightShoulder": "RightUpperArm", "UpperChest": "Neck"}  # hueso: su hijo (el eje)
const SINK_RED := 0.02
const MAX_PALM_DEG := 1.0  # el límite de pose T del 3.6.2
const MAX_ASYMMETRY_MM := 0.5  # medido 0,29 mm (la pose T en la piel; no se ve). Aprobado el 2026-11-18

var failures := 0
var root_dir: String
var options := {}
var species
var updater
var animations
var exporter: GDScript
var baker: GDScript
var mesh_baker: GDScript
var t_pose: GDScript
var static_pose: GDScript
var retarget_script: GDScript
var material_script: GDScript
var view: SubViewport
var camera: Camera3D
var caption: Label


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var addon := root_dir.path_join("godot/addons/creador")
	exporter = load(addon.path_join("glb_exporter.gd"))
	baker = load(addon.path_join("character_baker.gd"))
	mesh_baker = load(addon.path_join("mesh_baker.gd"))
	t_pose = load(addon.path_join("t_pose.gd"))
	static_pose = load(addon.path_join("static_pose.gd"))
	retarget_script = load(addon.path_join("pose_retarget.gd"))
	material_script = load(addon.path_join("body_material.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	animations = load(addon.path_join("animation_set.gd")).new()
	var error: String = animations.load_file(root_dir.path_join("godot/datos/animaciones/humanoide.json"))
	if error:
		print("ERROR: ", error)
		quit(1)
		return
	_make_view()
	view.add_child(species.scene)
	view.add_child(animations.scene)
	species.scene.visible = false
	animations.scene.visible = false
	material_script.apply(species.mesh)
	var preset_script: GDScript = load(addon.path_join("preset.gd"))
	preset_script.apply_look(species.mesh, preset_script.from_text(species.preset_text(), "humana", species.sliders))
	updater = load(addon.path_join("character_updater.gd")).new(species)
	var out: String = options.get("salida", "pruebas/capturas/variante_t")
	out = out if out.is_absolute_path() else root_dir.path_join(out).simplify_path()
	DirAccess.make_dir_recursive_absolute(out)
	for body: String in ["neutro", "extremo"]:
		updater.update(_values(body), false)
		await _shoulder(body, out)
		await _hands(body, out)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _values(body: String) -> Dictionary:
	var values := {}
	if body == "extremo":
		for row: Dictionary in species.sliders:
			if row["tipo"] != "Por crear":
				for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
					values[row["id"] + side] = 1.0
	return values


func _make_view() -> void:
	view = SubViewport.new()
	view.size = TILE
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	camera = Camera3D.new()
	camera.fov = 35.0
	view.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	view.add_child(light)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.75, 0.78, 0.82)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.6, 0.65, 0.8)
	world.environment.ambient_light_energy = 0.25
	view.add_child(world)
	caption = Label.new()
	caption.position = Vector2(8, 4)
	caption.add_theme_color_override("font_color", Color.BLACK)
	view.add_child(caption)


## Personaje exportado (variante T o A) dentro de la vista, con el material del juego.
func _character(t_variant: bool) -> Node3D:
	var character: Node3D = exporter.build(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], t_variant)
	_mesh(character).material_override = material_script.standalone(species.mesh)
	view.add_child(character)
	return character


func _skeleton(character: Node3D) -> Skeleton3D:
	return character.find_children("*", "Skeleton3D", true, false)[0]


func _mesh(character: Node3D) -> MeshInstance3D:
	return character.find_children("*", "MeshInstance3D", true, false)[0]


func _origin(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


func _shoot(text: String, sheet: Image, cell: Vector2i) -> void:
	caption.text = text
	for f in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(image, Rect2i(Vector2i.ZERO, TILE), cell * TILE)


# ---------- (a) hombro y axila ----------

func _shoulder(body: String, out: String) -> void:
	var sheet := Image.create(TILE.x * 5, TILE.y, false, Image.FORMAT_RGBA8)
	var character := _character(true)
	await process_frame
	var skeleton := _skeleton(character)
	var mesh := _mesh(character)
	var retarget = retarget_script.new(animations.skeleton, skeleton, animations.bones, animations.hips)
	retarget.capture()
	var highest := -INF
	var instant := 0.0
	for step in STEPS:
		_attack(retarget, float(step) / STEPS)
		if _origin(skeleton, "RightHand").y > highest:
			highest = _origin(skeleton, "RightHand").y
			instant = float(step) / STEPS
	print("  MEDIDA %s: brazo más alto en «Atacar» a %.2f de la animación (mano derecha a %.3f m)" % [body, instant, highest])
	_attack(retarget, instant)
	_aim_shoulder(skeleton)
	await _shoot("%s · T · toon" % body, sheet, Vector2i(0, 0))
	material_script.set_unlit(mesh, true)
	await _shoot("%s · T · sin luces" % body, sheet, Vector2i(1, 0))
	material_script.set_unlit(mesh, false)
	var styled := mesh.mesh
	mesh.mesh = _without_style(styled)
	await _shoot("%s · T · sin normales del estilo" % body, sheet, Vector2i(2, 0))
	mesh.mesh = styled
	await _sink_tile(body, "T", character, sheet, 3)
	character.free()

	character = _character(false)
	await process_frame
	skeleton = _skeleton(character)
	t_pose.apply(skeleton)  # la A se anima desde su pose T (lo que hace el importador al corregir la silueta)
	retarget = retarget_script.new(animations.skeleton, skeleton, animations.bones, animations.hips)
	retarget.capture()
	_attack(retarget, instant)
	_aim_shoulder(skeleton)
	await _sink_tile(body, "A", character, sheet, 4)
	character.free()
	var path := out.path_join(body + "_hombro.png")
	sheet.save_png(path)
	print("GUARDADO ", path)


func _attack(retarget, instant: float) -> void:
	animations.play("atacar")
	animations.seek(animations.length() * instant)
	retarget.apply()


func _aim_shoulder(skeleton: Skeleton3D) -> void:
	var shoulder := _origin(skeleton, "RightUpperArm")
	var size := _origin(skeleton, "Head").y / 1.5
	camera.look_at_from_position(shoulder + Vector3(-0.3, -0.1, 0.8) * size, shoulder + Vector3(0, -0.08, 0) * size)


## La misma malla con las normales del horneado, sin las del estilo (style_normals.gd).
func _without_style(styled: Mesh) -> ArrayMesh:
	var plain: Node3D = baker.bake(species.mesh, species.skeleton, true)
	var arrays := styled.surface_get_arrays(0)
	arrays[Mesh.ARRAY_NORMAL] = _mesh(plain).mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	arrays[Mesh.ARRAY_TANGENT] = null
	plain.free()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _sink_tile(body: String, variant: String, character: Node3D, sheet: Image, column: int) -> void:
	var skeleton := _skeleton(character)
	var mesh := _mesh(character)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var rest: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var posed: PackedVector3Array = mesh_baker.bake(mesh, skeleton)["vertices"]
	var owners := _main_bones(mesh, skeleton)
	var colors := PackedColorArray()
	colors.resize(rest.size())
	var deepest := -INF
	var deepest_vertex := -1
	for vertex in rest.size():
		var bone: String = skeleton.get_bone_name(owners[vertex])
		if not SINK_BONES.has(bone):
			colors[vertex] = Color(0.6, 0.6, 0.6)
			continue
		var child := skeleton.find_bone(SINK_BONES[bone])
		var at_rest := _to_axis(rest[vertex], skeleton.get_bone_global_rest(owners[vertex]).origin, skeleton.get_bone_global_rest(child).origin)
		var in_pose := _to_axis(posed[vertex], skeleton.get_bone_global_pose(owners[vertex]).origin, skeleton.get_bone_global_pose(child).origin)
		var sink := at_rest - in_pose
		if sink > deepest:
			deepest = sink
			deepest_vertex = vertex
		var red := clampf(sink / SINK_RED, 0.0, 1.0)
		colors[vertex] = Color(red, 0.0, 1.0 - red)
	print("  MEDIDA %s, variante %s: hundimiento máximo %.1f mm (vértice %d, hueso %s)" % [body, variant, 1000.0 * deepest,
		deepest_vertex, skeleton.get_bone_name(owners[deepest_vertex])])
	var map_arrays := []
	map_arrays.resize(Mesh.ARRAY_MAX)
	map_arrays[Mesh.ARRAY_VERTEX] = posed
	map_arrays[Mesh.ARRAY_COLOR] = colors
	map_arrays[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	var map_mesh := ArrayMesh.new()
	map_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, map_arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	var map := MeshInstance3D.new()
	map.mesh = map_mesh
	map.material_override = material
	view.add_child(map)
	character.visible = false
	await _shoot("%s · %s · hundimiento (máx. %.1f mm)" % [body, variant, 1000.0 * deepest], sheet, Vector2i(column, 0))
	character.visible = true
	map.free()


## Por vértice: el hueso con más peso.
func _main_bones(mesh: MeshInstance3D, skeleton: Skeleton3D) -> PackedInt32Array:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var binds: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var owners := PackedInt32Array()
	owners.resize(binds.size() / 4)
	for vertex in owners.size():
		var best := 0
		for i in 4:
			if weights[4 * vertex + i] > weights[4 * vertex + best]:
				best = i
		var bind := binds[4 * vertex + best]
		var bone := mesh.skin.get_bind_bone(bind)
		owners[vertex] = bone if bone >= 0 else skeleton.find_bone(mesh.skin.get_bind_name(bind))
	return owners


## Distancia del punto a la recta que pasa por a y b.
func _to_axis(point: Vector3, a: Vector3, b: Vector3) -> float:
	var axis := (b - a).normalized()
	return ((point - a) - axis * (point - a).dot(axis)).length()


# ---------- (b) manos ----------

func _hands(body: String, out: String) -> void:
	var character := _character(true)
	await process_frame
	var skeleton := _skeleton(character)
	var mesh := _mesh(character)
	if options.has("girar"):
		static_pose.apply(skeleton, {"RightHand": [20, 0, 0]}, animations.hips, [])
	var vertices: PackedVector3Array = mesh_baker.bake(mesh, skeleton)["vertices"]
	var owners := _main_bones(mesh, skeleton)
	var hands := {"Left": PackedInt32Array(), "Right": PackedInt32Array()}  # vértices de la mano y los dedos
	var palms := {"Left": AABB(), "Right": AABB()}  # solo el hueso de la mano
	var started := {}
	for vertex in vertices.size():
		var bone := skeleton.get_bone_name(owners[vertex])
		for side: String in hands:
			if bone == side + "Hand":
				palms[side] = palms[side].expand(vertices[vertex]) if started.has(side) else AABB(vertices[vertex], Vector3.ZERO)
				started[side] = true
			if bone.begins_with(side) and _in_hand(skeleton, owners[vertex], side):
				hands[side].append(vertex)
	for side: String in hands:
		var across := _origin(skeleton, side + "IndexProximal") - _origin(skeleton, side + "LittleProximal")
		var around_arm := rad_to_deg(Vector3(0, across.y, across.z).angle_to(Vector3.BACK))
		print("  MEDIDA %s, mano %s: palma (índice − meñique) girada %.3f° sobre el brazo respecto a +Z; el vector entero, %.2f° de +Z" % [
			body, side, around_arm, rad_to_deg(across.angle_to(Vector3.BACK))])
		check("%s, mano %s: la palma mira abajo, índice delante (< %s° sobre el brazo)" % [body, side, MAX_PALM_DEG],
			around_arm < MAX_PALM_DEG, "%.3f°" % around_arm)
		print("  MEDIDA %s, mano %s: palma de %.1f mm de grosor (vista de frente) y %.1f mm de ancho (vista desde arriba); %d vértices" % [
			body, side, 1000.0 * palms[side].size.y, 1000.0 * palms[side].size.z, hands[side].size()])
	var thick: float = absf(palms["Right"].size.y - palms["Left"].size.y) / palms["Left"].size.y
	var wide: float = absf(palms["Right"].size.z - palms["Left"].size.z) / palms["Left"].size.z
	print("  MEDIDA %s: derecha contra izquierda, grosor %.2f %%, ancho %.2f %%" % [body, 100.0 * thick, 100.0 * wide])
	var asymmetry := _asymmetry(vertices, hands)
	var source: PackedVector3Array = mesh_baker.bake(species.mesh, species.skeleton)["vertices"]
	print("  MEDIDA %s: asimetría máxima entre las manos %.4f mm (en la malla de MakeHuman antes de la pose T, %.4f mm)" % [
		body, 1000.0 * asymmetry, 1000.0 * _asymmetry(source, hands)])
	for bone: String in ["Shoulder", "UpperArm", "LowerArm", "Hand", "MiddleProximal"]:
		var left := _origin(skeleton, "Left" + bone)
		print("  MEDIDA %s: hueso %s, izquierdo reflejado contra derecho %.4f mm" % [body, bone,
			1000.0 * Vector3(-left.x, left.y, left.z).distance_to(_origin(skeleton, "Right" + bone))])
	if body == "neutro":
		check("neutro: las manos son simétricas (< %s mm)" % MAX_ASYMMETRY_MM, 1000.0 * asymmetry < MAX_ASYMMETRY_MM,
			"%.4f mm" % (1000.0 * asymmetry))

	var sheet := Image.create(TILE.x * 3, TILE.y * 2, false, Image.FORMAT_RGBA8)
	var sides := ["Left", "Right"]
	for row in 2:
		var out_side := Vector3.RIGHT if sides[row] == "Left" else Vector3.LEFT
		var center := _origin(skeleton, sides[row] + "MiddleProximal")
		var shots := [["delante", Vector3.BACK, Vector3.UP], ["arriba", Vector3.UP, Vector3.FORWARD], ["lado", out_side, Vector3.UP]]
		for column in 3:
			camera.look_at_from_position(center + shots[column][1] * 0.55, center, shots[column][2])
			await _shoot("%s · mano %s · desde %s" % [body, "izquierda" if row == 0 else "derecha", shots[column][0]], sheet,
				Vector2i(column, row))
	character.free()
	var path := out.path_join(body + "_manos.png")
	sheet.save_png(path)
	print("GUARDADO ", path)


## La mayor distancia de un vértice de la mano izquierda, reflejado en X, al vértice más cercano de la derecha.
func _asymmetry(vertices: PackedVector3Array, hands: Dictionary) -> float:
	var worst := 0.0
	for left: int in hands["Left"]:
		var mirrored := Vector3(-vertices[left].x, vertices[left].y, vertices[left].z)
		var nearest := INF
		for right: int in hands["Right"]:
			nearest = minf(nearest, mirrored.distance_squared_to(vertices[right]))
		worst = maxf(worst, sqrt(nearest))
	return worst


## ¿El hueso es la mano de ese lado o cuelga de ella (dedos)?
func _in_hand(skeleton: Skeleton3D, bone: int, side: String) -> bool:
	while bone >= 0:
		if skeleton.get_bone_name(bone) == side + "Hand":
			return true
		bone = skeleton.get_bone_parent(bone)
	return false
