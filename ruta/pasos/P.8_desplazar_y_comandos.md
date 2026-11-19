# P.8 — Desplazar la cámara y lista de comandos

> Pedido por el responsable el 2026-11-19. Hoy la rueda acerca al centro del cuerpo y arrastrar gira la cámara como en
> una esfera. Faltaba moverla en plano (arriba, abajo, a los lados) y una lista visible de atajos (adelanta la lista de
> atajos de IU.10).

## 1. Objetivo y «Hecho cuando»

**Objetivo:** Ctrl + arrastrar desplaza la cámara en el plano de la pantalla con el cursor de mano, y un botón
«Comandos» junto al sol/luna enseña todos los atajos.

**Hecho cuando:**
- Con Ctrl pulsado sobre la vista, el cursor es una mano; Ctrl + arrastrar mueve la cámara sin girarla (lo que hay bajo
  el ratón sigue al ratón). Sin Ctrl, todo sigue como hoy.
- El desplazamiento se queda al encuadrar de nuevo (mover deslizadores, animar) y no puede alejar al personaje más de
  `MAX_PAN`. La tecla **Inicio** lo devuelve al centro.
- El botón «Comandos» abre una ventana con la lista de atajos, sacada de una sola tabla que crecerá en el futuro.

## 2. Nivel de modelo

**Simple.** Un vector más en la cámara y un diálogo con una tabla.

## 3. Contexto mínimo

`godot/app/orbit_camera.gd` (entero), `body_view.gd:134` (`_process`) y `:240` (crea la cámara), `main.gd` (botón de
tema), `tema/theme_builder.gd` (`ICONS`).

## 4. Archivos

- **P.8a — Desplazar.** Se tocan `orbit_camera.gd` (`pan`, `pan_by`, `recenter`, Ctrl + arrastrar, Inicio) y
  `body_view.gd` (cursor de mano con Ctrl). Se crea `pruebas/godot/probar_desplazar.gd`.
- **P.8b — Comandos.** Se crea `godot/app/commands_dialog.gd` y el icono `tema/iconos/teclado.svg` (Tabler
  `keyboard`, como los de IU.2); se tocan `main.gd` y `theme_builder.gd` (`ICONS`). Se crea
  `pruebas/godot/probar_comandos.gd`.
- **No se toca:** el encuadre automático (P.3), el zoom, el núcleo.

## 5. Diseño

**P.8a**
- `var pan := Vector3.ZERO`: desplazamiento del punto que mira la cámara, aparte de `target`. **Motivo:** el encuadre
  automático (P.3) cambia `target`; con el desplazamiento aparte, no se pierde al encuadrar.
- `_place()`: `position = target + pan + órbita`; `look_at(target + pan)`.
- `pan_by(pixels: Vector2)`: metros por píxel = `2 · distance · tan(fov / 2) / alto de la vista`;
  `pan += (-pixels.x · derecha + pixels.y · arriba) · metros_por_píxel` (ejes de la cámara: no gira nada);
  `pan = pan.limit_length(MAX_PAN)` con `MAX_PAN := 1.5` m.
- `_unhandled_input`: arrastre con el botón izquierdo y `event.ctrl_pressed` → `pan_by`; sin Ctrl → `rotate_by`.
  `KEY_HOME` pulsada → `recenter()` (`pan = Vector3.ZERO`).
- Cursor (`body_view.gd`): `mouse_default_cursor_shape = CURSOR_POINTING_HAND` mientras Ctrl esté pulsado, si no
  `CURSOR_ARROW`; se mira en `_process`. **Motivo:** `CURSOR_POINTING_HAND` es una mano en Windows (`IDC_HAND`) y en
  Linux; `CURSOR_DRAG` en Windows son cuatro flechas.

**P.8b**
- `commands_dialog.gd` (`extends AcceptDialog`): `const COMMANDS := [[teclas, qué hace], …]` (la única lista; añadir
  un atajo = añadir una fila). Título «Comandos», un `GridContainer` de 2 columnas (teclas en `TituloZona`, texto
  normal).
- Filas de hoy: Ctrl+S, Ctrl+O, Ctrl+E, Ctrl+Z, Ctrl+Y / Ctrl+Mayús+Z, arrastrar, Ctrl + arrastrar, rueda, Inicio.
- `main.gd`: botón `BotonFantasma` con icono `teclado` y texto «Comandos», a la izquierda del sol/luna.

## 6. Prueba

- `probar_desplazar.gd` (sin ventana): `pan_by` mueve la cámara y el punto mirado lo mismo, sin cambiar la orientación
  (base igual, ± 1e-5) ni `yaw`/`pitch`; arrastrar a la derecha mueve la cámara a su izquierda; un evento de arrastre con
  Ctrl desplaza y sin Ctrl gira; `frame()` + `snap()` conserva `pan`; no pasa de `MAX_PAN`; Inicio lo pone a cero.
  **Detecta el fallo:** quitar `pan` de `look_at` (la cámara gira al desplazar).
- `probar_comandos.gd` (sin ventana, con `main.gd`): el botón existe junto al de tema, abre el diálogo y este tiene una
  fila por cada entrada de `COMMANDS`, con «Ctrl + arrastrar» y «Inicio». **Detecta el fallo:** no conectar el botón.
- Siguen pasando `probar_encuadre`, `probar_vista`, `probar_tema` y `probar_ventana`.

## 7. Trampas conocidas

- La forma del cursor no sale en una captura: se comprueba a mano.
- Ctrl + clic no choca con Ctrl+S/O/E (esos son teclas, no clics).

## 8. Juicio visual

A mano: Ctrl + arrastrar sobre el personaje, Inicio, y abrir «Comandos».

## 9. Si te atascas

Si `CURSOR_POINTING_HAND` no se ve como una mano en Linux, probar `CURSOR_DRAG` allí y decirlo en el registro.
