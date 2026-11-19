# IU.9 — Ajustes: tema, tamaño de la interfaz y «Reducir animaciones»

> Fase IU (`propuestas/expansion_v2.md` §3, IU.9; `diseno/GUIA_INTERFAZ.md` §3 «Movimiento», §5.2 «Escala de la
> interfaz» y §7).

## 1. Objetivo y «Hecho cuando»

**Objetivo:** un diálogo «Ajustes» con las tres opciones del programa, que se aplican al momento y se recuerdan al
cerrarlo.

**Hecho cuando:**
- En la barra de abajo, junto a «Comandos», hay un botón «Ajustes» que abre un diálogo con:
  - **Tema:** Oscuro / Claro. Es el mismo ajuste que el botón sol/luna (D34), que se queda: los dos van a la par.
  - **Tamaño de la interfaz:** 90, 100, 110, 125 y 150 %.
  - **Reducir animaciones:** una casilla. Activada, la cámara llega de golpe al encuadre (P.3), sin el movimiento suave.
- Cada cambio se ve al momento (sin botón «Aplicar») y se guarda en `user://ajustes.cfg`; al volver a abrir el
  programa sigue igual.
- Un archivo de ajustes roto, o con valores fuera de rango, no impide arrancar: se usan los valores por defecto (o el
  más cercano permitido).

## 2. Nivel de modelo

**Simple.** Modelo barato. Solo amplía `settings_file.gd` (P.5c, IU.1c) y añade un diálogo; no toca el núcleo.

## 3. Contexto mínimo

`godot/app/settings_file.gd` (entero), `main.gd` (`_ready`, `set_dark`, `_name_theme_button`, botón «Comandos»),
`commands_dialog.gd` (un diálogo hecho igual), `orbit_camera.gd` (`frame`, `snap`, `_process`),
`tema/theme_builder.gd` (`ICONS`, `icon`), `pruebas/godot/probar_ultima_carpeta.gd` (cómo una prueba aísla
`user://ajustes.cfg`).

## 4. Archivos

- **IU.9a — Ajustes guardados.** Se toca `settings_file.gd`: `get_ui_scale`/`set_ui_scale` y
  `get_reduce_motion`/`set_reduce_motion`.
- **IU.9b — Diálogo.** Se crea `godot/app/settings_dialog.gd`; se toca `main.gd` (botón, aplicar al arrancar y al
  cambiar) y `orbit_camera.gd` (`instant`). Icono `ajustes` = Tabler `settings` v3.50.0: se añade
  `godot/app/tema/iconos/ajustes.svg` (+ `.import` «Keep File», como los otros) y su nombre a `ICONS`; en
  `CREDITOS.md` y `godot/CREDITOS.txt`, «30 iconos» pasa a «31». **Descargarlo usa la red: pedir OK.** Sin OK, el botón
  va solo con texto.
- **Prueba:** se crea `pruebas/godot/probar_ajustes.gd`; se toca `pruebas/godot/capturar_ventana.gd` (dos capturas
  más).
- **No se toca:** el núcleo (`addons/creador/`), `body_view.gd`, el tema (`theme_builder.gd` solo gana el icono).

## 5. Diseño

- **Archivo** (`[interfaz]` en `user://ajustes.cfg`, junto a `oscuro`):
  - `tamano`: uno de `SCALES := [0.9, 1.0, 1.1, 1.25, 1.5]`. `get_ui_scale()` devuelve el de la lista más cercano al
    guardado; si no hay o no es un número, el más cercano a `DisplayServer.screen_get_scale()` (valor inicial de la
    guía §5.2).
  - `reducir_animaciones`: `bool`; si no hay o no es `bool`, `false`.
  - **Motivo de la lista fija:** con un deslizador, la ventana cambiaría de tamaño mientras se arrastra.
