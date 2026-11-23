# IU.13 — Quitar «Comparar»

> Ficha del 2026-11-22 (nivel: simple). Aprobada por el responsable: no le gustó y no la ve necesaria.

## 1. Objetivo y «Hecho cuando»

Quitar la función del paso PL.7. Hecho cuando no quedan el botón «Comparar», la tecla C ni su fila en «Comandos», y el aviso de cambios sin guardar sigue funcionando.

## 2. Nivel de modelo

Simple: borrar código de la interfaz.

## 3. Contexto mínimo

`godot/app/body_actions.gd`, `godot/app/main.gd` (`_unhandled_input`), `godot/app/commands_dialog.gd`.

## 4. Archivos

- **Se tocan:** esos tres, `PLAN.md` y esta ficha.
- **Se borra:** `pruebas/godot/probar_comparar.gd` (solo prueba esta función).
- **No se toca:** `saved_text` y `has_changes()` (los usa el aviso al cerrar); la ficha `PL.7_comparar.md` (historia); las copias de `pruebas/capturas/shader_propuesta/proto/`.

## 5. Diseño

Borrar `compare_button`, `show_saved()`, `_unhandled_input()` (solo atendía la C) y la fila de `COMMANDS`.

## 6. Pruebas

`probar_comandos`, `probar_plantillas` y la autoprueba. Sin prueba nueva: se comprueba con `grep` que no queda ninguna referencia en `godot/`.

## 7. Trampas conocidas

Ninguna: `saved_text` se sigue usando.

## 8. Juicio visual

El responsable lo mira en el editor.

## 9. Si te atascas

Si una prueba que pasaba falla por algo distinto de Comparar, para y dilo.
