# SH.2 — Shader anime en el núcleo, apagado, con la sombra calculada

> Ficha del 2026-11-22 (nivel: medio). **Cerrada el 2026-11-22:** el responsable aprueba la sombra de las hojas de `pruebas/capturas/shader_sh2/`. Cambio respecto al diseño inicial: la saturación sube a 1,35 solo en colores claros, porque la piel clara quedaba beige y con 1,35 en todos fallaba la piel oscura. Decisiones: D47 y D48 en `ruta/DECISIONES.md`.

## 1. Objetivo y «Hecho cuando»

Añadir al núcleo el shader de la columna anime, apagado por defecto, con un color de sombra calculado desde el color de cada zona.

Hecho cuando:

- Con el interruptor apagado, las 6 capturas aprobadas no cambian (límite actual: 0,1 %).
- Con el interruptor encendido, cuerpo y piezas usan el shader nuevo y `unlit` funciona.
- `probar_toon_soft.gd` termina en `RESULTADO: TODO BIEN` en Forward+ y en Mobile.
- El responsable ha mirado la hoja y decide si desaparecen las sombras rosas y rojo-naranja.

## 2. Nivel de modelo

Medio: cambia un shader sin cambiar el aspecto por defecto, con la fórmula y las firmas ya escritas y comprobadas. Modelo recomendado: barato (Sonnet 5.5). Si una prueba existente falla sin motivo claro, parar y avisar.

## 3. Contexto mínimo

- `godot/addons/creador/body_material.gd` entero.
- `godot/addons/creador/toon.gdshader`.
- `pruebas/godot/estilo/toon_suave.gdshader` y `contorno_tenido.gdshader`.
- `pruebas/godot/capturar_hoja_shader.gd`: se copian de aquí `_dress`, `_capture`, `_shot`, `_set_shadow` y `_save_sheet`.
- `pruebas/godot/probar_material.gd:74-87`: cómo comparar los `uniform` con los valores del código.

## 4. Archivos

- **Se crean:** `godot/addons/creador/toon_soft.gdshader` y `pruebas/godot/probar_toon_soft.gd` (prueba y hoja, con ventana).
- **Se cambia:** `godot/addons/creador/body_material.gd`.
- **Al cerrar:** `PLAN.md`, solo después de confirmar con el responsable que la otra sesión terminó de editarlo.
- **No se tocan:** `toon.gdshader`, `outline.gdshader`, `preset.gd`, `finish_panel.gd`, `glb_exporter.gd`, `body_view.gd`, las capturas aprobadas ni los límites de otras pruebas.

## 5. Diseño

### Shader `toon_soft.gdshader`

Sin `vertex()` propio, porque `piece_shader()` inserta el suyo delante de `void fragment()`. La luz ambiente sigue desactivada hasta SH.3.

```glsl
// Paso SH.2: toon anime. Sombra calculada desde el color de cada zona (D48). Apagado por defecto (BodyMaterial.soft_enabled).
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

void light() {
	float lit = smoothstep(threshold - softness, threshold + softness, dot(NORMAL, LIGHT));
	lit *= smoothstep(0.15, 0.85, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shade_ratio, vec3(1.0), lit);
}
```

### Medida previa de la fórmula

Medida el 2026-11-22 en Forward+ y Mobile sobre una esfera con una luz. Valores en sRGB de Forward+. Mobile difiere como mucho 0,7° de matiz y 0,01 de saturación. «Antes» es el tinte fijo de SH.1, calculado.

| Color | Luz (matiz, sat.) | Sombra antes | Sombra ahora |
| --- | --- | --- | --- |
| Piel clara | 23,3°, 0,27 | 11,5°, 0,43 | 18,2°, 0,29 |
| Piel media | 22,8°, 0,50 | 15,0°, 0,62 | 18,5°, 0,54 |
| Piel oscura | 18,0°, 0,53 | 11,9°, 0,68; luminancia ×0,73 | 14,6°, 0,59; luminancia ×0,84 |
| Ropa blanca | 60,0°, 0,04 | 6,8°, 0,25 | 60,0°, 0,04 |
| Azul de fantasía | 216,1°, 0,59 | — | 220,9°, 0,63 |
| Verde de fantasía | 128,8°, 0,50 | — | 123,2°, 0,54 |

