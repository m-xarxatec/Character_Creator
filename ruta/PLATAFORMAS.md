# PLATAFORMAS — Windows y Android

> Sesión de traspaso (2026-11-16). Estudio del proyecto tal como está en la rama `traspaso`.
> **«NO VERIFICADO»** = no pude comprobarlo hoy en la documentación de Godot 4.7 (no usé la red) ni ejecutándolo (esta máquina no tiene Godot). Lo que afirmo sin esa marca lo comprobé con `grep` en el repositorio o es comportamiento estable de Godot 4 documentado en la 4.4.
> Cada «NO VERIFICADO» tiene su comprobación dentro de una ficha de `pasos/`.

---

## 1. Dependencias en tiempo de ejecución

**Comprobado con `grep` sobre `godot/` (`*.gd`, `*.gdshader`, `*.tscn`, `project.godot`):**

- `OS.execute`, `OS.create_process`, `python`: **0 apariciones.**
- `blender` y `mpfb`: 1 aparición, en un comentario (`godot/addons/creador/t_pose.gd:9`).
- Conclusión: **el editor exportado no necesita Blender ni MPFB.** Solo preparan `datos/` (`blender/exportar_datos.py`).

**Lo que ata el programa a una máquina concreta:**

| Dónde | Qué pasa | Efecto | Arreglo |
| --- | --- | --- | --- |
| `godot/app/body_view.gd:86-88` | Busca `datos/` dos carpetas por encima del script con `globalize_path` | En un programa exportado esa ruta no existe: el editor arranca con un mensaje de error | Ficha A2 |
| `datos/humana/*.json`, `*.csv` | El núcleo comprueba el `sha256` (`species_data.gd:43`). Git para Windows convierte los finales de línea si `core.autocrlf=true` (su valor habitual al instalar) | El `sha256` cambia y la especie no carga | Ficha A1. Aquí `core.autocrlf=false` y los 4 `sha256` coinciden (comprobado hoy) |
| `*.glb` con Git LFS (`.gitattributes`) | Sin `git lfs` instalado, `cuerpo.glb` es un puntero de texto de 130 bytes | La especie no carga | Requisito en el README (7.2) |
| Pruebas: `ulimit -v` | En Git Bash de Windows `ulimit -v` no limita la memoria (**NO VERIFICADO** qué imprime) | Las pruebas se lanzan sin límite de memoria | En Windows, usar solo `timeout`. Ficha 8.1 |
| `pruebas/fase_3/*.sh` (2 archivos) | Necesitan un shell POSIX | En Windows solo con Git Bash | Ficha 8.1 |
| `CLAUDE.md`: «snap», `blender -b` | Solo preparación de datos | Ninguno en ejecución | — |

**Separadores y mayúsculas:**

- El código usa `path_join` y `/` en todas partes; no hay ninguna `\` en rutas (comprobado). Godot acepta `/` en Windows.
- Todos los archivos de `godot/` y `datos/humana/` están en minúsculas (el único con mayúsculas es `datos/FORMATO.md`, que no se carga). Los 26 `preload` usan el nombre exacto. Windows no distingue mayúsculas; **Linux, Android y el `.pck` sí**: un `preload("Toon.gdshader")` funcionaría en Windows y fallaría en el build. Regla para los modelos: nombres de archivo siempre en minúsculas.
- Las pruebas cargan la interfaz por ruta absoluta desde otro proyecto (`probar_ventana.gd:11-12`). Funciona mientras la interfaz no use recursos importados; ver A6 en `ARQUITECTURA.md` §9.

---

## 2. Dónde vive `datos/` en el programa exportado

| Opción | Linux y Windows | Android | Plugin en el juego de otro | Problemas |
| --- | --- | --- | --- | --- |
| **a) Dentro del `.pck`** (`res://datos/`) | Sí | Sí (el `.pck` va dentro del APK) | Sí | Hay que evitar que Godot importe los `.glb` y `.csv` |
| b) Junto al ejecutable | Sí | **No existe** | No | Dos cosas que distribuir; el usuario puede borrarla |
| c) En `user://` | Sí, copiándola en el primer arranque | Sí, copiándola | No | 16 MB duplicados y lógica de «¿está copiada y al día?» |

**Recomendación: a)**, con `user://` solo para lo que crea el usuario (presets, proyectos, packs propios). Es la única opción que vale igual en las tres plataformas (D5).

**Las trampas, una por una:**

