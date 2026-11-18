# P.1 — Exportar sin congelar la ventana

> Pulido (2026-11-18). Problema conocido de `build/NOTAS_0.1.0.md`: «la ventana se queda quieta mientras tanto».

## 1. Objetivo y «Hecho cuando»

**Medido (esta máquina):** exportar tarda 1,47 s; hornear 0,10 s, normales del estilo + textura de la prenda 1,29 s,
escribir el `.glb` y el `.tres` 0,08 s. Lo pesado son cálculos con arrays y una `Image`: no tocan la escena.

**Hecho cuando:** al exportar, la ventana sigue dibujando (ningún fotograma tarda más de 0,3 s), el botón dice
«Exportando…» y se desactiva, y el `.glb` sale **idéntico** (mismos bytes) al de hoy. Si se mueve un deslizador
mientras exporta, el archivo es el del momento de pulsar.

## 2. Nivel de modelo

**Fuerte** (hilos y `GlbExporter`, `GUIA_MODELOS.md` §2).

## 3. Contexto mínimo

`godot/addons/creador/glb_exporter.gd`, `garment_texture.gd` (cabecera), `godot/app/body_actions.gd`, `body_view.gd`
(`export_glb`), `ruta/RENDIMIENTO.md` O3 punto 4 (reglas del hilo).

## 4. Archivos

- **Se crea:** `pruebas/godot/probar_exportar_hilo.gd`.
- **Se tocan:** `glb_exporter.gd` (partir `build` en tres), `garment_texture.gd` (`bake_arrays`), `body_view.gd`
  (`start_export`, `finish_export`), `body_actions.gd` (exportar con un `Thread`).
- **No se toca:** el formato del `.glb`, `CharacterBaker`, `StyleNormals`, las pruebas que ya existen.

## 5. Diseño

`GlbExporter` (las firmas de `build` y `save` no cambian: `build = finish(compute(prepare(…)))`):

- `prepare(mesh, skeleton, socket_names, t_pose) -> Dictionary` — **hilo principal** (0,1 s): hornea, anclajes a nodos,
  copia los arrays de la malla horneada, pesos de Head, colores, prenda visible y el material toon (`standalone`).
  Todo lo del editor se lee aquí: lo que cambie después no entra.
- `compute(job) -> void` — **cualquier hilo**: solo arrays e `Image` (normales del estilo, `garment` al alfa, textura
  con `GarmentTexture.bake_arrays`). No toca nodos, mallas ni el servidor de render.
- `finish(job) -> Node3D` — hilo principal: crea la `ArrayMesh`, la `ImageTexture` y el material; devuelve el personaje.
- `write(character, toon, path) -> Error` — hilo principal: `GLTFDocument` y el `.tres`; libera el personaje.

`GarmentTexture.bake_arrays(uvs, colors, indices, size, skin, garment)`; `bake(mesh, …)` la llama.

`BodyView`: `start_export() -> Dictionary` (= `prepare`) y `finish_export(job, path) -> Error` (= `finish` + `write`);
`export_glb` (autoprueba) = las tres seguidas, sin hilo.

`BodyActions._on_file_selected`: botón «Exportando…» y desactivado → `start_export` → `Thread.start(compute)` → esperar
con `process_frame` mientras `is_alive()` → `wait_to_finish` → `finish_export` → aviso. `_exit_tree` espera al hilo.
`export_running()` dice si hay uno en marcha (la prueba lo usa).

## 6. Prueba

`probar_exportar_hilo.gd` (sin ventana, con `main.gd`): exporta sin hilo (`export_glb`) y con hilo (`_on_file_selected`);
mientras tanto mueve un deslizador y mide el hueco mayor entre fotogramas. Comprueba: botón desactivado y «Exportando…»
durante; los dos `.glb` y `.tres` con los mismos bytes; hueco mayor < 0,3 s (`# PROVISIONAL`); el aviso dice «Guardado»;
botón otra vez activo.

Que detecta el fallo: si `compute` se llama en el hilo principal, el hueco pasa de 1 s.

## 7. Trampas conocidas

- `ArrayMesh.surface_get_arrays` y `ImageTexture` hablan con el servidor de render: fuera del hilo.
- El hilo no se puede dejar vivo al cerrar: `wait_to_finish` en `_exit_tree`.

## 8. Juicio visual

No hace falta (el `.glb` es el mismo, byte a byte). Probarlo a mano si quieres: exportar y mover la cámara mientras tanto.