### Interruptor en `body_material.gd`

```gdscript
const SOFT_SHADER := preload("toon_soft.gdshader")
const SOFT_DEFAULTS := {
	"skin_color": Color(0.80, 0.80, 0.80), "garment_color": Color(0.20, 0.20, 0.23), "show_garment": true, "unlit": false,
	"threshold": 0.05, "softness": 0.09, "shade_strength": 1.0, "ground_weight": 0.025,
	"rim_color": Color(1.0, 0.95, 0.92), "rim_strength": 0.075, "rim_width": 0.3, "detail_amount": 0.0}
static var soft_enabled := false  # interruptor interno (SH.2), sin interfaz; se lee al crear el material
static var _soft_piece_shader: Shader

static func body_shader() -> Shader   # SOFT_SHADER si soft_enabled; si no, SHADER
static func piece_shader() -> Shader  # copia con PULL_CODE del shader activo; cada una se crea una sola vez
```

Cambios, y ninguno más:

1. `apply()`: usa `body_shader()` y pone `SOFT_DEFAULTS` o `DEFAULTS` según el interruptor.
2. `piece_shader()`: devuelve `_soft_piece_shader` si `soft_enabled`.
3. `_parameter()`: `ours` también acepta `SOFT_SHADER` y `_soft_piece_shader`.
4. `get_outline_width()`: acepta también `SOFT_SHADER`. **No** empieza a aceptar piezas, porque cambiaría lo que hace hoy con el interruptor apagado.

`default_finish()`, `standalone()` y `FINISH` no cambian. Los presets se tratan en SH.7 y el `.tres` en SH.5.

### Hoja

En `pruebas/capturas/shader_sh2/`: `hoja_cuerpo.png` y `hoja_cara.png`, con las cámaras de SH.1, celdas de 420 × 560 px y sombra proyectada activa.

- **Columnas:** A = anime de SH.1 (`toon_suave`, tinte fijo (0,92; 0,72; 0,72)). B = `toon_soft` (sombra calculada). Ambas con `contorno_tenido` × (0,45; 0,30; 0,30) y 1,25 px.
- **Filas** (colores sRGB):

| Preset | Piel | Pelo | Ropa |
| --- | --- | --- | --- |
| `anime` | Clara (0,96; 0,80; 0,70) | `makehuman/toigo_blunt_bob_with_bangs`, verde (0,20; 0,55; 0,35) | Negra (0,10; 0,10; 0,11) |
| `femenino` | Oscura (0,30; 0,19; 0,14) | `quaternius/hair_long`, castaño (0,30; 0,20; 0,15) | Azul grisácea (0,28; 0,33; 0,45) |
| `masculino` | Media (0,72; 0,50; 0,36) | `makehuman/short02`, rubio (0,62; 0,46; 0,22) | Blanca (0,85; 0,85; 0,82) |
| `anime` | Fantasía azul (0,35; 0,55; 0,85) | `makehuman/short02`, azul oscuro (0,16; 0,20; 0,42) | Blanca (0,85; 0,85; 0,82) |

Poner `soft_enabled = true` **antes** de crear `BodyView`. Después de cada preset, volver a poner los valores de la base con `set_finish`, porque el preset trae `softness` 0,04 y `rim_strength` 0,25.

## 6. Prueba

**Uso:** `(ulimit -v 4000000; timeout 300 godot [--rendering-method mobile] --path pruebas/godot -s probar_toon_soft.gd 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')`. Necesita ventana. La hoja solo se guarda en Forward+.

