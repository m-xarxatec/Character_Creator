// Paso IU.7b: tinta de la zona bajo el ratón (material_overlay del cuerpo; body_view.gd). Se suma al estilo y no va al
// .glb. zone_mask[i] = 1 si el hueso de bind i (el del Skin) es de la zona; cuenta el hueso de mayor peso del vértice.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 tint : source_color = vec4(0.416, 0.333, 0.878, 1.0);
uniform float strength = 0.25;
uniform float zone_mask[64];

varying float lit;

void vertex() {
	uint bone = BONE_INDICES.x;
	float best = BONE_WEIGHTS.x;
	if (BONE_WEIGHTS.y > best) { bone = BONE_INDICES.y; best = BONE_WEIGHTS.y; }
	if (BONE_WEIGHTS.z > best) { bone = BONE_INDICES.z; best = BONE_WEIGHTS.z; }
	if (BONE_WEIGHTS.w > best) { bone = BONE_INDICES.w; }
	lit = zone_mask[min(int(bone), 63)];
}

void fragment() {
	ALBEDO = tint.rgb * strength * lit;
}