1. **Godot importa los `.csv` como traducciones.** Ya lo avisa `datos/FORMATO.md`. Arreglo: importar `deslizadores.csv` como **«Keep File (exported as is)»**. Eso crea un `deslizadores.csv.import` con el importador `keep` y el archivo entra en el `.pck` tal cual. Formato exacto de ese `.import`: **NO VERIFICADO**; se genera desde el editor (pestaña Importar) y se guarda en git lo que escriba.
2. **Godot importaría `cuerpo.glb` como escena** (15,9 MB y 159 formas: tarda, y duplica el tamaño en `.godot/`). Mismo arreglo: «Keep File».
3. **Los `.json` no son recursos importados.** Que entren solos en el `.pck` con «Exportar todos los recursos»: **NO VERIFICADO**. Arreglo seguro: filtro de inclusión en el preset de exportación: `include_filter="datos/*"`.
4. **`GLTFDocument` tiene que leer desde `res://` dentro del `.pck`.** `append_from_file("res://datos/humana/cuerpo.glb", state)` usa `FileAccess`, que lee dentro del `.pck` (**NO VERIFICADO** con un archivo «keep»). Plan B, seguro: `var bytes := FileAccess.get_file_as_bytes(path)` y `document.append_from_buffer(bytes, "", state)`. Vale porque el `.glb` lleva todo dentro (sin archivos externos).
5. **`FileAccess.get_sha256("res://…")` dentro del `.pck`:** **NO VERIFICADO**. Plan B: `get_file_as_bytes` + `HashingContext`.
6. **Coste del `sha256` en cada arranque:** 16 MB. En PC, decenas de ms; en móvil, a medir (ficha 8.5 o 15.1). Si pesa, se comprueba solo en builds de depuración (`OS.is_debug_build()`).

La ficha A2 incluye una prueba que carga la especie **desde un `.pck` real**; resuelve los cuatro «NO VERIFICADO» de golpe.

---

## 3. Renderizador

**Hoy:** `godot/project.godot` no fija ninguno. Valor por defecto de Godot 4: `forward_plus` en escritorio y `mobile` en plataformas móviles (el ajuste `rendering/renderer/rendering_method.mobile`). Todas las capturas aprobadas se hicieron con Forward+ en una GTX 1650.

| | Forward+ | Mobile | Compatibility (OpenGL) |
| --- | --- | --- | --- |
| API | Vulkan / D3D12 | Vulkan / D3D12 | OpenGL 3.3 / ES 3.0 |
| `light()` del toon (`toon.gdshader:40`) | Sí | Sí | **NO VERIFICADO** (espero que sí) |
| Contorno como `next_pass` con `cull_front` y `VIEWPORT_SIZE` | Sí | Sí | **NO VERIFICADO** (espero que sí) |
| Luces por malla | Muchas (por clústeres) | Límite por malla (8 omni + 8 foco: **NO VERIFICADO** en 4.7) | Pocas; cada luz extra cuesta una pasada (**NO VERIFICADO**) |
| Formas en la GPU | Shader de cómputo | Shader de cómputo | Varias pasadas, una por forma activa (**NO VERIFICADO**) |
| `Decal` (los ojos provisionales de `probar_estilo.gd`) | Sí | Sí | **No** |
| Resplandor, profundidad de campo | Sí | Sí, más simples | Resplandor sí; profundidad de campo: **NO VERIFICADO** |
| Color | HDR | HDR de menos precisión | Sin HDR; el borde de los tonos puede moverse algo |
| Fondo transparente en `SubViewport` | Sí | Sí | Sí |
| Para quién | PC con tarjeta dedicada | Móvil de gama media y PC con gráfica integrada | Móvil antiguo y PC viejo |

**Qué usar:**

| Plataforma | Renderizador | Motivo |
| --- | --- | --- |
| Linux y Windows | **Forward+** | Es con el que se aprobó el aspecto. Si el 5.13 demuestra que Mobile da la misma imagen, pasar a Mobile ahorra en gráficas integradas. |
| Android | **Mobile** | Permite los efectos de foto. Si el aparato no tiene Vulkan, Godot puede caer a Compatibility (`rendering/rendering_device/fallback_to_opengl3`: **NO VERIFICADO**). Por eso el toon debe verse bien en los tres. |

**Enlace con el paso 5.13:** ese paso es la puerta. Su ficha pide lanzar la misma captura con `--rendering-method forward_plus`, `mobile` y `gl_compatibility` y comparar con la herramienta del 5.11. Después se fija el renderizador en `project.godot` (A7). **Los ojos de la Fase 9 no pueden ser `Decal`**: no existen en Compatibility y ya se deformaban en tres cuartos (`IDEAS.md`).

---

## 4. Guardar, abrir y compartir archivos

