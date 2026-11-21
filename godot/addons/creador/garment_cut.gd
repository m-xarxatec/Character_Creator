class_name GarmentCut
extends RefCounted
## Paso AB.5: prendas recortadas de una pieza que sigue al cuerpo (las mallas, tights.glb): camiseta, pantalón, top…
## Cada vértice de la pieza, en reposo, cae en una región por el hueso que más lo mueve (brazo, pierna o torso) y tiene
## una coordenada de corte de 0 a 1: a lo largo del brazo (hombro → muñeca), de la pierna (cadera → tobillo) o del torso
## (altura de la cadera → la del cuello). La prenda se queda con los triángulos cuyos tres vértices pasan las reglas:
##   {"brazos": t máx. (−1 = sin mangas), "piernas": t máx. (−1 = sin perneras), "torso": [mín., máx.]}
## Las formas, huesos y pesos se copian (BodyDerived.subset): sigue al cuerpo igual que la pieza entera.
## Con «quitar»: [[x0, y0, z0, x1, y1, z1], …] (metros, malla en reposo; p. ej. el flequillo delante de los ojos), se
## quitan los vértices dentro de alguna caja y no se miran brazos, piernas ni torso.
## Uso:
##   var rules := {"brazos": 0.35, "piernas": -1, "torso": [0.0, 1.0]}  # camiseta de manga corta
##   var shirt := GarmentCut.cut(tights_mesh, species.skeleton, species.joints, rules)
## Las articulaciones son las del cuerpo neutro (species.joints, articulaciones.json): las de la malla de la pieza, que
## está en reposo sin formas; el reposo del esqueleto ya puede estar reajustado al cuerpo de ahora.

const BodyDerived := preload("body_derived.gd")
const ARMS := ["UpperArm", "LowerArm", "Hand", "Thumb", "Index", "Middle", "Ring", "Little"]  # tras Left/Right
const LEGS := ["UpperLeg", "LowerLeg", "Foot", "Toes"]


static func cut(piece: MeshInstance3D, skeleton: Skeleton3D, joints: Dictionary, rules: Dictionary) -> MeshInstance3D:
	var arrays := piece.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / vertices.size()
	var keep := PackedByteArray()
	keep.resize(vertices.size())
	var hips := _joint(joints, "Hips").y
	var neck := _joint(joints, "Neck").y
	var torso: Array = rules.get("torso", [0.0, 1.0])
	if rules.has("quitar"):
		for i in vertices.size():
			keep[i] = 0 if rules["quitar"].any(func(box: Array) -> bool: return _in_box(vertices[i], box)) else 1
		return BodyDerived.subset(piece, keep, 0.0)
	for i in vertices.size():
		var bone_name := _main_bone(piece.skin, skeleton, bones, weights, i, per)
		var side := "Left" if bone_name.begins_with("Left") else "Right"
		var limb := bone_name.trim_prefix(side)
		if bone_name.begins_with(side) and ARMS.any(func(part: String) -> bool: return limb.begins_with(part)):
			var t := _along(vertices[i], _joint(joints, side + "UpperArm"), _joint(joints, side + "Hand"))
			keep[i] = 1 if t <= rules.get("brazos", -1.0) else 0
		elif bone_name.begins_with(side) and LEGS.any(func(part: String) -> bool: return limb.begins_with(part)):
			var t := _along(vertices[i], _joint(joints, side + "UpperLeg"), _joint(joints, side + "Foot"))
			keep[i] = 1 if t <= rules.get("piernas", -1.0) else 0
		else:
			var f := (vertices[i].y - hips) / maxf(neck - hips, 0.001)
			keep[i] = 1 if f >= torso[0] and f <= torso[1] else 0
	return BodyDerived.subset(piece, keep, 0.0)


## El hueso con más peso en el vértice i.
static func _main_bone(skin: Skin, skeleton: Skeleton3D, bones: PackedInt32Array, weights: PackedFloat32Array, i: int,
		per: int) -> String:
	var best := 0
	for k in per:
		if weights[i * per + k] > weights[i * per + best]:
			best = k
	return skeleton.get_bone_name(skin.get_bind_bone(bones[i * per + best]))


## Cabeza del hueso en el cuerpo neutro (articulaciones.json: espacio de la malla).
static func _joint(joints: Dictionary, bone_name: String) -> Vector3:
	var head: Array = joints[bone_name]["head"]
	return Vector3(head[0], head[1], head[2])


static func _in_box(p: Vector3, box: Array) -> bool:
	return p.x >= box[0] and p.y >= box[1] and p.z >= box[2] and p.x <= box[3] and p.y <= box[4] and p.z <= box[5]


## Dónde cae p a lo largo del segmento a → b: 0 en a, 1 en b (puede salirse de 0–1).
static func _along(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	return (p - a).dot(ab) / maxf(ab.length_squared(), 0.000001)
