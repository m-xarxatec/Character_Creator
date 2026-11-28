extends SceneTree
# Paso AC.4: iris y pupila. Va en la segunda pasada de cada ojo; con cobertura 20-40 % no cambian el borde inferior ni la
# línea; color y tamaño cambian solo sus uniforms y solo píxeles del ojo.
# Paso AC.5: brillos del mismo lado en los dos ojos, radio ≤ 12 % del semieje del iris, y a oscuras no brillan.
# Con ventana (dibuja). Uso: (ulimit -v 4000000; timeout 300 godot [--rendering-method mobile] --path pruebas/godot -s probar_iris.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: `y_line` dependiente de la cobertura en EyeMesh.iris_values; quitar el next_pass;
# reflejar la uv.x en un ojo (EyeMesh._eye_mesh).

const COVERS := [0.20, 0.30, 0.40]
const MAX_DRIFT_MM := 0.0001  # PROVISIONAL: borde inferior y línea al cambiar la cobertura
const MAX_COVER_ERROR := 0.0001  # PROVISIONAL
const MIN_IRIS_PX := 200  # PROVISIONAL: píxeles del iris en la captura de prueba
const TOLERANCE := 2.0 / 255.0
const MAX_SHINE_RADIUS := 0.12  # ficha AC.3b §6: radio del brillo / semieje del iris
const MAX_DARK := 0.01  # canal máximo a oscuras (como probar_base_ojo.gd)
const SHINE_TEST := Color(0.0, 1.0, 0.0)  # color de los brillos para encontrarlos en la captura
const SHINE_FOV := 4.0  # cámara más cerrada para medir el radio: el iris ocupa unos 140 px

var eye_mesh
var failures := 0


func _initialize() -> void:
	var repo := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	eye_mesh = load(repo.path_join("godot/addons/creador/eye_mesh.gd"))
	var species = load(repo.path_join("godot/addons/creador/species_data.gd")).new()
	var error: String = species.load_folder(repo.path_join("godot/datos/humana"))
	_check(error == "", "la especie carga " + error)
	if error == "":
		root.add_child(species.scene)
		var preset = load(repo.path_join("godot/addons/creador/preset.gd")).from_text(species.preset_text(), species.manifest["species"], species.sliders)
		var updater = load(repo.path_join("godot/addons/creador/character_updater.gd")).new(species)
		load(repo.path_join("godot/addons/creador/body_material.gd")).apply(species.mesh)
		var eyes: Array[MeshInstance3D] = eye_mesh.build(species.mesh, species.skeleton, species.eyes)
		eyes = eyes.filter(func(n: MeshInstance3D) -> bool: return n.name.begins_with("ojo_"))  # AC.6a: las líneas, aparte
		for eye in eyes:
			updater.pieces.append(eye)
		updater.update(preset["valores"], false)
		_check_passes(eyes)
		_check_cover(species.eyes)
		if eyes.size() == 2 and eyes[0].material_override.next_pass != null:
			await _check_uniforms(species, eyes)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, text: String) -> void:
	print(("  bien  " if ok else "  FALLO ") + text)
	if not ok:
		failures += 1


func _check_passes(eyes: Array[MeshInstance3D]) -> void:
	_check(eyes.size() == 2, "una malla por ojo (%d)" % eyes.size())
	for eye in eyes:
		var white: ShaderMaterial = eye.material_override
		var iris: ShaderMaterial = white.next_pass
		_check(iris != null and iris.render_priority > white.render_priority, "%s: iris en la segunda pasada, detrás del blanco" % eye.name)
		_check(iris != null and iris.shader.code.contains("#define EYE_IRIS") and not white.shader.code.contains("#define EYE_IRIS"), "%s: solo el iris es transparente" % eye.name)