| | Linux y Windows | Android |
| --- | --- | --- |
| Carpeta propia del programa | `user://` = carpeta de datos del usuario (`%APPDATA%\Godot\app_userdata\GameMolde` en Windows) | `user://` = almacenamiento interno de la app; sin permisos |
| Elegir dónde guardar | `FileDialog` con `access = ACCESS_FILESYSTEM` y `use_native_dialog = true` (diálogo del sistema) | Diálogo nativo con el selector de documentos del sistema: **NO VERIFICADO** en 4.7 (creo que llegó en 4.4). Sin él, el `FileDialog` de Godot solo ve las carpetas de la app |
| Escribir en la galería o en Documentos | Sin restricciones | Desde Android 10, el almacenamiento compartido exige el selector del sistema o MediaStore. `OS.get_system_dir(…)` tiene un argumento `shared_storage`; su efecto real por versión de Android: **NO VERIFICADO** |
| Menú «Compartir» | No aplica | **No hay API en Godot.** Hace falta un plugin de Android y, con él, la compilación con Gradle (D22) |
| Abrir un `.gmolde` tocándolo desde otra app | Asociación de archivo: opcional | Filtro de *intent* en el manifiesto: pide Gradle. Para más adelante |
| Portapapeles | `DisplayServer.clipboard_set` / `clipboard_get` | Igual. Es la vía barata para el **código de personaje** |

**Camino propuesto en Android, por orden:** (1) guardar en `user://` y mostrar una galería propia dentro de la app; (2) «Guardar en…» con el selector del sistema; (3) solo si se pide, el plugin de compartir.

**Windows, cosas a probar (ficha 8.3):** ruta con espacios y tildes (`C:\Users\José Pérez\…`), ruta de más de 260 caracteres, carpeta sin permiso de escritura (mensaje claro, no silencio) y que `GlbExporter.save` escriba **los dos** archivos (`.glb` y `.tres`, `glb_exporter.gd:82`).

---

## 5. Estudio en Android

### 5.1 Coste de mostrar y posar

Medido en PC (registro del PLAN, GTX 1650): **0,69 ms por fotograma** con las 159 formas activas, 14.517 vértices y 26.756 triángulos.

Estimaciones para gama media (Adreno 619 o Mali-G57, 6 GB de RAM). **Son estimaciones, no medidas:**

| Caso | Qué trabaja | Estimación | Cómo medirlo |
| --- | --- | --- | --- |
| Posar un personaje **horneado** | 14.517 vértices con 4 pesos, 53 huesos, 2 pasadas (toon + contorno) | 2–4 ms por fotograma: holgado para 60 fps | Ficha 15.1 |
| Editar con deslizadores (personaje **vivo**) | Lo anterior + las formas activas (10–40 con un personaje normal; 159 en el peor caso) | 5–15 ms normal; el peor caso puede pasar de 33 ms | `probar_rendimiento.gd` en el aparato |
| Dos personajes horneados + 3 luces | El doble de lo primero | 5–10 ms | Ficha 15.6 |

El contorno dibuja la malla dos veces. Si falta rendimiento en móvil, es lo primero que se puede simplificar (opción «sin contorno al mover»).

### 5.2 Memoria

| Qué | Estimación | Nota |
| --- | --- | --- |
| Formas en la GPU | 159 × 14.517 × 16–32 bytes = **37–74 MB** | El tamaño por vértice y forma es **NO VERIFICADO**. Se mide con `Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)` (ver `RENDIMIENTO.md` §1.2) |
| Personaje horneado | Menos de 2 MB de malla + la textura | — |
| Textura de prenda de 2048 px | 16 MB sin comprimir | En el estudio no hace falta: el toon usa el color por vértice |
| Motor de Godot en Android | 60–100 MB de base (**NO VERIFICADO**) | — |

Consecuencia de diseño: **en Android solo hay un personaje vivo, y solo mientras se edita.** Al entrar en el estudio se hornea y se libera el vivo. Es la regla del §0 de `ARQUITECTURA.md`.

### 5.3 Gestos táctiles

| Gesto | Acción | Cómo |
| --- | --- | --- |
| Un dedo arrastra en vacío | Girar la cámara | `InputEventScreenDrag` → `OrbitCamera.rotate_by(event.relative)` (la función ya existe) |
| Dos dedos se separan o se juntan | Acercar o alejar | Distancia entre los dos `InputEventScreenDrag` (índices 0 y 1) → `zoom_by` |
| Dos dedos arrastran juntos | Mover la vista | Media del movimiento de los dos dedos → función nueva `pan_by` |
| Un dedo sobre un hueso o tirador | Posar | Selección por distancia en pantalla al hueso más cercano (`Camera3D.unproject_position`), no por física |
| Doble toque | Centrar en ese punto | Mismo rayo del acople (`ARQUITECTURA.md` §4) |

