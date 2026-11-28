# AC.6c — Cejas

> Ficha del 2026-11-24 (nivel: fuerte). **Aprobada por el responsable el 2026-11-24**, con D-a (1) y D-b (1) y con los deslizadores Altura, Grosor, Tamaño y Color dentro de este paso (AC.6c.4a y AC.6c.4b). Sale de AC.6 en `PLAN.md` («Párpado, pestañas y cejas») y de AC.3b §5.8: las cejas no están en el prototipo aprobado (`ojo_final.png`) y necesitan su propio diseño. AC.6c.0 es una puerta: sin el juicio del responsable sobre su hoja no se escribe nada en el repositorio.

## 1. Objetivo y «Hecho cuando»

Que el personaje tenga cejas anime, dibujadas sobre la piel como las líneas del ojo, que sigan a las formas y a los huesos, que se ajusten con 4 controles (Altura, Grosor, Tamaño y Color), que se guarden con el personaje y que salgan en el `.glb`.

Hecho cuando (al cerrar AC.6c.4b; cada subpaso tiene el suyo en §6):

1. `cuerpo.glb` y `articulaciones.json` salen idénticos (solo cambian `ojos.json` y el manifiesto).
2. La banda de cada ceja queda pegada a la piel (≤ 0,05 mm) en reposo y en los 10 extremos de Ojos, y la ceja nunca toca la abertura del ojo (§6).
3. Izquierda y derecha son simétricas (≤ 0,5 mm).
4. Una especie sin `ceja` en `ojos.json` carga y funciona igual, sin cejas.
5. Forward+ y Mobile las dibujan; el `.glb` las lleva horneadas en textura con alfa, sin shader.
6. Altura, Grosor, Tamaño y Color cambian la ceja en el editor y en el `.glb`, se guardan en el `.gmolde` y en los presets, y un archivo de antes (sin ellos) se abre con los valores de serie.
7. En los extremos de los 3 deslizadores, combinados con los 10 extremos de Ojos, la ceja no se sale de la banda ni toca la abertura del ojo.
8. El responsable aprueba la forma por defecto en la hoja de AC.6c.0 y el resultado en el programa.

## 2. Nivel de modelo

| Subpaso | Nivel | Por qué |
| --- | --- | --- |
| AC.6c.0 Hoja de formas, en una copia | fuerte | Mide la banda en Blender y decide la forma por defecto |
| AC.6c.1 Banda en Blender (`ojos.json`) | fuerte | Geometría sobre la frente con rayos de apoyo |
| AC.6c.2 Ceja en el programa | medio | Un modo nuevo del shader de líneas; avisar para cambiar a uno más barato |
| AC.6c.3 Ceja en el `.glb` | medio | Copia del modo nuevo en `EyeTexture`; avisar para cambiar a uno más barato |
| AC.6c.4a Valores de la ceja: guardar y aplicar | medio | Como `hair_band` (SH.6b): valores en `BodyMaterial` que la vista copia; toca el formato del preset |
| AC.6c.4b Controles en Acabado | simple | Una sección más en `finish_panel.gd`; avisar para cambiar a uno más barato |

## 3. Contexto mínimo

- Esta ficha; `ruta/pasos/AC.3b_ojo_en_programa.md` §5.4–§5.7 (datos, capas y `.glb`).
- `blender/cara_anime.py`: `eye_strip` (604), `_support` (586), `_faces` (596), `_strips` (706) y las constantes 68–76; la zona `brow` de `blender/cara_anime_zonas.json` (vértices que mueve el target CC0 `eyebrows` de MakeHuman, cabecera del archivo, líneas 15–18).
- `godot/addons/creador/eye_mesh.gd`: `STRIPS`, `build`, `line_material`, `_strip_mesh`.
- `godot/addons/creador/eye_line.gdshader` (modos 0–2) y `eye_texture.gd` (su copia en CPU: `LINE_DEFAULTS`, `_line_column`, `_line_alpha`).
- `godot/datos/FORMATO.md`, apartado `ojos.json`.
- Pruebas que se copian de tono: `pruebas/godot/probar_linea_ojo.gd` y los casos `--ojos` de `probar_glb.gd`.

## 4. Archivos

Más de 3 archivos en total: va partido. Cada subpaso solo toca los suyos.

