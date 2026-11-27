class_name HairPhysics
extends RefCounted
## Paso PE.4a: movimiento del pelo (ficha `ruta/pasos/PE.4_fisica_pelo.md`). Un SpringBoneSimulator3D hijo del
## esqueleto con una entrada por cadena de HairChains y colisiones en cabeza, cuello, hombros, pecho y espalda,
## medidas del cuerpo horneado (un poco por dentro de la piel: en reposo el pelo no choca).
## Paso PE.4c (ficha `ruta/pasos/PE.4c_traspaso_pelo.md`): para que el pelo largo no entre en la espalda, la nuca ni
## lo alto de los hombros, refit añade «tiras» (cápsulas finas pegadas a la piel) y da a cada articulación un radio
## igual a su holgura (lo que le sobra hasta el choque más cercano, quieta), con un tope.
## Uso:
##   var chains := HairChains.build(mesh, species.skeleton)
##   var simulator := HairPhysics.attach(species.skeleton, chains, species.mesh)   # null si no hay cadenas
##   HairPhysics.refit(simulator, species.mesh)   # tras cambiar el cuerpo: mide otra vez y reinicia
## Comprobado en Godot 4.7.2: ni el radio ni el desplazamiento de una colisión escalan con su hueso; refit pone las
## medidas reales (en metros, sin la escala de Proporción). Y Godot prueba el choque de cada hueso en su punta a la
## longitud del reposo SIN la escala de Proporción (con Altura 0,65, 1/0,65 más lejos que la punta real): la holgura
## se mide ahí (si no, el pelo quieto se movía hasta 8,6 mm).

const MeshBaker := preload("mesh_baker.gd")

const DEFAULTS := {  # todos PROVISIONAL hasta el juicio del responsable
	"rigidez": 1.0,
	"rigidez_punta": 0.4,  # la curva va de rigidez (raíz) a esto (punta): la punta se mueve más
	"freno": 0.4,
	"gravedad": 0.0,  # los peinados ya están modelados colgando: con 0,05 se hundían 4–14 mm quietos (PE.4a)
	"radio": 0.005,  # metros: radio mínimo de cada articulación al chocar, con la cabeza a ×1 (crece con ella)
	"percentil": 0.25,  # de la distancia de la piel al eje: el radio de cada colisión (con 0,4 el pelo ya chocaba)
}
## Colisiones: hueso, forma y eje de la cápsula ("hueso" = el del hueso; "ancho" = izquierda-derecha del personaje,
## para el tronco, que es más ancho que hondo).
const COLLIDERS := [
	["Head", "esfera", ""], ["Neck", "capsula", "hueso"], ["LeftShoulder", "capsula", "hueso"],
	["RightShoulder", "capsula", "hueso"], ["UpperChest", "capsula", "ancho"], ["Chest", "capsula", "ancho"],
]
const EXTENT := 0.05  # fracción de puntos que se deja fuera en cada extremo del eje (picos sueltos)
## Tiras (PE.4c): hueso, dirección de las franjas, cara que toca la piel (direcciones del personaje) y su «piel» si no
## es la de STRIP. Lo alto de los hombros, 0,98 (con 0,9 quedaba 2–6 cm bajo la piel); con la cabeza grande vuelve a
## 0,9: Godot prueba el choque a la longitud sin escala y las puntas reales entraban (Cabeza ×2,5: 14,3 mm).
const STRIPS := [
	["Spine", "arriba", "atras"], ["Chest", "arriba", "atras"], ["UpperChest", "arriba", "atras"],
	["Neck", "arriba", "atras"], ["UpperChest", "ancho", "arriba", 0.98],
]
const STRIP := {"paso": 0.04, "radio": 0.045, "piel": 0.9}  # PROVISIONAL; metros × la escala del hueso
const HOLGURA := {"margen": 0.002, "tope": 0.04, "tope_cabeza": 0.015}  # PROVISIONAL; tope_cabeza: sobre el cuello
const DIRECTIONS := {"arriba": Vector3.UP, "ancho": Vector3.RIGHT, "atras": Vector3.FORWARD}  # mira a +Z


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
		simulator.set_enable_all_child_collisions(i, true)
	refit(simulator, body)
	return simulator


