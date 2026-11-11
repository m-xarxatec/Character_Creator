# PLAN — GameMolde (hasta el MVP)

> Paso a paso. Un paso cada vez y siempre con aprobación (ver `CLAUDE.md`).
> Lo que no es del MVP va a `IDEAS.md`.

**Estado actual:** Fase 3 · 3.12 hecho; pendiente de decidir qué hacer con su recomendación (cabeza estilizada propia)
**Leyenda:** `[ ]` pendiente · `[~]` en curso · `[x]` hecho

---

## Qué es el MVP

Un programa hecho con Godot, con una pestaña **Cuerpo** que permite:

- Editar un cuerpo humano por zonas (14 zonas) con deslizadores de **forma** y de **proporción**, con simetría.
- Ver el resultado en vivo en un maniquí 3D y probarlo con animaciones.
- Exportar un `.glb` listo para un juego de Godot: huesos reajustados, pesos correctos, perfil humanoide y puntos de anclaje.
- **Estilo ilustración** (anime 3D): sombra a dos tonos y contorno negro grueso, igual en el editor y en el juego.

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
- [ ] 3.7 Guardar y cargar presets en JSON.
- [ ] 3.8 Pruebas: 10 cuerpos aleatorios → exportar → reimportar → comparar.
- [ ] 3.9 `update_character()`: única función del núcleo que aplica, en este orden, formas → reajuste → pose base → escala de proporción. El resto del programa solo usa esta función. Prueba: llamarla dos veces seguidas da el mismo resultado.
- [ ] 3.10 Estilo ilustración: shader de sombra a dos tonos + contorno negro (grosor ajustable), dentro del núcleo.
- [ ] 3.11 Al exportar, el personaje sale con ese estilo listo para el juego (el `.glb` + el material de Godot).

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

---

## Fase 4 — Interfaz: pestaña Cuerpo

Según `diseno/maqueta-pestana-cuerpo.html`.

- [ ] 4.1 Ventana con pestañas (solo Cuerpo activa).
- [ ] 4.2 Vista 3D con cámara orbital y maniquí en vivo.
- [ ] 4.3 Zonas y deslizadores con etiqueta de tipo.
- [ ] 4.4 Simetría, deshacer y rehacer, y "restablecer zona". Aviso al activar la simetría si los lados difieren: lista de deslizadores distintos y botones Mantener como está (por defecto) / Igualar a la izquierda / Igualar a la derecha. Igualar cuenta como un solo cambio para Deshacer. Si los lados son iguales, no se muestra el aviso.
- [ ] 4.5 Botones Probar huesos y Exportar .glb conectados al núcleo, y botón para quitar o poner la prenda base.
- [ ] 4.6 El maniquí se ve con el estilo ilustración; control de grosor del contorno.

**Hecho cuando:** se crea y se exporta un personaje usando solo el ratón.

---

## Fase 5 — Banco de pruebas de huesos

- [ ] 5.1 Animaciones de prueba CC0: reposo, caminar, correr, atacar, sentarse.
- [ ] 5.2 Poses extremas: brazos arriba, sentadilla, giro de tronco.
- [ ] 5.3 Comprobaciones automáticas: pesos que suman 1, ≤ 4 influencias, 56 huesos humanoides, anclajes presentes.
- [ ] 5.4 Informe visible (bien / aviso / error) con la zona afectada.
- [ ] 5.5 Decidir la pose de exportación con las dos salidas del 3.6 (si gana la A, cambiar la regla de `CLAUDE.md`).
- [ ] 5.6 Prueba de anclaje real: espada en `socket_hand_r` durante la animación de atacar. Los anclajes heredan la escala de su hueso en el editor; la espada no debe escalar con la mano.
- [ ] 5.7 Animaciones de Quaternius con y sin Overwrite Axis. Valorar exportar los huesos con los ejes del perfil humanoide de Godot para que no haga falta Overwrite Axis. Medida del 3.6.3 para elegir entre T y A: con el codo a 90°, la variante T horneada difiere del personaje del editor puesto en T hasta 20,1 mm (cuerpo extremo) y 12,1 mm (al azar), en el codo; la variante A, 0,11 mm. Hornear una pose cambia cómo se dobla después (Blender hace lo mismo).
- [ ] 5.8 Revisar de cerca la variante T: (a) hombro y axila en la estocada, con el brazo sobre la cabeza (zona oscura en el costado: ¿sombra o la piel se hunde?); (b) la mano derecha en pose T en reposo, que parece plana de canto.

