extends SceneTree
# Paso 9.8b (D58): el interior de la boca, oscuro. En los datos, el verde del color por vértice es 0 en la bolsa de la boca
# y 1 en el resto (y nunca 0 en la prenda); los dos shaders del cuerpo tienen mouth_color con el valor de BodyMaterial;
# en el .glb, el RGB del color por vértice es MOUTH_DARK en la boca y 1 en el resto, con la prenda en el alfa. Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_boca_oscura.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Rotura: en glb_exporter.gd, el RGB blanco en todas partes (como antes) -> falla «el .glb lleva la boca oscura».
# Lo que se ve: las filas «aa … oh» de capturar_expresiones.gd (boca abierta).

const TOLERANCE := 0.01  # el color se guarda en 8 o 16 bits

var failures := 0


func _initialize() -> void:
	var repo := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := repo.path_join("godot/addons/creador")
	var species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(repo.path_join("godot/datos/humana")):
		_check(false, "la especie no carga: " + species.error)
		_finish()
		return
	root.add_child(species.scene)
	var material: GDScript = load(addon.path_join("body_material.gd"))
	var exporter: GDScript = load(addon.path_join("glb_exporter.gd"))
	material.apply(species.mesh)
	var colors: PackedColorArray = species.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var mouth := PackedInt32Array()
	var clean := true
	for i in colors.size():
		clean = clean and (colors[i].g == 0.0 or colors[i].g == 1.0)
		if colors[i].g == 0.0:
			mouth.append(i)
			clean = clean and colors[i].r < 0.5
	print("MEDIDA vértices del interior de la boca: %d" % mouth.size())
	_check(not mouth.is_empty() and clean, "datos: verde 0 en la boca (nunca en la prenda) y 1 en el resto (si no: regenerar los datos)")
	for shader: String in ["toon.gdshader", "toon_soft.gdshader"]:
		var code := FileAccess.get_file_as_string(addon.path_join(shader))
		_check(code.contains("uniform vec3 mouth_color : source_color = vec3(0.03, 0.02, 0.02);")
			and code.contains("mouth_color, (1.0 - COLOR.g)"), "%s: mouth_color y el verde del color" % shader)
	_check(material.DEFAULTS["mouth_color"] == Color(0.03, 0.02, 0.02) and material.SOFT_DEFAULTS["mouth_color"] == Color(0.03, 0.02, 0.02),
		"BodyMaterial: mouth_color de serie, igual que en los shaders")
	var folder := OS.get_user_data_dir().path_join("probar_boca_oscura")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("boca.glb")
	_check(exporter.save(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], path, true) == OK, "exportar")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if not _check(document.append_from_file(path, state) == OK, "el .glb se lee"):
		_finish()
		return
	var scene := document.generate_scene(state)
	var body := scene.find_children("*", "MeshInstance3D", true, false).filter(func(m: Node) -> bool: return m.name == species.mesh.name)[0] as MeshInstance3D
	var exported: PackedColorArray = body.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var worst := 0.0
	for i in exported.size():
		var want: float = exporter.MOUTH_DARK if colors[i].g == 0.0 else 1.0
		var c := exported[i]
		worst = maxf(worst, maxf(absf(c.r - want), maxf(absf(c.g - want), absf(c.b - want))))
	print("MEDIDA color por vértice del .glb contra lo esperado: máx. %.4f" % worst)
	_check(exported.size() == colors.size() and worst <= TOLERANCE, "el .glb lleva la boca oscura (RGB %.2f) y el resto blanco" % exporter.MOUTH_DARK)
	scene.free()
	_finish()


func _finish() -> void:
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, text: String) -> bool:
	print(("  bien  " if ok else "  FALLO ") + text)
	if not ok:
		failures += 1
	return ok
