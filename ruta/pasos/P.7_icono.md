# P.7 — Icono propio de la ventana

> Pulido (2026-11-18). Hoy la ventana y el build de Linux usan el icono de Godot.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** GameMolde tiene su propio icono en la ventana y en el build de Linux.

**Hecho cuando:**
- Hay un `godot/app/icono.svg` hecho por nosotros (MIT, como el editor), elegido por ti entre 3 propuestas.
- `project.godot` lo usa (`application/config/icon`) y se ve en la barra de la ventana y en el lanzador de Linux.
- Hay un `icono.png` de 256 px sacado del SVG, para el README y para el `.ico` de Windows (Fase 8).

## 2. Nivel de modelo

**Simple.** El dibujo lo eliges tú; el resto es un ajuste del proyecto.

## 3. Contexto mínimo

`godot/project.godot`, `godot/export_presets.cfg`, `ruta/pasos/8.2_build_windows.md` §35 (el `.exe` necesita
`rcedit`: no entra aquí), `diseno/GUIA_INTERFAZ.md` (colores).

## 4. Archivos

- **Se crea:** `godot/app/icono.svg`, `godot/app/icono.png` y `pruebas/godot/probar_icono.gd`.
- **Se toca:** `godot/project.godot` (una línea). Si el filtro del `.pck` no lo coge, también `export_presets.cfg`.
- **No se toca:** el preset de Windows (Fase 8).

## 5. Diseño

1. Hago **3 propuestas en SVG** (sencillas, que se lean a 16 px), con los colores de `GUIA_INTERFAZ.md`:
   - a) silueta de maniquí en pose T dentro de un cuadrado redondeado;
   - b) cabeza anime de perfil con el contorno grueso del estilo;
   - c) las letras «GM» unidas por una articulación (círculo de hueso).
   Las enseño en una página para compararlas a 256, 64, 32 y 16 px.
2. La elegida va a `godot/app/icono.svg`. **Motivo del SVG:** Godot lo importa a cualquier tamaño y se edita como
   texto.
3. `project.godot`: `config/icon="res://app/icono.svg"`.
4. `icono.png` 256 px: se saca con Godot (`Image.load_svg_from_string` + `save_png`) desde la prueba o un script
   pequeño. **Motivo:** así no hace falta ninguna herramienta nueva.

## 6. Prueba

`probar_icono.gd` (sin ventana, con `--path godot`): `ProjectSettings.get_setting("application/config/icon")` apunta a
un archivo que existe y se carga como textura de al menos 256 px; el SVG no tiene `<image>` ni enlaces externos
(todo propio). **Detecta el fallo:** borrar la línea de `project.godot` → falla. Pasan la autoprueba y `probar_pck.sh`.

## 7. Trampas conocidas

- En Linux, el icono del lanzador lo pone el `.desktop`, no el ejecutable: si el build no lo enseña, se apunta en
  `IDEAS.md` (un `.desktop` en el `.zip`), no se arregla aquí.
- El SVG no debe usar fuentes de texto (`<text>`): en otro equipo saldría otra letra. Las letras, como trazos.

## 8. Juicio visual

**Tú eliges** el icono entre las 3 propuestas. Después, mira la barra de la ventana en Linux.

## 9. Si te atascas

Si Godot no rasteriza bien algún detalle del SVG, simplificar el dibujo (sin degradados ni máscaras).
