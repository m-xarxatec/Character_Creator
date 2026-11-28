# SH.7a — Interfaz del estilo anime (beta) y presets versión 3

> Ficha del 2026-11-23 (nivel: fuerte). **Hecha el 2026-11-23.** Decisión: D53. Adelanta la parte de interfaz de SH.7; el cambio de defecto sigue en SH.7.

## 1. Objetivo y «Hecho cuando»

Poder probar el estilo anime y regular la piel desde el programa, sin cambiar el aspecto por defecto.

Hecho cuando:
- En Acabado hay un interruptor «Estilo anime (beta)», apagado por defecto. Al encenderlo, el cuerpo, las piezas y los accesorios pasan a `toon_soft` sin perder colores, prenda ni `unlit`, y la luz proyecta sombra (SH.4). Al apagarlo, todo vuelve al clásico.
- Con el interruptor encendido se ve la sección Piel: Calidez del borde, Brillo de piel, Rubor, Color de labios y Pecas (0–10, de uno en uno). Cada barra tiene su ayuda y mueve el material del cuerpo.
- Restablecer vuelve al acabado y a la piel de partida del estilo, sin cambiar de estilo.
- El preset guardado lleva `estilo` y `piel` (versión 3). Los de la 1 y la 2 se siguen leyendo como estilo clásico. Los tres de serie pasan a la 3 con el mismo aspecto.

## 2. Archivos

`body_material.gd` (`set_style`, `is_soft`, `SKIN`, `SKIN_START`, `SOFT_OUTLINE_PX`, `set_skin`, `get_skin`, `default_finish(soft)`, `apply(…, soft)`), `preset.gd` (versión 3), `godot/app/body_view.gd` (`set_anime_style`, `is_anime_style`; las piezas nuevas toman el estilo del cuerpo), `preset_file.gd`, `finish_panel.gd`, `godot/datos/humana/presets/*.json` y `manifiesto.json`, `probar_presets.gd`, `probar_acabado.gd`.

## 3. Valores de partida (visuales; los cambia el responsable)

`SKIN_START`: banda 0,6 y brillo 0,35 (D52), rubor 0,35 y labios 0,45 (propuesta de SH.8), pecas 0. Línea de 1,25 px (la base aprobada de SH.1).

## 4. Prueba

`probar_presets.gd` y `probar_acabado.gd` (sin ventana); `probar_ventana.gd` y `probar_guardar_abrir.gd` (con ventana). Que detecta el fallo: `set_anime_style` sin pasar las piezas; Pecas con `step` 0,1.