**Interruptor:** por defecto está apagado y `apply()` da `SHADER`. Encendido, da `SOFT_SHADER`, y la pieza lleva `depth_pull`. `SOFT_DEFAULTS` coincide con los `uniform` del shader, ni uno más ni uno menos. `unlit` devuelve el color exacto.

**Color**, sobre una esfera con una luz, en Forward+ y Mobile. Límites `# PROVISIONAL`, con la medida en la tabla de arriba:

| Comprobación | Límite | Medido |
| --- | --- | --- |
| La parte iluminada conserva el color | ± 3/255 | ≤ 1/255 |
| Blanco, gris y negro siguen neutros en sombra | máx − mín ≤ 2/255 | 0 |
| Ropa blanca sin rosa | R − G ≤ 2/255 y saturación + ≤ 0,02 | 0 y 0 |
| Pieles y fantasía: el matiz gira hacia el rojo | de 2° a 8° | 3,4–5,6° |
| Pieles y fantasía: sombra más oscura y más saturada | sombra < luz y saturación mayor | Se cumple |
| Piel oscura no casi negra | luminancia sRGB sombra ÷ luz ≥ 0,80 | 0,84 |
| Piel media sin rojo-naranja saturado | saturación de sombra ≤ 0,58 | 0,54 |
| `shade_strength = 0` | sombra = luz ± 3/255 | 0 |

**Con el interruptor apagado** (no cambia nada):

```sh
sh pruebas/fase_5/capturas_de_referencia.sh <scratchpad>/sh2_ref 2>&1 | grep -E 'ERROR'
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s comparar_capturas.gd -- pruebas/capturas/aprobadas <scratchpad>/sh2_ref <scratchpad>/sh2_dif 2>&1 | grep -E 'MEDIDA|AVISO|FALLO|RESULTADO')
```

Además, `probar_material`, `probar_acabado` y `probar_presets`, porque usan `body_material.gd`.

**Que detecta el fallo** (romper, ver el `FALLO` y deshacer):

- `soft_enabled := true` por defecto → falla el interruptor.
- Multiplicar `shade_ratio` por `vec3(0.83, 0.48, 0.48)` → fallan los neutros y la ropa blanca.
- `SHADE_VALUE_DARK = 0.70` → falla la piel oscura.

## 7. Trampas conocidas

- **Colores puros:** el motor multiplica la luz por `ALBEDO`, así que un canal a 0 no puede subir: rojo o azul puros se oscurecen, pero no giran. Se mantiene `ALBEDO`, porque SH.3 lo necesita para la luz ambiente.
- **Ropa negra:** la sombra casi no se distingue de la luz. No se corrige aquí: se revisa en la hoja de SH.7 (D48).
- **Varias luces:** se suman como en el MVP y una luz a contraluz todavía aclara. Lo arregla SH.3, igual que la omni lejana.
- **Escalera y nariz:** se seguirán viendo en la hoja. Son de SH.4.
- **Compatibility:** con el borrador anterior de la fórmula dio una sombra algo distinta. No es renderizador del proyecto: no se ajusta a él.
- **`soft_enabled`:** es estático y se lee al crear el material. Cambiarlo no convierte los materiales ya creados.
- **`varying`:** se escribe en `fragment()` y se lee en `light()`. Comprobado en Forward+ y Mobile.

## 8. Juicio visual

Dar solo las rutas de `hoja_cuerpo.png` y `hoja_cara.png`, sin describirlas ni valorarlas. Preguntas:

1. ¿Han desaparecido las sombras rojo-naranja, las manchas rosas en la ropa blanca y la sombra casi negra en la piel oscura?
2. ¿La sombra de la piel azul se ve bien?
3. ¿Cambio la fuerza o alguna de las cuatro constantes de la sombra?

## 9. Si te atascas

Si las capturas aprobadas cambian con el interruptor apagado, o falla una prueba existente, para y dilo. No cambies límites ni salgas de los archivos del apartado 4.
