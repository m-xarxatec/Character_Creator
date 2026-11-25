extends SceneTree
# Paso PE.2: SpringBoneSimulator3D en esta versión de Godot (base del pelo con movimiento). Una cadena de 3 huesos de
# 10 cm que sale en horizontal (+X): (a) sin nada, acaba colgando (ángulo con −Y < MAX_HANG_DEG tras 4 s); (b) con una
# esfera debajo, ninguna articulación entra en ella más de MAX_SINK; (c) dos veces seguidas, el mismo resultado.
# El esqueleto avanza a mano (MODIFIER_CALLBACK_MODE_PROCESS_MANUAL + advance): paso fijo y repetible. La pose simulada
# solo se lee dentro de skeleton_updated (fuera, get_bone_global_pose da la pose sin simular).
# Medido el 2026-11-25: cuelga a 2,1°; con la esfera, las articulaciones a 78 mm del centro (radio 80); el tramo entre
# dos articulaciones sí la corta (hasta 14 mm con huesos de 10 cm): el choque es por articulación.
# Uso: (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_muelle.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')
# Que detecta el fallo: set_gravity(0, 0.0) -> no cuelga.

const MAX_HANG_DEG := 5.0  # PROVISIONAL (medido 2,1°)
const MAX_SINK := 0.005  # PROVISIONAL: metros (medido 2 mm)
const FRAMES := 240
const SPHERE_CENTER := Vector3(0.15, -0.12, 0.0)
const SPHERE_RADIUS := 0.08
var failures := 0
var skeleton: Skeleton3D
var joints: Array[Vector3] = []


func _initialize() -> void:
	await process_frame
	var free_a := await _run(false)
	var free_b := await _run(false)
	var hang := rad_to_deg(free_a.normalized().angle_to(Vector3.DOWN))
	print("MEDIDA cuelga a %.1f° de la vertical" % hang)
	check("la cadena acaba colgando", hang < MAX_HANG_DEG, "%.1f°" % hang)
	check("dos veces, el mismo resultado", free_a.is_equal_approx(free_b), "%s / %s" % [free_a, free_b])
	await _run(true)
	var nearest := INF
	for p in joints:
		nearest = minf(nearest, p.distance_to(SPHERE_CENTER))
	print("MEDIDA articulaciones a %.1f mm del centro de la esfera (radio %.0f)" % [nearest * 1000, SPHERE_RADIUS * 1000])
	check("no entra en la esfera", nearest >= SPHERE_RADIUS - MAX_SINK, "%.1f mm" % (nearest * 1000))
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


## Punta − raíz al final de la simulación (pose simulada).
func _run(with_sphere: bool) -> Vector3:
	skeleton = Skeleton3D.new()
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	root.add_child(skeleton)
	for i in 4:
		var bone := skeleton.add_bone("b%d" % i)
		if i > 0:
			skeleton.set_bone_parent(bone, i - 1)
		var rest := Transform3D(Basis(Vector3.BACK, -PI / 2), Vector3.ZERO) if i == 0 else Transform3D(Basis(), Vector3(0, 0.1, 0))
		skeleton.set_bone_rest(bone, rest)
		skeleton.set_bone_pose(bone, rest)
	var sim := SpringBoneSimulator3D.new()
	skeleton.add_child(sim)
	sim.setting_count = 1
	sim.set_root_bone_name(0, "b0")
	sim.set_end_bone_name(0, "b3")
	sim.set_stiffness(0, 0.1)
	sim.set_gravity(0, 1.0)
	sim.set_drag(0, 0.4)
	sim.set_radius(0, 0.01)
	if with_sphere:
		var sphere := SpringBoneCollisionSphere3D.new()
		sphere.radius = SPHERE_RADIUS
		sim.add_child(sphere)
		sphere.position = SPHERE_CENTER
		sim.set_enable_all_child_collisions(0, true)
	var tip := [Vector3.ZERO]
	joints.clear()
	skeleton.skeleton_updated.connect(func() -> void:
		tip[0] = skeleton.get_bone_global_pose(3).origin - skeleton.get_bone_global_pose(0).origin
		for i in 4:
			joints.append(skeleton.get_bone_global_pose(i).origin))
	await process_frame  # la cadena entra en el árbol antes del primer paso
	for f in FRAMES:
		skeleton.advance(1.0 / 60.0)
		await process_frame  # sin un fotograma entre pasos sale otra cosa (medido: 4,8° y sin tocar la esfera)
	skeleton.queue_free()
	return tip[0]
