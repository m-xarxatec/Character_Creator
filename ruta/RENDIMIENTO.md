# RENDIMIENTO — medidas, presupuesto y optimizaciones

> Sesión de traspaso (2026-11-16).
> **Hoy no pude medir nada:** esta máquina (Windows) no tiene Godot ni Blender (`which godot blender` no encuentra ninguno; D16). Todas las cifras del §1.1 salen del registro de `PLAN.md` y de `GUIA_ESTILO.md` §7. Los comandos para repetirlas y para tomar las que faltan están en el §1.3.
> Los números de apartado de este documento (§1.2, §2, O1 a O10) se citan desde otras fichas: **no renumerar**.

---

## 1. Medidas de partida

### 1.1 Lo que ya está medido (PC del responsable, GTX 1650, Linux, Forward+)

| Qué | Medida | De dónde sale |
| --- | --- | --- |
| Fotograma al arrastrar un deslizador, peor caso (159 formas activas) | **0,69 ms** de media | Registro, paso 2.3 (`probar_rendimiento.gd`) |
| Reajuste de huesos (`SkeletonRefit.apply`) | 0,62 ms | Registro, paso 3.4 |
| Carga del maniquí en la interfaz (leer `cuerpo.glb` + preparar) | 695 ms | Registro, paso 4.2 (`probar_vista.gd`) |
| Horneado de malla en CPU (`MeshBaker`) | 46–204 ms por personaje | Registro, paso 3.6.1 |
| Textura de prenda (`GarmentTexture.bake`, 2048 px, CPU) | 1,5 s | Registro, paso 3.6.6 |
| `.glb` exportado | 1,4 MB | `GUIA_ESTILO.md` §7 |
| `datos/humana/cuerpo.glb` | 15,9 MB | `ls -l` |
| Biblioteca de animaciones de Quaternius | 7,6 MB | `ls -l` |
| Malla | 14.517 vértices, 26.756 triángulos, 53 huesos exportados, 1 material | `GUIA_ESTILO.md` §7 |
| `probar_aleatorios.gd` (10 personajes: construir, guardar, exportar, comprobar) | 70 s | Registro, paso 3.8 |

Lectura: en PC, **dibujar no es el problema** (0,69 ms de 16,7). El margen es de más de 20 veces. Los riesgos están en: (a) lo que se hace **al soltar** el deslizador (horneados en CPU de decenas a cientos de ms); (b) la **memoria** de las formas; (c) el móvil, donde nada está medido.

### 1.2 Lo que falta por medir

| Medida | Por qué importa | Cómo |
| --- | --- | --- |
| `CharacterUpdater.update()` completo (CPU) | Es lo que se ejecuta en cada movimiento del deslizador. Solo está medida una parte (0,62 ms) | Comando M2 |
| `StyleNormals.apply` y horneado sin textura | Es la pausa al soltar del paso 4.6 | Comando M3 |
| **Memoria de vídeo de las formas** | Estimación: 159 formas × 14.517 vértices × 16–32 bytes = **37–74 MB**. El tamaño real por vértice y forma en Godot 4.7 es **NO VERIFICADO** | Comando M4 |
| **Coste de una forma más** (MB por forma) | Decide cuántas formas de cara caben (O6) | Comando M4, con y sin formas |
| RAM del proceso con el editor abierto | Presupuesto del §2 | Comando M5 |
| Arranque del build (doble clic → maniquí visible) | Presupuesto del §2 | Ficha 7.1, punto 7 |
| Todo lo anterior en un Android de gama media | Decide D20 y el diseño de la Fase 15 | Ficha 8.5 |
| Con Mobile y Compatibility en PC | Elegir renderizador (A7) | Ficha 5.13 |

### 1.3 Comandos (para lanzar en la máquina Linux)

Todos desde la raíz del repositorio. `R=$(pwd)`. Si A2 está aplicado, `datos/` es `godot/datos/`.

**M1 — Fotograma al arrastrar (ya existe; necesita ventana):**
```sh
(ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s probar_rendimiento.gd -- "$R/datos/humana/cuerpo.glb" 2>&1 | grep -E 'FALLO|RESULTADO|ERROR|media|formas')
```
Con otro renderizador: añadir `--rendering-method mobile` o `--rendering-method gl_compatibility` antes de `--path`.

