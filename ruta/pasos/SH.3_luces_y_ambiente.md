# SH.3 — Luces correctas y luz ambiente en `toon_soft`

> **Hecha el 2026-11-23 (SH.3a y SH.3b), pendiente del juicio visual de §8.** Cambio respecto a esta ficha: también se toca `godot/addons/creador/eye_layers.gdshader` (la ficha es anterior al ojo de AC.3c): su `light()` debe ser idéntico al de `toon_soft` (SH.2b) y recibe el mismo ambiente que la piel, con `rim_strength` 0. Medidas en el registro de `PLAN.md`; todas las previstas coinciden.

> Ficha del 2026-11-22 (nivel: medio, en dos subpasos). **Aprobada por el responsable el 2026-11-22**, aceptando que las luces de frente no se suman (manda la más fuerte), que a oscuras se vea el contorno hasta SH.4b y que los juegos usen ambiente de color plano (`AMBIENT_SOURCE_COLOR`), sin el plan B. Escrita sin ejecutar nada (hay una batería corriendo): toda medida que no estaba ya en los documentos va marcada **POR MEDIR** y toda función de Godot sin comprobar, **NO VERIFICADO**. Decisiones: D47 y D48 (opción c) en `ruta/DECISIONES.md`. Parte del cierre de SH.2.

## 1. Objetivo y «Hecho cuando»

Que `toon_soft` se porte bien con varias luces y con luz ambiente: las luces no se suman (manda la más fuerte, sin depender del orden), una omni se apaga con la distancia y el juego decide la oscuridad con su `WorldEnvironment`. El aspecto del editor con su luz por defecto no cambia.

Dos subpasos, cada uno con su propuesta y su «OK»:

- **SH.3a, luces.** Solo cambia `light()`. Hecho cuando:
  - Un contraluz no cambia la cara de delante (≤ 1/255).
  - El resultado no depende del orden en que Godot evalúa las luces: principal + contraluz da el mismo color en los dos órdenes (≤ 1/255).
  - Las luces **no se suman**: en cada píxel y canal manda la más fuerte (`max()`). Dos luces a contraluz dan lo mismo que una, y dos luces de frente dan lo que da la más fuerte (el MVP las sumaba). Motivo: con un solo acumulador (`DIFFUSE_LIGHT`) no se puede tener a la vez «las luces de frente suman» y «el contraluz no cambia nada» sin que el resultado dependa del orden, y Godot no garantiza ese orden.
  - Una omni se apaga con la distancia, sin salto al llegar a su alcance.
  - Con una sola luz direccional, con y sin sombra, el aspecto es el de SH.2 (≤ 0,1 % de píxeles distintos).
- **SH.3b, ambiente.** Hecho cuando:
  - Sin `ambient_light_disabled`, la luz ambiente de la escena se suma como color plano.
  - Sin luz y sin ambiente, nada brilla (el rim pasa de `EMISSION` a `light()`).
  - El editor, con su ambiente ajustado, se ve como en SH.2 (medido).
  - `unlit` sigue dando el color exacto aunque haya ambiente.

Ambos: `probar_luces.gd` termina en `RESULTADO: TODO BIEN` en Forward+ y en Mobile, y `probar_toon_soft.gd` sigue en `TODO BIEN`.

## 2. Nivel de modelo

- **SH.3a:** medio. Modelo recomendado: barato (Sonnet 5.5). La fórmula está escrita y, para una luz direccional, es idéntica a la de SH.2 (se demuestra abajo). Usa `LIGHT_IS_DIRECTIONAL` (**NO VERIFICADO**): el paso 0 de §5 lo comprueba antes de seguir. Si no compila, parar (GUIA §3, señal 3).
- **SH.3b:** medio con tres puntos **NO VERIFICADO** (§5, «Ambiente»). Modelo recomendado: barato (Sonnet 5.5) mientras las medidas coincidan con lo previsto; si el ambiente no se comporta como se espera (no multiplica por el albedo, o entra en `DIFFUSE_LIGHT` antes de `light()`), **parar y pasar a Opus 5.5 en high**.

