// Ojo provisional del paso 3.12 (solo para juzgar la cabeza; se quita después): esfera que mira a +Z,
// con iris grande en degradado, pupila y un brillo. Sin texturas.
shader_type spatial;
render_mode unshaded;

uniform vec3 iris_color : source_color = vec3(0.42, 0.26, 0.18);
uniform float iris_size = 0.62;
varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec3 d = normalize(local);
	vec2 p = d.xy / max(d.z, 0.05);
	float r = length(p * vec2(1.0, 0.82));
	vec3 color = vec3(0.97, 0.97, 0.98);
	vec3 iris = mix(iris_color * 1.35, iris_color * 0.4, smoothstep(-0.5, 0.5, p.y));
	color = mix(color, iris, 1.0 - smoothstep(iris_size - 0.03, iris_size, r));
	color = mix(color, vec3(0.03, 0.02, 0.03), 1.0 - smoothstep(iris_size * 0.38, iris_size * 0.42, r));
	color = mix(color, vec3(1.0), 1.0 - smoothstep(0.08, 0.1, length(p - vec2(-0.2, 0.22) * iris_size / 0.62)));
	ALBEDO = d.z > 0.0 ? color : vec3(0.97);
}