## Mide las colisiones con el cuerpo tal como está (formas, Proporción y pose) y reinicia la simulación.
static func refit(simulator: SpringBoneSimulator3D, body: MeshInstance3D) -> void:
	if simulator == null:
		return
	var skeleton := simulator.get_parent() as Skeleton3D
	for shape: Node in simulator.get_children():
		if shape.name.begins_with("Tira"):  # las del refit anterior (no tienen eje: _fit no sabría medirlas)
			simulator.remove_child(shape)
			shape.free()
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
	for entry: Array in STRIPS:
		if skeleton.find_bone(entry[0]) >= 0:
			_strip(simulator, skeleton, entry, points, owners, globals, grow)
	var base: float = simulator.get_meta("radio") * grow
	_retreat(simulator, skeleton, globals, base + HOLGURA["margen"])
	_joint_radii(simulator, skeleton, globals, base)
	simulator.reset()


## Una tira: el hueso cortado en franjas; en cada una, una cápsula a lo largo de la franja con su cara en la piel
## (percentil «piel» de los puntos de la franja; la espalda es casi plana y una cápsula gorda solo la tocaba a una altura).
static func _strip(simulator: SpringBoneSimulator3D, skeleton: Skeleton3D, entry: Array, points: PackedVector3Array,
		owners: PackedInt32Array, globals: Array[Transform3D], grow: float) -> void:
	var bone := skeleton.find_bone(entry[0])
	var frame := Transform3D(globals[bone].basis.orthonormalized(), globals[bone].origin)
	var k := globals[bone].basis.get_scale().x  # Proporción: con Altura 0,65 la tira también es más pequeña
	var step: float = STRIP["paso"] * k
	var radius: float = STRIP["radio"] * k
	var skin: float = STRIP["piel"]
	if entry.size() > 3:  # con la cabeza de ×1 a ×1,5, de su «piel» a la de todas
		skin = lerpf(entry[3], skin, clampf((grow - 1.0) * 2.0, 0.0, 1.0))
	var to_bone := skeleton.get_bone_global_rest(bone).basis.orthonormalized().inverse()  # direcciones del reposo
	var cut: Vector3 = (to_bone * DIRECTIONS[entry[1]]).normalized()
	var face: Vector3 = (to_bone * DIRECTIONS[entry[2]]).normalized()
	face = (face - cut * face.dot(cut)).normalized()
	var axis := cut.cross(face).normalized()
	var mine := PackedVector3Array()
	var heights := PackedFloat32Array()
	for i in points.size():
		if owners[i] == bone:
			mine.append(frame.affine_inverse() * points[i])
			heights.append(mine[mine.size() - 1].dot(cut))
	if mine.size() < 20:
		return
	var h := _percentile(heights, 0.02) + step * 0.5
	var top := _percentile(heights, 0.98)
	while h < top:
		var along := PackedFloat32Array()
		var outward := PackedFloat32Array()
		for p in mine:
			if absf(p.dot(cut) - h) < step * 0.5:
				along.append(p.dot(axis))
				outward.append(p.dot(face))
		if along.size() >= 20:  # franjas con pocos puntos: sueltas
			var low := _percentile(along, 0.15)
			var high := _percentile(along, 0.85)
			var shape := SpringBoneCollisionCapsule3D.new()
			shape.name = "Tira%d" % simulator.get_child_count()
			shape.bone_name = entry[0]
			shape.set_meta("cara", face)
			simulator.add_child(shape)
			shape.position_offset = axis * (low + high) * 0.5 + cut * h + face * (_percentile(outward, skin) - radius)
			shape.rotation_offset = Quaternion(Vector3.UP, axis)
			shape.radius = radius
			shape.height = 2.0 * (maxf((high - low) * 0.5 - radius, 0.0) + radius)
		h += step