## 3. Contexto mínimo

- `godot/addons/creador/toon_soft.gdshader` (83 líneas) y `pruebas/godot/probar_toon_soft.gd`: de aquí se copian `_make_sphere`, `_pixel`, `_dress`, `_capture`, `_shot`, `_set_shadow`, `_save_sheet`, `_check`, `_wait`.
- `pruebas/godot/capturar_hoja_shader.gd:34-36` y `:115-125`: la escena omni (`OMNI_COLOR`, `OMNIS`, `_add_omnis`) y `:198-215` (`_omni_shot`).
- `godot/app/body_view.gd:412-424` (`_add_world`: ambiente blanco, energía 0,4, luz direccional con energía 1 por defecto en `main.gd:80`).
- `pruebas/godot/capturar_ventana.gd:84`: cómo se alcanza el `Environment` del editor: `view.viewport.find_children("*", "WorldEnvironment", false, false)[0].environment`.
- `ruta/pasos/SH.2_shader_en_nucleo.md` §5 y §7 (fórmula, trampas «Varias luces» y «Colores puros»).

## 4. Archivos

| Subpaso | Se crean | Se cambian |
| --- | --- | --- |
| SH.3a | `pruebas/godot/probar_luces.gd`, `pruebas/godot/estilo/toon_soft_sh2.gdshader` (copia exacta del actual, congelada como referencia) | `godot/addons/creador/toon_soft.gdshader`, `eye_layers.gdshader` (bloque común, SH.2b) |
| SH.3b | — | `toon_soft.gdshader`, `eye_layers.gdshader` (sin `ambient_light_disabled`; `rim_*` con fuerza 0), `godot/app/body_view.gd` (una línea), `probar_luces.gd` |

- **Al cerrar cada subpaso:** `PLAN.md` (marcar, «Estado actual», una fila de registro), solo después de confirmar con el responsable que otra sesión no lo está editando. Al cerrar SH.3b, además una línea en `diseno/GUIA_ESTILO.md`: el juego decide la oscuridad con su `WorldEnvironment` (si el responsable lo aprueba).
- **No se tocan:** `toon.gdshader`, `outline.gdshader`, `body_material.gd` (sin `uniform` nuevos: `SOFT_DEFAULTS` no cambia), `preset.gd`, `finish_panel.gd`, `glb_exporter.gd`, las capturas aprobadas ni los límites de otras pruebas.
- **Condicional (SH.3b):** `probar_toon_soft.gd` solo si el paso 0 de §5 mide que su esfera, sin `Environment`, recibe ambiente. Entonces se le añade un `WorldEnvironment` con ambiente 0 (no se tocan sus límites) y se avisa.
- Cada subpaso toca 3 archivos o menos.

## 5. Diseño

### Por qué la fórmula de SH.2 falla con varias luces

`light()` se ejecuta una vez por luz y suma `LIGHT_COLOR / PI * mix(shade_ratio, 1, lit)`: cada luz, aunque no alcance el píxel, aporta su suelo de sombra (`shade_ratio` ≈ 0,6–0,9). Un contraluz aclara la cara de delante, dos luces suman dos suelos, y una omni lejana aporta el suelo entero hasta su alcance y se apaga de golpe, porque `LIGHT_COLOR` no incluye la atenuación (`ATTENUATION` solo entra en la máscara `lit`).

En `light()` no hay lista de luces ni se puede escribir un `varying`: el único estado entre luces es `DIFFUSE_LIGHT`, y Godot no garantiza qué luz se evalúa primero. Una fórmula que mezcle «sumar lo iluminado» con «suelo con `max()`» depende del orden (`max(acumulado + full·lit, suelo)`, con r = 0,8, principal de energía 1 y contraluz de 0,5: principal y luego contraluz da 1,0; contraluz y luego principal da 1,4). Solo `max(acumulado, tono_de_cada_luz)` es conmutativa. Por eso las luces no se suman. (Leo «arreglos de luces» del PLAN como «corregir el reparto de luces».)