| Subpaso | Archivos |
| --- | --- |
| AC.6c.0 | Nada del repositorio. Copia en el scratchpad; salida en `pruebas/capturas/ac6c/` (git la ignora) |
| AC.6c.1 | `blender/cara_anime.py`, `godot/datos/humana/{ojos.json,manifiesto.json}`, `godot/datos/FORMATO.md`, `pruebas/fase_3/probar_forma_ojo.py` (solo añadir casos) |
| AC.6c.2 | `godot/addons/creador/eye_mesh.gd` (una entrada en `STRIPS`), `eye_line.gdshader` (modo 3), `pruebas/godot/probar_cejas.gd` (nueva) |
| AC.6c.3 | `godot/addons/creador/eye_texture.gd` (modo 3), `pruebas/godot/probar_glb.gd` y `probar_piezas.gd` (añadir `ceja_l` y `ceja_r` a `EYE_MESHES`) |
| AC.6c.4a | `godot/addons/creador/body_material.gd` (`SKIN`, `SKIN_START`), `preset.gd` (color opcional), `godot/app/body_view.gd` (copiar a `ceja_*`), `pruebas/godot/probar_cejas.gd` y `probar_presets.gd` (añadir casos) |
| AC.6c.4b | `godot/app/finish_panel.gd`, `pruebas/godot/probar_acabado.gd` (añadir casos) |

**No se toca:** `cuerpo.glb`, `articulaciones.json`, las formas de la cara, `toon_soft.gdshader`, `outline.gdshader`, `glb_exporter.gd` (la ceja es una tira más y ya se exporta), los presets de serie (`godot/datos/humana/presets/*.json`: los valores que falten salen de serie al cargar).

## 5. Diseño

### 5.1 Idea: una banda fija y la ceja dibujada dentro

Decisión: Blender calcula una **banda** (rejilla de malla sobre la frente, encima de cada ojo) y el shader dibuja la ceja **dentro** de ella con uniforms. Motivo: así forma, altura, arco y grosor cambian sin regenerar `ojos.json`, la hoja de AC.6c.0 compara formas sin Blender y los deslizadores de AC.6c.4 solo mueven uniforms (como el iris en AC.4).

La banda es una tira con el formato de AC.6a (`ids`, `bary`, `offset`, `uv`, `filas`, `largo`): cada vértice es la mezcla baricéntrica de 3 vértices de la piel más un desplazamiento fijo, y por eso sigue a las formas y a los huesos sin código nuevo en `EyeMesh._strip_mesh`.

### 5.2 Datos (`ojos.json`, AC.6c.1)

Clave nueva por ojo: `"ceja"`, con el formato de las tiras. `uv.x` = u de 0 (extremo interior) a 1 (exterior); `uv.y` = altura en metros sobre la base de la banda. `largo` = ancho de la banda en metros.

```python
def brow_band(anime, center, frame, ahead, skin, columns, rows):
    """Banda de la ceja (AC.6c): columnas de la parte interior a la exterior, filas de abajo arriba, apoyadas en la piel
    con un rayo por ahead (la normal del ojo) y elevadas STRIP_LIFT. Mismo formato que eye_strip."""
```

Algoritmo:

1. **Marco del ojo:** `center` (centro del lazo, estado anime), `ahead` (normal del ojo, la de `ojos.json`), `side` = de la esquina interior a la exterior (por las `esquinas` del lazo), `up` = `ahead × side` orientado hacia +Y.
2. **Caja de la banda (aprobada en AC.6c.0):** en `side`, de 8 mm antes de la esquina interior a 12 mm después de la exterior; en `up`, de 2 a 28 mm sobre lo alto del lazo. Con la humana: 48,7 × 26 mm. Se define desde el marco del ojo, como en el prototipo, y no desde la zona `brow` (el prototipo no podía leerla y es lo que se aprobó); la zona `brow` solo se mide como comprobación (`MEDIDA`).
3. **Puntos:** rejilla de `BROW_COLUMNS` × `BROW_ROWS` = 32 × 15 (la del prototipo), a 30 mm por delante del centro del ojo.
4. **Apoyo:** rayo desde cada punto hacia `-ahead` contra la piel (solo piel, sin la bolsa). `_support` tiene hoy `RAY_FROM = 5 mm` y `MAX_SNAP = 4,5 mm` fijos; la frente queda más lejos. Se añaden parámetros con valor por defecto (`_support(point, normal, surfaces, ray_from=RAY_FROM, max_snap=MAX_SNAP)`), sin cambiar lo que hacen las tiras de AC.6a. Piel en la que se apoya: radio `BROW_RADIUS` = 50 mm en vez de `SKIN_RADIUS`. En el prototipo (rayos desde 30 mm, sin límite de distancia, primer triángulo de piel) se apoyaron los 480 puntos de cada ojo.
5. Si un punto no encuentra piel: **parar** (no se deja recto como en AC.6a; en la frente no debe pasar).
6. El ojo derecho, por reflejo, como en AC.3b (comprobar el orden interior → exterior).

