extends MeshInstance3D
# Paso 4.6: el maniquí con las normales del estilo ilustración (StyleNormals), en vivo.
# Es una copia de la malla con las formas ya aplicadas y sin formas propias; usa el mismo esqueleto y el mismo material.
# La malla original no cambia (la usan CharacterUpdater y el exportador): solo se oculta mientras la copia vale.
# Uso (lo hace body_view.gd):
#   style.setup(species.mesh, species.skeleton)   # una vez, con el material ya puesto
#   style.show_if_current()                       # tras cada cambio: si las formas han cambiado, enseña la original
#   style.refresh()                               # recalcula y enseña la copia (al cargar)
#   style.refresh_async()                         # lo mismo en un hilo (paso OPT.2: al dejar quieto el deslizador)
# Las normales se calculan en reposo (sin esqueleto): los deslizadores de Proporción y la pose T no las recalculan.

const MeshBaker := preload("../addons/creador/mesh_baker.gd")
const StyleNormals := preload("../addons/creador/style_normals.gd")

var source: MeshInstance3D
var last_ms := 0  ## lo que tardó el último refresh()
var _arrays: Array  # superficie de la malla original, sin formas
var _head: PackedFloat32Array
var _shape_cache := {}  # paso OPT.1: formas ya usadas, para no pedirlas todas a la malla en cada refresh
var _weights := PackedFloat32Array()  # pesos de las formas con los que se calculó la copia
var _generation := 0  # paso OPT.2: el último refresh_async; los resultados de uno anterior se tiran
var _tasks: Array[Array] = []  # tareas del hilo aún sin recoger (se esperan al salir)


func setup(source_mesh: MeshInstance3D, source_skeleton: Skeleton3D) -> void:
	source = source_mesh
	_arrays = source.mesh.surface_get_arrays(0)
	_arrays[Mesh.ARRAY_TANGENT] = null  # no casarían con las normales nuevas (sin mapas de normales no hacen falta)
	_head = StyleNormals.head_weights(_arrays, source.skin, source_skeleton)
	skin = source.skin
	transform = source.transform
	source.get_parent().add_child(self)
	skeleton = source.skeleton
	visible = false


## Enseña la copia si sigue valiendo (mismas formas); si no, la malla original. Devuelve si la copia vale.
func show_if_current() -> bool:
	var current := _weights == _shape_weights()
	visible = current
	source.visible = not current
	return current


func refresh() -> void:
	var start := Time.get_ticks_msec()
	_generation += 1  # un refresh_async que aún no ha vuelto ya no vale
	var vertices: PackedVector3Array = _arrays[Mesh.ARRAY_VERTEX].duplicate()
	var normals: PackedVector3Array = _arrays[Mesh.ARRAY_NORMAL].duplicate()
	MeshBaker._add_shapes(source, vertices, normals, _shape_cache)
	_set_mesh(vertices, StyleNormals.apply(vertices, normals, _arrays[Mesh.ARRAY_INDEX], _head), _shape_weights())
	last_ms = Time.get_ticks_msec() - start


## Paso OPT.2: como refresh, pero lo pesado (sumar las formas y StyleNormals) va en un hilo y la ventana no se congela.
## En el hilo principal solo quedan leer los pesos y poner la malla; las formas que falten en la caché las pide el hilo.
func refresh_async() -> void:
	var start := Time.get_ticks_msec()
	_generation += 1
	var generation := _generation
	var active := MeshBaker.active_shapes(source)
	var shapes := {}  # solo de la tarea: el hilo añade las que pida y _finish_async las guarda en la caché
	var missing: Array[int] = []
	for shape: int in active:
		if _shape_cache.has(shape):
			shapes[shape] = _shape_cache[shape]
		else:
			missing.append(shape)
	var array_mesh := source.mesh as ArrayMesh
	var weights := _shape_weights()
	var base_vertices: PackedVector3Array = _arrays[Mesh.ARRAY_VERTEX]
	var base_normals: PackedVector3Array = _arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = _arrays[Mesh.ARRAY_INDEX]
	var head := _head
	var task := [-1]
	_tasks.append(task)
	task[0] = WorkerThreadPool.add_task(func() -> void:
		var fetched := {}
		if not missing.is_empty():  # comprobado: desde un hilo da lo mismo y casi no para la ventana (OPT.2)
			var all := array_mesh.surface_get_blend_shape_arrays(0)
			for shape: int in missing:
				fetched[shape] = [all[shape][Mesh.ARRAY_VERTEX], all[shape][Mesh.ARRAY_NORMAL]]
			shapes.merge(fetched)
		var vertices := base_vertices.duplicate()
		var normals := base_normals.duplicate()
		MeshBaker.add_shape_arrays(vertices, normals, active, shapes)
		var styled := StyleNormals.apply(vertices, normals, indices, head)
		_finish_async.call_deferred(task, generation, vertices, styled, weights, start, fetched))


func _finish_async(task: Array, generation: int, vertices: PackedVector3Array, normals: PackedVector3Array,
		weights: PackedFloat32Array, start: int, fetched: Dictionary) -> void:
	WorkerThreadPool.wait_for_task_completion(task[0])  # ya terminó: solo libera la tarea
	_tasks.erase(task)
	_shape_cache.merge(fetched)
	if generation != _generation:
		return
	_set_mesh(vertices, normals, weights)
	last_ms = Time.get_ticks_msec() - start


func _exit_tree() -> void:
	for task: Array in _tasks:
		WorkerThreadPool.wait_for_task_completion(task[0])
	_tasks.clear()


func _set_mesh(vertices: PackedVector3Array, normals: PackedVector3Array, weights: PackedFloat32Array) -> void:
	var arrays := _arrays.duplicate()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var styled := ArrayMesh.new()
	styled.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = styled
	material_override = source.material_override
	_weights = weights
	show_if_current()


func _shape_weights() -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	for shape in source.mesh.get_blend_shape_count():
		weights.append(source.get_blend_shape_value(shape))
	return weights
