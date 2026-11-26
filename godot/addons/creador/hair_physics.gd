class_name HairPhysics
extends RefCounted
## Paso PE.4a: movimiento del pelo (ficha `ruta/pasos/PE.4_fisica_pelo.md`). Un SpringBoneSimulator3D hijo del
## esqueleto con una entrada por cadena de HairChains y colisiones en cabeza, cuello, hombros, pecho y espalda,
## medidas del cuerpo horneado (un poco por dentro de la piel: en reposo el pelo no choca).
## Uso:
##   var chains := HairChains.build(mesh, species.skeleton)
##   var simulator := HairPhysics.attach(species.skeleton, chains, species.mesh)   # null si no hay cadenas
##   HairPhysics.refit(simulator, species.mesh)   # tras cambiar el cuerpo: mide otra vez y reinicia
## Comprobado en Godot 4.7.2: ni el radio ni el desplazamiento de una colisión escalan con su hueso; refit pone las
## medidas reales (en metros, sin la escala de Proporción).

const MeshBaker := preload("mesh_baker.gd")

const DEFAULTS := {  # todos PROVISIONAL hasta el juicio del responsable
	"rigidez": 1.0,
	"rigidez_punta": 0.4,  # la curva va de rigidez (raíz) a esto (punta): la punta se mueve más
	"freno": 0.4,
	"gravedad": 0.0,  # los peinados ya están modelados colgando: con 0,05 se hundían 4–14 mm quietos (PE.4a)
	"radio": 0.005,  # metros: radio de cada articulación al chocar, con la cabeza a ×1 (crece con ella)
	"percentil": 0.25,  # de la distancia de la piel al eje: el radio de cada colisión (con 0,4 el pelo ya chocaba)
}
## Colisiones: hueso, forma y eje de la cápsula ("hueso" = el del hueso; "ancho" = izquierda-derecha del personaje,
## para el tronco, que es más ancho que hondo).
const COLLIDERS := [
	["Head", "esfera", ""], ["Neck", "capsula", "hueso"], ["LeftShoulder", "capsula", "hueso"],
	["RightShoulder", "capsula", "hueso"], ["UpperChest", "capsula", "ancho"], ["Chest", "capsula", "ancho"],
]
const EXTENT := 0.05  # fracción de puntos que se deja fuera en cada extremo del eje (picos sueltos)


static func attach(skeleton: Skeleton3D, chains: Array[PackedStringArray], body: MeshInstance3D,
		settings := {}) -> SpringBoneSimulator3D:
	if chains.is_empty():
		return null
	var config := DEFAULTS.duplicate()
	config.merge(settings, true)
	var simulator := SpringBoneSimulator3D.new()
	simulator.name = "FisicaPelo"
	simulator.set_meta("percentil", config["percentil"])
	simulator.set_meta("radio", config["radio"])
	skeleton.add_child(simulator)
	for entry: Array in COLLIDERS:
		if skeleton.find_bone(entry[0]) >= 0:
			var shape: SpringBoneCollision3D = SpringBoneCollisionSphere3D.new() if entry[1] == "esfera" else SpringBoneCollisionCapsule3D.new()
			shape.name = "Choque" + entry[0]
			shape.bone_name = entry[0]
			shape.set_meta("eje", entry[2])
			simulator.add_child(shape)
	var stiffness := Curve.new()
	stiffness.add_point(Vector2(0.0, 1.0))
	stiffness.add_point(Vector2(1.0, config["rigidez_punta"] / config["rigidez"]))
	simulator.setting_count = chains.size()
	for i in chains.size():
		simulator.set_root_bone_name(i, chains[i][0])
		simulator.set_end_bone_name(i, chains[i][chains[i].size() - 1])  # la punta no lleva peso: hace de cola
		simulator.set_stiffness(i, config["rigidez"])
		simulator.set_stiffness_damping_curve(i, stiffness)
		simulator.set_drag(i, config["freno"])
		simulator.set_gravity(i, config["gravedad"])
		simulator.set_gravity_direction(i, Vector3.DOWN)
		simulator.set_radius(i, config["radio"])
		simulator.set_enable_all_child_collisions(i, true)
	refit(simulator, body)
	return simulator


