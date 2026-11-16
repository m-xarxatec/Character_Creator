# PLAN — GameMolde (hasta el MVP)

> Paso a paso. Un paso cada vez y siempre con aprobación (ver `CLAUDE.md`).
> Lo que no es del MVP va a `IDEAS.md`.

**Estado actual:** Fase 5 · 5.1 y 5.2 hechos; siguiente: 5.3
**Leyenda:** `[ ]` pendiente · `[~]` en curso · `[x]` hecho

---

## Qué es el MVP

Un programa hecho con Godot, con una pestaña **Cuerpo** que permite:

- Editar un cuerpo humano por zonas (14 zonas) con deslizadores de **forma** y de **proporción**, con simetría.
- Ver el resultado en vivo en un maniquí 3D y probarlo con animaciones.
- Exportar un `.glb` listo para un juego de Godot: huesos reajustados, pesos correctos, perfil humanoide y puntos de anclaje.
- **Estilo ilustración** (anime 3D): sombra de 3 tonos (valor por defecto) y contorno negro grueso, igual en el editor y en el juego.

**Fuera del MVP:** cara y ojos, pelo, ropa (salvo la prenda base), accesorios, catálogo de packs y VRM.

---

## Fase 0 — Preparación

- [x] 0.1 Instalar Blender 4.2 LTS o superior, MPFB2 y el pack "MakeHuman system assets". Anotar versiones en `CLAUDE.md`.
- [x] 0.2 Instalar Godot 4 estable y anotar la versión en `CLAUDE.md`.
- [x] 0.3 Crear el repositorio git con la estructura de `CLAUDE.md` y un `CREDITOS.md` vacío.
- [x] 0.4 Prueba a mano: humano en MPFB2 → `.glb` → Godot con `SkeletonProfileHumanoid` → animación CC0 de Quaternius.
- [x] 0.5 Decidir la licencia del editor (MIT o GPL-3.0) y un nombre provisional.

**Hecho cuando:** el humano de prueba camina en Godot sin deformaciones raras y las versiones están anotadas.

---

## Fase 1 — Pipeline en Blender (sin ventana)

- [x] 1.1 Script `blender/generar_cuerpo.py`: recibe un JSON con valores y crea el humano con MPFB2.
- [x] 1.2 Aplicar el rig *Game engine* (pesos a 4 influencias) y la prenda base pintada. Sin proxy: se usa la malla completa.
- [x] 1.3 Hornear formas, quitar helpers y resolver las máscaras.
- [x] 1.4 Exportar `.glb` según `CLAUDE.md` (sección 6) y añadir los 4 puntos de anclaje.
- [x] 1.5 Renders de frente, perfil y espalda para revisarlos.
- [x] 1.6 Prueba automática: el `.glb` se abre en Godot sin errores y el BoneMap se rellena solo.

**Hecho cuando:** `blender -b -P blender/generar_cuerpo.py -- cuerpo.json salida.glb` funciona con 5 JSON distintos.

---

## Fase 2 — Datos para Godot

- [x] 2.1 Tabla de deslizadores del MVP: zona → deslizador → tipo (Forma / Proporción / Por crear) → target de MakeHuman o hueso. Meta: poder cambiar el tamaño de cada parte (cuello, espalda a lo ancho y hacia atrás, largo de la cara…). La tabla es un archivo de datos: añadir un deslizador = añadir una fila, sin tocar código.
- [x] 2.2 Definir el formato de `datos/` (manifiesto con `version`): `datos/FORMATO.md`.
- [x] 2.3 Conversor `blender/exportar_datos.py`: genera `datos/humana/` según `datos/FORMATO.md` (cuerpo en pose A con formas y anclajes como huesos, articulaciones con sus desplazamientos y manifiesto con `sha256`).
- [x] 2.4 Prueba: reajustar los huesos fuera de Blender da el mismo resultado que MPFB2 (diferencia < 1 mm) en 6 cuerpos.
- [x] 2.5 Limpiar pesos cruzados entre lados en `datos/` (umbral y medida antes de aplicar); al terminar, el límite de la variante A (codo a 90°, `probar_personaje_horneado.gd`) vuelve a 0,1 mm.

**Hecho cuando:** `datos/` está completa, versionada y probada.

---

## Fase 3 — Núcleo en Godot (sin interfaz)

