extends SceneTree
# Paso AC.6c.2: cejas (banda `ceja` de ojos.json en EyeMesh, modo 3 de eye_line.gdshader). En el estado anime y en los 10
# extremos de Ojos: la banda queda pegada a la piel (su distancia a la primera cara visible, por la normal del ojo, es
# STRIP_LIFT ± MAX_SKIN_MM) y el borde de abajo de la ceja (valores de serie) queda a MIN_GAP_MM o más del arco de
# arriba del lazo. La ceja de serie cabe entera en la banda. Sin `ceja` en ojos.json no hay `ceja_*`.
# Con ventana, además dibuja la cara unos fotogramas (en Forward+ y en Mobile no debe salir ningún SHADER ERROR).
# Uso: (ulimit -v 4000000; timeout 600 godot [--headless | --rendering-method mobile] --path pruebas/godot -s probar_cejas.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: la banda sin formas (EyeMesh._strip_mesh sin `kept`: se separa con Ojos › Altura); brow_height
# fuera de la banda (la ceja ya no cabe); sin la entrada "ceja" en EyeMesh.STRIPS (no hay ceja_*).
# Diferencia con la ficha (§6): «a oscuras, canal máximo ≤ 0,01» no se mide con una captura; lo vigila
# probar_linea_ojo.gd (eye_line sin EMISSION y con el bloque común de toon_soft), que vale también para el modo 3.

const SLIDERS := ["eye_size", "eye_spacing", "eye_position", "eye_tall", "eye_corner"]
const STRIP_LIFT := 0.00012  # metros: la de cara_anime.py
const MAX_SKIN_MM := 0.05  # PROVISIONAL (ficha AC.6c §1): banda–piel
const MIN_GAP_MM := 2.0  # PROVISIONAL (ficha AC.6c §6): borde de abajo de la ceja–arco de arriba del lazo; medir antes
const RAY_FROM := 0.030  # metros: el rayo de altura empieza 30 mm por delante (como el de Blender para la banda)
const SKIN_RADIUS := 0.05  # metros: piel alrededor del ojo
const CELL := 0.001  # metros: rejilla de triángulos para los rayos
const MM := 1000.0  # Geometry3D.ray_intersects_triangle descarta triángulos de 1 mm: se trabaja en mm
const SAMPLES := 41  # puntos del borde de la ceja
const FRAMES := 20  # fotogramas dibujando la cara (con ventana)

var repo: String
var species
var updater
var mesh_baker
var eye_mesh
var values: Dictionary
var pieces: Array[MeshInstance3D] = []
var brow := {}  # uniforms brow_* de serie, leídos del shader
var failures := 0


func _initialize() -> void:
	repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	mesh_baker = load(repo.path_join("godot/addons/creador/mesh_baker.gd"))
	eye_mesh = load(repo.path_join("godot/addons/creador/eye_mesh.gd"))
	species = load(repo.path_join("godot/addons/creador/species_data.gd")).new()
	if species.load_folder(repo.path_join("godot/datos/humana")):
		_check(false, "la especie no carga: " + species.error)
		_finish()
		return
	root.add_child(species.scene)
	var preset = load(repo.path_join("godot/addons/creador/preset.gd")).from_text(species.preset_text(), species.manifest["species"], species.sliders)
	values = preset["valores"]
	updater = load(repo.path_join("godot/addons/creador/character_updater.gd")).new(species)
	load(repo.path_join("godot/addons/creador/body_material.gd")).apply(species.mesh)
	_read_brow_defaults()
	if not _check(species.eyes.has("l") and species.eyes["l"].has("ceja") and species.eyes["r"].has("ceja"),
			"ojos.json trae la banda `ceja` (si no: regenerar los datos con blender/exportar_datos.py)"):
		_finish()
		return
	_check_without_brow()
	pieces = eye_mesh.build(species.mesh, species.skeleton, species.eyes)
	for piece in pieces:
		updater.pieces.append(piece)
	var names := pieces.map(func(n: Node) -> String: return String(n.name))
	_check("ceja_l" in names and "ceja_r" in names and pieces.size() == 10, "dos capas, seis líneas y dos cejas (%d)" % pieces.size())
	_check(_ceja("l").material_override.get_shader_parameter("mode") == 3, "la ceja usa el modo 3")
	_check_fits()
	_run()


func _run() -> void:
	var skin := 0.0
	var skin_at := ""
	var gap := INF
	var gap_at := ""
	for state: Array in _states():
		updater.update(state[1], false)
		var baked := _bake()
		var s := _skin_error(baked)
		var g := _gap(baked)
		print("MEDIDA %s: banda–piel %.4f mm; ceja–lazo %.2f mm" % [state[0], s * 1000.0, g * 1000.0])
		if s > skin:
			skin = s
			skin_at = state[0]
		if g < gap:
			gap = g
			gap_at = state[0]
	_check(skin * 1000.0 <= MAX_SKIN_MM, "la banda queda pegada a la piel (%.4f mm en %s)" % [skin * 1000.0, skin_at])
	_check(gap * 1000.0 >= MIN_GAP_MM, "la ceja no toca la abertura del ojo (%.2f mm en %s)" % [gap * 1000.0, gap_at])
	updater.update(values, false)
	if DisplayServer.get_name() != "headless":
		await _draw()
	_finish()


