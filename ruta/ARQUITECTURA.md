# ARQUITECTURA — cómo crece el núcleo sin rehacerlo

> Propuesta de la sesión de traspaso (2026-11-16). Nada se aplica sin aprobación.
> Todo lo que cito de Godot y no pude comprobar hoy va marcado **NO VERIFICADO**. Base de mi conocimiento: documentación de Godot 4.4 (la que enlaza `CLAUDE.md`); el proyecto usa 4.7.2.
> Idea central: **el personaje es un diccionario de estado; todo lo demás se recalcula desde él.** Así el mismo estado sirve para Deshacer, para el preset, para el proyecto compartido y para Android.

---

## 0. Tres conceptos que hay que tener claros

| Concepto | Qué es | Dónde vive |
| --- | --- | --- |
| **Estado del personaje** | Un `Dictionary` con todo lo que el usuario ha elegido: `valores`, `prenda_visible`, `colores`, `acabado` y, más adelante, `piezas`, `pose` y `capas`. | En memoria (la interfaz). Se guarda como preset o dentro de un proyecto. |
| **Personaje vivo** | La malla de `datos/` con sus formas en la GPU y el esqueleto reajustable. Caro en memoria. Solo hay **uno**: el que se está editando. | `SpeciesData` + `CharacterUpdater`. |
| **Personaje horneado** | Malla sin formas, huesos con escala 1 y anclajes como nodos. Barato. Es lo que se exporta, lo que se anima en el banco de pruebas y lo que se posa en el estudio. | `GlbExporter.build()`. |

Regla: **solo se edita el vivo; solo se anima, se posa y se exporta el horneado.** Evita que el editor y el `.glb` se comporten distinto (la diferencia medida en el 3.6.3 es de hasta 20,1 mm).

Claves del estado y paso en que aparecen:

```
estado = {
  "valores": {"gender": 0.5, "hand_size_l": 0.5, …},              # 4.4
  "prenda_visible": true,                                         # 4.5
  "colores": {"skin_color": Color, "garment_color": Color},       # 4.7
  "acabado": {"softness": 0.04, "rim_strength": 0.25, "rim_width": 0.3,
              "width_px": 2.5, "mid_shade": 0.9, "shadow_shade": 0.73},   # 4.7
  "piezas": [...],   # Fase 11      "pose": {...},   # Fase 10      "capas": {...}   # Fase 16
}
```

Una clave que falta vale su valor por defecto. Así un estado viejo sigue sirviendo cuando se añaden claves.

---

## 1. Formato de proyecto compartido (PC ⇄ Android)

**Nombre y extensión:** «proyecto de GameMolde», archivo `.gmolde` (D17). Es **texto JSON en UTF-8**, un solo archivo. El lector lo reconoce por el campo `formato`, no por la extensión.

**Relación con el preset:** el proyecto **contiene** el preset v2 del paso 4.7 sin cambiarlo, dentro de cada personaje. `Preset.from_dict()` se reutiliza tal cual. Un preset es «solo el cuerpo y su acabado»; un proyecto es «uno o más personajes, con sus piezas y poses, en una escena».

```json
{
  "formato": "gamemolde-proyecto",
  "version": 1,
  "programa": "0.2.0",
  "nombre": "Heroína",
  "miniatura": "<PNG de 256 px en base64; opcional>",
  "personajes": [
    {
      "id": "p1",
      "preset": {"version": 2, "especie": "humana", "nombre": "…", "valores": {}, "colores": {}, "acabado": {}, "prenda_visible": true},
      "piezas": [
        {"pack": "base", "pieza": "coleta_01", "sha256": "…", "ranura": "pelo",
         "hueso": "Head", "transform": [0, 0, 0, 0, 0, 0, 1, 1], "colores": {"principal": [0.2, 0.1, 0.1]}}
      ],
      "pose": {"huesos": {"LeftUpperArm": [0, 0, 0.38, 0.92]}, "cadera": [0, 0, 0]},
      "capas": {},
      "posicion": [0, 0, 0],
      "giro_y": 0
    }
  ],
  "escena": {
    "fondo": {"tipo": "color", "color": [0.32, 0.33, 0.36], "transparente": false},
    "luces": [{"tipo": "direccional", "color": [1, 1, 1], "energia": 1.0, "giro": [-40, 30], "animacion": null}],
    "camaras": [{"nombre": "Frente", "objetivo": [0, 1, 0], "giro": [0, 10], "distancia": 3.2, "fov": 35, "ortografica": false}],
    "camara_activa": 0
  }
}
```

