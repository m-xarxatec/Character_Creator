# EXPANSIÓN v2 — tareas detalladas para el agente

> Propuesta del mentor (2026-11-18), pedida por el responsable: revisar `IDEAS.md`, listar lo que falta y preparar una gran expansión (interfaz estilo VRoid, cuerpos femenino y masculino, assets propios).
> **Nada de esto entra en `PLAN.md` sin el OK del responsable.** Cada paso necesita su ficha en `ruta/pasos/` antes de hacerse (regla 10). Lo que aquí va en una línea, la ficha lo detalla.
> Documentos hermanos: `diseno/GUIA_INTERFAZ.md` (cómo debe verse la ventana), `diseno/maqueta-v2.html` (maqueta), `ruta/HOJA_DE_RUTA.md` (fases 8 a 17, que siguen valiendo).
> Formato de cada paso: **Objetivo** · Archivos · Diseño · Prueba · Juicio visual · Nivel · Tamaño · Depende de.
> «Comprobar» = dato que el mentor no pudo verificar desde aquí. El agente lo comprueba con un script de 10 líneas antes de usarlo (`GUIA_MODELOS.md` §3, señal 3).

---

## 0. Resumen y orden recomendado

| # | Bloque | Qué consigue el usuario | Tam. | Modelo |
| --- | --- | --- | --- | --- |
| 1 | **0 — Cerrar la 0.1.0** | El MVP publicado (portafolio) | S | barato |
| 2 | **IU — Interfaz nueva** | Ventana bonita, clara e intuitiva, al estilo VRoid | L | barato para casi todo; Fable para IU.3 e IU.7 |
| 3 | **PL — Plantillas y cuerpos** | Empezar con un clic: Femenina, Masculino, Neutro, Atlética… Publicar la 0.2.0 (Linux) | M | barato; Fable para PL.0 y PL.8 |
| 4 | **10.1–10.2 — Proyecto `.gmolde`** (ya en la hoja de ruta) | Guardar personaje + piezas en un archivo | M | Fable para revisar |
| 5 | **AB — Assets base («Pack Base 1»)** | Ropa, pelo (propio y CC0 moldeado) y accesorios | XL | Fable |
| 6 | **9 — Cara y ojos** (ya en la hoja de ruta) | Ojos, cejas y expresiones | XL | Fable |
| 7 | Resto de la hoja de ruta (11.3+, 12, 13, 14, 10.3+, 15, 16, 17) | Física, estudio, estilos, Android, especies, VRM | — | — |
| 8 | **X — Pendientes sueltos** | Lo de `IDEAS.md` que no tenía sitio | — | — |
| — | **R — Rescatado de proyectos parecidos** (§8) | Expresiones CC0, mallas ligeras, ocultar por capas, sprites… | — | Cada paso va con la fase que dice su fila |
| 9 | **8 — Windows** (ya en la hoja de ruta) | El programa también en Windows | M | barato |

**Por qué este orden (en frases sencillas):**

- La interfaz va **antes** que las pestañas nuevas: si se hace después, cada pestaña (Pelo, Ropa…) habría que rehacerla con el estilo nuevo.
- Las plantillas son **baratas** (la malla ya pasa de femenina a masculina con el deslizador Complexión) y son lo primero que ve quien abre el programa.
- El formato de proyecto va **antes** que los assets: una pieza puesta en el personaje tiene que guardarse en algún sitio.
- Dentro de los assets, primero lo que **sigue al cuerpo casi gratis** (los *helpers* de MakeHuman, §5.1), después lo difícil.
- **Windows va al final** (decidido por el responsable el 2026-11-18). Mientras tanto, cada versión se publica para Linux. Es un trabajo mecánico: se puede adelantar en cualquier momento si hace falta.

---

## 1. Cobertura de `IDEAS.md`: qué falta y dónde queda

Estado: **Hecho** · **Plan** (ya está en `PLAN.md` o en la hoja de ruta) · **Nuevo** (paso nuevo de este documento).

| Idea de `IDEAS.md` | Estado | Dónde |
| --- | --- | --- |
| Presets de cuerpo: atlético, delgado, robusto, mayor | Nuevo | PL.1 (mayor: PL.8) |
| `probar_rendimiento.gd` con rutas relativas | Nuevo | 0.3 |
| Botón «aleatorio» con límites | Nuevo | PL.5 |
| Comparar antes y después | Nuevo | PL.7 |
| Medidas reales (cm) | Nuevo | IU.8 |
| Atajos de teclado | Plan | P.4 (+ IU.10: lista con F1) |
| Pies al suelo al animar (IK de pies) | Nuevo | X.1 |
| Recortar `UAL1_Standard.glb` | Plan | P.6 |
| Más deslizadores de MakeHuman | Plan + Nuevo | 9.2 (cara); X.2 (cuerpo: pies, dedos, orejas…) |
| Deslizador Edad | Descartado (2026-11-21) | PL.8: Altura desde ×0,65 |
| Edades de 5 a 60 años, como Anny | Con los deslizadores (2026-11-21) | PL.8 (D42) |
| Pestaña Cara y ojos | Plan | Fase 9 |
| Pestaña Pelo | Plan + Nuevo | AB.9a–AB.9d (casquete, peinados CC0 moldeados, peinados propios, pelo de MakeHuman) + Fase 11 (física) |
| Pestaña Ropa | Plan + Nuevo | AB.4–AB.8, AB.10 + Fase 12 |
| Pestaña Accesorios | Plan + Nuevo | AB.11 + Fase 13 |
| Materiales: texturas de piel | Plan | 14.4 |
| Materiales: estilo pixel art | Nuevo | X.6 |
| Exportar VRM | Plan | Fase 17 |
| Niveles de detalle / selector de polígonos | Nuevo | X.5 |
| Hombro con el brazo sobre la cabeza (forma correctora) | Nuevo | X.4 |
| `alisado` con género y firmeza (sin medir) | Nuevo | **PL.0** (antes de las plantillas) |
| Cara: deslizadores por rasgo, separación de ojos, otro sistema de ojos, bolsas de la boca | Plan | 9.2, 9.4, 9.6 |
| Cabezas CC0 de OpenGameArt y pack CC-BY-SA opcional | Plan | 16.3 y D19 |
| Contorno regulable de 0 a muy grueso | Hecho | panel Acabado (0–10 px) |
| Contorno: color y grosor por zona; grumos en los dedos | Plan | 14.2 |
| Borde de la prenda ondulado en primeros planos | Nuevo | 0.4 |
| Estilo como archivo de datos | Plan | 14.1 |
| Grado de realismo (anime → semirrealista) | Nuevo | X.6 |
| Luz de vista previa en el editor | Nuevo | IU.3 |
| Tinte de sombra | Plan | SH.2 (D48) |
| Umbral del tono medio en la cara | Nuevo | X.7 |
| Aplanar más las normales de la cara (sin escalón) | Nuevo | X.7 |
| Estilos de ojos como packs | Plan | 9.5 |
| Pantalla inicial con botones de estilo | Plan + Nuevo | PL.4 (cuerpos) + 14.7 (estilos) |
| Más clips y cargar animaciones propias | Nuevo | X.3 |
| Suelo o rejilla en la vista | Nuevo | IU.3 |
| Estética de la ventana | Nuevo | **Fase IU** |
| Comando en el PATH | Nuevo | 0.5 |
| Quaternius UBC: peinados, cejas y barba | Plan + Nuevo | AB.9b (moldeados a nuestra cabeza) y 11.5 |
| Quaternius UBC: segunda base estilizada | Plan | 16.3 |
| Sistema de piezas (packs) | Plan | 11.1 = AB.2 |
| Conversor de assets CC0 de MakeHuman | Plan + Nuevo | AB.3 (helpers) + 12.1–12.2 (`.mhclo`) |
| Adaptador en Blender para piezas de otras webs | Plan | 13.3 |
| Catálogo en línea de packs | Nuevo | X.12 |
| Especies | Plan | Fase 16 |
| Plugin para Godot (pestaña del editor) | Nuevo | X.10 |
| NPC en el juego (multitudes) | Nuevo | X.11 |
| Versión web con Three.js | Descartada | `HOJA_DE_RUTA.md` §4 (si hace falta web: exportación web de Godot) |
| Android | Plan | Fase 15 |
| Rig automático con IA | Sin cambios | Condición: GPU de más de 8 GB |
| Comunidad: guía de piezas y traducciones | Nuevo | X.12, X.13 |
| Simetría relativa | Nuevo | X.14 |
| 8 influencias al exportar | Nuevo | X.15 |
| Cuelgue de `GLTFDocument` | Nuevo | X.16 |
| Juego oscuro: espadas, escudos, linternas | Plan + Nuevo | AB.11 + Fase 13 |
| Juego oscuro: base chibi | Plan | 16.2–16.3 (PL.9: sin chibi; la cabeza llega a ×2,5) |
| Juego oscuro: daño por zonas | Nuevo | X.9 |

