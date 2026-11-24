# AC.3b — Llevar al programa el ojo aprobado

> Ficha del 2026-11-22 (nivel: fuerte). **Aprobada por el responsable el 2026-11-22**, con deslizadores propios para Tamaño (hasta +16 %), Alto e Inclinación, Altura hacia arriba recortada al 65 %, AC.3b.1 y AC.3c cerrados seguidos y ojos con textura horneada en el `.glb`. AC.3b.0 es una puerta: sin el juicio del responsable sobre su hoja no se escribe nada en el repositorio.
> Parte del aspecto aprobado en `ruta/pasos/AC.4a_ojo_completo.md` y de la forma nueva aceptada en `ruta/pasos/AC.3_base_ojo.md`. Sustituye a los apartados de AC.3b y AC.3c de esa ficha donde se contradigan (§5.8) y da el plan de AC.4, AC.5 y AC.6.

## 1. Objetivo y «Hecho cuando»

Que el programa dibuje el ojo de `pruebas/capturas/ac3/ac4a/ojo_final.png` con datos y shaders limpios, sin ninguno de los apaños de la copia.

Hecho cuando (al cerrar AC.6b; cada subpaso tiene el suyo en §6):

1. `cuerpo.glb` conserva 13.380 vértices y 13.378 caras, y `articulaciones.json` sale idéntico.
2. **0 cruces y 0 invertidos** en reposo y en los extremos de los recorridos aprobados, en los 5 deslizadores de Ojos (AC.3 §1). No se relaja.
3. El pack MakeHuman sigue por debajo de 44.000.000 bytes.
4. Ningún `discard` de piel, polígono por CPU, hueco elipsoidal ni fila adelantada 0,90 mm.
5. El núcleo no nombra `app/`, y una especie sin `ojos.json` carga y funciona igual, sin ojos.
6. Forward+ y Mobile dibujan las capas en orden. El `.glb` lleva los ojos sin shader, con pesos de máximo 4 influencias que suman 1.
7. El responsable compara con `ojo_final.png` y aprueba. **La igualdad completa solo puede juzgarse tras SH.4b, SH.7 y SH.8** (§5.7).

## 2. Nivel de modelo

| Subpaso | Nivel | Modelo recomendado |
| --- | --- | --- |
| AC.3b.0 Forma corregida, en una copia | fuerte | Opus 5.5 high |
| AC.3b.1 Datos en Blender | fuerte | Opus 5.5 high |
| AC.3c Blanco en el núcleo | fuerte | Opus 5.5 high |
| AC.4 Iris y pupila | medio | Avisar para cambiar a uno más barato |
| AC.5 Brillos | medio | Avisar para cambiar a uno más barato |
| AC.6a Líneas, pestañas y pliegue | fuerte | Opus 5.5 high |
| AC.6b Ojos en el `.glb` | fuerte | Opus 5.5 high |
| SH.8 Rubor | el de su ficha | — |

## 3. Contexto mínimo

Esta ficha; `ruta/pasos/AC.3_base_ojo.md` §5.3 y §7; `ruta/pasos/AC.4a_ojo_completo.md` §5; `pruebas/capturas/ac3/ac4a/medidas.md` (sus valores mandan). Por subpaso:

- **AC.3b:** `blender/cara_anime.py`, `blender/exportar_datos.py` (`shape_specs`, `face_shapes`, `export_species`), `pruebas/capturas/ac3/ac3a_forma.py` y `ac3a_exportar.py`.
- **AC.3c–AC.5:** `godot/addons/creador/body_piece.gd`, `character_updater.gd`, `body_material.gd`, `toon_soft.gdshader`, `species_data.gd`, `godot/app/body_view.gd`, y del prototipo `ac4a_ojo.gd` y `ojo_completo.gdshader`.
- **AC.6:** `ojo_linea.gdshader`, `ac4a_ojo.gd` (`strip`, `project`), `godot/addons/creador/glb_exporter.gd`, `character_baker.gd` y `garment_texture.gd`.

