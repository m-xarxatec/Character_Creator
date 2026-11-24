# SH.3c — Banda cálida en el borde entre luz y sombra

> Ficha del 2026-11-23 (nivel: medio). **Hecha el 2026-11-23, apagada; falta el juicio visual (§5) y elegir `edge_strength`.** Decisión: D51 en `ruta/DECISIONES.md`.

## 1. Objetivo y «Hecho cuando»

Acercar la piel al anime tipo VRoid «realista»: en el paso de la luz a la sombra aparece una franja fina, más saturada y algo más roja, como la luz que se cuela bajo la piel. También sale en el borde de la sombra proyectada (cuello, flequillo).

Hecho cuando:

- Con `edge_strength = 0` (por defecto) nada cambia: `probar_luces.gd` sigue dando el aspecto de SH.2.
- Encendida, en el centro de la franja (`lit = 0,5`) la saturación sube, el brillo no cambia y el matiz gira hacia el rojo como mucho `EDGE_HUE_DEGREES` (8°).
- La luz plena, la sombra plena y los neutros (blanco, gris) no cambian.
- No depende del orden de las luces: la banda va dentro del tono de cada luz, antes del `max()` de SH.3a.

## 2. Archivos

- **Se crea:** `pruebas/godot/probar_piel.gd` (también lo usa SH.3d).
- **Se cambian:** `toon_soft.gdshader` (`uniform edge_strength`, `varying edge_ratio`), `eye_layers.gdshader` (el bloque común; el ojo, con 0), `body_material.gd` (`SOFT_DEFAULTS["edge_strength"] = 0.0`).

## 3. Diseño

En el bloque común:

```glsl
const float EDGE_SATURATION = 1.6;
const float EDGE_HUE_DEGREES = 8.0;
vec3 edge_of(vec3 color);  // mismo valor que el color, saturación × 1,6 y hasta 8° hacia el rojo; los neutros no cogen matiz
// en light():
float band = 4.0 * lit * (1.0 - lit) * edge_strength;      // 1 a mitad del paso de luz a sombra, 0 fuera
vec3 base = mix(shade_ratio, vec3(1.0), lit) * mix(vec3(1.0), edge_ratio, band);
```

`fragment()` calcula `edge_ratio = edge_of(color) / color`, como `shade_ratio`. El ancho de la franja lo da `softness` (0,09): no hay parámetro de ancho.

## 4. Prueba

`(ulimit -v 4000000; timeout 400 godot [--rendering-method mobile] --path pruebas/godot -s probar_piel.gd [-- --shader=<ruta>] 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')`

Esfera con la luz girada 87,13° (en el centro, `dot(NORMAL, LIGHT)` = `threshold`). Medidas en el registro de `PLAN.md`. Que detecta el fallo (en una copia, con `--shader`): `band` sin `edge_strength`; `EDGE_SATURATION = 1.0`; `band` sin `* (1.0 - lit)`.

## 5. Juicio visual

`pruebas/capturas/shader_piel/hoja_cuerpo.png` y `hoja_cara.png`: columna A apagada, B con `edge_strength` 0,6, C con banda y brillo (SH.3d). Las 4 filas de SH.2 con una luz y sombra.

Preguntas: ¿se lee como piel viva y no como una línea roja? ¿Qué valor de `edge_strength` va a `SOFT_DEFAULTS` en SH.7 (0 = sin banda)?