---

## 2. Bloque 0 — Cerrar la 0.1.0 (antes de expandir)

- **0.1 Juicios pendientes** (los hace el responsable): `ruta/PENDIENTES.md` (capturas del 5.15/5.11, 6.3, 7.0, 7.1, 7.2, P.2, P.3). Sin esto, los pasos `[~]` no se cierran.
- **0.2 Pulido P.4–P.7** tal como están en `PLAN.md`. P.5 cambia «Rim»: usar ya los nombres de `GUIA_INTERFAZ.md` §6 para no cambiarlos dos veces.
- **0.3 `probar_rendimiento.gd` con rutas relativas** (de `IDEAS.md`). Simple. Prueba: lanzarla con `godot/datos/humana/cuerpo.glb` (relativa) y con la absoluta: mismo resultado.
- **0.4 Borde de la prenda ondulado en primeros planos.** Medio. Medir primero: captura a 0,5 m del pecho con y sin el degradado de 6 cm; proponer arreglo (corte en el shader con `fwidth` para un borde estable, o más resolución de la textura horneada). Juicio visual.
- **0.5 Comando en el PATH:** `scripts/instalar_lanzador.sh` que copia el build a `~/.local/share/gamemolde/`, crea `~/.local/bin/gamemolde` y un `.desktop` con icono (P.7). Simple. Sin `sudo`.
- **0.6 Publicar** (lo hace el responsable): commits, etiqueta `v0.1.0`, `gh release` según `ruta/PENDIENTES.md`, copia de seguridad.

**Hecho cuando:** la 0.1.0 está publicada como versión preliminar y `PLAN.md` no tiene pasos `[~]`.

---

## 3. Fase IU — Interfaz nueva (estilo VRoid, propio)

**Objetivo:** que la ventana se vea como `diseno/maqueta-v2.html` y se comporte como dice `diseno/GUIA_INTERFAZ.md`.
**Hecho cuando:** una persona que no conoce el programa crea un personaje, cambia de plantilla, ajusta tres zonas y exporta sin preguntar nada; y `probar_tema.gd` + todas las pruebas de la ventana pasan.
**Regla de la fase:** cada paso cambia la ventana sin cambiar el núcleo (`addons/creador/` no se toca en toda la fase, salvo que la ficha lo diga).

### IU.1 Tokens y tema global
- **Objetivo:** el programa entero usa el tema nuevo (claro), sin mover ningún panel.
- **Archivos:** crear `godot/app/tema/tokens.gd`, `godot/app/tema/theme_builder.gd`, `pruebas/godot/probar_tema.gd`; tocar `main.gd` (poner el `Theme` en la raíz), `slider_panel.gd` (quitar `TYPE_COLORS`), `report_section.gd`/`report_panel.gd` (colores del informe desde tokens).
- **Diseño:** `GUIA_INTERFAZ.md` §3 y §5.2. Variaciones: `BotonPrincipal`, `BotonFantasma`, `Chip`, `Tarjeta`, `TituloZona`, `InsigniaForma`, `InsigniaProporcion`, `InsigniaCrear`, `Pista`.
- **Prueba:** `probar_tema.gd` (§8 de la guía). Que detecta el fallo: bajar el contraste de `texto_3`.
- **Juicio visual:** capturas de la ventana antes y después.
- **Nivel:** medio · **Tam.:** M · **Depende de:** D30, D34.

### IU.2 Iconos
- **Objetivo:** un juego de iconos coherente (24 px, trazo 2 px): pestañas, Deshacer, Rehacer, Abrir, Guardar, Exportar, vistas, simetría, prenda, rejilla, luz, restablecer, buscar, informe (bien, aviso, error), «Pronto».
- **Archivos:** `godot/app/tema/iconos/*.svg`, `CREDITOS.md` si son de terceros.
- **Diseño:** D33. Si son propios: SVG escritos a mano, formas simples, sin parecido con iconos de ningún programa.
- **Prueba:** cada icono que nombra el código existe y se carga (lista en `probar_tema.gd`).
- **Nivel:** simple (propios: medio) · **Tam.:** S.

### IU.3 Vista 3D bonita
- **Objetivo:** fondo degradado, sombra de suelo, rejilla opcional y luz de vista previa (ángulo e intensidad; no se exporta).
- **Archivos:** `body_view.gd`; crear `godot/app/floor_shadow.gd` (+ su shader pequeño en `godot/app/tema/`), `pruebas/godot/probar_vista_bonita.gd`.
- **Diseño:** `GUIA_INTERFAZ.md` §5.3. Primero, **comprobar** que `transparent_bg` no cambia el contorno (captura A/B de la misma pose); si cambia, plan B de la guía.
- **Prueba (sin ventana):** la sombra sigue al personaje en X/Z y se queda en y = 0 al animar; la luz de vista previa no cambia el `.tres` exportado (comparar el archivo con y sin girarla).
- **Juicio visual:** sí (claro y oscuro).
- **Nivel:** medio · **Tam.:** M · **Modelo:** Fable (toca cómo se ve el personaje).

### IU.4 Barra superior y pestañas principales
- **Objetivo:** la barra de §2 de la guía: marca, nombre del archivo con `•`, pestañas con icono y «Pronto», Deshacer/Rehacer, Abrir, Guardar y **Exportar** (principal). La barra inferior de `body_actions.gd` se vacía: sus botones suben aquí.
- **Archivos:** crear `godot/app/top_bar.gd`; tocar `main.gd`, `body_actions.gd`; adaptar `probar_ventana.gd` y `probar_acciones.gd`.
- **Diseño:** las funciones no cambian (mismas señales y llamadas a `BodyView`/`BodyEditor`). «Exportar» abre el diálogo de siempre (las opciones llegan con D35). La pestaña nueva **Estilo** existe vacía (la llena IU.6).
- **Prueba:** las de siempre, adaptadas: cada botón llama a lo mismo que antes; el `•` aparece al cambiar un valor y desaparece al guardar.
- **Nivel:** simple · **Tam.:** M.

### IU.5 Panel izquierdo: silueta de zonas
- **Objetivo:** elegir zona en una silueta (SVG propio) o en la lista; pestaña «Plantillas» vacía para la fase PL.
- **Archivos:** crear `godot/app/zone_picker.gd`, `godot/app/tema/silueta.svg` (o la silueta dibujada con `Polygon2D`/`draw_*`); tocar `main.gd`, `slider_panel.gd` (las cabeceras plegables dejan de hacer falta: el panel derecho enseña una zona).
- **Diseño:** las zonas de la silueta salen de una tabla `zona → formas` en el propio archivo; la lista sale de `deslizadores.csv` (vale para otra especie). Elegir zona = `slider_panel.open(zona)` (ya existe).
- **Prueba:** clic sintético en cada forma de la silueta abre su zona; la lista tiene las 14 zonas visibles en el orden de la tabla.
- **Nivel:** simple–medio · **Tam.:** M.

### IU.6 Panel derecho: filas de deslizador nuevas y pestaña Estilo
- **Objetivo:** la «Fila de deslizador» de la guía §4: valor 0–100 editable, ↺ por deslizador, relleno desde el neutro, marca del neutro, ayuda, extremos con nombre, una fila para los dos lados con Simetría, buscador. El panel Acabado pasa a la pestaña **Estilo**, con los nombres nuevos.
- **Archivos:** crear `godot/app/slider_row.gd`, `godot/app/textos/ayuda_deslizadores.csv`; tocar `slider_panel.gd`, `finish_panel.gd`, `main.gd`; adaptar `probar_panel.gd`, `probar_acabado.gd`, `probar_edicion.gd`.
- **Diseño:** el relleno desde el neutro es un `StyleBoxFlat` dibujado encima de la barra (o `_draw`), no un cambio del `HSlider`. Restablecer un deslizador = un cambio para Deshacer (como Restablecer zona). El buscador filtra por nombre y por ayuda, en todas las zonas.
- **Prueba:** escribir «73» deja 0,73; ↺ vuelve al neutro y se deshace con Ctrl+Z; con Simetría, una fila de dos lados mueve `_l` y `_r`; sin Simetría hay dos filas; buscar «ancho» encuentra los 6 ajustes de ancho (Cabeza, Hombros, Torso, Espalda ancha, Cintura y Caderas).
- **Nivel:** medio · **Tam.:** M.