### SH.3a — `light()`

```glsl
const float OMNI_FULL = 0.5;  // a partir de esta atenuación una omni o foco da su suelo de sombra entero

void light() {
	float lit = smoothstep(threshold - softness, threshold + softness, dot(NORMAL, LIGHT));
	lit *= smoothstep(0.15, 0.85, ATTENUATION);
	vec3 full = LIGHT_COLOR / PI;
	// La direccional no se apaga con la distancia; omni y foco, sí. NO VERIFICADO: LIGHT_IS_DIRECTIONAL.
	float reach = LIGHT_IS_DIRECTIONAL ? 1.0 : smoothstep(0.0, OMNI_FULL, ATTENUATION);
	vec3 tone = full * mix(shade_ratio, vec3(1.0), lit) * reach;
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, tone);  // por canal; conmutativa: no importa qué luz se evalúe primero
}
```

- **Una luz direccional da lo mismo que en SH.2** (`reach = 1`): `max(0, full·mix(r, 1, lit))` es `full·mix(r, 1, lit)`, la fórmula de SH.2 (el acumulador parte de 0 y `tone ≥ 0`). La sombra proyectada de SH.4 sigue igual: con sombra, `lit` baja a 0 y el suelo se queda.
- **Orden:** `max` es conmutativa y asociativa, así que el resultado es `max` de los tonos de todas las luces, sea cual sea el orden.
- **Contraluz:** una luz que no alcanza el píxel (`lit = 0`) aporta su suelo `full'·r`, que solo cambia el píxel si supera el tono de la principal. Con energías iguales o menores no cambia, salvo que algún canal de `shade_ratio` pase de 1 (posible en colores de fantasía): la prueba lo detectaría. Un contraluz **más fuerte** que la principal sí sube la cara de delante hasta su suelo.
- **Dos suelos:** `max(suelo1, suelo2)`, no la suma.
- **Dos luces de frente:** manda la más fuerte, **no se suman** (el MVP las sumaba): un juego con varias luces de frente se verá menos iluminado que con el MVP. Y con luces de color distinto, cada canal lo decide la luz que más pesa en él: no se mezclan los colores. Decisión del coordinador por el motivo de arriba; se pregunta al responsable en §8.
- **Omni y foco:** `reach` baja a 0 con la atenuación y lleva el suelo a 0 sin salto (con `smoothstep` la pendiente en 0 es nula). **NO VERIFICADO:** que `ATTENUATION` valga 0 en el borde del alcance y que el motor no evalúe `light()` más allá; la medida previa lo dice.
- **Trampa conocida:** `ATTENUATION` mezcla distancia y sombra. Una omni o foco **con sombra** también apaga su suelo dentro de su sombra. No se resuelve aquí (`shadow_receive`, SH.4); la ficha de SH.4 debe tenerlo en cuenta.
- **Mobile:** mismo código, dos operaciones más por luz. Se prueba en los dos renderizadores.

**Paso 0 (comprobaciones mínimas, antes de editar nada).**

1. Copiar `toon_soft.gdshader` tal cual a `pruebas/godot/estilo/toon_soft_sh2.gdshader`.
2. Escribir `probar_luces.gd` y ejecutarlo con la referencia en las dos columnas: debe dar `RESULTADO` con la medida previa (tabla de §6, columna «SH.2»), sin editar el shader del núcleo.
3. Editar `light()` y relanzar `probar_toon_soft.gd` (regresión de SH.2): si sale `SHADER ERROR` con `LIGHT_IS_DIRECTIONAL` o con la asignación a `DIFFUSE_LIGHT`, **parar y avisar**. Si no sale, la función existe en Forward+ y en Mobile (lanzar los dos).

