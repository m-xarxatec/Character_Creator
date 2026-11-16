# Hoja de ruta — del MVP al objetivo final (PROPUESTA, sin aprobar)

> Propuesta del 2026-11-16. No cambia `PLAN.md` ni `IDEAS.md`: cada fase entra en el plan solo cuando el responsable la apruebe.
> **Sin comprobar** (regla 4): las API de Godot 4.7 que se nombran aquí salen de la documentación de 4.4 y de lo que ya usa el proyecto; cada fase empieza comprobándolas. Las licencias marcadas «comprobar» no están verificadas.

Punto de partida: Fases 0–4 cerradas; quedan del MVP la 5 (banco de huesos), la 6 (formas propias) y la 7 (entrega).

---

## 1. Tabla de huecos

Estado: **Hecho** · **MVP** (pendiente en `PLAN.md`) · **IDEAS** (apuntado) · **Falta** (no está en ningún sitio). Tamaño: S (días), M (1–2 semanas), L (más).

### Cuerpo y base

| Función | Estado | Enfoque en Godot | Assets y licencia | Riesgo | Tam. | Depende de |
| --- | --- | --- | --- | --- | --- | --- |
| Deslizadores de cuerpo (40 filas) | Hecho | Formas + escala de hueso | MakeHuman CC0 | — | — | — |
| Formas «Por crear» (3) y alisado bajo la prenda | MVP (6.1) | Formas nuevas en `datos/` | Propias (MakeTarget) | Medio: esculpir a mano | M | Fase 5 |
| Más deslizadores de cuerpo | IDEAS | Filas nuevas en el CSV | MakeHuman CC0 | Bajo | S | — |
| Edad (adulto joven → mayor) | IDEAS | Macro `age` de 0,5 a 1; recortada en datos y en el núcleo | MakeHuman CC0 | Medio: suma correcciones | M | 6.2 |
| Chibi (2,5–3 cabezas) | IDEAS | Formas propias o segunda base | Propias o Quaternius CC0 | **Alto**: hoy 5,25 cabezas | L | Fase 6, decisión D1 |
| Presets con miniatura | Falta | Render en `SubViewport` al guardar | Propios | Bajo | S | Guardar/cargar en ventana |
| Guardar y cargar personaje en la ventana | Falta | `Preset` ya existe; falta el diálogo | — | Bajo | S | — |
| Deshacer en todas partes | Falta (hoy solo valores) | Historial de órdenes único en `app/` | — | Medio: tocar lo hecho | M | — |

### Cara

| Función | Estado | Enfoque en Godot | Assets y licencia | Riesgo | Tam. | Depende de |
| --- | --- | --- | --- | --- | --- | --- |
| Formas de cara anime (5) | Hecho, sin interfaz | Zona `Cara` oculta | Propias (script sobre MakeHuman) | — | — | — |
| Deslizadores por rasgo (ojos, cejas, nariz, boca, mandíbula, mentón, orejas) | IDEAS | Filas del CSV con targets de cara de MakeHuman | MakeHuman CC0 | Medio: se suman a las formas anime; hay que medirlo | M | Pestaña Cara |
| Conjuntos de cara listos | Falta | Presets parciales (solo zona Cara) | Propios | Bajo | S | Deslizadores de cara |
| Ojos de verdad (no calcomanía) | IDEAS | Malla de ojo propia + shader de iris; sigue a la cuenca | Propios | **Alto**: la calcomanía se deforma de perfil | L | Decisión D2 |
| Iris intercambiable, color libre | Falta | Textura de iris en gris + color en shader | Propios (dibujados) | Medio | M | Ojos |
| Cejas y pestañas | Falta | Malla o calcomanía sobre la cara | Propias o MakeHuman CC0 | Medio | M | Ojos |
| Bolsas de boca y ojos aplastadas (58 mm) | IDEAS (deuda) | Rehacer las formas sin tocar el interior | Propias | **Alto**: bloquea abrir la boca | M | — |
| Expresiones y visemas | IDEAS | Formas con nombre de VRM (`aa`, `blink`…) | Propias; MakeHuman trae expresiones (licencia: comprobar) | Alto | L | Bolsas, ojos |

### Pelo, ropa y accesorios

