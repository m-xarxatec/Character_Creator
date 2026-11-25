// Paso AC.6a: líneas del ojo sobre sus tiras de malla (EyeMesh): línea de arriba con 3 pestañas (mode 0), pliegue (1) y
// línea de abajo, casi negra (2). Valores de AC.4a (pruebas/capturas/ac3/ac4a/medidas.md). AC.6c: ceja (3), dibujada
// dentro de su banda (UV.x de 0 a 1, de dentro afuera; UV.y en metros sobre la base de la banda); serie: «arco suave»
// de AC.6c.0. brow_lift, brow_thickness y brow_size son los deslizadores (AC.6c.4).
// UV.x = u por longitud de arco (0 esquina interior, 1 exterior; la cola de las pestañas llega a ~1,08).
// UV.y = fila, en metros (+ hacia fuera del lazo), vista de frente: Blender apoya las filas por la normal del ojo. No hace
// falta corregirla con la superficie (d = v / |∇v|, AC.3b §5.2 d): con las filas de dentro apoyadas en el blanco, el grosor
// cambia como mucho un 7 % en los extremos (probar_linea_ojo.gd), y la corrección lo afinaba de frente.
// La luz es la de toon_soft (D48), sin emisión propia: el bloque «Común» es idéntico al suyo (SH.2b, lo vigila probar_linea_ojo.gd).
shader_type spatial;
render_mode specular_disabled, cull_disabled;

uniform int mode = 0;
uniform float depth_pull = 0.00018;
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float softness : hint_range(0.0, 0.5) = 0.09;
uniform float shade_strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.92);  // los usa el light() común; las líneas, sin rim
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;
uniform float shadow_receive : hint_range(0.0, 1.0) = 1.0;
uniform vec3 hair_band_color : source_color = vec3(1.0, 0.98, 0.95);
uniform float edge_strength : hint_range(0.0, 1.0) = 0.0;
uniform float gloss_strength : hint_range(0.0, 1.0) = 0.0;
uniform float gloss_size : hint_range(0.0, 0.5) = 0.05;
uniform float gloss_softness : hint_range(0.0, 0.5) = 0.05;
uniform vec3 gloss_color : source_color = vec3(1.0, 0.96, 0.94);
uniform vec3 line_color : source_color = vec3(0.18, 0.07, 0.08);  // burdeos muy oscuro
uniform float arc_length = 0.0374;  // m: para que las pestañas tengan forma en metros (EyeMesh lo pone por tira)
uniform float w_inner = 0.00015;  // grosor de la línea de arriba en la esquina interior (m)
uniform float w_peak = 0.0030;  // y en su pico
uniform float u_peak = 0.80;
uniform float inward = 0.85;  // parte del grosor hacia dentro del lazo
uniform float fade_u = 0.22;  // se apaga entre fade_u · 0,3 y fade_u
uniform float tail_end = 1.05;  // tras la esquina se afina hasta aquí
uniform float corner = 0.30;  // grosor en la esquina (u = 1) respecto al pico
uniform vec3 lash_u = vec3(0.94, 0.99, 1.035);
uniform vec3 lash_length = vec3(0.0008, 0.0011, 0.0008);
uniform float lash_width = 0.0005;
uniform float lash_tilt = 0.9;  // hacia la esquina exterior por cada metro de largo
uniform float crease_offset = 0.0022;
uniform float crease_width = 0.00016;
uniform float crease_alpha = 0.22;
uniform vec2 crease_span = vec2(0.25, 0.85);
uniform vec3 lower_color : source_color = vec3(0.04, 0.03, 0.04);
uniform float lower_peak = 0.0010;  // grosor máximo de la línea de abajo, centrada en el lazo
uniform float lower_u_peak = 0.76;
uniform float lower_start = 0.12;  // invisible antes de aquí
uniform float lower_end = 0.30;  // grosor en la esquina exterior respecto al pico
uniform vec3 brow_color : source_color = vec3(0.25, 0.16, 0.12);  // AC.6c: castaño oscuro (D-a)
uniform float brow_height = 0.0075;  // m sobre la base de la banda: la línea central en los extremos
uniform float brow_arch = 0.0015;  // m que sube el centro respecto a los extremos
uniform float brow_tilt = 0.0;  // m que sube el extremo exterior respecto al interior
uniform float brow_width = 0.0014;  // grosor máximo (m)
uniform float brow_inner_w = 0.85;  // grosor en el extremo interior, en partes del máximo
uniform float brow_outer_w = 0.15;  // y en el exterior (la cola se afila)
uniform float brow_start = 0.1774;  // dónde empieza y acaba en u
uniform float brow_end = 0.7815;
uniform float brow_lift = 0.0;  // deslizador Altura (m)
uniform float brow_thickness = 1.0;  // deslizador Grosor (× brow_width)
uniform float brow_size = 1.0;  // deslizador Tamaño (× el largo, alrededor de su centro)

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

