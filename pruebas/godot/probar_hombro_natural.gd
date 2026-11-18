extends SceneTree
# Paso 5.15: el hombro en la pose T (t_pose.gd, con la clavícula haciendo CLAVICLE_SHARE de la subida del brazo).
# Necesita ventana. Mide (lado derecho; w = |x de la articulación del brazo|):
#   articulación: lo que sube respecto a la T sin clavícula (la clavícula como en la A)
#   trapecio: pendiente en grados de la piel de arriba entre el lado del cuello (x = 0,45 w) y encima de la articulación
#   cúpula: piel encima de la articulación menos la del brazo a 0,6 w hacia fuera (positivo = el hombro asoma)
# Hoja: <salida>/hombro_natural.png; columnas «sin clavícula» y «con clavícula»; filas neutro y extremo, de frente y
# de tres cuartos.
# Uso: (ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s probar_hombro_natural.gd -- [--salida=pruebas/capturas/hombro_natural] 2>&1 | grep -E 'FALLO|MEDIDA|GUARDADO|RESULTADO|ERROR')

const TILE := Vector2i(400, 400)
const BODIES := ["neutro", "extremo"]

var failures := 0
var species
var t_pose: GDScript
var mesh_baker: GDScript
var view: SubViewport
var camera: Camera3D
var caption: Label


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var options := {}
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "1"
	var addon := root_dir.path_join("godot/addons/creador")
	t_pose = load(addon.path_join("t_pose.gd"))
	mesh_baker = load(addon.path_join("mesh_baker.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	_make_view()
	view.add_child(species.scene)
	var material_script: GDScript = load(addon.path_join("body_material.gd"))
	material_script.apply(species.mesh)
	var preset_script: GDScript = load(addon.path_join("preset.gd"))
	preset_script.apply_look(species.mesh, preset_script.from_text(species.preset_text(), "humana", species.sliders))
	var updater = load(addon.path_join("character_updater.gd")).new(species)
	var sheet := Image.create(TILE.x * 2, TILE.y * 4, false, Image.FORMAT_RGBA8)
	for row in BODIES.size():
		updater.update(_values(BODIES[row]), false)
		var before := {}
		for column in 2:
			var share: float = 0.0 if column == 0 else t_pose.CLAVICLE_SHARE
			t_pose.apply(species.skeleton, share)
			var measured := _measure()
			if column == 0:
				before = measured
			print("  MEDIDA %s, clavícula %d %%: articulación %+.1f mm; trapecio %.1f°; cúpula %.1f mm" % [BODIES[row],
				roundi(100 * share), 1000.0 * (measured["joint"] - before["joint"]), measured["trapezius"], 1000.0 * measured["dome"]])
			if column == 1:
				check("%s: con clavícula, la articulación del brazo sube (el hombro acompaña)" % BODIES[row],
					measured["joint"] > before["joint"], "%+.1f mm" % (1000.0 * (measured["joint"] - before["joint"])))
				check("%s: con clavícula, el trapecio es menos empinado" % BODIES[row],
					measured["trapezius"] < before["trapezius"], "%.1f° -> %.1f°" % [before["trapezius"], measured["trapezius"]])
			await _shoot(BODIES[row], share, sheet, column, 2 * row)
	var out: String = options.get("salida", "pruebas/capturas/hombro_natural")
	out = out if out.is_absolute_path() else root_dir.path_join(out).simplify_path()
	DirAccess.make_dir_recursive_absolute(out)
	sheet.save_png(out.path_join("hombro_natural.png"))
	print("GUARDADO ", out.path_join("hombro_natural.png"))
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
	world.environment.background_color = Color(0.33, 0.34, 0.38)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.6, 0.65, 0.8)
	world.environment.ambient_light_energy = 0.25
	view.add_child(world)
	caption = Label.new()
	view.add_child(caption)


func _origin(bone: String) -> Vector3:
	return species.skeleton.get_bone_global_pose(species.skeleton.find_bone(bone)).origin


func _measure() -> Dictionary:
	var vertices: PackedVector3Array = mesh_baker.bake(species.mesh, species.skeleton)["vertices"]
	var joint := _origin("RightUpperArm")
	var w := absf(joint.x)
	var neck_x := -0.45 * w
	var over := _top(vertices, joint.x, joint)
	var slope := rad_to_deg(atan2(_top(vertices, neck_x, joint) - over, absf(joint.x - neck_x)))
	return {"joint": joint.y, "trapezius": slope, "dome": over - _top(vertices, joint.x - 0.6 * w, joint)}


## La piel más alta en la franja x ± 6 mm, cerca del plano del hombro.
func _top(vertices: PackedVector3Array, x: float, joint: Vector3) -> float:
	var top := -INF
	for v in vertices:
		if absf(v.x - x) < 0.006 and absf(v.z - joint.z) < 0.1 and v.y > joint.y - 0.1 and v.y < joint.y + 0.3:
			top = maxf(top, v.y)
	return top


func _shoot(body: String, share: float, sheet: Image, column: int, row: int) -> void:
	var joint := _origin("RightUpperArm")
	var center := Vector3(joint.x * 0.5, (joint.y + _origin("Neck").y) / 2, joint.z)
	var far := absf(joint.x) * 4.5
	for v in 2:
		var eye := Vector3(0, 0.1, 1.0) if v == 0 else Vector3(-0.7, 0.15, 0.7)
		camera.look_at_from_position(center + eye.normalized() * far, center)
		caption.text = "%s · clavícula %d %% · %s" % [body, roundi(100 * share), ["frente", "tres cuartos"][v]]
		for f in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, TILE), Vector2i(column, row + v) * TILE)
