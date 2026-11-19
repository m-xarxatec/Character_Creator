# IU.11 — Cierre de la fase IU

> Fase IU (`propuestas/expansion_v2.md` §3, IU.11). Decidido el 2026-11-19: revisor-visual en pasada rápida; la prueba
> con una persona ajena ya la hizo el responsable.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** cerrar la fase con una hoja de capturas de la ventana y la revisión.

**Hecho cuando:**
- `pruebas/capturas/interfaz/iu11/` tiene la ventana en oscuro y en claro a 1280 × 720, a 1920 × 1080 y al 150 %
  (1920 × 1080), y `hoja.png` con las seis.
- El revisor-visual ha pasado (rápido) y lo que encuentre está en el registro o como paso nuevo.
- La prueba con una persona ajena: hecha por el responsable.

## 2. Nivel de modelo

**Simple.** Un script de capturas, sin cambios en la app.

## 3. Contexto mínimo

`pruebas/godot/capturar_ventana.gd` (cómo se cambia de tamaño, de tema y de escala).

## 4. Archivos

- **Se crea:** `pruebas/godot/capturar_hoja_iu.gd`.
- **No se toca:** la app ni el núcleo.

## 5. Diseño

- Para cada tema (oscuro, claro): captura a 1280 × 720, a 1920 × 1080 y a 1920 × 1080 con la interfaz al 150 %.
- `hoja.png`: las seis reducidas a 640 × 360, en 2 filas (oscuro, claro) × 3 columnas (tamaños).
- Borra `user://ajustes.cfg` al empezar y al terminar.

## 6. Prueba

El script comprueba que cada captura existe con su tamaño y no es de un solo color (`RESULTADO`).
**Detecta el fallo:** no cambiar el tamaño de la ventana → falla el tamaño.

## 7. Juicio visual

`pruebas/capturas/interfaz/iu11/hoja.png`. Lo juzga el responsable.