**M2, M3, M4 — Prueba nueva propuesta, `pruebas/godot/probar_medidas.gd`** (no existe; crearla es un paso con su propuesta; nivel simple). Debe imprimir, con el mismo formato `MEDIDA <nombre>: <valor>`:

| Línea | Cómo se mide |
| --- | --- |
| `MEDIDA update_ms` | Media y máximo de 200 llamadas a `CharacterUpdater.update(values, false)` cambiando un valor cada vez, con `Time.get_ticks_usec()` |
| `MEDIDA update_partes_ms` | Lo mismo, por separado: `ShapeWeights.weights` + `apply`, `SkeletonRefit.apply`, `Proportions.apply` |
| `MEDIDA horneado_ms` | `GlbExporter.build` sin textura (A5) |
| `MEDIDA normales_estilo_ms` | `StyleNormals.apply` |
| `MEDIDA textura_ms` | `GarmentTexture.bake` a 2048 y a 1024 px |
| `MEDIDA carga_ms` | `SpeciesData` completo, y aparte solo el `sha256` |
| `MEDIDA video_mb` | `Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)` y `RENDER_BUFFER_MEM_USED`, antes de cargar, tras cargar el cuerpo con formas y tras cargar una copia **sin** formas. La diferencia ÷ 159 = MB por forma |
| `MEDIDA ram_mb` | `OS.get_static_memory_usage()` en los mismos tres momentos |

Las líneas de tiempo valen con `--headless`. Las de `video_mb` necesitan ventana (sin ella no hay tarjeta). Comando:
```sh
(ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s probar_medidas.gd -- "$R" 2>&1 | grep -E 'MEDIDA|ERROR')
```

**M5 — RAM vista por el sistema, con el editor abierto:**
```sh
(ulimit -v 4000000; timeout 60 godot --path godot &) ; sleep 20 ; ps -o rss=,comm= -C godot | awk '{printf "MEDIDA ram_rss_mb: %.0f\n", $1/1024}'
```

**M6 — Tamaños:**
```sh
ls -l datos/humana/ | awk '{print $5, $9}' ; ls -l pruebas/godot/UAL1_Standard.glb | awk '{print $5}'
```

Las medidas se guardan en `ruta/medidas/<fecha>_<máquina>.md`, una tabla por máquina. Nunca se borran las viejas: sirven para ver si algo empeora.

---

## 2. Presupuesto propuesto

**Todo PROVISIONAL (D26):** se fija con la primera medida real en cada plataforma. «PC modesto» = portátil de 2018 con gráfica integrada (Intel UHD 620 o similar), 8 GB de RAM. «Android de gama media» = Adreno 619 o Mali-G57, 6 GB de RAM.

### 2.1 El editor

| Recurso | PC modesto | Android de gama media |
| --- | --- | --- |
| Fotograma al arrastrar un deslizador, media | ≤ 16,7 ms (60 fps) | ≤ 33 ms (30 fps) |
| Fotograma al arrastrar, p99 | ≤ 33 ms | ≤ 66 ms |
| Pausa al **soltar** el deslizador (horneados) | ≤ 100 ms sin que se note; ≤ 250 ms tolerable | ≤ 250 ms; por encima, en segundo plano |
| Fotograma al posar un personaje horneado | ≤ 8 ms | ≤ 16,7 ms |
| Arranque (lanzar → maniquí visible) | ≤ 3 s | ≤ 6 s |
| Abrir un proyecto | ≤ 1 s | ≤ 2 s |
| RAM del proceso | ≤ 600 MB | ≤ 500 MB en total (RAM + gráficos, línea TOTAL de `dumpsys meminfo`) |
| Memoria de vídeo | ≤ 300 MB | incluida en lo anterior |
| Tamaño de la descarga | ≤ 120 MB (`.zip`) | ≤ 80 MB (APK, una arquitectura) |
| Exportar un `.glb` (botón → archivo escrito) | ≤ 3 s | No aplica |
| Imagen de 4K (botón → PNG escrito) | ≤ 2 s | ≤ 4 s |

### 2.2 El personaje exportado

En línea con `GUIA_ESTILO.md` §7, cuyas cifras siguen como «PROPUESTA (pendiente de aprobar)». No las cambio; las repito para tenerlas juntas:

| Recurso | PC | Móvil |
| --- | --- | --- |
| Triángulos (cuerpo + pelo + ropa) | ≤ 40.000 | ≤ 15.000 (pide LOD: O8) |
| Huesos | ≤ 75 | ≤ 60 |
| Materiales | ≤ 4 | ≤ 2 |
| Textura mayor | 2048 px | 1024 px |
| Tamaño del `.glb` | ≤ 10 MB | ≤ 4 MB |

Hoy el cuerpo solo ya tiene 26.756 triángulos: **cumple PC y no cumple móvil**. Pelo y ropa dejan 13.244 triángulos de margen en PC. El semáforo de presupuesto (`IDEAS_AL_LIMITE.md`, H) enseña esto al usuario; el paso 5.14 lo pone en el informe.

---

## 3. Optimizaciones, por relación beneficio/coste

Regla: **ninguna se hace sin la medida que la justifica.** Cada una dice qué medir antes y después. Las que cambian el núcleo son un paso con propuesta.

| Código | Optimización | Beneficio | Coste | Cuándo |
| --- | --- | --- | --- | --- |
| **O1** | Separar «al arrastrar» de «al soltar» | Alto | S | 4.4–4.6 (ya previsto) |
| **O2** | Hornear sin textura cuando no se exporta (A5) | Alto: quita 1,5 s | S | 4.5 |
| **O3** | Trabajo pesado al soltar: aplazarlo, cancelarlo y, si hace falta, a un hilo | Alto | S → M | 4.6, si la medida pasa de 100 ms |
| **O4** | Cargar la especie una sola vez | Medio: 695 ms por carga | S | Fase 10 (varios personajes) |
| **O5** | No redibujar si nada cambia | Alto en móvil (batería y calor) | S | Fase 15; opcional en PC |
| **O6** | Presupuesto de formas: medir MB por forma y decidir | Alto: evita quedarse sin memoria | S (medir) | Antes del 9.2 |
| **O7** | El `sha256` solo en depuración o en segundo plano | Medio en móvil | S | Tras la medida de 8.5 |
| **O8** | LOD al exportar | Alto para el juego en móvil | M–L | Tras el MVP |
| **O9** | Contorno simplificado al mover en móvil | Medio | S | Fase 15, si `reposo_ms` no cumple |
| **O10** | Formas dispersas | Muy alto en memoria | XL | Solo si O6 lo exige (paso 16.4) |

### O1 — Qué se recalcula en cada fotograma y qué solo al soltar

| Momento | Qué se hace | Coste medido o estimado |
| --- | --- | --- |
| **En cada cambio del deslizador** (mientras se arrastra) | `CharacterUpdater.update`: pesos de formas (la GPU mezcla), reajuste de huesos, escala de Proporción | Menos de 2 ms en PC (0,62 ms medidos de una parte; el total, por medir con M2) |
| **Como máximo una vez por fotograma** | Si llegan 5 eventos de ratón en un fotograma, se aplica solo el último valor. Guardar el valor pendiente y aplicarlo en `_process` | Evita trabajo repetido con ratones de 1000 Hz |
| **Al soltar** | Normales de estilo (`StyleNormals`), malla estática del 4.6, entrada en el historial de Deshacer, miniatura del historial (14.8) | 46–204 ms de horneado + las normales (por medir con M3) |
| **Solo al exportar** | Textura de prenda (1,5 s), escritura del `.glb` y del `.tres` | 1,5–3 s; con indicador de «exportando» |
| **Nunca en el arrastre** | Leer archivos, `sha256`, crear nodos, crear materiales, `GLTFDocument` | — |

Medida: M2 antes y después. Prueba que lo vigila: contar llamadas a `update` por fotograma en `probar_panel.gd` (como máximo 1).

### O2 — Hornear sin textura

`GlbExporter.build(…, with_texture := true)` (A5, en la ficha 4.5). El banco de pruebas, el estudio y las miniaturas piden `false`. Medida: `horneado_ms` de M2 con y sin textura; la diferencia esperada es 1,5 s.

### O3 — La pausa al soltar

La ficha 4.6 pide parar si la pausa pasa de 250 ms. Opciones, de más barata a más cara. Se aplica la primera que cumpla el §2.1:

1. **Aplazar (S).** No hornear al soltar, sino 150 ms después, con un `Timer` de un disparo que se reinicia si el usuario vuelve a tocar un deslizador. Si encadena cambios, solo se hornea una vez.
2. **Hornear solo lo necesario (S).** La malla estática del 4.6 no necesita textura (O2) ni anclajes: solo vértices y normales. Llamar a `MeshBaker` directamente, no a `GlbExporter.build`.
3. **Repartir en fotogramas (M).** Las normales de estilo de la cabeza son un bucle por vértice: procesar N vértices por fotograma. La malla anterior se sigue viendo hasta acabar.
4. **Hilo de trabajo (M, nivel fuerte).** `WorkerThreadPool.add_task()` con los arrays de la malla **copiados** antes de lanzar; el hilo no toca nodos ni el esqueleto; al terminar, `call_deferred` para crear la `ArrayMesh` en el hilo principal. Si el usuario cambia algo mientras tanto, el resultado se descarta (contador de versión). Riesgos: acceso a `Skeleton3D` y a `Mesh` desde un hilo no es seguro; por eso se copian los datos antes. **No lo intenta un modelo simple.**

Medida: `normales_estilo_ms` y `horneado_ms` (M3), y el p99 de fotograma durante 10 ciclos de arrastrar y soltar.

### O4 — Cargar la especie una sola vez

Hoy cada carga vuelve a leer y analizar los 15,9 MB (695 ms). `SpeciesData` guarda la escena generada y la duplica para el segundo personaje (`ARQUITECTURA.md` §7). En la interfaz actual solo hay un personaje: no hace falta antes de la Fase 10. Medida: `carga_ms` de la segunda carga, que debe bajar a menos de 100 ms.

### O5 — No redibujar si nada cambia

`OS.low_processor_usage_mode = true`: Godot solo redibuja cuando la interfaz o la escena lo piden. Efecto: el editor en reposo baja a casi 0 % de procesador y de gráfica. Incompatible con animaciones continuas (banco de pruebas, física de pelo, luces animadas): se desactiva mientras duren. Medida: uso de procesador en reposo con `top` (PC) o temperatura y consumo en el móvil.

### O6 — Formas en la GPU o en la CPU, y cuántas caben

- **Hoy:** todas las formas viven en la GPU y la tarjeta las mezcla. Es lo que da los 0,69 ms. No hay que cambiarlo en PC.
- **El límite es la memoria**, no el tiempo: cada forma guarda datos para **todos** los vértices, también los que no mueve. Estimación del §1.2: entre 0,23 y 0,46 MB por forma.
- **Qué hacer:** medir MB por forma (M4). Con ese número: formas que caben = (presupuesto de vídeo − resto) ÷ MB por forma. Ejemplo con la estimación alta: 300 formas de cara añadidas = 139 MB más. Cabe en PC; en un Android de 500 MB en total, no.
- **Salidas, por orden de coste:** (1) cargar las formas de cara solo al editar la cara (dos mallas: cuerpo y cabeza con formas distintas; pide separar la cabeza: coste L); (2) en Android, abrir solo personajes ya horneados (`Platform.can("editar_cuerpo") = false`: coste 0); (3) formas dispersas (O10).
- **Formas en CPU:** mezclar en CPU 14.517 vértices × formas activas en GDScript cuesta decenas de ms por cambio (el horneado completo son 46–204 ms). No sirve para arrastrar. Solo sirve si se mezclan únicamente los vértices que cambian (O10).

### O7 — El `sha256` de `datos/`

16 MB de `sha256` en cada arranque. En PC son decenas de ms (por medir: `carga_ms` de M2 lo separa). En móvil, por medir en 8.5. Si pasa de 300 ms: comprobarlo solo en builds de depuración (`OS.is_debug_build()`), porque dentro de un `.pck` o un APK firmado los datos no cambian. **No se quita la comprobación** al cargar packs del usuario.

### O8 — LOD al exportar