### IU.7 Elegir zona tocando el cuerpo
- **Objetivo:** clic en el personaje → se abre la zona tocada; al pasar el ratón, la zona se ilumina.
- **Archivos:** crear `godot/app/zone_ray.gd` y `pruebas/godot/probar_zona_rayo.gd`; tocar `body_view.gd`.
- **Diseño:** el algoritmo de `ARQUITECTURA.md` §4 (rayo → triángulo → vértice → hueso de mayor peso) + una tabla `hueso → zona` (por ejemplo `LeftUpperArm → Brazos`, `Head → Cabeza`). Rayo sobre la malla con las formas de ahora (como `CharacterBox`), en un hilo si tarda más de 16 ms (medir). Iluminar: un parámetro del shader con la lista de huesos de la zona (no cambia el aspecto por defecto).
- **Prueba (sin ventana):** rayos sintéticos a la frente → Cabeza; a la palma → Manos; al muslo → Piernas; un rayo que no toca → no cambia la zona.
- **Nivel:** fuerte (shader + rayo) · **Tam.:** M · **Modelo:** Fable.

### IU.8 Barra de estado y medidas en vivo
- **Objetivo:** pastilla del informe (abre el desplegable del P.2), altura en metros, cabezas de alto, triángulos y huesos.
- **Archivos:** crear `godot/app/status_bar.gd`, `godot/app/measures.gd`; tocar `main.gd`.
- **Diseño:** altura = caja de `CharacterBox` en pose A; alto de la cabeza = de la barbilla a la coronilla (definir los vértices de referencia en la ficha, como hizo el 3.12). Se recalcula con el temporizador del encuadre (P.3), no en cada fotograma.
- **Prueba:** el cuerpo neutro da la altura y las cabezas medidas en el 3.12 (± 1 mm, ± 0,05 cabezas); Global › Altura a 1 cambia la altura en la proporción de `escala:Root`.
- **Nivel:** simple–medio · **Tam.:** S.

### IU.9 Ajustes: tema, tamaño y animaciones
- **Objetivo:** claro/oscuro, tamaño de la interfaz (90–150 %) y «Reducir animaciones», guardados en `user://ajustes.cfg`.
- **Archivos:** crear `godot/app/settings.gd` (+ diálogo); tocar `main.gd`.
- **Prueba:** guardar y leer los tres ajustes; un archivo de ajustes roto no impide arrancar (vuelve a los valores por defecto).
- **Nivel:** simple · **Tam.:** S.

### IU.10 Microinteracciones y primer arranque
- **Objetivo:** transiciones de 120–180 ms, ayudas de 400 ms, pista inicial sobre la vista (se oculta al primer giro), lista de atajos con F1, confirmación de cambios sin guardar (de P.4) con el diálogo nuevo.
- **Archivos:** `main.gd`, `top_bar.gd`, `body_view.gd`, `settings.gd`.
- **Prueba:** con «Reducir animaciones», ninguna transición dura más de 0 ms; la pista no vuelve tras el primer giro (se guarda en ajustes).
- **Nivel:** simple · **Tam.:** S.

### IU.11 Cierre de la fase
- Hoja de capturas (claro, oscuro, 1280 × 720, 1920 × 1080, 150 %), revisor-visual y prueba con una persona ajena (la del «Hecho cuando»). Lo que no se entienda vuelve como paso nuevo.

---

## 4. Fase PL — Plantillas y cuerpos (femenino, masculino y más)

**Lo importante:** no hacen falta dos mallas. La macro `gender` de MakeHuman (deslizador **Complexión**) ya lleva la misma malla de femenina (0) a masculina (1), con sus 81 correcciones. Lo que falta es **ofrecerlo bien**: plantillas listas, con miniatura, y una pantalla de inicio.

**Hecho cuando:** al abrir el programa se elige «Femenina» o «Masculino» (o cualquier otra plantilla) con un clic, el personaje cumple las proporciones de `GUIA_ESTILO.md` §2 y se exporta sin avisos del informe.

### PL.0 Medir el alisado con complexión y firmeza (pendiente de `IDEAS.md`)
- **Objetivo:** comprobar que `alisado` sigue cumpliendo «sin detalle anatómico» con `gender` a 0 y a 1 y `breast_firmness` a 0 y a 1 (el 6.2 solo midió músculo, grasa y pecho).
- **Archivos:** ampliar `pruebas/godot/probar_formas_propias_banco.gd` (o una prueba nueva) con esas 4 esquinas.
- **Prueba:** las medidas del 6.2 en las 4 esquinas; capturas con sombreado normal y toon.
- **Juicio visual:** sí. Si falla, la corrección es una forma propia nueva (Blender, nivel fuerte) **antes** de PL.1.
- **Nivel:** medio · **Tam.:** S · **Modelo:** Fable.

### PL.1 Plantillas de serie
- **Objetivo:** presets completos en versión 2 (con cara anime y `alisado` a 1): **Neutro** (el `anime.json` de hoy), **Femenina**, **Masculino**, **Atlética**, **Atlético**, **Delgada**, **Delgado**, **Robusta**, **Robusto**, **Esbelta** y **Esbelto** (proporciones heroicas). «Mayor» espera a PL.8.
- **Archivos:** `godot/datos/humana/presets/*.json`; `blender/exportar_datos.py` (lista `FILES`, como en el 3.15); manifiesto regenerado; `FORMATO.md` (apartado `presets/`: el campo `nombre` y un campo nuevo opcional `orden`); `probar_presets.gd`.
- **Diseño:** partir de `pruebas/fase_3/estilo/anime_femenino.json` y `anime_masculino.json` (versión 1, sin cara). El masculino midió 6,94 cabezas y la guía pide 7–7,5: ajustar con `leg_length`/`torso_length` y medir. Cada plantilla con su color de piel por defecto **gris neutro** (el color lo elige quien usa el editor; aprobado el 2026-11-12). `cuerpo.glb` debe salir con el **mismo sha256** (solo cambia la lista de archivos).
- **Prueba:** cada plantilla carga sin claves desconocidas; sus cabezas de alto, piernas, hombros y cintura caen en los rangos de `GUIA_ESTILO.md` §2 (los rangos son PROPUESTA: si una no entra, se informa con la medida, no se toca el rango); el informe de `CharacterChecks` sale sin errores en pose T y en «Atacar».
- **Juicio visual:** hoja con todas, de frente y ¾.
- **Nivel:** medio (toca `datos/` y Blender solo para el manifiesto) · **Tam.:** M · **Depende de:** PL.0.

### PL.2 Miniaturas hechas por el editor
- **Objetivo:** cada plantilla (y luego cada pieza) tiene una imagen de 256 px renderizada **por el propio editor** (nunca capturas de otros programas).
- **Archivos:** crear `godot/app/thumbnailer.gd`; las de serie, generadas con un script (`pruebas/godot/generar_miniaturas.gd`, con ventana) y guardadas junto a cada preset (`<id>.png`, en el manifiesto); las del usuario, en `user://miniaturas/<sha256 del preset>.png`.
- **Diseño:** `SubViewport` de 256 × 256 con `render_target_update_mode = UPDATE_ONCE`, cámara ¾ fija, el fondo degradado de IU.3; leer con `get_texture().get_image()` tras `RenderingServer.frame_post_draw`. Sin ventana no hay render: la prueba sin ventana solo comprueba que la de serie existe y mide 256 × 256.
- **Nivel:** medio · **Tam.:** S–M.

### PL.3 Galería de plantillas
- **Objetivo:** la pestaña «Plantillas» del panel izquierdo enseña las miniaturas; un clic aplica la plantilla (un solo cambio para Deshacer, con `BodyEditor.load_values` del 7.0). Si hay cambios sin guardar, se avisa antes.
- **Archivos:** crear `godot/app/template_gallery.gd`; tocar `main.gd`; prueba nueva `probar_plantillas.gd`.
- **Prueba:** aplicar Masculino deja `gender = 1` y los valores del archivo; Ctrl+Z vuelve al estado anterior; las miniaturas siguen el campo `orden`.
- **Nivel:** simple · **Tam.:** S.

