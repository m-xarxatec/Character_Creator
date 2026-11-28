// Referencia congelada (SH.3a): copia exacta de toon_soft.gdshader al cerrar SH.2b, para comparar en probar_luces.gd. No se edita.
// El bloque «Común» se comparte con eye_layers.gdshader (SH.2b): si se cambia aquí, se cambia igual allí.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform vec3 skin_color : source_color = vec3(0.80, 0.80, 0.80);
uniform vec3 garment_color : source_color = vec3(0.20, 0.20, 0.23);
uniform bool show_garment = true;
uniform bool unlit = false;
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float softness : hint_range(0.0, 0.5) = 0.09;
uniform float shade_strength : hint_range(0.0, 1.0) = 1.0;
uniform float ground_weight : hint_range(0.0, 1.0) = 0.025;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.92);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.075;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float detail_amount : hint_range(0.0, 1.0) = 0.0;

// ==== Común (SH.2b): idéntico en toon_soft.gdshader y eye_layers.gdshader; lo vigila probar_base_ojo.gd ====
const float SHADE_VALUE_LIGHT = 0.78;  // cuánto oscurece un color claro
const float SHADE_VALUE_DARK = 0.92;   // un color oscuro baja menos, para no acabar casi negro
const float SHADE_SATURATION = 1.08;  // colores medios y oscuros
const float SHADE_SATURATION_LIGHT = 1.35;  // colores claros: la sombra de la piel clara no debe quedar beige (D47)
const float SHADE_HUE_DEGREES = 5.0;   // hacia el rojo, por el camino corto

varying vec3 shade_ratio;

vec3 to_srgb(vec3 c) {
	return mix(12.92 * c, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-5)), d / (q.x + 1e-5), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// El giro se reduce en colores casi neutros: blanco, gris y negro no cogen matiz.
vec3 shade_of(vec3 color) {
	vec3 hsv = rgb_to_hsv(to_srgb(clamp(color, 0.0, 1.0)));
	float to_red = fract(0.5 - hsv.x) - 0.5;
	float turn = clamp(to_red, -SHADE_HUE_DEGREES / 360.0, SHADE_HUE_DEGREES / 360.0) * min(hsv.y * 4.0, 1.0);
	float value = mix(SHADE_VALUE_DARK, SHADE_VALUE_LIGHT, smoothstep(0.2, 0.8, hsv.z));
	float saturation = mix(SHADE_SATURATION, SHADE_SATURATION_LIGHT, smoothstep(0.75, 0.92, hsv.z));
	vec3 shaded = vec3(fract(hsv.x + turn), min(hsv.y * saturation, 1.0), hsv.z * value);
	return mix(color, to_linear(hsv_to_rgb(shaded)), shade_strength);
}

void light() {
	float lit = smoothstep(threshold - softness, threshold + softness, dot(NORMAL, LIGHT));
	lit *= smoothstep(0.15, 0.85, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shade_ratio, vec3(1.0), lit);
}
// ==== Fin del común ====

void fragment() {
	float garment = show_garment ? step(0.5, min(COLOR.r, COLOR.a)) : 0.0;
	vec3 color = mix(skin_color, garment_color, garment);
	if (detail_amount > 0.0) {
		color *= mix(vec3(1.0), texture(detail_tex, UV).rgb / 0.266, detail_amount);
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	shade_ratio = shade_of(color) / max(color, vec3(0.0001));
	if (unlit) {
		ALBEDO = vec3(0.0);
		EMISSION = color;
	} else {
		vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		ALBEDO = color * (1.0 - ground_weight * (0.5 - 0.5 * world_normal.y));
		float rim = smoothstep(1.0 - rim_width, 1.0, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
		EMISSION = rim_color * color * rim * rim_strength;
	}
}