### 5.3 Shader (`eye_line.gdshader`, modo 3, AC.6c.2)

Uniforms nuevos, con los valores de serie aprobados en AC.6c.0 («arco suave»):

| Uniform | Qué es | Serie |
| --- | --- | --- |
| `brow_color : source_color` | Color de la ceja (D-a, §5.6; deslizador Color, §5.4b) | (0,25; 0,16; 0,12), castaño oscuro |
| `brow_height` | Altura de la línea central en los extremos, en metros sobre la base de la banda | 0,0075 |
| `brow_arch` | Cuánto sube el centro respecto a los extremos (m) | 0,0015 |
| `brow_tilt` | Cuánto sube el extremo exterior respecto al interior (m) | 0,0 |
| `brow_width` | Grosor máximo (m) | 0,0014 |
| `brow_inner_w`, `brow_outer_w` | Grosor en cada extremo, en partes del máximo (la cola se afila) | 0,85 y 0,15 |
| `brow_start`, `brow_end` | Dónde empieza y acaba la ceja en u | 0,1774 y 0,7815 |
| `brow_lift`, `brow_thickness`, `brow_size` | Los deslizadores (§5.4b) | 0, 1 y 1 |

`fragment()` en modo 3: **la referencia es el prototipo aprobado**, `pruebas/capturas/ac6c/proto/ceja.gdshader` (git lo ignora; copia de `eye_line.gdshader` con el modo 3). Con `t` = posición dentro de la ceja (de `brow_start` a `brow_end`, escalados por `brow_size` alrededor de su centro): línea central `c(t) = brow_height + brow_lift + brow_arch · 4t(1 − t) + brow_tilt · (t − 0,5)`, grosor `w(t) = brow_width · brow_thickness · mix(brow_inner_w, 1, smoothstep(0, 0,35, t)) · mix(1, brow_outer_w, smoothstep(0,55, 1, t))` y `alpha = band(d − c(t), −w/2, w/2)` con los extremos suavizados un píxel en u, con la misma `band()` y el mismo `fwidth` que los otros modos. Sin luz propia: el bloque «Común» no cambia.

`EyeMesh.STRIPS` gana `"ceja": ["ceja", 3]`: nodos `ceja_l` y `ceja_r`, con `render_priority` de las líneas. Nada más cambia en `EyeMesh`.

### 5.4 `.glb` (AC.6c.3)

`EyeTexture._line_column` y `_line_alpha` ganan el modo 3 (copia de §5.3), y `LINE_DEFAULTS`, sus uniforms. La prueba de constantes de `probar_glb --ojos` ya compara todos los valores de serie con el shader. `GlbExporter` no cambia: las tiras nuevas salen como las demás. Textura: 1024 de ancho y el alto que dé el píxel casi cuadrado (con la banda de 48,7 × 26 mm, unos 550 px; **POR MEDIR** en bytes).

### 5.4b Deslizadores (AC.6c.4a y AC.6c.4b)

Decisión: los valores viven en el material del cuerpo, como `hair_band` (SH.6b), y la vista los copia a `ceja_l` y `ceja_r`. Motivo: así entran solos en el `.gmolde`, en los presets y, como `EyeTexture` lee el material de la ceja, en el `.glb`, sin un sistema nuevo de guardado.

| Control | Clave | Qué mueve en el shader | Rango (de partida) | Serie |
| --- | --- | --- | --- | --- |
| Altura | `brow_lift` en `BodyMaterial.SKIN` | suma a `brow_height` (m) | −0,003 a +0,003 | 0 |
| Grosor | `brow_thickness` en `SKIN` | multiplica `brow_width` | 0,5 a 4,0 | 1 |
| Tamaño | `brow_size` en `SKIN` | escala el largo (`brow_start`–`brow_end`) alrededor de su centro | 0,6 a 1,5 | 1 |
| Color | `brow_color` (color, como `skin_color`) | `brow_color` | cualquiera | (0,25; 0,16; 0,12) |

