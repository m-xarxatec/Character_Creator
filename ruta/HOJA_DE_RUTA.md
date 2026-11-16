# HOJA DE RUTA — GameMolde, del MVP al límite

> Sesión de traspaso (2026-11-16, modelo Fable). Es una **propuesta**: nada de esto entra en `PLAN.md` sin aprobación.
> Documentos hermanos: `ARQUITECTURA.md`, `PLATAFORMAS.md`, `RENDIMIENTO.md`, `IDEAS_AL_LIMITE.md`, `DECISIONES.md`, `GUIA_MODELOS.md` y las fichas de `pasos/`.
> Niveles de modelo: **simple** (sigue una ficha), **medio** (toma decisiones locales), **fuerte** (matemática 3D, formato o arquitectura; un modelo sencillo no debe intentarlo solo).

---

## 1. Estado real frente a `PLAN.md`

1. Fases 0 a 3 cerradas (revisor: APTO CON RESERVAS el 2026-11-14). El núcleo (`godot/addons/creador/`, 17 archivos, unas 1.300 líneas) carga la especie, aplica formas, reajusta huesos, hornea y exporta `.glb` + `.tres`.
2. Fase 4: hechos 4.1 a 4.3 (ventana, vista 3D con cámara orbital y panel de deslizadores). El siguiente paso es el **4.4**. Coincide con la línea «Estado actual» del PLAN.
3. El editor todavía no deshace, no exporta desde la interfaz, no guarda presets desde la interfaz y no muestra las normales de estilo en vivo. `project.godot` no fija renderizador ni tiene `export_presets.cfg`.
4. Reservas abiertas del revisor que siguen vivas: borde dentado de la prenda con el material del `.glb` sin el `.tres`, dedos en el muslo al sentarse (5.10), 762 caras de la cabeza con la normal contraria, `TANGENT` en el `.glb`.
5. **No pude ejecutar pruebas hoy:** esta máquina es Windows y no tiene Godot ni Blender (D16). Todas las medidas de `ruta/` salen del registro del PLAN; los comandos para repetirlas están en `RENDIMIENTO.md`.

---

## 2. Tabla de huecos

Estado: **Hecho** · **MVP** (pendiente, en `PLAN.md`) · **IDEAS** (apuntado en `IDEAS.md`) · **Falta** (no está en ningún sitio).

