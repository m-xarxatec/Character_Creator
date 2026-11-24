class_name EyeTexture
extends RefCounted
## Paso AC.6b: hornea en CPU las capas del ojo (eye_layers.gdshader) y sus líneas (eye_line.gdshader) en texturas, para
## el .glb, que no lleva shaders. Como garment_texture.gd: sin tarjeta gráfica, vale en un hilo y con --headless.
##
## Uso (lo hace glb_exporter.gd):
##   var values := EyeTexture.eye_values(ojo)                 # hilo principal: uniforms del editor + los de serie
##   var baked := EyeTexture.bake_eye(uvs, heights, indices, values)   # {"image", "uv"}: textura y UV de 0 a 1
##   var line := EyeTexture.bake_line(uvs, EyeTexture.line_values(linea))
## COPIA de las cuentas de los dos shaders (mismos nombres): si cambia un shader, cambiar aquí también. probar_glb.gd
## compara los valores de serie y las constantes con el texto de los shaders. La luz no se hornea: el .glb la recibe.
## Los colores se mezclan en lineal, como en el shader, y la imagen se guarda en sRGB.

const EYE_SIZE := 256  # píxeles del cuadrado de cada ojo
const LINE_WIDTH := 1024  # píxeles a lo largo de cada línea; el alto sale con píxeles casi cuadrados
const MARGIN := 0.04  # parte del lado que sobra alrededor del ojo
const PADDING := 4  # píxeles que el blanco se alarga fuera de la bolsa, para que el filtrado no meta otro color

## Valores de serie de los uniforms (los mismos que en los shaders).
const EYE_DEFAULTS := {"white_color": Color(0.92, 0.91, 0.94), "white_shadow": Color(0.78, 0.76, 0.90),
	"white_shadow_from": 0.62, "iris_color": Color(0.55, 0.08, 0.10), "iris_size": 1.0, "iris_center": Vector2(0.0, 0.0),
	"iris_axes": Vector2(0.0061, 0.010), "low_b": 0.007, "y_bottom": -0.007, "y_line": 0.006, "shine_side": 1.0,
	"shine_color": Color(0.98, 0.99, 1.0)}
const LINE_DEFAULTS := {"mode": 0, "arc_length": 0.0374, "line_color": Color(0.18, 0.07, 0.08), "w_inner": 0.00015,
	"w_peak": 0.0030, "u_peak": 0.80, "inward": 0.85, "fade_u": 0.22, "tail_end": 1.05, "corner": 0.30,
	"lash_u": Vector3(0.94, 0.99, 1.035), "lash_length": Vector3(0.0008, 0.0011, 0.0008), "lash_width": 0.0005,
	"lash_tilt": 0.9, "crease_offset": 0.0022, "crease_width": 0.00016, "crease_alpha": 0.22,
	"crease_span": Vector2(0.25, 0.85), "lower_color": Color(0.04, 0.03, 0.04), "lower_peak": 0.0010,
	"lower_u_peak": 0.76, "lower_start": 0.12, "lower_end": 0.30}
## Constantes de eye_layers.gdshader.
const SHADER_CONSTANTS := {"IRIS_TOP_DARK": 0.12, "IRIS_DARK_FROM": 0.42, "IRIS_LIGHT_GAIN": 1.7, "IRIS_LIGHT_MIX": 0.10,
	"IRIS_MOON": 0.55, "PUPIL_SIZE": Vector2(0.26, 0.24), "PUPIL_SOFT": 0.45, "PUPIL_SHADE": 0.35,
	"SHINE_MAIN": Vector3(0.40, 0.70, 0.12), "SHINE_DOT": Vector3(-0.32, 0.18, 0.06)}


## Uniforms de un ojo del editor (blanco en su material, iris y brillos en su next_pass); los no puestos, de serie.
static func eye_values(eye: MeshInstance3D) -> Dictionary:
	var values := EYE_DEFAULTS.duplicate()
	var material := eye.material_override as ShaderMaterial
	while material != null:
		_read(material, values)
		material = material.next_pass as ShaderMaterial
	return values


## Uniforms de una línea del editor (mode y arc_length los pone EyeMesh.line_material).
static func line_values(line: MeshInstance3D) -> Dictionary:
	var values := LINE_DEFAULTS.duplicate()
	_read(line.material_override as ShaderMaterial, values)
	return values


static func _read(material: ShaderMaterial, values: Dictionary) -> void:
	if material == null:
		return
	for key: String in values:
		var value: Variant = material.get_shader_parameter(key)
		if value != null:
			values[key] = value


