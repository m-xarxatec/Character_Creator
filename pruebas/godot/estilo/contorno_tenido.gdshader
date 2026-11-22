// Paso SH.1: contorno de prueba, teñido con el color de su zona. No lo usa el programa: solo capturar_hoja_shader.gd.
// Es outline.gdshader con dos cambios: no engorda la sombra proyectada y su color = color de la zona × outline_tint.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec3 skin_color : source_color = vec3(0.80, 0.80, 0.80);
uniform vec3 garment_color : source_color = vec3(0.20, 0.20, 0.23);
uniform bool show_garment = true;
uniform vec3 outline_tint : source_color = vec3(0.45, 0.30, 0.30);
uniform float width_px : hint_range(0.0, 10.0) = 1.25;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 normal = (PROJECTION_MATRIX * vec4(MODELVIEW_NORMAL_MATRIX * NORMAL, 0.0)).xyz;
	vec2 direction = normalize(normal.xy + vec2(1e-6));
	if (!IN_SHADOW_PASS) {
		clip.xy += direction * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	}
	POSITION = clip;
}

void fragment() {
	float garment = show_garment ? step(0.5, min(COLOR.r, COLOR.a)) : 0.0;
	ALBEDO = mix(skin_color, garment_color, garment) * outline_tint;
}
