extends SceneTree
# Paso AB.13b (D45): las pestañas Pelo, Ropa y Accesorios (godot/app/pieces_panel.gd) enseñan por pieza solo su nombre, su
# estado de puesta y su color: ni autor, ni licencia, ni creador (eso va solo en Créditos). Sin ventana.
# Uso: (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_piezas_limpias.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')
# Que detecta el fallo: en pieces_panel.gd, volver a añadir un Label con card["autor"] -> fallan «sin autor ni licencia» y «la fuente».

const WORDS := ["autor", "licencia", "creador", "cc0", "cc-by"]

var failures := 0


func _initialize() -> void:
	var app := ProjectSettings.globalize_path("res://").path_join("../../godot/app")
	var main: Control = load(app.path_join("main.gd").simplify_path()).new()
	root.add_child(main)
	await process_frame
	var view = main.body_view
	check("la biblioteca está cargada", view.library != null and not view.library.packs.is_empty())
	var forbidden := _forbidden(view.library)
	for tab_name: String in main.piece_panels:
		var panel: ScrollContainer = main.piece_panels[tab_name]
		var type: String = main.PIECE_TABS[tab_name]
		_check_buttons(view, panel, tab_name, type)
		_check_clean(panel, tab_name, forbidden)
		_check_toggle(view, panel, tab_name, type)
	var source := FileAccess.get_file_as_string(app.path_join("pieces_panel.gd").simplify_path())
	check("la fuente de pieces_panel.gd no lee ['autor'] ni ['licencia']", source != "" and not source.contains('["autor"]')
		and not source.contains('["licencia"]'))
	main.free()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## Autor y licencia de cada pack cargado (así vale para packs nuevos) y las palabras prohibidas.
func _forbidden(library) -> Array[String]:
	var list: Array[String] = []
	for id: String in library.packs:
		for field: String in ["autor", "licencia"]:
			list.append(String(library.packs[id]["datos"][field]).to_lower())
	list.append_array(WORDS)
	return list


## Las piezas de ese tipo que enseña el panel (las que siguen al cuerpo o son accesorios rígidos).
func _cards(view, type: String) -> Array:
	return view.library.pieces(type, view.SPECIES).filter(
		func(card: Dictionary) -> bool: return card["sigue_al_cuerpo"] or card.has("generador"))


func _check_buttons(view, panel, tab_name: String, type: String) -> void:
	var wrong := []
	var cards := _cards(view, type)
	for card: Dictionary in cards:
		var button: Button = panel.buttons.get(card["pack"].path_join(card["id"]))
		if button == null or button.text != card["nombre"]:
			wrong.append(card["id"])
	check("%s: un botón con el nombre de cada una de las %d piezas" % [tab_name, cards.size()], wrong.is_empty()
		and panel.buttons.size() == cards.size(), str(wrong))


func _check_clean(panel: Node, tab_name: String, forbidden: Array[String]) -> void:
	var found := []
	var texts := 0
	for node: Node in _all(panel):
		for property: String in ["text", "tooltip_text"]:
			if not property in node:
				continue
			var value: String = String(node.get(property)).to_lower()
			texts += 1
			for word: String in forbidden:
				if word != "" and value.contains(word):
					found.append("%s «%s» (%s)" % [node.name, value, word])
	check("%s: sin autor ni licencia en ningún texto ni tooltip (%d textos mirados)" % [tab_name, texts], found.is_empty()
		and texts > 0, str(found.slice(0, 3)))


func _all(node: Node) -> Array[Node]:
	var nodes: Array[Node] = [node]
	for child: Node in node.get_children():
		nodes.append_array(_all(child))
	return nodes


## Un clic en el botón pone la pieza (y queda pulsado); quitarla desde la vista lo desmarca.
func _check_toggle(view, panel, tab_name: String, type: String) -> void:
	var cards := _cards(view, type)
	if cards.is_empty():
		return
	var key: String = cards[0]["pack"].path_join(cards[0]["id"])
	var button: Button = panel.buttons[key]
	button.button_pressed = true
	check("%s: el clic en «%s» la pone y el botón queda pulsado" % [tab_name, button.text],
		view.is_on(key) and button.button_pressed == view.is_on(key))
	view.set_piece(cards[0]["pack"], cards[0]["id"], false)
	panel.refresh()
	check("%s: al quitarla, el botón se desmarca" % tab_name, not view.is_on(key) and not button.button_pressed)