### PL.4 Pantalla «Nuevo personaje»
- **Objetivo:** al arrancar (y con Archivo › Nuevo): tarjetas grandes **Femenina · Masculino · Neutro**, una fila «Más cuerpos» con el resto, y «Abrir…» / «Recientes». Prepara el sitio para los botones de estilo del 14.7 (Realista, Semi, Anime, Caricatura, Personalizado), que se añaden cuando existan.
- **Archivos:** crear `godot/app/start_screen.gd`; tocar `main.gd`; ajuste «Mostrar al arrancar» en `settings.gd`.
- **Prueba:** elegir una tarjeta carga esa plantilla y cierra la pantalla; «Recientes» guarda los 8 últimos archivos y quita los que ya no existen.
- **Nivel:** simple · **Tam.:** S.

### PL.5 Aleatorio con semilla y candados
- **Objetivo:** botón 🎲 en la barra superior: valores al azar dentro de límites razonables (0,2–0,8 por defecto; «Atrevido» usa 0–1), con candado por zona (las zonas con candado no cambian). La semilla se ve y se puede escribir para repetir un resultado.
- **Archivos:** crear `godot/app/randomizer.gd`; tocar `top_bar.gd`, `zone_picker.gd` (icono de candado).
- **Diseño:** `RandomNumberGenerator` con `seed`; la complexión respeta la plantilla actual salvo que se desbloquee Global; la edad (PL.8) nunca entra en el azar por debajo de su mínimo.
- **Prueba:** la misma semilla da los mismos valores; una zona con candado no cambia; 100 tiradas sin errores del informe en pose T (reutiliza `probar_aleatorios.gd`).
- **Nivel:** simple · **Tam.:** S.

### PL.6 Mezclar dos plantillas
- **Objetivo:** elegir dos plantillas y un porcentaje (por ejemplo, 70 % Atlética + 30 % Robusta).
- **Archivos:** crear `godot/app/template_mixer.gd` (diálogo pequeño).
- **Diseño:** interpolación lineal de los valores; colores y acabado de la primera.
- **Prueba:** 0 % = la primera, 100 % = la segunda, 50 % = la media exacta.
- **Nivel:** simple · **Tam.:** S.

### PL.7 Comparar antes y después
- **Objetivo:** mantener pulsado un botón (o la tecla C) enseña el personaje tal como estaba al abrir o al guardar, como silueta fantasma superpuesta.
- **Archivos:** `body_view.gd`; crear `godot/app/ghost_view.gd`.
- **Diseño:** una segunda instancia de la malla con los valores guardados y un material semitransparente sin contorno; se crea al pulsar y se libera al soltar (memoria).
- **Prueba:** al soltar no queda ningún nodo extra; la memoria vuelve a su valor (± 5 %).
- **Nivel:** medio · **Tam.:** S–M.

### PL.8 Deslizador Edad (primera parte: de joven a mayor)
> **Descartado por el responsable el 2026-11-21:** sin deslizador Edad (exacto pedía ~150 formas más). En su lugar,
> Global › Altura baja hasta ×0,65 y cada uno ajusta la figura (`ruta/pasos/PL.8_figura_pequena.md`).

- **Objetivo:** fila nueva `age` (Global › Edad) de joven (25 años) a 60 años (D42: nada por encima de 60), con sus correcciones, y las plantillas **Mayor** y **Mayora** (60 años).
- **Archivos:** `blender/exportar_datos.py`, `godot/datos/humana/*` (sube la `version` del manifiesto), `deslizadores.csv`, pruebas de la fase 2 y `probar_rendimiento.gd`.
- **Diseño:** el deslizador va de la macro `age` 0,5 (`young`, 25 años) a la que da 60 años (con sus correcciones), como hace Anny (`propuestas/proyectos_parecidos.md` §1.2). **Comprobar** en MPFB la equivalencia en años. La edad queda **fuera** de «Exageración» (16.2) y del aleatorio. **Después (X.17):** el rango se amplía hasta los 5 años. Medir la memoria que añade (`RENDIMIENTO.md` O6).
- **Prueba:** el deslizador a 0 da exactamente la variación `young`; las pruebas de reajuste de huesos (fase 2) siguen < 1 mm.
- **Juicio visual:** sí.
- **Nivel:** fuerte · **Tam.:** M · **Modelo:** Fable · **Depende de:** D42 (decidida).

### PL.9 (opcional) Chibi con la misma malla
> **Cambiado por el responsable el 2026-11-21:** las recetas de chibi del PL.9a «están raras». Sin chibi: Cabeza › Tamaño
> llega a ×2,5 y cada uno ajusta el resto (`ruta/pasos/PL.9_chibi.md`).

- **Objetivo:** intentar el chibi (2,5–3 cabezas) sin base nueva: rangos ampliados de Proporción + formas propias de cuello y cabeza. El 3.12 llegó a 3,46 cabezas fuera de rango.
- **Diseño:** es el 16.2 adelantado solo para Proporción. Si no llega a 3 cabezas con buen aspecto, se para y se va a 16.3 (segunda base).
- **Nivel:** fuerte · **Tam.:** M · **Modelo:** Fable.

---

## 5. Fase AB — Assets base: el «Pack Base 1» (la gran expansión)

### 5.1 De dónde salen los assets (licencias limpias)

| Origen | Qué da | Licencia | Encaje con nuestro cuerpo | Coste |
| --- | --- | --- | --- | --- |
| **Helpers de MakeHuman** (`helper-tights`, `helper-skirt`, `helper-hair`) | Mallas pensadas para ropa ceñida, faldas y pelo, que **ya se deforman con todas las formas** de MakeHuman | CC0 (parte de la malla base) | **Perfecto**: se quitaron en el paso 1.3, pero son de la misma malla | **Bajo** |
| **Derivadas del cuerpo** (caras del cuerpo desplazadas por la normal) | Guantes, calcetines, botas ceñidas | CC0 (derivado de la malla CC0) | Perfecto: mismos vértices, mismas formas y pesos | Bajo |
| **Generadores propios** (código MIT en Godot) | Cuernos, halos, gafas, diademas, orejas de animal, espadas y escudos sencillos | Propia → CC0 | Rígidas en un hueso o anclaje | Medio el primero, bajo los siguientes |
| **Formas propias por script** (Blender, como `cara_anime.py`) | Orejas puntiagudas, más formas de cuerpo | CC0 | Perfecto (son formas del cuerpo) | Medio |
| **Ropa de «MakeHuman system assets»** (`.mhclo`) | Camisetas, pantalones, zapatos realistas | CC0 | Bueno, con el lector y la transferencia del 12.1 | Alto |
| **KayKit «Character Pack: Adventurers»** | 25+ armas y accesorios (espadas, escudos, hachas, bastones…) | CC0 (comprobar en su página y en el `LICENSE` del zip antes de descargar) | Rígidas en los anclajes: no hace falta ajustarlas | Bajo |
| **Quaternius «Modular Character Outfits – Fantasy»** (noviembre de 2025) | 12 trajes de fantasía en 62 piezas | CC0 (comprobar) | Hechas para **su** cuerpo: hace falta la transferencia del 12.1 y revisión a mano | Alto |
| **Quaternius «Universal Base Characters»** | Hasta 20 peinados, cejas, barba; base de referencia | CC0 (comprobar) | Peinados: se moldean a nuestra cabeza (AB.9b). | Medio |
| **Peinados libres sueltos** | Ver §5.3 | CC0 | Se moldean (AB.9b) | Medio |

**La pieza clave:** la malla base de MakeHuman trae, además del cuerpo, geometría de ayuda numerada después de él: `helper-tights` para la ropa pegada al cuerpo, `helper-skirt` para las faldas y `helper-hair` para el pelo. Los *targets* de MakeHuman mueven también esos vértices (por eso la ropa de MakeHuman sigue al cuerpo). Si nuestro pipeline los exporta como piezas aparte, con sus formas y pesos, tenemos ropa ceñida, falda y casquete de pelo que **siguen a todos los deslizadores desde el primer día**, sin la herramienta difícil del 12.1.

Lo que hay que comprobar en AB.3: (1) que los *targets* que usamos traen deltas para esos vértices; (2) si el rig *Game engine* les da pesos (si no, se copian del vértice del cuerpo más cercano); (3) qué cubre exactamente `helper-tights` (se espera torso, brazos y piernas); (4) nuestras **formas propias** (`alisado`, cara anime, glúteos, hombros) se hicieron solo sobre el cuerpo: a los helpers hay que pasárselas (vértice del cuerpo más cercano o el algoritmo de `ruta/codigo/nucleo/shape_transfer.gd`).

**Licencia de lo que hagamos:** todo lo hecho por nosotros o derivado de la malla CC0 sale como **CC0** (D36). La salida de un script GPL de `blender/` no hereda la GPL (los datos son nuestros, no el código del script). Las piezas **rígidas** se pueden publicar además como pack CC0 suelto (OpenGameArt, itch.io); las que siguen al cuerpo solo tienen sentido dentro de GameMolde (dependen de la malla de MakeHuman).

