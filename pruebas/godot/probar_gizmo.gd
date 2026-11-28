extends SceneTree
# Paso 13.1a: cuentas del gizmo de mover, girar y escalar (godot/app/transform_gizmo.gd), sin cámara ni ventana, y
# colocación de un accesorio en otro hueso (RigidPiece: to_place, to_array, set_place).
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_gizmo.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: en TransformGizmo.angle, quitar el cambio de signo -> falla «girar hacia la cámara da +90°».
# En RigidPiece.set_place, usar place también en la copia «_i» -> falla «la copia _i es el reflejo de _d».

const TransformGizmo := preload("res://../../godot/app/transform_gizmo.gd")
const RigidPiece := preload("res://../../godot/addons/creador/rigid_piece.gd")
const EPSILON := 1e-6
const MAX_TURN_ERROR_DEG := 0.01

var failures := 0


func _initialize() -> void:
	_check_pick()
	_check_along()
	_check_angle()
	_check_factor()
	var frame := Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * 1.5), Vector3(0.1, 1.2, -0.3))
	var place := Transform3D(Basis(Vector3.RIGHT, 0.3).scaled(Vector3.ONE * 0.8), Vector3(0.02, 0.05, 0.01))
	_check_moved(frame, place)
	_check_turned(frame, place)
	_check_scaled(place)
	_check_numbers()
	_check_set_place()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func _check_pick() -> void:
	var handles: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(0, 0), Vector2(100, 0)]),
		PackedVector2Array([Vector2(0, 0), Vector2(0, 100)]),
	]
	check("pick: un asa a 5 px se coge", TransformGizmo.pick(handles, Vector2(50, 5), 10.0) == 0)
	check("pick: la segunda asa a 5 px se coge", TransformGizmo.pick(handles, Vector2(5, 50), 10.0) == 1)
	check("pick: a 20 px no coge nada", TransformGizmo.pick(handles, Vector2(50, 20), 10.0) == -1)


func _check_along() -> void:
	var meters := TransformGizmo.along(Vector2.ZERO, Vector2(100, 0), Vector2(10, 10), Vector2(60, 10))
	check("along: 50 px sobre un eje de 100 px por metro = 0,5 m", absf(meters - 0.5) <= EPSILON, str(meters))
	meters = TransformGizmo.along(Vector2.ZERO, Vector2(0.5, 0), Vector2(10, 10), Vector2(60, 10))
	check("along: un eje de punta no mueve", meters == 0.0, str(meters))


func _check_angle() -> void:
	var a := TransformGizmo.angle(Vector2.ZERO, Vector2(100, 0), Vector2(0, -100), true)
	check("angle: girar hacia la cámara da +90°", absf(a - PI / 2.0) <= EPSILON, str(rad_to_deg(a)))
	a = TransformGizmo.angle(Vector2.ZERO, Vector2(100, 0), Vector2(0, -100), false)
	check("angle: con el eje al revés da −90°", absf(a + PI / 2.0) <= EPSILON, str(rad_to_deg(a)))


func _check_factor() -> void:
	var f := TransformGizmo.factor(Vector2.ZERO, Vector2(100, 0), Vector2(150, 0))
	check("factor: de 100 a 150 px = ×1,5", absf(f - 1.5) <= EPSILON, str(f))
	f = TransformGizmo.factor(Vector2.ZERO, Vector2(10, 0), Vector2(100, 0))
	check("factor: como mucho ×2 por evento", absf(f - 2.0) <= EPSILON, str(f))


func _check_moved(frame: Transform3D, place: Transform3D) -> void:
	var axis := Vector3(1, 1, 0).normalized()
	var after := TransformGizmo.moved(frame, place, axis, 0.03)
	var before_world := frame * place
	var world := frame * after
	var shift := world.origin - before_world.origin - axis * 0.03
	check("moved: el mundo se mueve lo pedido (frame con escala 1,5 y giro)", shift.length() <= EPSILON, str(shift))
	check("moved: no gira ni escala", _basis_gap(world.basis, before_world.basis) <= EPSILON)


