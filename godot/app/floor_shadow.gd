extends MeshInstance3D
# Paso IU.3: sombra suave bajo los pies (y = 0) que sigue a la cadera en X y Z, y rejilla opcional cada 0,5 m.
# Solo la vista: no va al .glb. El dibujo está en tema/suelo.gdshader.
# Uso: var floor := FloorShadow.new(); viewport.add_child(floor); floor.setup(skeleton); floor.set_grid(true)

const SIZE := 3.0  # m de lado del plano

var body_skeleton: Skeleton3D
var hips := -1
var grid := false


func _init() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("tema/suelo.gdshader")
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func setup(new_skeleton: Skeleton3D) -> void:
	body_skeleton = new_skeleton
	hips = body_skeleton.find_bone("Hips")
	follow()


func set_grid(on: bool) -> void:
	grid = on
	material_override.set_shader_parameter("grid", on)


## Pone el plano en el suelo, bajo la cadera.
func follow() -> void:
	if body_skeleton == null or hips < 0 or not is_inside_tree():
		return
	var at: Vector3 = body_skeleton.global_transform * body_skeleton.get_bone_global_pose(hips).origin
	global_position = Vector3(at.x, 0.0, at.z)


func _process(_delta: float) -> void:
	follow()
