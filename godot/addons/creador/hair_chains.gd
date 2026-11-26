class_name HairChains
extends RefCounted
## Paso PE.3: cadenas de huesos para un peinado ya puesto (ficha `ruta/pasos/PE.3_cadenas_pelo.md`).
## Reparte el pelo en sectores alrededor de la cabeza; en cada sector que cuelga, una cadena `x_pelo_<sector>_<k>`
## hija de la cabeza, al final del esqueleto (los huesos del cuerpo no cambian de índice). Rehace los pesos del
## peinado (≤ 4, suman 1) y añade los binds a su Skin: en reposo, la malla queda donde estaba.
## Uso:
##   var mesh := BodyPiece.attach(library.load_piece("makehuman", "bob02"), species.skeleton)
##   BodyPiece.follow(mesh, species.mesh)                   # antes: las posiciones salen con las formas activas
##   var chains := HairChains.build(mesh, species.skeleton)  # [[x_pelo_0_0, x_pelo_0_1, …], …] o [] si no cuelga
##   BodyPiece.detach(mesh); HairChains.remove(species.skeleton)   # al quitar el peinado (PE.3b)
## Las cadenas siguen a la cabeza al cambiar el cuerpo: SkeletonRefit les deja su reposo local y BodyPiece.follow les
## pone la bind pose del reposo nuevo (PE.3b).

const MeshBaker := preload("mesh_baker.gd")

const PREFIX := "x_pelo_"
const DEFAULTS := {
	"hueso": "Head",  # perfil humanoide: vale para cualquier especie
	"sectores": 8,  # PROVISIONAL
	"separacion": 0.045,  # metros entre articulaciones (PE.2: el choque es por articulación)
	"max_articulaciones": 10,
	"largo_minimo": 0.07,  # metros colgando por debajo del inicio; menos = sin cadena. PROVISIONAL (PE.4b): con
	# el preset del personaje nuevo las patillas de hair_buzzed caían 62 mm; los cortos, 60–92 mm (se mueve la nuca)
	"inicio_frente": 0.10,  # metros sobre el origen de la cabeza, delante (flequillo)  PROVISIONAL
	"inicio_lados": 0.04,  # metros sobre el origen de la cabeza, a los lados y detrás  PROVISIONAL
	"fundido": 0.03,  # metros bajo el inicio en que se pasa de los pesos originales a la cadena
	"isla_pequena": 0.10,  # fracción de vértices: una isla menor va entera a un sector
}
const WELD := 0.0001  # metros: vértices más cerca que esto son el mismo (la importación los parte por las UV)
const MAX_INFLUENCES := 4


static func is_chain_bone(bone_name: String) -> bool:
	return bone_name.begins_with(PREFIX)


## Paso PE.3b: quita los huesos de cadena. Skeleton3D no tiene remove_bone (4.7.2): se rehace la lista con los demás,
## en el mismo orden (mismos índices), con su padre, reposo y pose. Llamarla después de quitar el peinado.
static func remove(skeleton: Skeleton3D) -> void:
	var kept: Array[Dictionary] = []
	for bone in skeleton.get_bone_count():
		if not is_chain_bone(skeleton.get_bone_name(bone)):
			var parent := skeleton.get_bone_parent(bone)
			kept.append({"name": skeleton.get_bone_name(bone), "rest": skeleton.get_bone_rest(bone),
				"parent": skeleton.get_bone_name(parent) if parent >= 0 else "",
				"position": skeleton.get_bone_pose_position(bone), "rotation": skeleton.get_bone_pose_rotation(bone),
				"scale": skeleton.get_bone_pose_scale(bone)})
	if kept.size() == skeleton.get_bone_count():
		return
	skeleton.clear_bones()
	for data in kept:
		skeleton.add_bone(data["name"])
	for bone in kept.size():
		var data := kept[bone]
		if data["parent"] != "":
			skeleton.set_bone_parent(bone, skeleton.find_bone(data["parent"]))
		skeleton.set_bone_rest(bone, data["rest"])
		skeleton.set_bone_pose_position(bone, data["position"])
		skeleton.set_bone_pose_rotation(bone, data["rotation"])
		skeleton.set_bone_pose_scale(bone, data["scale"])
	# Tras clear_bones la GPU deja de recibir la pose de las mallas que ya estaban puestas (el cuerpo se congela:
	# comprobado en 4.7.2, probar_pelo_ventana.gd); volver a darles el esqueleto las conecta otra vez.
	for mesh: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", true, false):
		var path := mesh.skeleton
		mesh.skeleton = NodePath()
		mesh.skeleton = path


