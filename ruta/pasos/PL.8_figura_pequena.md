# PL.8 — Figura más pequeña (en lugar del deslizador Edad)

> Decidido por el responsable el 2026-11-21: fuera el deslizador Edad (y Mayora/Mayor). En su lugar, que la figura se
> pueda hacer más pequeña (huesos y articulaciones los mismos) y que cada uno la ajuste como quiera.

## 1. Objetivo y «Hecho cuando»

- Global › Altura llega a ×0,65 (unos 1,08 m desde 1,66 m; D42: desde 5 años). Lo demás, con los deslizadores.

## 2. Nivel de modelo

**Simple** (un dato del CSV).

## 3. Archivos

- **Se tocan:** `godot/datos/humana/deslizadores.csv` (`height`: `escala:Root=0.65`), `manifiesto.json` (regenerado:
  `cuerpo.glb` igual), `pruebas/godot/probar_proporciones.gd` (el rango esperado), `PLAN.md`.

## 4. Diseño

- Es una escala uniforme del hueso raíz (deslizador Proporción): todo el esqueleto y la malla a la vez, sin formas ni
  datos nuevos. El neutro sigue en 1 y el máximo en ×1,15; los presets no cambian (ninguno baja de 0,5).
- Por qué no la edad: con MakeHuman hacía falta medir todas sus mezclas (~150 formas más, `cuerpo.glb` de 34 MB y ~1 s
  más al abrir) para que fuera exacta.

## 5. Prueba

Las de siempre (`probar_proporciones`, `probar_medidas`, `probar_exportar`…).
