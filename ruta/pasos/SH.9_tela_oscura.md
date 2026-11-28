# SH.9 — Tela oscura con sombra y línea legible sobre negro

> Ficha del 2026-11-24 (nivel: medio). **Hecha el 2026-11-24; falta el juicio visual (§5).** Pedida por el responsable tras la revisión del cierre de SH (`pruebas/capturas/revision/2026-11-24_cierre_sh7/INFORME.md`, dos sugerencias aprobadas).

## 1. Objetivo y «Hecho cuando»

1. **Tela oscura casi sin sombra.** Con `SHADE_VALUE_DARK = 0.92` un color oscuro baja un 8 % de su valor: en la ropa 0,10 son 2/255 (27 → 25). Se fija un mínimo en `diseno/GUIA_ESTILO.md` §4 y el shader lo cumple.
2. **Negro puro: línea y ropa valen 0.** La línea debe seguir legible sobre ropa negra pura.

Sin estropear la piel oscura (D48: los colores oscuros no deben acabar casi negros). No se hace: la prueba «piel oscura + ropa negra + fondo oscuro» (aplazada por el responsable). El clásico (`toon.gdshader`) no se toca.

Hecho cuando `probar_tela_oscura.gd` da TODO BIEN en Forward+ y Mobile, las pruebas de la §4 siguen igual y la hoja A/B está guardada.

## 2. Archivos

- **Se crea:** `pruebas/godot/probar_tela_oscura.gd`.
- **Se cambian:** `godot/addons/creador/toon_soft.gdshader` (bloque «Común» y `fragment()`), `godot/addons/creador/eye_layers.gdshader` (solo el bloque «Común», igual que el de `toon_soft`), `diseno/GUIA_ESTILO.md` §4.
- **No se toca:** `body_material.gd` (todo son constantes, no `uniform`), `outline.gdshader`, `toon.gdshader`, los archivos de AC.6a y `PLAN.md`.

## 3. Diseño

Dos constantes, en sRGB (donde 1/255 se ve igual en lo claro y en lo oscuro):

```glsl
// Común, en shade_of(): la sombra baja al menos SHADE_MIN_DROP de valor (lo que ya baja la piel oscura aprobada).
const float SHADE_MIN_DROP = 6.0 / 255.0;
... hsv.z * value  →  max(min(hsv.z * value, hsv.z - SHADE_MIN_DROP), 0.0)

// Solo toon_soft, al final del color de fragment(): ningún color baja de DARK_FLOOR de valor (mismo matiz y saturación).
const float DARK_FLOOR = 14.0 / 255.0;
vec3 floor_dark(vec3 color);
```

- La piel oscura (valor 0,27–0,30) ya baja 6/255: no cambia. Lo que baja menos (ropa, pelo e iris oscuros) baja 6/255.
- El negro puro se pinta con valor 14/255 (gris muy oscuro, como pide D47: «ropa negra leída como gris oscuro en la luz»); la línea teñida del negro sigue en ~0 y se distingue. 14/255 es el máximo que deja intacta la comprobación de SH.2 «la parte iluminada conserva el color» con el negro 0,05 (tolerancia 3/255).
- El ojo hereda la sombra mínima por el bloque común (sus partes oscuras bajan 6/255).

## 4. Pruebas

`(ulimit -v 4000000; timeout 400 godot [--rendering-method mobile] --path pruebas/godot -s probar_tela_oscura.gd [-- --shader=<copia>] 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')`

Esfera con una luz (de frente: luz; de espaldas: sombra), como `probar_toon_soft.gd`. Mide, en luminancia sRGB /255: luz − sombra de la ropa 0,10, la del preset (0,20/0,20/0,23) y el negro puro; la piel oscura (0,30 y 0,27) frente al shader de antes (el mismo código sin los dos cambios); la línea teñida (0,8) frente al negro puro, en luz y en sombra. Límites `# PROVISIONAL`. En Forward+ guarda `pruebas/capturas/sh9_tela_oscura/hoja_ab.png`: filas ropa 0,10, negro puro y piel oscura con ropa 0,10; columnas A (antes) y B (después), de frente y de espaldas.

También, en Forward+ y Mobile: `probar_luces`, `probar_linea`, `probar_sombra`, `probar_piel`, `probar_toon_soft`, `probar_base_ojo`; `probar_legibilidad` (Forward+); sin ventana `probar_material` y `probar_acabado`. Capturas de referencia (`capturas_de_referencia.sh` + `comparar_capturas.gd`).

Que detecta el fallo (en una copia, con `--shader`): `SHADE_MIN_DROP = 0.0`; `DARK_FLOOR = 0.0`; `SHADE_MIN_DROP = 0.06` (cambia la piel oscura).

## 5. Juicio visual

`pruebas/capturas/sh9_tela_oscura/hoja_ab.png`. ¿La camiseta negra se lee con sombra? ¿La línea se ve sobre el negro puro? ¿La piel oscura sigue igual?