float line_width(float u) {
	float w = mix(w_inner, w_peak, smoothstep(0.0, u_peak, u));
	w *= 1.0 - (1.0 - corner) * smoothstep(u_peak, 1.0, u);  // se afila hacia la esquina
	return w * (1.0 - smoothstep(1.0, tail_end, u));
}

float lower_width(float u) {
	float w = lower_peak * smoothstep(lower_start, lower_u_peak, u);
	return w * (1.0 - (1.0 - lower_end) * smoothstep(lower_u_peak, 1.0, u));
}

// AC.6c: posición dentro de la ceja (0 en su extremo interior, 1 en el exterior).
float brow_t(float u) {
	float half_len = 0.5 * (brow_end - brow_start) * brow_size;
	return (u - 0.5 * (brow_start + brow_end) + half_len) / (2.0 * half_len);
}

float brow_center(float t) {
	return brow_height + brow_lift + brow_arch * 4.0 * t * (1.0 - t) + brow_tilt * (t - 0.5);
}

float brow_w(float t) {
	return brow_width * brow_thickness * mix(brow_inner_w, 1.0, smoothstep(0.0, 0.35, t))
		* mix(1.0, brow_outer_w, smoothstep(0.55, 1.0, t));
}

float band(float d, float low, float high) {
	float aa = max(fwidth(d), 0.0000001);
	return smoothstep(low - aa, low + aa, d) * (1.0 - smoothstep(high - aa, high + aa, d));
}

float lash(float u, float d, float at, float len) {
	float base = (1.0 - inward) * line_width(at) * 0.5;
	float h = (d - base) / len;
	float along = (u - at) * arc_length - lash_tilt * (d - base);
	float half_w = lash_width * 0.5 * (1.0 - h);
	float aa = max(fwidth(along), 0.0000001);
	return step(0.0, h) * step(h, 1.0) * (1.0 - smoothstep(half_w - aa, half_w + aa, abs(along)));
}

void fragment() {
	float u = UV.x;
	float d = UV.y;
	float alpha;
	vec3 color = line_color;
	if (mode == 0) {
		float w = line_width(u);
		alpha = band(d, -inward * w, (1.0 - inward) * w) * smoothstep(fade_u * 0.3, fade_u, u);
		for (int i = 0; i < 3; i++) {
			alpha = max(alpha, lash(u, d, lash_u[i], lash_length[i]));
		}
	} else if (mode == 2) {
		float w = lower_width(u);
		alpha = band(d, -0.5 * w, 0.5 * w) * smoothstep(lower_start, lower_start + 0.08, u);
		color = lower_color;
	} else if (mode == 3) {
		float t = brow_t(u);
		float half_w = 0.5 * brow_w(t);
		alpha = band(d - brow_center(t), -half_w, half_w) * band(t, 0.0, 1.0);  // los extremos, suavizados en u
		color = brow_color;
	} else {
		float half_c = crease_width * 0.5;
		alpha = band(d, crease_offset - half_c, crease_offset + half_c) * crease_alpha
			* smoothstep(crease_span.x - 0.1, crease_span.x, u) * (1.0 - smoothstep(crease_span.y, crease_span.y + 0.1, u));
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	shade_ratio = shade_of(color) / max(color, vec3(0.0001));
	edge_ratio = edge_of(color) / max(color, vec3(0.0001));
	gloss_mask = 0.0;
	receive = shadow_receive;
	edge_from = threshold;
	band_amount = 0.0;
	ALBEDO = color;
	ALPHA = alpha;
}