func _finish() -> void:
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, text: String) -> bool:
	print(("  bien  " if ok else "  FALLO ") + text)
	if not ok:
		failures += 1
	return ok


## brow_* de eye_line.gdshader (con --headless Godot no da los valores por defecto del shader: se leen del texto).
func _read_brow_defaults() -> void:
	var code := FileAccess.get_file_as_string(repo.path_join("godot/addons/creador/eye_line.gdshader"))
	var found := RegEx.create_from_string("uniform float (brow_\\w+) = ([-0-9.]+);").search_all(code)
	for m in found:
		brow[m.get_string(1)] = float(m.get_string(2))
	_check(brow.size() == 11, "el shader tiene los 11 uniforms brow_* con número (%d)" % brow.size())


## Una especie sin `ceja` en ojos.json: EyeMesh no crea ninguna ceja (las otras 8 mallas, sí).
func _check_without_brow() -> void:
	var eyes: Dictionary = species.eyes.duplicate(true)
	for side: String in ["l", "r"]:
		eyes[side].erase("ceja")
	var built: Array = eye_mesh.build(species.mesh, species.skeleton, eyes)
	var cejas := built.filter(func(n: Node) -> bool: return String(n.name).begins_with("ceja_"))
	_check(cejas.is_empty() and built.size() == 8, "sin `ceja` en ojos.json no hay cejas (%d mallas)" % built.size())
	for node: Node in built:
		node.get_parent().remove_child(node)
		node.free()


## La ceja de serie (Altura 0, Grosor 1, Tamaño 1) cabe en la banda: en u, entre 0 y 1; en altura, entre 0 y su alto.
func _check_fits() -> void:
	var band: Dictionary = species.eyes["l"]["ceja"]
	var top: float = band["uv"][int(band["filas"]) - 1][1]
	var low := INF
	var high := -INF
	for i in SAMPLES:
		var t := float(i) / (SAMPLES - 1)
		var half_w := 0.5 * _width(t)
		low = minf(low, _center(t) - half_w)
		high = maxf(high, _center(t) + half_w)
	var start := _u(0.0)
	var end := _u(1.0)
	print("MEDIDA ceja de serie en la banda: u %.3f a %.3f; altura %.2f a %.2f mm (banda 0 a %.2f)" % [start, end,
		low * 1000.0, high * 1000.0, top * 1000.0])
	_check(start >= 0.0 and end <= 1.0 and low >= 0.0 and high <= top, "la ceja de serie cabe en la banda")


## [nombre, valores]: el estado anime y los 10 extremos de Ojos.
func _states() -> Array:
	var out := [["anime", values]]
	for key: String in SLIDERS:
		for value: float in [0.0, 1.0]:
			var state := values.duplicate()
			state[key] = value
			out.append(["%s_%d" % [key, value], state])
	return out


func _bake() -> Dictionary:
	var out := {"cuerpo": mesh_baker.bake(species.mesh, species.skeleton)}
	for side: String in ["l", "r"]:
		out["ceja_" + side] = mesh_baker.bake(_ceja(side), species.skeleton)
	return out


func _ceja(side: String) -> MeshInstance3D:
	return pieces.filter(func(n: Node) -> bool: return n.name == "ceja_" + side)[0]


## Mayor diferencia entre STRIP_LIFT y la distancia de un vértice de la banda al plano de la primera cara visible del
## cuerpo bajo él (rayo por la normal del ojo, como en Blender). INF si alguno no tiene piel debajo.
func _skin_error(baked: Dictionary) -> float:
	var worst := 0.0
	for side: String in ["l", "r"]:
		var normal := _eye_normal(side)
		var grid := _grid(baked, normal)
		for p: Vector3 in baked["ceja_" + side]["vertices"]:
			var hit := _first_hit(p + normal * RAY_FROM, -normal, grid)
			worst = maxf(worst, INF if hit.is_empty() else absf((p - hit[0]).dot(hit[1]) - STRIP_LIFT))
	return worst


## Menor distancia entre el borde de abajo de la ceja de serie (sobre la banda horneada) y el arco de arriba del lazo.
func _gap(baked: Dictionary) -> float:
	var best := INF
	for side: String in ["l", "r"]:
		var eye: Dictionary = species.eyes[side]
		var band: Dictionary = eye["ceja"]
		var body: PackedVector3Array = baked["cuerpo"]["vertices"]
		var arc := PackedVector3Array()
		for k: float in eye["arco_superior"]:
			arc.append(body[int(eye["lazo"][int(k)])])
		for i in SAMPLES:
			var t := float(i) / (SAMPLES - 1)
			var p := _on_band(baked["ceja_" + side]["vertices"], band, _u(t), _center(t) - 0.5 * _width(t))
			for k in arc.size() - 1:
				best = minf(best, p.distance_to(Geometry3D.get_closest_point_to_segment(p, arc[k], arc[k + 1])))
	return best