### SH.3b — Ambiente

Cambios en `toon_soft.gdshader` (el resto del archivo no cambia):

```glsl
render_mode specular_disabled;   // sin ambient_light_disabled: el motor suma el ambiente de la escena
...
// fragment(), rama no unlit: se quita la línea de EMISSION con el rim; ALBEDO no cambia.
...
// light(): el rim entra en el tono de cada luz, ANTES del max() (si se sumara después, dependería del orden de las luces)
	float rim = smoothstep(1.0 - rim_width, 1.0, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	vec3 tone = full * (mix(shade_ratio, vec3(1.0), lit) + rim_color * rim * rim_strength) * reach;
	DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, tone);
```

- **Ambiente plano:** con `AMBIENT_SOURCE_COLOR` el motor suma `color_ambiente · energía · ALBEDO`, igual para todas las normales. El shader no añade ningún término que dependa de la normal. No se aplica `shade_ratio` al ambiente: es luz pareja.
- **El rim sale de `EMISSION`** porque emitía con la luz apagada. En `light()` el rim es luz y va dentro del tono de cada luz: `DIFFUSE_LIGHT` se multiplica por `ALBEDO`, así que sale `rim_color · color · rim · rim_strength`, lo mismo que antes salvo el factor de `ground_weight` (≤ 2,5 %). Con la luz del editor (energía 1) es igual; con otra energía sube o baja con ella. Una primera versión sumaba el rim con `+=` después del `max()`: dependía del orden de las luces igual que la fórmula de arriba (el rim de una luz se acumulaba o no según cuándo se evaluara). Dentro del `max()` es conmutativo: con varias luces el rim no se suma, manda el de la luz más fuerte. En el centro de una esfera `dot(NORMAL, VIEW) = 1` y el rim vale 0.
- **`unlit`:** no cambia (`ALBEDO = 0`, `EMISSION = color`); el ambiente multiplica por `ALBEDO`, así que no suma. Se comprueba (**NO VERIFICADO**).
- **Editor:** `body_view.gd:417`, `ambient_light_energy = 0.4` pasa a `0.0`, con un comentario de una línea («toon_soft suma el ambiente: 0 mantiene el aspecto de SH.2»). Hasta ahora ese 0,4 no lo veía ningún material de personaje (`toon` y `toon_soft` lo desactivaban), y `suelo.gdshader` y `zona.gdshader` son `unshaded`, así que 0 no cambia nada más. Con el interruptor apagado el cambio no se nota.
- **Ambiente que no es de color (cielo):** con `AMBIENT_SOURCE_SKY` o fondo de cielo el motor muestrea el cielo según la normal: **no es plano** (**NO VERIFICADO**; se mide). D48 pide plano: requisito para el juego, `AMBIENT_SOURCE_COLOR`, o un cielo de un solo color. **Plan B, solo si el responsable lo pide tras ver la medida:** guardar la normal real en un `varying` y poner `NORMAL` constante al final de `fragment()` (el muestreo ya no depende del píxel); habría que rehacer `light()` y el rim con ese `varying`. No se hace en esta ficha.

**Comprobaciones mínimas del ambiente (paso 0 de SH.3b):** esfera con la luz apagada y `AMBIENT_SOURCE_COLOR` blanco con energía 0,4. Imprimir `MEDIDA ambiente`: píxel de frente, píxel de espalda y el esperado `to_srgb(to_linear(color)·0,4)`. Si no coinciden (±3/255) o frente ≠ espalda, parar y avisar. Esfera con `unlit` y ambiente 1: píxel = color exacto (±1/255). Esfera sin `Environment`: imprimir si recibe ambiente (decide si hay que tocar `probar_toon_soft.gd`).

## 6. Prueba

