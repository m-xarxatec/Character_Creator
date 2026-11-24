class_name EyeMesh
extends RefCounted
## Pasos AC.3c, AC.4 y AC.6a: las capas del ojo, sobre la bolsa de la cara, y sus líneas, con los datos de ojos.json
## (datos/FORMATO.md). Sin interfaz.
##
## Uso:
##   for eye in EyeMesh.build(species.mesh, species.skeleton, species.eyes):   # cuelgan del esqueleto; [] sin ojos.json
##       updater.pieces.append(eye)
## Cada ojo es una malla con los mismos vértices, huesos, pesos y formas que la bolsa del cuerpo, subida a la membrana
## del lazo (`elevacion`), con una sola normal.
## Una malla por ojo: el blanco es su material y el iris (con los brillos, AC.5), su `next_pass`.
## AC.6a: detrás de los dos ojos, tres tiras por ojo (`linea_*`, `linea_inferior_*` y `pliegue_*`, eye_line.gdshader).
## Cada vértice de una tira es la mezcla baricéntrica de 3 vértices del cuerpo más un desplazamiento fijo (de Blender).

const MeshBaker := preload("mesh_baker.gd")
const BodyPiece := preload("body_piece.gd")
const SHADER := preload("eye_layers.gdshader")
const LINE_SHADER := preload("eye_line.gdshader")
const STRIPS := {"tira_superior": ["linea", 0], "tira_inferior": ["linea_inferior", 2], "pliegue": ["pliegue", 1]}  # nodo, modo
const LINE_PULL := 0.00018  # metros: las líneas, por delante de las capas
const LINE_PRIORITY := 3  # después del blanco (0), el iris y los brillos (1)
const PULLS: Array[float] = [0.00005, 0.00010, 0.00012]  # metros: cada capa, un poco más cerca de la cámara
const MIN_DELTA := 0.00001  # metros: una forma que mueve menos la bolsa no se copia (como BodyDerived)
const IRIS_A := 0.0061  # metros: semieje horizontal (AC.4a)
const IRIS_LOW := 1.15  # semieje vertical de la mitad de abajo, en unidades de IRIS_A
const IRIS_GAP := 0.0006  # metros: del párpado de abajo al iris
const IRIS_COVER := 0.30  # parte del iris tapada por el párpado de arriba (AC.4a)
const LID_LINE := 0.0018156  # metros: lo que la línea entra en el ojo, 85 % de w = 2,136 mm (AC.4a); no depende de la cobertura

static var _iris_shader: Shader


static func build(body: MeshInstance3D, skeleton: Skeleton3D, eyes: Dictionary) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if eyes.is_empty():
		return out
	var arrays := body.mesh.surface_get_arrays(0)
	var shapes := MeshBaker.shape_arrays(body.mesh)
	for side: String in ["l", "r"]:
		var mesh := _eye_mesh(body, arrays, shapes, eyes[side])
		var node := MeshInstance3D.new()
		node.name = "ojo_%s" % side
		node.mesh = mesh
		node.skin = body.skin.duplicate()
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.material_override = layer_material(0, {})
		node.material_override.next_pass = layer_material(1, iris_values(eyes[side]))
		BodyPiece.hang(node, skeleton)
		out.append(node)
	for side: String in ["l", "r"]:
		for key: String in STRIPS:
			if eyes[side].has(key):
				var strip := MeshInstance3D.new()
				strip.name = "%s_%s" % [STRIPS[key][0], side]
				strip.mesh = _strip_mesh(body, arrays, shapes, eyes[side], eyes[side][key])
				strip.skin = body.skin.duplicate()
				strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				strip.material_override = line_material(STRIPS[key][1], eyes[side][key]["largo"])
				BodyPiece.hang(strip, skeleton)
				out.append(strip)
	return out


