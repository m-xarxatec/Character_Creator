# PL.9 — Cabeza más grande (en lugar del chibi)

> `propuestas/expansion_v2.md` §4 (PL.9). Ficha del 2026-11-21 (Opus 5.5; Fable ya no está disponible).
> **Decidido por el responsable (2026-11-21):** las tres recetas de chibi del PL.9a «están raras»; sin chibi ni
> recetas: que la cabeza crezca lo que cada uno quiera y el resto lo hagan los deslizadores.

## 1. Objetivo y «Hecho cuando»

- Cabeza › Tamaño llega a ×2,5 (antes ×1,3): con el cuerpo corto salen unas 3,3 cabezas de alto.

## 2. Nivel de modelo

**Simple** (un dato del CSV y los valores que dependen de él).

## 3. Archivos

- **Se tocan:** `deslizadores.csv` (`head_size`: `escala:Head=2.5`), los presets (`head_size` recalculado para que
  la cabeza quede igual), `manifiesto.json` (sha256), `godot/app/randomizer.gd` (no toca la cabeza), las pruebas que
  esperaban ×1,3 y los presets de prueba de `pruebas/fase_3/estilo/`.
- **Se crea:** `pruebas/godot/capturar_cabeza.gd` (sustituye a la de recetas del PL.9a, que se borra).

## 4. Diseño

- Escala uniforme del hueso Head, como hasta ahora; el neutro sigue en 0,5 (×1). Valor nuevo de un preset:
  `0,5 + (escala − 1) / 3` (0,8 → 0,56; 0,75 → 0,55).
- Aleatorio no toca la cabeza: entre 0,2 y 0,8 saldría hasta ×1,9.
- Sin migración de presets guardados: el programa aún no se ha publicado.

## 5. Prueba

Las de siempre (`probar_panel`, `probar_vista`, `probar_proporciones`, `probar_medidas`, `probar_animaciones`…) con
×2,5 en el máximo. Capturas: `capturar_cabeza.gd` (juicio visual).
