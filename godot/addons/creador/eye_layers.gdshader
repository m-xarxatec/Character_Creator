// Pasos AC.3c, AC.4 y AC.5: capas del ojo sobre la bolsa de la cara. Blanco (opaco) e iris con pupila y brillos (EYE_IRIS, transparente).
// Los brillos van en la pasada del iris: caen siempre dentro de él (AC.4a los recorta al iris).
// Iris adaptado de «Anime Style Eyes (Procedural Eye Shader)», de ProfesorShader (CC0 1.0, godotshaders.com).
// UV = posición anime menos el centro del lazo, en metros; x apunta a +X en los dos ojos (los brillos caen del mismo lado).
// UV2.x = altura relativa entre el párpado de abajo (0) y el de arriba (1), de ojos.json: da la sombra del párpado.
// La luz es la de toon_soft (D48), sin emisión propia: el bloque «Común» es idéntico al suyo (SH.2b, lo vigila probar_base_ojo.gd).
shader_type spatial;
render_mode specular_disabled;  // SH.3b: recibe el mismo ambiente que la piel

uniform float depth_pull = 0.00005;
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float softness : hint_range(0.0, 0.5) = 0.09;
uniform float shade_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 white_color : source_color = vec3(0.92, 0.91, 0.94);
uniform vec3 white_shadow : source_color = vec3(0.78, 0.76, 0.90);
uniform float white_shadow_from = 0.62;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.92);  // SH.3b: los usa el light() común; el ojo, sin rim
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;
uniform float shadow_receive : hint_range(0.0, 1.0) = 1.0;  // SH.4: los usa el light() común
uniform vec3 hair_band_color : source_color = vec3(1.0, 0.98, 0.95);  // SH.6b: el ojo, sin banda
uniform float edge_strength : hint_range(0.0, 1.0) = 0.0;  // SH.3c: el blanco del ojo, sin banda
uniform float gloss_strength : hint_range(0.0, 1.0) = 0.0;  // SH.3d: sin brillo (los brillos del ojo son su capa, AC.5)
uniform float gloss_size : hint_range(0.0, 0.5) = 0.05;
uniform float gloss_softness : hint_range(0.0, 0.5) = 0.05;
uniform vec3 gloss_color : source_color = vec3(1.0, 0.96, 0.94);
uniform vec3 iris_color : source_color = vec3(0.55, 0.08, 0.10);
uniform float iris_size = 1.0;  // escala el iris alrededor de su centro
uniform vec2 iris_center = vec2(0.0);
uniform vec2 iris_axes = vec2(0.0061, 0.010);  // semiejes del iris entero (m)
uniform float low_b = 0.007;  // semieje vertical de la mitad de abajo (m)
uniform float y_bottom = -0.007;  // borde inferior visible (m)
uniform float y_line = 0.006;  // borde de abajo de la línea en el eje (m)
uniform float shine_side = 1.0;  // AC.5: lado de los brillos en x (+1: la luz de la vista, LIGHT_ANGLES de body_view.gd)
uniform vec3 shine_color : source_color = vec3(0.98, 0.99, 1.0);

// AC.4: iris y pupila
const float IRIS_TOP_DARK = 0.12;  // arriba casi negro: iris × este valor
const float IRIS_DARK_FROM = 0.42;  // altura visible desde la que oscurece hacia la línea
const float IRIS_LIGHT_GAIN = 1.7;  // abajo claro y saturado: iris × ganancia + mezcla
const float IRIS_LIGHT_MIX = 0.10;
const float IRIS_MOON = 0.55;
const vec2 PUPIL_SIZE = vec2(0.26, 0.24);  // semiejes de la pupila / semiejes del iris
const float PUPIL_SOFT = 0.45;
const float PUPIL_SHADE = 0.35;
// AC.5: brillos (AC.4a): x / a hacia la luz, altura visible s y radio / a (como mucho 12 %)
const vec3 SHINE_MAIN = vec3(0.40, 0.70, 0.12);
const vec3 SHINE_DOT = vec3(-0.32, 0.18, 0.06);

