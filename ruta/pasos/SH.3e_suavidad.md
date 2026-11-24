# SH.3e — Piel más suave: hoja de `softness`

> Ficha del 2026-11-23 (nivel: simple). **Hecha el 2026-11-23; falta elegir el valor (§3).** Pedida por el responsable («que la piel se vea más soft»).

## 1. Objetivo y «Hecho cuando»

Ver si basta con ensanchar el paso de la luz a la sombra (`softness`, hoy 0,09) para que la piel se vea más suave, antes de añadir un medio tono propio.

Hecho cuando `probar_piel.gd` guarda `pruebas/capturas/shader_piel/hoja_suavidad_cuerpo.png` y `hoja_suavidad_cara.png`: las 4 filas de SH.2, columnas `softness` 0,09 / 0,14 / 0,20 (en el cuerpo y en las piezas), con la banda 0,6 y el brillo 0,35 elegidos (D52).

## 2. Archivos

Solo `pruebas/godot/probar_piel.gd` (`SOFTNESS_COLUMNS`, `CHOSEN`). No cambia ningún shader.

## 3. Juicio visual

¿Qué `softness` va a `SOFT_DEFAULTS` en SH.7? Si ni 0,20 se ve suave, el siguiente paso sería un medio tono cálido entre la luz y la sombra (tres tonos con bordes suaves), con su propia ficha.
