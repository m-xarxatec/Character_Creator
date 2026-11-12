// Material del cuerpo en estilo ilustración (pasos 3.12 y 3.10): piel o prenda según el color por vértice `garment`
// (en el rojo o en el alfa, corte en 0,5), con 3 tonos planos de bordes suaves, sombra cálida, luz de contorno (rim) suave y sin
// brillo. El medio y la sombra salen del color base, más oscuro (lo multiplican: 1 = sin cambio), así que valen
// para cualquier color.
// Contorno: outline.gdshader como next_pass de este material (lo monta body_material.gd).
// `unlit`: sin luces ni rim, color exacto (EMISSION = color); para las pruebas de color de la prenda.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform vec3 skin_color : source_color = vec3(0.80, 0.80, 0.80);
uniform vec3 garment_color : source_color = vec3(0.20, 0.20, 0.23);
uniform bool show_garment = true;
uniform bool unlit = false;
uniform float mid_shade : hint_range(0.0, 1.0) = 0.9;
uniform float shadow_shade : hint_range(0.0, 1.0) = 0.73;
uniform float mid_threshold : hint_range(-1.0, 1.0) = 0.45;
uniform float shadow_threshold : hint_range(-1.0, 1.0) = 0.0;
uniform float softness : hint_range(0.0, 0.5) = 0.04;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.92);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.25;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	// `garment` está en el rojo en el editor (alfa 1) y en el alfa en el .glb (RGB blanco, para que la norma glTF no
	// tiña el material; ver glb_exporter.gd). El menor de los dos vale en ambos casos sin interruptor.
	float garment = show_garment ? step(0.5, min(COLOR.r, COLOR.a)) : 0.0;
	vec3 color = mix(skin_color, garment_color, garment);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (unlit) {
		ALBEDO = vec3(0.0);
		EMISSION = color;
	} else {
		ALBEDO = color;
		float rim = smoothstep(1.0 - rim_width, 1.0, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
		EMISSION = rim_color * color * rim * rim_strength;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float to_mid = smoothstep(shadow_threshold - softness, shadow_threshold + softness, ndl);
	float to_lit = smoothstep(mid_threshold - softness, mid_threshold + softness, ndl);
	vec3 tone = vec3(mix(mix(shadow_shade, mid_shade, to_mid), 1.0, to_lit));
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * tone;  // LIGHT_COLOR ya viene multiplicado por PI
}
