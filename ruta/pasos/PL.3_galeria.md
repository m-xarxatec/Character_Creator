# PL.3 — Galería de plantillas (versión simple)

> `propuestas/expansion_v2.md` §4 (PL.3). Aprobado el 2026-11-20 («simplifícalo y hazlo»).

## 1. Objetivo y «Hecho cuando»

- La pestaña «Plantillas» del panel izquierdo enseña una tarjeta por preset de serie (miniatura y nombre); un clic pone
  ese cuerpo y Ctrl+Z lo deshace.

## 2. Nivel de modelo

**Simple.**

## 3. Archivos

- **Se crean:** `godot/app/template_gallery.gd`, `pruebas/godot/probar_plantillas.gd`.
- **Se tocan:** `godot/app/zone_picker.gd` (la pestaña), `godot/app/main.gd` (conectarla), `pruebas/godot/probar_zonas.gd`
  (ya no dice «Pronto»), `presets/anime.json` (`nombre` «Neutro») y el manifiesto regenerado, `PLAN.md`.

## 4. Diseño (simplificado)

- Solo el cuerpo: `template_chosen(values)` → `BodyEditor.load_values` (un cambio de Deshacer). Colores, prenda y
  acabado no cambian, y el archivo abierto tampoco (Guardar no pisa la plantilla). Por eso no hace falta el aviso de
  cambios sin guardar: Ctrl+Z lo devuelve todo.
- Orden: `ORDER` en la galería (sin campo `orden` en el preset); las que falten, detrás por orden alfabético.
- 2 columnas; miniatura de 96 px arriba y el nombre debajo; ayuda «Empezar desde «X» (Ctrl+Z lo deshace)».

## 5. Prueba

`probar_plantillas.gd`: 11 tarjetas en orden (la primera «Neutro»), cada una con su miniatura; elegir Masculino deja
`gender` = 1 y los valores del archivo, sin cambiar el color de piel ni el archivo abierto; Ctrl+Z vuelve atrás.
**Detecta el fallo:** conectar la galería a «Abrir preset» (cambia el archivo abierto).