**Hecho cuando:** un cuerpo extremo muestra los avisos correctos.

---

## Fase 6 — Formas propias ("Por crear")

- [ ] 6.1 Esculpir con MakeTarget las formas que faltan (glúteos, pecho, cabeza chibi…).
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

| Fecha | Paso | Qué se hizo |
| --- | --- | --- |
| 2026-11-10 | — | Creación de PLAN.md, IDEAS.md, CLAUDE.md y la maqueta de la pestaña Cuerpo |
| 2026-11-10 | 0.1 / 0.3 | Blender 5.2.2 LTS anotado; carpetas creadas, `README.md` y `CREDITOS.md`; maqueta a `diseno/`, conceptos a `referencias/cuerpos/` |
| 2026-11-10 | 0.1 | MPFB 2.0.18 activado en Blender 5.2.2; prueba sin ventana: humano base de 19158 vértices |
| 2026-11-10 | 0.2 | Godot 4.7.2 estable instalado (`godot` en el PATH) |
| 2026-11-10 | — | Meta visual añadida al MVP: estilo ilustración con contorno (pasos 3.10, 3.11 (antes 3.9, 3.10) y 4.6) |
| 2026-11-10 | 0.1 | Pack "MakeHuman system assets" (CC0) instalado en MPFB; zips borrados |
| 2026-11-10 | 0.4 (parcial) | Humano MPFB + rig Game engine → `.glb` → Godot sin ventana: 53 huesos, 1,66 m, mira a +Z, 4 influencias que suman 1. Sale en pose A. Falta la parte a mano: BoneMap y animación |
| 2026-11-10 | 0.4 | BoneMap humanoide por script (53/56), animaciones de Quaternius sobre el humano: caminar, atacar y sentarse sin deformaciones. Hallazgo: la pose A rompe los brazos; hace falta pose T |
| 2026-11-10 | 0.5 | Licencia MIT para el editor (`LICENSE`) y nombre provisional GameMolde. Fase 0 terminada |
| 2026-11-10 | 1.1 | `blender/generar_cuerpo.py`: JSON (versión 1) → cuerpo MPFB con macros y targets, validado y con los pies en el suelo. 5 cuerpos de ejemplo y 23 pruebas |
| 2026-11-10 | 1.2 | `blender/poner_rig.py` (53 huesos, máx. 4 influencias, suman 1) y `blender/prenda_base.py` (top y short pintados, iguales en todos los cuerpos). Decidido: malla completa sin proxy y prenda pintada. 45 pruebas |
| 2026-11-10 | — | Requisito nuevo: la prenda base se puede quitar con un botón y exportar con o sin ella (pasos 3.5 y 4.5) |
| 2026-11-10 | 1.3 | `blender/limpiar_malla.py`: formas horneadas, sin malla auxiliar ni máscaras, solo grupos de huesos. Quedan 13.380 vértices y el cuerpo no se mueve ni 0,01 mm. 45 pruebas |
| 2026-11-10 | 1.4 | Exporta `.glb`: pose T (`pose_t.py`), nombres humanoides y export (`exportar_glb.py`), 4 anclajes (`anclajes.py`). Los 5 cuerpos pasan 110 comprobaciones y el neutro se anima bien en Godot sin corrección. Proyecto Godot de pruebas movido a `pruebas/godot/` |
| 2026-11-10 | 1.5 | `blender/render_vistas.py`: frente, perfil y espalda en una imagen (en `pruebas/**/capturas/`, fuera de git). Revisados los 5 cuerpos: pose T, prenda en su sitio, sin cortes ni huecos |
| 2026-11-10 | 1.6 | `pruebas/godot/probar_glb.gd`: Godot abre los 5 `.glb` sin errores; nombres y padres de los 53 huesos coinciden con el perfil humanoide, pose T, anclajes, pesos y prenda. 91 comprobaciones. Fase 1 terminada |
| 2026-11-10 | 2.1 | `datos/humana/deslizadores.csv`: 40 deslizadores en 14 zonas (33 Forma, 4 Proporción, 3 Por crear). Decidido: las macros se hornean como 2 formas (menos/más) sobre el cuerpo neutro; los largos son formas de MakeHuman y los huesos se reajustan (2.4); Proporción = escala uniforme de un hueso. Sobras del 0.4 borradas. 47 pruebas |
| 2026-11-10 | 2.2 | `datos/FORMATO.md`: carpeta por especie con manifiesto (`sha256`), `cuerpo.glb` en pose A con formas `_decr`/`_incr` y 4 huesos de anclaje, y `articulaciones.json` (base + desplazamientos). Macros: 2 formas cada una, pesos explicados. Proxy ligero para después. Pose de exportación: se decide en el 5.5 |
| 2026-11-10 | 2.3 | `blender/exportar_datos.py` genera `datos/humana/` (159 formas: 78 de la tabla + 81 correcciones de macros; 15,5 MB; mismos sha256 al repetir). Contra MPFB: 243 esquinas máx. 0,004 / media 0,001 mm; 242 cuerpos al azar máx. 0,025 / media 0,006 mm (1 saltado por el hueco de MPFB, reproducido en `pruebas/fase_2/hueco_mpfb/`); huesos 0,0008 mm y 0,000°. Fluido en Godot: 0,69 ms por fotograma con las 159 formas (GTX 1650). Arreglos: anclaje de cadera en pose A, sin el descarte de pesos < 0,01 de MPFB, `generar_cuerpo.py` pasa a 0,5 los valores en un hueco (con aviso en el log). Blender fijado en 5.2.2 |
| 2026-11-10 | 2.4 | `godot/addons/creador/bone_refit.gd` (primer archivo del núcleo, hecho solo desde FORMATO.md): cabeza, cola y giro de cada hueso. Contra MPFB en 6 cuerpos (neutro, atlético, mujer robusta, largo, al azar, extremo 0/1), 57 huesos con anclajes: máx. 0,0036 mm y 0,000° (giros reales de hasta 51° en los dedos del pie, sin problemas). Continuidad en 0,5 (0,49985 / 0,50015, 78 tríos): máx. 0,056 mm. Decidido: los deslizadores Forma con targets usan la regla de pesos de las macros. Referencia: `pruebas/fase_2/referencia_reajuste.py`; prueba: `pruebas/godot/probar_reajuste.gd` |
| 2026-11-10 | 3.1 | `godot/addons/creador/species_data.gd`: carga una especie de `datos/` (versión y sha256 de cada archivo; si algo falla, no carga nada) y monta malla y esqueleto con `GLTFDocument` en tiempo de ejecución. Prueba `pruebas/godot/probar_carga.gd`: 57 huesos, 159 formas, color `garment`, 13.380 vértices únicos, reposo del esqueleto = `articulaciones.json` (máx. 0,0011 mm), rechaza sha256 cambiado y versión 2. Nota en FORMATO.md sobre importar el `.csv` en Godot; añadidos 5.6 y la nota del 7.1 |
| 2026-11-10 | 3.2 | `godot/addons/creador/shape_weights.gd`: valores por deslizador y lado (`id`, `id_l`/`id_r`), pesos con la regla de FORMATO.md (81 correcciones por producto), `apply` en la malla y simetría al escribir. Decidido: fuera de rango se recorta a [0, 1]; NaN e infinito se rechazan. La regla de pesos en Python es ahora una sola, `shape_weights()` en `exportar_datos.py`, usada por la prueba del 2.3 y por la referencia (2.3 y 2.4 repetidas: mismos números). Prueba `pruebas/godot/probar_formas.gd`: pesos = Python en 483 casos (6 cuerpos, 234 de continuidad, 243 esquinas; las 81 correcciones entran), horneado contra MPFB en atlético y extremo máx. 0,0005 / media 0,0001 mm, simetría y valores fuera de rango |
| 2026-11-10 | 3.3 | `godot/addons/creador/proportions.gd`: 6 valores de Proporción → escala uniforme en la **pose** del hueso (0 → `decr`, 0,5 → 1, 1 → `incr`); guarda valores con `ShapeWeights.set_value`. Prueba `pruebas/godot/probar_proporciones.gd` (con ventana): fórmula, huesos e hijos (anclaje de mano incluido), malla horneada con altura × 1,15 (error 0,0000 mm; los pies bajan 0,084 mm porque `Root` está 0,56 mm bajo el suelo) y simetría. Aprendido: leer una pose en el fotograma en que la escena entra en el árbol deja al esqueleto sin ver cambios (esperar 2 fotogramas); `bake_mesh_from_current_skeleton_pose()` no funciona con `--headless` y lee la pose ya dibujada. Añadidos al 3.6: horneado en CPU y apoyar en el suelo |
| 2026-11-10 | 3.4 | `godot/addons/creador/skeleton_refit.gd`: reajusta reposo, pose (posición y giro) y *bind poses* de los 57 huesos con `bone_refit.gd`; la escala de Proporción no se toca. `species_data.gd` da a cada personaje su `Skin` propia y exige malla y esqueleto en el origen. Prueba `pruebas/godot/probar_reajuste_esqueleto.gd` (con ventana; sin ella se salta la malla horneada): reposo contra MPFB en 6 cuerpos máx. 0,0035 mm y 0,000°; reposo × *bind pose* = identidad (máx. 0,002 mm por los 32 bits de Godot; límite 0,01 mm); ida y vuelta exacta; dos personajes independientes; 0,62 ms por reajuste; malla quieta en reposo 0,0006 mm; codo a 90° en el cuerpo largo contra MPFB + esqueleto de Blender máx. 0,020 / media 0,001 mm. Aprendido: `bake_mesh_from_current_skeleton_pose()` no incluye las formas (se hornean antes) |
| 2026-11-11 | 3.5 | `godot/addons/creador/body.gdshader` (piel o prenda con corte en 0,5 del color `garment`, por píxel; sin luces hasta el 3.10) y `body_material.gd` (interruptor `show_garment`, parámetro del material). Prueba `pruebas/godot/probar_prenda.gd` (con ventana, imagen de 1024 px): 1.320 vértices de frente caen en un píxel de su color (0 errores), también con caderas y grasa al máximo y con la prenda oculta; solo dos colores, sin mezcla; el borde de la cintura varía 1 píxel (2 mm) en 16 cm (medida, sin límite fijado). Pasos de estilo renumerados a 3.10 y 3.11 por el nuevo 3.9 (`update_character()`); regla 9 en CLAUDE.md |
| 2026-11-11 | 3.6.1 | `godot/addons/creador/mesh_baker.gd`: horneado en CPU de vértices y normales (formas como forma − base, 4 pesos divididos por su suma, poses globales encadenadas aquí; sin tangentes). 46–204 ms por personaje. Prueba `pruebas/godot/probar_horneado.gd`: 4 casos contra el horneado de Godot (con ventana) máx. 0,0196 mm y 0,015°; límites aprobados 0,05 mm y 0,1° (el de Godot es el menos preciso: contra MPFB da 0,0199 mm y el de CPU 0,0064 mm). Las pruebas de malla del 3.3 y del 3.4 pasan a CPU y a `--headless`; límite del codo contra MPFB bajado a 0,05 mm. Límite del borde de la prenda (3.5): 2 px a 1024 px. Godot guarda los pesos en 16 bits (anotado en FORMATO.md). 3.6 dividido en 6 subpasos |
| 2026-11-11 | 3.6.2 | `godot/addons/creador/t_pose.gd`: pose T como pose (brazo, antebrazo y mano en línea hacia los lados, palma hacia abajo), porte a MIT de `blender/pose_t.py` con permiso del autor (comprobado: no trae código de MPFB). Parte siempre del reposo + escala de pose, así que repetirla da exactamente lo mismo. Prueba `pruebas/godot/probar_pose_t.gd` (sin ventana; neutro, extremo y al azar): horizontales y palma 0,0001° (límite 1°); manos sin deformar 0,0004 mm; contra la pose T de Blender, hombro y axila máx. 0,0037 / media 0,0006 mm y resto máx. 0,0063 / media 0,0004 mm (límite 0,05 mm). Contra el perfil humanoide de Godot: dirección igual en brazo, antebrazo y mano (clavícula 8,7°); los ejes propios de los huesos difieren hasta 93° (apuntado en el 5.7) |
| 2026-11-11 | 3.6.3 | `godot/addons/creador/character_baker.gd`: personaje nuevo sin formas ni escalas (reposo = pose global sin escala, *bind poses* nuevas, malla horneada en CPU), apoyado en y = 0, en variante A o T; el del editor no cambia. Prueba `pruebas/godot/probar_personaje_horneado.gd` (extremo y al azar con escalas, A y T): malla igual que antes de hornear máx. 0,0006 mm; suelo 0,000000 mm (límite 0,001); T + codo a 90° contra Blender con la pose T como reposo máx. 0,0135 mm (límite 0,1); A + codo contra el editor 0,111 mm (límite provisional 0,2 hasta el 2.5: pesos cruzados entre manos). Hallazgo: hornear una pose cambia cómo se dobla después (T horneada contra el editor en T: 12–20 mm en el codo; apuntado en el 5.7). Nueva `pruebas/fase_2/probar_cuatro_influencias.py`: el recorte a 4 pesos de la Fase 1 (608 vértices de torso y cuello tenían hasta 6) mueve como máximo 3,89 mm con el tronco a 45° (límite 5 mm). Godot guarda tangentes aunque no se le pasen. Añadido el paso 2.5 |
| 2026-11-11 | 2.5 | `blender/poner_rig.py`: `remove_cross_weights()` quita los pesos del lado contrario a más de 5 cm del centro, antes del recorte a 4 (regla en FORMATO.md). `datos/humana/` regenerado (nuevos sha256, `version` 1). Limpiados 11 vértices (dedos de los pies, piernas y mano; peso cruzado máx. 0,0051). La variante A con el codo a 90° pasa de 0,111 a 0,0008 mm; límite de vuelta a 0,1 mm. Todas las pruebas de Blender (fases 1 y 2, 2.3 contra MPFB y 4 influencias) y de Godot (9) pasan |
| 2026-11-11 | 3.6.4 | `godot/addons/creador/sockets.gd`: del personaje horneado saca uno con los 53 huesos de deformación y los 4 anclajes como nodo vacío dentro de un `BoneAttachment3D` pegado a su hueso; `Skin` sin anclajes e índices de hueso de la malla corregidos (los anclajes no son los últimos huesos: cambian 19.789 índices). Prueba `pruebas/godot/probar_anclajes.gd` (extremo y al azar con escalas, A y T): nombres y padres del perfil humanoide; anclajes en su sitio y con su giro (0,00000 mm, 0,0000°; límites 0,1 mm y 1°), escala 1, también con el codo a 90°; pesos en el hueso del mismo nombre; malla con el codo a 90° igual que antes (0,00000 mm; límite 0,01); un peso en un anclaje se rechaza. Desde hoy, Godot y Blender se lanzan con `ulimit -v` y `timeout` (el PC se colgó durante un experimento de exportación) |
| 2026-11-11 | 3.6.5 | `godot/addons/creador/glb_exporter.gd`: hornea, pasa los anclajes a nodos y escribe el `.glb` con `GLTFDocument` (Character → Armature → huesos, malla y anclajes, como los de Blender, para que valgan los mismos ajustes de importación). 1,4 MB; exportar dos veces da el mismo archivo. Pruebas sobre 4 archivos (neutro y al azar con escalas, T y A): `probar_exportar.gd` (al releer: 53 huesos máx. 0,0004 mm, anclajes 0,0003 mm y 0,000°, malla 0,00000 mm, 0 formas, 4 influencias, escala 1); `probar_glb.gd` con el nuevo `--pose-a`; `pruebas/fase_3/probar_glb_en_blender.py` (53 huesos, 4 vacíos hijos de su hueso, 1 malla); `pruebas/fase_3/probar_importador.sh` + `probar_importado.gd` (importador del editor en un proyecto vacío). Animaciones de Quaternius (capturas en `pruebas/capturas/exportado_t.png` y `_a.png`): la T se anima bien; la A rompe los brazos sin la corrección del importador (esperado, se valora en la Fase 5). Sin cuelgues: exportar un `BoneAttachment3D` con hijo funciona; el cuelgue era al leer un glTF sin malla ni piel (apuntado en IDEAS.md) |
| 2026-11-11 | 3.6.6 | Prenda fuera del editor con textura horneada (opción A; por caras el borde fallaba hasta 23 mm). `godot/addons/creador/garment_texture.gd`: dibuja la prenda con las UV en una imagen de 2048 px (1 píxel ≈ 0,9 mm en el borde), en CPU, con 8 px de margen en las costuras UV. `glb_exporter.gd`: material sin luces con esa textura (prenda oculta: sin textura, todo piel); +20 KB, 1,5 s. Hallazgo: la norma glTF multiplica el material por el color por vértice, y Blender lo hace: con `garment` en el RGB, la piel salía negra. En el `.glb`, `garment` va en el alfa y el RGB es blanco. `body_material.gd`: `get_color()` y `DEFAULTS` (con `--headless` Godot no lee los valores del shader). Pruebas: nueva `probar_prenda_exportada.gd` (con ventana, leído sin el addon: 0 vértices de otro color, visible y oculta; borde de la cintura 1 px = 2 mm, igual que en el editor); `probar_glb_en_blender.py` (textura 2048 px; 75.076 esquinas en su color en la textura; captura con Cycles en `pruebas/capturas/prenda_blender/`: 0 píxeles oscuros, y con el color de antes salían 20.423). `probar_exportar`, `probar_glb` (T y A), `probar_prenda` y el importador del editor siguen pasando |
| 2026-11-11 | 3.12 | Prueba de estilo. Núcleo: `toon.gdshader` (3 tonos con bordes suaves, sombra cálida, rim, sin brillo) y `outline.gdshader` (malla invertida como `next_pass`, grosor en píxeles). Prueba `pruebas/godot/probar_estilo.gd` con 3 presets + chibi fuera de rango (`pruebas/fase_3/estilo/*.json`) y ojos provisionales como calcomanía (`Decal`; las esferas no se ven tras los párpados de MakeHuman). Cabezas de alto: femenino 6,96, masculino 6,94, chibi 5,25, chibi fuera de rango 3,46 (con ×1,3 de cabeza no se llega a 2,5). Anatomía: bajar músculo y grasa ayuda poco; las normales suavizadas ×10 limpian el torso. Capturas y hoja en `pruebas/capturas/estilo/`. Recomendación: cabeza estilizada propia. Además (3.6.6): el `.glb` se queda con el color por vértice y la prueba comprueba que el material es OPAQUE |
