# AB.15 — Arreglar la prueba de ejes (`probar_ejes_perfil`)

> Ficha del 2026-11-21 (nivel: simple). Aprobada por el responsable. Solo se toca la prueba; el programa no tiene la culpa.

## 1. Objetivo y «Hecho cuando»

`probar_ejes_perfil.gd` vuelve a escribir `pruebas/fase_5/salida/t_perfil.glb` y no da «TODO BIEN» si no lo escribe.
Hecho cuando: (1) `probar_exportar`, `probar_ejes_perfil` y `probar_overwrite_axis.sh` dan TODO BIEN, en ese orden; (2) `t_perfil.glb` tiene fecha nueva; (3) si el guardado falla o no se escribe el archivo, la prueba da FALLO; (4) `git status --short` solo muestra los archivos de este paso.

## 2. Nivel de modelo

Simple: una función de una prueba. Sonnet 5.5.

## 3. Causa (ya diagnosticada)

`_save` llamaba a `exporter._material(species.mesh, exported.mesh)`, que desde el commit 49caa02 (P.1) recibe un solo argumento. Daba `SCRIPT ERROR`, no escribía el `.glb` y aun así imprimía `RESULTADO: TODO BIEN` (código 0). `probar_overwrite_axis.sh` comparaba entonces un `t_perfil.glb` del 18-nov con un cuerpo actual: 2 FALLOS de 138,896 mm.

## 4. Archivos

- **Se toca:** `pruebas/godot/probar_ejes_perfil.gd` (`_save` y su llamada).
- **Documentos:** esta ficha y `PLAN.md`.
- **No se toca:** `godot/addons/creador/`, ningún límite de ninguna prueba.

## 5. Diseño

1. `_save` exporta con el exportador real: `prepare` → `compute` → `finish` → `write` (como `BodyView.export_glb`), en vez de reimplementar el guardado con funciones privadas.
2. Antes de guardar se borra el `t_perfil.glb` viejo; después, una comprobación comprueba que `_save` llegó al final y que el archivo existe. Un `SCRIPT ERROR` dentro de `_save` ya no puede acabar en TODO BIEN.
3. Sin límites nuevos.

## 6. Pruebas

Las tres de arriba, en orden. **Detecta el fallo:** volver a llamar a `exporter._material(species.mesh, job)` en `_save` → «FALLO el guardado llegó al final y el .glb existe»; una ruta de guardado que no existe → 3 FALLOS. Deshecho con `cmp`.

## 7. Si te atascas

Si tras el arreglo `probar_overwrite_axis.sh` sigue con FALLO, para y dilo: no se tocan límites (regla 9).