- Rangos aprobados en AC.6c.0 (Grosor hasta ×4 y Tamaño hasta ×1,5, pedidos por el responsable). En todas las combinaciones la ceja cabe en la banda: con Grosor ×4 y Altura −3 mm queda a 1,7 mm de su borde de abajo; Tamaño ×1,5 llega justo a los dos lados (por eso la banda es ancha).
- `BodyMaterial.SKIN_START` lleva los valores de serie, y `Preset._load_skin` ya rellena los que falten: los `.gmolde` y presets de antes se abren igual.
- `brow_color`: `Preset.COLORS` exige hoy exactamente sus colores y un archivo sin `brow_color` fallaría. Se añade `OPTIONAL_COLORS := {"brow_color": <serie>}` en `preset.gd`: se escribe siempre y, si falta al leer, va el de serie. Motivo: no subir `VERSION` ni tocar los presets de serie (sus `sha256`).
- `body_view.gd`: `_copy_brow(mesh)` junto a `_copy_band`, llamada desde `sync_lines()` y al construir los ojos.
- Panel: sección **«Cejas»** en Acabado, dentro de la parte del estilo anime (como Piel), con 3 deslizadores y un `ColorPickerButton`, con nombre y ayuda de una línea (como `SKIN_NAMES`/`SKIN_HELP`). «Restablecer acabado» las devuelve a serie. En estilo clásico las cejas se ven con los valores de serie (igual que pasa hoy con el resto de la piel anime).

### 5.4c Estado

- **AC.6c.0 cerrado (2026-11-24).** Hecho en Godot, no en Blender (no había Blender en ese equipo): la banda del prototipo se apoya con rayos desde el marco del ojo sobre `cuerpo.glb` con las formas del preset anime. Hojas en `pruebas/capturas/ac6c/` (`formas`, `flequillo`, `rangos`, `grosor`, `largo` y `LEEME.txt`) y prototipo en `pruebas/capturas/ac6c/proto/` (git los ignora). El responsable aprueba «arco suave» de serie, el flequillo que tapa la ceja, Grosor hasta ×4 y Tamaño hasta ×1,5.
- **Medido:** el punto más adelantado de la frente, a 18 mm sobre el centro del ojo (10 mm sobre lo alto del lazo), igual en los dos lados. Con Ojos › Altura, Alto y Tamaño al máximo, lo alto del lazo sube 6,43 mm; una cuenta que **no** mueve la banda con la piel da que la ceja (Altura −3 mm, Grosor ×2) lo pisaría hasta 1,12 mm. Es una cota pesimista: la medida buena es la de AC.6c.2 (§6), y si de verdad se tocan, parar y preguntar.

### 5.5 Restricciones

| Restricción | Cómo se cumple |
| --- | --- |
| El núcleo no depende de la interfaz | Todo en `addons/creador/` y en los datos |
| La humana es una especie | Sin `ceja` en `ojos.json`, no hay cejas |
| Licencias | La zona `brow` sale de un target CC0 de MakeHuman; la ceja se dibuja con código propio. Nada de las cejas «proxy» de MakeHuman |
| Pesos | Los de `_mixed_weights`: máximo 4, suman 1 |
| Forward+ y Mobile | Sin funciones exclusivas de Forward+; capturas en los dos |
| Android | Las formas de Ojos no se cargan (`zonas_solo_pc`); la banda copia solo las que existen, como las tiras |

### 5.6 Decisiones del responsable (tomadas el 2026-11-24: D-a (1) y D-b (1))

- **D-a, color:** (1) color propio de la ceja, de serie un castaño oscuro, editable en AC.6c.4 (recomendado: no depende de qué pelo lleve puesto); (2) el color del pelo puesto, oscurecido (necesita que el núcleo sepa cuál es el pelo: se sale de la ficha).
- **D-b, flequillo:** (1) el pelo tapa la ceja, como cualquier malla (recomendado: es lo que hace el motor sin trucos y vale igual en el `.glb`); (2) la ceja se ve a través del flequillo, como en muchos juegos anime. La (2) necesita un truco de profundidad que **no está comprobado**; si se elige, va a `IDEAS.md` y se estudia aparte.

## 6. Pruebas

Solo las del subpaso. La batería completa, cuando la pida el responsable. Límites nuevos con `# PROVISIONAL`.

