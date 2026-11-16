class_name AnimationSet
extends RefCounted
## Carga un juego de animaciones de datos/animaciones/ (ver datos/FORMATO.md): un .json con los clips y la tabla
## de huesos, y un .glb con el esqueleto animado (la fuente).
##
## Uso:
##   var animations := AnimationSet.new()
##   if animations.load_file("…/datos/animaciones/humanoide.json"): push_error(animations.error)
##   else: add_child(animations.scene)        # el reproductor necesita estar en el árbol; la escena no se ve
##   animations.play("caminar")               # id del clip; siempre en bucle (son animaciones de prueba)
##   animations.seek(0.5)                     # o animations.advance(delta) en cada fotograma
##   animations.pose_turns("sentadilla")      # giros de una pose fija, para StaticPose ({} si no existe)
## La fuente no se muestra (se le quita la malla). Para pasar su pose a un personaje: PoseRetarget.
## Abre el .glb con GLTFDocument (en tiempo de ejecución): vale en el editor y dentro de un juego.

const VERSION := 1

var error := ""
var scene: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var clips: Array  ## [{id, nombre, animation}], en el orden del archivo
var poses: Array  ## [{id, nombre, bones: {hueso: [x, y, z] en grados}}]: poses fijas (paso 5.2)
var feet: Array  ## huesos del personaje que se apoyan en el suelo
var bones: Dictionary  ## hueso del personaje → hueso de la fuente
var hips: String  ## hueso del personaje que además se desplaza


## Devuelve el error ("" si todo va bien); también queda en error.
func load_file(path: String) -> String:
	error = _load(path)
	if error and scene:
		scene.free()
		scene = null
	return error


func clip_ids() -> Array:
	return clips.map(func(clip: Dictionary) -> String: return clip["id"])


## Clips y poses juntos, en el orden de la lista del editor: [{id, nombre}].
func entries() -> Array:
	return (clips + poses).map(func(entry: Dictionary) -> Dictionary: return {"id": entry["id"], "nombre": entry["nombre"]})


func pose_turns(id: String) -> Dictionary:
	for pose: Dictionary in poses:
		if pose["id"] == id:
			return pose["bones"]
	return {}


## Pone el clip en su primer fotograma. Devuelve false si no existe.
func play(id: String) -> bool:
	for clip: Dictionary in clips:
		if clip["id"] == id:
			player.play(clip["animation"])
			seek(0.0)
			return true
	return false


func length() -> float:
	return player.current_animation_length


func seek(seconds: float) -> void:
	player.seek(fposmod(seconds, length()))
	player.advance(0.0)  # en modo manual, seek no mueve los huesos hasta avanzar


func advance(delta: float) -> void:
	player.advance(delta)


func _load(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text) if text else null
	if typeof(data) != TYPE_DICTIONARY:
		return "No se puede leer " + path
	if data.get("version") != float(VERSION):
		return "Versión %s de animaciones; se esperaba %d" % [data.get("version"), VERSION]
	var glb := path.get_base_dir().path_join(data["file"])
	if FileAccess.get_sha256(glb) != data["sha256"]:
		return "El sha256 de %s no coincide" % data["file"]
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(glb, state) != OK:
		return "No se puede abrir " + glb
	scene = document.generate_scene(state)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	if skeletons.size() != 1 or players.size() != 1:
		return "%s debe tener un esqueleto y un reproductor" % data["file"]
	skeleton = skeletons[0]
	player = players[0]
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL  # avanza quien lo usa
	for mesh: Node in scene.find_children("*", "MeshInstance3D", true, false):
		mesh.free()
	clips = data["clips"]
	bones = data["bones"]
	poses = data.get("poses", [])
	feet = data.get("feet", [])
	hips = data["hips"]
	for clip: Dictionary in clips:
		if not player.has_animation(clip["animation"]):
			return "Falta la animación %s en %s" % [clip["animation"], data["file"]]
		player.get_animation(clip["animation"]).loop_mode = Animation.LOOP_LINEAR
	for bone: String in bones:
		if skeleton.find_bone(bones[bone]) < 0:
			return "Falta el hueso %s en %s" % [bones[bone], data["file"]]
	return ""
