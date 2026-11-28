extends SceneTree
# Pasos 3.10a, 3.10c y 3.11b: el material del cuerpo (body_material.gd con toon.gdshader y outline.gdshader). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_material.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# DEFAULTS se compara con los `uniform` de los .gdshader (que el código y los shaders no se separen) y con la tabla
# «Valores por defecto» de diseno/GUIA_ESTILO.md (que el código y la guía no se separen).

var failures := 0
var material: GDScript
var root_dir: String
var species


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	var addon := root_dir.path_join("godot/addons/creador")
	material = load(addon.path_join("body_material.gd"))
	species = load(addon.path_join("species_data.gd")).new()
	if species.load_folder(root_dir.path_join("godot/datos/humana")):
		print("ERROR: ", species.error)
		quit(1)
		return
	_check_without_material()
	_check_material(material.apply(species.mesh))
	_check_defaults_match_shaders()
	_check_defaults_match_guide()
	_check_no_specular()
	_check_garment()
	_check_colors()
	_check_finish()
	_check_outline_width()
	_check_unlit()
	_check_standalone()
	_check_hide_mask()
	_check_editor_alpha()
	species.scene.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


func _check_without_material() -> void:
	check("sin material: valen los valores por defecto (prenda visible, sin unlit, contorno por defecto)",
		material.is_garment_visible(species.mesh) and not material.is_unlit(species.mesh)
		and material.get_color(species.mesh, "skin_color") == material.DEFAULTS["skin_color"]
		and material.get_outline_width(species.mesh) == material.OUTLINE_DEFAULTS["width_px"])


func _check_material(applied: ShaderMaterial) -> void:
	check("apply(): material toon en el cuerpo", applied.shader == material.SHADER and species.mesh.material_override == applied)
	var outline := applied.next_pass as ShaderMaterial
	check("contorno presente: next_pass con outline.gdshader", outline != null and outline.shader == material.OUTLINE_SHADER)
	var all_set := true
	for name: String in material.DEFAULTS:
		all_set = all_set and applied.get_shader_parameter(name) == material.DEFAULTS[name]
	for name: String in material.OUTLINE_DEFAULTS:
		all_set = all_set and outline != null and outline.get_shader_parameter(name) == material.OUTLINE_DEFAULTS[name]
	check("apply() pone todos los valores por defecto, del cuerpo y del contorno", all_set)
	check("contorno: grosor por defecto %s px" % material.OUTLINE_DEFAULTS["width_px"],
		material.get_outline_width(species.mesh) == material.OUTLINE_DEFAULTS["width_px"])
	var again: ShaderMaterial = material.apply(species.mesh)
	check("otra llamada a apply() da otro material con otro contorno (no se apilan)", again != applied and again.next_pass != outline)


## Los valores de DEFAULTS y OUTLINE_DEFAULTS son los de los `uniform` de los dos .gdshader (ni uno más ni uno menos).
func _check_defaults_match_shaders() -> void:
	_compare_uniforms("toon.gdshader", material.DEFAULTS)
	_compare_uniforms("outline.gdshader", material.OUTLINE_DEFAULTS)


