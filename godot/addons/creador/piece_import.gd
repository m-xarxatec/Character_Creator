class_name PieceImport
extends RefCounted
## Paso 13.3c: trae un .glb ajeno como accesorio rígido (D59). Lo valida y limpia GlbInspect, lo abre GLTFDocument y lo
## aplana en «partes» (una por material: color y textura), con las transformaciones horneadas en los vértices. Lo guarda
## como un pack propio por pieza (user://packs/propia_<12 hex>/: pieza.glb y pack.json, licencia «propia»), que
## PackLibrary ya lee al escanear user://packs. Sin límites de partes, triángulos ni tamaño (D59 P3 y P5). Sin interfaz.
## Uso:
##   var r := PieceImport.read(path)   # {error, avisos, partes: [{mesh, color, textura}], caja, triangulos}
##   var parts := PieceImport.fit(r["partes"], PieceImport.scale_for(r["caja"], 0.9))   # [] si el factor no vale
##   var s := PieceImport.save(parts, {"nombre": "Espada", "autor": "", "origen": "", "especie": "humana",
##       "hueso": "socket_hand_r"}, "user://packs")   # {error, pack, pieza}

const GlbInspect := preload("glb_inspect.gd")
const PackLibrary := preload("pack_library.gd")
const PREFIX := "propia_"
const LICENSE := "propia"  # D59: siempre la misma, sin texto libre (está en PackLibrary.LICENSES)
const FILE := "pieza.glb"
const NAME_MAX := 60
const NO_AUTHOR := "Sin indicar"
const PLACE := [0, 0, 0, 0, 0, 0, 1, 1]  # la escala va horneada en los vértices
const GROW := 0.1  # el origen se respeta si cae en la caja crecida un 10 % del lado mayor
const FLAT := 1e-12  # con el determinante por debajo, la malla queda aplastada y se salta
const FLAT_NOTE := "se salta una malla aplastada (escala 0 en algún eje)"


static func read(path: String) -> Dictionary:
	var inspected := GlbInspect.read(path)
	if inspected["error"] != "":
		return _failed(inspected["error"])
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_buffer(inspected["bytes"], "", state) != OK:
		return _failed("Godot no puede abrir el archivo")
	var scene := document.generate_scene(state)
	if scene == null:
		return _failed("Godot no puede abrir el archivo")
	var warnings: Array[String] = []
	warnings.assign(inspected["avisos"])
	var groups := {}  # material → {color, textura, v, n, uv, i}, en orden de aparición
	var error := _collect(scene, Transform3D.IDENTITY, groups, warnings)
	scene.free()
	if error != "":
		return _failed(error)
	var parts := []
	var triangles := 0
	for group: Dictionary in groups.values():
		if not group["i"].is_empty():
			parts.append({"mesh": _mesh(group["v"], group["n"], group["uv"], group["i"]), "color": group["color"],
				"textura": group["textura"]})
			triangles += group["i"].size() / 3
	if parts.is_empty():
		return _failed("no tiene triángulos visibles")
	return {"error": "", "avisos": warnings, "partes": parts, "caja": box_of(parts), "triangulos": triangles}


## Factor para que el lado mayor mida target metros; con target <= 0, 1.0 (tal cual).
static func scale_for(box: AABB, target: float) -> float:
	return 1.0 if target <= 0.0 else target / box.get_longest_axis_size()


## Partes nuevas: si el origen queda lejos de la pieza, se centra; después se escala. [] si el factor no es finito y > 0.
static func fit(parts: Array, factor: float) -> Array:
	if not is_finite(factor) or factor <= 0.0 or parts.is_empty():
		return []
	var box := box_of(parts)
	var shift := Vector3.ZERO
	if not box.grow(box.get_longest_axis_size() * GROW).has_point(Vector3.ZERO):
		shift = -box.get_center()
	var out := []
	for part: Dictionary in parts:
		var arrays: Array = part["mesh"].surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for k: int in points.size():
			points[k] = (points[k] + shift) * factor
		out.append({"mesh": _mesh(points, arrays[Mesh.ARRAY_NORMAL], arrays[Mesh.ARRAY_TEX_UV], arrays[Mesh.ARRAY_INDEX]),
			"color": part["color"], "textura": part["textura"]})
	return out