**Uso:** `(ulimit -v 4000000; timeout 400 godot [--rendering-method mobile] --path pruebas/godot -s probar_luces.gd [-- --shader=<ruta> --ambiente-editor=<energía>] 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')`. Necesita ventana. La hoja solo se guarda en Forward+, en `pruebas/capturas/shader_sh3/`.

`--shader` y `--ambiente-editor` existen solo para romper el código **sobre una copia**: `--shader` sustituye el código de `toon_soft` (cuerpo y pieza) por el de otro archivo, y `--ambiente-editor` fija la energía de ambiente del `BodyView` después de crearlo. Sin argumentos se prueba lo que hay en el núcleo.

Esfera con una piel media y `rim_strength` y `ground_weight` a 0 (como `_make_sphere`), con cada luz como hijo del `SubViewport` de la esfera. «Frente»: `rotation_degrees (0,0,0)`; «espalda»: `(0,180,0)`. Todos los límites `# PROVISIONAL`; los previstos salen de la fórmula, no de una medida.

### SH.3a

| Comprobación | Límite | Previsto / medido |
| --- | --- | --- |
| Luz de frente (energía 1) + luz de espalda (energía 1): el píxel central es el de la luz de frente sola | ≤ 1/255 (`FRONT_STABLE`) | 0 / **POR MEDIR** |
| Dos luces de espalda (energía 1 cada una) = una sola | ≤ 1/255 (`STACK_TOLERANCE`) | 0 / **POR MEDIR** |
| Una luz de espalda sola da la sombra de SH.2 | ≤ 1/255 | 0 / **POR MEDIR** |
| Principal (energía 1, de frente) + contraluz (energía 0,5, de espalda), creadas en un orden y en el otro (dos escenas): mismo color | ≤ 1/255 (`ORDER_TOLERANCE`), y los dos iguales a la principal sola | 0 (conmutativa por construcción) / **POR MEDIR** |
| Dos luces de frente (energía 0,4 y 0,8), en los dos órdenes: lo que da la de 0,8 sola (no se suman) | ≤ 1/255 (`ORDER_TOLERANCE`) | 0 / **POR MEDIR** |
| Omni de frente (energía 1, alcance 6, sin sombra) a 0,5, 2, 4, 5, 5,8 y 6,2 m de la superficie: la luminancia no sube con la distancia | sube ≤ 1/255 (`OMNI_MONOTONE`) | **POR MEDIR** |
| La omni a 6,2 m (fuera de alcance) | ≤ 1/255 (`DARK_MAX`) | 0 / **POR MEDIR** |
| Salto de la omni entre 5,8 y 6,2 m | ≤ 16/255 (`OMNI_EDGE_JUMP`) | ≈ 13 por cálculo (**NO VERIFICADO**: supone atenuación lineal) / **POR MEDIR** |
| Hoja de cuerpo y cara, 4 filas, una luz direccional con sombra: la columna nueva frente a la referencia SH.2 | ≤ 0,1 % de píxeles con algún canal a más de 8/255 (`SAME_LOOK`) | 0 / **POR MEDIR** |
| Interruptor, valores por defecto y `uniform` de SH.2 | los de `probar_toon_soft.gd`, que se relanza entero | — |

**Medida previa (antes de editar el shader).** El paso 0 imprime con la referencia SH.2: píxel central con la omni a cada distancia (**POR MEDIR**; comprueba que hoy el suelo entero llega hasta el alcance y se apaga de golpe, que es lo que dice el PLAN) y el píxel de la cara de delante con un contraluz (**POR MEDIR**). Si hoy la omni ya se apaga sin salto, parar y avisar: la premisa del PLAN sería falsa.

### SH.3b