- `transform` de una pieza: posición (3), giro como cuaternión (4) y escala uniforme (1), relativos al hueso.
- `pose.huesos`: por cada hueso movido, el **giro en el espacio del mundo respecto a la pose T** (cuaternión). No depende de los ejes locales del hueso (ver §2.3). Un hueso que falta sigue a su padre. `cadera`: desplazamiento de la cadera, en fracción de su altura en reposo (así vale para cualquier estatura).
- `animacion` de una luz: `null` o `{"tipo": "orbita" | "pulso" | "parpadeo" | "ciclo_color", "velocidad": 1.0, "amplitud": 1.0}`.

**Qué guarda:** valores, acabado, piezas (por referencia: pack + pieza + `sha256`), pose, luces, cámaras, fondo y miniatura.
**Qué no guarda:** mallas, texturas, el historial de Deshacer, la disposición de la ventana ni rutas absolutas. Todo lo que se puede recalcular desde `datos/` y los packs se recalcula.

**Piezas que faltan en el otro aparato:** el proyecto se abre igual; la pieza sale en una lista de avisos («falta la pieza coleta_01 del pack base») y se conserva en el archivo al guardar. Nunca se borra en silencio.

**Piezas propias del usuario** (un `.glb` importado): no viajan en el `.gmolde`. Para llevarlas hay un segundo formato, `.gmoldez`: un ZIP con `proyecto.gmolde` y la carpeta `packs/usuario/`. Se escribe con `ZIPPacker` y se lee con `ZIPReader` (existen en Godot 4; uso en Android **NO VERIFICADO**). Va en la Fase 13, no antes.

**Versión y migraciones:** cada bloque lleva su versión: `version` (proyecto) y `preset.version`. Al abrir:

1. Si `formato` no es `gamemolde-proyecto` → error.
2. Si `version` es **mayor** que la del programa → error «este proyecto es de una versión más nueva; actualiza el programa» (D18).
3. Si es menor → se pasa por la cadena `ProjectFile.MIGRATIONS` (v1→v2, v2→v3…), una función pequeña por salto.
4. Cada preset interior se migra con `Preset.migrate()`.

```gdscript
# godot/addons/creador/project_file.gd  (Fase 10; núcleo, sin interfaz)
class_name ProjectFile
const FORMAT := "gamemolde-proyecto"
const VERSION := 1
static func to_text(project: Dictionary) -> String              # claves ordenadas: mismo proyecto, mismo texto
static func from_text(text: String) -> Dictionary               # {error, proyecto, avisos: Array[String]}
static func migrate(data: Dictionary) -> Dictionary             # {error, data}
```

**Cómo se pasa entre aparatos** (de más barato a más caro):

| Vía | Cómo | Coste | Fase |
| --- | --- | --- | --- |
| **Código de personaje** | Texto corto copiable (por ejemplo `GM1-…`): versión + valores a 1 byte cada uno + colores + acabado, en base64 URL, con suma de control. Se copia con `DisplayServer.clipboard_set()` y se pega en el otro aparato. Solo el cuerpo y su acabado, sin piezas ni pose. Unos 150 caracteres. | S | 10.12 |
| **Archivo** | Guardar `.gmolde` y pasarlo por cable, correo o mensajería. | S | 10.2 |
| **Carpeta en la nube** | El programa no habla con ninguna nube. Se guarda en una carpeta que el usuario sincroniza (Syncthing, Drive). En Android, el selector del sistema ya muestra los proveedores de nube (**NO VERIFICADO** en Godot 4.7). | 0 | 15.5 |
| **Código QR** | Mostrar el código de personaje como QR en la pantalla del PC. Generarlo es código propio (unas 300 líneas). **Leerlo** con la cámara dentro de la app pide cámara y decodificador: no lo haría; el móvil lo lee con su app de cámara y el texto se pega. | M | Opcional |

---

## 2. Capas de deformación y su orden

