class_name EyeMesh
extends RefCounted
## Paso AC.3c: las capas del ojo, sobre la bolsa de la cara, con los datos de ojos.json (datos/FORMATO.md). Sin interfaz.
##
## Uso:
##   for eye in EyeMesh.build(species.mesh, species.skeleton, species.eyes):   # cuelgan del esqueleto; [] sin ojos.json
##       updater.pieces.append(eye)
## Cada ojo es una malla con los mismos vértices, huesos, pesos y formas que la bolsa del cuerpo, subida a la membrana
## del lazo (`elevacion`), con una sola normal. Hoy solo la capa 0 (blanco); AC.4 y AC.5 añaden iris y brillos.

const MeshBaker := preload("mesh_baker.gd")
const BodyPiece := preload("body_piece.gd")
const SHADER := preload("eye_layers.gdshader")
const LAYERS: Array[int] = [0]
const PULLS: Array[float] = [0.00005, 0.00010, 0.00012]  # metros: cada capa, un poco más cerca de la cámara
const MIN_DELTA := 0.00001  # metros: una forma que mueve menos la bolsa no se copia (como BodyDerived)


static func build(body: MeshInstance3D, skeleton: Skeleton3D, eyes: Dictionary) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if eyes.is_empty():
		return out
	var arrays := body.mesh.surface_get_arrays(0)
	var shapes := MeshBaker.shape_arrays(body.mesh)
	for side: String in ["l", "r"]:
		var mesh := _eye_mesh(body, arrays, shapes, eyes[side])
		for layer in LAYERS:
			var node := MeshInstance3D.new()
			node.name = "ojo_%s_%d" % [side, layer]
			node.mesh = mesh
			node.skin = body.skin.duplicate()
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.material_override = layer_material(layer, {})
			BodyPiece.hang(node, skeleton)
			out.append(node)
	return out


static func layer_material(layer: int, values: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = layer
	material.set_shader_parameter("depth_pull", PULLS[layer])
	for key: String in values:
		material.set_shader_parameter(key, values[key])
	return material


static func _eye_mesh(body: MeshInstance3D, arrays: Array, shapes: Array, eye: Dictionary) -> ArrayMesh:
	var order := PackedInt32Array()
	var remap := {}
	for v: float in eye["bolsa"]:
		remap[int(v)] = order.size()
		order.append(int(v))
	var lifts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var heights := PackedVector2Array()
	for n in order.size():
		lifts.append(Vector3(0.0, 0.0, eye["elevacion"][n]))
		uvs.append(Vector2(eye["uv"][n][0], eye["uv"][n][1]))
		heights.append(Vector2(eye["altura"][n], 0.0))
	var normal := Vector3(eye["normal"][0], eye["normal"][1], eye["normal"][2])
	var normals := PackedVector3Array()
	normals.resize(order.size())
	normals.fill(normal)
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = _moved(arrays[Mesh.ARRAY_VERTEX], order, lifts)
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_TEX_UV] = uvs
	surface[Mesh.ARRAY_TEX_UV2] = heights
	surface[Mesh.ARRAY_BONES] = _per_vertex(arrays[Mesh.ARRAY_BONES], order, 4)
	surface[Mesh.ARRAY_WEIGHTS] = _per_vertex(arrays[Mesh.ARRAY_WEIGHTS], order, 4)
	surface[Mesh.ARRAY_INDEX] = _triangles(arrays[Mesh.ARRAY_INDEX], remap)
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = (body.mesh as ArrayMesh).blend_shape_mode
	var kept := []
	for s in shapes.size():
		if not _moves(shapes[s][Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_VERTEX], order):
			continue  # en Android no llegan las formas de Ojos: solo se copian las que existen
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = _moved(shapes[s][Mesh.ARRAY_VERTEX], order, lifts)
		shape[Mesh.ARRAY_NORMAL] = normals
		kept.append(shape)
		mesh.add_blend_shape(body.mesh.get_blend_shape_name(s))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface, kept)
	return mesh


static func _moved(vertices: PackedVector3Array, order: PackedInt32Array, lifts: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(order.size())
	for n in order.size():
		out[n] = vertices[order[n]] + lifts[n]
	return out


static func _moves(shape: PackedVector3Array, base: PackedVector3Array, order: PackedInt32Array) -> bool:
	for v in order:
		if (shape[v] - base[v]).length() > MIN_DELTA:
			return true
	return false


static func _per_vertex(values: Variant, order: PackedInt32Array, count: int) -> Variant:
	var out: Variant = values.duplicate()
	out.resize(order.size() * count)
	for n in order.size():
		for k in count:
			out[n * count + k] = values[order[n] * count + k]
	return out


## Los triángulos con sus 3 vértices en la bolsa, con los índices de la malla del ojo.
static func _triangles(indices: PackedInt32Array, remap: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		if remap.has(indices[t]) and remap.has(indices[t + 1]) and remap.has(indices[t + 2]):
			out.append(remap[indices[t]])
			out.append(remap[indices[t + 1]])
			out.append(remap[indices[t + 2]])
	return out
