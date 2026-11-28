# SH.2b — Código común de luz entre la piel y el ojo

> Ficha del 2026-11-23 (nivel: simple). **Hecha el 2026-11-23.** Decisión: D50 en `ruta/DECISIONES.md`.

## 1. Objetivo y «Hecho cuando»

Que la piel (`toon_soft`) y el blanco del ojo (`eye_layers`) no se separen nunca en cómo reciben la luz.

Hecho cuando:

- Las constantes de la sombra, las funciones de color (`to_srgb`, `to_linear`, `rgb_to_hsv`, `hsv_to_rgb`, `shade_of`) y `light()` están entre las marcas `// ==== Común` y `// ==== Fin del común`, con el mismo texto en los dos shaders.
- `probar_base_ojo.gd` compara el bloque entero (antes solo `light()`) y detecta un cambio en uno solo de los dos.
- Nada cambia de aspecto: `probar_toon_soft.gd` y `probar_base_ojo.gd` siguen en `TODO BIEN`.

## 2. Archivos

- **Se cambian:** `godot/addons/creador/toon_soft.gdshader` y `eye_layers.gdshader` (solo se mueve código: `light()` sube encima de `fragment()`), `pruebas/godot/probar_base_ojo.gd` (`_check_light` y `_common_text`).
- **No se tocan:** `body_material.gd` (`piece_shader()` sigue insertando `PULL_CODE` delante de `void fragment()`).

## 3. Diseño

Un include (`.gdshaderinc`) quitaría la copia, pero el `.tres` exportado debe ir autocontenido (3.11b) y SH.5 tendría que expandirlo. Por eso se queda copiado y lo vigila la prueba (D50). Los `uniform` que usa `light()` se declaran en cada shader, cada uno con sus valores (el ojo, sin rim, banda ni brillo).

**Regla para pasos futuros:** todo cambio en el bloque común se hace igual en los dos archivos.

## 4. Prueba

`(ulimit -v 4000000; timeout 300 godot [--rendering-method mobile] --path pruebas/godot -s probar_base_ojo.gd 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR')`

Que detecta el fallo: `SHADE_HUE_DEGREES = 6.0` solo en `eye_layers.gdshader` → `FALLO bloque común (luz y sombra calculada) igual al de toon_soft`.