Orden único, siempre el mismo. Las capas 1, 2 y 4 existen hoy (`CharacterUpdater.update`).

| # | Capa | Qué cambia | Dónde se aplica | Estado |
| --- | --- | --- | --- | --- |
| 1 | **Formas** | Vértices (formas en la GPU) | `ShapeWeights.apply` | Hecho |
| 2 | **Reajuste** | Posición y giro de reposo de cada hueso y sus *bind poses* | `SkeletonRefit.apply` | Hecho |
| 3 | **Largo de hueso** | Mueve las articulaciones de los descendientes a lo largo del hueso | Dentro del reajuste, tras calcular las posiciones | Fase 16 |
| 4 | **Proporción** | Escala uniforme en la pose; la heredan los hijos | `Proportions.apply` | Hecho |
| 5 | **Grosor y largo propios** | Escala no uniforme **en la *bind pose***; no la heredan los hijos | `SkeletonRefit.apply`, al escribir las *bind poses* | Fase 16 |
| 6 | **Escultura libre** | Desplazamientos por vértice, en reposo | Forma propia añadida a la malla | Fase 16 |
| 7 | **Pose** | Giros de la pose | `WorldPose.apply` (o `TPose.apply`) | 5.2 / Fase 10 |
| 8 | **Piezas** | Siguen al mismo esqueleto; la ropa lleva las mismas formas | `ShapeWeights.apply` sobre cada prenda | Fases 11–13 |

### 2.1 Por qué no se rompen los pesos ni la exportación

- **Ninguna capa toca los pesos** (4 influencias que suman 1) **ni el número o el orden de los huesos humanoides.** Solo cambian vértices, reposos, *bind poses* y poses.
- Al exportar, `CharacterBaker` pasa las capas 1 a 7 a los vértices y deja el esqueleto con escala 1 y pose igual al reposo. El `.glb` nunca lleva formas ni escalas, haya las capas que haya. Las pruebas actuales (`probar_personaje_horneado.gd`, `probar_exportar.gd`) siguen valiendo sin cambios.

### 2.2 Largo y grosor por separado (capas 3 y 5): el diseño

El problema: en `Skeleton3D`, la escala de un hueso la heredan sus hijos, y la pose es posición + giro + escala (sin cizalla). Una escala no uniforme en un hueso deforma a los hijos en cuanto giran.

La solución usa algo que ya hay: la matriz con la que Godot mueve cada vértice es `pose global del hueso × bind pose`. La *bind pose* es un `Transform3D` completo, propio de cada personaje (`species_data.gd:69` duplica la `Skin`) y **no se hereda**. `SkeletonRefit.apply` ya la reescribe en cada cambio (`skeleton_refit.gd:43`).

1. **Grosor** `g` y **largo** `l` de un hueso: se construye `S`, una escala `l` a lo largo del eje del hueso y `g` en las dos direcciones perpendiculares. El eje se **calcula** (cola − cabeza de `articulaciones.json`, llevado al espacio local del hueso); no se supone que sea el eje Y.
2. La *bind pose* pasa a ser `S × inversa(reposo global)`. Los vértices del hueso engordan o se alargan alrededor de su cabeza. Los hijos no heredan nada.
3. **Largo:** además, todos los descendientes se trasladan `(l − 1) × (cola − cabeza)` en la etapa de posiciones (capa 3), para que el hueso siguiente empiece donde acaba el estirado.
4. En las articulaciones, un vértice con peso en dos huesos mezcla las dos posiciones: la transición sale suave sin hacer nada más.
5. **Asimetría:** las claves ya llevan `_l` y `_r`. No hay que hacer nada nuevo.

En la tabla es una fila de tipo Proporción (D23) con prefijo nuevo: `largo:UpperArm=0.7` / `largo:UpperArm=1.5`, o `grosor:…`. Hoy `Proportions._parse` solo entiende `escala:`.

Coste en ejecución: cero por fotograma. Riesgos: (a) la GPU transforma las normales con la misma matriz, así que con `g ≠ l` la luz en vivo es algo inexacta; al exportar, `MeshBaker` debe usar la inversa traspuesta (su cabecera ya lo avisa); (b) el diseño está razonado, **no probado**: el paso 16.1 empieza con una prueba de un solo hueso.