## Guarda las partes como pack propio en root/<id>/ (si ya existe, se reescribe). Si algo falla, borra lo escrito.
static func save(parts: Array, meta: Dictionary, root: String) -> Dictionary:
	var name: Variant = meta.get("nombre")
	if not _good_name(name):
		return _not_saved("el nombre ha de tener de 1 a %d caracteres, sin saltos de línea" % NAME_MAX)
	if parts.is_empty():
		return _not_saved("la pieza no tiene partes")
	var id := _id(parts)
	var folder := root.path_join(id)
	DirAccess.make_dir_recursive_absolute(folder)
	var error := _write_glb(parts, folder.path_join(FILE))
	if error == "":
		error = _write_card(meta, id, folder)
	if error != "":
		for file_name: String in [FILE, "pack.json"]:
			DirAccess.remove_absolute(folder.path_join(file_name))
		DirAccess.remove_absolute(folder)
		return _not_saved(error)
	return {"error": "", "pack": id, "pieza": id}


## La caja de todas las partes.
static func box_of(parts: Array) -> AABB:
	var box := AABB()
	var first := true
	for part: Dictionary in parts:
		var part_box: AABB = part["mesh"].get_aabb()
		box = part_box if first else box.merge(part_box)
		first = false
	return box


# --- Leer ---

static func _collect(node: Node, parent: Transform3D, groups: Dictionary, warnings: Array[String]) -> String:
	var transform := parent * (node as Node3D).transform if node is Node3D else parent
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh != null:
		if absf(transform.basis.determinant()) < FLAT:
			if not FLAT_NOTE in warnings:
				warnings.append(FLAT_NOTE)
		else:
			for surface: int in instance.mesh.get_surface_count():
				if instance.mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
					var group := _group(groups, instance.get_active_material(surface) as BaseMaterial3D)
					if not _append(group, instance.mesh.surface_get_arrays(surface), transform):
						return "tiene vértices que no son números finitos"
	for child: Node in node.get_children():
		var error := _collect(child, transform, groups, warnings)
		if error != "":
			return error
	return ""


## El grupo del material (color y textura); lo crea si no está.
static func _group(groups: Dictionary, material: BaseMaterial3D) -> Dictionary:
	var color := material.albedo_color if material else Color.WHITE
	var texture := material.albedo_texture if material else null
	var key := "%s|%d" % [color, texture.get_instance_id() if texture else 0]
	if not groups.has(key):
		var image: Image = texture.get_image() if texture else null
		groups[key] = {"color": color, "textura": image, "v": PackedVector3Array(), "n": PackedVector3Array(),
			"uv": PackedVector2Array(), "i": PackedInt32Array()}
	return groups[key]


## Añade una superficie al grupo con la transformación horneada. false si un vértice no es finito.
static func _append(group: Dictionary, arrays: Array, transform: Transform3D) -> bool:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
	var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	var out_points: PackedVector3Array = group["v"]
	var out_normals: PackedVector3Array = group["n"]
	var out_uv: PackedVector2Array = group["uv"]
	var out_indices: PackedInt32Array = group["i"]
	var base := out_points.size()
	var start := out_indices.size()
	var has_normals: bool = normals is PackedVector3Array and normals.size() == points.size()
	var has_uv: bool = uv is PackedVector2Array and uv.size() == points.size()
	var normal_basis := transform.basis.inverse().transposed()
	for k: int in points.size():
		var point := transform * points[k]
		if not point.is_finite():
			return false
		out_points.append(point)
		if has_normals:
			out_normals.append((normal_basis * normals[k]).normalized())
		if group["textura"] != null:
			out_uv.append(uv[k] if has_uv else Vector2.ZERO)
	var flip := transform.basis.determinant() < 0.0  # reflejada: los triángulos se invierten para seguir mirando fuera
	var indexed := indices is PackedInt32Array
	var count: int = indices.size() if indexed else points.size()
	for k: int in range(0, count - count % 3, 3):
		var a: int = indices[k] if indexed else k
		var b: int = indices[k + 1] if indexed else k + 1
		var c: int = indices[k + 2] if indexed else k + 2
		out_indices.append(base + a)
		out_indices.append(base + (c if flip else b))
		out_indices.append(base + (b if flip else c))
	if not has_normals:
		out_normals.append_array(_area_normals(out_points, out_indices, base, start))
	group["v"] = out_points
	group["n"] = out_normals
	group["uv"] = out_uv
	group["i"] = out_indices
	return true


