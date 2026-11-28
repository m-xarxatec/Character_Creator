extends VBoxContainer
## Paso 13.1b: «Colocar» un accesorio puesto: elegir su hueso (los anclajes y, en la sección «Huesos», los huesos), el
## modo del gizmo (Mover, Girar, Escalar) y Restablecer (su anclaje de pack.json). Mientras está abierta hay un
## TransformGizmo en la vista y «Tocar zonas» apagado (un clic en el gizmo saltaría a la pestaña Cuerpo). La abre,
## la cierra y la libera pieces_panel.gd. Sin Deshacer.
## Uso:
##   var row := PlaceRow.new(); list.add_child(row); row.setup(body_view, "base/halo")
##   row.close()   # quita el gizmo y repone «Tocar zonas» como diga el ajuste

const BoneLabels := preload("bone_labels.gd")
const TransformGizmo := preload("transform_gizmo.gd")
const SettingsFile := preload("settings_file.gd")
const RigidPiece := preload("../addons/creador/rigid_piece.gd")

const SECTION := "Huesos"  # aparte: sus nombres se parecen a los de las zonas del cuerpo
const MODES := {"Mover": TransformGizmo.Mode.MOVE, "Girar": TransformGizmo.Mode.TURN, "Escalar": TransformGizmo.Mode.SCALE}

var view: SubViewportContainer  # BodyView
var key := ""  # "pack/pieza"
var bones := OptionButton.new()
var modes := {}  # texto de MODES → Button
var reset := Button.new()
var gizmo: TransformGizmo  # null si está cerrada


func setup(body_view: SubViewportContainer, piece_key: String) -> void:
	view = body_view
	key = piece_key
	_add_bones()
	_add_buttons()
	gizmo = TransformGizmo.new()
	gizmo.moved_by.connect(_on_moved)
	gizmo.turned_by.connect(_on_turned)
	gizmo.scaled_by.connect(_on_scaled)
	view.viewport.add_child(gizmo)  # después de la cámara: recibe la entrada antes
	view.set_touch_zones(false)
	_process(0.0)


func close() -> void:
	if gizmo == null:
		return
	gizmo.free()
	gizmo = null
	view.set_touch_zones(SettingsFile.get_touch_zones())


func _process(_delta: float) -> void:
	var holder := _holder()
	if gizmo != null and holder != null:
		gizmo.target = holder.global_transform * RigidPiece.get_place(holder)


## El accesorio puesto ahora, o null.
func _holder() -> BoneAttachment3D:
	return view.accessories.get(key)


func _card() -> Dictionary:
	return view.library.piece(key.get_base_dir(), key.get_file())


func _add_bones() -> void:
	for bone: String in BoneLabels.SOCKETS:
		_add_bone(bone)
	bones.add_separator(SECTION)
	bones.add_separator()  # la línea que subraya el título (theme_builder.gd)
	for bone: String in BoneLabels.BONES:
		_add_bone(bone)
	bones.item_selected.connect(_on_bone_selected)
	add_child(bones)
	_show_bone()


## Solo los que tiene la especie.
func _add_bone(bone: String) -> void:
	if view.species.skeleton.find_bone(bone) < 0:
		return
	bones.add_item(BoneLabels.label(bone))
	bones.set_item_metadata(bones.item_count - 1, bone)


## El desplegable enseña el hueso de ahora (ninguno si no está en la lista).
func _show_bone() -> void:
	var chosen := -1
	for i in bones.item_count:
		if not bones.is_item_separator(i) and bones.get_item_metadata(i) == _holder().bone_name:
			chosen = i
	bones.select(chosen)


func _add_buttons() -> void:
	var line := HBoxContainer.new()
	var group := ButtonGroup.new()
	for text: String in MODES:
		var button := Button.new()
		button.text = text
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = MODES[text] == TransformGizmo.Mode.MOVE
		button.toggled.connect(func(on: bool) -> void:
			if on:
				gizmo.mode = MODES[text])
		line.add_child(button)
		modes[text] = button
	reset.text = "Restablecer"
	reset.tooltip_text = "Volver a su sitio de serie"
	reset.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_END
	reset.pressed.connect(_on_reset)
	line.add_child(reset)
	add_child(line)


## En el hueso nuevo, en su origen, sin giro y con la escala de serie (los desplazamientos de otro hueso la alejarían).
func _on_bone_selected(index: int) -> void:
	var usual: Transform3D = RigidPiece.default_place(_card())["place"]
	RigidPiece.set_place(_holder(), bones.get_item_metadata(index),
		Transform3D(Basis.from_scale(usual.basis.get_scale()), Vector3.ZERO))


func _on_reset() -> void:
	var usual := RigidPiece.default_place(_card())
	RigidPiece.set_place(_holder(), usual["hueso"], usual["place"])
	_show_bone()


func _on_moved(axis: Vector3, meters: float) -> void:
	var holder := _holder()
	_place(TransformGizmo.moved(holder.global_transform, RigidPiece.get_place(holder), axis, meters))


func _on_turned(axis: Vector3, radians: float) -> void:
	var holder := _holder()
	_place(TransformGizmo.turned(holder.global_transform, RigidPiece.get_place(holder), axis, radians))


func _on_scaled(factor: float) -> void:
	_place(TransformGizmo.scaled(RigidPiece.get_place(_holder()), factor))


## Coloca la pieza en el hueso en el que está.
func _place(place: Transform3D) -> void:
	var holder := _holder()
	RigidPiece.set_place(holder, holder.bone_name, place)
