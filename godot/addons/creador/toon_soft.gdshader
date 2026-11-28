// Paso SH.2: toon anime. Sombra calculada desde el color de cada zona (D48). Apagado por defecto (BodyMaterial.soft_enabled).
// El bloque «Común» se comparte con eye_layers.gdshader (SH.2b): si se cambia aquí, se cambia igual allí.
shader_type spatial;
render_mode specular_disabled;  // SH.3b: sin ambient_light_disabled, la luz ambiente de la escena se suma (D48 c)

uniform vec3 skin_color : source_color = vec3(0.80, 0.80, 0.80);
uniform vec3 garment_color : source_color = vec3(0.20, 0.20, 0.23);
uniform vec3 mouth_color : source_color = vec3(0.03, 0.02, 0.02);  // 9.8b (D58): interior de la boca (verde del color = 0)
uniform bool show_garment = true;
uniform bool unlit = false;
uniform float threshold : hint_range(-1.0, 1.0) = 0.05;
uniform float softness : hint_range(0.0, 0.5) = 0.09;
uniform float shade_strength : hint_range(0.0, 1.0) = 1.0;
uniform float ground_weight : hint_range(0.0, 1.0) = 0.025;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.92);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.075;
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;
uniform float edge_strength : hint_range(0.0, 1.0) = 0.0;  // SH.3c: banda cálida entre luz y sombra; 0 = apagada
uniform float gloss_strength : hint_range(0.0, 1.0) = 0.0;  // SH.3d: brillo suave de la piel (no en la prenda); 0 = apagado
uniform float gloss_size : hint_range(0.0, 0.5) = 0.05;
uniform float gloss_softness : hint_range(0.0, 0.5) = 0.05;
uniform vec3 gloss_color : source_color = vec3(1.0, 0.96, 0.94);
// SH.8: zonas de la piel (datos/humana/piel.png; FORMATO.md). Sin textura (negro) no hay rubor, labios ni pecas.
uniform sampler2D skin_zones : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform float blush_amount : hint_range(0.0, 1.0) = 0.0;  // rubor; su color sale de la piel
uniform float lips_amount : hint_range(0.0, 1.0) = 0.0;  // labios; su color sale de la piel
uniform float freckles : hint_range(0.0, 10.0, 1.0) = 0.0;  // SH.8b: 0 = sin pecas; 1 = pocas en la cara ... 10 = todo el cuerpo
uniform float shadow_receive : hint_range(0.0, 1.0) = 1.0;  // SH.4: sombra proyectada que recibe; 0 = ninguna
uniform float face_shadow_receive : hint_range(0.0, 1.0) = 1.0;
uniform float face_light : hint_range(0.0, 0.5) = 0.0;
// SH.6b: banda de brillo del pelo («anillo»). Altura: la de la dirección del centro de la cabeza al punto, en el sistema
// del hueso de la cabeza (hair_head: mundo → cabeza, con origen en su centro; lo pone la vista cada fotograma). Fuerza 0
// salvo en piezas de pelo.
uniform float hair_band_strength : hint_range(0.0, 2.0) = 0.0;
uniform float hair_band_height : hint_range(-1.0, 1.0) = 0.55;
uniform float hair_band_width : hint_range(0.0, 0.5) = 0.07;
uniform float hair_band_softness : hint_range(0.0, 0.5) = 0.05;
uniform vec3 hair_band_color : source_color = vec3(1.0, 0.98, 0.95);
uniform mat4 hair_head = mat4(1.0);  // X.7: baja el umbral en la cara (más cara con luz); 0 = como el cuerpo  // SH.4: y en la cara (canal A de skin_zones), × la de arriba
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float detail_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D hide_mask : hint_default_transparent, filter_nearest, repeat_disable;  // 12.1b: piel bajo la ropa
uniform sampler2D base_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;  // 13.3h: textura de la pieza

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

// ---- SH.8: rubor, labios y pecas (solo la piel; el ojo no los usa) ----
const float FRECKLE_CELLS = 240.0;  // celdas por unidad de UV (la cara tiene el doble de UV por metro: pecas más finas)
const float FRECKLE_FIRST = 0.035;  // alcance del nivel 1 (fracción de 1,7 m desde el centro de la cara): nariz y mejillas
const float FRECKLE_OPACITY = 0.6;  // nada exagerado

// Un color hermano del de la piel: girado hacia `hue` (vueltas) como mucho `turn_degrees`, con la saturación y el valor
// multiplicados. Como en shade_of, los colores casi neutros no cogen matiz.
vec3 tint_of(vec3 color, float hue, float turn_degrees, float saturation, float value) {
	vec3 hsv = rgb_to_hsv(to_srgb(clamp(color, 0.0, 1.0)));
	float to_hue = fract(hue - hsv.x + 0.5) - 0.5;
	float turn = clamp(to_hue, -turn_degrees / 360.0, turn_degrees / 360.0) * min(hsv.y * 4.0, 1.0);
	return to_linear(hsv_to_rgb(vec3(fract(hsv.x + turn), min(hsv.y * saturation, 1.0), hsv.z * value)));
}

