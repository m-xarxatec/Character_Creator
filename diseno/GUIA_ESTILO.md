# Guía de estilo — la meta, medible

> Guía del responsable del proyecto. El revisor la usa para comparar; no la cambia.
> Cada valor marcado **PROPUESTA (pendiente de aprobar)** sale del conocimiento general del estilo anime, no de medidas de este proyecto. Al aprobarlo, se quita la marca.

---

## 1. Objetivo

- Personajes **bonitos tipo VRoid**: anime 3D, limpios, agradables, listos para un juego.
- Además, el estilo del juego propio: **oscuro** (fantasía oscura, luz baja). "Oscuro" es el estilo del juego, no una proporción.
- El aspecto VRoid, en palabras: cabeza algo grande, ojos grandes y expresivos, nariz y boca casi invisibles, piel lisa sin músculos marcados, sombras planas en pocas bandas con bordes limpios, contorno oscuro fino, colores suaves y cálidos.

---

## 2. Proporciones por preset

Femenino y masculino: **aprobados el 2026-11-20** (paso PL.1b) con los presets `femenino.json` y `masculino.json`,
medidas con `Measures.proportions()` (`godot/app/measures.gd`, en reposo): rango = lo medido ± 0,15 cabezas, ± 0,05 en
hombros y ± 0,03 en lo demás. Cómo se mide cada una: `ruta/pasos/PL.1_plantillas.md` §4 (hombros: ancho de la malla a
la altura de la articulación, por fuera; mano y pie: media de los dos lados).

| Medida | Anime femenino | Anime masculino |
| --- | --- | --- |
| Cabezas de alto (altura ÷ barbilla–coronilla) | 7,01–7,31 (7,16) | 6,97–7,27 (7,12) |
| Piernas (de la ingle al suelo ÷ altura) | 0,47–0,53 (0,503) | 0,49–0,55 (0,521) |
| Hombros (ancho ÷ alto de la cabeza) | 1,68–1,78 (1,73) | 1,90–2,00 (1,95) |
| Cintura (ancho ÷ ancho de hombros) | 0,51–0,57 (0,540) | 0,46–0,52 (0,490) |
| Mano (largo ÷ alto de la cabeza) | 0,57–0,63 (0,604) | 0,70–0,76 (0,733) |
| Pie (largo ÷ alto de la cabeza) | 0,71–0,77 (0,744) | 0,90–0,96 (0,934) |

Por qué: el anime alarga las piernas y estrecha la cintura respecto a un humano real (unas 7,5 cabezas).

Medido en el 3.12: femenino 6,96, masculino 6,94; los rangos propuestos entonces (sin medir) no encajaban con estos cuerpos y se cambiaron por lo medido en PL.1b.

**Chibi: sin preset ni rango** (el responsable, 2026-11-21, paso PL.9): Cabeza › Tamaño llega a ×2,5 y cada uno ajusta el resto con los deslizadores.

---

## 3. Cara (para cuando exista la pestaña Cara)

- **Ojos:** PROPUESTA (pendiente de aprobar): alto del ojo = 0,12–0,18 del alto de la cara. Por qué: los ojos grandes son el rasgo que más define el anime.
- **Nariz:** PROPUESTA (pendiente de aprobar): casi plana; de frente, solo una sombra o un punto. Por qué: una nariz con volumen rompe el toon en manchas.
- **Boca:** PROPUESTA (pendiente de aprobar): pequeña, sin labios marcados; ancho ≤ 0,30 del ancho de la cara.
- **Evitar el "valle inquietante":** ojos grandes sobre una cara realista, párpados y pestañas de MakeHuman tapando ojos de anime, pliegues de piel, ojeras, poros, dientes visibles en reposo.

---

## 4. Sombreado toon

Desde SH.7 (2026-11-23, D47–D54) el estilo por defecto es el **anime** (`toon_soft.gdshader`), parecido a VRoid: piel suave y rosada, sombra cálida, línea fina de color. Referencia del responsable: la imagen VRoid que adjuntó el 2026-11-23. El **clásico** (`toon.gdshader`, 3 tonos y contorno negro) sigue disponible apagando «Estilo anime» en Acabado.