| Comprobación | Límite | Previsto / medido |
| --- | --- | --- |
| Sin luz y sin ambiente (`Environment` con energía 0), esfera con `rim_strength` 1 y `rim_width` 1, contorno 0: todos los píxeles del personaje | máx. canal ≤ 1/255 (`DARK_MAX`) | 0 / **POR MEDIR** |
| Solo ambiente blanco 0,4: píxel central = `to_srgb(to_linear(color)·0,4)` | ± 3/255 (`AMBIENT_TOLERANCE`) | **NO VERIFICADO** / **POR MEDIR** |
| Ambiente plano (`AMBIENT_SOURCE_COLOR`): píxel central frente y espalda | ≤ 2/255 (`FLAT_TOLERANCE`) | 0 / **POR MEDIR** |
| Ambiente de cielo con degradado: frente y espalda | solo `MEDIDA`, sin límite | **POR MEDIR** |
| Luz de frente + ambiente = luz sola + ambiente solo (suma en lineal; color oscuro para no saturar) | ± 3/255 | **POR MEDIR** |
| `unlit` con ambiente 1: color exacto | ± 1/255 | **NO VERIFICADO** / **POR MEDIR** |
| Rim con luz de frente energía 1 en el borde de la esfera: igual que la referencia SH.2 | ≤ 3/255 | ≈ 0 / **POR MEDIR** |
| Rim en el borde con principal + contraluz (energías 1 y 0,5), en los dos órdenes de creación, `rim_strength` 0,3 para que se vea | mismo color ≤ 1/255 (`ORDER_TOLERANCE`) | 0 / **POR MEDIR** |
| Hoja de cuerpo y cara, con el ambiente real del editor: columna nueva frente a la referencia SH.2 | ≤ 0,1 % (`SAME_LOOK`) | 0 / **POR MEDIR** |
| Misma hoja con ambiente 0,4 (el valor viejo) | solo `MEDIDA` de lo que se evita | **POR MEDIR** |

**Con el interruptor apagado** (los dos subpasos; en SH.3a no puede cambiar nada porque `toon_soft` no se carga, pero lo pide el PLAN):

```sh
sh pruebas/fase_5/capturas_de_referencia.sh <scratchpad>/sh3_ref 2>&1 | grep -E 'ERROR'
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s comparar_capturas.gd -- pruebas/capturas/aprobadas <scratchpad>/sh3_ref <scratchpad>/sh3_dif 2>&1 | grep -E 'MEDIDA|AVISO|FALLO|RESULTADO')
```

Las 6 capturas al 0,000 % (límite actual 0,1 %). `probar_material`, `probar_acabado` y `probar_presets` no hacen falta: `body_material.gd` no cambia. Se lanza `probar_toon_soft.gd` en Forward+ y Mobile.

**Que detecta el fallo** (siempre sobre una copia del shader en el `<scratchpad>`, con `--shader=`; nada se rompe en el repositorio):

| Rotura | Debe fallar |
| --- | --- |
| SH.3a: en la copia, `light()` vuelve a `DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shade_ratio, vec3(1.0), lit);` | contraluz, dos luces de espalda, dos de frente y salto de la omni |
| SH.3a: en la copia, la fórmula anterior de esta ficha: `DIFFUSE_LIGHT = max(DIFFUSE_LIGHT + full * lit, tone);` | **orden** (principal + contraluz, los dos órdenes dan colores distintos) |
| SH.3a: `float reach = 1.0;` | salto de la omni y fuera de alcance |
| SH.3a: `reach = smoothstep(0.0, OMNI_FULL, ATTENUATION);` para todas las luces (quitar `LIGHT_IS_DIRECTIONAL`) | hoja con sombra (el suelo desaparece en la sombra) |
| SH.3b: la copia con `render_mode ambient_light_disabled, specular_disabled;` | solo ambiente, suma y plano |
| SH.3b: la copia con el rim de vuelta en `EMISSION` (`EMISSION = rim_color * color * rim * rim_strength;`) y fuera de `light()` | sin luz y sin ambiente |
| SH.3b: la copia con el rim sumado después del `max()` (`DIFFUSE_LIGHT += rim_color * rim * rim_strength * full * reach;`) | orden del rim |
| SH.3b: `--ambiente-editor=0.4` | hoja con el ambiente real del editor |