## Ojo: {"image": RGB8 de EYE_SIZE², "uv": UV de 0 a 1}. uvs, en metros (TEX_UV de EyeMesh); heights, la altura entre
## párpados de cada vértice (TEX_UV2.x).
static func bake_eye(uvs: PackedVector2Array, heights: PackedFloat32Array, indices: PackedInt32Array,
		values: Dictionary, size: int = EYE_SIZE) -> Dictionary:
	var low := uvs[0]
	var high := uvs[0]
	for p in uvs:
		low = low.min(p)
		high = high.max(p)
	var center := (low + high) / 2.0
	var side := maxf(high.x - low.x, high.y - low.y) * (1.0 + 2.0 * MARGIN)
	var out := PackedVector2Array()
	for p in uvs:
		out.append(Vector2((p.x - center.x) / side + 0.5, 0.5 - (p.y - center.y) / side))
	var field := _height_field(out, heights, indices, size)
	var pixel := side / size
	var v := _linear_values(values)
	var iris := Iris.new(v)
	var white_a: Color = v["white_color"]
	var white_b: Color = v["white_shadow"]
	var shadow_from: float = v["white_shadow_from"]
	var data := PackedByteArray()
	data.resize(size * size * 3)
	for y in size:
		var py := center.y - ((y + 0.5) / size - 0.5) * side
		for x in size:
			var p := Vector2(center.x + ((x + 0.5) / size - 0.5) * side, py)
			var color := white_a.lerp(white_b, Iris.smooth(shadow_from, 1.0, maxf(field[y * size + x], 0.0)))
			if iris.near(p, pixel):
				var layer := iris.color(p, pixel)
				color = color.lerp(layer, layer.a)
			color = color.linear_to_srgb()
			var i := (y * size + x) * 3
			data[i] = clampi(roundi(color.r * 255.0), 0, 255)
			data[i + 1] = clampi(roundi(color.g * 255.0), 0, 255)
			data[i + 2] = clampi(roundi(color.b * 255.0), 0, 255)
	return {"image": Image.create_from_data(size, size, false, Image.FORMAT_RGB8, data), "uv": out}


## Altura entre párpados en cada píxel (interpolada en los triángulos), alargada PADDING píxeles; -1 fuera.
static func _height_field(uvs: PackedVector2Array, heights: PackedFloat32Array, indices: PackedInt32Array,
		size: int) -> PackedFloat32Array:
	var field := PackedFloat32Array()
	field.resize(size * size)
	field.fill(-1.0)
	for t in range(0, indices.size(), 3):
		var a := uvs[indices[t]] * size
		var b := uvs[indices[t + 1]] * size
		var c := uvs[indices[t + 2]] * size
		var area := (b - a).cross(c - a)
		if absf(area) < 1e-12:
			continue
		var box_low := a.min(b).min(c).floor()
		var box_high := a.max(b).max(c).ceil()
		for y in range(maxi(0, int(box_low.y)), mini(size, int(box_high.y) + 1)):
			for x in range(maxi(0, int(box_low.x)), mini(size, int(box_high.x) + 1)):
				var p := Vector2(x + 0.5, y + 0.5)
				var wa := (b - p).cross(c - p) / area
				var wb := (c - p).cross(a - p) / area
				var wc := 1.0 - wa - wb
				if wa >= -1e-6 and wb >= -1e-6 and wc >= -1e-6:
					field[y * size + x] = wa * heights[indices[t]] + wb * heights[indices[t + 1]] + wc * heights[indices[t + 2]]
	for step in PADDING:
		var next := field.duplicate()
		for i in field.size():
			if field[i] >= 0.0:
				continue
			for j: int in [i - 1 if i % size > 0 else -1, i + 1 if i % size < size - 1 else -1, i - size, i + size]:
				if j >= 0 and j < field.size() and field[j] >= 0.0:
					next[i] = field[j]
					break
		field = next
	return field


## Los colores de los uniforms (sRGB) en lineal, como los lee el shader (source_color).
static func _linear_values(values: Dictionary) -> Dictionary:
	var out := values.duplicate()
	for key: String in out:
		if out[key] is Color:
			out[key] = (out[key] as Color).srgb_to_linear()
	return out


