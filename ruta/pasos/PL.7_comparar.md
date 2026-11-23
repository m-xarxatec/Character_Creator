# PL.7 — Comparar antes y después (versión simple)

> `propuestas/expansion_v2.md` §4 (PL.7). Aprobado el 2026-11-20 («vamos con la siguiente»), simplificado.

## 1. Objetivo y «Hecho cuando»

- Mientras se mantiene pulsado «Comparar» (barra de abajo) o la tecla C, el personaje se ve como estaba al abrir o
  guardar; al soltar, vuelve al de ahora.

## 2. Nivel de modelo

**Simple** (la propuesta decía medio por el fantasma, que aquí no se hace).

## 3. Archivos

- **Se crea:** `pruebas/godot/probar_comparar.gd`.
- **Se tocan:** `godot/app/body_actions.gd` (botón y `show_saved`), `godot/app/main.gd` (tecla C),
  `godot/app/commands_dialog.gd` (fila de la C), `PLAN.md`.

## 4. Diseño (simplificado)

- Sin segunda malla ni fantasma semitransparente: la misma vista cambia a los valores de `saved_text` (lo último
  abierto o guardado) y vuelve. Motivo: una copia de la malla con 286 formas cuesta memoria y tiempo, y el
  responsable notó el programa algo lento.
- Solo la vista: el editor y Deshacer no cambian. La C no actúa con Ctrl (Ctrl+C) ni mientras se escribe en un campo
  (`_unhandled_input`).

## 5. Prueba

`probar_comparar.gd` (7): botón y tecla enseñan lo de antes y vuelven; el editor y Deshacer no cambian; tras guardar
compara con lo guardado; «Comandos» lista la C. **Detecta el fallo:** pasar por `editor.load_values`.