func _check_cover(data: Dictionary) -> void:
	for side: String in ["l", "r"]:
		var first: Dictionary = eye_mesh.iris_values(data[side], COVERS[0])
		var drift := 0.0
		for c: float in COVERS:
			var v: Dictionary = eye_mesh.iris_values(data[side], c)
			var bottom: float = v["iris_center"].y - v["iris_axes"].y
			var top: float = v["iris_center"].y + v["iris_axes"].y
			drift = maxf(drift, absf(bottom - first["y_bottom"]))
			drift = maxf(drift, absf(v["y_bottom"] - first["y_bottom"]))
			drift = maxf(drift, absf(v["y_line"] - first["y_line"]))
			var covered: float = (top - v["y_line"]) / (top - bottom)
			_check(absf(covered - c) <= MAX_COVER_ERROR, "%s: cobertura %.2f (medida %.4f)" % [side, c, covered])
		print("MEDIDA %s: borde inferior y línea al cambiar la cobertura: %.5f mm" % [side, drift * 1000.0])
		_check(drift * 1000.0 <= MAX_DRIFT_MM, "%s: el borde inferior y la línea no dependen de la cobertura" % side)


func _check_uniforms(species, eyes: Array[MeshInstance3D]) -> void:
	species.mesh.visible = false
	for node in species.skeleton.get_children():  # AC.6a: solo las capas del ojo (las líneas tapan el borde del iris)
		if node is MeshInstance3D and not String(node.name).begins_with("ojo_"):
			node.visible = false
	var view := SubViewport.new()
	view.size = Vector2i(320, 240)
	view.transparent_bg = true
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	species.scene.reparent(view, false)
	var c: Array = species.eyes["l"]["centro"]
	var camera := Camera3D.new()
	camera.fov = 12.0
	view.add_child(camera)
	camera.position = Vector3(c[0], c[1], c[2] + 0.3)
	view.add_child(DirectionalLight3D.new())
	var iris: ShaderMaterial = eyes[0].material_override.next_pass
	var red := await _shot(view)
	eyes[0].material_override.next_pass = null
	var white := await _shot(view)
	eyes[0].material_override.next_pass = iris
	var inside := _diff_mask(red, white)
	var area := _count(inside)
	print("MEDIDA píxeles del iris: %d" % area)
	_check(area >= MIN_IRIS_PX, "el iris se dibuja sobre el blanco")
	iris.set_shader_parameter("iris_color", Color(0.12, 0.30, 0.62))
	var blue := await _shot(view)
	iris.set_shader_parameter("iris_color", Color(0.55, 0.08, 0.10))
	var by_color := _diff_mask(blue, red)
	_check(_count(by_color) > area / 2, "el color cambia el iris (%d px)" % _count(by_color))
	_check(_outside(by_color, inside) == 0, "el color no cambia nada fuera del iris (%d px)" % _outside(by_color, inside))
	iris.set_shader_parameter("iris_size", 1.15)
	var bigger := await _shot(view)
	iris.set_shader_parameter("iris_size", 1.0)
	var by_size := _diff_mask(bigger, red)
	_check(_outside(by_size, inside) > 0, "el tamaño agranda el iris (%d px nuevos)" % _outside(by_size, inside))
	_check(_outside(_diff_mask(bigger, white), _opening(white)) == 0, "el iris no se sale de la abertura")
	await _check_shine(species, eyes, view, camera)


## AC.5: en cada ojo, los brillos (los píxeles que cambian al teñirlos) frente al centro y el ancho del iris.
func _check_shine(species, eyes: Array[MeshInstance3D], view: SubViewport, camera: Camera3D) -> void:
	var sides: Array[float] = []
	var fov := camera.fov
	camera.fov = SHINE_FOV
	for k in eyes.size():
		var c: Array = species.eyes[["l", "r"][k]]["centro"]
		camera.position = Vector3(c[0], c[1], c[2] + 0.3)
		var iris: ShaderMaterial = eyes[k].material_override.next_pass
		var normal := await _shot(view)
		eyes[k].material_override.next_pass = null
		var white := await _shot(view)
		eyes[k].material_override.next_pass = iris
		iris.set_shader_parameter("shine_color", SHINE_TEST)
		var tinted := await _shot(view)
		iris.set_shader_parameter("shine_color", Color(0.98, 0.99, 1.0))
		var inside := _diff_mask(normal, white)
		var shine := _diff_mask(tinted, normal)
		var box := _span(inside, view.size.x)
		var center := (box.x + box.y) / 2.0
		var width := box.y - box.x + 1.0
		var side := signf(_mean_x(shine, view.size.x) - center)
		sides.append(side)
		var radius := _disc_radius(normal, tinted, shine, center, side) / (width / 2.0)
		print("MEDIDA ojo %s: brillo en el lado %+d; radio / semieje = %.3f (iris de %d px)" % [["l", "r"][k], side, radius, width])
		_check(_count(shine) > 0, "ojo %s: tiene brillos" % ["l", "r"][k])
		_check(radius <= MAX_SHINE_RADIUS, "ojo %s: radio del brillo ≤ 12 %% del semieje del iris" % ["l", "r"][k])
		_check(_outside(shine, inside) == 0, "ojo %s: los brillos no se salen del iris" % ["l", "r"][k])
	camera.fov = fov
	_check(sides.size() == 2 and sides[0] == sides[1] and sides[0] != 0.0, "los brillos caen del mismo lado en los dos ojos")
	await _check_dark(species, eyes, view, camera)