## Mide las colisiones con el cuerpo tal como está (formas, Proporción y pose) y reinicia la simulación.
static func refit(simulator: SpringBoneSimulator3D, body: MeshInstance3D) -> void:
	if simulator == null:
		return
	var skeleton := simulator.get_parent() as Skeleton3D
	var points: PackedVector3Array = MeshBaker.bake(body, skeleton)["vertices"]
	var owners := _owners(body, skeleton)
	var globals := MeshBaker.global_poses(skeleton)
	for shape: Node in simulator.get_children():
		if shape is SpringBoneCollision3D:
			var bone := skeleton.find_bone(shape.bone_name)
			var frame := Transform3D(globals[bone].basis.orthonormalized(), globals[bone].origin)  # sin la escala
			var mine := PackedVector3Array()
			for i in points.size():
				if owners[i] == bone:
					mine.append(frame.affine_inverse() * points[i])
			if mine.size() >= 4:
				_fit(shape, mine, frame, simulator.get_meta("percentil"))
	var grow := globals[skeleton.find_bone(simulator.get_root_bone_name(0))].basis.get_scale().x  # el pelo crece con la cabeza
	for i in simulator.setting_count:
		simulator.set_radius(i, simulator.get_meta("radio") * grow)
	simulator.reset()


## Por vértice del cuerpo, el hueso que más pesa.
static func _owners(body: MeshInstance3D, skeleton: Skeleton3D) -> PackedInt32Array:
	var arrays := body.mesh.surface_get_arrays(0)
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var count := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var per := bones.size() / count
	var owners := PackedInt32Array()
	owners.resize(count)
	for i in count:
		var best := 0
		for k in per:
			if weights[i * per + k] > weights[i * per + best]:
				best = k
		var bind := bones[i * per + best]
		var bone := body.skin.get_bind_bone(bind)
		owners[i] = bone if bone >= 0 else skeleton.find_bone(body.skin.get_bind_name(bind))
	return owners


## Coloca y mide una colisión con los puntos del hueso (en su marco sin escala).
static func _fit(shape: SpringBoneCollision3D, points: PackedVector3Array, frame: Transform3D, percentile: float) -> void:
	if shape is SpringBoneCollisionSphere3D:
		var center := Vector3.ZERO
		for p in points:
			center += p
		center /= points.size()
		var distances := PackedFloat32Array()
		for p in points:
			distances.append(p.distance_to(center))
		shape.position_offset = center
		shape.radius = _percentile(distances, percentile)
		return
	var axis := Vector3.UP if shape.get_meta("eje") == "hueso" else (frame.basis.inverse() * Vector3.RIGHT).normalized()
	var along := PackedFloat32Array()
	var across := Vector3.ZERO
	for p in points:
		along.append(p.dot(axis))
		across += p - axis * p.dot(axis)
	across /= points.size()
	var radial := PackedFloat32Array()
	for p in points:
		radial.append((p - axis * p.dot(axis) - across).length())
	var radius := _percentile(radial, percentile)
	var low := _percentile(along, EXTENT)
	var high := _percentile(along, 1.0 - EXTENT)
	var capsule := shape as SpringBoneCollisionCapsule3D
	shape.position_offset = across + axis * (low + high) * 0.5
	shape.rotation_offset = Quaternion(Vector3.UP, axis)
	capsule.height = maxf(high - low, 2.0 * radius) + 2.0 * radius  # primero cabe el radio; luego la altura buena
	capsule.radius = radius
	capsule.height = maxf(high - low, 2.0 * radius)


static func _percentile(values: PackedFloat32Array, fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(fraction * (sorted.size() - 1)), 0, sorted.size() - 1)]