### 2.3 La pose se guarda en el mundo

Una pose se guarda como «cuánto ha girado cada hueso, en el espacio del mundo, respecto a la pose T». Ventajas: no depende de los ejes locales del hueso (que cambiarán si se aprueba el 5.7), vale entre personajes de proporciones distintas y es la misma operación que copiar una animación de otro esqueleto.

```gdscript
# godot/addons/creador/world_pose.gd  (paso 5.2; ficha A3)
class_name WorldPose
## deltas: {hueso: Quaternion}. Parte siempre del reposo: aplicarla dos veces da lo mismo.
static func apply(skeleton: Skeleton3D, deltas: Dictionary) -> void
## Lee la pose actual como deltas respecto al reposo.
static func capture(skeleton: Skeleton3D) -> Dictionary
## Copia la pose de otro esqueleto que esté en la misma pose de reposo (banco de pruebas, 5.1).
static func copy(source: Skeleton3D, target: Skeleton3D, names: PackedStringArray) -> void
```

Algoritmo de `apply`, de padre a hijo: `global = delta × reposo_global`; `local = inversa(global del padre ya girado) × global`; se escribe solo el giro.

### 2.4 Escultura libre (capa 6) y el límite de las formas en la GPU

- Godot guarda cada forma completa para todos los vértices. Con 159 formas y 14.517 vértices son decenas de MB en la tarjeta (estimación en `RENDIMIENTO.md`; sin medir).
- No conozco ninguna API para cambiar **una** forma de una malla ya creada (**NO VERIFICADO**). Añadir la forma «escultura» obliga a reconstruir la superficie con todas sus formas.
- Diseño: en modo escultura se trabaja sobre una copia estática en CPU (rápida: `ArrayMesh.surface_update_vertex_region`); el resultado se guarda en el proyecto como lista dispersa `{índice de vértice: [dx, dy, dz]}` en reposo; al salir del modo, la malla viva se reconstruye una vez.
- Si la cara pasa de unas 300 formas o Android se queda sin memoria, la salida es **formas dispersas** (paso 16.4): guardar las formas en CPU con solo los vértices que mueven y subir a la GPU solo las del deslizador que se arrastra. Es un cambio grande (XL, fuerte). No se hace sin una medida que lo pida.

---

## 3. Huesos extra opcionales (cola, alas, orejas, brazos extra)

Reglas para no romper el perfil humanoide ni el retargeting:

1. Los 53 huesos humanoides **no cambian** de nombre, de padre ni de orden. Los extra se añaden **al final** de la lista.
2. Un hueso extra siempre cuelga de un hueso humanoide o de otro extra. **Nunca se mete entre dos humanoides.**
3. Nombre: `x_<pieza>_<n>` (por ejemplo `x_cola_01`). El prefijo `x_` los distingue en pruebas y en el BoneMap (quedan sin mapear; el retargeting de Godot los deja como están: **NO VERIFICADO** en 4.7).
4. Los huesos extra **vienen con la pieza**: el `.glb` de una cola trae su cadena de huesos y su malla con pesos. Al ponerla, `PieceAttacher.merge()` copia esos huesos al esqueleto del personaje (hijos del hueso de anclaje) y reapunta la `Skin` de la pieza por nombre. Queda **un solo `Skeleton3D`**: un solo esqueleto en el `.glb`, y `SpringBoneSimulator3D` trabaja sobre él.
5. Física: la ficha de la pieza describe las cadenas (§6). El `.glb` no transporta la física; viaja en una escena `.tscn` junto al `.glb` (Fase 11.4).
6. Presupuesto: `GUIA_ESTILO.md` §7 propone 75 huesos en PC y 60 en móvil. El banco de pruebas avisa al pasarlos.
7. Brazos extra: no los mueve ninguna animación humanoide. Se posan a mano o copian el giro de los brazos reales con un modificador (**NO VERIFICADO**: nodo adecuado en 4.7).

```gdscript
# godot/addons/creador/piece_attacher.gd  (Fase 13.6)
## Copia los huesos de la pieza al esqueleto del personaje, colgados de parent_bone. Devuelve {nombre viejo: nombre nuevo}.
static func merge(character: Skeleton3D, piece: Skeleton3D, parent_bone: String, offset: Transform3D, prefix: String) -> Dictionary
```