## Iris, pupila y brillos de un ojo: iris_layer() y shine_layer() de eye_layers.gdshader, con los uniforms ya leídos.
## fwidth() es aquí lo que cambia la medida en un píxel de la textura.
class Iris:
	var color_iris: Color
	var bright: Color
	var moon_color: Color
	var shine_color: Color
	var center: Vector2
	var axes: Vector2
	var low: float
	var bottom: float
	var waist: float
	var top_b: float
	var y_bottom: float
	var y_line: float
	var big_at: Vector2
	var big_r: float
	var dot_at: Vector2
	var dot_r: float
	var k := SHADER_CONSTANTS

	func _init(v: Dictionary) -> void:
		color_iris = v["iris_color"]
		shine_color = v["shine_color"]
		axes = v["iris_axes"] * v["iris_size"]
		center = v["iris_center"]
		low = v["low_b"] * v["iris_size"]
		bottom = center.y - axes.y
		waist = bottom + low
		top_b = maxf(center.y + axes.y - waist, 0.0001)
		y_bottom = v["y_bottom"]
		y_line = v["y_line"]
		bright = min1(color_iris * k["IRIS_LIGHT_GAIN"] + gray(k["IRIS_LIGHT_MIX"]))
		moon_color = min1(bright * 1.2 + gray(0.06))
		var a := axes.x
		var span := y_line - y_bottom
		var main: Vector3 = k["SHINE_MAIN"]
		var dot: Vector3 = k["SHINE_DOT"]
		big_at = Vector2(center.x + v["shine_side"] * main.x * a, y_bottom + main.y * span)
		big_r = main.z * a
		dot_at = Vector2(center.x + v["shine_side"] * dot.x * a, y_bottom + dot.y * span)
		dot_r = dot.z * a

	## Dentro del recuadro del iris (fuera, su alfa es 0).
	func near(p: Vector2, pixel: float) -> bool:
		return absf(p.x - center.x) <= axes.x + 2.0 * pixel and p.y >= bottom - 2.0 * pixel \
			and p.y <= center.y + axes.y + 2.0 * pixel

	## Color lineal con la cobertura en el alfa.
	func color(p: Vector2, pixel: float) -> Color:
		var b := low if p.y < waist else top_b
		var q := Vector2((p.x - center.x) / axes.x, (p.y - waist) / b)
		var r := q.length()
		var aa := maxf(pixel * (absf(q.x) / axes.x + absf(q.y) / b) / maxf(r, 1e-6), 0.0001)
		var s := (p.y - y_bottom) / (y_line - y_bottom)
		var t := clampf((p.y - bottom) / (2.0 * axes.y), 0.0, 1.0)
		var c := bright.lerp(color_iris, smooth(0.08, 0.55, t))
		var moon_in := 1.0 - smooth(0.80, 0.94, ((q - Vector2(0.0, 0.32)) / Vector2(0.92, 1.0)).length())
		var moon := (1.0 - smooth(0.86, 0.97, r)) * (1.0 - moon_in) * smooth(0.05, -0.45, q.y)
		c = c.lerp(moon_color, moon * k["IRIS_MOON"])
		var pupil := 1.0 - smooth(1.0 - k["PUPIL_SOFT"], 1.0, ((p - center) / axes / k["PUPIL_SIZE"]).length())
		c = c.lerp(color_iris * k["PUPIL_SHADE"], pupil)
		c = c.lerp(color_iris * k["IRIS_TOP_DARK"], smooth(k["IRIS_DARK_FROM"], 0.98, s))
		c = c.lerp(color_iris * 0.30, smooth(0.88, 1.0, r) * 0.7)
		c = c.lerp(shine_color, maxf(_disc(p, big_at, big_r, pixel), _disc(p, dot_at, dot_r, pixel)))
		c.a = 1.0 - smooth(1.0 - aa, 1.0 + aa, r)
		return c

	static func _disc(p: Vector2, at: Vector2, radius: float, pixel: float) -> float:
		var offset := p - at
		var d := offset.length()
		var aa := maxf(pixel * (absf(offset.x) + absf(offset.y)) / maxf(d, 1e-9), 0.000001)
		return 1.0 - smooth(radius - aa, radius + aa, d)

	## smoothstep de GLSL, también con e0 > e1 (el de GDScript no da lo mismo en ese caso).
	static func smooth(e0: float, e1: float, x: float) -> float:
		var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
		return t * t * (3.0 - 2.0 * t)

	static func min1(c: Color) -> Color:
		return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0))

	static func gray(value: float) -> Color:
		return Color(value, value, value, 0.0)