### 5.2 Contenido propuesto del Pack Base 1

| Ranura | Piezas | Origen |
| --- | --- | --- |
| `ropa_torso` | Camiseta (manga corta y larga), top, camiseta de tirantes, jersey ceñido | `helper-tights` recortado (AB.5) |
| `ropa_piernas` | Mallas, pantalón corto, pantalón largo ceñido, falda corta y larga | `helper-tights` (AB.5) y `helper-skirt` (AB.8) |
| `ropa_interior` | Traje de baño de una pieza (sustituto en 3D de la prenda base pintada) | `helper-tights` (AB.5) |
| `ropa_pies` | Calcetines, botas altas, zapatillas | Derivadas del cuerpo (AB.10) |
| `ropa_exterior` | Guantes, guantes sin dedos | Derivadas del cuerpo (AB.10) |
| `pelo` | Casquete rapado + 6 peinados propios (corto, bob, coleta alta, dos coletas, melena larga, flequillo recto) + los peinados CC0 de §5.3 moldeados a nuestra cabeza | `helper-hair` + mechones (AB.9a, AB.9c) y CC0 moldeados (AB.9b, AB.9d) |
| `accesorio` | Cuernos (generador), halo, gafas redondas, diadema, corona, orejas de gato y de zorro | Generadores (AB.11) |
| `accesorio` (anclajes) | Espada, escudo, linterna, bastón | KayKit CC0 o generadores (AB.11) |
| Formas del cuerpo | Orejas puntiagudas (elfo), orejas grandes | Formas propias (AB.12) |

Colores por pieza (principal y secundario), sombreadas con el mismo toon y contorno. Sin texturas en esta fase; los estampados (rayas, cuadros) llegan como parámetros del shader en AB.13.

### 5.3 Peinados libres para usar o moldear

Búsqueda del mentor (2026-11-18). Todos dicen CC0 en su página. **Antes de descargar nada:** el responsable da permiso de red, el agente comprueba la licencia en la página del autor y en el archivo descargado, y apunta autor, enlace y fecha en `CREDITOS.md`. Si algo no cuadra, no se usa (señal de alarma 3 del §9).

| Fuente | Qué trae | Estilo | Encaje con nuestra cabeza | Prioridad |
| --- | --- | --- | --- | --- |
| **Quaternius — Universal Base Characters** (quaternius.com, itch.io) | Hasta 20 peinados para combinar (comprobar cuántos trae la versión gratis; la copia de `referencias/` tiene 8), cejas y barba | Estilizado, malla sólida | Hechos para su cabeza: moldear (AB.9b) | **1** (el más cercano al toon) |
| **MakeHuman — pelo de «system assets» y pack «Hair 01»** (static.makehumancommunity.org) | Peinados realistas (bob, coletas, melenas, trenzas…) | Realista, tarjetas con transparencia | **Muy bueno**: están hechos para **nuestra misma malla base** (se anclan con `.mhclo` al `helper-hair`) | **2** (encajan solos; falta pasarlos al toon, AB.9d) |
| **MakeHuman — pack «Hair editor»** | Estilos de pelo para el editor de pelo de MPFB (curvas) | Curvas de Blender | Misma malla base | 3 (para estudiar o convertir curvas en mechones) |
| **Micket — OpenGameArt** | Coleta (mujer), punk corto (mujer), melena larga, peinado hacia arriba y raya al lado (hombre) | Low poly (253–374 triángulos) | Hechos para otra cabeza: moldear | **2** (ideales para practicar el moldeado: pocos vértices) |
| **tiko479 — OpenGameArt** | Coleta de rastas toon y rastas cortas | Toon / low poly | Moldear | 3 |
| **The Wild Dodo — itch.io** («Low Poly Male And Female Models») | Coleta, dos cortos, pelo con gorra | Low poly | Moldear | 3 |
| **Quaternius — Background Posed Humans** | Personajes posados con pelo | Low poly | Hay que separar el pelo del cuerpo y moldear | 4 |
| **PINKCANNON — «Tiby» (OpenGameArt)** | Pelo de malla de un personaje chibi (se puede separar) | Toon | Moldear; solo el pelo, no el personaje | 4 |

**Encontrados pero descartados:**

| Fuente | Por qué no |
| --- | --- |
| «VRoid Studio CC0 models» (OpenGameArt) | La regla del proyecto excluye todo lo de VRoid; además, según la propia página, la licencia que llevan dentro los archivos no es la misma en todos (unos dicen CC0, otros enlazan a la licencia de pixiv), y varios están etiquetados como adolescentes |
| «Basemesh Pack – Free Edition» (Superhive) | Solo uso personal y no comercial |
| Packs de pago de CGTrader, Fab, ArtStation o Unity | Licencia «royalty free» de tienda: no se pueden redistribuir dentro de un programa libre |
| «Low Poly Character Customization» (edusilvart, itch.io) | CC-BY 4.0: solo si se aprueba D19 |

**Qué es «moldear» un peinado** (lo hace AB.9b, y vale para cualquier fuente de la tabla):

1. Importarlo en Blender junto a nuestra cabeza (cuerpo neutro con la cara anime).
2. Colocarlo con puntos de referencia (coronilla, orejas, nuca) y una escala propuesta por script; el responsable la confirma.
3. Ajustarlo al casquete (`helper-hair`) con un desplazamiento mínimo, para que no atraviese el cráneo; retoque a mano si hace falta.
4. Pesos a `Head` y, en los mechones largos, cadenas de huesos `x_pelo_*` para la física del 11.3.
5. Pasarle las formas del casquete o de la cabeza (`ruta/codigo/nucleo/shape_transfer.gd`) para que siga a Cabeza › Ancho y Alto.
6. Material toon con color y banda de brillo; se quitan las texturas realistas (en el pelo de tarjetas se mantiene solo el recorte de transparencia).
7. Comprobar el presupuesto (≤ 6.000 triángulos y ≤ 12 huesos, PROVISIONAL) y escribir su ficha en `pack.json`: autor, licencia, enlace de origen y «moldeado por GameMolde».

Un peinado CC0 moldeado sigue siendo CC0 y puede entrar en el Pack Base 1 (D36); se cita al autor original como cortesía.

### 5.4 Pasos

**AB.1 = 10.1 + 10.2 (formato `.gmolde` y galería local).** Se hacen con sus fichas de la hoja de ruta; el borrador `ruta/codigo/` ya trae `probar_proyecto.gd`. El bloque `piezas` del proyecto guarda `pack`, `pieza`, `sha256`, colores y parámetros (largo de manga, etc.).

**AB.2 = 11.1 (sistema de piezas mínimo: `PackLibrary`).** Con el diseño de `ARQUITECTURA.md` §6 y sus licencias permitidas (`CC0-1.0`, `propia`). Nivel fuerte para revisar, medio para escribir.

### AB.3 Exportar los helpers como piezas base
- **Objetivo:** `godot/packs/base/` con `tights.glb`, `skirt.glb` y `hair.glb` (mallas con **las mismas formas, con los mismos nombres** que el cuerpo, y pesos a 4 influencias), y `pack.json` con licencia `CC0-1.0`.
- **Archivos:** crear `blender/exportar_helpers.py` (GPL, como el resto de `blender/`) y `pruebas/fase_8/probar_helpers.py` (o la fase que toque); `CREDITOS.md` (origen: malla base de MakeHuman, CC0).
- **Diseño:** cargar el humano **con** helpers (MPFB), aplicar los mismos *targets* que `exportar_datos.py` como formas, separar cada helper por sus grupos de vértices, quitar las formas sin efecto (< 0,01 mm, como el 12.1), pasar las formas propias (§5.1 punto 4) y limpiar pesos a 4 influencias que suman 1. Todo en pose A, como `cuerpo.glb`.
- **Prueba:** para 6 cuerpos (los de la fase 1): la pieza generada en Godot con `ShapeWeights.apply` coincide con el helper que da MPFB con esos valores (< 1 mm, como la prueba 2.4); pesos ≤ 4 y suman 1; número de formas y memoria medidos e informados.
- **Nivel:** fuerte · **Tam.:** L · **Modelo:** Fable · **Depende de:** AB.2, D37.