Medidas de esta ficha: scripts de solo lectura en `/tmp/claude-1000/-home-evilsec-Documentos-portafolio-juego-demo/412b273e-636c-4d5d-97ba-f2fc2b4ab2cf/scratchpad/ac3b/`. Son temporales: AC.3b.0 las repite en Blender.

## 4. Archivos

Más de 3 archivos en total (señal 1): por eso va partido. Cada subpaso solo toca los suyos.

| Subpaso | Archivos |
| --- | --- |
| AC.3b.0 | Nada del repositorio. Copia en el scratchpad; salida en `pruebas/capturas/ac3b/` (git la ignora) |
| AC.3b.1 | `blender/cara_anime.py`, `blender/cara_anime_zonas.json`, `blender/exportar_datos.py`, `godot/datos/humana/{cuerpo.glb,manifiesto.json,ojos.json,deslizadores.csv}`, `godot/datos/FORMATO.md`, `pruebas/fase_3/probar_forma_ojo.py` (nueva); los `.glb` de `godot/packs/` solo si AC.3b.0 demuestra que caben |
| AC.3c | `godot/addons/creador/eye_mesh.gd` (nuevo), `eye_layers.gdshader` (nuevo), `species_data.gd`, `godot/app/body_view.gd`, `pruebas/godot/probar_base_ojo.gd` (nueva) |
| AC.4 | `eye_layers.gdshader`, `eye_mesh.gd`, `pruebas/godot/probar_iris.gd` (nueva). Control en la interfaz: paso aparte AC.4b, con su propuesta |
| AC.5 | `eye_layers.gdshader`, `pruebas/godot/probar_iris.gd` |
| AC.6a | `blender/cara_anime.py` (tiras a `ojos.json`), `godot/datos/humana/{ojos.json,manifiesto.json}`, `godot/datos/FORMATO.md`, `eye_mesh.gd`, `eye_line.gdshader` (nuevo), `pruebas/godot/probar_linea_ojo.gd` (nueva) |
| AC.6b | `godot/addons/creador/eye_texture.gd` (nuevo), `glb_exporter.gd`, `godot/app/body_view.gd`, `pruebas/godot/probar_glb.gd` (solo añadir casos) |

**No se toca:** `toon_soft.gdshader` y `outline.gdshader` salvo el plan B de §5.2 b), con OK aparte; `articulaciones.json`; el resto de formas de la cara; `pruebas/capturas/ac3/ac4a/`, que es la referencia.

## 5. Diseño

### 5.1 Medidas nuevas (2026-11-22)

**Origen:** `ac3/datos/nueva/cuerpo.glb`, cuatro formas de cara a 1, **ojo izquierdo** (el derecho es su reflejo: POR MEDIR en AC.3b.0). La lectura reproduce los datos anteriores: 14.517 vértices del `.glb` (13.380 soldados), bolsa de 724 triángulos y 46 triángulos cruzados por ojo (92 en los dos, como el AC.3a). «Invertidos» cuenta todos, también los no visibles: es más estricto que el AC.3a.

**Causa de los cruces:**

- **6 «orejas»:** triángulos de piel con sus 3 vértices en el lazo (índices 6-8, 13-15, 16-18, 30-31-33, 31-32-33 y 35-37). Como el lazo es una elipse convexa, esos triángulos caen siempre **dentro** de la abertura. Ningún suavizado puede arreglarlo.
- **41 triángulos de piel de espaldas** al plano del lazo, en los anillos 0 (34) y 1 (7). Desde el anillo 2 no hay ninguno.

**Métodos probados en memoria (cruces en reposo, un ojo):**

| Método | Cruces | Motivo de descarte |
| --- | --- | --- |
| Forma actual | 46 | — |
| Membrana XYZ de los anillos 1–K, con o sin orejas | 52–97 | Empeora: un agujero convexo tira de los vecinos hacia dentro |
| Lazo limpio, párpado resbalando sobre la piel | 4–24 | La piel vista de frente da saltos |
| Lazo limpio, conservando la altura (K = 5) | 3 | No llega a 0 |
| **Lazo limpio + corona en el plano del lazo (K = 5)** | **0** | **Elegido** |

