extends SceneTree
# Paso 3.16: normales del estilo en el núcleo (style_normals.gd) y en el .glb exportado (glb_exporter.gd). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_normales_estilo.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Con el preset de personaje nuevo (presets/anime.json): la malla exportada lleva StyleNormals.apply() de la horneada
# (CharacterBaker + Sockets, lo mismo que recibe GlbExporter), comparadas ya guardadas en una malla de Godot.
# Que el porte desde las maquetas es exacto lo prueban sus capturas (probar_estilo y probar_normales_cara con --salida,
# idénticas píxel a píxel); que llegan al leer el .glb, probar_exportar y las tres pruebas de normales del 3.13a-2.

const SAME_DEG := 0.001
const MIN_CHANGE_DEG := 1.0  # media del cambio en la cabeza y en el resto: si no, no se han aplicado

var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	var species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	var loaded: Dictionary = load(addon.path_join("preset.gd")).from_text(species.preset_text(), "humana", species.sliders)
	load(addon.path_join("character_updater.gd")).new(species).update(loaded["valores"], false)
	var style: GDScript = load(addon.path_join("style_normals.gd"))
	check("valores elegidos: suavizado 10 y aplanado 0,6", style.SMOOTH_STEPS == 10 and style.FACE_DEPTH == 0.6)

	var exported: Node3D = load(addon.path_join("glb_exporter.gd")).build(
		species.mesh, species.skeleton, species.manifest["bones"]["sockets"], true)
	var bake: Node3D = load(addon.path_join("character_baker.gd")).bake(species.mesh, species.skeleton, true)
	var baked: Node3D = load(addon.path_join("sockets.gd")).to_nodes(bake, species.manifest["bones"]["sockets"])  # como GlbExporter
	bake.free()
	var out_mesh := exported.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var raw_mesh := baked.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arrays: Array = raw_mesh.mesh.surface_get_arrays(0)
	var raw: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var head: PackedFloat32Array = style.head_weights(arrays, raw_mesh.skin, raw_mesh.get_parent())
	var expected: PackedVector3Array = _stored(arrays, style.apply(arrays[Mesh.ARRAY_VERTEX], raw, arrays[Mesh.ARRAY_INDEX], head))
	var got: PackedVector3Array = out_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	check("mismos vértices en la malla exportada y en la horneada", got.size() == expected.size(), "%d / %d" % [got.size(), expected.size()])
	if got.size() == expected.size():
		_compare(got, expected, raw, head)
	exported.free()
	baked.free()
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## Las normales tal como quedan guardadas en una malla de Godot (las comprime): así se compara lo mismo con lo mismo.
func _stored(arrays: Array, normals: PackedVector3Array) -> PackedVector3Array:
	var copy := arrays.duplicate()
	copy[Mesh.ARRAY_NORMAL] = normals
	copy[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, copy)
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]


func _compare(got: PackedVector3Array, expected: PackedVector3Array, raw: PackedVector3Array, head: PackedFloat32Array) -> void:
	var worst := 0.0
	var unit := true
	var change := {"cabeza": [0.0, 0], "resto": [0.0, 0]}
	for i in got.size():
		worst = maxf(worst, rad_to_deg(got[i].angle_to(expected[i])))
		unit = unit and absf(got[i].length() - 1.0) < 0.001
		var part := "cabeza" if head[i] > 0.5 else "resto"
		change[part][0] += rad_to_deg(got[i].angle_to(raw[i]))
		change[part][1] += 1
	check("exportadas = StyleNormals.apply de la malla horneada (< %s°)" % SAME_DEG, worst < SAME_DEG, "máx. %.6f°" % worst)
	check("normales de largo 1", unit)
	for part: String in change:
		var mean: float = change[part][0] / change[part][1]
		check("cambian respecto a las horneadas en %s (media > %s°)" % [part, MIN_CHANGE_DEG], mean > MIN_CHANGE_DEG,
			"media %.1f° en %d vértices" % [mean, change[part][1]])
