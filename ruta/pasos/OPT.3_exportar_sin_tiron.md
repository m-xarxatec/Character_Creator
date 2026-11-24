# OPT.3 — Exportar sin tirón

> Ficha del 2026-11-24 (nivel: fuerte). **Pendiente de aprobación del responsable.** Sale de AC.6b: el responsable pide que todo sea fluido «bajo cualquier medio o método». P.1 llevó al hilo lo más pesado, pero al pulsar «Exportar» y al terminar la ventana aún se congela.

## 1. Objetivo y «Hecho cuando»

Que exportar un `.glb` no congele la ventana en ningún momento: ni al pulsar, ni mientras trabaja, ni al guardar.

Hecho cuando:

1. Ningún fotograma de toda la exportación tarda más de **100 ms** (`# PROVISIONAL`; se fija con la medida real y tu OK, regla 9), con ventana y en frío (la caché de formas vacía, como en el uso real).
2. El `.glb` y el `.tres` salen **idénticos** a los de ahora, byte a byte (el `.tres`, sin los id aleatorios, como ya compara `probar_exportar_hilo.gd`).
3. `export_glb` (sin hilo), `GlbExporter.save` y `CharacterBaker.bake` siguen funcionando igual para quien los usa (informe de deformación, pruebas).

## 2. Nivel de modelo

**Fuerte:** hilos y reparto del trabajo entre el hilo principal y otro; un error da archivos distintos o cuelga la ventana.

## 3. Contexto mínimo

**Medido el 2026-11-24** (con ventana, en frío; script de solo lectura en el scratchpad), `GlbExporter.prepare` tarda 650–750 ms en el hilo principal:

| Parte | ms | Dónde |
| --- | --- | --- |
| Pedir a la malla las formas del cuerpo (`MeshBaker.shape_arrays`) | 335–386 | `CharacterBaker.bake` → `MeshBaker.bake` → `_add_shapes` |
| Sumar las formas y aplicar los huesos al cuerpo, piezas y ojos | 247–274 | `MeshBaker.bake` (`add_shape_arrays`, `_skin`) |
| Material `.tres` (`BodyMaterial.standalone`) | 38–76 | |
| Anclajes, arrays, pesos de la cabeza, zonas | < 35 | |

Al terminar, `finish` + `write` (en el hilo principal) dejan otro hueco de ~200 ms (`probar_exportar_hilo`, AC.6b).

Archivos: `godot/addons/creador/glb_exporter.gd` (`prepare`, `compute`, `finish`, `write`), `character_baker.gd` (`bake`), `mesh_baker.gd` (`bake`, `_add_shapes`, `cache_shapes`, `add_shape_arrays`, `_skin`), `godot/app/style_view.gd` (`_shape_cache`, de OPT.1), `godot/app/body_view.gd` (`start_export`, `finish_export`), `godot/app/body_actions.gd` (`_on_file_selected`), `pruebas/godot/probar_exportar_hilo.gd`.

## 4. Archivos

Tres subpasos, cada uno con su medida. Se para tras cada uno y se informa.

| Subpaso | Archivos |
| --- | --- |
| OPT.3a Formas de la caché | `mesh_baker.gd`, `character_baker.gd`, `glb_exporter.gd` (un parámetro `cache` que pasa de uno a otro), `godot/app/style_view.gd` (`shape_cache()`), `godot/app/body_view.gd` (lo pasa), `pruebas/godot/probar_exportar_hilo.gd`. Son 6 archivos, pero en 5 de ellos es una línea o dos |
| OPT.3b El horneado, al hilo | `character_baker.gd`, `glb_exporter.gd`, `probar_exportar_hilo.gd` |
| OPT.3c Guardar, al hilo | `glb_exporter.gd`, `godot/app/body_actions.gd`, `probar_exportar_hilo.gd` |

**No se toca:** lo que sale en el archivo (formato, orden de mallas y de vértices, materiales), `eye_texture.gd`, `garment_texture.gd`, `skin_paint.gd`, la interfaz (el botón sigue diciendo «Exportando…»).