| Función | Estado | Enfoque en Godot | Assets y licencia | Riesgo | Tam. | Depende de |
| --- | --- | --- | --- | --- | --- | --- |
| Sistema de piezas (pack: `.glb` + ficha + miniatura) | IDEAS | Cargador en el núcleo; ranuras | — | Medio: es el formato de todo lo demás | M | — |
| Peinados como piezas | IDEAS | Malla con piel al hueso `Head`; se escala con la cabeza | Quaternius CC0 (8), MakeHuman CC0 | Medio: ajuste a cabezas distintas | M | Piezas |
| Física de mechones | IDEAS | `SpringBoneSimulator3D` (existe desde 4.4) con huesos extra | — | Medio: presupuesto de huesos (≤ 75) | M | Peinados |
| Pincel de mechones | IDEAS | Generar malla a lo largo de curvas | Propios | **Muy alto** | L+ | Todo lo anterior |
| Prendas que siguen al cuerpo | IDEAS | Cada vértice de la prenda atado a 3 vértices del cuerpo (como `.mhclo`, reimplementado desde su documentación) | MakeHuman CC0 | **Alto**: es el paso más técnico | L | Piezas |
| Capas y ocultar la piel | IDEAS | Máscara por vértice (como `garment`) + orden de capas | — | Medio | M | Prendas |
| Plantilla de textura editable | Falta | Exportar la UV como PNG; cargar un PNG | Propios | Bajo | S | Prendas |
| Accesorios en anclajes | IDEAS | Hijo del nodo de anclaje; ya existen los 4 | CC0 o propios | Bajo | S | Piezas, 5.6 |

### Aspecto, estudio y exportación

| Función | Estado | Enfoque en Godot | Assets y licencia | Riesgo | Tam. | Depende de |
| --- | --- | --- | --- | --- | --- | --- |
| Acabado en vivo (piel, borde, rim, contorno) | Hecho | `BodyMaterial.FINISH` | — | — | — | — |
| Estilo como archivo de datos | IDEAS | JSON → `BodyMaterial` (tonos, tinte, color del contorno) | Propios | Bajo | M | — |
| Contorno por zona | IDEAS | Grosor por color de vértice | — | Medio | M | — |
| Pantalla inicial con estilos | IDEAS | Base + acabado; render propio por botón | Propios | Medio: pide varias bases | M | Estilos, D1 |
| Luz de vista previa | IDEAS | Ángulo e intensidad en `body_view` | — | Bajo | S | — |
| Reproducir animaciones | MVP (5.1) | `AnimationPlayer` con retargeting | Quaternius CC0 | Bajo | — | Fase 5 |
| Posar a mano | Falta | Girar huesos con el ratón; biblioteca de poses en JSON | Propias | **Alto**: interfaz difícil | L | Fase 5 |
| Captura PNG con fondo transparente | Falta | `SubViewport` con `transparent_bg` | — | Bajo | S | — |
| Solo contorno | Falta | Material blanco sin luz + contorno | — | Bajo | S | — |
| Hoja de giro (frente, perfil, espalda, 3/4) | Falta | 4–5 capturas con cámara ortogonal, unidas en una imagen | — | Bajo | S | Captura |
| `.glb` para Godot y Blender | Hecho | `GLTFDocument` | — | Reserva: borde de la prenda sin el `.tres` | — | — |
| VRM 1.0 | IDEAS | Extensiones `VRMC_*` sobre el glTF. No hay exportador en Godot; el addon `godot-vrm` (MIT) existe, pero no he comprobado si exporta 1.0 | — | **Alto** | L | Expresiones, pelo, D6 |
| Niveles de detalle | IDEAS | Proxies de MakeHuman | MakeHuman CC0 | Medio | M | — |
| Interfaz con estilo propio | IDEAS | `Theme` de Godot según la maqueta | Fuente con licencia libre (comprobar) | Bajo | M | — |

---

## 2. Fases propuestas después del MVP

Orden propuesto: **8 Cimientos → 9 Cara → 10 Estudio → 11 Pelo y accesorios → 12 Ropa → 13 Aspecto → 14 VRM → 15 Pulido.**

Dos cambios respecto al orden orientativo, en una frase cada uno:

- **El Estudio sube al tercer puesto:** es barato, reutiliza el banco de la Fase 5 y da ya el segundo uso del editor (referencias de dibujo).
- **Los accesorios van con el pelo:** usan el mismo sistema de piezas y los anclajes ya existen.