### AB.4 Pieza que sigue al cuerpo, en vivo
- **Objetivo:** poner `tights.glb` sobre el personaje en el editor; sigue a todos los deslizadores, a la pose T y a las animaciones.
- **Archivos:** núcleo: crear `godot/addons/creador/body_piece.gd` (monta la pieza con el **mismo** `Skeleton3D` del cuerpo y le aplica los pesos de forma con `ShapeWeights.apply`); tocar `character_updater.gd` (aplicar también a las piezas); prueba `probar_pieza_cuerpo.gd`.
- **Diseño:** «sigue al cuerpo» = mismas formas + mismo esqueleto. Nada de copiar vértices cada fotograma: lo hace la GPU, como con el cuerpo.
- **Prueba (sin ventana):** con 10 cuerpos aleatorios y en «Atacar», contar vértices de piel **dentro de la zona cubierta** que salen por fuera de la pieza (distancia con signo por la normal). Medir y proponer el límite (regla 9); con AB.6 activo, el límite es 0 visibles.
- **Nivel:** fuerte · **Tam.:** M · **Modelo:** Fable · **Depende de:** AB.3.

### AB.5 Prendas recortadas y paramétricas
- **Objetivo:** de `tights` salen varias prendas con **parámetros**: largo de manga, largo de pernera, escote, largo del top. El usuario mueve «Largo de manga» y la manga crece o se acorta (como en los creadores de personajes de los juegos).
- **Archivos:** núcleo: crear `godot/addons/creador/garment_cut.gd`; datos: `godot/packs/base/prendas/*.json` (una prenda = helper + reglas de corte + parámetros por defecto); prueba `probar_prendas.gd`.
- **Diseño:** precalcular, una vez y en reposo, una **coordenada de corte** por vértice del helper: a lo largo del brazo (proyección sobre el segmento hombro → mano), de la pierna (cadera → pie) y del torso (cadera → cuello). Una prenda = quedarse con las caras cuyos vértices están dentro de los cortes. Primera versión: corte por caras enteras (borde que sigue las aristas; con la malla completa se nota poco). Segunda versión, solo si el juicio visual lo pide: partir las aristas en el corte (nivel fuerte). La malla recortada copia de esos vértices las formas y los pesos. Material con las dos caras visibles (`cull_disabled`) para que el borde de la manga no se vea hueco.
- **Prueba:** manga al 0 % = sin manga, al 100 % = hasta la muñeca; ninguna cara queda suelta (sin vecinos); el recorte se repite idéntico (mismo resultado dos veces); las formas copiadas dan la misma posición que el helper completo en esos vértices (0 mm).
- **Juicio visual:** sí, en cuerpos extremos y poses del 5.2.
- **Nivel:** fuerte · **Tam.:** L · **Modelo:** Fable.

### AB.6 Ocultar la piel bajo la ropa (12.3 adelantado)
- **Objetivo:** la piel tapada por una prenda no se dibuja: nunca atraviesa.
- **Diseño:** precalcular para cada vértice del cuerpo su cara más cercana del helper (una vez, en datos); la máscara de una prenda = vértices del cuerpo cuya cara de helper sigue en la prenda. El shader del cuerpo descarta esas caras (`discard`) con la máscara en una textura 1D o un canal libre del color por vértice (el verde lo quiere el 14.2: decidir en la ficha). Varias prendas: unión de máscaras.
- **Prueba:** el conteo de AB.4 da 0 vértices de piel visibles por fuera; sin prendas, la máscara está vacía y el cuerpo se ve igual que antes (captura idéntica).
- **Para prendas que no salen de los helpers** (importadas, de MakeHuman, de Quaternius) y para varias capas de ropa, el método general es R.8 (rayos por capas). La ficha decide si AB.6 usa uno, otro o los dos.
- **Nivel:** medio–fuerte · **Tam.:** M.

### AB.7 Exportar con piezas
- **Objetivo:** el `.glb` lleva cada pieza como malla aparte con el mismo esqueleto, horneada igual que el cuerpo (formas y pose T); el `.tres` lleva sus materiales. Opción: borrar al exportar las caras de piel ocultas (12.5).
- **Archivos:** `character_baker.gd`, `glb_exporter.gd`, `probar_glb.gd`, `probar_exportar.gd`.
- **Prueba:** el `.glb` con camiseta pasa `probar_glb.gd`; al reimportar, la camiseta sigue al cuerpo al animar en un proyecto vacío; con «borrar caras ocultas», los índices y los pesos siguen bien (mismas comprobaciones de 3.6.4).
- **Nivel:** fuerte · **Tam.:** M · **Modelo:** Fable.

### AB.8 Faldas desde `helper-skirt`
- **Objetivo:** falda corta y larga (largo como parámetro). La física llega con el 12.6.
- **Prueba:** la falda no atraviesa los muslos en «Caminar» (medir); al sentarse, informar de lo que pasa (sin física, la falda rígida se cruza: es esperable y se dice).
- **Nivel:** medio · **Tam.:** M.

### AB.9 Pelo (cuatro subpasos)

**Material común:** toon con color y una banda de brillo propia del anime (parámetro del shader; sin texturas). La banda se crea en SH.6b (`PLAN.md`); AB.9a y los demás peinados la usan.
**Prueba común:** con 10 cuerpos aleatorios, ningún vértice del cráneo por fuera del pelo; cada peinado ≤ 6.000 triángulos y ≤ 12 huesos (PROVISIONAL de la ficha 11); ficha con autor y licencia.

#### AB.9a Casquete
- **Objetivo:** `helper-hair` como casquete que sigue a la cabeza: rapado y base de todos los peinados.
- **Nivel:** medio · **Tam.:** S · **Depende de:** AB.3, AB.4.

#### AB.9b Moldeador de peinados importados (CC0)
- **Objetivo:** el proceso «moldear» de §5.3, como script reutilizable, y **los 3 primeros peinados moldeados**: dos de Quaternius UBC y uno de Micket (el más sencillo, para estrenar el proceso).
- **Archivos:** crear `blender/moldear_peinado.py` (GPL, como `blender/`; la salida es CC0) y su prueba; las piezas, en `godot/packs/base/`.
- **Diseño:** pasos 1 a 7 de §5.3. El script recibe el archivo del peinado y una ficha JSON con los puntos de referencia y la escala, para que repetirlo dé lo mismo.
- **Prueba:** la común; además, moldear dos veces el mismo peinado da el mismo `.glb` (mismo sha256).
- **Juicio visual:** sí, cada peinado de frente, perfil y espalda, con cabezas extremas.
- **Nivel:** fuerte · **Tam.:** M · **Modelo:** Fable · **Depende de:** AB.9a; permiso de red para descargar.

#### AB.9c Peinados propios por datos
- **Objetivo:** 6 peinados generados (corto, bob, coleta alta, dos coletas, melena larga, flequillo recto).
- **Diseño:** un mechón = cinta o tubo aplastado a lo largo de una curva (raíz sobre el casquete, grosor que se afila, giro). Un peinado = un JSON con sus curvas; un peinado nuevo = un archivo nuevo. Los mechones reciben las formas del casquete por el vértice más cercano. Mechones largos con cadena de huesos `x_pelo_*`.
- **Juicio visual:** mucho: es el paso más creativo del pack. Si los mechones generados no convencen, se para y se sigue con AB.9b (más peinados CC0 moldeados) o con peinados modelados a mano por el responsable.
- **Nivel:** fuerte · **Tam.:** L · **Modelo:** Fable.

#### AB.9d Pelo de MakeHuman al estilo toon
- **Objetivo:** los peinados CC0 de MakeHuman (system assets y Hair 01) puestos sobre nuestra cabeza con su `.mhclo` y pasados al toon.
- **Diseño:** el lector de `.mhclo` es el del 12.1–12.2 (propio, escrito desde la documentación del formato; nunca el código de MPFB ni de MakeHuman). Como están hechos para nuestra misma malla base, se anclan al `helper-hair` sin moldear. Pasarlos al toon: color plano, banda de brillo y solo el recorte de transparencia de su textura.
- **Juicio visual:** sí. Si las tarjetas realistas no casan con el toon, se usan solo como guía de volumen para AB.9c.
- **Nivel:** fuerte · **Tam.:** M · **Depende de:** 12.1 (lector `.mhclo`).

### AB.10 Calzado y guantes derivados del cuerpo
- **Objetivo:** calcetines, botas altas, zapatillas, guantes y guantes sin dedos.
- **Diseño:** caras del cuerpo de pies, pantorrillas o manos, desplazadas por la normal (2–6 mm), con suela extruida en el calzado. Mismos vértices = mismas formas y pesos (copia directa, sin búsqueda). Se ocultan con AB.6.
- **Prueba:** como AB.5 (formas copiadas: 0 mm de diferencia en reposo antes del desplazamiento) y conteo de piel por fuera = 0 con AB.6.
- **Nivel:** medio · **Tam.:** M.