// ==== Común (SH.2b): idéntico en toon_soft.gdshader y eye_layers.gdshader; lo vigila probar_base_ojo.gd ====
const float SHADE_VALUE_LIGHT = 0.78;  // cuánto oscurece un color claro
const float SHADE_VALUE_DARK = 0.92;   // un color oscuro baja menos, para no acabar casi negro
const float SHADE_MIN_DROP = 6.0 / 255.0;  // SH.9: pero baja al menos esto (lo que baja la piel oscura): la tela oscura tiene sombra
const float SHADE_SATURATION = 1.08;  // colores medios y oscuros
const float SHADE_SATURATION_LIGHT = 1.35;  // colores claros: la sombra de la piel clara no debe quedar beige (D47)
const float SHADE_HUE_DEGREES = 5.0;   // hacia el rojo, por el camino corto
const float EDGE_SATURATION = 1.6;  // SH.3c: la banda del borde entre luz y sombra, más saturada que el color
const float EDGE_HUE_DEGREES = 8.0;  // y más girada hacia el rojo que la sombra

varying vec3 shade_ratio;
varying vec3 edge_ratio;  // SH.3c: edge_of(color) / color
varying float gloss_mask;  // SH.3d: 1 donde puede haber brillo (piel con luces), 0 donde no
varying float edge_from;  // X.7: umbral de la luz aquí (threshold; en la cara, threshold - face_light)
varying float band_amount;  // SH.6b: banda de brillo del pelo aquí (0 fuera de ella y en todo lo que no es pelo)
varying float receive;  // SH.4: cuánto oscurece la sombra proyectada aquí (0: nada; 1: hasta el color de sombra)

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
	vec3 shaded = vec3(fract(hsv.x + turn), min(hsv.y * saturation, 1.0), max(min(hsv.z * value, hsv.z - SHADE_MIN_DROP), 0.0));
	return mix(color, to_linear(hsv_to_rgb(shaded)), shade_strength);
}

// SH.3c: color de la banda cálida del borde entre luz y sombra (la luz que «se cuela» bajo la piel): mismo valor que el
// color, más saturado y girado hacia el rojo. Como en shade_of, blanco, gris y negro no cogen matiz.
vec3 edge_of(vec3 color) {
	vec3 hsv = rgb_to_hsv(to_srgb(clamp(color, 0.0, 1.0)));
	float to_red = fract(0.5 - hsv.x) - 0.5;
	float turn = clamp(to_red, -EDGE_HUE_DEGREES / 360.0, EDGE_HUE_DEGREES / 360.0) * min(hsv.y * 4.0, 1.0);
	return to_linear(hsv_to_rgb(vec3(fract(hsv.x + turn), min(hsv.y * EDGE_SATURATION, 1.0), hsv.z)));
}

const float OMNI_FULL = 0.5;  // SH.3a: a partir de esta atenuación una omni o foco da su suelo de sombra entero

void light() {
	float lit = smoothstep(edge_from - softness, edge_from + softness, dot(NORMAL, LIGHT));
	lit *= mix(1.0, smoothstep(0.15, 0.85, ATTENUATION), receive);  // SH.4: sombra proyectada, según receive
	vec3 full = LIGHT_COLOR / PI;
	// La direccional no se apaga con la distancia; omni y foco, sí, sin salto al llegar a su alcance.
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : smoothstep(0.0, OMNI_FULL, ATTENUATION);
	// SH.3b: el rim es luz (sin luz no brilla) y entra en el tono de cada luz, antes del max().
	float rim = smoothstep(1.0 - rim_width, 1.0, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	// SH.3c: la banda vale 1 a mitad del paso de luz a sombra (también en el borde de la sombra proyectada) y 0 fuera.
	float band = 4.0 * lit * (1.0 - lit) * edge_strength;
	vec3 base = mix(shade_ratio, vec3(1.0), lit) * mix(vec3(1.0), edge_ratio, band);
	// SH.3d: brillo suave de piel (D49). Mancha de borde suave alrededor del medio vector, solo en la parte con luz. Aclara
	// el color de la piel por un factor (como mucho ×(1 + gloss_color)): igual de suave en piel clara y oscura.
	float gloss = smoothstep(1.0 - gloss_size - gloss_softness, 1.0 - gloss_size + gloss_softness,
		dot(NORMAL, normalize(LIGHT + VIEW))) * lit * gloss_mask * gloss_strength;
	// SH.6b: la banda del pelo aclara el color del pelo como el brillo de piel, solo donde da la luz.
	vec3 tone = full * (base + rim_color * rim * rim_strength + gloss_color * gloss + hair_band_color * band_amount * lit) * reach;
	// SH.3a: las luces no se suman, manda la más fuerte en cada canal. max() no depende del orden en que Godot
	// evalúa las luces: un contraluz no aclara la cara de delante y dos suelos de sombra no se acumulan.
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, tone);
}
// ==== Fin del común ====

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.xyz -= normalize(view.xyz) * depth_pull;
	POSITION = PROJECTION_MATRIX * view;
}