- **Tonos:** **2** (luz y sombra) con borde corto y suave (`softness` 0,09, editable como «Suavidad de la sombra»). D47.
- **Color de sombra:** calculado desde el color de cada zona (más oscuro, más saturado y algo más rojo), para que cualquier color se vea bien. D48.
- **Tela oscura (SH.9):** la sombra baja **al menos 6/255 de valor** (sRGB), lo mismo que baja la piel oscura, que no cambia; y ningún color se pinta por debajo de **14/255**: el negro puro se lee gris muy oscuro (D47) y la línea se distingue de él. Medido con `probar_tela_oscura.gd` (luminancia /255): ropa 0,10, luz 25 y sombra 19–20; negro puro 13–14 y 6–8, con la línea en 1–3.
- **Banda cálida:** franja fina más saturada en el paso de luz a sombra (`edge_strength` 0,6). D52.
- **Brillo de piel:** satinado suave que multiplica el color de la piel donde da la luz (`gloss_strength` 0,35). D49 (cambia el «sin brillo» de antes).
- **Rubor, labios y pecas:** zonas generadas desde la geometría (`piel.png`); rubor 0,35, labios 0,45, pecas de 0 a 10 (0 por defecto). D52 y D54.
- **Cara:** sin sombra proyectada (`face_shadow_receive` 0; la nariz casi no se ve), un poco más de luz (`face_light` 0,15) y sin escalón en la sien (`StyleNormals.temple_blend` 0,35). D54.
- **Sombra proyectada:** sí en el cuerpo (cuello, ropa, pelo), de la luz principal; ninguna luz suma a otra (manda la más fuerte). SH.3 y SH.4.
- **Luz de contorno (rim):** fuerza 0,075 y ancho 0,3. **Pelo:** anillo de brillo («Brillo del pelo» 0,6), solo donde da la luz. SH.6b.
- Todo lo anterior se regula con deslizadores en Acabado → Piel y viaja en el preset (versión 3).

---

## 5. Contorno

- **Grosor:** regulable de 0 a 10 px; en estilo anime, 1,25 px por defecto y la mitad en la cara («Línea en la cara» 0,5).
- **Color:** en estilo anime, el de cada zona (piel, ropa o pelo) más oscuro («Color de la línea» 0,8); en el clásico, casi negro y algo cálido.
- Sin roturas en las costuras ni contornos "flotando" separados de la malla.

### Valores por defecto del estilo clásico

`probar_material.gd` comprueba que el código (`BodyMaterial`) tiene estos valores. Todos se cambian en el editor. Los del estilo anime están en `BodyMaterial.SOFT_DEFAULTS`, `default_finish(true)` y `SKIN_START` (lista de arriba).

| Qué | Código | Por defecto | Estado |
| --- | --- | --- | --- |
| Color de piel | `skin_color` | 0,80 / 0,80 / 0,80 | Gris neutro 0,80: aprobado el 2026-11-12 |
| Dureza del borde | `softness` | 0,04 | Aprobado el 2026-11-12 |
| Rim: fuerza | `rim_strength` | 0,25 | Aprobado el 2026-11-12 |
| Rim: ancho | `rim_width` | 0,3 | Aprobado el 2026-11-12 |
| Grosor del contorno (px) | `width_px` | 2,5 | Aprobado el 2026-11-12 |
| Tono medio (× color base) | `mid_shade` | 0,9 | Aprobado el 2026-11-12 |
| Sombra (× color base) | `shadow_shade` | 0,73 | Aprobado el 2026-11-12 |
| Normales del torso (pasadas de suavizado) | `StyleNormals.SMOOTH_STEPS` | 10 | Elegido en el 3.12 |
| Normales de la cara (fondo del elipsoide por delante) | `StyleNormals.FACE_DEPTH` | 0,6 | Elegido en el 3.13a-2; se revisa sobre la cara anime (`aplanado_anime_hoja.png`, 3.16) |

### Equivalencia con MToon (para la fase de VRM)