---

## 4. Anclajes en cualquier hueso

- Los 4 anclajes de hoy (`socket_*`) son huesos de `datos/` con nombre en el manifiesto. Se quedan como **anclajes sugeridos**: posiciones buenas por defecto que siguen al cuerpo.
- Una pieza se puede poner en **cualquier** hueso: el proyecto guarda `hueso` + `transform` relativo (§1). En escena es un `BoneAttachment3D` con la pieza dentro, igual que hacen hoy los anclajes exportados (`sockets.gd`).
- **Acople al soltar** (13.2): (1) rayo desde el cursor contra el personaje **horneado**; (2) triángulo tocado → su vértice más cercano; (3) de sus 4 pesos, el hueso de mayor peso; (4) la pieza queda hija de ese hueso, con el origen en el punto tocado y orientada con la normal.
  El rayo se calcula en CPU con `Geometry3D.ray_intersects_triangle` sobre los 26.756 triángulos (decenas de ms: vale al soltar, no en cada fotograma). Con física (`intersect_ray` y su `face_index`) sería más rápido: **NO VERIFICADO**.
- La escala del hueso no afecta a la pieza, porque en el horneado todos los huesos tienen escala 1 (lo comprueba el paso 5.6).

---

## 5. Especies y bases

| Común a todas (código del núcleo) | Propio de cada especie (carpeta `datos/<especie>/`) |
| --- | --- |
| Formato de `datos/`, pesos de formas, reajuste, Proporción, horneado, anclajes, exportación, preset y proyecto | `cuerpo.glb`, `articulaciones.json`, `deslizadores.csv`, `presets/`, `manifiesto.json` |
| Material y estilos | Lista de huesos y de anclajes (ya en el manifiesto) |
| Interfaz: el panel se monta solo desde la tabla | Zonas y deslizadores (ya en la tabla) |

**Sitios donde hoy el código supone «humana»** (auditoría; no cambiar nada hasta que exista la segunda especie, paso 16.3):

| Dónde | Suposición | Arreglo cuando toque |
| --- | --- | --- |
| `godot/app/body_view.gd:13` | `SPECIES := "humana"` | Elegir especie al crear el personaje |
| `godot/addons/creador/species_data.gd:14` | Preset de inicio `presets/anime.json` | Campo del manifiesto |
| `godot/addons/creador/t_pose.gd:21-26` | Nombres de brazo, mano y dedos | Solo si el manifiesto dice `"pose_t": true` |
| `godot/addons/creador/style_normals.gd` (`head_weights`) | Hueso `Head` | Campo del manifiesto |
| `godot/addons/creador/proportions.gd:53` | Lados = prefijos `Left` y `Right` | Vale para toda especie con esos nombres; documentarlo en `FORMATO.md` |
| `species_data.gd:58`, `mesh_baker.gd`, `glb_exporter.gd:34` | Una malla, un esqueleto, superficie 0 | Regla del formato: se mantiene |
| `godot/app/slider_panel.gd:10` | Zona `Cara` oculta | Se quita en el 9.1 |

Cuando llegue, el manifiesto (versión nueva) añade: `"capacidades": {"perfil": "humanoide", "pose_t": true, "cabeza": "Head", "preset_nuevo": "presets/anime.json"}`.

**Bases de estilo** (chibi, heroico, esbelto): son especies con la misma lista de huesos y otra malla o tabla. Una base **no se cambia a mitad de edición** (ya decidido en `IDEAS.md`).

**Límites del proyecto, como lista de revisión de cada especie o base nueva:** edades de 5 a 60 años (D42); sin detalle anatómico bajo la prenda base; assets CC0 o propios. Va en la ficha de la especie y la comprueba el responsable. El código no puede comprobarlo.

---

## 6. Piezas y packs

Un pack es una carpeta. Los de serie van en `res://packs/<id>/`; los del usuario, en `user://packs/<id>/`.

```
packs/base/
  pack.json
  coleta_01.glb
  coleta_01.png        # miniatura de 256 px
```

