extends SceneTree
# Paso 13.3h-a: textura base de las piezas en toon, toon_soft y outline (uniform base_tex, blanco por defecto) y
# BodyMaterial.set_base_texture / get_base_texture. Sin textura nada cambia: el único uso es multiplicar el color por
# base_tex (blanco = × 1) y ningún parámetro más se pone ni se mueve. Sin ventana: compila los shaders, pero no dibuja
# (los píxeles de textura × color quedan para la parte con ventana de la ficha). No escribe nada.
# Uso: prlimit --as=4096000000 timeout 120 godot --headless --path pruebas/godot -s probar_textura_pieza.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'
# Que detecta el fallo: quitar «base_tex» de OUTLINE_SYNC -> falla «el contorno lleva la textura»; quitar el factor en
# toon.gdshader -> falla «toon: el color × base_tex»; hint_default_black en toon_soft -> falla «toon_soft: base_tex blanco por
# defecto»; que set_base_texture ignore null -> falla «null la quita».

const BodyMaterial := preload("res://../../godot/addons/creador/body_material.gd")
const StudioView := preload("res://../../godot/app/studio_view.gd")
const DECLARATION := "uniform sampler2D base_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;"
const FACTOR := "mix(skin_color, garment_color, garment) * texture(base_tex, UV).rgb"
## La línea entera donde se usa, en cada shader.
const USE_LINES := {
	"toon": "vec3 color = " + FACTOR + ";",
	"toon_soft": "vec3 color = " + FACTOR + ";",
	"outline": "vec3 hsv = rgb_to_hsv(to_srgb(clamp(" + FACTOR + ", 0.0, 1.0)));"}
const TINT := Color(0.2, 0.6, 0.4)

var failures := 0


func _initialize() -> void:
	_check_shader("toon", BodyMaterial.SHADER)
	_check_shader("toon_soft", BodyMaterial.SOFT_SHADER)
	_check_shader("outline", BodyMaterial.OUTLINE_SHADER)
	for soft: bool in [false, true]:
		var name := "pieza anime" if soft else "pieza clásica"
		var code := _code(BodyMaterial.piece_shader(soft))
		check(name + ": su shader compila y lleva la textura", _has_uniform(BodyMaterial.piece_shader(soft))
				and code.count(FACTOR) == 1)
		_check_untouched(soft, name + ", sin textura: ")
		_check_texture(soft, name + ": ")
	_check_without_material()
	print("RESULTADO: ", "TODO BIEN" if failures == 0 else "%d FALLOS" % failures)
	quit(1 if failures else 0)


func check(label: String, ok: bool, detail := "") -> void:
	print(("  bien  " if ok else "  FALLO ") + label, " ", detail)
	if not ok:
		failures += 1


# --- Shaders ---

## El código sin comentarios ni espacios a los lados.
func _code(shader: Shader) -> String:
	var lines: Array[String] = []
	for line: String in shader.code.split("\n"):
		lines.append(line.get_slice("//", 0).strip_edges())
	return "\n".join(lines)


## Sin ventana, un shader que no compila no da ningún uniform.
func _has_uniform(shader: Shader) -> bool:
	return shader.get_shader_uniform_list().any(func(u: Dictionary) -> bool: return u["name"] == "base_tex")


## Con solo la declaración y un factor, sin textura (blanco, × 1,0) el color es el de antes.
func _check_shader(name: String, shader: Shader) -> void:
	var code := _code(shader)
	var lines := code.split("\n")
	check(name + ": compila y declara base_tex", _has_uniform(shader))
	check(name + ": base_tex blanco por defecto, color sRGB", lines.count(DECLARATION) == 1)
	check(name + ": el color × base_tex", lines.count(USE_LINES[name]) == 1)
	check(name + ": base_tex no se usa en nada más", code.count("base_tex") == 2, str(code.count("base_tex")))


# --- Material ---