### 5.2 Los apaños del prototipo

| Apaño | Opciones | Recomendación |
| --- | --- | --- |
| a) Descarte de piel con polígono por CPU | 1. Corregir la malla (§5.3). 2. Llevar el descarte a `toon_soft` (arrays de 42 puntos, CPU en cada estado, no vale en el `.glb`) | **1.** Desaparecen el `discard`, los `rim_world_*` y las caras traseras |
| b) Hueco elipsoidal del contorno | 1. Sin hueco: con la malla corregida no hay caras dobladas que pintar. 2. Plan B: máscara en `UV2.x` de `cuerpo.glb` (0 piel, 1 bolsa) que anula `width_px` | **1.** Se mide en AC.3b.0 (§6). Si quedan píxeles, parar y proponer el plan B: toca `outline.gdshader` y necesita OK |
| c) Filas inferiores adelantadas 0,90 mm | 1. Apoyar las filas de dentro **sobre la bolsa**, con el mismo método (triángulo y baricéntricas) y elevación de 0,12 mm que las de fuera. 2. Mantener los 0,90 mm | **1.** Sigue a la bolsa sin constante y sin desplazarse al girar la cámara |
| d) Engorde de la línea inferior (0,54–1,74 mm) | 1. Medir `v` sobre la superficie real en el shader: `d = v / \|∇v\|`, con el gradiente desde `dFdx`/`dFdy` de `VERTEX` y `UV.y`. 2. Recalcular las filas en las 10 formas | **1.** Sin datos nuevos, y en el estado anime `d = v`. Si no cumple §6, plan B: la opción 2 |
| e) Los 6 triángulos de piel de `subset` | 1. Lazo limpio: las orejas pasan a la bolsa. 2. Elegir 724 por contigüidad | **1.** Medido: **730 triángulos, 412 vértices del `.glb` y 0 de piel** con la regla de `BodyDerived.subset`; no hace falta código de contigüidad |

### 5.3 Forma corregida y los «0 cruces»

**El criterio no cambia.** Se cumple corrigiendo la malla, sin tocar sus vértices ni sus caras:

1. **Lazo limpio:** se quitan del lazo las 6 puntas (7, 14, 17, 31, 32 y 36), que pasan al interior de la bolsa. Quedan **36 vértices**, con esquinas en los índices 0 y 20 del lazo limpio (arcos de 21 y 17 puntos). Se aparta de la elipse como mucho **0,28 mm**.
2. **Plano del lazo:** normal de Newell, `u = Y × n`, `v = n × u`.
3. **Bolsa:** su posición en ese plano es la media de sus vecinos con el lazo fijo (700 pasadas). La profundidad se conserva.
4. **Corona (anillos 1–5, 177 vértices):** cada vértice en (ángulo, radio relativo al lazo), media de vecinos con el lazo y el anillo 6 fijos (700 pasadas, ángulo por el camino corto). La altura, también por media de vecinos. Mueve la piel 2,64 mm de media y **6,54 mm como máximo**, y su altura hasta **2,35 mm**.
5. **Formas de ojo:** el movimiento de los anillos 1–5 y de la bolsa es la extensión armónica del movimiento del lazo y del anillo 6. Es lineal, así que vale en todo el recorrido del deslizador.

**Resultado:** **0 cruces en reposo.** En los extremos, de 0 a 7 cruces y de 0 a 3 invertidos por ojo. **Al 100 % no se cumple**, así que hay que recortar o usar formas propias (AC.3 §5.3 b y c):