## 5. Diseño

### 5.1 OPT.3a — Las formas, de la caché de la vista

Decisión: el exportador usa las formas que la vista del estilo ya tiene en memoria (`StyleView._shape_cache`, de OPT.1) en vez de pedirlas todas a la malla. Motivo: es justo la parte más lenta (335–386 ms) y la caché ya tiene las formas activas, porque la vista las usa en cada cambio.

```gdscript
# mesh_baker.gd
static func bake(mesh: MeshInstance3D, skeleton: Skeleton3D, cache: Variant = null) -> Dictionary  # cache → _add_shapes
# character_baker.gd
static func bake(mesh, skeleton, t_pose, profile_axes := false, pieces := [], rigid := [], cache: Variant = null) -> Node3D
# glb_exporter.gd
static func prepare(…, eyes := [], eye_data := {}, cache: Variant = null) -> Dictionary
# style_view.gd
func shape_cache() -> Dictionary  # la caché de OPT.1 (solo lectura: el exportador no la cambia salvo para añadir formas que falten)
```

- La caché solo vale para el **cuerpo** (es de su malla); piezas y ojos siguen como ahora (pocas formas y mallas pequeñas: < 10 ms).
- Si falta alguna forma activa, `cache_shapes` la pide como hoy y la añade: el resultado es el mismo.
- **Riesgo:** la caché es de `StyleView`, que puede estar calculando en su hilo (OPT.2). El exportador solo la **lee** en el hilo principal; `_finish_async` también escribe en el hilo principal (`call_deferred`). No hay dos hilos a la vez. Comprobarlo leyendo `style_view.gd` antes de escribir; si no es así, parar.

### 5.2 OPT.3b — Sumar formas y huesos, en el hilo

Decisión: partir `CharacterBaker.bake` en tres, como P.1 partió el exportador. Motivo: la suma y la piel (247–274 ms) son solo arrays y valen en un hilo (`add_shape_arrays` ya se usa en uno desde OPT.2); lo que toca el esqueleto vivo y crea nodos se queda en el principal.

```gdscript
static func prepare_bake(mesh, skeleton, t_pose, profile_axes, pieces, rigid, cache) -> Dictionary  # principal
static func compute_bake(job: Dictionary) -> void  # cualquier hilo: solo arrays
static func finish_bake(job: Dictionary) -> Node3D  # principal: crea esqueleto, mallas y pieles
static func bake(…) -> Node3D  # = las tres seguidas (para quien lo usa hoy)
```

1. `prepare_bake`: guarda la pose del editor, pone reposo y pose T, lee por cada malla (cuerpo, piezas, ojos) sus arrays, los pesos activos y sus formas (`cache_shapes`), sus matrices de piel (`skin_matrices`) y las poses globales; devuelve el esqueleto a su pose y los datos de los accesorios rígidos.
2. `compute_bake`: `add_shape_arrays` + `_skin` de cada malla; suelo (el punto más bajo a y = 0) y ejes del perfil, como hoy.
3. `finish_bake`: crea `Character → Skeleton3D → mallas` con los resultados, en el mismo orden que hoy.

`GlbExporter` se reorganiza para que cada parte vaya en su sitio:

| Parte | Hoy | Después |
| --- | --- | --- |
| `prepare` (principal) | hornea todo, anclajes, colores de piezas, `.tres`, lecturas | `prepare_bake`, `.tres`, lecturas (zonas, valores de ojos, pesos de la cabeza desde los arrays de origen) |
| `compute` (hilo) | normales del estilo, texturas, ojos | `compute_bake` + lo de hoy |
| `finish` (principal) | mallas y materiales | `finish_bake`, `Sockets.to_nodes`, colores de piezas, mallas y materiales |