| Función | Estado | Enfoque técnico en Godot 4.7 | Assets: origen y licencia | Riesgo | Tam. | Depende de | Nivel |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Cuerpo por zonas, en vivo | Hecho | Formas en GPU + `CharacterUpdater` | MakeHuman, CC0 | Bajo | — | — | — |
| Simetría, Deshacer, restablecer | MVP 4.4 | Historial por copias del estado (`ValueHistory`), no `UndoRedo` | — | Bajo | M | 4.3 | medio |
| Exportar `.glb` desde la interfaz | MVP 4.5 | `FileDialog` + `GlbExporter.save` | — | Bajo | S | 4.4 | simple |
| Estilo en vivo (normales) | MVP 4.6 | Malla estática horneada al soltar (`StyledMesh`) | — | Medio (salto visual, D6) | M | 4.5 | medio |
| Panel Acabado y preset v2 | MVP 4.7 | `BodyMaterial.set_param`, `Preset.migrate` | — | Bajo | M | 4.4 | medio |
| Banco de pruebas de huesos | MVP F5 | Personaje horneado + copia de pose en mundo (`WorldPose`) | Quaternius UAL, CC0 | **Alto** (retargeting) | L | 4.5 | fuerte (5.1, 5.7, 5.10); resto medio |
| Formas «Por crear» | MVP F6 | Targets propios por script → `exportar_datos.py` | Propios, CC0 | Medio (juicio visual) | L | Blender + MPFB en Linux | fuerte |
| Builds de Linux | MVP 7.1 | `export_presets.cfg`, `datos/` dentro del `.pck` | — | Medio | M | A2 | medio |
| Builds de Windows | Falta (el PLAN dice «si se decide»; ya está decidido) | Exportación cruzada desde Linux; pruebas en Windows | — | Medio | M | 7.1 | medio |
| Cara: deslizadores por rasgo | IDEAS | Más filas en `deslizadores.csv` con targets de cara de MakeHuman | MakeHuman, CC0 | Medio (memoria de formas) | M | Blender | medio |
| Ojos e iris intercambiables | IDEAS | Malla de ojo propia + shader de iris por parámetros (no `Decal`) | Propios | **Alto** (valle inquietante) | L | Cara | fuerte |
| Expresiones y visemas | IDEAS | Formas; antes hay que arreglar las bolsas de boca y ojos | MakeHuman (por comprobar) o propias | Alto | L | Ojos | fuerte |
| Formato de proyecto compartido | Falta | JSON `.gmolde` con bloques versionados (`ProjectFile`) | — | Medio | M | Preset v2 | fuerte (diseño hecho en `ARQUITECTURA.md`); implementarlo, medio |
| Estudio: posar (FK) | Falta | Gizmo de giro por hueso sobre `WorldPose` | — | Medio | L | F5 | medio |
| Estudio: posar con IK | Falta | IK de dos huesos propia en GDScript (los nodos de IK nuevos: **NO VERIFICADO**) | — | Alto | L | FK | fuerte |
| Estudio: cámara y luces | Falta | Ampliar `orbit_camera.gd`; luces como datos | — | Bajo | M | Proyecto | simple–medio |
| Imágenes PNG, transparencia, 4K | Falta | `SubViewport.transparent_bg`, tamaño propio, `save_png` | — | Bajo | S | Estudio | simple |
| Hoja de giro | Falta | 4–8 capturas en una `Image` | — | Bajo | S | PNG | simple |
| Modos de render (contorno, silueta…) | Falta | `uniform int modo` en `toon.gdshader` | — | Bajo | S | PNG | medio |
| Pelo como piezas | IDEAS | Piezas `.glb` en `Head` | Quaternius UBC, CC0; propias | Medio | M | Sistema de piezas | medio |
| Pelo con física | IDEAS | `SpringBoneSimulator3D` (existe desde 4.4) | — | Medio | M | Pelo | medio |
| Pincel de mechones | IDEAS | — | — | Muy alto | XL | — | No hacer (§4) |
| Ropa que sigue al cuerpo | IDEAS | Formas transferidas al crear el pack; en ejecución, mismos pesos de forma | MakeHuman, CC0 | Alto | XL | Sistema de piezas | fuerte |
| Ocultar piel bajo la ropa | IDEAS | Máscara por vértice + `discard`; al exportar se borran las caras | — | Medio | M | Ropa | medio |
| Accesorios en anclajes | IDEAS | `BoneAttachment3D` en cualquier hueso | Propios, CC0 | Bajo | M | Sistema de piezas | medio |
| Sistema de piezas y packs | IDEAS | Carpeta + ficha JSON + miniatura; `GLTFDocument` en ejecución | — | Medio | L | Proyecto | fuerte (diseño hecho); implementarlo, medio |
| Estilos como datos | IDEAS | JSON → `BodyMaterial` | Propios | Bajo | S | 4.7 | simple |
| Interfaz con estilo propio | IDEAS | `Theme` de Godot según `diseno/` | Fuentes OFL (decisión) | Bajo | M | — | medio |
| Miniaturas de presets | Falta | `SubViewport` pequeño → PNG en `user://` | — | Bajo | S | Proyecto | simple |
| Android (estudio) | IDEAS («Android (tablet)») | Mismo proyecto, etiquetas de plataforma | — | **Alto** (aparatos reales) | XL | Estudio, A2 | fuerte al empezar; después medio |
| Especies | IDEAS | Otra carpeta en `datos/`; el manifiesto declara huesos y capacidades | Propias o CC0 | Alto | XL | Auditoría de especie | fuerte |
| Huesos largo/grosor, asimetría | Falta | Escala no heredada en las *bind poses* (`ARQUITECTURA.md` §2) | — | Medio | M | — | fuerte |
| Escultura libre | Falta | Deltas dispersos en reposo; necesita la capa de CPU | — | Muy alto | XL | Formas dispersas | fuerte |
| VRM 1.0 | IDEAS | Extensiones glTF propias o `godot-vrm` (D24) | — | Alto | L | Cara, Pelo | fuerte |

---

## 3. Fases después del MVP

Orden propuesto (D25). Cambios respecto al orden orientativo: (1) el formato de proyecto va **dentro** de la fase del estudio, antes que Pelo, porque todo lo demás guarda en él; (2) propongo un **APK de humo** justo después de Windows (8.5), solo para medir.

Cada pestaña nueva empieza con una rebanada vertical (★): datos → núcleo → interfaz → exportación → prueba.

### Fase 8 — Windows (fichas detalladas en `pasos/8.*`)

- 8.1 Pasar en Windows todas las pruebas sin ventana y anotar las diferencias.
- 8.2 `export_presets.cfg` de Windows y build desde Linux.
- 8.3 Diálogos de archivo, rutas con espacios y tildes, y mayúsculas en los nombres.
- 8.4 Paquete `.zip`, prueba en un Windows limpio y aviso de SmartScreen en el README.
- 8.5 (Opcional, D21) APK de humo: abre, carga el maniquí y mide.