vec3 hash3(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yxz + 33.33);
	return fract((q.xxy + q.yzz) * q.zyx);
}

// Cuánto tapa una peca este punto (0–1). near: canal G de skin_zones. El nivel N llega hasta la distancia
// FRECKLE_FIRST · (1 / FRECKLE_FIRST)^((N - 1) / 9): 1 = nariz y mejillas, 3 = la cara, 5 = cuello y pecho, 10 = todo.
// Más lejos del centro, menos pecas, y el nivel 1 lleva la mitad que el 10. Cuando una peca ocupa menos de un píxel, se apaga en vez de parpadear.
float freckle_cover(vec2 uv, float near) {
	if (freckles < 0.5 || near <= 0.0) {
		return 0.0;
	}
	float order = (1.0 - near) * (1.0 - near);
	float reach = FRECKLE_FIRST * pow(1.0 / FRECKLE_FIRST, (freckles - 1.0) / 9.0);
	float zone = 1.0 - smoothstep(reach * 0.7, reach, order);
	vec2 p = uv * FRECKLE_CELLS;
	float fade = 1.0 - smoothstep(0.3, 0.6, max(fwidth(p.x), fwidth(p.y)));
	if (zone * fade <= 0.0) {
		return 0.0;
	}
	float density = mix(0.35, 0.12, clamp(order / reach, 0.0, 1.0)) * mix(0.5, 1.0, (freckles - 1.0) / 9.0);  // nivel 1: pocas
	vec2 cell = floor(p);
	float cover = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 here = cell + vec2(float(x), float(y));
			vec3 h = hash3(here);
			if (h.z < density) {
				float radius = mix(0.14, 0.28, fract(h.z * 17.0));
				float d = length(p - (here + 0.2 + 0.6 * h.xy));
				float edge = max(fwidth(d), 0.02);
				cover = max(cover, (1.0 - smoothstep(radius - edge, radius + edge, d)) * mix(0.5, 1.0, fract(h.x * 7.0)));
			}
		}
	}
	return cover * zone * fade * FRECKLE_OPACITY;
}

// SH.9: ningún color baja de DARK_FLOOR de valor (sRGB), con el mismo matiz y saturación; los demás no cambian. Así el
// negro puro se lee gris muy oscuro (D47) y la línea (casi 0) se distingue. Más de 14/255 movería el negro 0,05 de SH.2.
const float DARK_FLOOR = 14.0 / 255.0;

vec3 floor_dark(vec3 color) {
	vec3 hsv = rgb_to_hsv(to_srgb(clamp(color, 0.0, 1.0)));
	return hsv.z < DARK_FLOOR ? to_linear(hsv_to_rgb(vec3(hsv.xy, DARK_FLOOR))) : color;
}

void fragment() {
	if (texture(hide_mask, UV).a > 0.5) { discard; }
	float garment = show_garment ? step(0.5, min(COLOR.r, COLOR.a)) : 0.0;
	vec3 color = mix(skin_color, garment_color, garment) * texture(base_tex, UV).rgb;
	vec4 all_zones = texture(skin_zones, UV);
	vec3 zones = all_zones.rgb;  // SH.8: solo en la piel, nunca en la prenda
	receive = shadow_receive * mix(face_shadow_receive, 1.0, all_zones.a);  // A: 0 en la cara (sin textura, 1)
	edge_from = threshold - face_light * (1.0 - all_zones.a);
	band_amount = 0.0;
	if (hair_band_strength > 0.0 && !unlit) {
		vec3 local = (hair_head * vec4((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, 1.0)).xyz;
		float off = abs(normalize(local).y - hair_band_height);
		band_amount = hair_band_strength * (1.0 - smoothstep(hair_band_width - hair_band_softness,
			hair_band_width + hair_band_softness, off)) * smoothstep(0.0, 0.35, dot(NORMAL, VIEW));
	}
	float skin = 1.0 - garment;
	color = mix(color, tint_of(color, 0.97, 12.0, 1.45, 0.96), zones.r * blush_amount * skin);  // hacia el rosa
	color = mix(color, tint_of(color, 0.98, 14.0, 1.6, 0.85), zones.b * lips_amount * skin);
	color = mix(color, tint_of(color, 0.07, 10.0, 1.35, 0.72), freckle_cover(UV, zones.g) * skin);  // hacia el marrón
	color = mix(color, mouth_color, (1.0 - COLOR.g) * skin);  // 9.8b (D58): el verde es 0 en la bolsa de la boca
	if (detail_amount > 0.0) {
		color *= mix(vec3(1.0), texture(detail_tex, UV).rgb / 0.266, detail_amount);
	}
	color = floor_dark(color);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	shade_ratio = shade_of(color) / max(color, vec3(0.0001));
	edge_ratio = edge_of(color) / max(color, vec3(0.0001));
	gloss_mask = unlit ? 0.0 : 1.0 - garment;
	if (unlit) {
		ALBEDO = vec3(0.0);
		EMISSION = color;
	} else {
		vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
		ALBEDO = color * (1.0 - ground_weight * (0.5 - 0.5 * world_normal.y));
	}
}