Solo documentación, sin código de MToon. Los nombres y fórmulas de MToon 1.0 están escritos de memoria y **sin comprobar** con su especificación: se comprueban en el paso 17.5. Los uniform con * llegan con la Fase SH (D47).

| Nuestro uniform | MToon | Traducción |
| --- | --- | --- |
| Color de sombra calculado, con `shade_strength`* | shadeColorFactor | El color de sombra ya calculado de la zona (MToon guarda el color final) |
| `threshold`* | shadingShiftFactor | `-threshold` |
| `softness` | shadingToonyFactor | `1 - softness`; aproximado: MToon usa rampa lineal y nosotros `smoothstep` |
| `rim_color` × `rim_strength` | parametricRimColorFactor | Aproximado: el nuestro también se multiplica por el color de la zona |
| `rim_width` | parametricRimFresnelPowerFactor, parametricRimLiftFactor | Sin conversión exacta: se ajusta comparando |
| Color de la zona × `outline_tint`* | outlineColorFactor | Con `outlineLightingMixFactor` = 0, porque nuestro contorno no recibe luz |
| `width_px` | outlineWidthFactor, con outlineWidthMode = screenCoordinates | `width_px` ÷ alto de la pantalla en píxeles |
| `ground_weight`*, `shadow_receive`*, `detail_tex`*, banda de brillo del pelo* (SH.6b) | Sin equivalente directo | Se decide en 17.5 |
| `blush_amount`* (color calculado desde la piel) | Sin parámetro propio | Depende de cómo viaje el rubor (SH.8) |

Piel y prenda comparten material: un solo `shadeColorFactor` no da las dos sombras, así que 17.5 necesitará una textura de sombra o un material por zona.

---

## 6. Cámara del juego

- **Ángulo:** PROPUESTA (pendiente de aprobar): 40–50° desde arriba (unos 45°).
- **Distancia:** PROPUESTA (pendiente de aprobar): la que deja al personaje entre **64 y 128 px de alto** en una pantalla de 1080 px.
- **Legibilidad:** a ese tamaño se reconocen la silueta, la pose y hacia dónde mira el personaje. También con **luz baja** y con una luz de color (el juego es de fantasía oscura).

---

## 7. Presupuesto técnico por personaje

Medido hoy (solo cuerpo, `datos/humana/cuerpo.glb`): **26.756 triángulos**, 14.517 vértices, 53 huesos exportados (56 desde el paso 9.3: ojos y mandíbula, sin pesos), 1 material, textura de prenda de 2048 px, `.glb` exportado de 1,4 MB.

| Recurso | PC | Móvil |
| --- | --- | --- |
| Triángulos (cuerpo + pelo + ropa) | PROPUESTA (pendiente de aprobar): ≤ 40.000 | PROPUESTA (pendiente de aprobar): ≤ 15.000 (pide malla ligera, ver IDEAS: selector de polígonos) |
| Huesos | PROPUESTA (pendiente de aprobar): ≤ 75 (56 humanoides + pelo y anclajes) | PROPUESTA (pendiente de aprobar): ≤ 60 |
| Materiales | PROPUESTA (pendiente de aprobar): ≤ 4 | PROPUESTA (pendiente de aprobar): ≤ 2 |
| Textura mayor | PROPUESTA (pendiente de aprobar): 2048 px | PROPUESTA (pendiente de aprobar): 1024 px |
| Tamaño del `.glb` | PROPUESTA (pendiente de aprobar): ≤ 10 MB | PROPUESTA (pendiente de aprobar): ≤ 4 MB |

Por qué: en un juego con varios personajes a la vez, el móvil es el límite; el PC admite el cuerpo completo.

---

## 8. Qué evitar

- Anatomía demasiado marcada: costillas, músculos, bultos, pecho y entrepierna bajo la prenda.
- Cortes, agujeros, caras invertidas, piel atravesando la prenda.
- Deformaciones al animar: hombros hundidos, codos y rodillas sin volumen, muñecas retorcidas.
- Contorno roto, con huecos o con grumos.
