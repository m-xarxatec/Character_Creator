shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform vec3 skin_color : source_color = vec3(0.80, 0.80, 0.80);
uniform vec3 garment_color : source_color = vec3(0.20, 0.20, 0.23);
uniform bool show_garment = true;
uniform bool unlit = false;
uniform vec3 shade_tint : source_color = vec3(0.70, 0.55, 0.58);
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float softness : hint_range(0.0, 0.5) = 0.28;
uniform float ground_weight : hint_range(0.0, 1.0) = 0.2;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.08;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.92);
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float detail_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float garment = show_garment ? step(0.5, min(COLOR.r, COLOR.a)) : 0.0;
	vec3 color = mix(skin_color, garment_color, garment);
	if (detail_amount > 0.0) {
		color *= mix(vec3(1.0), texture(detail_tex, UV).rgb / 0.266, detail_amount);
	}
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALBEDO = color * (1.0 - ground_weight * (0.5 - 0.5 * world_normal.y));
	float rim = smoothstep(1.0 - rim_width, 1.0, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	EMISSION = rim_color * color * rim * rim_strength;
}

void light() {
	float lit = smoothstep(threshold - softness, threshold + softness, dot(NORMAL, LIGHT));
	if (LIGHT_IS_DIRECTIONAL) {
		lit *= smoothstep(0.15, 0.85, ATTENUATION);
		vec3 unit = LIGHT_COLOR / PI;
		DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, unit * shade_tint) + unit * (vec3(1.0) - shade_tint) * lit;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * ATTENUATION;
	}
}