**Hecho cuando:** alguien descarga el `.zip` en Windows, crea un personaje y exporta un `.glb` que pasa `probar_glb.gd`.

### Fase 9 — Cara y ojos

- ★ 9.1 Mostrar la zona Cara con las 5 formas anime ya existentes, de punta a punta (panel → preset → `.glb` → prueba). Tamaño S.
- 9.2 Deslizadores por rasgo: filas nuevas con targets de cara de MakeHuman (CC0). Medir la memoria por forma antes (ver `RENDIMIENTO.md` O6).
- 9.3 Los 3 huesos que faltan del perfil (ojos y mandíbula; D10).
- 9.4 Ojos nuevos (sin `Decal`): malla propia y shader de iris con parámetros (color, pupila, brillo).
- 9.5 Iris intercambiables como estilos de datos; cejas y pestañas.
- 9.6 Arreglar las bolsas de boca y ojos aplastadas (hasta 58 mm; `IDEAS.md`).
- 9.7 Expresiones (alegría, enfado, tristeza, sorpresa, parpadeo). 9.8 Visemas (A, I, U, E, O).

**Hecho cuando:** un personaje con cara propia, ojos con iris elegido y 5 expresiones se exporta y las expresiones se ven en un proyecto de Godot sin el addon.

### Fase 10 — Proyecto compartido y estudio de poses y fotos

- 10.1 Formato de proyecto `.gmolde` en el núcleo (`ProjectFile`), con migraciones y prueba de ida y vuelta.
- 10.2 Guardar, abrir y galería local con miniaturas.
- ★ 10.3 Pestaña Estudio: girar huesos (FK) → guardar la pose en el proyecto → PNG con fondo transparente.
- 10.4 Biblioteca de poses propia (CC0), espejo de pose y partes bloqueadas.
- 10.5 Cámara: paneo, zoom hacia el cursor, vistas rápidas, lente y modo ortográfico; cámaras guardadas.
- 10.6 Luces: preset de tres puntos, color, mover arrastrando. El shader toon pasa a respetar `ATTENUATION` (cambio visual: pide aprobación).
- 10.7 Imagen en alta resolución y relación de aspecto libre. 10.8 Hoja de giro.
- 10.9 Modos de render: solo contorno, silueta, valores y color plano.
- 10.10 Posar arrastrando manos y pies (IK). 10.11 Gestos de mano. 10.12 Código de personaje (texto copiable).

**Hecho cuando:** se abre un proyecto, se posa el personaje, se elige cámara y luz, y sale una hoja de giro en PNG transparente.

### Fase 11 — Pelo

- 11.1 Sistema de piezas mínimo en el núcleo: ficha, carga y ranura (`ARQUITECTURA.md` §6).
- ★ 11.2 Un peinado (Quaternius UBC, CC0) en `Head`, con color, guardado en el proyecto y exportado.
- 11.3 Física con `SpringBoneSimulator3D` y colisiones de cabeza y torso.
- 11.4 La física viaja al juego: escena `.tscn` junto al `.glb`.
- 11.5 Más peinados, cejas y barba.

**Hecho cuando:** una coleta se mueve al caminar en el editor y en un proyecto vacío.

### Fase 12 — Ropa

- 12.1 Herramienta de pack: transfiere las formas del cuerpo a una prenda (Godot sin ventana, MIT).
- ★ 12.2 Una camiseta CC0 de MakeHuman que sigue al cuerpo en vivo y se exporta.
- 12.3 Ocultar la piel de debajo. 12.4 Capas y orden. 12.5 Al exportar, borrar las caras ocultas.
- 12.6 Faldas y capas con huesos de muelle.

**Hecho cuando:** con el cuerpo en sus extremos, la piel no atraviesa la camiseta (medido: 0 vértices de piel visibles por fuera).

### Fase 13 — Piezas y accesorios

- ★ 13.1 Una pieza rígida (espada propia) en cualquier hueso, con gizmo de mover, girar y escalar.
- 13.2 Acople magnético. 13.3 Importar un `.glb` propio con asistente. 13.4 Biblioteca de packs con filtros y licencia visible.
- 13.5 Generadores procedurales (cuernos). 13.6 Piezas con huesos extra (cola). 13.7 Agarre de la mano según el arma.

**Hecho cuando:** una espada propia se suelta sobre la mano, queda en su hueso, se guarda en el proyecto, se exporta y sigue en la mano al animar en un proyecto vacío.

### Fase 14 — Aspecto y estilos

