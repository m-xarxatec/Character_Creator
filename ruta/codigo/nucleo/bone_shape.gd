class_name BoneShape
extends RefCounted
## Largo y grosor de un hueso por separado, sin que lo hereden los hijos (paso 16.1; ruta/ARQUITECTURA.md §2.2).
##
## Uso (justo después de SkeletonRefit.apply, que deja reposo y bind poses «limpios», y antes de Proportions.apply):
##   BoneShape.apply(skeleton, skin, {"LeftUpperArm": Vector2(1.5, 1.2)}, {"LeftUpperArm": tail - head})
##   # Vector2(largo, grosor): 1 = sin cambio. El eje es cabeza -> cola del hueso, en el espacio del esqueleto, en reposo.
## Qué hace, para cada hueso con forma:
## - Su bind pose pasa a ser S × inversa(reposo global), con S = escala `largo` a lo largo del eje y `grosor` en las
##   dos direcciones perpendiculares, en el espacio local del hueso. Sus vértices se estiran alrededor de su cabeza.
##   Como S va en la bind pose y no en la pose, los hijos NO la heredan y nada se cizalla al girar.
## - Cada hijo se traslada para seguir pegado a la malla: su cabeza va a donde S lleva ese punto. Todos sus
##   descendientes se trasladan lo mismo (sin escala). Sus bind poses no cambian.
## No toca los pesos, ni el giro de ningún hueso, ni la escala de la pose (Proporción se combina sin más).
## NO es idempotente: aplica sobre el reposo que encuentra. Hay que llamarla una vez por cada SkeletonRefit.apply.
## Normales: con largo != grosor, la matriz del hueso ya no conserva ángulos; quien hornee normales debe usar
## normal_basis() (la inversa traspuesta). En vivo, la tarjeta gráfica no lo hace: la luz es algo inexacta al editar.
## ESTADO: diseño razonado, SIN EJECUTAR todavía. La prueba probar_forma_hueso.gd decide si vale.

const MIN_FACTOR := 0.2
const MAX_FACTOR := 5.0
const EPS := 0.000001


## shapes: {hueso: Vector2(largo, grosor)}. axes: {hueso: Vector3}. Un hueso sin eje, o con un factor no finito, se ignora.
## Devuelve los nombres de los huesos ignorados.
static func apply(skeleton: Skeleton3D, skin: Skin, shapes: Dictionary, axes: Dictionary) -> Array[String]:
	var ignored: Array[String] = []
	var originals: Array[Transform3D] = []  # reposo global antes de tocar nada
	var world_scales: Array[Basis] = []  # la escala del hueso vista desde el mundo
	var local_scales: Array[Basis] = []  # la misma, en el espacio local del hueso (va a la bind pose)
	var shifts: Array[Vector3] = []  # traslación acumulada de cada hueso
	for i in skeleton.get_bone_count():  # el padre siempre va antes que el hijo
		var rest := skeleton.get_bone_global_rest(i)
		var bone := skeleton.get_bone_name(i)
		var world_scale := Basis.IDENTITY
		var local_scale := Basis.IDENTITY
		if shapes.has(bone):
			var shape: Vector2 = shapes[bone]
			var axis: Vector3 = axes.get(bone, Vector3.ZERO)
			if axis.length() < EPS or not is_finite(shape.x) or not is_finite(shape.y):
				ignored.append(bone)
			else:
				var length := clampf(shape.x, MIN_FACTOR, MAX_FACTOR)
				var thickness := clampf(shape.y, MIN_FACTOR, MAX_FACTOR)
				world_scale = scale_along(axis.normalized(), length, thickness)
				local_scale = scale_along((rest.basis.orthonormalized().inverse() * axis).normalized(), length, thickness)
		originals.append(rest)
		world_scales.append(world_scale)
		local_scales.append(local_scale)
		var parent := skeleton.get_bone_parent(i)
		if parent < 0:
			shifts.append(Vector3.ZERO)
		else:
			var offset := rest.origin - originals[parent].origin  # de la cabeza del padre a la de este hueso
			shifts.append(shifts[parent] + world_scales[parent] * offset - offset)
	var moved: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		moved.append(Transform3D(originals[i].basis, originals[i].origin + shifts[i]))
		var parent := skeleton.get_bone_parent(i)
		var local := moved[i] if parent < 0 else moved[parent].affine_inverse() * moved[i]
		skeleton.set_bone_rest(i, local)
		skeleton.set_bone_pose_position(i, local.origin)  # el giro y la escala de la pose no se tocan
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(b))
		if bone >= 0:
			skin.set_bind_pose(b, Transform3D(local_scales[bone], Vector3.ZERO) * originals[bone].affine_inverse())
	return ignored


## Escala `along` en la dirección axis (unitaria) y `across` en las perpendiculares: across·I + (along − across)·axis·axisᵀ.
static func scale_along(axis: Vector3, along: float, across: float) -> Basis:
	var extra := along - across
	return Basis(
		Vector3(across, 0.0, 0.0) + axis * (extra * axis.x),
		Vector3(0.0, across, 0.0) + axis * (extra * axis.y),
		Vector3(0.0, 0.0, across) + axis * (extra * axis.z))


## Con qué matriz transformar una normal cuando la del vértice es `matrix` (puede tener escala no uniforme).
## El resultado hay que normalizarlo.
static func normal_basis(matrix: Basis) -> Basis:
	return matrix.inverse().transposed()