### AB.11 Accesorios rígidos
- **Objetivo:** generadores en el núcleo (MIT, cero assets): **cuernos** (borrador de `ruta/codigo/`), **halo**, **gafas**, **diadema/corona**, **orejas de animal**; y armas en los anclajes (KayKit CC0 si se aprueba descargarlo, o generadores de espada, escudo y linterna; ya existe `test_sword.gd`).
- **Diseño:** el patrón de `ruta/pasos/13_piezas_y_accesorios.md` (13.1 y 13.5): función pura `build(params) -> ArrayMesh`, parámetros guardados en el proyecto, `BoneAttachment3D` en el hueso o el anclaje. Escalar con la cabeza (las piezas de cabeza siguen la escala del hueso `Head`).
- **Prueba:** la del generador de cuernos de la ficha 13 para cada generador (vértices esperados, malla cerrada, normales unitarias, caja dentro del tamaño pedido); la espada sigue en la mano al animar en un proyecto vacío.
- **Nivel:** medio (fuerte el primer generador) · **Tam.:** M.

### AB.12 Formas propias nuevas: orejas
- **Objetivo:** «Orejas puntiagudas» y «Orejas grandes» como formas del cuerpo (deslizadores de la zona Cara o de una zona Orejas), para hacer elfos sin piezas.
- **Archivos:** `blender/formas_propias.py` (o uno nuevo, como `cara_anime.py`), `godot/datos/humana/*`, `deslizadores.csv`.
- **Prueba:** como el 6.2 (sube la `version`, sha256, medidas de la forma); la forma no mueve ningún vértice fuera de la oreja (> 0,01 mm).
- **Nivel:** fuerte · **Tam.:** M · **Modelo:** Fable.

### AB.13 Pestañas Ropa, Pelo y Accesorios
- **Objetivo:** cada pestaña con una fila por pieza de su tipo (por ahora solo el nombre: las miniaturas, en `IDEAS.md`), colores por pieza, parámetros (largo de manga…), estampados por parámetros del shader (rayas, cuadros, degradado) y **sin autor ni licencia en las tarjetas o filas de piezas: van solo en el panel de Créditos (D45)**.
- **Diseño:** el mismo esqueleto de ventana que Cuerpo (izquierda: categorías y miniaturas; derecha: ajustes de la pieza elegida). Una sola pieza por ranura, salvo accesorios (`ARQUITECTURA.md` §6).
- **Prueba:** poner, cambiar y quitar piezas es un cambio para Deshacer; ninguna fila de piezas muestra autor ni licencia, y Créditos lista cada pack con la licencia de su `pack.json`.
- **Nivel:** medio · **Tam.:** L.

### AB.14 Publicar el Pack Base 1
- `godot/packs/base/LEEME.md` (qué trae, licencia CC0, cómo se hizo), miniaturas, fila en `CREDITOS.md`. Si se aprueba D36: las piezas rígidas como pack suelto en `.glb` para OpenGameArt o itch.io (lo publica el responsable).

**Hecho cuando (fase AB):** un personaje Femenina y otro Masculino, cada uno con peinado, camiseta, pantalón, botas y un accesorio, se exportan, pasan `probar_glb.gd`, se animan en un proyecto vacío sin que la piel atraviese la ropa, y todos los packs aparecen con su autor y licencia en Créditos.

---

## 6. Fase X — Pendientes de `IDEAS.md` sin fase propia

| Paso | Objetivo | Nivel | Tam. | Notas |
| --- | --- | --- | --- | --- |
| X.1 | Pies al suelo al animar (IK de pies) | fuerte | M | IK de dos huesos del borrador (10.10); se midieron hasta 168 mm de pie flotando al sentarse (5.1) |
| X.2 | Más deslizadores de cuerpo de MakeHuman (pies, dedos, orejas; nada bajo la prenda base) | medio | M | Filas nuevas en la tabla; medir memoria por forma antes (O6) |
| X.3 | Más clips y cargar animaciones propias (`.glb` humanoide) | medio | M | Reutiliza `PoseRetarget`; rechazar archivos sin esqueleto humanoide con un aviso claro |
| X.4 | Forma correctora del hombro con el brazo sobre la cabeza | fuerte | L | Hunde 21–43 mm al «Atacar» (5.8); forma guiada por el ángulo del brazo; decidir cómo la usa el juego |
| X.5 | Selector de polígonos al exportar (Low-poly, Ligero, Medio, Completo) | fuerte | L | Mismos huesos y anclajes; pesos de la base; pruebas de deformación por nivel |
| X.6 | Estilos nuevos: semirrealista (sombreado suave sin contorno) y pixel art (render a baja resolución con paleta) | medio | M | Como estilos de datos del 14.1; el pixel art es del estudio (imagen), no del `.glb` |
| X.7 | Cara: umbral del tono medio y transición gradual de las normales (sin escalón en la sien). La sombra de la nariz debe desaparecer o bajar mucho, con `shadow_receive` (SH.4) o con estas normales | fuerte | M | Toca `StyleNormals`; juicio visual A/B; referencia: fila masculino de `pruebas/capturas/shader_ab/hoja_cara.png` |
| X.8 | Luz de vista previa con presets (día, atardecer, mazmorra) | simple | S | Amplía IU.3; útil para el juego oscuro |
| X.9 | Exportar cápsulas de colisión por hueso (daño por zonas) | medio | M | Junto al `.glb`: `CollisionShape3D` por hueso en la `.tscn` del 11.4, o un JSON con radios y largos |
| X.10 | Plugin para Godot: GameMolde como pestaña del editor de Godot | medio | M | `EditorPlugin` con `_has_main_screen()`; mismo núcleo y misma interfaz |
| X.11 | NPC en el juego: crear personajes variados en tiempo de juego | medio | M | API del núcleo `from_preset(dict)` + variación aleatoria; ejemplo con 20 personajes y medida de FPS |
| X.12 | Comunidad: guía «Cómo crear una pieza», lista de packs en GitHub (solo licencias comprobadas) | simple | S | Documentos |
| X.13 | Traducciones (español base, inglés) | simple–medio | M | `TranslationServer` + CSV de traducciones; los textos salen del código |
| X.14 | Simetría relativa (mover un lado suma lo mismo al otro) | simple | S | Opción en `BodyEditor` |
| X.15 | Opción de 8 influencias al exportar | medio | S | Aviso: algunos motores solo leen 4 |
| X.17 | ~~Edades de 5 a 60 años con deslizador Edad y plantillas por edad~~ | — | — | **Descartado el 2026-11-21:** sin deslizador Edad: con Altura (desde ×0,65) y los demás deslizadores (PL.8, responsable, 2026-11-21) |
| X.16 | Reproducción mínima del cuelgue de `GLTFDocument` (BoneAttachment sin malla ni piel) | medio | S | El responsable decide si lo reporta a Godot |

**Meta de estilo después del MVP (2026-11-21):** el sombreado de la ampliación apunta a un estilo como el de VRoid (solo inspiración visual) y su referencia es `diseno/referencia_estilo_quaternius.png`; el MVP mantiene la sombra de 3 tonos y el contorno negro (D44 en `ruta/DECISIONES.md`).

---

## 7. Decisiones nuevas (para `ruta/DECISIONES.md`)