## Retira hacia dentro cada tira que, quieta, deja algún punto que Godot prueba a menos de «gap» (el pelo ya
## descansa ahí: si tocara, se movería solo). Si el punto le queda de lado, retirarse no basta: si aún tocaría, se
## quita (con Cabeza ×0,8 long01 se movía quieto 27 mm).
static func _retreat(simulator: SpringBoneSimulator3D, skeleton: Skeleton3D, globals: Array[Transform3D], gap: float) -> void:
	var tested := PackedVector3Array()
	for i in simulator.setting_count:
		for j in simulator.get_joint_count(i):
			tested.append(globals[simulator.get_joint_bone(i, j)].origin)
			if j + 1 < simulator.get_joint_count(i):
				tested.append(_tail(simulator, globals, i, j))
	for shape: Node in simulator.get_children():
		if shape.name.begins_with("Tira"):
			var deficit := 0.0
			for p in tested:
				deficit = maxf(deficit, gap - _distance(skeleton, shape, globals, p))
			shape.position_offset -= (shape.get_meta("cara") as Vector3) * deficit
			var left := 0.0
			for p in tested:
				left = maxf(left, gap - _distance(skeleton, shape, globals, p))
			if left > HOLGURA["margen"]:
				simulator.remove_child(shape)
				shape.free()


## Radio de cada articulación = su holgura quieta − margen, entre el radio del peinado y el tope. Con radio por
## articulación Godot ya no usa los valores del ajuste: se ponen uno a uno, calculados del ajuste (los leídos de la
## articulación tras refit no sirven: el freno sale 0).
static func _joint_radii(simulator: SpringBoneSimulator3D, skeleton: Skeleton3D, globals: Array[Transform3D], base: float) -> void:
	var neck_y := globals[skeleton.find_bone("Neck")].origin.y
	for i in simulator.setting_count:
		var n := simulator.get_joint_count(i)
		var curve := simulator.get_stiffness_damping_curve(i)
		simulator.set_individual_config(i, true)
		for j in n:
			simulator.set_joint_stiffness(i, j, simulator.get_stiffness(i) * curve.sample(float(j) / maxf(n - 1, 1)))
			simulator.set_joint_drag(i, j, simulator.get_drag(i))
			simulator.set_joint_gravity(i, j, simulator.get_gravity(i))
			simulator.set_joint_gravity_direction(i, j, simulator.get_gravity_direction(i))
			var at := globals[simulator.get_joint_bone(i, j)].origin
			var room := _clearance(simulator, skeleton, globals, at)
			if j + 1 < n:
				room = minf(room, _clearance(simulator, skeleton, globals, _tail(simulator, globals, i, j)))
			var top: float = HOLGURA["tope"] if at.y < neck_y else HOLGURA["tope_cabeza"]
			simulator.set_joint_radius(i, j, clampf(room - HOLGURA["margen"], base, maxf(top, base)))


## Donde Godot prueba el choque de la articulación j: la punta de su hueso a la longitud sin la escala de Proporción.
static func _tail(simulator: SpringBoneSimulator3D, globals: Array[Transform3D], i: int, j: int) -> Vector3:
	var origin := globals[simulator.get_joint_bone(i, j)]
	var next := globals[simulator.get_joint_bone(i, j + 1)].origin
	return origin.origin + (next - origin.origin) / origin.basis.get_scale().x


## Distancia de un punto a la superficie del choque más cercano.
static func _clearance(simulator: SpringBoneSimulator3D, skeleton: Skeleton3D, globals: Array[Transform3D], point: Vector3) -> float:
	var best := INF
	for shape: Node in simulator.get_children():
		if shape is SpringBoneCollision3D:
			best = minf(best, _distance(skeleton, shape, globals, point))
	return best


## Distancia de un punto a la superficie de una colisión, colocada como la coloca Godot (su hueso sin la escala).
static func _distance(skeleton: Skeleton3D, shape: SpringBoneCollision3D, globals: Array[Transform3D], point: Vector3) -> float:
	var g := globals[skeleton.find_bone(shape.bone_name)]
	var place := Transform3D(g.basis.orthonormalized(), g.origin) * Transform3D(Basis(shape.rotation_offset), shape.position_offset)
	if shape is SpringBoneCollisionCapsule3D:
		var axis := place.basis.y.normalized()
		var half: float = shape.height * 0.5 - shape.radius
		var t := clampf((point - place.origin).dot(axis), -half, half)
		return point.distance_to(place.origin + axis * t) - shape.radius
	return point.distance_to(place.origin) - shape.radius


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
