extends SceneTree
# Pasos AB.4–AB.13 y 9.4: piezas (y ojos) sobre el personaje del editor (godot/app/body_view.gd con BodyPiece, BodyDerived y
# RigidPiece): poner y quitar, una por ranura, seguir al cuerpo, exportarlas en el .glb y guardarlas en el .gmolde.
# Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_piezas.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en BodyPiece.follow, quitar ShapeWeights.apply -> falla «las mallas siguen a weight».

var failures := 0


func _initialize() -> void:
	var main: Control = load(ProjectSettings.globalize_path("res://").path_join("../../godot/app/main.gd").simplify_path()).new()
	root.add_child(main)
	await process_frame
	var view = main.body_view
	_check_wear(main, view)
	_check_export(view)
	_check_project(main, view)
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_wear(main: Control, view) -> void:
	for id in ["tights", "skirt", "casquete", "guantes", "botas", "cuernos", "ojos_anime"]:
		check("poner %s" % id, view.set_piece("base", id, true))
	check("calcetines quitan las botas (misma ranura)", view.set_piece("base", "calcetines", true)
		and view.is_on("base/calcetines") and not view.is_on("base/botas"))
	check("el casquete quita el volumen de melena y al revés", view.set_piece("base", "hair", true)
		and not view.is_on("base/casquete") and view.set_piece("base", "casquete", true) and not view.is_on("base/hair"))
	var tights: MeshInstance3D = view.pieces["base/tights"]
	check("las mallas cuelgan del esqueleto del cuerpo", tights.get_parent() == view.species.skeleton)
	var values: Dictionary = main.editor.values.duplicate()
	values["weight"] = 1.0
	main.editor.load_values(values)
	var shape := tights.find_blend_shape_by_name("weight_incr")
	check("las mallas siguen a weight (forma weight_incr a 1)", shape >= 0 and tights.get_blend_shape_value(shape) == 1.0)
	var cap: MeshInstance3D = view.pieces["base/casquete"]
	print("  MEDIDA casquete: %d triángulos, %d formas" % [cap.mesh.get_faces().size() / 3, cap.mesh.get_blend_shape_count()])
	check("el casquete tiene caras y formas", cap.mesh.get_faces().size() > 0 and cap.mesh.get_blend_shape_count() > 0)
	check("los cuernos son dos mallas en un BoneAttachment3D de Head", view.meshes_of("base/cuernos").size() == 2
		and view.accessories["base/cuernos"].bone_name == "Head")
	var eyes: MeshInstance3D = view.pieces["base/ojos_anime"]
	print("  MEDIDA ojos: %d triángulos, %d formas" % [eyes.mesh.get_faces().size() / 3, eyes.mesh.get_blend_shape_count()])
	view.set_piece_color("base/ojos_anime", Color(0.1, 0.6, 0.3))
	check("ojos: con su dibujo y el iris que se elige (paso 9.4)", eyes.has_meta("textura")
		and view.piece_color("base/ojos_anime").is_equal_approx(Color(0.1, 0.6, 0.3)))
	check("is_on y meshes_of de algo no puesto", not view.is_on("base/skirt_no") and view.meshes_of("base/no").is_empty())
	check("quitar la falda", view.set_piece("base", "skirt", false) and not view.is_on("base/skirt"))


func _check_export(view) -> void:
	var path := OS.get_user_data_dir().path_join("piezas_prueba.glb")
	check("exportar con piezas", view.export_glb(path) == OK)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		check("el .glb se vuelve a leer", false)
		return
	var scene := document.generate_scene(state)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var names: Array = meshes.map(func(m: MeshInstance3D) -> String: return m.name)
	# cuerpo + mallas + casquete + guantes + calcetines + 2 cuernos + ojos
	check("el .glb trae el cuerpo primero y 7 mallas de piezas, todas con piel", meshes.size() == 8 and names[0] == "Body"
		and meshes.all(func(m: MeshInstance3D) -> bool: return m.skin != null), str(names))
	var eye_meshes := meshes.filter(func(m: MeshInstance3D) -> bool: return m.name == "Ojos")
	check("los ojos viajan con su dibujo como textura", eye_meshes.size() == 1
		and (eye_meshes[0].mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture != null)
	var lowest := INF
	for m: MeshInstance3D in meshes:
		lowest = minf(lowest, m.get_aabb().position.y)
	check("nada por debajo del suelo más de 1 cm", lowest > -0.01, "%.4f" % lowest)  # PROVISIONAL
	scene.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path.get_basename() + ".tres")


func _check_project(main: Control, view) -> void:
	var path := OS.get_user_data_dir().path_join("piezas_prueba.gmolde")
	var worn: Array = view.pieces.keys() + view.accessories.keys()
	worn.sort()
	check("guardar el proyecto", main.body_actions.save_preset(path) == OK)
	view.set_piece("base", "tights", false)
	view.set_piece("base", "cuernos", false)
	check("abrirlo sin error", main.body_actions.open_preset(path) == "")
	var back: Array = view.pieces.keys() + view.accessories.keys()
	back.sort()
	check("vuelven las mismas piezas", back == worn, str(back))
	check("la pestaña Ropa marca las mallas", main.piece_panels["Ropa"].buttons["base/tights"].button_pressed)
	DirAccess.remove_absolute(path)
