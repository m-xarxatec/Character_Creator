extends SceneTree
# Paso 3.8: 10 cuerpos al azar (preset JSON) → exportar en pose T y en pose A → reimportar → comparar con el personaje en memoria.
# Sin ventana. Uso: (ulimit -v 4000000; timeout 600 godot --headless --path pruebas/godot -s probar_aleatorios.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR|medida')
# Escribe pruebas/fase_3/salida/aleatorios/: cuerpo_NN.json (el preset) y t/ y a/ con cuerpo_NN.glb. Después, en Blender:
#   blender -b -P pruebas/fase_3/probar_glb_en_blender.py -- <ruta a un .glb>...
# El cuerpo se construye desde el preset ya releído del archivo (así se usa también preset.gd). Por medida: máximo y
# media de todos los elementos de los 10 cuerpos, por variante. «medida» = sin límite aprobado: no falla (hoy no queda ninguna salvo el giro de los huesos).

const Compare := preload("comparar_glb.gd")

const COUNT := 10
const SEED := 38
const SAME_MM := 0.1  # los de probar_exportar.gd (paso 3.6.5)
const SOCKET_DEG := 1.0
const FLOOR_MM := 0.001  # el de probar_personaje_horneado.gd (paso 3.6.3)
const SUM_EPS := 1e-4
const INFLUENCE_EPS := 1e-4  # aprobado el 2026-11-12 (medida 0,000031: cuantización de 16 bits de Godot)
const NORMAL_DEG := 0.1  # aprobado el 2026-11-12, como el horneado del 3.6.1 (medida 0,0074°)
const MIN_SPREAD_M := 0.1  # no es un límite del código: comprueba que la prueba no compara diez veces el mismo cuerpo
const VARIANTS := ["t", "a"]