- [x] 3.1 Cargar `datos/` y montar malla y esqueleto.
- [x] 3.2 Deslizadores de forma (*blend shapes*) con simetría. Comprobar que Godot calcula los mismos pesos que el script de Blender, incluidas las 81 correcciones.
- [x] 3.3 Deslizadores de proporción (escala uniforme de huesos).
- [x] 3.4 Reajuste de huesos con `articulaciones.json` (base + desplazamientos de cada forma) y *bind poses*.
- [x] 3.5 Prenda base: el shader corta en 0,5 el color por vértice `garment` (degradado de 6 cm: borde recto en la malla completa; ya sigue al cuerpo sola), con un interruptor para mostrarla u ocultarla que también se guarda al exportar.
- [x] 3.6 Exportar `.glb`, en 6 subpasos. Salen dos variantes para comparar: pose T horneada y pose A con la corrección de silueta de Godot; la elección entre pose T horneada y pose A se decide en la Fase 5, con el banco de pruebas.
  - [x] 3.6.1 Horneado en CPU: vértices y normales finales sin tarjeta gráfica (formas + esqueleto con los 4 pesos). Prueba: CPU contra `bake_mesh_from_current_skeleton_pose()` con ventana (< 0,01 mm); codo a 90° contra MPFB (< 0,5 mm) sin ventana. **Hecho cuando:** la prueba de malla del 3.3 y la del codo del 3.4 pasan con `--headless`.
  - [x] 3.6.2 Pose T: girar los brazos de pose A a pose T como pose del esqueleto, reimplementado desde la descripción (sin copiar `blender/pose_t.py`, GPL). Prueba: brazos horizontales (< 1°); malla contra el mismo cuerpo en pose T hecho en Blender (límite a proponer con la medida real). **Hecho cuando:** el neutro y el extremo quedan en pose T y las manos no se deforman.
  - [x] 3.6.3 Hornear el personaje: uno nuevo y limpio, con formas, escala de Proporción y pose pasadas a la malla y al reposo, y apoyado en el suelo (punto más bajo de los pies en y = 0). Prueba: todos los huesos con escala 1; malla igual que antes de hornear (< 0,1 mm); punto más bajo en y = 0; máximo 4 influencias por vértice, que suman 1; medir cuánto cambia la deformación al recortar a 4 influencias (codo a 90°, antes y después) y dar la medida antes de fijar el límite. **Hecho cuando:** salen las dos variantes (pose T horneada y pose A), sin formas ni escalas.
  - [x] 3.6.4 Anclajes y huesos: los 4 huesos de anclaje pasan a nodos vacíos hijos de su hueso, sin la escala del hueso; quedan los 53 huesos de deformación. Prueba: 53 huesos con nombre y padre humanoide; 4 anclajes en su sitio (< 0,1 mm) y con escala 1; malla deformada (codo a 90°) igual antes y después de quitar los anclajes (< 0,01 mm); si los índices de huesos cambian, los pesos siguen apuntando al hueso correcto. **Hecho cuando:** el personaje horneado cumple la tabla de `CLAUDE.md`, menos el archivo.
  - [x] 3.6.5 Escribir el `.glb`: las dos variantes con `GLTFDocument`. Prueba: `probar_glb.gd` (paso 1.6) pasa con los dos; al reimportar, malla y huesos iguales (< 0,1 mm); los dos se abren en Blender sin errores y con 53 huesos. **Hecho cuando:** los dos `.glb` se abren en Godot sin el addon y se animan. Si `GLTFDocument` se cuelga al exportar un `BoneAttachment3D` con un hijo, parar y preparar una reproducción mínima en `pruebas/fase_3/cuelgue_gltf/` (versión exacta de Godot, escena mínima, qué pasa).
  - [x] 3.6.6 Prenda fuera del editor: debe verse igual en Blender, otros motores y Godot sin el addon. Proponer: textura horneada con las UV o dos materiales por caras. Respeta el interruptor (si está oculta, no se exporta). Prueba: abrir el `.glb` exportado en Blender y comprobar que se ve la prenda (captura); con el interruptor apagado, no se ve. **Hecho cuando:** la prenda se ve igual en Blender y en Godot sin el addon.