- **Aplicar:** `main.gd` tiene `set_ui_scale(scale)` → `get_window().content_scale_factor = scale` y
  `set_reduce_motion(on)` → `body_view.camera.instant = on`. Los llama en `_ready` con lo leído y desde el diálogo.
  Guarda `SettingsFile` dentro de cada `set_*` de `main.gd`, como hace ya `set_dark`.
- **Cámara:** `orbit_camera.gd` gana `var instant := false`; al final de `frame()`, `if instant: snap()`.
- **`SettingsDialog`** (`extends AcceptDialog`, título «Ajustes», botón «Cerrar»): una rejilla de dos columnas
  (etiqueta y control): `OptionButton` Tema (Oscuro, Claro), `OptionButton` Tamaño («90 %»…«150 %»), `CheckBox`
  «Reducir animaciones», cada uno con su ayuda (`tooltip_text`). Señales `dark_chosen(bool)`, `scale_chosen(float)`,
  `reduce_motion_chosen(bool)`; `refresh(dark, scale, reduce)` pone los controles sin emitir (al abrirse, por si el
  sol/luna cambió el tema).
- **Para IU.10:** las transiciones nuevas leerán `SettingsFile.get_reduce_motion()`. Hoy la única animación es la de
  la cámara.

## 6. Prueba

`probar_ajustes.gd` (sin ventana, con `main.gd`, como `probar_ultima_carpeta.gd`; borra `user://ajustes.cfg` al
empezar **y al terminar**, para no cambiar otras pruebas):
1. Sin archivo: oscuro, tamaño = el más cercano a `screen_get_scale()` de la lista, sin reducir; el programa arranca.
2. Desde el diálogo: Claro → el tema de la raíz cambia y el sol/luna dice «Pasar al tema oscuro»; 125 % →
   `content_scale_factor` = 1,25; Reducir → `camera.instant`. Los tres quedan en el archivo.
3. Un `main.gd` nuevo (reinicio) lee los tres.
4. Archivo roto (texto sin sentido) → valores por defecto y arranca; `tamano = 3.0` → 1,5; `tamano = "abc"` → el de
   la pantalla; `reducir_animaciones = 7` → `false`.
5. Con Reducir, tras `frame()` la cámara ya está en el encuadre (`target == goal_target`) sin esperar fotogramas; sin
   Reducir, no.
6. El sol/luna y el diálogo van a la par (`refresh` tras pulsar el sol/luna).
**Detecta el fallo:** quitar `if instant: snap()` → falla la 5; no buscar el más cercano en la lista → falla la 4.

`capturar_ventana.gd`: `5_ajustes.png` (el diálogo abierto) y `6_tamano_150.png` (la ventana al 150 %, a 1920 × 1080).

## 7. Trampas conocidas

- **Comprobar** que `content_scale_factor` escala la interfaz con `window/stretch/mode` en `disabled` (el valor de
  `project.godot`) y qué pasa con la vista 3D (`SubViewportContainer`): ¿baja su resolución? Medirlo antes de seguir.
- **Comprobar** qué devuelve `screen_get_scale()` sin ventana y en Linux con X11 (la guía avisa de que puede dar 1).
- Al 150 % en 1280 × 720 caben 853 × 480 píxeles lógicos: zonas (280) + panel derecho (360) dejan poca vista. Medirlo
  en la captura; si no cabe, avisarlo (no rehacer la distribución en este paso).
- `probar_tema` y otras pruebas suponen oscuro y 100 %: por eso `probar_ajustes` borra el archivo al terminar.

## 8. Juicio visual

Capturas `5_ajustes.png` y `6_tamano_150.png` en `pruebas/capturas/ventana/`, en oscuro y en claro. ¿Se entiende el
diálogo? ¿Se lee bien al 150 %?

## 9. Si te atascas

Si `content_scale_factor` no escala con `stretch/mode = disabled`, no cambiar `project.godot` sin preguntar: probar
`canvas_items` en una copia y traer la medida.