// Color y cobertura del iris: abajo, media elipse de semieje fijo; arriba, otra hasta lo alto del iris entero.
vec4 iris_layer(vec2 p) {
	vec2 axes = iris_axes * iris_size;
	float low = low_b * iris_size;
	float bottom = iris_center.y - axes.y;
	float waist = bottom + low;
	float top_b = max(iris_center.y + axes.y - waist, 0.0001);
	vec2 q = vec2((p.x - iris_center.x) / axes.x, (p.y - waist) / (p.y < waist ? low : top_b));
	float r = length(q);
	float aa = max(fwidth(r), 0.0001);
	float s = (p.y - y_bottom) / (y_line - y_bottom);
	float t = clamp((p.y - bottom) / (2.0 * axes.y), 0.0, 1.0);
	vec3 bright = min(iris_color * IRIS_LIGHT_GAIN + vec3(IRIS_LIGHT_MIX), vec3(1.0));
	vec3 c = mix(bright, iris_color, smoothstep(0.08, 0.55, t));
	float moon_in = 1.0 - smoothstep(0.80, 0.94, length((q - vec2(0.0, 0.32)) / vec2(0.92, 1.0)));
	float moon = (1.0 - smoothstep(0.86, 0.97, r)) * (1.0 - moon_in) * smoothstep(0.05, -0.45, q.y);
	c = mix(c, min(bright * 1.2 + vec3(0.06), vec3(1.0)), moon * IRIS_MOON);
	float pupil = 1.0 - smoothstep(1.0 - PUPIL_SOFT, 1.0, length((p - iris_center) / axes / PUPIL_SIZE));
	c = mix(c, iris_color * PUPIL_SHADE, pupil);
	c = mix(c, iris_color * IRIS_TOP_DARK, smoothstep(IRIS_DARK_FROM, 0.98, s));
	c = mix(c, iris_color * 0.30, smoothstep(0.88, 1.0, r) * 0.7);
	return vec4(c, 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r));
}

// 1 dentro del círculo de radio radius alrededor de center (en metros), con el borde suavizado un píxel.
float disc(vec2 p, vec2 center, float radius) {
	float d = length(p - center);
	float aa = max(fwidth(d), 0.000001);
	return 1.0 - smoothstep(radius - aa, radius + aa, d);
}

// AC.5: un brillo grande arriba, hacia la luz, y un punto pequeño abajo, al otro lado. Crecen con el iris.
float shine_layer(vec2 p) {
	float a = iris_axes.x * iris_size;
	float span = y_line - y_bottom;
	vec2 big_at = vec2(iris_center.x + shine_side * SHINE_MAIN.x * a, y_bottom + SHINE_MAIN.y * span);
	vec2 dot_at = vec2(iris_center.x + shine_side * SHINE_DOT.x * a, y_bottom + SHINE_DOT.y * span);
	return max(disc(p, big_at, SHINE_MAIN.z * a), disc(p, dot_at, SHINE_DOT.z * a));
}

void fragment() {
#ifdef EYE_IRIS
	vec4 iris = iris_layer(UV);
	vec3 color = mix(iris.rgb, shine_color, shine_layer(UV));
	ALPHA = iris.a;
#else
	vec3 color = mix(white_color, white_shadow, smoothstep(white_shadow_from, 1.0, UV2.x));
#endif
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	shade_ratio = shade_of(color) / max(color, vec3(0.0001));
	edge_ratio = edge_of(color) / max(color, vec3(0.0001));
	gloss_mask = 0.0;
	receive = shadow_receive;
	edge_from = threshold;
	band_amount = 0.0;
	ALBEDO = color;
}