- Los pesos de la cabeza (`StyleNormals.head_weights`) se calculan con los huesos y pesos de **origen**, que el horneado copia tal cual: mismo resultado.
- **No** se crean nodos en el hilo (Godot lo permite fuera del árbol, pero no hace falta y es más fácil de romper).

### 5.3 OPT.3c — Guardar el archivo, en el hilo

`write` (≈ 150–200 ms: `GLTFDocument.append_from_scene` + `write_to_filesystem`, que comprime las texturas en PNG) pasa a un segundo hilo tras `finish`, con el personaje fuera del árbol; `ResourceSaver.save` del `.tres` también.

- **NO VERIFICADO:** que `GLTFDocument` funcione en un hilo con una escena fuera del árbol y dé el mismo archivo. **Antes de escribir:** script mínimo de 10 líneas que exporta el mismo personaje en el hilo principal y en un `Thread` y compara los `sha256`. Si no coinciden o falla, OPT.3c no se hace: queda en `IDEAS.md` y se informa.
- `body_actions.gd`: tras `finish` lanza el hilo de guardar; el botón sigue en «Exportando…» hasta que acaba.

## 6. Pruebas

`probar_exportar_hilo.gd`, que ya compara el `.glb` y el `.tres` byte a byte entre con hilo y sin hilo. Se añade:

| Subpaso | Comprueba | Rotura que debe dar FALLO |
| --- | --- | --- |
| OPT.3a | `MEDIDA` al pulsar (hoy 645–755 ms con ventana); el `.glb` idéntico | Sin pasar la caché: vuelve la medida de antes (se comprueba que la prueba lo ve) |
| OPT.3b | `MEDIDA` al pulsar y al terminar; idéntico | `compute_bake` sin el suelo: el archivo cambia y la comparación falla |
| OPT.3c | `MEDIDA` del peor fotograma de toda la exportación; idéntico | Guardar en el principal: vuelve el hueco del final |

- Al cerrar OPT.3c se propone bajar `MAX_GAP_MS` de 300 a la medida real con margen (regla 9) y se añade el límite de 100 ms del «Hecho cuando» con su `# PROVISIONAL`.
- Las medidas, con ventana (`godot --path …`, sin `--headless`): la lectura de la tarjeta solo cuesta con ventana. Además, sin ventana, para que la prueba siga valiendo en la batería.
- Además: `probar_glb --ojos` (sobre `generar_glb_piezas.gd`), `probar_piezas`, `probar_pintar_piel`, `probar_personaje_horneado` y la autoprueba (`godot --headless --path godot -- --autoprueba`).

## 7. Trampas conocidas

1. **La caché crece** con cada forma que se usa (~0,35 MB por forma, OPT.1). El exportador no debe vaciarla ni duplicarla.
2. **La pose del editor:** `prepare_bake` la cambia y la devuelve en el mismo fotograma; si una animación está en marcha, que la devuelva igual que hoy (lo cubre `probar_exportar_hilo` con «lo que cambie después no entra»).
3. **Orden de las mallas:** el archivo debe salir idéntico; cualquier cambio en el orden de las piezas o de los ojos rompe la comparación byte a byte (y es justo lo que se quiere ver).
4. **Cerrar la ventana a mitad:** hoy `_exit_tree` espera al hilo; con el hilo de guardar (OPT.3c), lo mismo.
5. **Varios hilos a la vez:** las texturas del ojo ya usan `WorkerThreadPool` (AC.6b, 2 hilos); el hilo de guardar no debe empezar antes de que acaben.

## 8. Juicio visual

No cambia nada que se vea. El responsable exporta a mano en el programa y dice si la ventana sigue fluida (al pulsar, mientras trabaja y al terminar).

## 9. Si te atascas

Para y dilo si: el archivo deja de salir idéntico y no se ve por qué, la caché de `StyleView` se usa desde dos hilos, `GLTFDocument` no vale en un hilo, una medida no baja como se espera, o una prueba que pasaba deja de pasar sin causa evidente. No se relaja ningún límite.
