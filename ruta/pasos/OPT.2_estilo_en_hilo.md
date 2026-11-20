# OPT.2 — Sin tirón al soltar un deslizador

> Pedido por el responsable el 2026-11-20 tras OPT.1 («haz OPT.2»).

## 1. Objetivo y «Hecho cuando»

- Al dejar quieto un deslizador, el recálculo de las normales del estilo no congela la ventana.

## 2. Nivel de modelo

**Fuerte** (hilos; API de Godot comprobada antes con un script mínimo).

## 3. Archivos

- **Se tocan:** `godot/app/style_view.gd` (`refresh_async`), `godot/app/body_view.gd` (el temporizador la usa),
  `godot/addons/creador/mesh_baker.gd` (`active_shapes`, `cache_shapes`, `add_shape_arrays`: lo mismo que
  `_add_shapes`, partido para poder ir en un hilo), `pruebas/godot/probar_vista_estilo.gd`,
  `pruebas/godot/medir_lentitud.gd` (peor fotograma al soltar), `PLAN.md`.

## 4. Diseño

- `refresh_async`: en el hilo principal, leer los pesos; en un `WorkerThreadPool`, pedir las formas que falten en la
  caché, sumarlas y `StyleNormals.apply` (solo arrays); de vuelta (`call_deferred`), guardar las formas pedidas en la
  caché y poner la malla. Un contador (`_generation`) tira los resultados de un cálculo que ya no vale (también tras un
  `refresh()` síncrono). Al salir se esperan las tareas pendientes.
- `refresh()` sigue síncrono (al cargar y en las pruebas).
- **Comprobado** (script mínimo): `surface_get_blend_shape_arrays` desde un hilo da lo mismo; aun así Godot hace la
  lectura de la tarjeta dentro del fotograma (~80–110 ms la primera vez que se activan formas nuevas).

## 5. Prueba

`probar_vista_estilo.gd`: el recálculo llega del hilo; `refresh_async` deja < 20 ms al hilo principal (PROVISIONAL;
medido 0,0); un resultado viejo del hilo no pisa al nuevo. **Detecta el fallo:** sin mirar `_generation`.
