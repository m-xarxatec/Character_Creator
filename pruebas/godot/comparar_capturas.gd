extends SceneTree
# Paso 5.11: compara capturas nuevas con las aprobadas: % de píxeles distintos e imagen de diferencias. Funciona sin ventana.
# Uso:
#   godot --headless --path pruebas/godot -s comparar_capturas.gd -- <aprobada> <nueva> <salida> [--limite=<%>] 2>&1 | grep -E 'MEDIDA|AVISO|FALLO|RESULTADO'
#   Sin argumentos: comprueba el comparador con imágenes construidas.
# Un píxel es distinto si algún canal difiere más de CHANNEL_TOLERANCE (de 255). La diferencia: la imagen nueva en gris con
# los píxeles distintos en rojo, en <salida>/<nombre>_dif.png.
# Que detecta el fallo: CHANNEL_TOLERANCE := 4 -> falla «todos los canales +5».

const CHANNEL_TOLERANCE := 8
const DEFAULT_LIMIT := 0.1  # %; ruido medido 0,000 %. Aprobado el 2026-11-18

var failures := 0


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var paths := args.filter(func(a: String) -> bool: return not a.begins_with("--"))
	if paths.size() < 3:
		_self_check()
	else:
		var limit := DEFAULT_LIMIT
		for arg: String in args:
			if arg.begins_with("--limite="):
				limit = float(arg.trim_prefix("--limite="))
		_compare_folders(paths[0], paths[1], paths[2], limit)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## % de píxeles distintos (−1 si el tamaño no coincide) y la imagen de diferencias (null si no hay ninguna).
static func compare(approved: Image, fresh: Image) -> Array:
	if approved.get_size() != fresh.get_size():
		return [-1.0, null]
	approved = approved.duplicate() as Image
	fresh = fresh.duplicate() as Image
	approved.convert(Image.FORMAT_RGBA8)
	fresh.convert(Image.FORMAT_RGBA8)
	var a := approved.get_data()
	var b := fresh.get_data()
	var marks := PackedByteArray()
	marks.resize(a.size() / 4)
	var different := 0
	for p in marks.size():
		for c in 4:
			if absi(a[4 * p + c] - b[4 * p + c]) > CHANNEL_TOLERANCE:
				marks[p] = 1
				different += 1
				break
	if different == 0:
		return [0.0, null]
	var gray: Image = fresh.duplicate()
	gray.convert(Image.FORMAT_L8)
	gray.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = gray.get_data()
	for p in marks.size():
		if marks[p]:
			data[4 * p] = 255
			data[4 * p + 1] = 0
			data[4 * p + 2] = 0
	return [100.0 * different / marks.size(), Image.create_from_data(gray.get_width(), gray.get_height(), false, Image.FORMAT_RGBA8, data)]


func _compare_folders(approved: String, fresh: String, out: String, limit: float) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var fresh_files := Array(DirAccess.get_files_at(fresh)).filter(func(f: String) -> bool: return f.ends_with(".png"))
	for file: String in DirAccess.get_files_at(approved):
		if not file.ends_with(".png"):
			continue
		if not file in fresh_files:
			print("  FALLO falta ", file)
			failures += 1
			continue
		fresh_files.erase(file)
		var result := compare(Image.load_from_file(approved.path_join(file)), Image.load_from_file(fresh.path_join(file)))
		if result[0] < 0.0:
			print("  FALLO tamaño distinto ", file)
			failures += 1
			continue
		print("  MEDIDA %s: %.3f %%" % [file, result[0]])
		if result[1] != null:
			(result[1] as Image).save_png(out.path_join(file.get_basename() + "_dif.png"))
		if result[0] > limit:
			print("  FALLO %s: %.3f %% > %s %%" % [file, result[0], limit])
			failures += 1
	for file: String in fresh_files:
		print("  AVISO nueva sin aprobar ", file)


func _self_check() -> void:
	var base := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	for y in 100:
		for x in 100:
			base.set_pixel(x, y, Color8(x * 2, y * 2, 100, 255))
	var same: Array = compare(base, base)
	check("una imagen contra sí misma: 0 %", same[0] == 0.0 and same[1] == null)
	var square: Image = base.duplicate()
	square.fill_rect(Rect2i(10, 10, 10, 10), Color.BLACK)
	var result: Array = compare(base, square)
	var red := 0
	if result[1] != null:
		var data: PackedByteArray = (result[1] as Image).get_data()
		for p in data.size() / 4:
			if data[4 * p] == 255 and data[4 * p + 1] == 0 and data[4 * p + 2] == 0:
				red += 1
	check("un cuadrado de 10 × 10 cambiado en 100 × 100: 1,00 %, con 100 píxeles rojos", absf(result[0] - 1.0) < 0.0001 and red == 100,
		"%.4f %%, %d rojos" % [result[0], red])
	var brighter: Image = base.duplicate()
	var bytes: PackedByteArray = brighter.get_data()
	for i in bytes.size():
		if i % 4 != 3:
			bytes[i] = mini(bytes[i] + 5, 255)
	brighter = Image.create_from_data(100, 100, false, Image.FORMAT_RGBA8, bytes)
	check("todos los canales +5: 0 % (dentro de la tolerancia)", compare(base, brighter)[0] == 0.0, "%.3f %%" % compare(base, brighter)[0])
	var bigger := Image.create(100, 101, false, Image.FORMAT_RGBA8)
	check("otro tamaño: se detecta", compare(base, bigger)[0] < 0.0)