```json
{
  "formato": "gamemolde-pack", "version": 1,
  "id": "base", "nombre": "Pack base", "autor": "GameMolde", "licencia": "CC0-1.0", "origen": "https://…",
  "piezas": [
    {"id": "coleta_01", "nombre": "Coleta", "tipo": "pelo", "ranura": "pelo", "especies": ["humana"],
     "archivo": "coleta_01.glb", "sha256": "…", "miniatura": "coleta_01.png",
     "anclaje": {"hueso": "Head", "transform": [0, 0, 0, 0, 0, 0, 1, 1]},
     "sigue_al_cuerpo": false,
     "fisica": [{"raiz": "x_coleta_01", "fin": "x_coleta_04", "rigidez": 1.0, "arrastre": 0.4, "gravedad": 0.1, "radio": 0.02}],
     "colores": ["principal"]}
  ]
}
```

- **Tipo:** `pelo`, `ropa`, `accesorio`, `ojos`, `cejas`. **Ranura:** una sola pieza por ranura (`pelo`, `cejas`, `ojos`, `ropa_interior`, `ropa_torso`, `ropa_piernas`, `ropa_pies`, `ropa_exterior`), salvo `accesorio`, que admite varias.
- **Licencia:** obligatoria, con identificador SPDX. El cargador **rechaza** el pack si no está en la lista permitida: `["CC0-1.0", "propia"]` (CC-BY solo si se aprueba D19). Autor y licencia se muestran solo en el panel de Créditos (D45), no junto a la pieza.
- `sha256` por pieza: el proyecto lo copia. Si al abrir no coincide, sale un aviso.
- **Ropa** (`"sigue_al_cuerpo": true`): el `.glb` trae formas con **los mismos nombres** que el cuerpo. En ejecución basta `ShapeWeights.apply(prenda, pesos)`. Esas formas las calcula una herramienta al crear el pack (12.1), no el editor. Las formas que no afectan a la prenda no se guardan; `ShapeWeights.apply` ya ignora las que faltan (`shape_weights.gd:61-71`).
- **Piezas sin archivo** (2026-11-21, pasos AB.5, AB.9a y AB.11): `derivada` {mascara, separacion} (caras de la piel, `BodyDerived`), `corte` {de, brazos, piernas, torso, quitar} (recorte de otra pieza del pack, `GarmentCut`) y `generador` {tipo, parametros, simetria} (accesorio rígido, `RigidPiece`). Ver `godot/packs/base/LEEME.md`.
- **Carga en caliente:** `PackLibrary.scan()` vuelve a leer las dos carpetas. Se llama al arrancar, con un botón «Actualizar» y cuando la ventana recupera el foco (`NOTIFICATION_APPLICATION_FOCUS_IN`). Las piezas se abren con `GLTFDocument`, como `cuerpo.glb`.

```gdscript
# godot/addons/creador/pack_library.gd  (Fase 11.1)
class_name PackLibrary
const LICENSES := ["CC0-1.0", "propia"]
func scan(folders: PackedStringArray) -> Array[String]            # devuelve los avisos (pack rechazado y por qué)
func pieces(type := "", species := "") -> Array[Dictionary]       # fichas, para la interfaz
func load_piece(pack_id: String, piece_id: String) -> Node3D      # null si falta o si el sha256 no coincide
```

---

## 7. Escena del estudio

- La escena son **datos** (bloque `escena` del §1). Un solo archivo del núcleo, `studio_scene.gd`, la convierte en nodos y al revés: `StudioScene.build(data, parent)` y `StudioScene.capture(parent) -> Dictionary`.
- **Luces:** `DirectionalLight3D`, `OmniLight3D` y `SpotLight3D` con color y energía. La animación de luces es una función pura `StudioScene.animate(light_data, t) -> Dictionary` (órbita, pulso, parpadeo, ciclo de color): se puede probar sin ventana.
  Aviso: `toon.gdshader` hoy no multiplica por `ATTENUATION` (`toon.gdshader:45`), así que una luz omni no pierde fuerza con la distancia ni proyecta sombra sobre el cuerpo. Añadirlo cambia el aspecto aprobado: es el paso 10.6, con juicio visual.
