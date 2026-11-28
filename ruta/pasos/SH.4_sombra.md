# SH.4 — Sombra proyectada

> Ficha del 2026-11-23 (nivel: medio). **Hecha el 2026-11-23; falta el juicio visual (§5).** Decisión: D53.

## 1. Objetivo y «Hecho cuando»

- La sombra proyectada nunca baja del color de sombra calculado; con `shadow_receive` 0 desaparece.
- `face_shadow_receive` actúa solo en la cara (para la sombra de la nariz) y deja la del cuello.
- El contorno no agranda la sombra: no se ensancha en `IN_SHADOW_PASS`.
- La luz del editor proyecta sombra solo en estilo anime; el clásico no cambia (6 capturas, 0,000 %).

## 2. Archivos

`toon_soft.gdshader` y `eye_layers.gdshader` (bloque común: `varying receive`), `outline.gdshader`, `body_material.gd` (`SOFT_DEFAULTS`), `godot/app/body_view.gd` (`SHADOW`, `_set_shadow`), `blender/generar_zonas_piel.py` y `piel.png` (canal A: fuera de la cara), `FORMATO.md`, `pruebas/godot/probar_sombra.gd`.

## 3. Diseño

`lit *= mix(1, smoothstep(0,15; 0,85; ATTENUATION), receive)`, con `receive = shadow_receive · mix(face_shadow_receive, 1, A)`. La luz: ortogonal, 6 m, `bias` 0,03, `normal_bias` 1 y `blur` 1. En la hoja de bordes, con `blur` 0 sale acné de sombra en hombros y pelo; 1 y 2 lo quitan; PSSM de 2 cortes no mejora.

## 4. Prueba

`probar_sombra.gd` (Forward+ y Mobile). Que detecta el fallo: `lit` sin `receive`; `receive` sin la cara; el contorno viejo (sombra de 0,0130 a 0,0252).

## 5. Juicio visual

`pruebas/capturas/shader_sombra/hoja_cara.png`: A sin sombra, B con sombra, C cara 0,5, D cara 0. ¿Cuánta sombra recibe la cara (`face_shadow_receive`)? Con menos también se va la del flequillo en la frente. `hoja_borde.png`: ¿`blur` 1 te vale? El coste se mide en el PC (aquí no hay tarjeta gráfica).