## Material de una línea: modo 0 línea de arriba con pestañas, 1 pliegue, 2 línea de abajo; largo del arco en metros.
static func line_material(mode: int, arc_length: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = LINE_SHADER
	material.render_priority = LINE_PRIORITY
	material.set_shader_parameter("mode", mode)
	material.set_shader_parameter("depth_pull", LINE_PULL)
	material.set_shader_parameter("arc_length", arc_length)
	return material


static func layer_material(layer: int, values: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER if layer == 0 else _transparent_shader()
	material.render_priority = layer
	material.set_shader_parameter("depth_pull", PULLS[layer])
	for key: String in values:
		material.set_shader_parameter(key, values[key])
	return material


## Uniforms del iris de un ojo: el borde inferior y la línea no dependen de la cobertura.
static func iris_values(eye: Dictionary, cover: float = IRIS_COVER) -> Dictionary:
	var y_bottom := _arc_y(eye, "arco_inferior") + IRIS_GAP
	var y_line := _arc_y(eye, "arco_superior") - LID_LINE
	var height := (y_line - y_bottom) / (1.0 - cover)
	return {"iris_center": Vector2(0.0, y_bottom + height / 2.0), "iris_axes": Vector2(IRIS_A, height / 2.0),
		"low_b": IRIS_LOW * IRIS_A, "y_bottom": y_bottom, "y_line": y_line}


static func _transparent_shader() -> Shader:
	if _iris_shader == null:
		_iris_shader = Shader.new()
		_iris_shader.code = SHADER.code.replace("shader_type spatial;", "shader_type spatial;\n#define EYE_IRIS")
	return _iris_shader


## Altura del arco (posiciones dentro de `lazo`) en el eje del ojo, x = 0.
static func _arc_y(eye: Dictionary, arc: String) -> float:
	var points := PackedVector2Array()
	for k: float in eye[arc]:
		var uv: Array = eye["uv"][eye["bolsa"].find(eye["lazo"][int(k)])]
		points.append(Vector2(uv[0], uv[1]))
	for n in points.size() - 1:
		if points[n].x * points[n + 1].x <= 0.0 and points[n].x != points[n + 1].x:
			return lerpf(points[n].y, points[n + 1].y, -points[n].x / (points[n + 1].x - points[n].x))
	return 0.0


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


## Malla de una tira: rejilla de columnas × `filas`, con los huesos y pesos mezclados (los 4 mayores, suman 1) y las
## formas que mueven alguno de sus vértices de origen. Normal única: la del ojo.
static func _strip_mesh(body: MeshInstance3D, arrays: Array, shapes: Array, eye: Dictionary, strip: Dictionary) -> ArrayMesh:
	var ids := PackedInt32Array()
	var bary := PackedVector3Array()
	var offsets := PackedVector3Array()
	var uvs := PackedVector2Array()
	for n in strip["ids"].size():
		for k in 3:
			ids.append(int(strip["ids"][n][k]))
		bary.append(Vector3(strip["bary"][n][0], strip["bary"][n][1], strip["bary"][n][2]))
		offsets.append(Vector3(strip["offset"][n][0], strip["offset"][n][1], strip["offset"][n][2]))
		uvs.append(Vector2(strip["uv"][n][0], strip["uv"][n][1]))
	var normals := PackedVector3Array()
	normals.resize(bary.size())
	normals.fill(Vector3(eye["normal"][0], eye["normal"][1], eye["normal"][2]))
	var surface := []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = _mixed(arrays[Mesh.ARRAY_VERTEX], ids, bary, offsets)
	surface[Mesh.ARRAY_NORMAL] = normals
	surface[Mesh.ARRAY_TEX_UV] = uvs
	var skinning := _mixed_weights(arrays[Mesh.ARRAY_BONES], arrays[Mesh.ARRAY_WEIGHTS], ids, bary)
	surface[Mesh.ARRAY_BONES] = skinning[0]
	surface[Mesh.ARRAY_WEIGHTS] = skinning[1]
	surface[Mesh.ARRAY_INDEX] = _grid(bary.size() / int(strip["filas"]), int(strip["filas"]))
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = (body.mesh as ArrayMesh).blend_shape_mode
	var kept := []
	for s in shapes.size():
		if not _moves(shapes[s][Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_VERTEX], ids):
			continue
		var shape := []
		shape.resize(Mesh.ARRAY_MAX)
		shape[Mesh.ARRAY_VERTEX] = _mixed(shapes[s][Mesh.ARRAY_VERTEX], ids, bary, offsets)  # posiciones absolutas
		shape[Mesh.ARRAY_NORMAL] = normals
		kept.append(shape)
		mesh.add_blend_shape(body.mesh.get_blend_shape_name(s))
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface, kept)
	return mesh


static func _mixed(vertices: PackedVector3Array, ids: PackedInt32Array, bary: PackedVector3Array,
		offsets: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(bary.size())
	for n in bary.size():
		var b := bary[n]
		out[n] = vertices[ids[3 * n]] * b.x + vertices[ids[3 * n + 1]] * b.y + vertices[ids[3 * n + 2]] * b.z + offsets[n]
	return out


## [huesos, pesos]: los de los 3 vértices mezclados por sus baricéntricas; los 4 mayores, divididos por su suma.
static func _mixed_weights(bones: PackedInt32Array, weights: PackedFloat32Array, ids: PackedInt32Array,
		bary: PackedVector3Array) -> Array:
	var out_bones := PackedInt32Array()
	var out_weights := PackedFloat32Array()
	for n in bary.size():
		var mixed := {}
		for k in 3:
			for b in 4:
				var bone := bones[ids[3 * n + k] * 4 + b]
				mixed[bone] = mixed.get(bone, 0.0) + bary[n][k] * weights[ids[3 * n + k] * 4 + b]
		var keys := mixed.keys()
		keys.sort_custom(func(x: int, y: int) -> bool: return mixed[x] > mixed[y])
		var total := 0.0
		for b in mini(4, keys.size()):
			total += mixed[keys[b]]
		for b in 4:
			out_bones.append(keys[b] if b < keys.size() else 0)
			out_weights.append(mixed[keys[b]] / total if b < keys.size() else 0.0)
	return [out_bones, out_weights]


## Dos triángulos por celda de la rejilla (vértice = columna × filas + fila).
static func _grid(columns: int, rows: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in columns - 1:
		for r in rows - 1:
			var a := k * rows + r
			out.append_array(PackedInt32Array([a, a + rows, a + 1, a + 1, a + rows, a + rows + 1]))
	return out


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
