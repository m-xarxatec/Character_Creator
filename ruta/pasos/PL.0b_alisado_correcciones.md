# PL.0b — Correcciones de `alisado` también para complexión y firmeza

> Sigue a PL.0 (falla: masculino, 20 y 6 triángulos invertidos; el relieve no baja lo pedido). Aprobado el 2026-11-20.

## 1. Objetivo y «Hecho cuando»

- El alisado se recalcula en cada esquina de las 5 macros (`gender`, `muscle`, `weight`, `breast_volume`,
  `breast_firmness`) y lo que cada esquina añade se guarda como corrección `alisado*<esquina>`, como en el 6.2.
- PL.0 pasa: los 4 cuerpos de complexión y firmeza a 0 y a 1, con sus correcciones, cumplen las medidas del 6.2.
- Macros extremas: las 32 esquinas (las 5 macros a 0 y a 1) sin triángulos invertidos.

## 2. Nivel de modelo

**Fuerte**: cambia los datos que viajan con el programa (`cuerpo.glb`).

## 3. Archivos

- **Se tocan:** `blender/exportar_datos.py` (solo `SMOOTHING_SLIDERS`), `pruebas/fase_6/probar_formas_propias.py`, `PLAN.md`.
- **Los regenera el script:** `godot/datos/humana/cuerpo.glb`, `articulaciones.json`, `manifiesto.json`.
- **No se tocan:** el formato de `datos/` (la versión del manifiesto no sube), el núcleo, los límites de las pruebas.

## 4. Diseño

- `SMOOTHING_SLIDERS = ("gender", "muscle", "weight", "breast_volume", "breast_firmness")`. `measure_shapes` ya mide
  las 243 esquinas: no hay cuerpos nuevos que calcular, solo más correcciones (hoy 21).
- La prueba mide las 243 esquinas una vez (`ed.corner_bodies` con las macros de `SMOOTHING_SLIDERS` leídas de la
  tabla) y calcula las correcciones con `ed.smoothing_corrections`. En cada cuerpo, el alisado es `alisado` más las
  correcciones cuyas partes tiene la esquina (peso 1; las demás pesan 0), como en la app.
- PL.0 y su hoja `complexion.png` usan ese alisado con correcciones.

## 5. Prueba

`blender -b -P pruebas/fase_6/probar_formas_propias.py 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO'`.
Después de regenerar: `probar_exportar_datos.py` (fase 2), la autoprueba y `probar_rendimiento.gd`.
**Detecta el fallo:** con `SMOOTHING_SLIDERS` como antes (sin `gender` ni `breast_firmness`), PL.0 vuelve a fallar.

## 6. Riesgos

- Más correcciones: `cuerpo.glb` más grande (17,5 MB) y la app más lenta. Se mide; si crece mucho, se para.
- En la mujer el relieve bajaba un 36 %: si con su alisado propio tampoco llega al 50 %, se da la medida y no se
  cambia el límite.

## 7. Juicio visual

`pruebas/capturas/formas_propias/complexion.png` (con `-- --capturas`). Cambia la malla: proponer el revisor-visual.