static func build(piece: MeshInstance3D, skeleton: Skeleton3D, settings := {}) -> Array[PackedStringArray]:
	var config := DEFAULTS.duplicate()
	config.merge(settings, true)
	var result: Array[PackedStringArray] = []
	var head := skeleton.find_bone(config["hueso"])
	if head < 0 or piece.mesh == null or piece.skin == null or piece.mesh.get_surface_count() != 1:
		return result
	if not piece.transform.is_equal_approx(Transform3D.IDENTITY):
		push_error("HairChains: la pieza no está en el espacio del esqueleto")
		return result
	var arrays := piece.mesh.surface_get_arrays(0)
	var frame := _head_frame(skeleton, head)
	var coords := _coords(_shaped_points(piece, arrays), frame)
	var azimuths := _island_azimuths(coords, arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_INDEX], config)
	var chains: Array[Dictionary] = []
	for sector in int(config["sectores"]):
		var chain := _chain(sector, coords, azimuths, config)
		if not chain.is_empty():
			result.append(_add_bones(chain, sector, frame, skeleton, head, piece.skin))
		chains.append(chain)
	if not result.is_empty():
		_reweight(piece, arrays, coords, azimuths, chains, config)
	return result


## Posiciones de la superficie 0 con las formas activas (las que puso BodyPiece.follow).
static func _shaped_points(piece: MeshInstance3D, arrays: Array) -> PackedVector3Array:
	var points: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var normals: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var active := MeshBaker.active_shapes(piece)
	var shapes := {}
	MeshBaker.cache_shapes(piece, active, shapes)
	MeshBaker.add_shape_arrays(points, normals, active, shapes)
	return points


## Marco de la cabeza: origen en su articulación, Y su eje, Z hacia delante (+Z del mundo) y X a su izquierda.
static func _head_frame(skeleton: Skeleton3D, head: int) -> Transform3D:
	var rest := skeleton.get_bone_global_rest(head)
	var up := rest.basis.y.normalized()
	var forward := (Vector3.BACK - up * up.dot(Vector3.BACK)).normalized()
	return Transform3D(Basis(up.cross(forward), up, forward), rest.origin)


## Por vértice: x = altura, y = azimut en grados (0 delante, + a la izquierda), z = radio al eje.
static func _coords(points: PackedVector3Array, frame: Transform3D) -> PackedVector3Array:
	var inverse := frame.affine_inverse()
	var coords := PackedVector3Array()
	coords.resize(points.size())
	for i in points.size():
		var p := inverse * points[i]
		coords[i] = Vector3(p.y, rad_to_deg(atan2(p.x, p.z)), Vector2(p.x, p.z).length())
	return coords


## Azimut con que cada vértice elige sector: el suyo, o el del vértice más bajo de su isla si la isla es pequeña (por
## donde cuelga el mechón; el más alto suele estar en la coronilla, donde el azimut no dice nada: PE.4a).
static func _island_azimuths(coords: PackedVector3Array, raw: PackedVector3Array, indices: PackedInt32Array,
		config: Dictionary) -> PackedFloat32Array:
	var parent := _islands(raw, indices)
	var low := {}  # raíz de la isla → vértice más bajo
	var size := {}
	for i in coords.size():
		var root := _find(parent, i)
		size[root] = size.get(root, 0) + 1
		if not low.has(root) or coords[i].x < coords[low[root]].x:
			low[root] = i
	var azimuths := PackedFloat32Array()
	azimuths.resize(coords.size())
	for i in coords.size():
		var root := _find(parent, i)
		var small: bool = size[root] < float(config["isla_pequena"]) * coords.size()
		azimuths[i] = coords[low[root]].y if small else coords[i].y
	return azimuths


## Unión de vértices soldados por posición y por triángulos: parent[i] lleva a la raíz de su isla.
static func _islands(raw: PackedVector3Array, indices: PackedInt32Array) -> PackedInt32Array:
	var parent := PackedInt32Array()
	parent.resize(raw.size())
	var welded := {}
	for i in raw.size():
		var key := Vector3i((raw[i] / WELD).round())
		parent[i] = welded.get(key, i)
		welded[key] = parent[i]
	for t in range(0, indices.size(), 3):
		var a := _find(parent, indices[t])
		for k in [1, 2]:
			var b := _find(parent, indices[t + k])
			if b != a:
				parent[maxi(a, b)] = mini(a, b)
				a = mini(a, b)
	return parent


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