| Código | Pregunta | Opciones | Recomendación |
| --- | --- | --- | --- |
| D30 (ya existe) | Fuente de la interfaz (**decidida: b**) | a) La de Godot · b) Nunito (SIL OFL 1.1, comprobada) | **b)**: la letra redondeada aporta buena parte del aire amable que se busca. Pide ampliar la regla 5: «OFL solo para fuentes», con `OFL.txt` y fila en `CREDITOS.md` |
| D32 | Orden de la expansión | El de §0 · otro | **Decidida el 2026-11-18:** los assets van antes que Windows; Windows, al final |
| D33 | Iconos | a) Propios, CC0 · b) Tabler Icons (MIT, comprobada) | **Decidida: b)**, temporal (Tabler v3.50.0) |
| D34 | Tema por defecto | a) Claro · b) Oscuro | **Decidida: b)** oscuro, con un botón pequeño para cambiar a claro |
| D35 (**decidida: a**) | ¿«Exportar» deja de ser pestaña y pasa a botón principal con diálogo? | a) Sí · b) No | **a)** Las pestañas son para crear el personaje; exportar es una acción |
| D36 | Licencia de los assets propios y de los CC0 moldeados, y ¿se publican las piezas rígidas y los peinados como pack suelto? | a) CC0 y publicar · b) CC0 sin publicar fuera | **a)** Suma al portafolio y no cuesta nada; los moldeados citan al autor original |
| D39 | ¿Se aprueba descargar los packs de §5.3 (prioridades 1 y 2) y KayKit? | a) Sí, uno a uno, con la licencia comprobada · b) No, solo assets propios | **a)** El permiso de red lo da el responsable en cada descarga |
| D40 | Código de Anny (Apache 2.0) y Character Studio (MIT): ¿se porta con su cabecera o se reimplementa? | a) Reimplementar en GDScript y citar en `CREDITOS.md` · b) Portar con cabecera y aviso | **a)** Están en Python y JavaScript: portar ya es reescribir. Se citan igual |
| D41 | ¿Las 52 expresiones «Face Units» (CC0) entran en `datos/` cuando llegue la Fase 9? | a) Sí, con D31 · b) No, expresiones propias | **Decidida el 2026-11-24 (responsable): a)**, mezcladas en 5 expresiones VRM (faceunits01, `ruta/pasos/9.7_expresiones.md`) |
| D37 | ¿El pipeline vuelve a exportar los helpers de MakeHuman como piezas (AB.3)? | a) Sí · b) No, solo el camino del 12.1 | **a)** Es el camino más barato y fiable para la ropa ceñida, la falda y el pelo |
| D38 | Rango del deslizador Edad | — | **Sustituida por D42** (responsable, 2026-11-20): de 5 a 60 años. El deslizador Edad se descartó el 2026-11-21 |
| D42 | ¿Se permiten personajes de 5 a 60 años, como Anny (X.17)? | a) No · b) Sí, con las salvaguardas de X.17 | **Decidida el 2026-11-19: b)** |

---

## 8. Fase R — Lo que rescatamos de proyectos parecidos

Análisis completo (qué es cada proyecto, licencias, qué no se toca): `propuestas/proyectos_parecidos.md`.
No es una fase con orden propio: **cada paso se hace junto a la fase que dice la columna «Va con»**, cuando llegue.
Licencias: Anny = Apache 2.0 (datos CC0); Character Studio = MIT; Humanizer = AGPL, **solo ideas, sin abrir su código al implementar**.

| Paso | Qué | De dónde | Va con | Nivel | Tam. |
| --- | --- | --- | --- | --- | --- |
| R.1 | **Expresiones CC0:** las 52 formas «Face Units» (nombres ARKit) en `datos/`, sacadas de su origen en MakeHuman | Anny (datos CC0) | 9.7–9.8 (necesita D31) | fuerte | M |
| R.2 | Edad solo con `young` ↔ `old` (el rango completo de Anny queda para X.17) | Anny | PL.8 (ya integrado arriba) | — | — |
| R.3 | Deslizador «Proporciones ideales» (macro `proportions` de MakeHuman) | Anny | Fase PL, tras PL.8 | fuerte | M |
| R.4 | **Mallas ligeras** (sin dedos de los pies; reducidas al 10 %, 5 % y 3 %) con formas, pesos y huesos pasados por proyección baricéntrica | Anny (Apache 2.0) | X.5 y Android (Fase 15) | fuerte | L |
| R.5 | Simetría en la proyección: los vértices del plano central se proyectan sobre el corte de la malla con ese plano | Anny | AB.3 y 12.1 (`shape_transfer.gd`) | fuerte | S |
| R.6 | Medidas: contorno de cintura (bucle de vértices), volumen | Anny | IU.8 | simple–medio | S |
| R.7 | Comprobación nueva: «islas» de peso (vértices sueltos con peso de un hueso lejano) | Anny | `CharacterChecks` (5.3) | medio | S |
| R.8 | **Ocultar lo tapado por capas:** rayos desde cada cara de la capa baja, a lo largo de su normal, con alcance por pieza (3 cm por defecto); si los tres vértices chocan con una capa superior, la cara se oculta | Character Studio (MIT) | AB.6, 12.3–12.5 | medio–fuerte | M |
| R.9 | Restricciones entre piezas en `pack.json` (`prohibe`, `oculta_tipos`, `activa_formas`): «el casco quita el pelo» | Character Studio | AB.2 y AB.13 | fuerte (formato de pack) | S |
| R.10 | **Exportar optimizado para juego:** todas las mallas en una y texturas en un atlas (una llamada de dibujo) | Character Studio y Humanizer (idea) | AB.7, X.5, Android | fuerte | M |
| R.11 | **Hoja de sprites:** cada animación desde N ángulos en un atlas, con tamaño de píxel opcional | Character Studio | Fase 10 (estudio) y X.6 (pixel art) | medio | M |
| R.12 | Vida en la vista: parpadeo automático, ojos que siguen a la cámara, microsacadas | Character Studio y Humanizer (idea) | Tras 9.4 | medio | S |
| R.13 | Usar `VRMExporter.js` como referencia de la extensión `VRMC_vrm` al escribir la ficha detallada | Character Studio | Fase 17 (D24 a) | simple | S |
| R.14 | **Grabar expresiones con el móvil** (apps de seguimiento facial como MeowFace, que es de Android) sobre las formas ARKit de R.1 | Humanizer (idea) | Tras R.1 y 9.7 | fuerte | L |
| R.15 | Colisionadores por hueso y esqueleto físico (ragdoll) generados desde el cuerpo | Humanizer (idea) | X.9 | medio | M |
| R.16 | Personajes en tiempo de juego: caché, cola en hilos, cambio de equipo instantáneo | Humanizer (idea) | X.11 | fuerte | M |
| R.17 | Animaciones de cualquier esqueleto humanoide y escala del movimiento según la altura | Humanizer (idea) | X.3 | medio | M |
| R.18 | Texturas procedurales por capas (ruido, Worley, degradados, máscaras) y relleno de costuras UV | Humanizer (idea) | 14.4 | medio–fuerte | M |
| R.19 | Exportar un lote de N personajes al azar (con semilla) | Character Studio | X.11 | simple | S |
| R.20 | La licencia dice lo mismo en `LICENSE`, README, notas de versión y cualquier tienda | Lección de Humanizer | 7.4 y cada publicación | simple | S |

**Notas que no deben perderse:**

- **R.1:** de las 52 formas, 31 también mueven *helpers* (ojos, dientes, pestañas, lengua) que no tenemos: se exporta solo la parte de la piel y se informa de cuáles quedan cojas. `tongueOut` no sirve sin lengua; `jawOpen` necesita resolver antes las bolsas de la boca (9.6). Probar cada forma encima de la cara anime: si alguna suma mal, se corrige con una forma propia o se descarta. Nombres: los de ARKit dentro del editor; la Fase 17 los traduce a los de VRM.
- **R.4:** las mallas reducidas de Anny son de NAVER (Apache 2.0): cabecera y aviso en `CREDITOS.md`. Medir el aspecto con el toon y el contorno en cada nivel (juicio visual), y las pruebas de deformación por nivel que pide X.5.
- **R.8:** es un cálculo que se hace al soltar el deslizador o al cambiar de pieza, no en cada fotograma. Medir el tiempo en el cuerpo completo; si pasa de 100 ms, en un hilo (como el exportar del P.1).
- **R.14:** **comprobar** el protocolo de esas apps en su documentación pública. Es la primera función que usa la red: pide aprobación (regla 1) y aviso claro al usuario.

---

## 9. Señales de alarma propias de esta expansión

Además de las de `ruta/GUIA_MODELOS.md` §3, el agente **para y pregunta** si:

1. Un paso de la fase IU necesita tocar el núcleo (`addons/creador/`) y la ficha no lo decía.
2. Una plantilla, un aleatorio o una combinación de deslizadores da una edad fuera de 5–60 años, o una edad infantil sin las salvaguardas de X.17.
3. Un asset no trae su licencia en el propio archivo descargado o en la página oficial del autor, o la licencia del archivo no coincide con la de la página. Sin licencia comprobada no se descarga ni se usa (D19: nada de CC-BY por ahora). Tampoco se usa nada que venga de VRoid ni nada etiquetado como personaje adolescente o infantil, aunque diga CC0.
4. Un recorte de prenda o un peinado deja ver detalle anatómico bajo la ropa.
5. Las formas de una pieza disparan la memoria por encima de lo medido en AB.3 más un 20 %.
6. Algo de la maqueta HTML no se puede hacer igual en Godot: se propone la alternativa más cercana con una captura, no se inventa otra cosa.
7. Un paso de la fase R necesita mirar el código de Humanizer (AGPL): no se mira. Se trabaja desde `propuestas/proyectos_parecidos.md` §3 y la documentación pública.