### Fase 8 — Cimientos de producto

- [ ] 8.1 Guardar y cargar personaje desde la ventana (`Preset`), con miniatura.
- [ ] 8.2 Deshacer único: prenda, acabado y carga de preset entran en el mismo historial que los valores.
- [ ] 8.3 Tema de la interfaz según la maqueta (colores, tipografía, espaciado), como un recurso `Theme`.
- [ ] 8.4 Pestañas preparadas: cada pestaña es un archivo de `app/` que solo habla con el núcleo.

**Hecho cuando:** se guarda un personaje, se cierra el editor, se abre y se carga con su miniatura; Ctrl+Z deshace cualquier cambio.

### Fase 9 — Cara y ojos

- [ ] 9.1 **Rebanada vertical:** pestaña Cara con las 5 formas que ya existen como deslizadores (datos → núcleo → interfaz → `.glb` → prueba). Cámara que enfoca la cara al abrir la pestaña.
- [ ] 9.2 Arreglar las bolsas de la boca y los ojos (deuda de 58 mm): prueba con medida antes de añadir nada.
- [ ] 9.3 Ojos de verdad: malla propia que sigue a la cuenca, iris con color libre. Se quita la calcomanía.
- [ ] 9.4 Deslizadores de ojos: tamaño horizontal y vertical, posición, inclinación, separación, párpados.
- [ ] 9.5 Cejas, nariz, boca, mandíbula, mentón y orejas: filas nuevas con targets de MakeHuman; medir la suma con las formas anime.
- [ ] 9.6 Conjuntos de cara (presets parciales) y selector de iris.
- [ ] 9.7 Expresiones básicas (parpadeo, alegría, enfado, sorpresa, tristeza) y visemas (a, i, u, e, o), con nombres de VRM.

**Hecho cuando:** dos caras claramente distintas se crean solo con el ratón, se exportan y parpadean en un proyecto vacío.

### Fase 10 — Estudio de fotos y referencias de dibujo

- [ ] 10.1 **Rebanada vertical:** pestaña Estudio con una pose (reposo), cámara de frente y captura PNG con fondo transparente.
- [ ] 10.2 Animaciones del banco (Fase 5) con barra de tiempo: parar en cualquier fotograma.
- [ ] 10.3 Hoja de giro: frente, perfil, espalda y tres cuartos, cámara ortogonal, en un solo PNG.
- [ ] 10.4 Modo solo contorno y control de luz (ángulo e intensidad).
- [ ] 10.5 Biblioteca de poses en JSON (10–15 poses propias).
- [ ] 10.6 Posar a mano: girar huesos con el ratón (solo si se aprueba la decisión D4).

**Hecho cuando:** sale una hoja de giro PNG de un personaje en una pose elegida, con fondo transparente y en modo contorno.

### Fase 11 — Pelo y accesorios

- [ ] 11.1 Formato de pack (`.glb` + ficha `.json` con tipo, ranura, autor, licencia y origen + miniatura) y cargador en el núcleo.
- [ ] 11.2 **Rebanada vertical:** un peinado CC0, de punta a punta: pack → pestaña Pelo → sigue al tamaño de la cabeza → color → `.glb`.
- [ ] 11.3 Conversor de los peinados de Quaternius y MakeHuman a packs.
- [ ] 11.4 Mechones con `SpringBoneSimulator3D`; presupuesto de huesos comprobado por prueba.
- [ ] 11.5 Accesorios: un pack por anclaje (4), con el mismo cargador.

**Hecho cuando:** un personaje con peinado y un accesorio se exporta, y el pelo se mueve al caminar en un proyecto vacío.

### Fase 12 — Ropa

- [ ] 12.1 **Rebanada vertical:** una prenda CC0 (camiseta) que sigue al cuerpo neutro y a un cuerpo extremo, exportada.
- [ ] 12.2 Atado de la prenda al cuerpo en el núcleo (reimplementado; sin código de MPFB); prueba: la prenda no atraviesa la piel (medida en mm) en 10 cuerpos al azar.
- [ ] 12.3 Ocultar la piel de debajo (máscara por prenda).
- [ ] 12.4 Capas (interior, superior, inferior, calzado, exterior) y orden.
- [ ] 12.5 Plantilla de textura: exportar la UV y cargar un PNG propio.
- [ ] 12.6 Conversor de prendas CC0 de MakeHuman a packs.

