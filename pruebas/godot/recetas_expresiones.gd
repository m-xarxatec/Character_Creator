extends RefCounted
## Lo que las pruebas esperan de las expresiones según blender/expresiones.json (el mismo orden que
## blender/expresiones.py: las recetas en su orden y, detrás del último parpadeo «propio», sus 4 correcciones).
## repo: la raíz del repositorio. Sin recetas, las dos listas están vacías.

const FIXES := ["eye_tall_decr", "eye_tall_incr", "eye_size_decr", "eye_size_incr"]
const BLINKS := ["blinkLeft", "blinkRight"]


static func recipes(repo: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(repo.path_join("blender/expresiones.json")))
	return data["expresiones"] if data is Dictionary else {}


## Nombres VRM que lleva el .glb exportado (sin prefijo), en su orden.
static func vrm_names(repo: String) -> Array:
	return recipes(repo).keys()


## Formas expr_* de cuerpo.glb (datos), con las correcciones del parpadeo.
static func shape_names(repo: String) -> Array:
	var all := recipes(repo)
	var blinks: Array = all.keys().filter(func(n: String) -> bool: return n in BLINKS)
	var out := []
	for name: String in all:
		out.append("expr_" + name)
		if not blinks.is_empty() and name == blinks[-1]:
			for blink: String in blinks:
				if all[blink] is String and all[blink] == "propio":
					for fix: String in FIXES:
						out.append("expr_%s*%s" % [blink, fix])
	return out