| Subpaso | Comprueba | Rotura que debe dar FALLO | Qué ve el responsable |
| --- | --- | --- | --- |
| AC.6c.0 | Caja de la zona `brow` en (`side`, `up`) de los dos ojos (`MEDIDA`); todos los rayos encuentran piel en reposo y en los 10 extremos | — (es una hoja) | `pruebas/capturas/ac6c/formas.png`: 3 formas (recta, arco suave, arco marcado) × 2 grosores, de frente y tres cuartos, piel clara y oscura; `flequillo.png`: con 2 peinados con flequillo |
| AC.6c.1 | `probar_forma_ojo.py`: `cuerpo.glb` y `articulaciones.json` idénticos; banda con todos sus puntos apoyados; simetría ≤ 0,5 mm; `ojos.json` sin cambios en las claves de antes | Quitar el reflejo del ojo derecho (simetría falla) | Nada todavía: se cierra junto a AC.6c.2 |
| AC.6c.2 | `probar_cejas.gd` (Forward+ y Mobile): banda–piel ≤ 0,05 mm en reposo y en los 10 extremos; distancia mínima del borde inferior de la ceja (con los valores de serie) al arco superior del lazo ≥ 2 mm (`# PROVISIONAL`, medir antes); sin `ceja` en `ojos.json` no hay `ceja_*`; a oscuras, canal máximo ≤ 0,01 | Banda sin formas (se separa con Ojos › Altura); `brow_height` fuera de la banda (la ceja desaparece: cobertura 0) | Primer plano frente a la hoja aprobada, Forward+ y Mobile, y las 6 capturas aprobadas si cambian (regla 9) |
| AC.6c.3 | `probar_glb --ojos`: `ceja_l` y `ceja_r` con piel, ≤ 4 pesos que suman 1, textura con alfa, sin shader; constantes del modo 3 iguales al shader | Cambiar `brow_width` en `LINE_DEFAULTS` | `.glb` abierto en Godot, a 6 m y de cerca |
| AC.6c.4a | `probar_cejas.gd`: cada valor llega a los dos `ceja_*`; extremos de los 3 deslizadores × 10 extremos de Ojos: la ceja dentro de la banda y ≥ 2 mm de la abertura; el `.glb` exportado con Grosor 2 y otro color lleva otra textura. `probar_presets.gd`: guardar y abrir conserva los 4 valores; un archivo sin ellos se abre con los de serie | `_copy_brow` sin llamar desde `sync_lines`; leer sin `OPTIONAL_COLORS` (el archivo viejo falla) | — |
| AC.6c.4b | `probar_acabado.gd`: la sección «Cejas» existe en estilo anime, mueve los valores y «Restablecer acabado» los devuelve | Deslizador sin conectar | La pestaña Acabado con la sección Cejas, y el programa abierto para probarlo a mano |

Al cerrar AC.6c.2, AC.6c.3 y AC.6c.4b se propone el revisor-visual.

## 7. Trampas conocidas

1. **La frente es curva:** los rayos por `-ahead` llegan a la piel con ángulo; por eso `ray_from` y `max_snap` propios (§5.2, 4). Si en los extremos una columna se apoya en la sien o en el párpado, parar.
2. **Ojos › Altura hacia arriba y Alto:** el ojo sube hacia la ceja. La prueba de distancia mínima de AC.6c.2 es la que lo vigila; no se arregla moviendo la banda con el ojo sin preguntar.
3. **`_support` es de AC.6a:** sus nuevos parámetros llevan valor por defecto; `probar_linea_ojo.gd` debe dar las mismas medidas que antes.
4. **Orden de dibujo:** la ceja va con `render_priority` de las líneas (3) y con alfa; comprobar que el contorno (`outline.gdshader`) no la tapa ni la recorta.
5. **Copia en CPU:** si el modo 3 cambia en el shader, cambia en `eye_texture.gd` (la prueba de constantes avisa de los valores, no de las fórmulas).
6. **`ojos.json` crece:** se mide en AC.6c.1 (hoy 147 KB).

## 8. Juicio visual

Se dan solo las rutas, sin describir ni valorar.

- **AC.6c.0:** ¿qué forma y grosor van de serie? ¿D-a y D-b?
- **AC.6c.2:** ¿la ceja del programa es la elegida, también en los extremos de Ojos y con flequillo?
- **AC.6c.3:** ¿el `.glb` se ve bien fuera del editor?
- **AC.6c.4b:** ¿los 4 controles hacen lo que dicen y sus rangos están bien? (a mano, en el programa)

## 9. Si te atascas

Para y dilo si: algún rayo no encuentra piel, `cuerpo.glb` o `articulaciones.json` cambian, las tiras de AC.6a dan otras medidas, la ceja toca la abertura del ojo en algún extremo, o una prueba que pasaba deja de pasar sin causa evidente. No se relaja ningún límite ni se añade otro apaño.
