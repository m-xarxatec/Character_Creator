// Estilo ilustración (prueba del paso 3.12; se completa en el 3.10): piel o prenda como body.gdshader (color por
// vértice `garment` en el rojo, corte en 0,5), con 3 tonos planos de bordes suaves, sombra cálida, luz de contorno
// (rim) suave y sin brillo. Las tintas multiplican el color: 1 = sin cambio.
// Contorno: outline.gdshader como next_pass de este material.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform vec3 skin_color : source_color = vec3(1.0, 0.88, 0.81);
uniform vec3 garment_color : source_color = vec3(0.20, 0.20, 0.23);
uniform bool show_garment = true;
uniform vec3 mid_tint : source_color = vec3(0.97, 0.88, 0.86);
uniform vec3 shadow_tint : source_color = vec3(0.86, 0.70, 0.70);
uniform float mid_threshold : hint_range(-1.0, 1.0) = 0.45;
uniform float shadow_threshold : hint_range(-1.0, 1.0) = 0.0;
uniform float softness : hint_range(0.0, 0.5) = 0.04;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.92);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	float garment = show_garment ? step(0.5, COLOR.r) : 0.0;
	ALBEDO = mix(skin_color, garment_color, garment);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = smoothstep(1.0 - rim_width, 1.0, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	EMISSION = rim_color * ALBEDO * rim * rim_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float to_mid = smoothstep(shadow_threshold - softness, shadow_threshold + softness, ndl);
	float to_lit = smoothstep(mid_threshold - softness, mid_threshold + softness, ndl);
	vec3 tone = mix(mix(shadow_tint, mid_tint, to_mid), vec3(1.0), to_lit);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * tone;  // LIGHT_COLOR ya viene multiplicado por PI
}
