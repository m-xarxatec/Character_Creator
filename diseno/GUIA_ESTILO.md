# Guía de estilo — la meta, medible

> Guía del responsable del proyecto. El revisor la usa para comparar; no la cambia.
> Cada valor marcado **PROPUESTA (pendiente de aprobar)** sale del conocimiento general del estilo anime y chibi, no de medidas de este proyecto. Al aprobarlo, se quita la marca.

---

## 1. Objetivo

- Personajes **bonitos tipo VRoid**: anime 3D, limpios, agradables, listos para un juego.
- Además, el estilo del juego propio: **oscuro** (fantasía oscura, luz baja). "Oscuro" es el estilo del juego, no una proporción; el preset de proporciones se llama **chibi**.
- El aspecto VRoid, en palabras: cabeza algo grande, ojos grandes y expresivos, nariz y boca casi invisibles, piel lisa sin músculos marcados, sombras planas en pocas bandas con bordes limpios, contorno oscuro fino, colores suaves y cálidos.

---

## 2. Proporciones por preset

Medidas en "cabezas de alto" (altura total ÷ alto de la cabeza, de la barbilla a la coronilla).

| Medida | Anime femenino | Anime masculino | Chibi |
| --- | --- | --- | --- |
| Cabezas de alto | PROPUESTA (pendiente de aprobar): 6,5–7 | PROPUESTA (pendiente de aprobar): 7–7,5 | PROPUESTA (pendiente de aprobar): 2,5–3 |
| Piernas (de la ingle al suelo ÷ altura) | PROPUESTA (pendiente de aprobar): 0,50–0,55 | PROPUESTA (pendiente de aprobar): 0,48–0,53 | PROPUESTA (pendiente de aprobar): 0,25–0,35 |
| Hombros (ancho ÷ alto de la cabeza) | PROPUESTA (pendiente de aprobar): 1,4–1,6 | PROPUESTA (pendiente de aprobar): 1,8–2,1 | PROPUESTA (pendiente de aprobar): 1,0–1,3 |
| Cintura (ancho ÷ ancho de hombros) | PROPUESTA (pendiente de aprobar): 0,60–0,70 | PROPUESTA (pendiente de aprobar): 0,70–0,80 | PROPUESTA (pendiente de aprobar): 0,80–0,95 |
| Mano (largo ÷ alto de la cabeza) | PROPUESTA (pendiente de aprobar): 0,65–0,75 | PROPUESTA (pendiente de aprobar): 0,75–0,85 | PROPUESTA (pendiente de aprobar): 0,40–0,50 (algo grande para el cuerpo) |
| Pie (largo ÷ alto de la cabeza) | PROPUESTA (pendiente de aprobar): 0,85–0,95 | PROPUESTA (pendiente de aprobar): 0,95–1,05 | PROPUESTA (pendiente de aprobar): 0,50–0,65 (botas algo grandes) |

Por qué: el anime alarga las piernas y estrecha la cintura respecto a un humano real (unas 7,5 cabezas); el chibi encoge el cuerpo, no la cabeza, y agranda manos y pies para que se lean a poca resolución.

Medido en el 3.12: femenino 6,96, masculino 6,94, chibi 5,25 (fuera de rango, 3,46). **El chibi no llega con los deslizadores actuales**: necesita la segunda base o formas propias.

---

## 3. Cara (para cuando exista la pestaña Cara)

- **Ojos:** PROPUESTA (pendiente de aprobar): alto del ojo = 0,12–0,18 del alto de la cara (chibi: 0,20–0,28). Por qué: los ojos grandes son el rasgo que más define el anime.
- **Nariz:** PROPUESTA (pendiente de aprobar): casi plana; de frente, solo una sombra o un punto. Por qué: una nariz con volumen rompe el toon en manchas.
- **Boca:** PROPUESTA (pendiente de aprobar): pequeña, sin labios marcados; ancho ≤ 0,30 del ancho de la cara.
- **Evitar el "valle inquietante":** ojos grandes sobre una cara realista, párpados y pestañas de MakeHuman tapando ojos de anime, pliegues de piel, ojeras, poros, dientes visibles en reposo.

---

## 4. Sombreado toon

- **Número de tonos:** PROPUESTA (pendiente de aprobar): **3** (luz, medio y sombra), con bordes suaves de 0,02–0,06. Por qué: es lo que se probó en el 3.12 y con 2 la cara pierde volumen.
  - ⚠️ **Contradicción:** `CLAUDE.md` (tabla "Estilo") y `PLAN.md` (MVP y paso 3.10) dicen "sombra a dos tonos"; el 3.12 usó tres. Al aprobar este valor hay que corregir uno de los dos lados.
- **Luz de contorno (rim):** PROPUESTA (pendiente de aprobar): suave, fuerza 0,15–0,35, color cálido casi blanco. Por qué: separa la silueta del fondo oscuro sin parecer brillo.
- **Brillo especular:** ninguno. Por qué: el brillo hace que la piel parezca plástico.
- **Piel:** PROPUESTA (pendiente de aprobar): tono cálido; la sombra tira a rosado o rojizo, nunca a gris. Por qué: la sombra gris hace que la piel parezca enferma.

---

## 5. Contorno

- **Grosor:** regulable desde 0 (sin contorno) hasta muy grueso. PROPUESTA (pendiente de aprobar): rango 0–10 px.
- **Por defecto:** PROPUESTA (pendiente de aprobar): 2 px a distancia de juego (hoy el shader usa 2,5). Por qué: con más grosor los dedos de manos y pies hacen grumos.
- **Color:** PROPUESTA (pendiente de aprobar): casi negro y algo cálido, no negro puro.
- Sin roturas en las costuras ni contornos "flotando" separados de la malla.

---

## 6. Cámara del juego

- **Ángulo:** PROPUESTA (pendiente de aprobar): 40–50° desde arriba (unos 45°).
- **Distancia:** PROPUESTA (pendiente de aprobar): la que deja al personaje entre **64 y 128 px de alto** en una pantalla de 1080 px.
- **Legibilidad:** a ese tamaño se reconocen la silueta, la pose y hacia dónde mira el personaje. También con **luz baja** y con una luz de color (el juego es de fantasía oscura).

---

## 7. Presupuesto técnico por personaje

Medido hoy (solo cuerpo, `datos/humana/cuerpo.glb`): **26.756 triángulos**, 14.517 vértices, 53 huesos exportados, 1 material, textura de prenda de 2048 px, `.glb` exportado de 1,4 MB.

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
