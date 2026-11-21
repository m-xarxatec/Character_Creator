# PLAN — Taller de Assets de GameMolde

**Documento de diseño técnico · 20 de noviembre de 2026 · Estado: propuesta aprobada en su objetivo, pendiente de implementación**

> Este documento define la expansión **Taller de Assets** de [GameMolde / Character_Creator](https://github.com/m-xarxatec/Character_Creator). No describe un generador externo ni ordena modificar el repositorio todavía. Se utilizará, junto con `ideas.md` y `pasos_a_seguir.md`, para preparar después las instrucciones de Codex. **No es el `PLAN.md` general del repositorio y no debe sobrescribirlo.** Ubicación recomendada cuando se incorpore al proyecto: `propuestas/taller_assets/`.

## 1. Punto de partida comprobado

- El programa existente es **GameMolde**, editor de personajes desarrollado en **Godot 4.7.2, GDScript (no .NET)**. Núcleo: `godot/addons/creador/`; interfaz: `godot/app/`. Exporta `.glb`, tiene visor 3D, estilo toon y esqueleto humanoide. [README](https://github.com/m-xarxatec/Character_Creator/blob/main/README.md).
- Su personaje usa metros, **Y hacia arriba y frente hacia +Z**. Tiene anclajes `socket_hand_r`, `socket_hand_l`, `socket_back` y `socket_hip`. Se conservan y reutilizan, no se inventa otro sistema de montaje. [README](https://github.com/m-xarxatec/Character_Creator#usar-el-personaje-en-godot).
- La nueva interfaz ya existe parcialmente: `godot/app/main.gd` mantiene pestañas `Cuerpo`, `Cara y ojos`, `Pelo`, `Ropa`, `Accesorios`, `Estilo`; varias anuncian «Pronto». Se integrará **Taller de Assets** sin romperlas ni sustituirlas. [main.gd](https://github.com/m-xarxatec/Character_Creator/blob/main/godot/app/main.gd) · [Guía de interfaz](https://github.com/m-xarxatec/Character_Creator/blob/main/diseno/GUIA_INTERFAZ.md).
- Los planes existentes **ya contemplan** accesorios procedurales, ropa vinculada al cuerpo y packs: `propuestas/expansion_v2.md` (AB.1–AB.7 y AB.11–AB.13), `ruta/ARQUITECTURA.md` (§§1, 4 y 6), `IDEAS.md`. El Taller **amplía esa expansión**, no la reemplaza. Antes de programarlo, Codex debe comprobar qué piezas de AB y de la Fase 10–11 ya están implementadas; la documentación las describe en parte como futuras. [Expansión v2](https://github.com/m-xarxatec/Character_Creator/blob/main/propuestas/expansion_v2.md) · [Arquitectura](https://github.com/m-xarxatec/Character_Creator/blob/main/ruta/ARQUITECTURA.md).
- Según el `PLAN.md` consultado el **20/11/2026**, el MVP del creador y el rediseño IU figuran prácticamente cerrados, pero quedan decisiones visuales y publicación pendientes. **No confundir ese estado con el Taller**, que aún no está implementado. [PLAN.md original](https://github.com/m-xarxatec/Character_Creator/blob/main/PLAN.md).
- El repositorio exige aprobación previa, **un paso por vez**, ficha en `ruta/pasos/`, pruebas, revisión visual, respeto a licencias y que **los commits los haga el responsable**, no el agente. Estas reglas siguen vigentes con Codex, salvo cambio autorizado explícitamente por el propietario. [CLAUDE.md](https://github.com/m-xarxatec/Character_Creator/blob/main/CLAUDE.md) · [Guía de modelos](https://github.com/m-xarxatec/Character_Creator/blob/main/ruta/GUIA_MODELOS.md).

## 2. Objetivo y alcance

**Meta:** añadir a GameMolde una **pestaña «Taller de Assets»** desde la que crear, previsualizar, retocar, guardar, reutilizar, equipar y exportar **assets 3D** para el mismo creador de personajes. Todo funciona localmente **sin IA, APIs, cuentas ni conexión de red**. La IA podrá conectarse en una fase futura como consumidora de las mismas operaciones del motor, pero no será dependencia de ejecución.

### Decisiones tomadas en el chat

| Decisión | Valor |
|---|---|
| Producto | Expansión integrada en **GameMolde**, no software separado |
| Prioridad | **Armas/accesorios rígidos + una camiseta básica** en el MVP del Taller |
| Imágenes | Una o varias vistas **como capacidad evolutiva**; en MVP se procesa **una imagen simple** |
| Métodos | Varios modos, desarrollados de forma incremental |
| Automatización | **Semiautomática**: conversión básica + parámetros/correcciones del usuario |
| Runtime | Godot/GDScript, sin dependencias adicionales obligatorias |
| Exportación | GLB principal; datos editables y ficha del asset guardados aparte |
| Exclusiones | **No** generar personajes, esqueletos nuevos, text-to-3D con IA ni modelado profesional completo |

### Qué debe permitir el MVP (mínimo aceptable)

1. Abrir **Taller de Assets** desde la navegación existente, con previsualización 3D y controles sencillos.
2. Elegir **«Espada paramétrica»**: cambiar longitud, anchura, punta, grosor, guarda, empuñadura, pomo y colores. Resultado de geometría low-poly real, no un plano texturizado.
3. Elegir **«Desde imagen»**: importar un PNG de silueta/ilustración sencilla (JPG con fondo uniforme, si la segmentación pasa la prueba), extraer el contorno principal, ajustar el umbral cuando proceda y generar una **extrusión 3D editable** con grosor. La imagen de la espada aportada en el chat es caso de referencia. **No** se promete reconocer automáticamente qué píxeles son hoja, guarda o pomo.
4. Elegir **«Camiseta básica»**: generar o cargar una **malla 3D de prenda independiente**, ceñida al torso, con mangas cortas y color configurable, diseñada para el cuerpo humano base de GameMolde; debe seguir el esqueleto y las formas compatibles. No basta con pintar la camiseta sobre la piel.
5. Guardar los tres tipos de resultado en una **biblioteca local persistente**, con miniatura, parámetros de edición, autor/licencia y `.glb` reutilizable.
6. Seleccionar una espada y **equiparla** en `socket_hand_r`; seleccionar la camiseta en `ropa_torso`; verlas en el personaje, quitar/cambiar pieza y comprobar cómo se comportan en pose T y en una animación existente.
7. Exportar **el asset independiente** en `.glb` y, para las piezas equipadas, **el personaje con ellas** en un `.glb` compatible con el flujo ya existente, comprobando el resultado mediante reimportación.

**Nota de dependencia:** la persistencia del *equipamiento dentro de un proyecto* debe reutilizar el formato `.gmolde` cuando su fase esté disponible; si no lo está, el MVP puede guardar los assets en la biblioteca y mantener su equipamiento durante la sesión, **pero no debe afirmar que ya guarda un proyecto completo**. Antes de cerrar el MVP, el propietario decidirá si se ejecuta primero 10.1–10.2 / AB.1. No duplicar el formato `.gmolde` con un JSON incompatible.

### Fuera del MVP

Reconstrucción multivista real, identificación automática semántica de partes, fotografías complejas, UV automáticas avanzadas, texturas PBR complejas, vestidos holgados, simulación de tela, materiales realistas, retopología profesional, complementos de personaje articulados, generador de personajes, conexión con agentes y generación de modelos mediante IA. Todo ello se valora en `ideas.md`.

## 3. Decisión tecnológica: nativo primero

**Decisión:** construir el runtime con **GDScript + APIs de Godot**, y reutilizar el pipeline de Blender **solo como herramienta de preparación offline de datos de ropa** cuando haga falta. **No obligar al usuario final a instalar Python, Blender, OpenCV o Trimesh para usar el Taller.**

| Tecnología/API | Uso acordado |
|---|---|
| `Image`, `ImageTexture` | Leer imágenes, alfa, píxeles, miniaturas y vista de referencia |
| GDScript (algoritmos propios) | Máscara binaria, componentes conexas, seguimiento de borde, simplificación de contorno |
| `Geometry2D.triangulate_polygon` | Triangular **un contorno simple** (comprobar orientación, degeneración y retorno vacío) |
| `ArrayMesh` / `SurfaceTool` | Construir superficies, índices, normales y materiales procedurales |
| `MeshInstance3D`, `Skeleton3D`, `Skin` | Vista previa y piezas de ropa deformables |
| `GLTFDocument` + `GLTFState` | Guardar/importar `.glb` y validar resultados |
| `FileAccess`, `DirAccess`, `JSON`, hashes | Recetas, biblioteca `user://`, rutas y validación de packs |
| Blender + MPFB / helpers de MakeHuman | **Preparación en desarrollo**, si la camiseta precisa geometría o formas ya asociadas al cuerpo; no se lanza en runtime |

Referencias de API: [Geometry2D](https://docs.godotengine.org/es/4.x/classes/class_geometry2d.html), [GLTFDocument](https://docs.godotengine.org/es/4.x/classes/class_gltfdocument.html), [Carga/guardado 3D en tiempo de ejecución](https://docs.godotengine.org/es/4.x/tutorials/io/runtime_file_loading_and_saving.html), [MeshInstance3D](https://docs.godotengine.org/es/4.x/classes/class_meshinstance3d.html). **Las llamadas concretas se verifican contra la versión instalada de Godot 4.7.2 antes de utilizarlas.**

No introducir dependencias grandes para resolver el primer contorno. **Plan B medido**, solo si la segmentación nativa no alcanza la calidad acordada: evaluar un proceso auxiliar Python **offline y opcional** con Pillow/OpenCV/Shapely/Trimesh; requeriría propuesta y autorización, nunca se introduciría silenciosamente.

## 4. Arquitectura del Taller

```text
GameMolde / godot/app/
  main.gd + top_bar.gd (integración de pestaña; mínimos cambios)
  taller_assets/ (vistas y controladores; rutas definitivas tras auditoría)
       taller_view.gd        (pantalla, estados, cámara de previsualización)
       taller_controls.gd    (recetas, parámetros, modo seleccionado)
       taller_library.gd     (catálogo y acciones del usuario)

GameMolde / godot/addons/creador/ (núcleo reutilizable)
  taller_assets/ (carpeta propuesta; crear solo tras aprobación)
       asset_recipe.gd        (normalización/validación/versión de parámetros)
       asset_generator.gd     (contrato común: receta -> resultado)
       sword_generator.gd     (espada por secciones geométricas)
       image_mask.gd          (imagen -> máscara y bordes)
       silhouette_mesh.gd     (contorno -> malla extruida)
       shirt_generator.gd     (camiseta sobre base compatible)
       asset_validator.gd     (comprobar malla, dimensiones, etc.)
       asset_store.gd         (receta + GLB + miniatura, biblioteca)
       asset_equipper.gd      (anclajes/ropa; reutiliza PackLibrary si existe)

pruebas/taller_assets/ (scripts de prueba y fixtures)
```

**Las rutas son propuestas, no confirmación de que esos archivos existan.** El primer paso debe inspeccionar `body_view.gd`, `main.gd`, `glb_exporter.gd`, `character_updater.gd`, las piezas/pack disponibles y las pruebas actuales. Reutilizar clases existentes cuando hagan lo mismo; evitar copias de `PackLibrary`, `BodyPiece`, `GlbExporter` y el estado del personaje.

### Contrato de generación

Entrada conceptual: `AssetRecipe` (`format`, `version`, `id`, `modo`, `parametros`, `colores`, `fuentes`, `licencia`). Salida conceptual: `AssetResult` (`root_node/mesh`, `materiales`, `metadatos`, `anclaje`, `avisos`, `triangulos`, `dimensiones`). **Estos nombres son contratos propuestos**, no APIs ya implementadas. Los errores devuelven un resultado controlado; nunca una malla parcialmente corrupta.

```text
Interfaz -> Validación de receta -> Generador seleccionado -> Comprobación de malla
   -> Vista 3D -> [ajustes -> regeneración] -> Biblioteca -> Equipar / Exportar
```

- Cada generador debe ser **determinista**: misma receta e imagen producen misma geometría (no necesariamente bytes idénticos de un GLB si el exportador añade metadatos).
- Separar datos de geometría y de interfaz. El generador no puede abrir diálogos, usar red ni modificar al personaje.
- Parámetros con unidades y rangos, validados al inicio. Cambios de interfaz se agrupan para no regenerar al arrastrar cada píxel si el cálculo resulta pesado.
- Reutilizar los nombres de ranura de `ruta/ARQUITECTURA.md` (`ropa_torso`, `accesorio`, etc.). No crear otro catálogo incompatible.
- Edición posterior: **reabrir la receta**, no intentar deducir los parámetros a partir del `.glb` exportado.

### Receta JSON ilustrativa (pendiente de especificación final)

```json
{
  "formato": "gamemolde-asset-receta",
  "version": 1,
  "id": "espada_001",
  "modo": "espada_parametrica",
  "parametros": {"longitud_m": 1.0, "ancho_hoja_m": 0.09, "grosor_m": 0.018},
  "colores": {"hoja": "#B9C0C8", "guarda": "#77747A", "mango": "#514336"},
  "anclaje": {"ranura": "accesorio", "socket": "socket_hand_r"},
  "licencia": "propia"
}
```

Para el modo imagen se incluiría una **copia local de la imagen fuente** dentro de la carpeta del asset y su hash; no guardar rutas absolutas personales en la receta exportable. Las referencias externas/autorías deben quedar explícitas. El fichero `.glb` es el resultado para juegos; la receta y los recursos fuente son para **volver a editar**.

## 5. Algoritmos concretos

### 5.1 Espada paramétrica (prioridad 1)

- Construir **cuatro submallas o superficies**: hoja, guarda, empuñadura y pomo. Todas con geometría tridimensional.
- Hoja: anillos/secciones transversales a lo largo de **Y**, con contorno de punta y sección romboidal o biselada; conectar anillos con triángulos y cerrar los extremos. Longitud, ancho, estrechamiento y espesor parametrizables. No depender de la imagen para inferir volumen.
- Guarda: perfil o barra curvada muestreada por segmentos con una sección poligonal, o volúmenes trapezoidales unidos sin exigir booleanos complejos. Empuñadura: cilindro/prisma de pocas caras; pomo: prisma o bipirámide.
- Generar normales coherentes (facetadas para low-poly), materiales por pieza, coordenadas UV mínimas si aportan valor y **pivote de agarre** colocado en la empuñadura. El usuario podrá corregir posición/rotación respecto al socket.
- Convención de escala: **metros; Y arriba, frente +Z**. Validar escala en mano real del maniquí, no solo en visor aislado.

### 5.2 Imagen -> silueta -> extrusión (prioridad 2)

1. Cargar imagen de tamaño limitado (límite provisional, por ejemplo **1024 px en su lado mayor** para el procesamiento; reescalar solo la copia de trabajo). Mantener el original para referencia.
2. Si hay alfa útil, crear máscara por umbral alfa ajustable. Si no, proponer **color del fondo** desde las esquinas y permitir ajustar tolerancia y/o invertir máscara; los fondos complejos no están soportados en el MVP.
3. Tomar la componente conexa principal, rechazar máscaras vacías/minúsculas, registrar avisos si hay múltiples islas o agujeros (no se descartan en silencio).
4. Extraer el contorno exterior cerrado mediante seguimiento del borde o *marching squares*; normalizar la orientación, simplificar puntos (Douglas–Peucker, tolerancia ajustable) y comprobar autointersección.
5. Triangular el contorno simple en 2D con `Geometry2D.triangulate_polygon`; si falla, mostrar un error útil o permitir volver a simplificar la máscara. **La triangulación nativa de un polígono simple no resuelve por sí sola agujeros y múltiples contornos.**
6. Crear frente y espalda a ±profundidad/2 y coser las aristas laterales. Elegir eje coherente para que el plano de la imagen quede orientado hacia +Z, con Y hacia arriba. Corregir winding, generar normales y material.
7. Permitir ancho/alto en metros, grosor, simplificación, tolerancia de fondo y color. Mostrar el resultado girando 360°. El primer modo se denomina **«Extrusión»**; no venderlo como reconstrucción anatómica o fotogramétrica.

**Caso de prueba del chat:** la imagen de espada gris sobre fondo oscuro (20/11/2026). Con ella se evalúa extracción del contorno y conversión a un objeto con grosor. **No** se promete sacar por sí solo hoja, guarda y mango como piezas semánticas; para ello se usa la espada paramétrica o una edición manual futura.

### 5.3 Camiseta básica independiente (prioridad 3)

La camiseta **no** debe hacerse con la extrusión de una silueta frontal. Debe usar la geometría del personaje y su esqueleto.

**Ruta preferida, alineada con AB.3–AB.7 de la expansión:**

1. Auditar si están disponibles los **helpers** de MakeHuman (`helper-tights`) y si las formas usadas por GameMolde afectan sus vértices; comprobar pesos y licencia.
2. Si no existe aún la exportación de helpers, prepararla **fuera del runtime** con el pipeline Blender ya existente (código Blender con la licencia correspondiente). Recortar la región de **torso + mangas cortas** y obtener una malla con espesamiento visual mínimo, sin desgarros ni topología abierta inapropiada.
3. Conservar **pesos de huesos** y **formas compatibles** del cuerpo, o calcular transferencia medida si se parte de geometría derivada. Un `MeshInstance3D` de camiseta debe usar el **mismo `Skeleton3D`** que el cuerpo, no un esqueleto humanoide duplicado.
4. Aplicar la actualización corporal con el mecanismo ya existente (`CharacterUpdater`, `ShapeWeights`) en el orden previsto por el proyecto. Medir separación de la piel, clipping, escala y deformaciones.
5. Para el MVP, colores y un ajuste sencillo de holgura (pequeño desplazamiento respecto a la superficie). **No** agregar simulación de tela, pliegues físicos ni patrón personalizado.
6. Al vestir una camiseta, coordinar la **prenda base pintada** y ocultación de piel con el mecanismo disponible. La máscara general de piel oculta (AB.6) puede entrar como dependencia si las pruebas muestran clipping; no fingir que un offset lo soluciona todo.
7. Exportar el personaje y camiseta conjuntamente, reimportar y animar. Si la preparación de helpers tiene un bloqueo real, detener esa rama y proponer la opción mínima de **malla derivada del torso con pesos copiados**, con medidas; no reemplazar silenciosamente la camiseta por una textura sobre el cuerpo.

**Criterio de realidad:** la compatibilidad con *todos* los deslizadores de cuerpo, poses extremas y capas de ropa se alcanzará progresivamente. Para el MVP deben pasar al menos neutral + dos variaciones corporales representativas y una animación del proyecto, con informes medidos y revisión visual humana. Los comportamientos no soportados se anuncian.

## 6. Integración de interfaz y flujo de usuario

La nueva pestaña será **«Taller de Assets»** en la misma barra superior del programa (o acceso equivalente acordado tras auditar su anchura); **no** reemplaza `Ropa` ni `Accesorios`, que siguen siendo las pestañas para **equipar/seleccionar piezas existentes**. La pestaña Taller las **crea**.

Diseño siguiendo `diseno/GUIA_INTERFAZ.md`, colores del tema existente, sin inventar otro lenguaje visual:

- **Izquierda:** tipo de asset y modo (`Espada`, `Desde imagen`, `Camiseta`), y biblioteca/últimos resultados.
- **Centro:** visor orbital 3D, frente/perfil/¾, suelo/cuadrícula opcional, aviso de escala y recuento de triángulos; posibilidad de mostrar el maniquí como referencia sin regenerarlo.
- **Derecha:** controles del modo elegido, con valores numéricos y botón «Restablecer»; importación de imagen cuando proceda.
- **Acciones claras:** `Generar/Actualizar`, `Guardar en biblioteca`, `Equipar`, `Exportar GLB`, `Quitar/Volver`.
- Sin operaciones destructivas inesperadas: confirmar sustitución de una pieza, marcar cambios sin guardar, mantener deshacer si se integra con el historial de estado; no duplicar el gestor de deshacer sin auditarlo.

**Flujo:** entrar → elegir modo → editar parámetros → ver modelo → guardar receta y asset → equipar o exportar. Al reabrir desde biblioteca se recuperan los **parámetros**, no solo el GLB.

## 7. Biblioteca y compatibilidad con la expansión

Respetar `ruta/ARQUITECTURA.md` §6: packs en `res://packs/<id>/` (distribuidos con la app) y `user://packs/<id>/` (usuario); `pack.json` versionado con identificador, autor, licencia, lista de piezas, archivo, miniatura, `sha256`, ranura y transform de anclaje.

**Propuesta MVP:** `user://packs/taller_local/` (confirmar con la arquitectura del cargador), con una carpeta por asset o una estructura validada equivalente:

```text
user://packs/taller_local/
    pack.json
    espada_001.glb
    espada_001.png           # miniatura
    espada_001.receta.json   # edición reproducible
    fuentes/espada_001.png   # solo si procede del modo imagen
```

- No modificar `res://` en runtime ni dar por hecho que hay permisos de escritura.
- Evitar colisiones de ID, validar nombres/rutas y no ejecutar contenido importado.
- Guardado seguro: escribir temporalmente, comprobar, sustituir mediante la estrategia disponible del sistema de archivos; no corromper el pack al cerrar la app.
- Licencia y procedencia obligatorias: `propia` o `CC0-1.0` según el caso; **una obra importada no se convierte automáticamente en CC0**. Para activos de terceros, respetar lo que permite `CLAUDE.md` y registrar créditos.
- El `.glb` lleva materiales compatibles con glTF/PBR básico; el estilo toon de Godot puede acompañarse como `.tres` separado si hace falta. **No suponer que el shader propio viaja íntegro dentro de un GLB genérico.**
- `.gmolde` solo guarda referencias al pack/pieza/hash cuando esa fase exista; no incrustar geometría en el proyecto ni reemplazar el esquema aprobado.

## 8. Exportación y equipamiento

- **Espada/rigidez:** pivote en zona de agarre; attachment relativo al anclaje existente; comprobar que la espada **no hereda una escala deformante** durante una animación y que sigue a la mano.
- **Camiseta:** ranura `ropa_torso`, malla y pesos asociados al mismo esqueleto; sin duplicar huesos. Asegurar que la prenda se exporta junto al personaje y permanece animable al reimportar.
- **GLB independiente:** puede generarse sin personaje. **GLB combinado:** reutiliza la infraestructura de `glb_exporter.gd`/`character_baker.gd` y extiende el pipeline de forma aislada para múltiples piezas sin alterar los invariantes del rig.
- Probar siempre: archivos importables en **un proyecto vacío de Godot**, sin addon, y abrir muestras en **Blender**. Comprobar normas del personaje ya existentes (53 huesos, nombres, pesos ≤4 y suman 1) sin cambiar sus umbrales sin permiso.
- Para exportar se construye y valida una escena temporal limpia; se destruye después. **No** exportar directamente un árbol temporal de interfaz o nodos de la escena de edición que no pertenezcan al GLB.

## 9. Riesgos, límites y medidas

| Riesgo real | Protección / plan B |
|---|---|
| Imagen con fondo confuso o varios objetos | Mensaje claro; máscara manual/editada; no inventar geometría |
| Contorno con agujeros/autointersección | Rechazar en MVP o simplificar con aviso; agujeros para v2 |
| Volumen oculto imposible de inferir con una vista | Generación aproximada/extrusión y parámetros manuales, nunca «reconstrucción exacta» |
| Ropa incompatible con deslizadores | Medidas de desviación, lista de soportados; reutilizar helpers/formas y corregir antes de cerrar |
| Piel atravesando camiseta | Masking de piel/holgura medida; revisión en varias poses |
| Exportador pierde piezas, materiales, pivotes o pesos | Prueba de ida/vuelta GLB y proyecto vacío; no modificar el exportador de cuerpo sin prueba de regresión |
| GLTFDocument puede colgarse con attachments | Reproducción mínima y aislamiento según `PLAN.md` original, sin ocultar el bloqueo |
| Duplicar sistema de packs/proyecto | Auditar Fase 10–11/AB antes de escribir; extender sus contratos |
| Congelar interfaz con imágenes | Límite de tamaño; procesamiento diferido si se mide un problema, sin threads prematuros |
| Dependencias o licencias contaminadas | Solo Godot/runtime nativo; código propio MIT; pipeline Blender aislado y créditos |
| Ampliación excesiva | La lista MVP es fija; ideas nuevas a `ideas.md` y solo entran con aprobación |

**Presupuesto inicial (objetivos provisionales, no datos medidos):** espada paramétrica y extrusión de silueta de pocos miles de triángulos; camiseta acorde con la malla fuente sin aumentar innecesariamente el total. Mostrar el recuento real, memoria usada y latencia de regeneración; fijar límites definitivos tras un primer prototipo medido, **sin alterar tolerancias de pruebas existentes**.

## 10. Hitos de entrega y definición de terminado

| Hito | Entregable verificable |
|---|---|
| H0 — Auditoría/contratos | Inventario del código existente, dependencias reales y ficha técnica aprobada |
| H1 — Taller visible | Pestaña integrada + visor y parámetros, sin regresiones en Cuerpo |
| H2 — Espada 3D | Espada paramétrica con cuatro partes, materiales, pivote y pruebas |
| H3 — Imagen 2D | PNG simple → silueta → extrusión, con ajustes y controles de error |
| H4 — Biblioteca | Asset/receta/miniatura guardados, recargados y editables |
| H5 — Equipamiento rígido | Espada en mano, animación y exportación con personaje |
| H6 — Camiseta | Malla 3D separada con formas/pesos compatibles y vista en cuerpo |
| H7 — Exportación combinada | Camiseta + espada + personaje exportados y reimportados |
| H8 — QA/documentación | Pruebas de regresión, capturas para juicio visual y uso explicado |

**El MVP se acepta solo cuando:**

- [ ] El Taller abre y cierra sin afectar Cuerpo, ajustes, guardado previo ni exportación antigua.
- [ ] Una espada paramétrica **con grosor** se genera, gira, se equipa y se exporta como GLB.
- [ ] Un PNG simple **genera una extrusión real**, no un plano; entradas imposibles muestran error legible.
- [ ] Una camiseta **es una malla separada**, sigue el cuerpo en las pruebas acordadas y no pierde skinning al exportar.
- [ ] Se guardan y reabren, desde `user://`, al menos una espada, una extrusión y una camiseta con sus recetas.
- [ ] Un personaje con espada y camiseta reimporta sin perder componentes principales, rig ni materiales de base.
- [ ] Se han ejecutado pruebas automáticas y una revisión visual aprobada por el responsable.
- [ ] La app es **100 % funcional sin IA y sin conexión**.

**Ejemplos de invocación existentes:** `godot --path godot` y `godot --headless --path godot -- --autoprueba`. Las pruebas nuevas estarán en `pruebas/taller_assets/` y cada script documentará su comando concreto. No afirmar resultados antes de ejecutarlas.

## 11. Camino posterior al MVP

1. Más plantillas rígidas (escudo, hacha, martillo, casco, hombreras, botas sencillas) usando el mismo contrato de recetas.
2. Extrusión por **regiones y múltiples piezas**, bisel básico, agujeros y modo vóxel para sprites sencillos.
3. **Dos o más imágenes ortográficas** con alineación guiada → intersección de siluetas / visual hull → malla; no usar ese método para fotos en perspectiva sin calibración.
4. Ropa ajustable, más prendas, mangas, accesorios corporales y transferencia de formas según la ruta AB de GameMolde.
5. Solo después: interfaz de herramientas para un agente y una **skill de diseño 3D** capaz de generar recetas y llamar operaciones **seguras y validadas** del Taller. La IA no modifica el núcleo ni es necesaria para usarlo.

Todas las extensiones, con prioridad y coste, se desarrollan en `ideas.md`.

## 12. Fuentes y referencias utilizadas

**Documentación del proyecto (revisada 20/11/2026):**

- [Repositorio GameMolde / Character_Creator](https://github.com/m-xarxatec/Character_Creator)
- [README.md](https://github.com/m-xarxatec/Character_Creator/blob/main/README.md) — versión, exportación, rig y anclajes.
- [PLAN.md original](https://github.com/m-xarxatec/Character_Creator/blob/main/PLAN.md) — estado y pruebas existentes.
- [IDEAS.md original](https://github.com/m-xarxatec/Character_Creator/blob/main/IDEAS.md) — desarrollo futuro general.
- [CLAUDE.md](https://github.com/m-xarxatec/Character_Creator/blob/main/CLAUDE.md) — protocolo de aprobación, fichas, licencias y Git.
- [Expansión v2](https://github.com/m-xarxatec/Character_Creator/blob/main/propuestas/expansion_v2.md) — AB.1–AB.7, AB.11–AB.13.
- [ARQUITECTURA.md](https://github.com/m-xarxatec/Character_Creator/blob/main/ruta/ARQUITECTURA.md) — estado, `.gmolde`, packs y piezas.
- [GUIA_INTERFAZ.md](https://github.com/m-xarxatec/Character_Creator/blob/main/diseno/GUIA_INTERFAZ.md) — estructura y tokens de la UI.
- [main.gd](https://github.com/m-xarxatec/Character_Creator/blob/main/godot/app/main.gd) — pestañas existentes.

**Referencia visual de la conversación:** ilustración proporcionada por el usuario de una espada low-poly gris sobre fondo gris oscuro (20/11/2026); referencia de prueba, **no archivo ya añadido al repositorio**.

**APIs y ejemplos técnicos:**

- [Godot Geometry2D](https://docs.godotengine.org/en/stable/classes/class_geometry2d.html)
- [Godot GLTFDocument](https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html)
- [Godot runtime file loading/saving](https://docs.godotengine.org/en/stable/tutorials/io/runtime_file_loading_and_saving.html)
- [Godot SurfaceTool](https://docs.godotengine.org/en/stable/classes/class_surfacetool.html)
- [Godot ArrayMesh](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html)

**Open source estudiado en la conversación (solo inspiración, no dependencias aprobadas):**

- [Vectify](https://github.com/atdotslash/Vectify) — contornos, polígonos y extrusión.
- [GLBForge](https://github.com/glbforge/glbforge) — extrusión geométrica y tratamiento de texturas; **no integrar IA**.
- [ReliefDrop](https://github.com/kcgdz/ReliefDrop) — procesamiento por capas/relieve y exportación GLB/OBJ; solo referencia.
- [Roxel](https://github.com/starzonmyarmz/roxel) — ideas de representación voxel; referencia futura.
- [Drawing to 3D Agent](https://github.com/nyyyaomi/drawing-to-3d-agent) — intersección de siluetas/multivista; solo investigación.
- [2D-to-3D-Converter](https://github.com/Fatcatcreate/2D-to-3D-Converter) — reconstrucción multivista y vóxeles; **licencia por verificar**.
- [2D-to-3D Voxelizer](https://github.com/GazPrash/2d-to-3d-voxelizer) — voxeles y edición, referencia futura.

> **Regla de fuente:** los elementos de la expansión y la arquitectura son diseños existentes del repositorio; los nombres de módulos, recetas, hitos y algoritmos de este documento son **propuestas nuevas** para el Taller. Codex verificará en código la implementación real antes de añadir o reutilizar componentes.