| Deslizador | Sentido | MakeHuman: limpio hasta | Propia sobre el lazo: limpio hasta | Recomendación |
| --- | --- | --- | --- | --- |
| Tamaño | reducir | 55 % | −40 % de tamaño | Propia, −25 % |
| Tamaño | aumentar | 95 % | **+16,5 %** | Propia, +16 % |
| Alto | reducir | 40 % | 100 % de −20 % | Propia |
| Alto | aumentar | 100 % | 80 % de +20 % (+16 %) | Propia |
| Separación | hacia dentro | 100 % | 95 % de −3,4 mm | MakeHuman |
| Separación | hacia fuera | 70 % | 70 % de +4,6 mm | MakeHuman, recortada al 70 % |
| Altura | bajar | 100 % | 100 % de −2,9 mm | MakeHuman |
| Altura | subir | **65 %** | 45 % de +6,1 mm | MakeHuman recortada al 65 %: **bajo el 70 % provisional, lo decide el responsable** |
| Inclinación | los dos | 55 % | 100 % de ±9° | Propia |

- Las formas de ojo no mueven huesos (medido): `articulaciones.json` no debería cambiar, y la prueba lo confirma.
- **Sin medir:** dos deslizadores de Ojos a la vez (40 combinaciones). AC.3b.0 las da como `MEDIDA`, sin decidir por su cuenta.
- **Si el responsable prefiere otra cosa:** cambiar el criterio a «sin píxeles visibles en el render» solo se propone si este método falla en Blender, con la medida delante (regla 9).

### 5.4 Datos (`ojos.json`)

Archivo opcional, en el manifiesto; `version` sigue en 3.

```json
{"version": 1,
 "l": {"lazo": [0], "esquinas": [0, 20], "arco_superior": [0], "arco_inferior": [0],
       "bolsa": [0], "uv": [[0.0, 0.0]], "altura": [0.0], "centro": [0.0, 0.0, 0.0], "normal": [0.0, 0.0, 1.0]},
 "r": {}}
```

- Índices del `.glb` (por vértice, con los repetidos de las costuras en `bolsa`). `uv` y `altura` (de 0 a 1 entre párpados) van con cada índice de `bolsa`.
- **Se guardan en el estado anime, en Blender.** La copia los calculaba al cargar, y con otro personaje saldrían distintos.
- **POR MEDIR (AC.3c):** que Godot conserve el orden de los vértices del `.glb`. Se compara la posición de cada índice con la de Blender (≤ 0,01 mm). Si no coincide, parar y guardar posiciones en lugar de índices.
- AC.6a añade `tira_superior`, `tira_inferior` y `pliegue`: por vértice, `ids`, `bary`, `offset` y `uv`. Se calculan una vez en Blender: así la carga no lanza rayos.

### 5.5 Núcleo y capas

```gdscript
class_name EyeMesh  # godot/addons/creador/eye_mesh.gd, sin interfaz
static func build(body: MeshInstance3D, skeleton: Skeleton3D, eyes: Dictionary) -> Array[MeshInstance3D]
static func layer_material(layer: int, values: Dictionary) -> ShaderMaterial
```

- `SpeciesData` lee `ojos.json` si existe, en `species.eyes` (vacío si no). Ningún nombre de la humana en el código.
- Una malla por ojo con **los mismos vértices, huesos, pesos y formas** (`_piece` del prototipo), normal única y `uv` de `ojos.json`. Tres instancias con un solo shader: 0 blanco, 1 iris y pupila, 2 brillos, con `depth_pull` de 0,05, 0,10 y 0,12 mm.
- `body_view.gd` las cuelga con `BodyPiece.hang`, las añade a `updater.pieces` (siguen a las formas) y **no** a `pieces`, para que no salgan como piezas del pack ni en el preset.
- **Luz:** `light()` y `shade_of()` de `toon_soft` (D48), no el tinte fijo de la copia, y sin `EMISSION`. La sombra del blanco puede variar un poco respecto a `ojo_final.png`: lo juzga el responsable. SH.3 debe cambiar también este shader; una prueba compara el texto de las dos `light()` para que no se olvide.
- **Android:** `zonas_solo_pc` no carga las formas de Ojos; `build` copia solo las formas que existen.

### 5.6 Restricciones