**Hecho cuando:** un personaje con tres prendas en capas se anima sin que la piel atraviese la ropa.

### Fase 13 — Aspecto y estilos

- [ ] 13.1 **Rebanada vertical:** un estilo como archivo JSON que se carga, cambia el acabado y viaja al `.tres`.
- [ ] 13.2 Tinte de sombra, color del contorno y 2 tonos.
- [ ] 13.3 Contorno por zona (arregla los grumos de los dedos).
- [ ] 13.4 Pantalla inicial con estilos, cada uno con un render propio.

**Hecho cuando:** añadir un estilo es añadir un archivo, y aparece en la pantalla inicial con su miniatura.

### Fase 14 — Exportar VRM 1.0

- [ ] 14.1 Comprobar herramientas: qué exporta hoy `godot-vrm` (MIT) y qué habría que escribir.
- [ ] 14.2 **Rebanada vertical:** solo el cuerpo, con los metadatos y el humanoide de VRM, validado con un visor libre.
- [ ] 14.3 Expresiones, mirada y huesos con muelle (`VRMC_springBone`).
- [ ] 14.4 Material MToon a partir del acabado.

**Hecho cuando:** el `.vrm` se abre en dos programas libres distintos sin errores.

### Fase 15 — Pulido

- [ ] 15.1 Rendimiento: ningún deslizador tarda más de un fotograma (medido).
- [ ] 15.2 Botón aleatorio, comparar antes y después, medidas en cm.
- [ ] 15.3 Windows y comando en el PATH.

**Hecho cuando:** una persona nueva crea un personaje completo en 10 minutos sin ayuda.

---

## 3. Decisiones que necesito antes de cada fase

| N.º | Antes de | Decisión | Opciones | Recomiendo |
| --- | --- | --- | --- | --- |
| D1 | Fase 6 | Cómo se llega al chibi | (a) formas propias sobre MakeHuman; (b) segunda base (Quaternius, sin formas); (c) dejarlo fuera | (a): mantiene todos los deslizadores; (b) solo si (a) no llega a 3 cabezas |
| D2 | Fase 9 | Sistema de ojos | (a) malla propia con iris en shader; (b) calcomanía mejorada | (a): la calcomanía ya falla de perfil |
| D3 | Fase 9 | ¿Se admite CC-BY? (pendiente en `IDEAS.md`) | sí con crédito / no | No por ahora: CC0 y lo propio bastan hasta la Fase 12 |
| D4 | Fase 10 | Posado a mano | (a) solo biblioteca de poses; (b) girar huesos con el ratón | (a) primero; (b) al final de la fase si sobra |
| D5 | Fase 11 | Dónde viven los packs | (a) dentro de `datos/<especie>/`; (b) carpeta `packs/` aparte | (b): los packs los añade el usuario; `datos/` lleva `sha256` |
| D6 | Fase 14 | VRM: usar `godot-vrm` o escribirlo | addon (dependencia nueva, MIT) / propio | Decidir tras el 14.1, con lo que exporte de verdad |
| D7 | Fase 5 | Huesos: 53 o 56 | El 5.3 dice 56; se exportan 53 | Corregir el 5.3 a 53, salvo que se añadan ojos y mandíbula en la Fase 9 |

---

## 4. Qué no haría, y por qué

- **Pincel de mechones:** es un editor dentro del editor. Mucho coste y los peinados por piezas cubren el 90 % del valor. Solo después de todo lo demás.
- **Posado a mano completo (IK, dedos):** Blender ya lo hace mejor; aquí basta con poses hechas y animaciones parables.
- **Simulación de tela:** las prendas atadas al cuerpo más huesos con muelle en faldas dan casi lo mismo, sin coste en el juego.
- **Hiperrealismo y texturas de piel:** contradice el estilo y pide assets que no tenemos con licencia limpia.
- **Catálogo en línea y versión web o Android:** antes hace falta un editor completo en escritorio.
- **Rig automático con IA:** dependencia pesada y sin relación con el objetivo.
- **Segunda especie:** el núcleo ya no supone la humana; construir otra ahora no acerca la meta.
