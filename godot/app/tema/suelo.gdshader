// Paso IU.3: sombra de suelo bajo el personaje y rejilla opcional (floor_shadow.gd). Sin texturas.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform float shadow_alpha = 0.35;
uniform float shadow_radius = 0.55;  // m
uniform bool grid = false;
uniform float grid_step = 0.5;  // m
uniform float grid_alpha = 0.25;
uniform float grid_radius = 1.5;  // m: más allá la rejilla se apaga

varying vec2 local_xz;
varying vec2 world_xz;

void vertex() {
	local_xz = VERTEX.xz;
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float r = length(local_xz);
	float alpha = shadow_alpha * (1.0 - smoothstep(0.0, shadow_radius, r));
	if (grid) {
		vec2 cell = abs(fract(world_xz / grid_step + 0.5) - 0.5) * grid_step;
		vec2 width = fwidth(world_xz);
		float line = 1.0 - min(smoothstep(0.0, width.x * 1.5, cell.x), smoothstep(0.0, width.y * 1.5, cell.y));
		alpha = max(alpha, grid_alpha * line * (1.0 - smoothstep(grid_radius * 0.5, grid_radius, r)));
	}
	ALBEDO = vec3(0.0);
	ALPHA = alpha;
}
