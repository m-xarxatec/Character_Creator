extends RefCounted
## TA.4c: lee un PNG para el Taller. Mira su cabecera antes de decodificar: lo enorme se rechaza sin gastar memoria.
## Uso: ImageSource.load_png(ruta)  # {error: "", imagen, archivo: "fuentes/<nombre>.png", sha256} o {error}

const ImageMask := preload("image_mask.gd")
const SIGNATURE := [137, 80, 78, 71, 13, 10, 26, 10]
const IHDR_TYPE := [73, 72, 68, 82]
const IHDR_LENGTH := 13
const HEADER_SIZE := 24
const MEGABYTE := 1024 * 1024
const MAX_FILE_BYTES := 256 * MEGABYTE  # aprobado en TA.4c: un PNG de 4096 px sin comprimir ronda los 128 MB


static func load_png(path: String) -> Dictionary:
	if path.get_extension().to_lower() != "png":
		return {"error": "Solo se admiten imágenes PNG."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "No se pudo abrir el archivo."}
	var length := file.get_length()
	if length > MAX_FILE_BYTES:
		return {"error": "El archivo pesa %d MB y el máximo es %d MB. Elige una imagen más ligera."
			% [ceili(float(length) / MEGABYTE), MAX_FILE_BYTES / MEGABYTE]}
	var problem := _header_error(file.get_buffer(HEADER_SIZE))
	if problem != "":
		return {"error": problem}
	file.seek(0)
	var bytes := file.get_buffer(length)
	problem = _header_error(bytes)  # el archivo pudo cambiar entre las dos lecturas
	if problem != "":
		return {"error": problem}
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK or image.is_empty():
		return {"error": "El PNG está dañado o no se pudo leer."}
	return {"error": "", "imagen": image, "archivo": _source_name(path), "sha256": _sha256(bytes)}


static func _header_error(header: PackedByteArray) -> String:
	if header.size() < HEADER_SIZE or not _matches(header, 0, SIGNATURE):
		return "El archivo no es un PNG válido."
	if _big_endian(header, 8) != IHDR_LENGTH or not _matches(header, 12, IHDR_TYPE):
		return "La cabecera del PNG está dañada."
	var width := _big_endian(header, 16)
	var height := _big_endian(header, 20)
	if width == 0 or height == 0:
		return "La cabecera del PNG está dañada."
	if maxi(width, height) > ImageMask.MAX_SOURCE_SIDE:
		return "La imagen mide %d × %d px: el máximo es %d px por lado." % [width, height, ImageMask.MAX_SOURCE_SIDE]
	return ""


static func _matches(bytes: PackedByteArray, start: int, expected: Array) -> bool:
	for i in expected.size():
		if bytes[start + i] != expected[i]:
			return false
	return true


static func _big_endian(bytes: PackedByteArray, start: int) -> int:
	return bytes[start] << 24 | bytes[start + 1] << 16 | bytes[start + 2] << 8 | bytes[start + 3]


static func _sha256(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


## Nombre en minúsculas y válido en cualquier sistema, como exige la receta.
static func _source_name(path: String) -> String:
	var clean := ""
	for ch in path.get_file().get_basename().to_lower():
		clean += "_" if ch.unicode_at(0) < 32 else ch
	clean = clean.strip_edges().validate_filename()
	return "fuentes/%s.png" % (clean if clean != "" else "imagen")
