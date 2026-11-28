# SH.4b — Línea teñida y más fina en la cara

> Ficha del 2026-11-23 (nivel: medio). **Hecha el 2026-11-23.** Decisión: D54.

## 1. Objetivo y «Hecho cuando»

Como en la referencia VRoid: una línea fina del color de cada zona, más oscura, y casi nada en la cara.

- `outline_tint` 0 = la línea de siempre (`outline_color`); 1 = el color de la zona (piel; prenda con `min(COLOR.r, COLOR.a)` y `show_garment`; o el color de la pieza), con valor × 0,42 y saturación × 1,4 (en sRGB).
- `face_line` multiplica el grosor donde el canal A de `skin_zones` es 0 (la cara). Sin textura, el grosor no cambia.
- `set_color`, la prenda y las zonas llegan también al contorno. La vista copia el tinte a las piezas (`sync_lines`).
- Con los valores por defecto (0 y 1), el clásico no cambia (6 capturas, 0,000 %).

## 2. Archivos

`outline.gdshader`, `body_material.gd` (`OUTLINE_DEFAULTS`, `OUTLINE_SYNC`, `OUTLINE_SKIN`, `_set_both`, `standalone`), `godot/app/body_view.gd` (`sync_lines`, `_copy_line`), `finish_panel.gd`, `preset_file.gd`, `pruebas/godot/probar_linea.gd`.

## 3. Prueba y juicio visual

`probar_linea.gd` (Forward+ y Mobile). Que detecta el fallo: `ALBEDO = outline_color;`; el grosor sin la máscara de cara. Hojas: `pruebas/capturas/shader_linea/hoja_linea.png` (tinte 0 / 0,5 / 0,8 / 1) y `hoja_colores.png` (el estilo anime completo con 8 colores de piel).
