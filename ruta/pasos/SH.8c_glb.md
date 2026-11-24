# SH.8c — Rubor, labios y pecas en el `.glb`

> Ficha del 2026-11-23 (nivel: medio). **Hecha el 2026-11-23.** Decisión: D55.

## 1. Objetivo y «Hecho cuando»

En estilo anime, el `.glb` exportado lleva el rubor, los labios y las pecas pintados en la textura de color del cuerpo, para que se vean en un juego sin nuestro shader. En clásico sale como antes.

- Mismas constantes y `tint_of` que `toon_soft` (la prueba lee el shader).
- Rubor y labios: el color de `tint_of`, con la fuerza de la piel. Pecas: solo oscurecen, crecen con el nivel, el nivel 1 solo en nariz y mejillas, nada donde G = 0.
- La prenda se pinta encima (`GarmentTexture`), igual que antes.

## 2. Archivos

`godot/addons/creador/skin_paint.gd` (nuevo), `garment_texture.gd` (`skin_image`), `glb_exporter.gd` (`prepare` lee las zonas y la piel; `compute` pinta en el hilo), `pruebas/godot/probar_pintar_piel.gd`.

## 3. Diseño

Todo en CPU (vale en el hilo de exportación y sin tarjeta gráfica). Rubor y labios por píxel de `piel.png` (1024²) a bloques de 2×2 en la textura de 2048²; pecas celda a celda (240 por unidad de UV) con el `hash3` del shader, cada una como un disco con borde de medio píxel. En la textura no hay luz: el `.glb` lleva el color de la piel con sus marcas; el sombreado lo pone el material del juego o nuestro `.tres`.

## 4. Prueba

`probar_pintar_piel.gd` (sin ventana). Que detecta el fallo (con `-- --paint=<copia>`): `FRECKLE_OPACITY = -0.6`; el rubor sin `* blush`; `var reach := 1.0`.
