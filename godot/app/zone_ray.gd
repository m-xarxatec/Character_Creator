extends RefCounted
# Paso IU.7a: qué zona del cuerpo toca un rayo (clic en la vista). Algoritmo de ruta/ARQUITECTURA.md §4: rayo →
# triángulo más cercano → su vértice más cercano al punto → hueso de mayor peso → zona (BONE_ZONES). En la CPU, con las
# posiciones de ahora (formas + pose) que calcula CharacterBox con todos los vértices. Un hueso fuera de la tabla da ""
# (otra especie no rompe).
# Uso: var ray := ZoneRay.new(species.mesh); ray.refresh(species.mesh, species.skeleton)
#      var zone := ray.pick(from, direction)  # en el mundo; "" si no toca o el hueso no tiene zona

const CharacterBox := preload("character_box.gd")

## Hueso del perfil humanoide → zona de deslizadores.csv. Los dedos y el pulgar, por prefijo (FINGERS).
const BONE_ZONES := {
	"Hips": "Caderas", "Spine": "Cintura", "Chest": "Torso", "UpperChest": "Pecho", "Neck": "Cuello", "Head": "Cabeza",
	"LeftShoulder": "Hombros", "RightShoulder": "Hombros",
	"LeftUpperArm": "Brazos", "LeftLowerArm": "Brazos", "RightUpperArm": "Brazos", "RightLowerArm": "Brazos",
	"LeftHand": "Manos", "RightHand": "Manos",
	"LeftUpperLeg": "Piernas", "LeftLowerLeg": "Piernas", "RightUpperLeg": "Piernas", "RightLowerLeg": "Piernas",
	"LeftFoot": "Pies", "LeftToes": "Pies", "RightFoot": "Pies", "RightToes": "Pies",
}
const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Little"]

var box  # CharacterBox con todos los vértices
var triangles := PackedInt32Array()
var slot := PackedInt32Array()  # vértice → su posición en box.samples
var placed := PackedVector3Array()  # posición de ahora de cada muestra (espacio de la malla)
var to_world := Transform3D.IDENTITY
var bind_zones: Array[String] = []  # índice de bind del Skin → zona ("" sin zona)
var refresh_ms := 0
var pick_ms := 0


func _init(mesh: MeshInstance3D) -> void:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	triangles = arrays[Mesh.ARRAY_INDEX]
	box = CharacterBox.new(mesh, PackedInt32Array(range(count)))
	slot.resize(count)
	for s in box.samples.size():
		slot[box.samples[s]] = s
	var skeleton := mesh.get_node(mesh.skeleton) as Skeleton3D
	for bind in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(bind)
		var name: String = mesh.skin.get_bind_name(bind) if bone < 0 else skeleton.get_bone_name(bone)
		bind_zones.append(zone_of(name))


## Zona de un hueso por su nombre; "" si no tiene.
static func zone_of(bone: String) -> String:
	if BONE_ZONES.has(bone):
		return BONE_ZONES[bone]
	for finger: String in FINGERS:
		if bone.begins_with("Left" + finger) or bone.begins_with("Right" + finger):
			return "Dedos"
	return ""


## Lee las posiciones con las formas y la pose de ahora. Llamarlo antes de pick si algo cambió.
func refresh(mesh: MeshInstance3D, skeleton: Skeleton3D) -> void:
	var start := Time.get_ticks_msec()
	placed = box.points(mesh, skeleton)
	to_world = mesh.global_transform if mesh.is_inside_tree() else Transform3D.IDENTITY
	refresh_ms = Time.get_ticks_msec() - start


## Zona que toca el rayo (en el mundo); "" si no toca el cuerpo.
func pick(from: Vector3, direction: Vector3) -> String:
	var start := Time.get_ticks_msec()
	var vertex := nearest_vertex(from, direction)
	pick_ms = Time.get_ticks_msec() - start
	return "" if vertex < 0 else bind_zones[_main_bind(vertex)]


## Vértice del triángulo más cercano que toca el rayo, el más cercano al punto; -1 si no toca.
func nearest_vertex(from: Vector3, direction: Vector3) -> int:
	var local := to_world.affine_inverse()
	var origin := local * from
	var ray := (local.basis * direction).normalized()
	var best := INF
	var hit_at := Vector3.ZERO
	var hit_triangle := -1
	for t in range(0, triangles.size(), 3):
		var a := placed[slot[triangles[t]]]
		var b := placed[slot[triangles[t + 1]]]
		var c := placed[slot[triangles[t + 2]]]
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, ray, a, b, c)
		if hit != null:
			var distance := origin.distance_squared_to(hit)
			if distance < best:
				best = distance
				hit_at = hit
				hit_triangle = t
	if hit_triangle < 0:
		return -1
	var nearest := triangles[hit_triangle]
	for k in range(1, 3):
		var vertex := triangles[hit_triangle + k]
		if placed[slot[vertex]].distance_squared_to(hit_at) < placed[slot[nearest]].distance_squared_to(hit_at):
			nearest = vertex
	return nearest


## Índice de bind del hueso de mayor peso del vértice.
func _main_bind(vertex: int) -> int:
	var s := slot[vertex]
	var best := 4 * s
	for k in range(4 * s + 1, 4 * s + 4):
		if box.weights[k] > box.weights[best]:
			best = k
	return box.bones[best]