- [x] 3.7 Guardar y cargar presets en JSON (`preset.gd`: Dictionary o texto, sin decidir carpetas; formato con `version` propia y carga estricta; ver su cabecera).
- [x] 3.8 Pruebas: 10 cuerpos aleatorios → exportar → reimportar → comparar (`probar_aleatorios.gd`; límites en el registro).
- [x] 3.9 `update_character()` (`CharacterUpdater.update()`, un objeto que guarda la especie y el reposo original): única función del núcleo que aplica, en este orden, formas → reajuste → escala de proporción → pose base (la pose T lee la escala de la pose, así que va después de ella). El resto del programa solo usa esta función. Prueba: llamarla dos veces seguidas da el mismo resultado (0 mm exactos). `probar_estilo.gd`, `probar_exportar.gd` y las pruebas de fases anteriores siguen montando el personaje a mano; pasan a `CharacterUpdater` cuando se toquen.
- [x] 3.10 Estilo ilustración en el núcleo: `BodyMaterial` monta `toon.gdshader` (3 tonos por defecto, sin brillo) con el contorno (`outline.gdshader`, grosor ajustable) como `next_pass`, y lo ofrece al editor y al exportador. Queda un solo shader, `toon.gdshader`, con un interruptor `unlit` (sin luces ni contorno) para las pruebas de color exacto de la prenda. **Hecho cuando:** `BodyMaterial.apply()` deja el material toon con contorno y con los valores por defecto de `GUIA_ESTILO.md`; `probar_material.gd` (sin ventana) y las pruebas de la prenda (con `unlit`) pasan; `probar_estilo` usa el núcleo; `body.gdshader` está borrado. Fuera del MVP, en `IDEAS.md`: 2 tonos y grosor por zona. Normales suavizadas: 3.16.
  - [x] 3.10a Material y prueba sin ventana: `BodyMaterial.apply()`, `set_unlit()`, `set_outline_width()` y `probar_material.gd`. `body.gdshader` sigue.
  - [x] 3.10b Pasar `probar_estilo` y las pruebas de la prenda al núcleo (con `unlit`), comprobar que el color sale igual que con `body.gdshader` y borrarlo.
  - [x] 3.10c Hoja de valores (`probar_valores_estilo.gd`, con ventana): mínimo, por defecto y máximo de borde, rim, grosor del contorno y tono de piel y sombra. El responsable elige; entonces se completan la tabla de valores de `GUIA_ESTILO.md` y la comprobación de `probar_material.gd`.
- [x] 3.11 Al exportar, el personaje sale con ese estilo listo para el juego (el `.glb` + el material de Godot). Además, el `.glb` lleva un material con luz básico (PBR sin brillo) en vez del material sin luces de hoy (`KHR_materials_unlit`, `glb_exporter.gd`), para que reciba sombra fuera del editor (lo marcó el revisor el 2026-11-12). La prueba de exportación debe fallar si el material es sin luces.
  - [x] 3.11a `.glb` con material con luz (metálico 0, rugosidad 1); `probar_prenda_exportada` falla si es sin luces y `probar_glb_en_blender` captura con Workbench (luz plana).
  - [x] 3.11b `.tres` autocontenido junto al `.glb` (shaders toon y contorno incrustados, no enlazados al addon), probado en un proyecto vacío; `toon.gdshader` lee la prenda con `min(COLOR.r, COLOR.a)` (editor y `.glb`), con comentario del porqué.

### ★ 3.12 Prueba de estilo — se hace justo después del 3.6.6 y antes de la Fase 4

**Es el paso que decide si el editor cumple su objetivo: personajes bonitos, tipo VRoid.**

- [x] 3.12 Prueba de estilo.

**Objetivo:** comprobar si la base de MakeHuman puede llegar a un aspecto anime tipo VRoid, o si hace falta una cabeza estilizada propia. Es una prueba visual: rápida y sin pulir el código, pero con un resultado visual cuidado.

**Qué hacer:**

- **Sombreado toon** sobre `body.gdshader`: 2 o 3 tonos planos con bordes suaves, una luz de contorno (*rim*) suave, sin brillo especular y con la piel en un tono cálido. Contorno exterior de grosor regulable (malla invertida o el método que se proponga). Puede adelantar parte del 3.10.
- **Suavizar la anatomía:** el sombreado toon marca costillas, músculos y bultos. Probar a reducir ese detalle con los deslizadores existentes (músculo, grasa) y, si hace falta, con normales suavizadas. Decir qué funciona.
- **Tres presets de proporciones**, solo con los deslizadores que ya existen, guardados en JSON. Para cada uno, medir cuántas cabezas de alto tiene:
  - a) Anime femenino: cabeza algo mayor, cuello fino, cintura estrecha, piernas largas, manos y pies pequeños.
  - b) Anime masculino: hombros algo anchos, cintura estrecha, piernas largas, poco músculo marcado.
  - c) Chibi oscuro (para el juego): unas 2,5 cabezas de alto, manos y botas algo grandes.
- **Ojos provisionales:** solo para juzgar la cabeza, unos ojos sencillos (esferas o calcomanía plana). No es la pestaña Cara; se quitan después.
- **Referencia:** describir el aspecto VRoid con palabras (proporciones, sombreado, cara). No usar mallas, texturas ni capturas de VRoid: es software cerrado.

**Capturas:** en `pruebas/capturas/estilo/`, con la misma luz y cámara en todas:

- Cada preset de frente, perfil y tres cuartos, con el sombreado normal y con el toon.
- Primer plano de la cara de cada preset con el toon.
- Cámara del juego, para cada preset: desde arriba a unos 45° y a distancia de juego, con el toon y el contorno.
- Chibi fuera de rango, solo para juzgar (sin tocar `datos/`): cabeza ×2,2 y largo de piernas y torso al mínimo, con un primer plano del cuello.
- Una hoja de contacto con todo junto.

**Informe final, corto:**

- Qué funciona y qué no, en 5 líneas como mucho.
- Recomendación, con el porqué: (1) la base sirve con ajustes, (2) hace falta una cabeza estilizada propia, o (3) hace falta una base completa estilizada.
- Qué formas «Por crear» harían más falta para el aspecto anime.

**Reglas:** propuesta antes de empezar. El shader va al núcleo (MIT). Sin dependencias nuevas. Lanzar con `ulimit` y `timeout`. Modelo: Fable.

**Hecho cuando:** todas las pruebas pasan sin tocar la interfaz.

### 3.13 Elegir el camino de la cabeza anime

A = cabeza propia unida al anillo del cuello (pieza intercambiable); B = formas anime sobre la cara de MakeHuman. Se decide con maquetas (rápidas, sin pulir):

- [ ] ~~3.13a-1 Cortar la cabeza de MakeHuman por el cuello y volver a unirla: costura y contorno con cuerpos extremos.~~ No se hace: decidido el camino B.
- [x] 3.13a-2 Normales de elipsoide en la cara actual: capturas de antes y después, y comprobar que llegan a Blender y a Godot sin el addon.
- [ ] ~~3.13a-3 B barato: aplanar la cara solo con formas de MakeHuman que ya existen, con macros extremas (máximo y media).~~ No se hace: la cara como forma propia la sustituye.
- [x] 3.13a-4 Cabeza anime por script, deformando la de MakeHuman (CC0, mismo anillo), con las normales de elipsoide al 100 %; capturas con el toon de frente, de perfil y con la cámara del juego. `referencias/anime-model.blend` (CC-BY-SA 3.0, major4zMeakrob) es solo referencia visual (mirarla y compararla en capturas): prohibido usarla en operaciones geométricas (Shrinkwrap, Data Transfer, snapping, retopología encima, medidas punto a punto) y copiar su malla, pesos o UV.
- [x] 3.13 Decisión: **camino B**, la cara anime como formas por rasgo sobre la malla completa (en la propuesta se llamó «(a)»). Origen: deformación por script de la cabeza de MakeHuman (CC0).

Pasos formales que salen de la decisión (pendientes; cada uno con su propuesta):

- [x] 3.14 Formas por rasgo en `datos/` (`cuenca_plana`, `boca_anime`, `mandibula_anime`, `menton_anime`, `nariz_anime`), desde `blender/cara_anime.py`; sin deslizadores visibles en el MVP. Sube la `version` del manifiesto si cambia el formato.
- [x] 3.15 Preset «cara anime»: todas las formas a 1, salvo `nariz_anime` a 0 (nariz de MakeHuman).
- [x] 3.16 Normales del núcleo: cara (elipsoide, aplanado 0,6) y torso (suavizado, ×10 en la prueba del 3.12). Hoy viven solo en las maquetas (`pruebas/godot/probar_normales_cara.gd` y `probar_estilo.gd`). Aplanado 0,6 decidido con la hoja A/B sobre la cara anime (2026-11-14).
- [x] 3.17 (antes de cerrar la Fase 3) Las 5 pruebas con ventana que pisan capturas de otras (`probar_estilo`, `probar_cara_anime`, `probar_normales_cara`, `probar_prenda_exportada`, `probar_rendimiento`) pasan a guardar en su propia carpeta, como pide `CLAUDE.md`, para que el revisor visual pueda ejecutarlas todas sin tocar las capturas del constructor.

---

## Fase 4 — Interfaz: pestaña Cuerpo

Según `diseno/maqueta-pestana-cuerpo.html`.

- [x] 4.1 Ventana con pestañas (solo Cuerpo activa).
- [x] 4.2 Vista 3D con cámara orbital y maniquí en vivo.
- [x] 4.3 Zonas y deslizadores con etiqueta de tipo.
- [x] 4.4 Simetría, deshacer y rehacer, y "restablecer zona". Aviso al activar la simetría si los lados difieren: lista de deslizadores distintos y botones Mantener como está (por defecto) / Igualar a la izquierda / Igualar a la derecha. Igualar cuenta como un solo cambio para Deshacer. Si los lados son iguales, no se muestra el aviso.
- [x] 4.5 Botones Probar huesos y Exportar .glb conectados al núcleo, y botón para quitar o poner la prenda base.
- [x] 4.6 El maniquí se ve con el estilo ilustración, con las normales de estilo recalculadas al soltar el deslizador.
- [x] 4.7a Acabado en el núcleo: borde, rim (fuerza y ancho) y grosor del contorno con `BodyMaterial`; los valores se guardan en el preset. Sube el formato del preset a la versión 2 y migra los presets existentes.
- [x] 4.7b Panel Acabado en la ventana: color de piel (cualquier color), borde, rim (fuerza y ancho) y grosor del contorno.

