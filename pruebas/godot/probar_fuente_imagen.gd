extends SceneTree
# TA.4c: lectura segura de un PNG para el Taller (ImageSource.load_png). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_fuente_imagen.gd 2>&1 | grep -E 'FALLO|RESULTADO')
# Los PNG se crean en user://ta4c_fuente (carpeta de este proyecto de pruebas) y se borran al terminar.
# Que detecta el fallo: decodificar antes de leer la cabecera -> falla «rechaza por la cabecera un ancho falso».

const MAX_SIDE := 4096
const MAX_FILE := 256 * 1024 * 1024  # aprobado por el responsable en TA.4c

var source: GDScript
var recipe: GDScript
var folder: String
var failures := 0


func _initialize() -> void:
	var core := ProjectSettings.globalize_path("res://").path_join("../../godot/addons/creador/taller_assets").simplify_path()
	source = load(core.path_join("image_source.gd"))
	recipe = load(core.path_join("asset_recipe.gd"))
	folder = ProjectSettings.globalize_path("user://ta4c_fuente")
	DirAccess.make_dir_recursive_absolute(folder)
	_check_valid()
	_check_side_limit()
	_check_file_limit()
	_check_damaged()
	_check_other_files()
	_clean_up()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _check_valid() -> void:
	var alpha := _image(64, 48, Color.TRANSPARENT)
	var path := _save(alpha, "con_alfa.png")
	var result: Dictionary = source.load_png(path)
	_check("carga un PNG con alfa", result.error == "" and result.imagen.get_size() == Vector2i(64, 48), result.error)
	_check("el píxel de la imagen se conserva", result.get("imagen") != null
		and result.imagen.get_pixel(20, 20).is_equal_approx(Color.WHITE) and result.imagen.get_pixel(0, 0).a == 0.0)
	_check("el sha256 es el del archivo", result.get("sha256", "") == FileAccess.get_sha256(path), result.get("sha256", ""))
	_check("la ruta va en fuentes/", result.get("archivo", "") == "fuentes/con_alfa.png", result.get("archivo", ""))
	_check("la receta admite su fuente", _recipe_accepts(result))
	var opaque: Dictionary = source.load_png(_save(_image(32, 32, Color.BLUE), "fondo_color.png"))
	_check("carga un PNG con fondo de color", opaque.error == "" and opaque.imagen.detect_alpha() == Image.ALPHA_NONE)
	_check("otro archivo da otro sha256", opaque.get("sha256", "") != result.get("sha256", ""))
	var upper: Dictionary = source.load_png(_copy(path, "Mi Dibujo.PNG"))
	_check("el nombre pasa a minúsculas", upper.get("archivo", "") == "fuentes/mi dibujo.png", upper.get("archivo", ""))
	_check("la receta admite el nombre con espacio", _recipe_accepts(upper))


func _check_side_limit() -> void:
	for size: Vector2i in [Vector2i(MAX_SIDE, 1), Vector2i(1, MAX_SIDE)]:
		var result: Dictionary = source.load_png(_save(_image(size.x, size.y, Color.WHITE), "limite.png"))
		_check("admite %d × %d px" % [size.x, size.y], result.error == "" and result.imagen.get_size() == size, result.error)
	for size: Vector2i in [Vector2i(MAX_SIDE + 1, 1), Vector2i(1, MAX_SIDE + 1)]:
		var result: Dictionary = source.load_png(_save(_image(size.x, size.y, Color.WHITE), "grande.png"))
		_check("rechaza %d × %d px" % [size.x, size.y], _rejected(result, "máximo"), result.error)
	var good := FileAccess.get_file_as_bytes(_save(_image(8, 8, Color.WHITE), "base.png"))
	var fake := good.duplicate()
	fake.encode_u32(16, _swapped(8192))  # el ancho de la cabecera, sin arreglar su CRC
	var result: Dictionary = source.load_png(_write("ancho_falso.png", fake))
	_check("rechaza por la cabecera un ancho falso", _rejected(result, "máximo"), result.error)
	fake = good.duplicate()
	fake.encode_u32(20, 0xFFFFFFFF)
	result = source.load_png(_write("alto_enorme.png", fake))
	_check("un alto de 32 bits no se desborda", _rejected(result, "máximo"), result.error)