- **Fondos:** color, degradado (shader de cielo propio) o transparente (`SubViewport.transparent_bg`). Cielos HDRI CC0 más adelante: pesan y en móvil cuestan.
- **Cámaras guardadas:** los mismos números que ya tiene `orbit_camera.gd` (`target`, `yaw`, `pitch`, `distance`), más `fov` y `ortografica`.
- **Varios personajes:** cada uno es un bloque de `personajes`. En el estudio todos son **horneados**. Solo se pasa a «vivo» el que se edita. Límite propuesto: 4 en PC y 2 en Android, a medir.
- La especie se carga **una vez**: `SpeciesData` guarda la escena y el segundo personaje la duplica (hoy cada carga vuelve a leer los 15,9 MB; 695 ms medidos).

---

## 8. Funciones por plataforma

Un solo archivo de la interfaz decide qué hay. Nadie más pregunta por la plataforma.

```gdscript
# godot/app/platform.gd  (Fase 15.2; es de la interfaz, no del núcleo)
static func is_mobile() -> bool: return OS.has_feature("mobile")
static func can(feature: String) -> bool   # consulta la tabla FEATURES de abajo
```

| Función (`feature`) | Linux y Windows (`pc`) | Android (`android`) |
| --- | --- | --- |
| `editar_cuerpo`, `editar_cara` (deslizadores) | Sí | Sí, condicionado a la medida (D20) |
| `estudio` (posar, cámara, luces, imágenes) | Sí | Sí |
| `abrir_proyecto`, `guardar_proyecto` | Sí | Sí |
| `exportar_glb`, `exportar_vrm` | Sí | **No** |
| `banco_de_pruebas` | Sí | No |
| `importar_pieza`, `escultura` | Sí | No |
| `packs_usuario` | Sí | Más adelante |
| `alta_resolucion` | Hasta 8K | Hasta 4096 px (límite típico de textura en móvil; **NO VERIFICADO**) |

Etiquetas de Godot que se usan: `pc`, `mobile`, `android`, `windows`, `linux`. Para probar el modo móvil en el PC: una etiqueta propia `estudio` en las *custom features* del preset de exportación, o `--feature estudio` (**NO VERIFICADO** el argumento en 4.7).

El núcleo no consulta nada de esto. La prueba `probar_ventana.gd` ya vigila que el núcleo no nombre `app/`.

---

## 9. Cambios mínimos antes de cerrar el MVP

Cada uno es una propuesta. Las que tienen ficha propia están en `pasos/`.

| Código | Cambio | Qué desbloquea | Coste | Ficha |
| --- | --- | --- | --- | --- |
| **A1** | `.gitattributes`: los archivos de `datos/` no cambian sus finales de línea | Clonar en Windows sin romper el `sha256` | S (2 líneas) | `pasos/A1_gitattributes.md` |
| **A2** | `datos/` dentro del proyecto de Godot (`godot/datos/`), importada como «Keep File», y un único sitio que la busca | Builds de Linux, Windows y Android; uso como plugin | M (unos 25 archivos, cambio mecánico) | `pasos/A2_datos_en_el_proyecto.md` |
| **A3** | `WorldPose` en el núcleo: la pose como giros en el mundo | Poses del 5.2, banco de pruebas, estudio, formato de proyecto | S–M (1 archivo + prueba) | `pasos/A3_pose_en_mundo.md` |
| **A4** | El estado del personaje como diccionario único, y `Preset.migrate()` como cadena | Deshacer en todas partes, proyecto compartido, Android | 0 extra: es la forma de hacer el 4.4 y el 4.7 | `pasos/A4_estado_y_migraciones.md` |
| A5 | `GlbExporter.build(…, with_texture := true)`: poder construir el personaje horneado sin hornear la textura (1,5 s) | Vista previa y banco de pruebas rápidos | S | Dentro de la ficha 4.5 |
| A6 | Las pruebas de la interfaz que usen recursos importados se lanzan con `--path godot` | Animaciones y packs dentro de la app | 0 (convención) | `GUIA_MODELOS.md` |
| A7 | Fijar el renderizador en `project.godot` | Que el aspecto no dependa del valor por defecto | S | Tras el 5.13 (`PLATAFORMAS.md` §3) |

Lo que **no** hace falta tocar antes del MVP: anclajes en cualquier hueso, huesos extra, packs, especies y capas 3, 5 y 6. Caben con lo de arriba sin reescribir nada.
