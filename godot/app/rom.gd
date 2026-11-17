extends RefCounted
# Paso 5.9: rango de movimiento. Cada movimiento gira UN hueso alrededor de un eje del personaje (X a su izquierda,
# Y arriba, Z al frente; desde la pose T) entre dos ángulos; sus hijos lo siguen y el resto queda en pose T.
# Datos: godot/datos/animaciones/rom.json (ejes y signos dados para el lado izquierdo; con «lados»: 2 el derecho hace
# el mismo gesto en espejo, con el eje (x, −y, −z)). Los giros salen en el formato de StaticPose: {hueso: [x, y, z]} grados.
# Uso: var rom := Rom.new(); rom.load_file(ruta); StaticPose.apply(esqueleto, rom.turns_at(segundos), "Hips", [])

var moves: Array = []
var seconds := 2.0  # lo que dura cada movimiento: reposo → desde → hasta → reposo


func load_file(path: String) -> String:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1.0 or not data.get("movimientos") is Array:
		return "No se puede leer el rango de movimiento: " + path
	moves = data["movimientos"]
	seconds = data.get("segundos", seconds)
	return ""


func ids() -> PackedStringArray:
	return PackedStringArray(moves.map(func(m: Dictionary) -> String: return m["id"]))


## t de 0 a 1: 0 y 1 = reposo; 0,25 = «desde»; 0,75 = «hasta»; en línea recta entre ellos.
static func angle(from: float, to: float, t: float) -> float:
	if t <= 0.25:
		return lerpf(0.0, from, t / 0.25)
	if t <= 0.75:
		return lerpf(from, to, (t - 0.25) / 0.5)
	return lerpf(to, 0.0, (t - 0.75) / 0.25)


## Giros de un movimiento en el instante t (0..1).
func turns(id: String, t: float) -> Dictionary:
	for move: Dictionary in moves:
		if move["id"] == id:
			return move_turns(move, angle(move["desde"], move["hasta"], t))
	return {}


## Giros de toda la secuencia (un movimiento tras otro, en bucle) a los `elapsed` segundos.
func turns_at(elapsed: float) -> Dictionary:
	if moves.is_empty():
		return {}
	var index := int(elapsed / seconds) % moves.size()
	return turns(moves[index]["id"], fmod(elapsed, seconds) / seconds)


static func move_turns(move: Dictionary, degrees: float) -> Dictionary:
	var axis := Vector3(move["eje"][0], move["eje"][1], move["eje"][2])
	if int(move["lados"]) == 1:
		return {move["hueso"]: _euler(axis, degrees)}
	return {"Left" + move["hueso"]: _euler(axis, degrees),
		"Right" + move["hueso"]: _euler(Vector3(axis.x, -axis.y, -axis.z), degrees)}


## Un giro sobre un eje X, Y o Z en el formato de StaticPose (grados sobre cada eje).
static func _euler(axis: Vector3, degrees: float) -> Array:
	return [axis.x * degrees, axis.y * degrees, axis.z * degrees]