## Un PNG válido con relleno detrás: justo en el tope entra; un byte más se rechaza con un aviso claro.
func _check_file_limit() -> void:
	var good := FileAccess.get_file_as_bytes(_save(_image(8, 8, Color.WHITE), "base.png"))
	var inside: Dictionary = source.load_png(_padded("en_el_tope.png", good, MAX_FILE))
	_check("admite un archivo de 256 MB justos", inside.error == "", inside.error)
	DirAccess.remove_absolute(folder.path_join("en_el_tope.png"))
	var over: Dictionary = source.load_png(_padded("sobre_el_tope.png", good, MAX_FILE + 1))
	_check("rechaza un byte más con su aviso", _rejected(over, "pesa 257 MB y el máximo es 256 MB"), over.error)
	DirAccess.remove_absolute(folder.path_join("sobre_el_tope.png"))


func _padded(file_name: String, bytes: PackedByteArray, total: int) -> String:
	var path := folder.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.seek(total - 1)
	file.store_8(0)
	file.close()
	return path


func _check_damaged() -> void:
	var good := FileAccess.get_file_as_bytes(_save(_image(8, 8, Color.WHITE), "base.png"))
	var broken_signature := good.duplicate()
	broken_signature[1] = 0
	var broken_length := good.duplicate()
	broken_length[11] = 12
	var broken_type := good.duplicate()
	broken_type[12] = 0
	var zero_width := good.duplicate()
	zero_width.encode_u32(16, 0)
	var cases := {"vacío": PackedByteArray(), "texto": "esto no es un png".to_utf8_buffer(),
		"solo firma": good.slice(0, 8), "cabecera cortada": good.slice(0, 20), "firma rota": broken_signature,
		"longitud de IHDR falsa": broken_length, "tipo de bloque falso": broken_type, "ancho cero": zero_width,
		"datos cortados": good.slice(0, 30)}
	for label: String in cases:
		_check("rechaza un PNG: " + label, _rejected(source.load_png(_write("danado.png", cases[label]))))


func _check_other_files() -> void:
	var good := _save(_image(8, 8, Color.WHITE), "base.png")
	_check("rechaza otra extensión", _rejected(source.load_png(_copy(good, "dibujo.jpg")), "PNG"))
	_check("rechaza un archivo sin extensión", _rejected(source.load_png(_copy(good, "dibujo")), "PNG"))
	_check("rechaza un archivo que no existe", _rejected(source.load_png(folder.path_join("no_existe.png")), "abrir"))


func _recipe_accepts(loaded: Dictionary) -> bool:
	if loaded.error != "":
		return false
	var data := {"formato": recipe.FORMAT, "version": 1, "id": "pieza", "modo": "extrusion_imagen", "autor": "Taller",
		"licencia": "propia", "fuente": {"archivo": loaded.archivo, "sha256": loaded.sha256}}
	return recipe.normalize(data).error == ""


## Un error no trae imagen ni datos a medias.
func _rejected(result: Dictionary, wanted := "") -> bool:
	return result.size() == 1 and result.get("error", "") != "" and (wanted == "" or result.error.contains(wanted))


func _image(width: int, height: int, background: Color) -> Image:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(background)
	if width > 8 and height > 8:
		image.fill_rect(Rect2i(width / 4, height / 4, width / 2, height / 2), Color.WHITE)
	if background.a == 1.0:
		image.convert(Image.FORMAT_RGB8)
	return image


func _save(image: Image, file_name: String) -> String:
	var path := folder.path_join(file_name)
	image.save_png(path)
	return path


func _copy(from: String, file_name: String) -> String:
	return _write(file_name, FileAccess.get_file_as_bytes(from))


func _write(file_name: String, bytes: PackedByteArray) -> String:
	var path := folder.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return path


## Los PNG guardan los enteros al revés que encode_u32.
func _swapped(value: int) -> int:
	return (value & 0xFF) << 24 | (value & 0xFF00) << 8 | (value >> 8) & 0xFF00 | (value >> 24) & 0xFF


func _clean_up() -> void:
	for file in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)


func _check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