## Sector más cercano (0 = delante) y, para mezclar, el de abajo, el de arriba y la parte del de arriba.
static func _sector_of(azimuth: float, count: int) -> Vector3:
	var u := fposmod(azimuth / (360.0 / count), count)
	var low := floori(u) % count
	return Vector3(roundi(u) % count, low, u - floorf(u))


static func _start(sector: int, config: Dictionary) -> float:
	var front := maxf(0.0, cos(deg_to_rad(sector * 360.0 / int(config["sectores"]))))
	return config["inicio_lados"] + (config["inicio_frente"] - config["inicio_lados"]) * front


## {start, spacing, points (en el marco de la cabeza)} de la cadena del sector, o {} si no cuelga bastante.
static func _chain(sector: int, coords: PackedVector3Array, azimuths: PackedFloat32Array, config: Dictionary) -> Dictionary:
	var count := int(config["sectores"])
	var start := _start(sector, config)
	var members := PackedInt32Array()
	var lowest := INF
	for i in coords.size():
		if int(_sector_of(azimuths[i], count).x) == sector:
			members.append(i)
			lowest = minf(lowest, coords[i].x)
	var drop := start - lowest
	if members.is_empty() or drop < config["largo_minimo"]:
		return {}
	var step := maxf(config["separacion"], drop / (int(config["max_articulaciones"]) - 1))
	var joints := int(ceil(drop / step - 1e-6)) + 1
	var spacing := drop / (joints - 1)
	var points: Array = []  # Vector3 o null (franja vacía)
	for k in joints:
		points.append(_band_point(coords, members, start - k * spacing, spacing * 0.5, sector, count))
	_fill_gaps(points, start, spacing)
	return {"start": start, "spacing": spacing, "points": points}


## Media cilíndrica (azimut circular, radio, altura h) de los miembros a menos de half de la altura h que además
## están en el sector por su propio azimut (la parte alta de un mechón que cuelga en otro sitio no cuenta: PE.4a).
static func _band_point(coords: PackedVector3Array, members: PackedInt32Array, h: float, half: float, sector: int,
		count: int) -> Variant:
	var direction := Vector2.ZERO
	var radius := 0.0
	var n := 0
	for i in members:
		if absf(coords[i].x - h) <= half and int(_sector_of(coords[i].y, count).x) == sector:
			var angle := deg_to_rad(coords[i].y)
			direction += Vector2(sin(angle), cos(angle))
			radius += coords[i].z
			n += 1
	if n == 0:
		return null
	var unit := direction.normalized() if direction.length() > 1e-6 else Vector2(0, 1)
	return Vector3(unit.x * radius / n, h, unit.y * radius / n)


## Rellena las franjas vacías: interpola entre las vecinas con punto (o copia la única que haya), a la altura de la
## franja (start − k · spacing). La última franja siempre tiene punto (el vértice más bajo está en ella).
static func _fill_gaps(points: Array, start: float, spacing: float) -> void:
	var known := PackedInt32Array()
	for k in points.size():
		if points[k] != null:
			known.append(k)
	for k in points.size():
		if points[k] != null:
			continue
		var before := -1
		var after := -1
		for j in known:
			if j < k:
				before = j
			elif after < 0:
				after = j
		var a: Vector3 = points[before] if before >= 0 else points[after]
		var b: Vector3 = points[after] if after >= 0 else points[before]
		var t := float(k - before) / (after - before) if before >= 0 and after >= 0 else 0.0
		var p := a.lerp(b, t)
		points[k] = Vector3(p.x, start - k * spacing, p.z)


## Crea los huesos de la cadena (el 0, hijo de la cabeza) y sus binds en la piel. Devuelve sus nombres.
static func _add_bones(chain: Dictionary, sector: int, frame: Transform3D, skeleton: Skeleton3D, head: int,
		skin: Skin) -> PackedStringArray:
	var points: Array = chain["points"]
	var names := PackedStringArray()
	var binds := PackedInt32Array()
	var parent_global := skeleton.get_bone_global_rest(head)
	var parent := head
	var direction := -frame.basis.y
	for k in points.size():
		var here: Vector3 = frame * (points[k] as Vector3)
		if k + 1 < points.size():
			direction = ((frame * (points[k + 1] as Vector3)) - here).normalized()
		var global := Transform3D(_basis_along(direction, frame.basis.x), here)
		var bone_name := "%s%d_%d" % [PREFIX, sector, k]
		var bone := skeleton.add_bone(bone_name)
		skeleton.set_bone_parent(bone, parent)
		skeleton.set_bone_rest(bone, parent_global.affine_inverse() * global)
		skeleton.reset_bone_pose(bone)
		skin.add_bind(bone, global.affine_inverse())
		skin.set_bind_name(skin.get_bind_count() - 1, bone_name)
		binds.append(skin.get_bind_count() - 1)
		names.append(bone_name)
		parent = bone
		parent_global = global
	chain["binds"] = binds
	return names