Decisión técnica: calcular el pellizco **a mano** con los dos toques, en vez de usar `InputEventMagnifyGesture`, porque su emisión en Android depende de un ajuste del proyecto (**NO VERIFICADO**) y a mano es igual en todos los aparatos. En el PC se prueba con `input_devices/pointing/emulate_touch_from_mouse`.

Los tiradores para el dedo necesitan al menos 48 px de pantalla. La interfaz del estudio en móvil es otra disposición (paneles abajo), no la del PC encogida.

### 5.4 Tamaño del APK y firma

- **Tamaño (estimación, NO VERIFICADO):** plantilla de Godot para `arm64-v8a`, 25–35 MB + `datos/` (15,9 MB; comprimida dentro del APK, quizá la mitad) + animaciones (la biblioteca de Quaternius entera pesa 7,6 MB: D12) = **45–65 MB** con una sola arquitectura. Se mide en la ficha 8.5 o 15.1.
- **Firma:** para probar vale el almacén de claves de depuración (lo crea `keytool`, del JDK). Para publicar hace falta uno de publicación, **que guardas tú** y que no entra nunca en git. Para Google Play: formato AAB y nivel de API mínimo que cambia cada año (**NO VERIFICADO** el vigente). Fuera de Play: APK firmado e instalación manual.
- **Herramientas (D21):** JDK 17, SDK de Android (`platform-tools`, `build-tools`, una plataforma) y las plantillas de exportación de Godot 4.7.2. Versiones exactas que pide Godot 4.7: **NO VERIFICADO**. Todo exige red e instalación: requiere tu OK.

### 5.5 Qué funciones del PC se quitan

Exportar `.glb` y VRM, banco de pruebas de huesos, importar piezas propias, escultura libre, generación de packs y resoluciones por encima de 4096 px. Tabla completa en `ARQUITECTURA.md` §8.

### 5.6 ¿Deslizadores en Android? Decisión: **sí**, condicionada a una medida

Motivos:

1. **El móvil tiene que ejecutar el núcleo de todos modos.** El proyecto compartido guarda valores, no mallas (`ARQUITECTURA.md` §1). Para abrir un personaje, Android carga `datos/`, aplica las formas y hornea. Dejar mover los deslizadores no añade código al núcleo: solo interfaz.
2. El coste por fotograma estimado (5–15 ms) cabe en 30 fps. El coste real de un cambio (`CharacterUpdater.update`) son unos pocos ms de CPU en PC (0,62 ms el reajuste, medido); en móvil, quizá 10 veces más: sigue cabiendo.
3. El riesgo es la **memoria** (37–74 MB de formas), no la velocidad. Se controla con «un solo personaje vivo».

Condición: medido en un aparato de gama media con `probar_rendimiento.gd`, **media ≤ 33 ms y p99 ≤ 66 ms**, y la app no supera el presupuesto de memoria de `RENDIMIENTO.md` §2. Si falla, `Platform.can("editar_cuerpo")` devuelve `false` en Android y el móvil solo abre personajes hechos en el PC.

En Android la edición es **más simple**: mismo panel, sin banco de pruebas y sin exportación.

### 5.7 Validación de la decisión «Android = estudio»

La decisión es buena: evita en el móvil lo más frágil (exportación, diálogos de archivos, comparación con Blender). No veo ningún problema serio. Tres avisos:

1. «El mismo proyecto de Godot» obliga a que `datos/` viva dentro del `.pck` (D5). Es el único cambio estructural, y es barato si se hace antes del 7.1.
2. La física de pelo y ropa en el estudio (`SpringBoneSimulator3D`) en Compatibility o Mobile: es CPU, no depende del renderizador; coste en móvil **NO VERIFICADO**.
3. Sin plugin, «sacar imágenes» en Android significa guardarlas donde diga el selector del sistema o dentro de la app. Compartir directamente llega después (D22).

---

## 6. Pasos concretos

Están escritos como fichas en `pasos/`:

| Ficha | Qué hace |
| --- | --- |
| `A1_gitattributes.md` | Finales de línea de `datos/` |
| `A2_datos_en_el_proyecto.md` | `datos/` dentro del proyecto, «Keep File», localizador único y prueba desde un `.pck` |
| `7.1_builds_linux.md` | `export_presets.cfg` (Linux), plantillas y build |
| `8.1_pruebas_en_windows.md` | Pasar las pruebas sin ventana en Windows |
| `8.2_build_windows.md` | Preset de Windows y build cruzado desde Linux |
| `8.3_archivos_en_windows.md` | Diálogos, rutas y nombres |
| `8.4_paquete_windows.md` | `.zip`, prueba en limpio y aviso de SmartScreen |
| `8.5_apk_de_humo.md` | Herramientas de Android, APK mínimo y medidas |
| `15_android.md` | Resumen de la fase del estudio en Android |