func _compare_uniforms(file: String, defaults: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(root_dir.path_join("godot/addons/creador").path_join(file))
	var regex := RegEx.create_from_string("uniform\\s+(\\w+)\\s+(\\w+)\\s*(?::[^=;]*)?=\\s*([^;]+);")
	var found := {}
	for match in regex.search_all(text):
		found[match.get_string(2)] = _parse(match.get_string(1), match.get_string(3).strip_edges())
	var wrong: Array[String] = []
	for name: String in defaults:
		if not found.has(name) or not _equal(found[name], defaults[name]):
			wrong.append(name)
	for name: String in found:
		if not defaults.has(name):
			wrong.append(name)
	check("%s: sus %d uniform coinciden con los valores por defecto del código" % [file, found.size()], wrong.is_empty(), str(wrong))


## Cada fila de la tabla de la guía (| Qué | `código` | valor | Estado |) tiene el mismo valor en el código.
func _check_defaults_match_guide() -> void:
	var defaults: Dictionary = material.DEFAULTS.merged(material.OUTLINE_DEFAULTS)
	var text := FileAccess.get_file_as_string(root_dir.path_join("diseno/GUIA_ESTILO.md"))
	var regex := RegEx.create_from_string("(?m)^\\|[^|]*\\|\\s*`(\\w+)`\\s*\\|([^|]+)\\|")
	var rows := regex.search_all(text)
	var wrong: Array[String] = []
	for row in rows:
		var name := row.get_string(1)
		var parts := row.get_string(2).replace(",", ".").split("/")
		var value: Variant = Color(float(parts[0]), float(parts[1]), float(parts[2])) if parts.size() == 3 else float(parts[0])
		if not defaults.has(name) or not _equal(value, defaults[name]):
			wrong.append(name)
	check("guía: las %d filas de «Valores por defecto» coinciden con el código" % rows.size(),
		rows.size() == 7 and wrong.is_empty(), str(wrong))


func _parse(type: String, value: String) -> Variant:
	if type == "bool":
		return value == "true"
	if type == "vec3":
		var parts := value.trim_prefix("vec3(").trim_suffix(")").split(",")
		return Color(float(parts[0]), float(parts[1]), float(parts[2]))
	return float(value)


func _equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	return a.is_equal_approx(b) if a is Color else (is_equal_approx(a, b) if a is float else a == b)


## Sin brillo (guía, §4): el shader desactiva el especular y la luz ambiente, y no lo pone a mano.
func _check_no_specular() -> void:
	var text := FileAccess.get_file_as_string(root_dir.path_join("godot/addons/creador/toon.gdshader"))
	check("sin brillo: render_mode con specular_disabled y ambient_light_disabled; SPECULAR siempre 0",
		text.contains("specular_disabled") and text.contains("ambient_light_disabled") and text.contains("SPECULAR = 0.0;")
		and not text.contains("SPECULAR = 1") and not text.contains("SPECULAR = 0.5"))


func _check_garment() -> void:
	check("prenda: visible al empezar", material.is_garment_visible(species.mesh))
	material.set_garment_visible(species.mesh, false)
	check("prenda: oculta", not material.is_garment_visible(species.mesh))
	material.set_garment_visible(species.mesh, true)
	check("prenda: visible otra vez", material.is_garment_visible(species.mesh))


func _check_colors() -> void:
	var skin := Color(0.5, 0.25, 0.125)
	var garment := Color(0.75, 0.5, 0.25)
	material.set_color(species.mesh, "skin_color", skin)
	material.set_color(species.mesh, "garment_color", garment)
	check("colores: ida y vuelta de piel y prenda (y sin tocar la prenda ni el contorno)",
		material.get_color(species.mesh, "skin_color") == skin and material.get_color(species.mesh, "garment_color") == garment
		and material.is_garment_visible(species.mesh) and material.get_outline_width(species.mesh) == material.OUTLINE_DEFAULTS["width_px"])


## Paso 4.7: acabado (borde, rim y contorno) con set_finish / get_finish.
func _check_finish() -> void:
	var defaults: Dictionary = material.default_finish()
	check("acabado: sin tocar, el de por defecto", material.get_finish(species.mesh) == defaults, str(material.get_finish(species.mesh)))
	var shaders := FileAccess.get_file_as_string(root_dir.path_join("godot/addons/creador/toon.gdshader")) \
		+ FileAccess.get_file_as_string(root_dir.path_join("godot/addons/creador/outline.gdshader"))
	for name: String in material.FINISH:
		var low: float = material.FINISH[name][0]
		var high: float = material.FINISH[name][1]
		check("acabado '%s': el rango es el hint_range del shader" % name,
			shaders.contains("uniform float %s : hint_range(%.1f, %.1f)" % [name, low, high]), "%s a %s" % [low, high])
		var middle := (low + high) / 2.0
		check("acabado '%s': ida y vuelta" % name, material.set_finish(species.mesh, name, middle)
			and is_equal_approx(material.get_finish(species.mesh)[name], middle))
		material.set_finish(species.mesh, name, high + 5.0)
		var top: float = material.get_finish(species.mesh)[name]
		material.set_finish(species.mesh, name, low - 5.0)
		check("acabado '%s': se recorta a su rango" % name, top == high and material.get_finish(species.mesh)[name] == low)
		check("acabado '%s': NaN e infinito se rechazan y no cambian nada" % name, not material.set_finish(species.mesh, name, NAN)
			and not material.set_finish(species.mesh, name, INF) and material.get_finish(species.mesh)[name] == low)
		material.set_finish(species.mesh, name, defaults[name])
	check("acabado: clave desconocida rechazada", not material.set_finish(species.mesh, "skin_color", 0.5))
	check("acabado: vuelve al de por defecto", material.get_finish(species.mesh) == defaults)


func _check_outline_width() -> void:
	check("contorno: set_outline_width(4) → 4", material.set_outline_width(species.mesh, 4.0) and material.get_outline_width(species.mesh) == 4.0)
	material.set_outline_width(species.mesh, 99.0)
	check("contorno: por encima del máximo se recorta a %s" % material.MAX_OUTLINE_PX, material.get_outline_width(species.mesh) == material.MAX_OUTLINE_PX)
	material.set_outline_width(species.mesh, -3.0)
	check("contorno: 0 = sin contorno; lo negativo se recorta a 0", material.get_outline_width(species.mesh) == 0.0)
	material.set_outline_width(species.mesh, 4.0)
	check("contorno: NaN e infinito se rechazan y no cambian nada",
		not material.set_outline_width(species.mesh, NAN) and not material.set_outline_width(species.mesh, INF)
		and material.get_outline_width(species.mesh) == 4.0)


func _check_unlit() -> void:
	var applied := species.mesh.material_override as ShaderMaterial
	var outline: ShaderMaterial = applied.next_pass
	check("unlit: apagado al empezar, con contorno", not material.is_unlit(species.mesh) and applied.next_pass != null)
	material.set_unlit(species.mesh, true)
	check("unlit encendido: parámetro puesto y sin contorno (next_pass vacío)", material.is_unlit(species.mesh) and applied.next_pass == null)
	material.set_outline_width(species.mesh, 6.0)
	check("unlit: el grosor se puede cambiar sin contorno", material.get_outline_width(species.mesh) == 6.0 and applied.next_pass == null)
	material.set_unlit(species.mesh, false)
	check("unlit apagado: vuelve el mismo contorno, con el grosor de antes",
		not material.is_unlit(species.mesh) and applied.next_pass == outline and material.get_outline_width(species.mesh) == 6.0)
	material.set_unlit(species.mesh, true)
	check("unlit no cambia colores ni prenda", material.get_color(species.mesh, "skin_color") != Color.BLACK and material.is_garment_visible(species.mesh))
	material.set_unlit(species.mesh, false)


## Paso 3.11b: la copia para el juego lleva los valores de la malla, con luces, y los shaders incrustados (sin ruta).
func _check_standalone() -> void:
	material.set_color(species.mesh, "skin_color", Color(0.9, 0.6, 0.5))
	material.set_garment_visible(species.mesh, false)
	material.set_unlit(species.mesh, true)
	var copy: ShaderMaterial = material.standalone(species.mesh)
	var outline := copy.next_pass as ShaderMaterial
	check("copia: valores de la malla (piel, prenda oculta, grosor 6) y con luces",
		copy.get_shader_parameter("skin_color") == Color(0.9, 0.6, 0.5) and copy.get_shader_parameter("show_garment") == false
		and copy.get_shader_parameter("unlit") == false and outline != null and outline.get_shader_parameter("width_px") == 6.0)
	check("copia: shaders incrustados (sin ruta) con el mismo código que los del addon",
		copy.shader.resource_path == "" and copy.shader.code == material.SHADER.code
		and outline.shader.resource_path == "" and outline.shader.code == material.OUTLINE_SHADER.code)
	var path := "user://probar_material_copia.tres"
	var saved := ResourceSaver.save(copy, path)
	var text := FileAccess.get_file_as_string(path)
	check("copia guardada en .tres: sin ninguna ruta res:// y con los dos shaders dentro",
		saved == OK and not text.contains("res://") and text.count("shader_type spatial") == 2, "error %d" % saved)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	material.set_unlit(species.mesh, false)
	material.set_garment_visible(species.mesh, true)
	_check_standalone_anime()


## SH.5: en estilo anime la copia es de toon_soft, con la piel, el acabado y el mapa de zonas, todo dentro del .tres.
func _check_standalone_anime() -> void:
	material.set_style(species.mesh, true)
	material.set_skin_zones(species.mesh, species.skin_zones)
	material.set_skin(species.mesh, "freckles", 4)
	material.set_finish(species.mesh, "softness", 0.14)
	material.set_color(species.mesh, "skin_color", Color(0.3, 0.19, 0.14))
	var copy: ShaderMaterial = material.standalone(species.mesh)
	check("copia anime: shader toon_soft incrustado", copy.shader.resource_path == "" and copy.shader.code == material.SOFT_SHADER.code)
	check("copia anime: piel, acabado, color y zonas de la malla", copy.get_shader_parameter("freckles") == 4.0
		and is_equal_approx(copy.get_shader_parameter("softness"), 0.14) and copy.get_shader_parameter("skin_color") == Color(0.3, 0.19, 0.14)
		and copy.get_shader_parameter("edge_strength") == material.SKIN_START["edge_strength"]
		and copy.get_shader_parameter("skin_zones") != null and species.skin_zones != null)
	var path := "user://probar_material_copia_anime.tres"
	var saved := ResourceSaver.save(copy, path)
	var text := FileAccess.get_file_as_string(path)
	check("copia anime guardada en .tres: sin rutas, con los dos shaders y el mapa de zonas dentro",
		saved == OK and not text.contains("res://") and text.count("shader_type spatial") == 2 and text.contains("Image"), "error %d" % saved)
	var reloaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ShaderMaterial
	var zones: Texture2D = reloaded.get_shader_parameter("skin_zones") if reloaded != null else null
	var expected_size: int = material.EXPORT_ZONES_SIZE
	check("copia anime: el .tres se vuelve a leer con el mapa de zonas (%d px) y pesa menos de 1,5 MB" % expected_size,
		zones != null and zones.get_width() == expected_size and text.length() < 1500000, "%s, %d bytes" % [zones, text.length()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	material.set_style(species.mesh, false)


## Paso 12.1b-b3: máscara de piel oculta. Sin máscara no se descarta nada: el hint debe dar A = 0 (transparente; el
## negro de Godot es opaco, A = 1, y lo descartaría todo) y el discard va en la primera línea de fragment().
func _check_hide_mask() -> void:
	var discard_first := RegEx.create_from_string("void fragment\\(\\) \\{\\n\\tif \\(texture\\(hide_mask, UV\\)\\.a > 0\\.5\\) \\{ discard; \\}")
	for file: String in ["toon.gdshader", "toon_soft.gdshader", "outline.gdshader"]:
		var text := FileAccess.get_file_as_string(root_dir.path_join("godot/addons/creador").path_join(file))
		check("máscara: %s con hide_mask transparente por defecto y discard al empezar fragment()" % file,
			text.contains("uniform sampler2D hide_mask : hint_default_transparent,") and discard_first.search(text) != null)
	check("máscara: las piezas (copias del toon) también la llevan", material.piece_shader(false).code.contains("hide_mask")
		and material.piece_shader(true).code.contains("hide_mask"))
	material.apply(species.mesh)
	var outline := (species.mesh.material_override as ShaderMaterial).get_meta("outline") as ShaderMaterial
	check("máscara: sin poner, ninguna", material.get_hide_mask(species.mesh) == null)
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	var mask := ImageTexture.create_from_image(image)
	material.set_hide_mask(species.mesh, mask)
	check("máscara: ida y vuelta", material.get_hide_mask(species.mesh) == mask)
	check("máscara: el contorno la lleva", outline.get_shader_parameter("hide_mask") == mask)
	material.set_style(species.mesh, true)
	check("máscara: sobrevive al cambio a anime (cuerpo y contorno)", material.get_hide_mask(species.mesh) == mask
		and outline.get_shader_parameter("hide_mask") == mask)
	var copy: ShaderMaterial = material.standalone(species.mesh)
	check("máscara: la copia para el juego va sin ella (cuerpo y contorno)", copy.get_shader_parameter("hide_mask") == null
		and (copy.next_pass as ShaderMaterial).get_shader_parameter("hide_mask") == null)
	material.set_style(species.mesh, false)
	check("máscara: sobrevive al volver al clásico", material.get_hide_mask(species.mesh) == mask)
	material.set_hide_mask(species.mesh, null)
	check("máscara: null la quita del cuerpo y del contorno", material.get_hide_mask(species.mesh) == null
		and outline.get_shader_parameter("hide_mask") == null)


## Paso 3.11b: toon.gdshader lee la prenda con min(rojo, alfa); en el editor el alfa vale 1, así que manda el rojo.
func _check_editor_alpha() -> void:
	var colors: PackedColorArray = species.mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var lowest := 1.0
	for color in colors:
		lowest = minf(lowest, color.a)
	check("malla del editor: alfa 1 en todos los vértices (min(rojo, alfa) = rojo)", colors.size() > 0 and lowest == 1.0,
		"%d vértices, alfa mínimo %s" % [colors.size(), lowest])
