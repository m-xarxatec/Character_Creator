extends MeshInstance3D
# Paso 4.6: el maniquí con las normales del estilo ilustración (StyleNormals), en vivo.
# Es una copia de la malla con las formas ya aplicadas y sin formas propias; usa el mismo esqueleto y el mismo material.
# La malla original no cambia (la usan CharacterUpdater y el exportador): solo se oculta mientras la copia vale.
# Uso (lo hace body_view.gd):
#   style.setup(species.mesh, species.skeleton)   # una vez, con el material ya puesto
#   style.show_if_current()                       # tras cada cambio: si las formas han cambiado, enseña la original
#   style.refresh()                               # al dejar quieto el deslizador: recalcula y enseña la copia
# Las normales se calculan en reposo (sin esqueleto): los deslizadores de Proporción y la pose T no las recalculan.

const MeshBaker := preload("../addons/creador/mesh_baker.gd")
const StyleNormals := preload("../addons/creador/style_normals.gd")

var source: MeshInstance3D
var last_ms := 0  ## lo que tardó el último refresh()
var _arrays: Array  # superficie de la malla original, sin formas
var _head: PackedFloat32Array
var _shape_cache := {}  # paso OPT.1: formas ya usadas, para no pedirlas todas a la malla en cada refresh
var _weights := PackedFloat32Array()  # pesos de las formas con los que se calculó la copia


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
	var vertices: PackedVector3Array = _arrays[Mesh.ARRAY_VERTEX].duplicate()
	var normals: PackedVector3Array = _arrays[Mesh.ARRAY_NORMAL].duplicate()
	MeshBaker._add_shapes(source, vertices, normals, _shape_cache)
	var arrays := _arrays.duplicate()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = StyleNormals.apply(vertices, normals, arrays[Mesh.ARRAY_INDEX], _head)
	var styled := ArrayMesh.new()
	styled.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = styled
	material_override = source.material_override
	_weights = _shape_weights()
	show_if_current()
	last_ms = Time.get_ticks_msec() - start


func _shape_weights() -> PackedFloat32Array:
	var weights := PackedFloat32Array()
	for shape in source.mesh.get_blend_shape_count():
		weights.append(source.get_blend_shape_value(shape))
	return weights