func _check_turned(frame: Transform3D, place: Transform3D) -> void:
	var axis := Vector3(1, 1, 0).normalized()
	var after := TransformGizmo.turned(frame, place, axis, 0.5)
	var before_world := frame * place
	var world := frame * after
	var shift := world.origin - before_world.origin
	check("turned: el origen del mundo no cambia", shift.length() <= EPSILON, str(shift))
	var turn := Quaternion((world.basis * before_world.basis.inverse()).orthonormalized())
	var error := rad_to_deg(turn.angle_to(Quaternion(axis, 0.5)))
	print("  MEDIDA error del giro: %.6f°" % error)
	check("turned: el giro del mundo es el pedido (≤ %s°)" % MAX_TURN_ERROR_DEG, error <= MAX_TURN_ERROR_DEG)


func _check_scaled(place: Transform3D) -> void:
	var s := _mean(TransformGizmo.scaled(place, 1.5).basis.get_scale())
	check("scaled: 0,8 × 1,5 = 1,2", _close(s, 1.2), str(s))
	s = _mean(TransformGizmo.scaled(place, 0.001).basis.get_scale())
	check("scaled: no baja de 0,05", _close(s, 0.05), str(s))
	s = _mean(TransformGizmo.scaled(place, 1000.0).basis.get_scale())
	check("scaled: no pasa de 20", _close(s, 20.0), str(s))
	check("scaled: no mueve", TransformGizmo.scaled(place, 1.5).origin.is_equal_approx(place.origin))


## Error relativo: la escala viaja en float de 32 bits (20 × 6e-8 ya pasa de 1e-6 absoluto).
func _close(value: float, goal: float) -> bool:
	return absf(value - goal) <= EPSILON * goal


func _check_numbers() -> void:
	# Cuaterniones exactamente unitarios: el redondeo a 6 decimales no los mueve.
	for t: Array in [[0.045, 0.1, -0.02, 0, 0, 0, 1, 1], [0, 0.03, 0.12, 0.5, 0.5, 0.5, 0.5, 1.3],
			[-0.25, 1.5, 0.004, 0.36, 0.48, 0.64, 0.48, 0.25]]:
		var back := RigidPiece.to_array(RigidPiece.to_place(t))
		var gap := 0.0
		for i in 8:
			gap = maxf(gap, absf(back[i] - t[i]))
		check("to_array(to_place(t)) = t (≤ 1e-6)", gap <= EPSILON, "%s → %s" % [t, back])


func _check_set_place() -> void:
	var skeleton := Skeleton3D.new()
	for bone in ["Root", "Head", "RightHand"]:
		skeleton.add_bone(bone)
	skeleton.set_bone_parent(1, 0)
	skeleton.set_bone_parent(2, 0)
	root.add_child(skeleton)
	var card := {"id": "prueba", "generador": {"tipo": "cuernos", "parametros": {}, "simetria": true},
		"anclaje": {"hueso": "Head", "transform": [0.045, 0.1, 0, 0, 0, 0, 1, 1]}}
	var holder: BoneAttachment3D = RigidPiece.build(card, skeleton)
	check("build sigue colgando del anclaje de serie", holder != null and holder.bone_name == "Head")
	var place := RigidPiece.to_place([0.02, -0.01, 0.05, 0.36, 0.48, 0.64, 0.48, 1.3])
	check("set_place en RightHand devuelve true", RigidPiece.set_place(holder, "RightHand", place))
	check("set_place cambia bone_name", holder.bone_name == "RightHand", holder.bone_name)
	check("get_place devuelve lo puesto", RigidPiece.get_place(holder).is_equal_approx(place))
	var mirror := Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO)
	var right: MeshInstance3D = holder.get_node("prueba_d")
	var left: MeshInstance3D = holder.get_node("prueba_i")
	check("la copia _d va en place", right.transform.is_equal_approx(place))
	check("la copia _i es el reflejo de _d", left.transform.is_equal_approx(mirror * right.transform * mirror))
	check("set_place en un hueso que no existe devuelve false",
		not RigidPiece.set_place(holder, "Cola", Transform3D()))
	check("…y no cambia nada", holder.bone_name == "RightHand" and right.transform.is_equal_approx(place)
		and RigidPiece.get_place(holder).is_equal_approx(place))
	skeleton.free()


func _basis_gap(a: Basis, b: Basis) -> float:
	return maxf((a.x - b.x).length(), maxf((a.y - b.y).length(), (a.z - b.z).length()))


func _mean(v: Vector3) -> float:
	return (v.x + v.y + v.z) / 3.0


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1
