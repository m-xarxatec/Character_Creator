// Contorno exterior con malla invertida (prueba del paso 3.12; se completa en el 3.10): se dibujan las caras de
// atrás, empujadas hacia fuera en pantalla. Grosor en píxeles: igual de cerca que de lejos.
// Uso: next_pass del material del cuerpo (sigue a las formas y al esqueleto, porque es la misma malla).
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec3 outline_color : source_color = vec3(0.07, 0.05, 0.06);
uniform float width_px : hint_range(0.0, 10.0) = 2.5;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 normal = (PROJECTION_MATRIX * vec4(MODELVIEW_NORMAL_MATRIX * NORMAL, 0.0)).xyz;
	vec2 direction = normalize(normal.xy + vec2(1e-6));
	clip.xy += direction * width_px * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color;
}