**Hecho cuando:** se crea y se exporta un personaje usando solo el ratón.

---

## Fase 5 — Banco de pruebas de huesos

- [x] 5.1 Animaciones de prueba CC0: reposo, caminar, correr, atacar, sentarse.
- [x] 5.2 Poses extremas: brazos arriba, sentadilla, giro de tronco.
- [ ] 5.3 Comprobaciones automáticas: pesos que suman 1, ≤ 4 influencias, 56 huesos humanoides, anclajes presentes.
- [ ] 5.4 Informe visible (bien / aviso / error) con la zona afectada.
- [ ] 5.5 Decidir la pose de exportación con las dos salidas del 3.6 (si gana la A, cambiar la regla de `CLAUDE.md`).
- [ ] 5.6 Prueba de anclaje real: espada en `socket_hand_r` durante la animación de atacar. Los anclajes heredan la escala de su hueso en el editor; la espada no debe escalar con la mano.
- [ ] 5.7 Animaciones de Quaternius con y sin Overwrite Axis. Valorar exportar los huesos con los ejes del perfil humanoide de Godot para que no haga falta Overwrite Axis. Medida del 3.6.3 para elegir entre T y A: con el codo a 90°, la variante T horneada difiere del personaje del editor puesto en T hasta 20,1 mm (cuerpo extremo) y 12,1 mm (al azar), en el codo; la variante A, 0,11 mm. Hornear una pose cambia cómo se dobla después (Blender hace lo mismo).
- [ ] 5.8 Revisar de cerca la variante T: (a) hombro y axila en la estocada, con el brazo sobre la cabeza (zona oscura en el costado: ¿sombra o la piel se hunde?); (b) la mano derecha en pose T en reposo, que parece plana de canto.
- [ ] 5.9 Animación de rango de movimiento (ROM): cada articulación por todo su recorrido.
- [ ] 5.10 Medidas automáticas de malla: pérdida de volumen en articulaciones (%), autointersección, estiramiento de triángulos y triángulos degenerados.
- [ ] 5.11 Comparar capturas con las de `pruebas/capturas/aprobadas/` (% de píxeles distintos + imagen de diferencias), con cámara, luz y fondo fijos.
- [ ] 5.12 Prueba de legibilidad: captura de la cámara del juego reducida al tamaño real en pantalla, también con luz baja.
- [ ] 5.13 Toon y contorno en los tres renderizadores de Godot (Forward+, Mobile, Compatibility).
- [ ] 5.14 Informe del presupuesto técnico contra `diseno/GUIA_ESTILO.md`.

**Hecho cuando:** un cuerpo extremo muestra los avisos correctos.

---

## Fase 6 — Formas propias ("Por crear")

- [ ] 6.1 Esculpir con MakeTarget las formas que faltan (glúteos, pecho, cabeza chibi…). Incluye una forma para alisar pecho y entrepierna: con sombreado normal se marcan bajo la prenda e incumplen "sin detalle anatómico".
- [ ] 6.2 Añadirlas a `datos/` y subir la versión.
- [ ] 6.3 Probarlas en el banco de pruebas.

**Hecho cuando:** ningún deslizador del MVP queda como "Por crear".

---

## Fase 7 — Entrega del MVP

- [ ] 7.1 Builds para Linux (y Windows, si se decide). Decidir dónde vive `datos/` en el programa exportado y comprobar que el cargador lo encuentra.
- [ ] 7.2 README con capturas, vídeo y créditos.
- [ ] 7.3 Revisión de licencias y de `CREDITOS.md`.
- [ ] 7.4 Release en GitHub.

**Hecho cuando:** otra persona descarga el editor, crea un personaje y lo usa en Godot sin ayuda.

---

## Registro

> Las filas de las Fases 0 a 3 están en `REGISTRO.md`.