var failures := 0
var species
var updater
var exporter: GDScript
var shapes: GDScript
var proportions: GDScript
var preset: GDScript
var material: GDScript
var socket_names: Array
var out: String
var errors := {}  # {variante: {medida: [errores de todos los cuerpos]}}


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	out = root_dir.path_join("pruebas/fase_3/salida/aleatorios")
	exporter = load(addon.path_join("glb_exporter.gd"))
	shapes = load(addon.path_join("shape_weights.gd"))
	proportions = load(addon.path_join("proportions.gd"))
	preset = load(addon.path_join("preset.gd"))
	material = load(addon.path_join("body_material.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	material.apply(species.mesh)
	updater = load(addon.path_join("character_updater.gd")).new(species)
	socket_names = species.manifest["bones"]["sockets"]
	for variant: String in VARIANTS:
		DirAccess.make_dir_recursive_absolute(out.path_join(variant))
		errors[variant] = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for index in COUNT:
		_body(index, rng)
	_report()
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _add(variant: String, measure: String, values: Array) -> void:
	errors[variant][measure] = errors[variant].get(measure, []) + values


## Un cuerpo al azar: valores de todos los deslizadores (sin simetría), colores y prenda; se guarda como preset.
func _body(index: int, rng: RandomNumberGenerator) -> void:
	var values: Dictionary = shapes.neutral_values(species.sliders)
	values.merge(proportions.neutral_values(species.sliders))
	for key: String in values:
		values[key] = rng.randf()
	var colors := {"skin_color": Color(rng.randf(), rng.randf(), rng.randf()), "garment_color": Color(rng.randf(), rng.randf(), rng.randf())}
	var file := out.path_join("cuerpo_%02d.json" % index)
	var writer := FileAccess.open(file, FileAccess.WRITE)
	if writer == null:
		check("cuerpo %02d: se escribe el preset" % index, false, error_string(FileAccess.get_open_error()))
		return
	writer.store_string(preset.to_text(preset.to_dict("Azar %02d" % index, "humana", values, colors, index % 4 != 3)))
	writer.close()
	var loaded: Dictionary = preset.from_text(FileAccess.get_file_as_string(file), "humana", species.sliders)
	check("cuerpo %02d: el preset escrito se vuelve a cargar sin errores ni claves desconocidas" % index,
		loaded["error"] == "" and loaded["desconocidas"].is_empty(), loaded["error"])
	if loaded["error"] != "":
		return
	_set_up(loaded)
	for variant: String in VARIANTS:
		_export_and_compare(index, variant, loaded)


func _set_up(loaded: Dictionary) -> void:
	var rejected: Array[String] = updater.update(loaded["valores"], false)
	if not rejected.is_empty():
		check("update_character aplica todas las claves del preset", false, str(rejected))
	preset.apply_look(species.mesh, loaded)


func _export_and_compare(index: int, variant: String, loaded: Dictionary) -> void:
	var t_pose := variant == "t"
	var label := "cuerpo %02d, pose %s: " % [index, variant.to_upper()]
	var path := out.path_join(variant).path_join("cuerpo_%02d.glb" % index)
	var memory: Node3D = exporter.build(species.mesh, species.skeleton, socket_names, t_pose)
	var memory_skeleton: Skeleton3D = memory.get_child(0)
	var memory_mesh := memory_skeleton.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var error: Error = exporter.save(species.mesh, species.skeleton, socket_names, path, t_pose)
	check(label + "se exporta sin errores", error == OK and FileAccess.file_exists(path), error_string(error))
	var first := FileAccess.get_sha256(path)
	exporter.save(species.mesh, species.skeleton, socket_names, path, t_pose)
	check(label + "exportar dos veces da el mismo archivo", FileAccess.get_sha256(path) == first)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	error = document.append_from_file(path, state)
	check(label + "se vuelve a leer sin errores", error == OK, error_string(error))
	if error == OK:
		var scene := document.generate_scene(state)
		var skeletons := scene.find_children("*", "Skeleton3D", true, false)
		var meshes := scene.find_children("*", "MeshInstance3D", true, false)
		check(label + "un esqueleto y una malla", skeletons.size() == 1 and meshes.size() == 1)
		if skeletons.size() == 1 and meshes.size() == 1:
			_measure(index, label, variant, skeletons[0], meshes[0], memory_skeleton, memory_mesh)
			_check_garment(label, meshes[0])
		scene.free()
	memory.free()


func _measure(index: int, label: String, variant: String, skeleton: Skeleton3D, mesh: MeshInstance3D, memory_skeleton: Skeleton3D,
		memory_mesh: MeshInstance3D) -> void:
	var bones: Dictionary = Compare.bone_errors(skeleton, memory_skeleton)
	_add(variant, "huesos_mm", bones["mm"])
	_add(variant, "huesos_deg", bones["deg"])
	check(label + "53 huesos, todos con escala 1", bones["count"] == 53 and bones["unit"])
	var sockets: Dictionary = Compare.socket_errors(skeleton, memory_skeleton, socket_names)
	_add(variant, "anclajes_mm", sockets["mm"])
	_add(variant, "anclajes_deg", sockets["deg"])
	check(label + "4 anclajes", sockets["found"] == 4 and sockets["memory_found"] == 4)

	var memory_vertices: PackedVector3Array = memory_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var order: Array = Compare.order_errors(mesh, memory_vertices)
	check(label + "mismos vértices, en el mismo orden (< %s mm)" % SAME_MM, not order.is_empty() and Compare.stats(order).x < SAME_MM)
	if order.is_empty():
		return
	_add(variant, "malla_mm", order)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var transform := Compare.to_scene(mesh)
	var lowest := INF
	var highest := -INF
	for vertex in vertices:
		lowest = minf(lowest, (transform * vertex).y)
		highest = maxf(highest, (transform * vertex).y)
	_add(variant, "suelo_mm", [absf(lowest) * 1000.0])
	_add(variant, "altura_m", [highest])
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var sums := []
	for i in vertices.size():
		sums.append(absf(weights[4 * i] + weights[4 * i + 1] + weights[4 * i + 2] + weights[4 * i + 3] - 1.0))
	_add(variant, "suma_pesos", sums)
	var eight: bool = ((mesh.mesh as ArrayMesh).surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
	check(label + "0 formas, 4 influencias por vértice, color por vértice y una superficie",
		mesh.mesh.get_blend_shape_count() == 0 and not eight and weights.size() == 4 * vertices.size()
		and arrays[Mesh.ARRAY_COLOR] != null and mesh.mesh.get_surface_count() == 1)
	var influences: Array = Compare.influence_errors(mesh, skeleton, memory_mesh, memory_skeleton)
	var normals: Array = Compare.normal_errors(mesh, memory_mesh)
	_add(variant, "pesos_huesos", influences)
	_add(variant, "normales_deg", normals)
	print("  cuerpo %02d, pose %s: huesos %.5f mm, anclajes %.5f mm, malla %.5f mm, pesos %.6f, normales %.4f°" % [index,
		variant.to_upper(), Compare.stats(bones["mm"]).x, Compare.stats(sockets["mm"]).x, Compare.stats(order).x,
		Compare.stats(influences).x, Compare.stats(normals).x])


## La prenda: con la prenda visible el material lleva la textura de 2048 px; oculta, no lleva textura.
func _check_garment(label: String, mesh: MeshInstance3D) -> void:
	var shown: bool = material.is_garment_visible(species.mesh)
	var standard := mesh.get_active_material(0) as StandardMaterial3D
	var texture := standard.albedo_texture if standard else null
	check(label + ("prenda visible: textura de 2048 px" if shown else "prenda oculta: sin textura"),
		standard != null and (texture != null and texture.get_size() == Vector2(2048, 2048) if shown else texture == null))


func _report() -> void:
	for variant: String in VARIANTS:
		print("Pose %s, %d cuerpos (máximo y media de todos los elementos):" % [variant.to_upper(), COUNT])
		var heights: Array = errors[variant].get("altura_m", [0.0])
		check("los cuerpos son distintos entre sí (alturas de %.2f a %.2f m, diferencia > %s m)" % [heights.min(), heights.max(), MIN_SPREAD_M],
			heights.max() - heights.min() > MIN_SPREAD_M)
		_limit(variant, "huesos_mm", "53 huesos, posición", "mm", SAME_MM)
		_measure_only(variant, "huesos_deg", "53 huesos, giro", "°")
		_limit(variant, "anclajes_mm", "anclajes, posición", "mm", SAME_MM)
		_limit(variant, "anclajes_deg", "anclajes, giro", "°", SOCKET_DEG)
		_limit(variant, "malla_mm", "vértices de la malla", "mm", SAME_MM)
		_limit(variant, "suelo_mm", "punto más bajo", "mm", FLOOR_MM)
		_limit(variant, "suma_pesos", "suma de pesos (distancia a 1)", "", SUM_EPS)
		_limit(variant, "pesos_huesos", "huesos y pesos, vértice a vértice (mayor diferencia de peso)", "", INFLUENCE_EPS)
		_limit(variant, "normales_deg", "normales", "°", NORMAL_DEG)


func _limit(variant: String, measure_name: String, label: String, unit: String, limit: float) -> void:
	var s: Vector2 = Compare.stats(errors[variant].get(measure_name, [INF]))
	check("%s (< %s %s)" % [label, limit, unit], s.x < limit, "máximo %.6f %s, media %.6f %s" % [s.x, unit, s.y, unit])


func _measure_only(variant: String, measure_name: String, label: String, unit: String) -> void:
	var s: Vector2 = Compare.stats(errors[variant].get(measure_name, [INF]))
	print("  medida  %s: máximo %.6f %s, media %.6f %s" % [label, s.x, unit, s.y, unit])
