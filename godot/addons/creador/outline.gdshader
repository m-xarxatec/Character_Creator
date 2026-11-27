// Contorno exterior con malla invertida (prueba del paso 3.12; se completa en el 3.10): se dibujan las caras de
// atrás, empujadas hacia fuera en pantalla. Grosor en píxeles: igual de cerca que de lejos.
// Uso: next_pass del material del cuerpo (sigue a las formas y al esqueleto, porque es la misma malla).
// AC.3c: UV2.x es la máscara del ojo (TEXCOORD_1 de cuerpo.glb; 0 en la piel y en mallas sin ese canal): anula el grosor
// y lleva el casco hacia el fondo, para no pintar contorno dentro de la abertura. La sombra no cambia.
// SH.4b: línea teñida (outline_tint: 0 = outline_color, como siempre; 1 = el color de la zona, oscuro y algo más
// saturado: piel, prenda con min(COLOR.r, COLOR.a) y show_garment, o el color de la pieza) y más fina en la cara
// (face_line × grosor donde el canal A de skin_zones es 0). Con los valores por defecto, igual que antes.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec3 outline_color : source_color = vec3(0.07, 0.05, 0.06);
uniform float width_px : hint_range(0.0, 10.0) = 2.5;
uniform vec3 skin_color : source_color = vec3(0.80, 0.80, 0.80);
uniform vec3 garment_color : source_color = vec3(0.20, 0.20, 0.23);
uniform bool show_garment = true;
uniform float outline_tint : hint_range(0.0, 1.0) = 0.0;
uniform float face_line : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D skin_zones : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D hide_mask : hint_default_transparent, filter_nearest, repeat_disable;  // 12.1b: piel bajo la ropa

const float LINE_VALUE = 0.42;  // la línea teñida: valor del color × esto (en sRGB)
const float LINE_SATURATION = 1.4;  // y saturación × esto

vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 normal = (PROJECTION_MATRIX * vec4(MODELVIEW_NORMAL_MATRIX * NORMAL, 0.0)).xyz;
	vec2 direction = normalize(normal.xy + vec2(1e-6));
	if (!IN_SHADOW_PASS) {  // SH.4: en el pase de sombra no se ensancha, así su sombra es la del cuerpo
		float width = width_px * mix(face_line, 1.0, textureLod(skin_zones, UV, 0.0).a);  // SH.4b: A = 0 en la cara
		clip.xy += direction * width * (1.0 - UV2.x) * 2.0 / VIEWPORT_SIZE * clip.w;
		clip.z *= 1.0 - 0.99 * UV2.x;
	}
	POSITION = clip;
}

void fragment() {
	if (texture(hide_mask, UV).a > 0.5) { discard; }
	float garment = show_garment ? min(COLOR.r, COLOR.a) : 0.0;
	vec3 hsv = rgb_to_hsv(to_srgb(clamp(mix(skin_color, garment_color, garment), 0.0, 1.0)));
	vec3 tinted = to_linear(hsv_to_rgb(vec3(hsv.x, min(hsv.y * LINE_SATURATION, 1.0), hsv.z * LINE_VALUE)));
	ALBEDO = mix(outline_color, tinted, outline_tint);
}