## Línea: {"image": RGBA8 (color de la línea y su alfa), "uv": UV de 0 a 1}. uvs: (u, fila en metros), de EyeMesh.
static func bake_line(uvs: PackedVector2Array, values: Dictionary, width: int = LINE_WIDTH) -> Dictionary:
	var low := uvs[0]
	var high := uvs[0]
	for p in uvs:
		low = low.min(p)
		high = high.max(p)
	var span := (high - low).max(Vector2(1e-6, 1e-6))
	var height := maxi(4, ceili(span.y / (values["arc_length"] * span.x / width)))
	var out := PackedVector2Array()
	for p in uvs:
		out.append(Vector2((p.x - low.x) / span.x, (high.y - p.y) / span.y))
	var color: Color = values["lower_color"] if values["mode"] == 2 else values["line_color"]
	var rgb := PackedByteArray([color.r8, color.g8, color.b8])
	var data := PackedByteArray()
	data.resize(width * height * 4)
	var step := Vector2(span.x / width, span.y / height)
	for x in width:
		var column := _line_column(low.x + (x + 0.5) * step.x, step, values)
		for y in height:
			var i := (y * width + x) * 4
			data[i] = rgb[0]
			data[i + 1] = rgb[1]
			data[i + 2] = rgb[2]
			data[i + 3] = clampi(roundi(_line_alpha(high.y - (y + 0.5) * step.y, step.y, column) * 255.0), 0, 255)
	return {"image": Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data), "uv": out}


## Lo que solo depende de u en fragment() de eye_line.gdshader: [banda baja, banda alta, factor] y, en la línea de
## arriba, por cada pestaña [base, largo, lo que se aparta en u (m), medio ancho, aa], y al final la inclinación.
static func _line_column(u: float, step: Vector2, v: Dictionary) -> PackedFloat32Array:
	if v["mode"] == 0:
		var w := _line_width(u, v)
		var out := PackedFloat32Array([-v["inward"] * w, (1.0 - v["inward"]) * w, Iris.smooth(v["fade_u"] * 0.3, v["fade_u"], u)])
		var aa := maxf(step.x * v["arc_length"] + step.y * v["lash_tilt"], 0.0000001)
		for i in 3:
			var at: float = v["lash_u"][i]
			out.append_array(PackedFloat32Array([(1.0 - v["inward"]) * _line_width(at, v) * 0.5, v["lash_length"][i],
				(u - at) * v["arc_length"], v["lash_width"] * 0.5, aa]))
		out.append(v["lash_tilt"])
		return out
	if v["mode"] == 2:
		var w := _lower_width(u, v)
		return PackedFloat32Array([-0.5 * w, 0.5 * w, Iris.smooth(v["lower_start"], v["lower_start"] + 0.08, u)])
	var half_c: float = v["crease_width"] * 0.5
	var span: Vector2 = v["crease_span"]
	return PackedFloat32Array([v["crease_offset"] - half_c, v["crease_offset"] + half_c,
		v["crease_alpha"] * Iris.smooth(span.x - 0.1, span.x, u) * (1.0 - Iris.smooth(span.y, span.y + 0.1, u))])


## Alfa en la fila d (metros) de una columna (_line_column).
static func _line_alpha(d: float, fw: float, column: PackedFloat32Array) -> float:
	var alpha := 0.0 if column[2] == 0.0 else _band(d, column[0], column[1], fw) * column[2]
	if column.size() > 3:  # pestañas: lash() de eye_line.gdshader
		var tilt := column[18]
		for k in 3:
			var at := 3 + 5 * k
			var h := (d - column[at]) / column[at + 1]
			if h < 0.0 or h > 1.0:
				continue
			var along := column[at + 2] - tilt * (d - column[at])
			var half_w := column[at + 3] * (1.0 - h)
			alpha = maxf(alpha, 1.0 - Iris.smooth(half_w - column[at + 4], half_w + column[at + 4], absf(along)))
	return alpha


static func _line_width(u: float, v: Dictionary) -> float:
	var w := lerpf(v["w_inner"], v["w_peak"], Iris.smooth(0.0, v["u_peak"], u))
	w *= 1.0 - (1.0 - v["corner"]) * Iris.smooth(v["u_peak"], 1.0, u)
	return w * (1.0 - Iris.smooth(1.0, v["tail_end"], u))


static func _lower_width(u: float, v: Dictionary) -> float:
	var w: float = v["lower_peak"] * Iris.smooth(v["lower_start"], v["lower_u_peak"], u)
	return w * (1.0 - (1.0 - v["lower_end"]) * Iris.smooth(v["lower_u_peak"], 1.0, u))


static func _band(d: float, low: float, high: float, fw: float) -> float:
	var aa := maxf(fw, 0.0000001)
	return Iris.smooth(low - aa, low + aa, d) * (1.0 - Iris.smooth(high - aa, high + aa, d))