## Normales que faltan: media por área de las caras de cada vértice (vértices desde base; caras desde start).
static func _area_normals(points: PackedVector3Array, indices: PackedInt32Array, base: int, start: int) -> PackedVector3Array:
	var sums := PackedVector3Array()
	sums.resize(points.size() - base)
	for k: int in range(start, indices.size(), 3):
		var a := points[indices[k]]
		var face := (points[indices[k + 2]] - a).cross(points[indices[k + 1]] - a)  # en Godot, cara delantera en horario
		for j: int in 3:
			sums[indices[k + j] - base] += face
	for k: int in sums.size():
		sums[k] = sums[k].normalized()
	return sums


static func _mesh(points: PackedVector3Array, normals: PackedVector3Array, uv: Variant, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	if uv is PackedVector2Array and not uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _failed(error: String) -> Dictionary:
	return {"error": error, "avisos": [], "partes": [], "caja": AABB(), "triangulos": 0}


# --- Guardar ---

static func _good_name(name: Variant) -> bool:
	if not name is String or name.strip_edges().length() < 1 or name.strip_edges().length() > NAME_MAX:
		return false
	for k: int in name.length():
		var code: int = name.unicode_at(k)
		if code < 32 or (code >= 127 and code < 160):
			return false
	return true


## propia_ + 12 hex del sha256 del contenido (arrays, colores y PNG de las texturas): igual pieza, igual id.
static func _id(parts: Array) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	for part: Dictionary in parts:
		hashing.update(var_to_bytes(part["mesh"].surface_get_arrays(0)))
		hashing.update(var_to_bytes(part["color"]))
		if part["textura"] != null:
			hashing.update((part["textura"] as Image).save_png_to_buffer())
	return PREFIX + hashing.finish().hex_encode().substr(0, 12)


## pieza.glb: una malla m<k> por parte, con un StandardMaterial3D de su color y su textura (GLTFDocument la mete dentro).
static func _write_glb(parts: Array, path: String) -> String:
	var root := Node3D.new()
	root.name = "pieza"
	for k: int in parts.size():
		var part: Dictionary = parts[k]
		var material := StandardMaterial3D.new()
		material.albedo_color = part["color"]
		if part["textura"] != null:
			material.albedo_texture = ImageTexture.create_from_image(part["textura"])
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part["mesh"].surface_get_arrays(0))
		mesh.surface_set_material(0, material)
		var instance := MeshInstance3D.new()
		instance.name = "m%d" % k
		instance.mesh = mesh
		root.add_child(instance)
		instance.owner = root  # como GlbExporter._set_owner: sin owner, GLTFDocument no lo exporta
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(root, state)
	if error == OK:
		error = document.write_to_filesystem(state, path)
	root.free()
	return "" if error == OK else "no se puede escribir %s (%s)" % [path, error_string(error)]


## pack.json, después del .glb (lleva su sha256).
static func _write_card(meta: Dictionary, id: String, folder: String) -> String:
	var author: String = meta.get("autor", "").strip_edges() if meta.get("autor") is String else ""
	var data := {"formato": PackLibrary.FORMAT, "version": PackLibrary.VERSION, "id": id,
		"nombre": (meta["nombre"] as String).strip_edges(), "autor": author if author != "" else NO_AUTHOR,
		"licencia": LICENSE, "origen": meta.get("origen", "") if meta.get("origen") is String else "",
		"piezas": [{"id": id, "nombre": (meta["nombre"] as String).strip_edges(), "tipo": "accesorio",
			"ranura": "accesorio", "especies": [meta.get("especie", "") if meta.get("especie") is String else ""],
			"sigue_al_cuerpo": false, "archivo": FILE, "sha256": FileAccess.get_sha256(folder.path_join(FILE)),
			"anclaje": {"hueso": meta.get("hueso", "") if meta.get("hueso") is String else "", "transform": PLACE}}]}
	var file := FileAccess.open(folder.path_join("pack.json"), FileAccess.WRITE)
	if file == null:
		return "no se puede escribir pack.json en %s" % folder
	file.store_string(JSON.stringify(data, " "))
	file.close()
	return ""


static func _not_saved(error: String) -> Dictionary:
	return {"error": error, "pack": "", "pieza": ""}