## Base con Y = direction y X lo más parecida a side.
static func _basis_along(direction: Vector3, side: Vector3) -> Basis:
	if absf(direction.dot(side)) > 0.99:
		side = Vector3.BACK
	var x := (side - direction * direction.dot(side)).normalized()
	return Basis(x, direction, x.cross(direction))


## Pesos nuevos (paso 7 de la ficha) y malla rehecha con las mismas formas y material.
static func _reweight(piece: MeshInstance3D, arrays: Array, coords: PackedVector3Array, azimuths: PackedFloat32Array,
		chains: Array[Dictionary], config: Dictionary) -> void:
	var old_bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var old_weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := old_bones.size() / coords.size()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(old_bones.size())
	weights.resize(old_weights.size())
	for i in coords.size():
		var mix := _vertex_mix(coords[i].x, _sector_of(azimuths[i], chains.size()), chains, config)
		var original: float = mix.get(-1, 0.0)
		mix.erase(-1)
		for k in per:
			if old_weights[i * per + k] > 0.0:
				mix[old_bones[i * per + k]] = mix.get(old_bones[i * per + k], 0.0) + original * old_weights[i * per + k]
		_write_top(mix, bones, weights, i * per, per)
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	_replace_mesh(piece, arrays, per)


## {bind: peso} de las cadenas para un vértice; la clave -1 es la parte que se queda con los pesos originales.
static func _vertex_mix(h: float, sector: Vector3, chains: Array[Dictionary], config: Dictionary) -> Dictionary:
	var mix := {-1: 0.0}
	var sides := [[int(sector.y), 1.0 - sector.z], [(int(sector.y) + 1) % chains.size(), sector.z]]
	for side: Array in sides:
		var chain: Dictionary = chains[side[0]]
		var share: float = side[1]
		if share <= 0.0:
			continue
		if chain.is_empty() or h >= chain["start"]:
			mix[-1] += share
			continue
		var into := clampf((chain["start"] - h) / config["fundido"], 0.0, 1.0)
		mix[-1] += share * (1.0 - into)
		var binds: PackedInt32Array = chain["binds"]
		var last := binds.size() - 2  # la punta no lleva peso
		var along: float = (chain["start"] - h) / chain["spacing"] - 0.5
		var k0 := clampi(floori(along), 0, last)
		var f := clampf(along - k0, 0.0, 1.0) if along >= 0.0 and k0 < last else 0.0
		mix[binds[k0]] = mix.get(binds[k0], 0.0) + share * into * (1.0 - f)
		if f > 0.0:
			mix[binds[k0 + 1]] = mix.get(binds[k0 + 1], 0.0) + share * into * f
	return mix


## Los MAX_INFLUENCES pesos mayores, normalizados, en bones/weights a partir de offset (el resto, a 0).
static func _write_top(mix: Dictionary, bones: PackedInt32Array, weights: PackedFloat32Array, offset: int, per: int) -> void:
	var keys := mix.keys().filter(func(b: int) -> bool: return mix[b] > 0.0)
	keys.sort_custom(func(a: int, b: int) -> bool: return mix[a] > mix[b] or (mix[a] == mix[b] and a < b))
	keys = keys.slice(0, mini(MAX_INFLUENCES, per))
	var total := 0.0
	for b: int in keys:
		total += mix[b]
	for k in per:
		bones[offset + k] = keys[k] if k < keys.size() else 0
		weights[offset + k] = mix[keys[k]] / total if k < keys.size() else 0.0


## Cambia la malla por una con los arrays nuevos, las mismas formas (y sus valores) y el mismo material.
static func _replace_mesh(piece: MeshInstance3D, arrays: Array, per: int) -> void:
	var source := piece.mesh as ArrayMesh
	var values := PackedFloat32Array()
	for s in source.get_blend_shape_count():
		values.append(piece.get_blend_shape_value(s))
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = source.blend_shape_mode
	for s in source.get_blend_shape_count():
		mesh.add_blend_shape(source.get_blend_shape_name(s))
	var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, source.surface_get_blend_shape_arrays(0), {}, flags)
	mesh.surface_set_material(0, source.surface_get_material(0))
	mesh.resource_name = source.resource_name
	piece.mesh = mesh
	for s in values.size():
		piece.set_blend_shape_value(s, values[s])
