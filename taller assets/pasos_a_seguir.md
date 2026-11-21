# PASOS A SEGUIR — MVP del Taller de Assets para Codex

**Guía de ejecución por etapas · 20 de noviembre de 2026 · Solo planificación: no hay código creado**

> **Objetivo único:** incorporar un **Taller de Assets dentro de GameMolde**, no una herramienta externa: espada paramétrica, conversión sencilla de imagen a extrusión 3D y camiseta 3D independiente que sigue al personaje. Biblioteca, equipamiento y exportación GLB. El resultado debe funcionar sin IA ni servicios online. Este documento desarrolla `plan.md`; las mejoras futuras van a `ideas.md`.

## 0. Instrucciones de trabajo para Codex

**Antes de actuar:** leer los documentos del repositorio que correspondan al paso: [`CLAUDE.md`](https://github.com/m-xarxatec/Character_Creator/blob/main/CLAUDE.md), [`PLAN.md`](https://github.com/m-xarxatec/Character_Creator/blob/main/PLAN.md), [`ruta/GUIA_MODELOS.md`](https://github.com/m-xarxatec/Character_Creator/blob/main/ruta/GUIA_MODELOS.md), [`ruta/DECISIONES.md`](https://github.com/m-xarxatec/Character_Creator/blob/main/ruta/DECISIONES.md), [`ruta/ARQUITECTURA.md`](https://github.com/m-xarxatec/Character_Creator/blob/main/ruta/ARQUITECTURA.md), [`propuestas/expansion_v2.md`](https://github.com/m-xarxatec/Character_Creator/blob/main/propuestas/expansion_v2.md) y los **tres documentos de este Taller**. Leer el código que realmente se vaya a tocar, no solo resúmenes o rutas propuestas.

### Reglas innegociables

1. **No empezar sin permiso expreso del responsable.** La aceptación de estos documentos **no equivale** a autorización de programar, instalar dependencias o descargar archivos.
2. **Un paso por vez:** proponer → recibir «OK» → implementar → probar → informar → esperar siguiente aprobación. No encadenar varios pasos por iniciativa del agente.
3. **Sin ficha no hay paso.** Antes de ejecutar un paso, crear/ajustar su ficha bajo `ruta/pasos/` **con aprobación** y con objetivos, archivos autorizados, diseño, pruebas, riesgos y criterios de cierre. Si el protocolo del repo exige incorporar el paso al `PLAN.md` raíz, proponer ese cambio; nunca sobreescribirlo con este `plan.md`.
4. **No sobrescribir los documentos de raíz:** `PLAN.md`, `IDEAS.md` y `CLAUDE.md`. Los tres nuevos documentos se guardarán, si el responsable aprueba incorporarlos, en **`propuestas/taller_assets/plan.md`, `ideas.md` y `pasos_a_seguir.md`**.
5. **Solo archivos aprobados en cada ficha.** Un bloqueo, hallazgo o dependencia imprevista se presenta al responsable. No efectuar grandes refactors «aprovechando» el Taller.
6. **No hacer operaciones Git de escritura** (commit, checkout, merge, rebase, reset, cherry-pick, push, tag). Git solo lectura; el responsable hace los commits.
7. **No acceder a internet, instalar bibliotecas o importar assets de terceros sin autorización.** Mantener derechos compatibles con la licencia del repositorio. No copiar código GPL al núcleo MIT; scripts de `blender/` siguen su régimen separado.
8. **No inventar APIs/archivos.** Comprobar contra el Godot instalado y el árbol real. No declarar que algo está probado si no lo está.
9. **Probar el fallo:** una prueba nueva debe fallar al introducir de forma reversible un defecto concreto; restaurar el código y volver a pasarla. No cambiar umbrales de pruebas preexistentes sin aprobación.
10. **La revisión visual la decide el usuario.** Entregar capturas y comandos de revisión cuando cambie la malla, la ropa o la exportación; esperar aprobación antes de continuar.

### Formato de propuesta para comenzar cada paso

```text
PROPUESTA — Taller TA.N
Objetivo: [resultado observable]
Estado/dependencias: [qué ya existe, qué falta, qué bloquea]
Archivos: [lista cerrada de archivos que se tocarán]
Algoritmo/diseño: [resumen comprensible]
Pruebas: [comandos reales, qué se mide, cómo detectan un fallo]
Riesgos/licencias: [puntos relevantes]
Cómo verlo: [escena/captura/archivo de salida]
¿Apruebas?
```

### Informe final de cada paso

```text
TA.N — [hecho / bloqueado]
Cambios: [archivos concretos, en una o dos líneas]
Pruebas: [comandos, resultado real; si no ejecutadas, por qué]
Evidencia: [rutas de capturas, GLB o informes, si procede]
Siguiente: TA.N+1 (no comenzado; espera de aprobación)
```

Los pasos están diseñados para dividirse **aún más** cuando una ficha resulte demasiado amplia. Los nombres de módulos y archivos son **candidatos**, no obligaciones de duplicar implementaciones existentes.

## 1. Dependencias y orden de trabajo

```text
TA.0 Auditoría y compatibilidad
     ↓
TA.1 Contratos, fixtures y pruebas base
     ↓
TA.2 Pestaña y vista del Taller
     ↓
TA.3 Espada paramétrica
     ↓
TA.4 Imagen 2D -> extrusión
     ↓
TA.5 Recetas y biblioteca local
     ↓
TA.6 Equipar/exportar espada
     ↓
TA.7 Preparar geometría compatible de camiseta
     ↓
TA.8 Camiseta en vivo y parámetros
     ↓
TA.9 Exportar personaje con camiseta + espada
     ↓
TA.10 Robustez, documentación y validación
     ↓
TA.11 Cierre y revisión final del MVP
```

**Bloqueos externos que deben explicitarse en TA.0:** ¿ya están implementados `PackLibrary` (AB.2), formato `.gmolde` (10.1–10.2), `BodyPiece` (AB.4), exportación de varias mallas (AB.7)? Si no, el Taller integrará un **subconjunto mínimo compatible**, o se detendrá para ejecutar las dependencias de la expansión **con aprobación**. No crear sustitutos incompatibles con esas fases.

---

## TA.0 — Auditoría del repositorio y mapa de integración

**Objetivo:** conocer el estado real antes de tocar el programa y decidir qué piezas existentes se reutilizan.

**Inspeccionar (solo lectura):**

- `godot/project.godot`, `godot/app/main.gd`, `godot/app/top_bar.gd`, `godot/app/body_view.gd`, `godot/app/body_editor.gd`.
- `godot/addons/creador/`, especialmente `glb_exporter.gd`, `character_baker.gd`, `character_updater.gd`, `shape_weights.gd`, `sockets.gd` y clases de packs/piezas **si existen**.
- `godot/datos/` (manifiesto, malla y helpers disponibles), `blender/` (pipeline de preparación), `pruebas/` y su mecanismo de ejecución.
- `ruta/ARQUITECTURA.md` §6, `propuestas/expansion_v2.md` AB.1–AB.7 / AB.11–AB.13, `ruta/PENDIENTES.md`, `ruta/DECISIONES.md` y `diseno/GUIA_INTERFAZ.md`.
- Licencias y restricciones; comprobar Git LFS antes de ejecutar pruebas que requieran `cuerpo.glb`.

**Entregar:** tabla de «existe / planificado / ausente» para UI, packs, recetas, camiseta, sockets, exportador, pruebas, módulos 3D y formatos; diagrama de integración; lista corta de cambios mínimos. Verificar Godot **4.7.2** del proyecto o informar diferencia sin asumir compatibilidad.

**Aceptación:** ningún archivo de código modificado; identificación de las dependencias que bloquean TA.6, TA.8 y TA.9; decisión sobre reutilización de AB/PackLibrary y estado real de `.gmolde`.

**Nivel:** medio–fuerte para auditoría del pipeline de exportación. **Prueba:** comprobaciones/lecturas del repositorio; ningún resultado geométrico aún.

## TA.1 — Definir contratos de receta, malla y pruebas base

**Objetivo:** fijar una estructura de datos pequeña, versionada y verificable para todos los modos.

**Candidatos de archivo:** `godot/addons/creador/taller_assets/asset_recipe.gd`, `asset_generator.gd`, `asset_validator.gd`; pruebas bajo `pruebas/taller_assets/` o donde establezca el runner encontrado en TA.0; documentación de formato cercana al código.

**Diseño mínimo:**

- Tipos de receta: `espada_parametrica`, `extrusion_imagen`, `camiseta_basica`; versión `1`, valores por defecto, unidades metros, orientación Y/+Z, materiales por región y campos de procedencia.
- Contrato de generadores: receta validada → malla/escena + metadatos + errores. Nada de interfaz, red, guardado o equipamiento dentro del generador.
- Contrato de validación: vértices finitos, triángulos con área positiva, índices en rango, superficies no vacías, dimensiones dentro de rangos; para sólidos: caras cerradas donde aplique, normales con dirección correcta. Para ropa: skin/pesos verificados aparte.
- **Fixtures pequeños** propios: polígono convexo, polígono cóncavo sin agujeros, alfa con rectángulo, imagen vacía, objeto recortado, fondo uniforme y receta inválida. La espada del chat se incorpora como fixture **solo si el usuario facilita/copia el archivo al repositorio y autoriza ese uso**.

**Pruebas:** ejecución headless del validador con geometría sintética; las recetas incompletas se completan con defaults seguros, las versiones desconocidas se rechazan sin perder datos, un polígono vacío no genera una malla válida.

**Aceptación:** prueba de contrato reproducible, esquema de receta entendido por los tres generadores y sin dependencias de UI. **Nivel:** medio.

## TA.2 — Crear la pestaña «Taller de Assets» sin romper el editor

**Objetivo:** navegar al Taller y volver al cuerpo usando el tema y la barra existentes.

**Candidatos:** cambios mínimos en `godot/app/main.gd` y `top_bar.gd`; componentes bajo `godot/app/taller_assets/` (por decidir tras auditoría).

**Hacer:**

1. Añadir acceso «Taller de Assets» a la navegación. Si no cabe por resolución mínima, proponer botón/menú de acceso sin ocultar «Exportar».
2. Crear panel izquierdo para modos, centro de vista 3D orbital y panel derecho para propiedades; la UI puede mostrar objetos de prueba temporales en este paso.
3. Reutilizar tokens/theme, `FileDialog`, controles y cámara existentes donde sea apropiado. Mantener los botones `Cuerpo`, `Ropa`, `Accesorios` y la funcionalidad actual.
4. Reservar acciones `Generar`, `Guardar`, `Equipar`, `Exportar`, desactivadas con ayuda clara hasta que existan sus servicios.
5. Dejar claro visualmente que el Taller **crea** assets y Ropa/Accesorios **los equipan**.

**Prueba:** abrir GameMolde, entrar al Taller, regresar al cuerpo, editar un deslizador y exportar con el flujo anterior; medir tamaños 1280×720 y 1920×1080 y un tema claro/oscuro si existe. Capturas para aprobación humana.

**Aceptación:** la navegación funciona y no hay regresiones funcionales en la pestaña Cuerpo. **Nivel:** medio; **juicio visual obligatorio**.

## TA.3 — Generador de espada low-poly por parámetros

**Objetivo:** primer asset real con geometría tridimensional y submateriales.

**Candidatos:** `sword_generator.gd`, material utilitario compartido si hace falta, controles de espada en la UI, pruebas `probar_espada_*`.

**Hacer:**

1. Construir **hoja** a lo largo de Y, con segmentos de secciones transversales y perfil biselado/romboidal; punta definida y espesor positivo.
2. Añadir **guarda** horizontal configurable, **empuñadura** poligonal y **pomo** prismático, cada uno separable por material.
3. Parámetros mínimos: longitud, ancho, grosor, largo de punta, longitud de guarda, radio de mango, tamaño de pomo y tres colores. Usar valores razonables, rangos estrictos y restablecimiento.
4. Origen de agarre coherente para mano derecha, con ajuste posterior de offset/rotación. Frente hacia +Z en pose de referencia.
5. Facetado low-poly, sin geometría invisible innecesaria y normales correctas. Actualizar vista al modificar parámetros.

**Pruebas automáticas:**

- Dimensiones de la caja envolvente coherentes con parámetros (tolerancias propuestas según precisión de malla).
- Cuatro zonas visibles, materiales esperados, triángulos no degenerados y no NaN; con grosor positivo el volumen está realmente en 3D.
- Dos recetas distintas producen dimensiones distintas; repetir receta no cambia vértices/índices.
- Caso «longitud mínima» y «longitud máxima» no rompe la malla.

**Prueba visual:** espada completa desde frente, lado, ¾; comparable a la **referencia visual de espada** del chat sin pretender copia exacta por una sola imagen.

**Aceptación:** espada editable y 360°, con calidad suficiente para adjuntarla después al personaje. **Nivel:** fuerte para primera malla; revisión visual obligatoria.

## TA.4 — Conversión simple desde imagen a extrusión 3D

**Objetivo:** recibir una imagen **sencilla** del usuario y producir una malla con volumen controlado sin IA.

**Candidatos:** `image_mask.gd`, `silhouette_mesh.gd`, controles de importación y previsualización; fixtures de imagen en `pruebas/taller_assets/`.

**Algoritmo requerido:**

1. Cargar PNG con canal alfa; imagen opaca de fondo uniforme mediante umbral por color/tolerancia. Limitar tamaño y detectar carga fallida.
2. Generar máscara binaria, identificar componente principal y avisar de múltiples objetos, huecos, zonas desconectadas o transparencia ausente.
3. Seguir contorno exterior cerrado, quitar puntos colineales y simplificar sin autointersecciones. Dibujar borde detectado sobre la imagen para verificarlo.
4. Triangular **polígono simple** con `Geometry2D.triangulate_polygon`; **no** dar por resueltos los huecos interiores con la llamada básica.
5. Crear caras de frente/espalda + laterales, normales y material; respetar Y arriba, +Z frente; parámetros de grosor, altura, tolerancia y simplificación.
6. Si falla el contorno/triangulación, no bloquear ni crear basura: mostrar la razón y permitir reajustar.

**Pruebas:** imagen transparente de rectángulo → prisma; silueta cóncava sencilla → extrusión; imagen vacía → error; fondo sólido con tolerancia → máscara conocida; PNG grande → reducción o rechazo explícito; máscara con agujero → aviso claro de limitación en MVP; prueba manual con espada del chat si se aporta como fixture.

**Aceptación:** al girar, se ve grosor real; malla importable, sin errores de índice ni normales; parámetro de grosor cambia el volumen. **Nivel:** fuerte para contornos/triangulación; revisión visual obligatoria.

## TA.5 — Guardado, apertura y edición desde biblioteca local

**Objetivo:** ninguna pieza desaparece al cerrar GameMolde y todas pueden editarse de nuevo desde su **receta**.

**Candidatos:** `asset_store.gd`, integración con `PackLibrary` **si está implementado**, panel de biblioteca y prueba de ida/vuelta.

**Hacer:**

1. Reutilizar formato de `pack.json` de `ruta/ARQUITECTURA.md` §6 y `user://packs/`.
2. Guardar nombre/ID, tipo, receta versionada, fuente gráfica local cuando exista, GLB, miniatura, SHA-256, autor/licencia y ranura.
3. Abrir desde biblioteca y reconstruir con los mismos parámetros. Si falta fuente o difiere hash: aviso, mantener los datos disponibles, no sobrescribir el problema.
4. Validar rutas/IDs, extensión y límites para no escribir fuera de la carpeta del pack. Guardado seguro, rechazo de nombres duplicados o versión explícita.
5. Conectar acciones `Guardar en biblioteca`, `Reabrir`, `Eliminar` (solo si se aprueba) y `Exportar asset independiente` a los servicios existentes.
6. Acompañar el `.glb` de materiales glTF básicos; el sombreado toon de Godot se conserva aparte solo en su formato compatible.

**Pruebas:** guardar→cerrar→abrir→regenerar dos espadas y una extrusión con mismos parámetros; fichero truncado/corrupto causa aviso, no crash; prueba de no sobrescritura; SHA-256 al guardar/abrir; proyecto Godot vacío importa GLB.

**Aceptación:** biblioteca persistente y editable, sin crear otro sistema de packs. **Nivel:** medio–fuerte; pruebas de ficheros obligatorias.

## TA.6 — Equipar espada y exportarla con personaje

**Objetivo:** conectar un asset rígido del Taller con el personaje real, con animación y exportación correctas.

**Candidatos:** `asset_equipper.gd` o integración con `PieceAttacher`/`PackLibrary` existente; cambios **mínimos** al coordinador y exportador; pruebas de socket.

**Hacer:**

1. Elegir espada guardada, usar `socket_hand_r`, ajustar traslación/rotación/escala uniforme. Guardar el transform con la receta o vínculo de pieza.
2. Montar sobre el personaje horneado/attachment correcto, respetando la lógica ya decidida del rig. No heredar escalas deformantes del hueso.
3. Ejecutar animación «Atacar» y otra prueba disponible; verificar que la espada se mueve con la mano sin saltos ni cambios de escala.
4. Exportar `.glb` con espada; comprobar si el `GlbExporter` actual necesita soportar nodos/meshes adicionales. Proteger regresión del exportador antiguo.
5. Si el proyecto `.gmolde` ya existe, guardar referencia (`pack`, `pieza`, `sha256`, `ranura`, `transform`) usando su formato. Si no existe, dejar el equipamiento en sesión + asset persistente y **declarar el límite**.

**Pruebas:** espada centrada en mano en pose T y durante ataque; reimportación en Godot sin addon; no se alteran los 53 huesos del personaje, sockets ni materiales; comparar exportación sin accesorios con la prueba anterior del repositorio.

**Aceptación:** primer asset del Taller **usable en personaje y GLB exportado**. **Nivel:** fuerte por integración con exportador; juicio visual obligatorio.

## TA.7 — Fuente geométrica y pesos de la camiseta básica

**Objetivo:** preparar una camiseta **3D independiente** con topología y pesos compatibles con la base humana.

**No empezar sin decidir la dependencia de AB.3:** revisar helpers de MakeHuman, `blender/exportar_datos.py`, formas propias, pesos y restricciones de licencia. No importar un archivo de ropa aleatorio que no encaje con el cuerpo.

**Ruta A (preferida, coherente con `expansion_v2.md`):** extraer `helper-tights`, recortar camiseta de manga corta, transferir/retener formas relevantes y skin, exportar dato GLB de prenda. El script de preparación se sitúa bajo `blender/` y respeta su licencia; el runtime del Taller sigue sin necesitar Blender. Reutilizar AB.3 si ya se implementó.

**Ruta B (solo con autorización si A se bloquea):** seleccionar superficies del torso y parte superior de brazos a partir de la malla CC0, copiando pesos por vértice, aplicando holgura, creando bordes y realizando pruebas geométricas. Documentar limitaciones de ajuste.

**Pruebas:** 1 camiseta visible y separada del cuerpo; máximo cuatro influencias por vértice, pesos suman 1 con tolerancia aprobada; UV/material válido; malla sin triángulos degenerados; cotejo con 2 variaciones de torso y brazos; memoria y triángulos medidos.

**Aceptación:** un GLB/base de camiseta preparado y validado, reutilizable por el generador. **No se acepta** sustituirla por textura pintada. **Nivel:** fuerte; revisión visual necesaria.

## TA.8 — Generador/ajustador de camiseta y seguimiento del personaje

**Objetivo:** usar la prenda en el Taller, ajustar color/holgura y ponerla en un cuerpo editable sin romper animación ni formas.

**Candidatos:** `shirt_generator.gd`, integración con `BodyPiece`/`CharacterUpdater`/`ShapeWeights`, `ropa_torso` en la UI y pruebas de deformación.

**Hacer:**

1. Ofrecer receta de camiseta con talla/holgura controlada, manga corta inicial y colores. Las variaciones geométricas deben respetar pesos y formas; evitar «escalar todo el mesh» si desajusta el rig.
2. Relacionarla con **el mismo `Skeleton3D`** que usa el personaje. Reutilizar los nombres de formas existentes y el orden del update del cuerpo.
3. Equiparla en `ropa_torso`, quitando/cambiando una sola prenda de esa ranura. La prenda base pintada no debe crear doble camiseta visible.
4. Comprobar clipping con torso neutro, torso ancho/estrecho y brazos en T/ataque. Si se necesitan máscaras de piel para pasar la prueba, reutilizar/adaptar AB.6 con aprobación; no ocultar errores con un shader temporal engañoso.
5. Dejar bien definidos parámetros que funcionan; avisar cuando una forma corporal no se transfiera.

**Pruebas:** la camiseta sigue al torso al mover sliders, en pose T y durante la animación de prueba; si se quita, el cuerpo vuelve a su aspecto esperado; no duplica huesos ni carga otra copia del personaje; no aparece skinning defectuoso al equiparla otra vez.

**Aceptación:** camiseta funcional como **asset equipable separado**, con pruebas medibles y revisión visual humana; no requiere simulación física. **Nivel:** fuerte.

## TA.9 — Exportación integrada de cuerpo + espada + camiseta

**Objetivo:** cerrar el circuito real de uso del Taller dentro del producto existente.

**Candidatos:** extensión mínima de `character_baker.gd`, `glb_exporter.gd` y/o integración AB.7, sin nuevos exportadores paralelos; pruebas de ida y vuelta; fichero .tres complementario si corresponde.

**Hacer:**

1. Construir escena de exportación limpia con personaje horneado, accesorios rígidos montados y camiseta vinculada al esqueleto.
2. Exportar GLB con todas las piezas y **reimportarlo** desde Godot en un proyecto vacío, sin addon ni recursos internos no embebidos.
3. Asegurar que la camiseta tiene `Skin`/huesos correctos tras reimportar y sigue la animación; que la espada está anclada, con pivote y material.
4. Conservar la salida actual del editor al exportar sin piezas; no alterar pose de reposo, nombres, número de huesos, materiales de cuerpo ni normas aprobadas.
5. Validar color/material glTF; el estilo toon se entrega por el mecanismo `.tres` existente cuando proceda, no se afirma que un shader Godot se exporta como PBR estándar.

**Pruebas de regresión:** exportación antigua «sin piezas», exportación con solo espada, con solo camiseta, con ambas; pruebas de reimportación, esqueleto, 4 pesos, materiales y posiciones; una muestra abierta en Blender. Reproducir y aislar cualquier cuelgue de `GLTFDocument` antes de seguir.

**Aceptación:** `personaje + espada + camiseta.glb` es utilizable en Godot y Blender y no pierde el rig. **Nivel:** fuerte; juicio visual obligatorio.

## TA.10 — Robustez, límites, UX y documentación

**Objetivo:** pasar de prototipo funcional a MVP que no sorprenda ni rompa trabajos.

**Hacer:**

- Mensajes de error amigables para imagen vacía, fondo no separable, huecos, archivos corruptos, versión incompatible, pérdida de permisos y falta de fuente.
- Validar receta, extensión, hash, tamaño de imagen, límites de escala y colores; ningún parámetro provoca NaN/crash.
- Guardado seguro y reapertura con recetas; exportación no destructiva; miniaturas regenerables y licencia siempre visible.
- Evitar operaciones costosas por frame; usar procesamiento acotado por evento. Medir tiempo de generación, triángulos y memoria con los assets de prueba; **no inventar presupuestos numéricos de rendimiento**.
- Comprobar funcionamiento offline, instalación normal del build y resolución mínima de la GUI.
- Actualizar documentación de uso del Taller, créditos/licencias y una guía de qué imágenes funcionan; lista de limitaciones transparente.
- Ejecutar `godot --headless --path godot -- --autoprueba` y pruebas específicas con **comandos verificados y anotados en su cabecera**; pruebas visuales con capturas reproducibles.

**Aceptación:** errores controlados, pruebas de regresión pasan, documentación en español y capturas entregadas al responsable. **Nivel:** medio; revisión visual obligatoria.

## TA.11 — Cierre del MVP y entrega al responsable

**Objetivo:** reunir evidencia sin abrir nuevos trabajos.

**Entregar en un informe corto:**

1. Qué modos funcionan y qué tipos de imágenes/prendas admite el Taller.
2. Una **espada paramétrica** guardada, reabierta y exportada; una **extrusión desde PNG**; una **camiseta básica**.
3. Un GLB independiente de asset y un GLB de personaje con **espada + camiseta**, reimportados y probados.
4. Comandos y resultados reales de las pruebas; listado de regresiones del cuerpo y materiales.
5. Capturas a frente/lado/¾ de espada, extrusión y camiseta en cuerpo; rutas de archivos para revisión humana.
6. Lista de limitaciones conocidas, en especial imágenes con agujeros, fotos complejas y variaciones de camiseta no soportadas.
7. Tabla de `MVP cumplido / no cumplido`, sin marcar algo como aprobado si falta la revisión del responsable.
8. `ideas.md` actualizado **solo** con ideas aceptadas durante la ejecución; no implementar backlog.

**Cierre:** no hacer commit ni publicar versiones por cuenta del agente. El responsable revisa, aprueba el MVP y decide cuándo integrarlo/publicarlo.

---

## 2. Matriz de pruebas del MVP

| Caso | Prueba mínima | Criterio de salida |
|---|---|---|
| Espada paramétrica | dos presets, dimensiones mínima/máxima | Todas las mallas válidas, 4 partes reconocibles, grosor real |
| Silueta desde imagen | alfa sencillo y fondo uniforme | Contorno detectado, caras delante/detrás/laterales |
| Imagen inválida | vacía, demasiado grande, agujero | Error/aviso comprensible; sin crash ni corrupción |
| Biblioteca | guardar→cerrar→abrir→editar | Receta, miniatura y GLB recuperados |
| Equipamiento rígido | `socket_hand_r` + animación | Pivote/escala conservados; espada sigue la mano |
| Camiseta neutra | torso base + pose T | Malla separada y rig correcto |
| Camiseta con formas | 2 variaciones de cuerpo + animación | Forma y pesos compatibles; clipping revisado |
| Exportación GLB | sin piezas, espada, camiseta, ambas | Reimportan; rig, materiales y jerarquía correctos |
| Regresión GameMolde | autoprueba y uso de Cuerpo | Editor anterior funciona igual |
| UX y licencias | 1280×720, tema, biblioteca y créditos | Todo legible y autor/licencia visibles |
| Offline | aplicación sin internet/agente | Generación y guardado siguen disponibles |

**Los umbrales cuantitativos de geometría/tiempo se fijarán con mediciones del primer prototipo y con aprobación.** Los ya existentes del repositorio no se reducen ni modifican arbitrariamente.

## 3. Criterios de parada obligatoria para Codex

- La API que se quiere usar **no existe** en la versión de Godot disponible o el agente no puede comprobarla.
- El cambio exige modificar formato `.gmolde`, rig o exportador en una dirección incompatible con las decisiones existentes.
- La prenda requiere copiar código de una biblioteca con licencia incompatible con el núcleo MIT.
- Una prueba nueva no detecta un error que debería detectar, o una prueba de regresión falla.
- Un GLB parece correcto en visor pero pierde huesos, pesos o submallas al reimportar.
- La pieza de ropa atraviesa el cuerpo de forma visible y no se ha medido o explicado la corrección.
- Para continuar hay que descargar archivos, instalar software o tocar un archivo fuera de la ficha aprobada.
- El responsable no ha validado las capturas obligatorias de un cambio de aspecto.

**Ante una parada:** describir el bloqueo, las opciones mínimas, el efecto sobre el MVP y pedir autorización. No improvisar una solución oculta.

## 4. Preparación del futuro `codex.md` (no crear ahora)

Cuando el responsable lo solicite, `codex.md` o las instrucciones que utilice Codex deberán referenciar **estos tres archivos**, más las normas reales del repositorio, y limitarse a:

- leer el estado del paso y su ficha;
- proponer exactamente el siguiente TA.N;
- esperar «OK»;
- ejecutar solo los cambios autorizados;
- probar y registrar resultados;
- parar después de cada paso.

**No** se crea `codex.md` en este paquete porque el encargo actual pide exactamente **tres documentos**.

## 5. Fuentes y trazabilidad

### Fuentes del proyecto (consultadas para el diseño)

- [GameMolde / Character_Creator](https://github.com/m-xarxatec/Character_Creator) — proyecto de destino.
- [README.md](https://github.com/m-xarxatec/Character_Creator/blob/main/README.md) — Godot, GLB, ejes y sockets.
- [PLAN.md raíz](https://github.com/m-xarxatec/Character_Creator/blob/main/PLAN.md) — flujo y estado del programa principal.
- [CLAUDE.md](https://github.com/m-xarxatec/Character_Creator/blob/main/CLAUDE.md) — aprobación, paso/ficha, Git, licencias, pruebas.
- [propuestas/expansion_v2.md](https://github.com/m-xarxatec/Character_Creator/blob/main/propuestas/expansion_v2.md) — AB.1–AB.7; AB.11–AB.13.
- [ruta/ARQUITECTURA.md](https://github.com/m-xarxatec/Character_Creator/blob/main/ruta/ARQUITECTURA.md) — packs, `.gmolde`, estado y equipamiento.
- [ruta/GUIA_MODELOS.md](https://github.com/m-xarxatec/Character_Creator/blob/main/ruta/GUIA_MODELOS.md) — protocolo de ejecución y señales de alarma.
- [diseno/GUIA_INTERFAZ.md](https://github.com/m-xarxatec/Character_Creator/blob/main/diseno/GUIA_INTERFAZ.md) — estructura visual.
- [main.gd](https://github.com/m-xarxatec/Character_Creator/blob/main/godot/app/main.gd) — pestañas existentes.

### Referencias de implementación y algoritmos

- [Godot GLTFDocument](https://docs.godotengine.org/es/4.x/classes/class_gltfdocument.html)
- [Godot Geometry2D](https://docs.godotengine.org/es/4.x/classes/class_geometry2d.html)
- [Godot ArrayMesh](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html)
- [Godot SurfaceTool](https://docs.godotengine.org/en/stable/classes/class_surfacetool.html)
- [Vectify](https://github.com/atdotslash/Vectify), [GLBForge](https://github.com/glbforge/glbforge), [ReliefDrop](https://github.com/kcgdz/ReliefDrop) — contornos, extrusión, relieves, referencias conceptuales; no dependencias aprobadas.
- [Roxel](https://github.com/starzonmyarmz/roxel) y [2D-to-3D Voxelizer](https://github.com/GazPrash/2d-to-3d-voxelizer) — futuras mejoras voxel.
- [Drawing to 3D Agent](https://github.com/nyyyaomi/drawing-to-3d-agent) y [2D-to-3D-Converter](https://github.com/Fatcatcreate/2D-to-3D-Converter) — reconstrucción multivista futura, con auditoría previa de licencias.

**Referencia visual del usuario:** espada gris estilizada en fondo oscuro compartida en este chat el 20/11/2026. No asumir que está almacenada en el repositorio; solicitar su incorporación al banco de pruebas si se necesita como fixture persistente.

---

**Estado del plan de Codex:** `TA.0` es el **primer paso por proponer**. Ningún paso está implementado ni aprobado para ejecución mediante estos documentos. Las decisiones de arquitectura y prioridades provienen de lo acordado en la conversación; los detalles concretos de clases/rutas son propuestas sujetas a la auditoría inicial.