| Restricción | Cómo se cumple |
| --- | --- |
| El núcleo no depende de la interfaz | `EyeMesh` y sus shaders en `addons/creador/`; el montaje, en `body_view.gd` |
| La humana es una especie | Todo sale de `ojos.json`; sin archivo, sin capas |
| Pack MakeHuman | Hoy 43.991.380 bytes, **quedan 8.620**. Afectan 25 de sus 35 piezas (las 31 de la AC.3 suman las de otros packs: 1 base y 5 Quaternius). AC.3b.0 regenera en la copia y mide **antes** de escribir. Si no cabe, parar: el límite es del responsable |
| 6 capturas aprobadas | Cambian. Se generan al cerrar AC.3c, una sola vez, y volver a aprobarlas lo decide el responsable (regla 9) |
| Forward+ y Mobile | Las capturas de AC.3c, AC.4 y AC.6a se sacan en los dos. No se usan funciones exclusivas de Forward+ |
| Pesos | Máximo 4, normalizados a 1, como `_piece`. Al doblar un hueso las tiras pueden separarse: se mide en AC.6a |
| Color por vértice | Ningún dato nuevo en el RGB. Lo nuevo va en `ojos.json` |
| `.glb` | §5.7 |

### 5.7 El `.glb` y la igualdad con `ojo_final.png`

**`.glb` (AC.6b):**

- Mallas `ojo_l`, `ojo_r`, `linea_l` y `linea_r`, con el mismo esqueleto, horneadas y sin shader.
- `ojo_*` lleva blanco, iris, pupila y brillos en **una textura horneada por CPU** (`EyeTexture`, como `GarmentTexture`). `linea_*`, textura con alfa. Tamaño y bytes: POR MEDIR, de partida 256 × 256.
- **Bolsa bajo el ojo:** en el `.glb` no hay `depth_pull`, y dos superficies iguales parpadearían. Se hunden 1 mm los vértices interiores de la bolsa en la copia horneada. Sigue la malla completa y el lazo no se mueve.
- `_color_pieces` pintaría estas mallas de un color plano: `glb_exporter.gd` debe saltárselas. **Esto cambia lo que dijo AC.3 §4** («no se toca»).
- El rubor no sale hasta SH.8, que decide cómo viaja.

**Igualdad:** `ojo_final.png` usa el toon anime, el contorno teñido y el rubor. En el programa eso llega con SH.4b, SH.7 y SH.8. Hasta entonces, las capturas de comparación encienden `soft_enabled` y usan una copia del contorno teñido **solo en la prueba**, con la cámara del prototipo, y se comparan sin el rubor.

### 5.8 Orden y cambios sobre AC.3

Se respeta el orden del PLAN: **AC.3b, AC.3c, AC.4, AC.5, AC.6, SH.8**, con dos añadidos: AC.3b.0 (puerta en una copia) y AC.6b (`.glb`). AC.3b.1 y AC.3c se **cierran seguidos**: entre los dos, el programa enseñaría una cuenca de color piel.

Cambia respecto a AC.3: 730 triángulos en lugar de 724 (§7.7 y §5.5), `eye_layers.gdshader` en lugar de `eye_white.gdshader`, y `glb_exporter.gd` sí se toca. **Las cejas del AC.6 no están en el prototipo aprobado:** no entran aquí y necesitan su propio diseño.

### 5.9 Tamaño propio y giro de cámara

