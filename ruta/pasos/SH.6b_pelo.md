# SH.6b — Banda de brillo del pelo

> Ficha del 2026-11-23 (nivel: fuerte). **Hecha el 2026-11-23.** Decisiones: AB.9 y D54.

## 1. Objetivo y «Hecho cuando»

Un anillo de brillo en el pelo, igual en cualquier peinado (sin UV ni normales), que se apaga en la sombra.

- La altura es la de la dirección que va del centro de la cabeza al punto, en el sistema del hueso Head (`hair_head`: mundo → cabeza; centro a `HEAD_CENTER_UP` = 7,5 cm a lo largo del hueso). La banda está donde esa altura vale `hair_band_height` (0,55) ± `hair_band_width` (0,07), con borde `hair_band_softness` (0,05). Se atenúa en la silueta.
- Aclara el color del pelo como el brillo de piel (× (1 + color · banda)), solo donde da la luz (`* lit`).
- Solo en piezas de ranura `pelo`, con la fuerza «Brillo del pelo» de la piel del cuerpo (0,6 de partida); la piel y la ropa, a 0.

## 2. Archivos

`toon_soft.gdshader` y `eye_layers.gdshader` (bloque común: `varying band_amount`, `hair_band_color`), `body_material.gd`, `godot/app/body_view.gd` (`hair`, `head_transform`, `_copy_band`, `_process`), `finish_panel.gd`, `pruebas/godot/probar_pelo.gd` y `probar_toon_soft.gd` (lee `mat4`).

## 3. Diseño: uniform por fotograma

`hair_head` lo pone la vista en cada fotograma, solo en las piezas de pelo y en estilo anime: una matriz por pieza, sin coste apreciable. Guardar la dirección en los vértices ocuparía un canal y no seguiría a la animación. Para el `.tres` exportado, el juego tendrá que poner `hair_head` (o queda la identidad y la banda no sale); se documenta en SH.7.

## 4. Prueba y juicio visual

`probar_pelo.gd`. Que detecta el fallo: la banda sin `* lit`; la altura fija. Hoja: `pruebas/capturas/shader_pelo/hoja_pelo.png` (2 peinados de packs distintos × frente, tres cuartos y perfil; fuerza 0 / 0,6 / 1,2).
