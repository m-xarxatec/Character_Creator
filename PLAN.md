# PLAN — GameMolde (hasta el MVP)

> Paso a paso. Un paso cada vez y siempre con aprobación (ver `CLAUDE.md`).
> Lo que no es del MVP va a `IDEAS.md`.

**Estado actual:** Fase 3 · paso 3.5 pendiente
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

**Hecho cuando:** `datos/` está completa, versionada y probada.

---

## Fase 3 — Núcleo en Godot (sin interfaz)

- [x] 3.1 Cargar `datos/` y montar malla y esqueleto.
- [x] 3.2 Deslizadores de forma (*blend shapes*) con simetría. Comprobar que Godot calcula los mismos pesos que el script de Blender, incluidas las 81 correcciones.
- [x] 3.3 Deslizadores de proporción (escala uniforme de huesos).
- [x] 3.4 Reajuste de huesos con `articulaciones.json` (base + desplazamientos de cada forma) y *bind poses*.
- [ ] 3.5 Prenda base: el shader corta en 0,5 el color por vértice `garment` (degradado de 6 cm: borde recto en la malla completa; ya sigue al cuerpo sola), con un interruptor para mostrarla u ocultarla que también se guarda al exportar.
- [ ] 3.6 Exportar `.glb`: hornear, 4 influencias, anclajes como nodos vacíos y nombres humanoides. Preparar dos salidas para comparar: pose T horneada y pose A con la corrección de silueta de Godot. Al exportar, la escala de pose se hornea en la malla y en el reposo; prueba: todos los huesos del .glb con escala 1 y la malla igual que antes de hornear (< 0,1 mm). Horneado en CPU (skinning con los pesos, sin GPU), para exportar y probar sin ventana; prueba cruzada: CPU contra `bake_mesh_from_current_skeleton_pose()` con ventana, diferencia < 0,01 mm; cuando exista, pasar la prueba de malla del 3.3 a modo sin ventana. Al exportar, apoyar el personaje en el suelo: punto más bajo de los pies en y = 0.
- [ ] 3.7 Guardar y cargar presets en JSON.
- [ ] 3.8 Pruebas: 10 cuerpos aleatorios → exportar → reimportar → comparar.
- [ ] 3.9 Estilo ilustración: shader de sombra a dos tonos + contorno negro (grosor ajustable), dentro del núcleo.
- [ ] 3.10 Al exportar, el personaje sale con ese estilo listo para el juego (el `.glb` + el material de Godot).

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
| 2026-11-10 | — | Meta visual añadida al MVP: estilo ilustración con contorno (pasos 3.9, 3.10 y 4.6) |
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
