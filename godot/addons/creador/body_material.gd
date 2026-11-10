class_name BodyMaterial
extends RefCounted
## Material del cuerpo (body.gdshader) y el interruptor de la prenda base.
##
## Uso:
##   BodyMaterial.apply(species.mesh)
##   BodyMaterial.set_garment_visible(species.mesh, false)
## El interruptor es un parámetro del material: el exportador (paso 3.6) lo lee con is_garment_visible().

const SHADER := preload("body.gdshader")


static func apply(mesh: MeshInstance3D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("show_garment", true)
	mesh.material_override = material
	return material


static func set_garment_visible(mesh: MeshInstance3D, visible: bool) -> void:
	(mesh.material_override as ShaderMaterial).set_shader_parameter("show_garment", visible)


static func is_garment_visible(mesh: MeshInstance3D) -> bool:
	return (mesh.material_override as ShaderMaterial).get_shader_parameter("show_garment")