- **Tamaño (AC.3 §5.3 d):** con el método nuevo, el propio queda limpio de **−40 % a +16,5 %**. Cumple −25 % y **no llega a +25 %**. Objetivo provisional: lo decide el responsable. La técnica que faltaba («que el párpado absorba el cambio») es la corona de §5.3.
- **Forma y giro de cámara:** aceptados por el responsable el 2026-11-22 sobre `pruebas/capturas/ac3b/ab_forma.png` y `giro.png`, **con la condición de corregir antes de AC.3b.1** cuatro problemas que «se notan demasiado»: contorno dentro del ojo, peinados que se mueven, ojos grandes (Tamaño + Alto) e iris en tres cuartos.
- **Pack:** cada pieza se queda solo con las formas que ya lleva (decisión del responsable, 2026-11-22). El pelo y la ropa siguen sin acompañar a las formas de cara del 9.2a.
- **AC.3b.0 cerrado (2026-11-23).** El responsable acepta el ojo y los peinados de `pruebas/capturas/ac3b/`. Aprobado: máscara de contorno en `TEXCOORD_1` de `cuerpo.glb` (bolsa y anillos 1–5; 0,5 en el 6) que anula `width_px` y empuja el casco con `clip.z`, tocando `outline.gdshader`; límite de bulto del iris y los brillos ≤ 2,0 px a ±35° (medido 1,52); retoque de `cuenca_plana` en 39 vértices de 6 piezas. La mancha de la nariz, más visible sin el apaño del prototipo, se resuelve en SH.4. El prototipo se queda fuera de git; receta en `pruebas/capturas/ac3b/proto/LEEME.md`.
- **AC.3b.1 y AC.3c preparados en una copia (2026-11-23), sin aplicar.** El responsable decide esperar al iris: hoy el programa no tiene ojos y, solo con el blanco, quedarían ojos blancos sin iris. Parche en `pruebas/capturas/ac3c/parche/` (23 archivos, con `sha256` en `LISTA.txt`), hecho sobre el commit `c3eea38`. Antes de aplicarlo, comprobar que sus archivos no han cambiado (SH.3 también toca `body_view.gd`). Decisiones pendientes al aplicar: la rotura literal «quitar `_extend`» no da FALLO, porque `_soften` ya reparte el movimiento (se propone «sin extensión ni reparto»); y si las 6 capturas aprobadas se dejan como están (cambian ≤ 43 de 972.000 px, 0 fuera de cabeza y cuello). El `.glb` exportado llevará `TEXCOORD_1` (116.136 bytes).
- **AC.3b.1 y AC.3c aplicados (2026-11-23).** El responsable aprueba la rotura «sin extensión ni reparto», que da FALLO, y deja las 6 capturas aprobadas como están.
- **AC.4 aplicado (2026-11-24); para más adelante:** el responsable ve en tres cuartos el ojo con una leve curva hacia dentro de la cara, «como si estuviera hundido» (`pruebas/capturas/ac4/programa/`). No molesta: se corrige más adelante, no en AC.5.
- **AC.6a hecho (2026-11-24).** Cambios respecto a §5: las filas se apoyan por la normal del ojo (no la de estilo de cada columna) en la primera cara visible por orden de vértices (piel o blanco), y **sin la corrección `d = v / |∇v|`** de §5.2 d: con §5.2 c el grosor de la línea de abajo cambia como mucho un 7,2 % y la corrección la afinaba de frente (0,38 frente a 0,61 mm en u 0,42). La rotura «d = v sin corregir» se sustituye por «filas de dentro sin formas» (63 %, FALLO). `EyeMesh.build` devuelve también las 6 tiras; `probar_base_ojo` y `probar_iris` filtran `ojo_*`.

## 6. Pruebas

Solo las del subpaso. La batería completa, cuando la pida el responsable. Límites nuevos con `# PROVISIONAL`.

