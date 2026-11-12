class_name CharacterUpdater
extends RefCounted
## update_character: lo único que cambia el personaje del editor. Aplica siempre, en este orden:
## formas → reajuste del esqueleto → escala de Proporción → pose base.
##
## Uso:
##   var updater := CharacterUpdater.new(species)           # justo después de cargar la especie (guarda el reposo original)
##   var rejected := updater.update(values, false)          # values: Forma y Proporción juntos, como en el preset
##   updater.update(values, true)                           # la misma, con la pose T (false = pose A, el reposo)
## Es una función de estado completo: lo que falta en values vale neutro y el resultado no depende de las llamadas
## anteriores (llamarla dos veces seguidas, o venir de otro cuerpo o de la pose T, da lo mismo).
## Devuelve las claves que no aplicó, en una lista: desconocidas o con un valor no válido (NaN, infinito).
## El reajuste pisa la posición y el giro de la pose (no la escala): por eso la pose base va después de él.
## La pose T lee la escala de la pose: por eso la pose base va después de la escala y no depende de la llamada anterior.

const Proportions := preload("proportions.gd")
const ShapeWeights := preload("shape_weights.gd")
const SkeletonRefit := preload("skeleton_refit.gd")
const TPose := preload("t_pose.gd")

var species  # SpeciesData
var base: Dictionary


func _init(loaded_species) -> void:
	species = loaded_species
	base = SkeletonRefit.capture_base(species.skeleton)


func update(values: Dictionary, pose_t: bool) -> Array[String]:
	var shape_values: Dictionary = ShapeWeights.neutral_values(species.sliders)
	var scale_values: Dictionary = Proportions.neutral_values(species.sliders)
	var rejected: Array[String] = []
	for key: String in values:
		var target: Dictionary = shape_values if shape_values.has(key) else scale_values
		var is_number: bool = typeof(values[key]) == TYPE_FLOAT or typeof(values[key]) == TYPE_INT
		if not is_number or not ShapeWeights.set_value(target, key, values[key], false):
			rejected.append(key)
	var weights: Dictionary = ShapeWeights.weights(shape_values, ShapeWeights.shape_names(species.mesh.mesh))
	ShapeWeights.apply(species.mesh, weights)
	SkeletonRefit.apply(species.skeleton, species.mesh.skin, species.joints, weights, base)
	Proportions.apply(species.skeleton, Proportions.scales(scale_values, species.sliders))
	if pose_t:
		TPose.apply(species.skeleton)
	return rejected