## A oscuras (sin luces) los brillos no se ven: el ojo no tiene emisión propia.
func _check_dark(species, eyes: Array[MeshInstance3D], view: SubViewport, camera: Camera3D) -> void:
	var c: Array = species.eyes["l"]["centro"]
	camera.position = Vector3(c[0], c[1], c[2] + 0.3)
	var iris: ShaderMaterial = eyes[0].material_override.next_pass
	var normal := await _shot(view)
	iris.set_shader_parameter("shine_color", SHINE_TEST)
	var shine := _diff_mask(await _shot(view), normal)
	iris.set_shader_parameter("shine_color", Color(0.98, 0.99, 1.0))
	var lamps := view.find_children("*", "DirectionalLight3D", false, false)
	for lamp: Node in lamps:
		lamp.visible = false
	var dark := await _shot(view)
	for lamp: Node in lamps:
		lamp.visible = true
	var top := 0.0
	for k in shine.size():
		if shine[k] == 1:
			var p := dark.get_pixel(k % view.size.x, k / view.size.x)
			top = maxf(top, maxf(p.r, maxf(p.g, p.b)))
	print("MEDIDA a oscuras: canal máximo de los brillos %.4f" % top)
	_check(_count(shine) > 0 and top <= MAX_DARK, "a oscuras los brillos no brillan")


## Radio en píxeles del brillo grande (el del lado `side` de `from`), por su área: cada píxel cuenta lo que lo cubre el
## brillo (caída del rojo al teñirlo de verde, sobre la del centro del brillo), así el borde suavizado no suma un píxel.
func _disc_radius(normal: Image, tinted: Image, shine: PackedByteArray, from: float, side: float) -> float:
	var width := normal.get_width()
	var drops := PackedFloat32Array()
	drops.resize(shine.size())
	var peak := 0.0
	for k in shine.size():
		if shine[k] == 1 and (float(k % width) - from) * side > 0.0:
			drops[k] = normal.get_pixel(k % width, k / width).r - tinted.get_pixel(k % width, k / width).r
			peak = maxf(peak, drops[k])
	var area := 0.0
	for drop: float in drops:
		area += clampf(drop / maxf(peak, 0.0001), 0.0, 1.0)
	return sqrt(area / PI)


## Columnas mínima y máxima (x, y) de la máscara.
func _span(mask: PackedByteArray, width: int) -> Vector2:
	var low := INF
	var high := -INF
	for k in mask.size():
		if mask[k] == 1:
			low = minf(low, k % width)
			high = maxf(high, k % width)
	return Vector2(low, high)


func _mean_x(mask: PackedByteArray, width: int) -> float:
	var total := 0.0
	for k in mask.size():
		if mask[k] == 1:
			total += k % width
	return total / maxf(_count(mask), 1)


func _shot(view: SubViewport) -> Image:
	for i in 6:
		await process_frame
	var image := view.get_texture().get_image()
	image.convert(Image.FORMAT_RGBAF)
	return image


func _diff_mask(a: Image, b: Image) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(a.get_width() * a.get_height())
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if maxf(absf(p.r - q.r), maxf(absf(p.g - q.g), maxf(absf(p.b - q.b), absf(p.a - q.a)))) > TOLERANCE:
				out[y * a.get_width() + x] = 1
	return out


func _opening(image: Image) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(image.get_width() * image.get_height())
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				out[y * image.get_width() + x] = 1
	return out


func _count(mask: PackedByteArray) -> int:
	return mask.count(1)


func _outside(mask: PackedByteArray, area: PackedByteArray) -> int:
	var n := 0
	for k in mask.size():
		if mask[k] == 1 and area[k] == 0:
			n += 1
	return n
