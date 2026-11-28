extends SceneTree
# Paso 15.2a: la tabla de funciones por plataforma (godot/app/platform.gd). Sin ventana; los dos «WARNING» esperados son
# los de la función desconocida.
# Uso: prlimit --as=4096000000 timeout 120 godot --headless --path pruebas/godot -s probar_plataforma.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'
# Que detecta el fallo: dar ANDROID a «exportar_glb» -> falla «android no exporta»; en current(), no mirar simulated ->
# falla «simulado: android».

## función → [la tiene el PC, la tiene Android] (ARQUITECTURA.md §8)
const EXPECTED := {
	"editar_cuerpo": [true, true], "editar_cara": [true, true], "estudio": [true, true],
	"abrir_proyecto": [true, true], "guardar_proyecto": [true, true], "exportar_glb": [true, false],
	"exportar_vrm": [true, false], "banco_de_pruebas": [true, false], "importar_pieza": [true, false],
	"escultura": [true, false], "packs_usuario": [true, false]}

var failures := 0


func _initialize() -> void:
	var godot_dir := ProjectSettings.globalize_path("res://").path_join("../../godot").simplify_path()
	var platform: GDScript = load(godot_dir.path_join("app/platform.gd"))
	check_table(platform)
	check_current(platform)
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures > 0 else 0)


func check_table(platform: GDScript) -> void:
	var names: Array = platform.FEATURES.keys()
	names.sort()
	var wanted: Array = EXPECTED.keys()
	wanted.sort()
	check("la tabla tiene las 11 funciones y ninguna más", names == wanted, str(names))
	for feature: String in EXPECTED:
		check("pc: «%s» %s" % [feature, EXPECTED[feature][0]], platform.can(feature, "pc") == EXPECTED[feature][0])
		check("android: «%s» %s" % [feature, EXPECTED[feature][1]],
			platform.can(feature, "android") == EXPECTED[feature][1])
	check("android no exporta", not platform.can("exportar_glb", "android"))
	check("función desconocida: no, en las dos", not platform.can("exportar_gbl", "pc")
		and not platform.can("exportar_gbl", "android"))
	check("plataforma desconocida: nada", EXPECTED.keys().all(
		func(feature: String) -> bool: return not platform.can(feature, "consola")))
	check("imagen: 8192 en pc y 4096 en android",
		platform.max_image_side("pc") == 8192 and platform.max_image_side("android") == 4096)
	check("imagen: plataforma desconocida, la de android", platform.max_image_side("consola") == 4096)


func check_current(platform: GDScript) -> void:
	check("de serie no se simula nada", platform.simulated == "")
	check("en el PC de pruebas: pc", platform.current() == "pc" and not platform.is_mobile(), platform.current())
	check("sin plataforma manda la actual (pc)", platform.can("exportar_glb") and platform.max_image_side() == 8192)
	platform.simulated = "android"
	check("simulado: android", platform.current() == "android" and platform.is_mobile(), platform.current())
	check("simulado: sin plataforma manda android", not platform.can("exportar_glb")
		and platform.can("guardar_proyecto") and platform.max_image_side() == 4096)
	check("simulado: la plataforma pedida manda sobre la simulada", platform.can("exportar_glb", "pc"))
	platform.simulated = ""
	check("al dejar de simular vuelve a pc", platform.current() == "pc")


func check(what: String, ok: bool, detail := "") -> void:
	if not ok:
		failures += 1
	print("  %s  %s%s" % ["bien" if ok else "FALLO", what, "" if detail.is_empty() else " (%s)" % detail])