| Fecha | Paso | Qué se hizo |
| --- | --- | --- |
| 2026-11-14 | 4.1 | `godot/project.godot` (GameMolde, escena principal `res://app/main.tscn`; el núcleo queda dentro como `addons/creador/`). `godot/app/main.gd` crea un `TabContainer` con las 6 pestañas de la maqueta (Cuerpo, Cara y ojos, Pelo, Ropa, Accesorios, Exportar); solo Cuerpo activa. Las pestañas se crean en el script para que la prueba lo cargue desde otro proyecto. Prueba nueva `probar_ventana.gd` (sin ventana): 6 pestañas en orden, solo Cuerpo activa, se abre en Cuerpo y ningún archivo del núcleo nombra `app/`. El proyecto arranca sin errores (`--headless --quit-after 5`) |
| 2026-11-14 | 4.2 | `godot/app/body_view.gd`: vista 3D en un `SubViewport` (fondo gris, luz direccional, luz ambiente); carga `datos/humana` (dos carpetas por encima del script: vale para el MVP, no para distribuir) con el preset de personaje nuevo, `BodyMaterial.apply` + `Preset.apply_look`, pose A (reposo); `set_values()` llama a `CharacterUpdater.update` (lo usará el 4.3). `godot/app/orbit_camera.gd`: arrastrar con el botón izquierdo gira, la rueda acerca y aleja (1–5 m), ángulo vertical −10° a 60°, mira a 1 m de altura. La app carga el núcleo con `preload` relativo (sin `class_name`, para que las pruebas la carguen desde otro proyecto). Pestaña Cuerpo: vista a la izquierda (2/3) y panel vacío para los deslizadores. El estilo de las normales en vivo queda para el 4.6. Prueba nueva `probar_vista.gd` (sin ventana): carga sin error (695 ms), cámara de frente, giro de 90°, límites de ángulo y zoom, `head_size` a 1 da escala 1,3 y volver al preset deja el esqueleto igual. Pasan `probar_vista` y `probar_ventana`; el proyecto arranca sin errores. `IDEAS.md`: estética de la ventana después del MVP |
| 2026-11-15 | 4.3 | `godot/app/slider_panel.gd`: panel montado solo desde `deslizadores.csv`. Decidido por el responsable: las zonas son cabeceras en el orden de la tabla y al elegir una se despliegan sus deslizadores (y se pliega la anterior; empieza abierta Global). Cada fila: nombre, barra 0–1 (paso 0,01) y etiqueta de tipo con el color de la maqueta. Zona Cara oculta (`HIDDEN_ZONES`, paso 3.14); Por crear visibles y desactivados; dos lados = dos filas «(izq.)» = `_l` y «(der.)» = `_r` (la simetría es el 4.4). El maniquí cambia mientras se arrastra: `BodyView.set_value()` → `CharacterUpdater.update`. Prueba nueva `probar_panel.gd` (sin ventana): 14 zonas en orden, 48 filas, desplegar y plegar, etiquetas, solo 3 Por crear desactivados, barras con los valores del preset, Cabeza › Tamaño escala la cabeza 1,3, Músculo cambia las formas y la mano izq. solo la izquierda. Pasan `probar_panel`, `probar_vista` y `probar_ventana`; el proyecto arranca sin errores |
| 2026-11-15 | 4.4 | `godot/app/body_editor.gd` (sin interfaz): valores, simetría (activada al empezar; usa `ShapeWeights.set_value` del núcleo) e historial de hasta 200 cambios; `begin_change`/`end_change` hacen de un arrastre un solo cambio; `reset_zone` (al neutro de la tabla), `differing_sides` y `match_side` cuentan como un cambio. Deshacer solo deshace valores, no la simetría. `godot/app/symmetry_dialog.gd`: aviso de Godot (por ahora sin estilo, aprobado) con la lista «Zona › Nombre: izq. / der.» y Mantener como está (por defecto; también Intro, Esc o cerrar) / Igualar a la izquierda / Igualar a la derecha; si los lados son iguales no sale. `slider_panel.gd`: casilla Simetría y botones Deshacer y Rehacer arriba, Restablecer zona al final de cada zona, la barra avisa al editor al pulsar (`gui_input`, antes del salto) y al soltar, y la rueda ya no mueve las barras (`scrollable = false`). `main.gd`: Ctrl+Z, Ctrl+Mayús+Z y Ctrl+Y (acciones `ui_undo`/`ui_redo` de Godot). `body_view.gd` pierde `set_value` (todo pasa por el editor). Pruebas: nueva `probar_edicion.gd` (27 comprobaciones de la lógica) y `probar_panel.gd` ampliada (36: casilla, aviso, igualar, mantener, deshacer, rehacer, atajos y restablecer). Comprobado aparte con eventos de ratón simulados (script temporal): pulsar, arrastrar y soltar = 1 cambio. Pasan `probar_edicion`, `probar_panel`, `probar_vista` y `probar_ventana`; el proyecto arranca sin errores |
| 2026-11-15 | 4.5 | `godot/app/body_actions.gd`: barra inferior de la pestaña Cuerpo. Probar huesos alterna el maniquí entre reposo (A) y pose T (`BodyView.set_pose_t`; los deslizadores mantienen la pose); el banco de verdad es la Fase 5. Exportar .glb: diálogo de guardar, siempre en pose T (`GlbExporter.save` vía `BodyView.export_glb`), `.tres` al lado, «Exportando…» mientras tanto y aviso con la ruta o el error. Prenda base: casilla con `BodyMaterial.set_garment_visible` (no entra en Deshacer). `main.gd` pone la barra debajo. Prueba nueva `probar_acciones.gd` (sin ventana): prenda, pose T (mano 1,016 → 1,320 m) y vuelta al reposo idéntica, exportar ~1,5 s, mismo archivo desde reposo y desde pose T, ruta mala da aviso de error. Pasan `probar_acciones`, `probar_panel`, `probar_vista`, `probar_ventana` y `probar_edicion`; el proyecto arranca sin errores |
| 2026-11-15 | 4.6 | `godot/app/style_view.gd`: copia de la malla con las formas aplicadas y las normales de `StyleNormals.apply` (calculadas en reposo), sin formas propias, con el mismo esqueleto y material; la malla original no cambia (la usan `CharacterUpdater` y el exportador), solo se oculta. `body_view.gd`: mientras cambian las formas se ve la original; a los 0,3 s sin cambios (temporizador: vale también para Deshacer, Rehacer, Restablecer y simetría) se recalcula y vuelve la copia. Proporción y pose T no recalculan (no cambian las formas). Usa `MeshBaker._add_shapes`. Prueba nueva `probar_vista_estilo.gd` (sin ventana): vértices = original con formas, normales = `StyleNormals` (0,007°), cambio de vista al mover una Forma y vuelta al dejarla quieta; recálculo ~155 ms (carga 695 → 899 ms). Pasan `probar_vista_estilo`, `probar_vista`, `probar_panel`, `probar_acciones`, `probar_edicion`, `probar_ventana` y `probar_exportar`; el proyecto arranca sin errores |
| 2026-11-15 | 4.7a | El 4.7 se parte en 4.7a (núcleo) y 4.7b (panel). `BodyMaterial`: `FINISH` (claves y rangos: `softness` 0–0,5, `rim_strength` y `rim_width` 0–1, `width_px` 0–10), `set_finish` (recorta; rechaza clave desconocida, NaN e infinito), `get_finish` y `default_finish`. `Preset` versión 2: campo `acabado` (el que falta toma el valor por defecto, fuera de rango se recorta, desconocido o no numérico es error); `to_dict` lo recibe como último argumento opcional y `apply_look` lo aplica. **Decidido:** la versión 1 se sigue leyendo (carga con el acabado por defecto); siempre se guarda la 2. `datos/humana/presets/anime.json` a versión 2 y su sha256 en el manifiesto (la versión del manifiesto no sube: el formato de `datos/` no cambia). Los presets de `pruebas/fase_3/estilo/` siguen en versión 1 y cargan. Guardar y cargar presets desde la ventana queda para su paso. `probar_presets` (+11) y `probar_material` (+18, con el rango comparado con el `hint_range` de los shaders). Pasan `probar_material`, `probar_presets`, `probar_carga`, `probar_exportar`, `probar_vista`, `probar_vista_estilo`, `probar_acciones`, `probar_aleatorios`, `probar_update` y `probar_panel` |
| 2026-11-15 | 4.7b | `godot/app/finish_panel.gd`: panel Acabado bajo los deslizadores (columna derecha): selector de color de piel (sin transparencia), barras de borde, rim (fuerza y ancho) y contorno (px) con los rangos de `BodyMaterial.FINISH`, y botón Restablecer acabado (no entra en Deshacer, como la prenda). Cambia el material de la malla, que comparte la copia con estilo: el `.glb` y el `.tres` salen como se ve. `main.gd` lo coloca. Prueba nueva `probar_acabado.gd` (sin ventana): el panel empieza como el material, cada barra y el color lo cambian, el `.tres` lo recoge y Restablecer vuelve al valor por defecto. Corregido el comentario de `style_normals.gd` del 4.6, que nombraba `app/` y hacía fallar `probar_ventana` (el núcleo no nombra la interfaz). Pasan `probar_acabado`, `probar_ventana`, `probar_panel`, `probar_acciones`, `probar_vista` y `probar_edicion`; el proyecto arranca sin errores |
| 2026-11-16 | cierre de la Fase 4 y limpieza | El responsable comprobó el «Hecho cuando» con la ventana (11 pasos, solo con el ratón): **Fase 4 cerrada**. Limpieza aprobada: borrados `__pycache__/` (2), `godot/personaje.glb` y `.tres` (ahora en `.gitignore`: `godot/personaje.*`) y las capturas del constructor repetidas en la revisión del 14-nov (`estilo`, `cara_anime`, `prenda_blender`, `prenda_exportada`, `tres_vacio` y `normales_cara`, salvo `llegan_a_blender.png` y `llegan_a_godot_sin_addon.png`, que no se pueden regenerar); las filas del registro de las Fases 0 a 3 pasan a `REGISTRO.md` (`PLAN.md`: de 67 a 28 KB). `pruebas/**/salida/` ya estaba fuera de git. Propuesta de fases posteriores al MVP en `propuestas/hoja_de_ruta.md` (sin aprobar; no cambia este plan) |
| 2026-11-16 | 5.1 | Animaciones de prueba en el editor. Datos: `datos/animaciones/humanoide.json` (clips, tabla de 53 huesos y `sha256`) + `UAL1_Standard.glb` (Quaternius, CC0; la misma copia que `pruebas/godot/`), fuera de la carpeta de la especie: no toca el manifiesto ni `exportar_datos.py`. Núcleo: `animation_set.gd` (carga el `.glb` con `GLTFDocument`, sin importador; reproductor en modo manual, clips en bucle) y `pose_retarget.gd` (cada hueso gira respecto a su pose T lo que la fuente respecto a su reposo; `Hips` se desplaza por la proporción de alturas de cadera; no toca la escala). **Decidido:** se pasa la pose en cada fotograma en vez de convertir las animaciones, porque el reajuste cambia los huesos con cada deslizador. Interfaz: lista Animación en la barra (`body_actions.gd`), `BodyView.set_animation()`; los deslizadores siguen funcionando con el clip en marcha y exportar da el mismo archivo. Prueba nueva `probar_animaciones.gd` (sin ventana, 4 cuerpos × 5 clips × 8 instantes): fuente en reposo 0,00012° (límite 0,01°); brazos contra la fuente en la referencia 0,99° (límite 3°); deriva al animar máx. 0,0001° (límite 0,1°); pies al caminar máx. 30,9 mm (límite 45 mm); con la referencia en pose A da 58,5° (la prueba lo detecta, > 20°); cargar 120 ms; un fotograma 0,027 ms. **Limitación medida, sin límite:** sin IK, con las rodillas dobladas los pies flotan según las proporciones (sentarse: 52 mm el neutro, 168 mm el cuerpo alto); en un juego pasa igual (a `IDEAS.md`). Aprendido: fuera del árbol `Skeleton3D` no refresca la pose global, y en modo manual `seek` no mueve los huesos hasta `advance(0)`. `probar_acciones` +8. Pasan `probar_animaciones`, `probar_acciones`, `probar_ventana`, `probar_vista`, `probar_vista_estilo`, `probar_panel`, `probar_edicion`, `probar_acabado`, `probar_exportar`, `probar_update` y `probar_carga`; el proyecto arranca sin errores |
| 2026-11-16 | 5.2 | El responsable aprobó el 5.1 en la ventana (los 5 clips valen; más clips, cargar animaciones propias, suelo y anclaje de pies: a `IDEAS.md`, después del MVP). Poses extremas como datos: `poses` y `feet` en `datos/animaciones/humanoide.json` (giros en grados por hueso sobre los ejes del personaje; el de un hueso arrastra a sus hijos). Núcleo: `static_pose.gd` (`StaticPose.apply`: parte de la pose T, gira y luego mueve `Hips` para dejar el pie más bajo a su altura de la pose T; no toca la escala); `AnimationSet` gana `poses`, `feet`, `entries()` y `pose_turns()`. Interfaz: las 3 poses salen en la misma lista Animación, después de los clips; `BodyView.set_animation()` sirve para las dos cosas. Prueba nueva `probar_poses.gd` (sin ventana, 4 cuerpos, mide los huesos y no los números del archivo): brazos contra la vertical 5,00° (límite 10°) y manos 0,29–0,39 m sobre la cabeza; sentadilla: muslo contra la horizontal 3,7–5,8° (límite 10°), rodilla 109,5–112,0° (límite 100–120°), cadera baja 40–61 % (límite > 25 %); giro de tronco 45,00° (límite 43–47°) con los pies quietos (0,0002 mm); pie más bajo en el suelo (< 0,1 mm); sin pose, el giro medido es < 1° (la prueba distingue). Error mío corregido antes de cerrar: leía la pose de cada hueso después de girar a su padre (el giro se aplicaba dos veces; la prueba lo vio: 129° en vez de 45°). `probar_acciones` +3. Pasan `probar_poses`, `probar_acciones`, `probar_animaciones`, `probar_ventana`, `probar_vista`, `probar_vista_estilo`, `probar_panel`, `probar_edicion`, `probar_acabado` y `probar_exportar`; el proyecto arranca sin errores |