| Subpaso | Comprueba | Rotura que debe dar FALLO | Qué ve el responsable |
| --- | --- | --- | --- |
| AC.3b.0 | Repite §5.3 en Blender con los dos ojos y el contador del AC.3a: 0 cruces en reposo y en los recorridos; bytes del pack; píxeles de contorno dentro de la abertura = 0 (contorno magenta, 5 cámaras); diferencia de las piezas | Dejar las orejas en el lazo | `ab_forma.png` (ahora / corregida, con `ojo_final.png` al lado), `giro.png`, `medidas.md` |
| AC.3b.1 | `probar_forma_ojo.py`: 13.380 / 13.378; simetría ≤ 0,5 mm; 0 cruces e invertidos; holgura ≥ 0; fuera de cabeza y cuello ≤ 0,5 mm; `articulaciones.json` idéntico. Además, `probar_carga`, `probar_formas_rasgos`, `probar_formas_cara.py`, `probar_packs` y la autoprueba | Sin extensión ni reparto (`_extend` y `_soften`); un índice mal en `ojos.json` | Nada todavía: se cierra junto a AC.3c |
| AC.3c | `probar_base_ojo.gd`: 730 caras por ojo; capa–cuerpo 0,000 mm en los 10 extremos; orden de índices; sin `ojos.json` carga bien; a oscuras, canal máximo ≤ 0,01; `light()` igual a la de `toon_soft` | Blanco sin formas; `EMISSION`; borrar `ojos.json` | Blanco en 3 tonos, esquina exterior, cámara de juego, escena omni, Forward+ y Mobile, y las 6 capturas nuevas |
| AC.4 | Iris con `iris_cover` 30 %: borde inferior y `w` no dependen de c; color y tamaño cambian solo sus uniforms | `w` dependiente de c | Primer plano frente a `ojo_final.png`, piel clara y oscura, iris rojo y azul |
| AC.5 | Brillos en el mismo lado en los dos ojos; radio ≤ 12 % de a; a oscuras no brillan | Reflejar `uv.x` en el derecho | El mismo primer plano |
| AC.6a | Tira–lazo ≤ 0,05 mm en los 10 extremos; altura ≥ −0,18 mm; **grosor de la línea inferior ±15 %** de su valor en cada extremo; separación al doblar cabeza y cuello: `MEDIDA` | Hundir 1 mm una fila; tira sin formas; `d = v` sin corregir | `extremos_primer_plano` nuevo frente al aprobado |
| AC.6b | `probar_glb`: mallas nuevas, ≤ 4 pesos que suman 1, sin formas sueltas; la bolsa queda detrás del ojo; sin shader en el `.glb` | Exportar sin hundir la bolsa | `.glb` abierto en Godot a 6 m y de cerca |

Al cerrar AC.3c, AC.6a y AC.6b se propone el revisor-visual.

## 7. Trampas conocidas

1. **Forma y aspecto:** la corona mueve piel visible hasta 6,54 mm. Por eso AC.3b.0 es una puerta: sin su juicio no se escribe nada.
2. **Ojo derecho:** se genera por reflejo. Comprobar que `rim_r` sigue el orden de AC.4a §5.1 también en el lazo limpio.
3. **Las esquinas se fijan por índice** en reposo, no por «x máxima» (AC.4a §5.1).
4. **Piezas junto al ojo:** copian las formas de la piel. Un flequillo puede cambiar aunque el pack quepa.
5. **`StyleNormals`** trata la cabeza como un elipsoide; las capas usan su normal única. Comprobar que no aparecen bandas.
6. **`render_priority` y transparencia:** orden blanco → iris → brillos → línea, también con pelo delante.
7. **`light()` duplicada:** SH.3 cambia la de `toon_soft`. La prueba de AC.3c avisa si se separan.
8. **Origen del engorde:** los «0,54–1,74 mm» solo constan en la cabecera de AC.4a, no en `medidas.md`. AC.6a lo mide de nuevo antes de corregirlo.

## 8. Juicio visual

Se dan solo las rutas, sin describir ni valorar.

- **AC.3b.0:** ¿la forma corregida conserva el ojo aprobado? ¿El giro de cámara se acepta?
- **AC.3c:** ¿el borde es limpio? ¿El blanco se oscurece con la piel? ¿Se aceptan las 6 capturas nuevas?
- **AC.4 y AC.5:** ¿el iris y los brillos son los de `ojo_final.png`?
- **AC.6a:** ¿la línea, las pestañas y el pliegue son los aprobados, también en los extremos?
- **AC.6b:** ¿el `.glb` se ve bien fuera del editor?
- **Tras SH.8:** ¿el programa se ve igual que `ojo_final.png`?

## 9. Si te atascas

Para y dilo si: el método no da 0 cruces en Blender, el pack no cabe, `articulaciones.json` cambia, el orden de vértices no se conserva, queda contorno dentro de la abertura, la línea no cumple con los dos métodos de §5.2 d), o una prueba que pasaba deja de pasar sin causa evidente. No se relaja ningún límite ni se añade otro apaño.