- ★ 14.1 Estilo como archivo de datos: dos estilos (3 tonos y 2 tonos) elegibles y guardados.
- 14.2 Contorno por zona y color del contorno. 14.3 Tinte de sombra. 14.4 Calcomanías de piel. 14.5 Materiales especiales.
- 14.6 Tema de la interfaz según `diseno/`. 14.7 Pantalla de inicio con estilos. 14.8 Historial de Deshacer visual.

**Hecho cuando:** el usuario elige entre al menos 3 estilos con miniatura, el estilo se guarda en el proyecto, y el `.tres` exportado reproduce el estilo elegido en un proyecto vacío.

### Fase 15 — Android (estudio)

- 15.1 Herramientas, firma de pruebas y APK de humo con medidas (si no se hizo en 8.5).
- 15.2 Funciones por plataforma (`Platform`, `ARQUITECTURA.md` §8).
- ★ 15.3 Abrir un `.gmolde`, posarlo con el dedo y guardar un PNG.
- 15.4 Gestos (un dedo gira, dos dedos acercan y mueven). 15.5 Guardar y compartir. 15.6 Memoria y rendimiento. 15.7 Firma y distribución.

**Hecho cuando:** en un móvil de gama media se abre un `.gmolde` hecho en el PC, se posa con el dedo, se guarda un PNG y el proyecto modificado vuelve a abrirse en el PC, dentro del presupuesto de `RENDIMIENTO.md` §2.

### Fase 16 — Especies y modificaciones extremas

- ★ 16.1 Largo y grosor de un hueso (brazo), de punta a punta.
- 16.2 Rangos ampliados y «Exageración». 16.3 Auditoría de especie y segunda base (chibi). 16.4 Formas dispersas (solo si las medidas lo piden). 16.5 Escultura libre. 16.6 Piernas de animal.

**Hecho cuando:** un personaje con brazos largos y gruesos, piernas cortas y un brazo distinto del otro se exporta, pasa `probar_glb.gd` y se anima sin que las manos se deformen.

### Fase 17 — VRM 1.0

- 17.1 Estudio de la especificación y de licencias (D24). 17.2 Humanoide y metadatos. 17.3 Expresiones. 17.4 Huesos de muelle. 17.5 Material.

**Hecho cuando:** el `.vrm` exportado pasa un validador de VRM y se abre, con expresiones y pelo con movimiento, en un programa libre que lea VRM 1.0.

Fichas: detalladas para la Fase 8 (`pasos/8.1` a `8.5`); breves para las fases 9 a 17 (`pasos/9_cara_y_ojos.md`, `10_proyecto_y_estudio.md`, `11_pelo.md`, `12_ropa.md`, `13_piezas_y_accesorios.md`, `14_aspecto_y_estilos.md`, `15_android.md`, `16_especies_y_extremos.md`, `17_vrm.md`).

### Comodines (tamaño S, en cualquier momento tras el MVP)

Aleatorio con semilla y candados · medidas en cm · espejo de la vista · temporizador de poses para dibujo de gesto · sombreado facetado. Ver el top 10 de `IDEAS_AL_LIMITE.md`.

---

## 4. Qué no haría, y por qué

| Idea | Por qué no |
| --- | --- |
| Pincel de mechones | Coste XL (generar malla, UV y huesos desde trazos) para algo que las piezas con física cubren al 80 %. |
| Versión web con Three.js | Obliga a reescribir el núcleo en otro lenguaje y a mantener dos. Si algún día hace falta web, que sea la exportación web de Godot. |
| Pose desde foto e IA local (texto a personaje, foto a proporciones) | Modelos de cientos de MB, licencias de pesos dudosas y dependencia nueva. Valor real, pero fuera de alcance mientras el editor no esté completo. |
| Rig automático con IA (UniRig) | Ya está en `IDEAS.md` con su condición (GPU de más de 8 GB). No cambia nada. |
| Tela simulada de verdad | Godot no tiene tela para mallas con esqueleto fiable (`SoftBody3D` sobre mallas con piel: **NO VERIFICADO**). Los huesos de muelle dan el 90 % del efecto. |
| Hiperrealismo | Contradice la guía de estilo y el presupuesto de móvil. |
| Slime y especies sin esqueleto humanoide, al principio | Rompen la pose T, el retargeting y las pruebas. Solo después de la auditoría de especie (16.3). |
| Perfiles de exportación para Unity y Unreal | Sin esos motores instalados no se pueden probar; publicar un perfil sin prueba es inventar. El `.glb` estándar ya se abre en ambos. |
| Línea de tiempo con fotogramas clave | Es otro programa (un editor de animación). El estudio hace poses e imágenes; para animar ya están Blender y Godot. |
| Vista dividida en 4 | Cuadruplica el coste de dibujo en móvil; las vistas rápidas y la hoja de giro cubren el uso. |