## 7. Trampas conocidas

- **Una sola función `fragment()`:** `piece_shader()` inserta `PULL_CODE` delante de cada `void fragment()`. No escribir esa cadena en un comentario ni repetirla.
- **`shade_ratio > 1`:** en colores de fantasía un canal puede subir en la sombra; con energías iguales un contraluz podría entonces notarse. La prueba usa una piel media; si falla con otro color, anotar la medida y decidir con el responsable.
- **Rim y luz:** con la luz apagada el rim desaparece (es lo buscado). Con más de una luz no se suma: manda el de la luz más fuerte.
- **Las luces no se suman:** dos luces de frente dan lo que da la más fuerte. Cualquier prueba o captura futura (SH.4, SH.7, el juego) no debe esperar la suma del MVP.
- **Contorno:** `outline.gdshader` es `unshaded` y no se toca: en oscuridad total la línea sigue viéndose. Se decide en SH.4b.
- **Omni con sombra:** su sombra también apaga el suelo (arriba). Para SH.4.
- **Otras pruebas con ambiente:** `probar_legibilidad.gd` (ambiente 0,1–0,4), `probar_estilo.gd`, `capturar_banco.gd` (0,25) y los otros `Environment` del repositorio usan el MVP, que sigue sin ambiente. Cuando SH.7 encienda el interruptor, su ambiente empezará a verse: revisarlo allí, no aquí.
- **Ambiente de cielo:** no es plano (arriba). El juego debe saberlo.
- **`soft_enabled`, `varying` y Compatibility:** como en SH.2.

## 8. Juicio visual

Hojas de `pruebas/capturas/shader_sh3/`, columnas A = SH.2 (referencia congelada) y B = SH.3. Dar solo las rutas, sin describirlas ni valorarlas.

- **SH.3a:** `hoja_cuerpo.png` y `hoja_cara.png` (4 filas de SH.2, una luz con sombra; no deben cambiar), `hoja_contraluz.png` (el cuerpo de `SHOT_BODY` con la luz del editor y una segunda direccional a contraluz, giro de 180°) y `hoja_omni.png` (la escena omni de SH.1, mismas cámara y luces).
- **SH.3b:** las mismas hojas, y `hoja_ambiente.png`: fila `anime`; columnas: luz del editor con ambiente 0, solo ambiente 0,15, solo ambiente 0,4, sin luz y sin ambiente (solo se ve la línea del contorno).

Preguntas:

1. **SH.3a:** ¿el contraluz deja la cara de delante como estaba y se ve bien el borde que ilumina?
2. **SH.3a:** ¿la omni se apaga de forma natural al alejarse, sin parche ni salto? ¿Cambio `OMNI_FULL` (0,5)?
3. **SH.3a:** ¿aceptas que varias luces de frente no se sumen (manda la más fuerte, por canal)? Un juego con varias luces de frente se verá menos iluminado que con el MVP, y las luces de color no se mezclan. Recomendación: aceptarlo, porque con un solo acumulador no hay otra forma sin depender del orden de evaluación, y encaja con el estilo anime (un tono claro, un tono de sombra).
4. **SH.3b:** ¿el ambiente parejo se lee como «oscuridad que decide el juego» y no como una pantalla lavada? ¿Aceptas que en oscuridad total solo quede la línea del contorno hasta SH.4b?

## 9. Si te atascas

Si `LIGHT_IS_DIRECTIONAL` o la asignación a `DIFFUSE_LIGHT` no compilan, si el ambiente no se comporta como se espera (§5), si las 6 capturas aprobadas cambian con el interruptor apagado o si falla una prueba existente, para y dilo. No cambies límites ni salgas de los archivos del apartado 4. No pases el ambiente a `uniform` propios ni toques el contorno: es lo que descarta D48.