func _piece(soft: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	BodyMaterial.apply(mesh, true, soft)
	return mesh


func _outline(mesh: MeshInstance3D) -> ShaderMaterial:
	return (mesh.material_override as ShaderMaterial).get_meta("outline")


## Todos los parámetros del material y de su contorno, según los uniform de cada shader.
func _parameters(mesh: MeshInstance3D) -> Dictionary:
	var values := {}
	for material: ShaderMaterial in [mesh.material_override, _outline(mesh)]:
		var prefix := "contorno/" if material == _outline(mesh) else ""
		for uniform: Dictionary in material.shader.get_shader_uniform_list():
			values[prefix + uniform["name"]] = material.get_shader_parameter(uniform["name"])
	return values


## Una pieza sin textura lleva los parámetros de antes del paso: los del estilo, depth_pull y base_tex sin poner.
func _check_untouched(soft: bool, label: String) -> void:
	var mesh := _piece(soft)
	var defaults: Dictionary = BodyMaterial.SOFT_DEFAULTS if soft else BodyMaterial.DEFAULTS
	check(label + "base_tex fuera de los valores por defecto", not defaults.has("base_tex")
			and not BodyMaterial.OUTLINE_DEFAULTS.has("base_tex"))
	var values := _parameters(mesh)
	check(label + "sin poner en el material ni en el contorno", values.has("base_tex") and values["base_tex"] == null
			and values.has("contorno/base_tex") and values["contorno/base_tex"] == null
			and BodyMaterial.get_base_texture(mesh) == null)
	var expected := defaults.duplicate()
	expected["depth_pull"] = BodyMaterial.PIECE_PULL
	for name: String in BodyMaterial.OUTLINE_DEFAULTS:
		expected["contorno/" + name] = BodyMaterial.OUTLINE_DEFAULTS[name]
	var wrong: Array[String] = []
	for name: String in values:
		if values[name] != expected.get(name):
			wrong.append(name)
	check(label + "los demás parámetros, los de siempre", wrong.is_empty(), str(wrong))
	mesh.free()


func _carries(mesh: MeshInstance3D, texture: Texture2D) -> bool:
	return BodyMaterial.get_base_texture(mesh) == texture and _outline(mesh).get_shader_parameter("base_tex") == texture


func _check_texture(soft: bool, label: String) -> void:
	var mesh := _piece(soft)
	var plain := _parameters(mesh)
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.1, 0.1))
	var texture := ImageTexture.create_from_image(image)
	BodyMaterial.set_base_texture(mesh, texture)
	check(label + "ida y vuelta", BodyMaterial.get_base_texture(mesh) == texture)
	check(label + "el contorno lleva la textura", _outline(mesh).get_shader_parameter("base_tex") == texture)
	var changed := _parameters(mesh).keys().filter(func(k: String) -> bool: return _parameters(mesh)[k] != plain[k])
	check(label + "solo cambia base_tex", changed == ["base_tex", "contorno/base_tex"], str(changed))
	BodyMaterial.set_color(mesh, "skin_color", TINT)
	check(label + "el color elegido tiñe y no quita la textura", BodyMaterial.get_color(mesh, "skin_color") == TINT
			and _outline(mesh).get_shader_parameter("skin_color") == TINT and _carries(mesh, texture))
	BodyMaterial.set_style(mesh, not soft, true)
	check(label + "sobrevive al cambiar de estilo", BodyMaterial.is_soft(mesh) != soft and _carries(mesh, texture))
	BodyMaterial.set_style(mesh, soft, true)
	check(label + "y al volver", BodyMaterial.is_soft(mesh) == soft and _carries(mesh, texture))
	BodyMaterial.set_base_texture(mesh, null)
	check(label + "null la quita del material y del contorno", _carries(mesh, null))
	BodyMaterial.set_color(mesh, "skin_color", plain["skin_color"])
	var left := _parameters(mesh).keys().filter(func(k: String) -> bool: return _parameters(mesh)[k] != plain[k])
	left.erase("contorno/width_px")  # set_style pone el grosor del estilo
	check(label + "quitada, queda como sin textura", left.is_empty(), str(left))
	BodyMaterial.set_base_texture(mesh, texture)
	var copy := MeshInstance3D.new()
	copy.material_override = StudioView._copy(mesh.material_override)
	check(label + "la copia del Estudio la lleva", copy.material_override != mesh.material_override
			and _outline(copy) != _outline(mesh) and _carries(copy, texture))
	check(label + "la copia para el juego (cuerpo) no la lleva",
			BodyMaterial.standalone(mesh).get_shader_parameter("base_tex") == null)
	copy.free()
	mesh.free()


func _check_without_material() -> void:
	var mesh := MeshInstance3D.new()
	var no_material := BodyMaterial.get_base_texture(mesh) == null
	mesh.material_override = StandardMaterial3D.new()
	check("get_base_texture sin ShaderMaterial: null", no_material and BodyMaterial.get_base_texture(mesh) == null)
	mesh.free()
