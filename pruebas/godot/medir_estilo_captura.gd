extends SceneTree
# Paso 5.13: en una captura de frente (capturar_banco.gd, fondo de color liso), mide el grosor del contorno en el borde
# de la silueta a la altura de los muslos y cuenta los tonos de la piel. Sin ventana.
# Uso: godot --headless --path pruebas/godot -s medir_estilo_captura.gd -- <captura.png> [ancho de una vista en px] 2>&1 | grep MEDIDA
# Contorno: media, en las filas del 55 al 65 % del alto de la silueta, de los píxeles oscuros seguidos desde el fondo hacia
# dentro, por los dos lados. Tonos: luminancias de los píxeles que no son fondo ni contorno, agrupadas a menos de 8/255;
# solo cuentan los grupos con más del 2 % de esos píxeles.

const DARK := 0.12
const BACKGROUND_TOLERANCE := 10


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var image := Image.load_from_file(args[0])
	var width: int = int(args[1]) if args.size() > 1 else image.get_width()
	image = image.get_region(Rect2i(0, 0, width, image.get_height()))
	image.convert(Image.FORMAT_RGBA8)
	var background := image.get_pixel(width - 2, image.get_height() - 2)
	var top := image.get_height()
	var bottom := 0
	for y in image.get_height():
		for x in width:
			if not _is_background(image.get_pixel(x, y), background):
				top = mini(top, y)
				bottom = maxi(bottom, y)
	var runs := []
	for y in range(top + int(0.55 * (bottom - top)), top + int(0.65 * (bottom - top))):
		for direction: int in [1, -1]:
			var x := 0 if direction == 1 else width - 1
			while x >= 0 and x < width and _is_background(image.get_pixel(x, y), background):
				x += direction
			var run := 0
			while x >= 0 and x < width and image.get_pixel(x, y).get_luminance() < DARK:
				run += 1
				x += direction
			if run > 0:
				runs.append(run)
	var mean := 0.0
	for r: int in runs:
		mean += r
	mean /= maxi(runs.size(), 1)
	var groups := {}
	var total := 0
	for y in image.get_height():
		for x in width:
			var pixel := image.get_pixel(x, y)
			if _is_background(pixel, background) or pixel.get_luminance() < DARK:
				continue
			var key := int(pixel.get_luminance() * 255.0 / 8.0)
			groups[key] = groups.get(key, 0) + 1
			total += 1
	var tones := groups.values().filter(func(n: int) -> bool: return n > 0.02 * total).size()
	print("MEDIDA %s: contorno %.2f px (%d filas), %d tonos" % [args[0].get_file(), mean, runs.size() / 2, tones])
	quit()


func _is_background(pixel: Color, background: Color) -> bool:
	return absf(pixel.r - background.r) * 255 <= BACKGROUND_TOLERANCE and absf(pixel.g - background.g) * 255 <= BACKGROUND_TOLERANCE \
		and absf(pixel.b - background.b) * 255 <= BACKGROUND_TOLERANCE
