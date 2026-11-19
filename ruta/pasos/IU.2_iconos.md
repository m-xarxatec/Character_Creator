# IU.2 — Iconos

> Fase IU, segundo paso (`propuestas/expansion_v2.md` §3, IU.2). **D33 decidida el 2026-11-19:** de momento, los
> gratis que hay a mano: **Tabler Icons v3.50.0** (MIT, comprobada en GitHub; versión del 27-10-2026). Se pueden cambiar
> después: el código pide cada icono por su nombre en español, no por el de Tabler.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** un juego de iconos coherente (24 px, trazo 2 px) en las pestañas y los botones que ya existen.

**Hecho cuando:**
- Los 26 iconos de §5 están en `godot/app/tema/iconos/` en blanco, con la licencia MIT de Tabler al lado y su fila en
  `CREDITOS.md`.
- Los botones y pestañas de hoy llevan su icono, que cambia de color con el tema (oscuro y claro).
- `probar_tema.gd` comprueba que cada icono que nombra el código existe y se carga.

## 2. Nivel de modelo

**Simple.** Copiar archivos, un cargador y poner iconos en botones.

## 3. Contexto mínimo

`godot/app/tema/theme_builder.gd`, `godot/app/main.gd` (pestañas, Licencias, botón de tema), `body_actions.gd`
(`_button`), `slider_panel.gd` (Deshacer y Rehacer), `diseno/GUIA_INTERFAZ.md` §5.2 (último punto: iconos en blanco,
teñidos con `icon_*_color`).

## 4. Archivos

- **IU.2a — Iconos y cargador.** Se crean `godot/app/tema/iconos/*.svg` (+ su `.import` «Keep File») y
  `godot/app/tema/iconos/licencia_tabler.txt`. Se tocan `theme_builder.gd` (`icon()` y colores de icono),
  `godot/export_presets.cfg` (filtro), `CREDITOS.md` (+ copia `godot/CREDITOS.txt`) y `probar_tema.gd`
  (comprobación 7).
- **IU.2b — Ponerlos.** Se tocan `main.gd`, `body_actions.gd` y `slider_panel.gd`.
- **No se toca:** el núcleo, la distribución de la ventana (IU.4), los textos de los botones.

## 5. Diseño

Nombre en el código → icono de Tabler (`icons/outline/<nombre>.svg`):

| Código | Tabler | Código | Tabler | Código | Tabler |
| --- | --- | --- | --- | --- | --- |
| `cuerpo` | `user` | `deshacer` | `arrow-back-up` | `rejilla` | `grid-4x4` |
| `cara` | `mood-smile` | `rehacer` | `arrow-forward-up` | `luz` | `bulb` |
| `pelo` | `scissors` | `abrir` | `folder-open` | `restablecer` | `restore` |
| `ropa` | `shirt` | `guardar` | `device-floppy` | `buscar` | `search` |
| `accesorios` | `sword` | `vistas` | `eye` | `bien` | `circle-check` |
| `exportar` | `file-export` | `simetria` | `flip-vertical` | `aviso` | `alert-triangle` |
| `pronto` | `clock` | `prenda` | `hanger` | `error` | `circle-x` |
| `oscuro` | `moon` | `claro` | `sun` | `licencias` | `license` |
| `reproducir` | `player-play` | `pausa` | `player-pause` | | |

- Al copiarlos, `currentColor` → `#FFFFFF`. **Motivo:** la guía pide iconos blancos que el tema tiñe.
- `ThemeBuilder.icon(name: String) -> Texture2D`: lee el `.svg` como texto y lo pasa por
  `Image.load_svg_from_string` (24 px) → `ImageTexture`, con caché. **Motivo:** igual que la fuente, sin importador:
  vale cuando las pruebas cargan `app/` desde otro proyecto y dentro del `.pck` («Keep File» + filtro).
- Colores: en `Button`, `icon_normal_color` = `texto_2`, `icon_hover_color` = `texto`, `icon_pressed_color` =
  `acento_texto`, `icon_disabled_color` = `texto_3`; en `BotonPrincipal`, blanco; en las pestañas,
  `icon_selected_color` = `acento_linea`, el resto `texto_2`/`texto_3`.
- IU.2b: pestañas (`tabs.set_tab_icon`), Deshacer/Rehacer, Probar huesos (`vistas`), Exportar, Guardar, Abrir,
  Licencias y el botón de tema (icono `claro`/`oscuro`, **sin texto**, con su ayuda).

## 6. Prueba

`probar_tema.gd`, comprobación 7: cada icono de la tabla existe, no tiene `<image>`, `<text>` ni `href`, y se carga a
24 × 24; y cada `icon("…")` escrito en `godot/app/` está en la tabla. **Detecta el fallo:** borrar `guardar.svg`, o
escribir `icon("guardarr")`. Además pasan las pruebas de la ventana (el botón de tema cambia de icono en la 6).

## 7. Trampas conocidas

- `currentColor` sin cambiar sale negro en Godot (ThorVG): por eso se cambia al copiar.
- MIT pide que el aviso de copyright viaje con los iconos: `licencia_tabler.txt` va en el `.pck` (filtro `*.txt`).
- Si se cambian los iconos más adelante, solo cambian los `.svg` de la carpeta: los nombres del código no.

## 8. Juicio visual

Capturas en `pruebas/capturas/interfaz/iu2/` (oscuro y claro).

## 9. Si te atascas

Si un icono no se lee bien a 24 px, se elige otro de Tabler y se cambia solo su fila de §5.
