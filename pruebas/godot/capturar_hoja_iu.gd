extends SceneTree
# Paso IU.11: hoja de capturas del cierre de la fase IU. La ventana en oscuro y en claro, a 1280 × 720, a 1920 × 1080 y
# al 150 % (1920 × 1080), y hoja.png con las seis (2 filas: oscuro, claro). Con ventana.
# Borra user://ajustes.cfg al empezar y al terminar.
# Uso: (ulimit -v 4000000; timeout 120 godot --path pruebas/godot -s capturar_hoja_iu.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Escribe en pruebas/capturas/interfaz/iu11/. Que detecta el fallo: no cambiar el tamaño de la ventana -> falla el tamaño.

const SIZES := [["1280x720", Vector2i(1280, 720), 1.0], ["1920x1080", Vector2i(1920, 1080), 1.0],
	["150", Vector2i(1920, 1080), 1.5]]
const CELL := Vector2i(640, 360)

var out: String
var failures := 0


func _initialize() -> void:
	var root_dir := ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	out = root_dir.path_join("pruebas/capturas/interfaz/iu11")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)  # si no, el gestor la recorta a la pantalla
	var settings := ProjectSettings.globalize_path("user://ajustes.cfg")
	DirAccess.remove_absolute(settings)
	var main: Control = load(root_dir.path_join("godot/app/main.gd")).new()
	root.add_child(main)
	await process_frame  # _ready de main corre al entrar en el árbol
	var sheet := Image.create(CELL.x * SIZES.size(), CELL.y * 2, false, Image.FORMAT_RGBA8)
	for row in 2:
		var dark := row == 0
		main.set_dark(dark)
		for column in SIZES.size():
			var size: Vector2i = SIZES[column][1]
			root.size = size
			DisplayServer.window_set_size(size)  # en Windows root.size solo no cambia la ventana
			main.set_ui_scale(SIZES[column][2])
			var name := "%s_%s" % ["oscuro" if dark else "claro", SIZES[column][0]]
			var image := await _shoot(name)
			check("%s: %d × %d y no vacía" % [name, size.x, size.y], image.get_size() == size and not image.is_invisible()
				and _varied(image), str(image.get_size()))
			image.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(image, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, row * CELL.y))
	sheet.save_png(out.path_join("hoja.png"))
	main.set_ui_scale(1.0)
	main.free()
	await process_frame
	DirAccess.remove_absolute(settings)
	print("Capturas en ", out)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures > 0 else 0)


func _shoot(name: String) -> Image:
	for i in 15:
		await process_frame
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.save_png(out.path_join(name + ".png"))
	return image


## No es de un solo color: dos esquinas y el centro distintos.
func _varied(image: Image) -> bool:
	var center := image.get_pixelv(image.get_size() / 2)
	return image.get_pixel(0, 0) != center or image.get_pixel(image.get_width() - 1, image.get_height() - 1) != center


func check(text: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + text, " ", detail)
	if not ok:
		failures += 1
