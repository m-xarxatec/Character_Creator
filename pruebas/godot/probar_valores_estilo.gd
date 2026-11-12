extends "res://probar_estilo.gd"
# Paso 3.10c: hoja de valores del estilo. Prueba visual, sin límites: el mismo personaje (preset anime_femenino, con
# normales suavizadas como en probar_estilo) con cada valor al mínimo, por defecto y al máximo; todo lo demás, con los
# valores de BodyMaterial (también la piel y la prenda).
# Necesita ventana (no --headless).
# Uso: (ulimit -v 4000000; timeout 600 godot --path pruebas/godot -s probar_valores_estilo.gd 2>&1 | grep -E 'ERROR|GUARDADO')
# Opcional: `-- --salida=<carpeta>` guarda las capturas en otra carpeta (sin él, en pruebas/capturas/valores_estilo/).
# Cada casilla: de frente (ortogonal) y con la cámara del juego (ventana de 1920×1080, recortada sin escalar). Nada se
# escala: el grosor del contorno en la hoja es el de la pantalla.

const PRESET := "anime_femenino"
const GAME_SIZE := Vector2i(1920, 1080)
const TILE := Vector2i(360, 600)
const LABEL_WIDTH := 240
const CAPTION := 44
const GAP := 24
const ROWS := [
	["borde\n(softness)", [["mínimo", {"softness": 0.02}], ["por defecto", {"softness": 0.04}],
		["máximo", {"softness": 0.06}]]],
	["rim: fuerza", [["mínimo", {"rim_strength": 0.15}], ["por defecto", {"rim_strength": 0.25}],
		["máximo", {"rim_strength": 0.35}]]],
	["rim: ancho", [["mínimo", {"rim_width": 0.15}], ["por defecto", {"rim_width": 0.3}],
		["máximo", {"rim_width": 0.5}]]],
	["contorno", [["mínimo", {"width_px": 1.0}], ["2 px", {"width_px": 2.0}], ["por defecto", {"width_px": 2.5}],
		["máximo", {"width_px": 4.0}]]],
	["piel", [["por defecto", {"skin_color": Color(0.80, 0.80, 0.80)}], ["cálida", {"skin_color": Color(0.93, 0.80, 0.70)}],
		["oscura", {"skin_color": Color(0.55, 0.38, 0.28)}], ["azul", {"skin_color": Color(0.45, 0.60, 0.85)}]]],
	["sombra\n(× color)", [["más suave", {"shadow_shade": 0.85}], ["por defecto", {"shadow_shade": 0.73}],
		["más fuerte", {"shadow_shade": 0.6}]]],
]


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	out = _capture_folder("pruebas/capturas/valores_estilo")
	DirAccess.make_dir_recursive_absolute(out)
	shapes = load(addon.path_join("shape_weights.gd"))
	proportions = load(addon.path_join("proportions.gd"))
	refit = load(addon.path_join("skeleton_refit.gd"))
	baker = load(addon.path_join("mesh_baker.gd"))
	garment_texture = load(addon.path_join("garment_texture.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	root.add_child(species.scene)
	base = refit.capture_base(species.skeleton)
	head_mask = _head_mask()
	_build_view()
	var body := _bake(_load_preset(PRESET)["valores"], {})
	var smooth: PackedVector3Array = _smooth_normals(body["vertices"], body["normals"], SMOOTH_STEPS)
	var cells: Array[Array] = []
	for row: Array in ROWS:
		var line := []
		for variant: Array in row[1]:
			var file := "%s_%s" % [row[0].get_slice("\n", 0).replace(": ", "_"), variant[0].replace(" ", "_")]
			line.append([_caption(variant), await _pair(body, smooth, variant[1], file)])
		cells.append(line)
	_save(await _labeled_sheet(cells), "hoja_valores")
	quit(0)


## El material del núcleo con sus valores por defecto, salvo los de changes (width_px va al contorno).
func _variant_material(changes: Dictionary) -> ShaderMaterial:
	var defaults: Dictionary = load(root_dir.path_join("godot/addons/creador/body_material.gd")).DEFAULTS
	var material := _toon_material([defaults["skin_color"], defaults["garment_color"]])
	for name: String in changes:
		var target: ShaderMaterial = material.get_meta("outline") if name == "width_px" else material
		target.set_shader_parameter(name, changes[name])
	return material


## De frente y con la cámara del juego, una al lado de la otra, a tamaño real.
func _pair(body: Dictionary, normals: PackedVector3Array, changes: Dictionary, file: String) -> Array[Image]:
	var height: float = body["height"]
	var front := _model(body, normals, _variant_material(changes))
	_ortho(Vector3(0.0, height / 2.0, 0.0), height * 1.08)
	var front_image := await _shot(front, 0.0, TILE, file + "_frente")
	front.free()
	var game := _model(body, normals, _variant_material(changes))
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	(ground.mesh as PlaneMesh).size = Vector2(60.0, 60.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.62, 0.64, 0.6)
	ground.material_override = ground_material
	game.add_child(ground)
	_game_camera(Vector3(0.0, height / 2.0, 0.0))
	var full := await _shot(game, -25.0, GAME_SIZE, file + "_juego")
	game.free()
	var game_image := full.get_region(Rect2i((GAME_SIZE - TILE) / 2, TILE))
	return [front_image, game_image]


func _caption(variant: Array) -> String:
	var value: Variant = variant[1].values()[0]
	var text := "%.2f / %.2f / %.2f" % [value.r, value.g, value.b] if value is Color \
		else ("%s px" % value if variant[1].has("width_px") else "%s" % value)
	return "%s · %s" % [variant[0], text.replace(".", ",")]


## Hoja con rótulos: una fila por valor (nombre a la izquierda) y en cada casilla su rótulo, frente y juego.
func _labeled_sheet(cells: Array[Array]) -> Image:
	var columns := 0
	for line in cells:
		columns = maxi(columns, line.size())
	var cell := Vector2i(2 * TILE.x + GAP, CAPTION + TILE.y + GAP)
	var sheet_viewport := SubViewport.new()
	sheet_viewport.size = Vector2i(LABEL_WIDTH + columns * cell.x, cells.size() * cell.y)
	sheet_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet_viewport)
	var background := ColorRect.new()
	background.color = Color.WHITE
	background.size = sheet_viewport.size
	sheet_viewport.add_child(background)
	for r in cells.size():
		var y := r * cell.y
		_label(sheet_viewport, ROWS[r][0], Vector2(12, y + CAPTION + TILE.y / 2 - 30), 30)
		for c in cells[r].size():
			var x := LABEL_WIDTH + c * cell.x
			_label(sheet_viewport, cells[r][c][0], Vector2(x, y + 4), 26)
			for i in 2:
				var picture := TextureRect.new()
				picture.texture = ImageTexture.create_from_image(cells[r][c][1][i])
				picture.position = Vector2(x + i * TILE.x, y + CAPTION)
				sheet_viewport.add_child(picture)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := sheet_viewport.get_texture().get_image()
	sheet_viewport.queue_free()
	return image


func _label(parent: Node, text: String, position: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.BLACK)
	parent.add_child(label)
