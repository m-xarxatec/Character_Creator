extends SceneTree
# Paso AB.16: exporta con el editor real un .glb con pelo, ropa y un accesorio rígido, para probar_glb.gd.
# Salida (ignorada por git): pruebas/godot/salida/glb_piezas/con_piezas.glb
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s generar_glb_piezas.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Luego: godot --headless --path pruebas/godot -s probar_glb.gd -- "$PWD/pruebas/godot/salida/glb_piezas" --piezas=4 --rigidas=2

const PIECES := [["quaternius", "hair_long"], ["overscore", "os_tank_top"], ["base", "cuernos"]]  # los cuernos son 2 mallas
const OUTPUT := "res://salida/glb_piezas/con_piezas.glb"


func _initialize() -> void:
	var main: Control = load(ProjectSettings.globalize_path("res://").path_join("../../godot/app/main.gd").simplify_path()).new()
	root.add_child(main)
	await process_frame
	var ok := true
	for piece: Array in PIECES:
		if not main.body_view.set_piece(piece[0], piece[1], true):
			print("  FALLO no se pudo poner ", piece[1])
			ok = false
	var path := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	DirAccess.remove_absolute(path)
	ok = main.body_view.export_glb(path) == OK and FileAccess.file_exists(path) and ok
	main.free()
	print("RESULTADO: ", "TODO BIEN" if ok else "FALLO al generar", " ", path)
	quit(0 if ok else 1)