## Punto de la banda horneada en (u, altura en metros), por interpolación entre sus columnas y filas.
func _on_band(vertices: PackedVector3Array, band: Dictionary, u: float, height: float) -> Vector3:
	var rows := int(band["filas"])
	var columns := vertices.size() / rows
	var top: float = band["uv"][rows - 1][1]
	var x := clampf(u, 0.0, 1.0) * (columns - 1)
	var y := clampf(height / top, 0.0, 1.0) * (rows - 1)
	var c := mini(int(x), columns - 2)
	var r := mini(int(y), rows - 2)
	var fx := x - c
	var fy := y - r
	var a := vertices[c * rows + r].lerp(vertices[c * rows + r + 1], fy)
	var b := vertices[(c + 1) * rows + r].lerp(vertices[(c + 1) * rows + r + 1], fy)
	return a.lerp(b, fx)


## Copia en CPU del modo 3 de eye_line.gdshader (brow_t, brow_center, brow_w), con los valores de serie.
func _u(t: float) -> float:
	var half_len: float = 0.5 * (brow["brow_end"] - brow["brow_start"]) * brow["brow_size"]
	return 0.5 * (brow["brow_start"] + brow["brow_end"]) - half_len + t * 2.0 * half_len


func _center(t: float) -> float:
	return brow["brow_height"] + brow["brow_lift"] + brow["brow_arch"] * 4.0 * t * (1.0 - t) + brow["brow_tilt"] * (t - 0.5)


func _width(t: float) -> float:
	return brow["brow_width"] * brow["brow_thickness"] * lerpf(brow["brow_inner_w"], 1.0, smoothstep(0.0, 0.35, t)) \
		* lerpf(1.0, brow["brow_outer_w"], smoothstep(0.55, 1.0, t))


func _eye_normal(side: String) -> Vector3:
	var eye: Dictionary = species.eyes[side]
	return Vector3(eye["normal"][0], eye["normal"][1], eye["normal"][2])


## Triángulos del cuerpo de cara a la normal del ojo, cerca de los ojos, en una rejilla sobre el plano del ojo.
func _grid(baked: Dictionary, normal: Vector3) -> Dictionary:
	var center := Vector3.ZERO
	for side: String in ["l", "r"]:
		for v: float in species.eyes[side]["lazo"]:
			center += baked["cuerpo"]["vertices"][int(v)] / (2.0 * species.eyes[side]["lazo"].size())
	var across := Vector3.UP.cross(normal).normalized()
	var up := normal.cross(across)
	var vertices: PackedVector3Array = baked["cuerpo"]["vertices"]
	var indices: PackedInt32Array = species.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var cells := {}
	for t in range(0, indices.size(), 3):
		var a := vertices[indices[t]]
		if a.distance_to(center) > SKIN_RADIUS * 1.5:
			continue
		var b := vertices[indices[t + 1]]
		var c := vertices[indices[t + 2]]
		var face := (c - a).cross(b - a).normalized()  # delantera por el orden de los vértices (como probar_linea_ojo)
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for q: Vector3 in [a, b, c]:
			var flat := Vector2(q.dot(across), q.dot(up)) / CELL
			low = low.min(flat)
			high = high.max(flat)
		for x in range(floori(low.x), floori(high.x) + 1):
			for y in range(floori(low.y), floori(high.y) + 1):
				var key := Vector2i(x, y)
				if not cells.has(key):
					cells[key] = []
				cells[key].append([a, b, c, face])
	return {"cells": cells, "across": across, "up": up}


## [punto, normal de la cara] del primer triángulo de cara al rayo; [] si no toca ninguno.
func _first_hit(from: Vector3, direction: Vector3, grid: Dictionary) -> Array:
	var key := Vector2i(floori(from.dot(grid["across"]) / CELL), floori(from.dot(grid["up"]) / CELL))
	var best := INF
	var out := []
	for tri: Array in grid["cells"].get(key, []):
		if (tri[3] as Vector3).dot(direction) >= 0.0:
			continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(from * MM, direction, tri[0] * MM, tri[1] * MM, tri[2] * MM)
		if hit != null and (from * MM).distance_to(hit) < best:
			best = (from * MM).distance_to(hit)
			out = [(hit as Vector3) / MM, tri[3]]
	return out


## Con ventana: una cámara delante de la cara y unos fotogramas dibujando (los errores del shader salen en la salida).
func _draw() -> void:
	var eye: Dictionary = species.eyes["l"]
	var center := Vector3(eye["centro"][0], eye["centro"][1], eye["centro"][2]) * Vector3(0.0, 1.0, 1.0)
	var camera := Camera3D.new()
	species.scene.add_child(camera)
	camera.look_at_from_position(center + Vector3(0.0, 0.02, 0.4), center + Vector3(0.0, 0.02, 0.0))
	camera.fov = 15.0
	camera.current = true
	var light := DirectionalLight3D.new()
	species.scene.add_child(light)
	light.look_at_from_position(Vector3(0.0, 2.0, 2.0), Vector3.ZERO)
	for i in FRAMES:
		await process_frame
	print("MEDIDA dibujada la cara %d fotogramas con %s" % [FRAMES, RenderingServer.get_current_rendering_method()])