- **Para qué:** el cuerpo (26.756 triángulos) no cumple el presupuesto de móvil (15.000).
- **Opción A (S, sin código):** al importar el `.glb` en Godot, el importador ya genera niveles de detalle automáticos (opción de importación «Generate LODs», activa por defecto). El juego los usa solo. Coste: una línea en el README. Límite: no reduce el archivo ni vale para otros motores.
- **Opción B (M–L, fuerte):** reducir en el editor antes de exportar, con `ImporterMesh.generate_lods()` (uso en ejecución fuera del editor: **NO VERIFICADO**) o con un algoritmo propio de colapso de aristas. Debe conservar: pesos (4, suma 1), color `garment`, normales de estilo y el borde de la prenda. Prueba: `probar_glb.gd` pasa con la malla reducida y la silueta difiere menos de X píxeles (herramienta del 5.11).
- **Opción C (L, en Blender):** una segunda malla base ligera en `datos/` (el «selector de polígonos» de `IDEAS.md`), con las formas transferidas. Mejor calidad; pide Blender y juicio visual.
- Recomendación: **A ya** (documentar), **C** cuando haya segunda base (16.3). B solo si alguien lo pide.

### O9 — Contorno en móvil

El contorno dibuja la malla dos veces. Si `reposo_ms` en el aparato no cumple: (1) apagar el contorno mientras se mueve la cámara o se posa y encenderlo al parar; (2) reducir la resolución de dibujo de la vista 3D (`Viewport.scaling_3d_scale = 0.75`) manteniendo la interfaz nítida. Medida: `reposo_ms` con y sin.

### O10 — Formas dispersas

Diseño en `ARQUITECTURA.md` §2.4. Las formas se guardan en CPU solo con los vértices que mueven; a la GPU suben como formas reales solo las del deslizador que se arrastra y sus correcciones; el resto se hornea en la base al soltar. Reduce la memoria de vídeo unas 10 veces o más. Cambia `SpeciesData`, `ShapeWeights`, `MeshBaker` y `exportar_datos.py`. **XL, nivel fuerte, y solo con una medida de O6 que lo exija.**

### Coste de luces, sombras y partículas en el estudio

Nada medido. Estimaciones y cómo medir (con el medidor de la ficha 8.5, añadiendo estos casos):

| Elemento | Coste esperado | Regla propuesta |
| --- | --- | --- |
| Luz direccional sin sombra | Casi nulo | Siempre disponible |
| Sombra de luz direccional | Una pasada más de la malla por cascada. Con 1 cascada (basta para un personaje): +30–50 % del coste de dibujo | 1 cascada, mapa de 2048 px en PC y 1024 px en móvil |
| Luz omni o foco sin sombra | Bajo en Forward+ y Mobile; una pasada extra por luz en Compatibility (**NO VERIFICADO**) | Máximo 4 luces en PC y 3 en Android (PROVISIONAL) |
| Sombra de luz omni | Cara: 6 caras de cubo (o 2 paraboloides) | Solo PC; como máximo 1 |
| Resplandor | Bajo–medio; depende de la resolución | Activable; apagado por defecto en móvil |
| Profundidad de campo | Medio–alto | Solo PC y solo al sacar la imagen, no en vivo |
| Partículas | Depende del número; `GPUParticles3D` en Compatibility **NO VERIFICADO** | Límite de 500 partículas por efecto en móvil |
| Física de muelles (pelo, ropa) | CPU: proporcional al número de huesos de muelle. 20 huesos: despreciable en PC; móvil **NO VERIFICADO** | Presupuesto de 40 huesos de muelle por personaje (PROVISIONAL) |
| Imagen de 8K | Memoria: 7680 × 4320 × 4 bytes = 133 MB por búfer, y hay varios | 8K solo en PC; 4096 px en Android |

---

## 4. Cómo no empeorar sin darse cuenta

1. `probar_rendimiento.gd` ya tiene límites (media 16,7 ms; p99 33,3 ms). Con 0,69 ms de media, un empeoramiento de 10 veces **no la haría saltar**. Propuesta (pide aprobación, regla 9): añadir una segunda comprobación relativa, «la media no supera el triple de la última medida anotada para esta máquina», leyendo la referencia de un archivo.
2. Cada paso que toque `CharacterUpdater`, `ShapeWeights`, `SkeletonRefit`, los shaders o la malla anota M1 y M2 en su fila del registro.
3. Al cerrar cada fase: tabla completa de medidas en `ruta/medidas/`, comparada con la anterior.
