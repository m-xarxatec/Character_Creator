# IU.10 — Microinteracciones y primer arranque

> Fase IU (`propuestas/expansion_v2.md` §3, IU.10; `diseno/GUIA_INTERFAZ.md` §3 «Movimiento»).

## 1. Objetivo y «Hecho cuando»

**Objetivo:** pequeños detalles que hacen el programa más fácil la primera vez: una pista sobre la vista, F1 para los
atajos, ayudas que salen antes y paneles que aparecen con un fundido corto.

**Hecho cuando:**
- La primera vez, sobre la vista 3D se lee «Arrastra para girar · Rueda para acercar · F1 atajos». Se oculta al
  primer giro de la cámara y no vuelve al abrir otra vez el programa (se guarda en `user://ajustes.cfg`).
- F1 abre la ventana «Comandos» (P.8b), que tiene la fila «F1 — Ver esta lista».
- Las ayudas (`tooltip_text`) salen a los 400 ms.
- Al desplegar el panel de zonas o el informe, aparecen con un fundido de 180 ms; con «Reducir animaciones», de golpe
  (0 ms).
- **Fuera de este paso:** el cambio de color de 120 ms al pasar el ratón por un botón (Godot no lo anima; pide código
  en cada botón) va a `IDEAS.md`, decidido por el responsable. El aviso de cambios sin guardar ya existe (P.4,
  `main.gd` `_add_close_dialog`) y ya usa el tema: no se toca.

## 2. Nivel de modelo

**Simple.** Modelo barato (Sonnet). Solo interfaz; no toca el núcleo.

## 3. Contexto mínimo

`godot/app/settings_file.gd` (entero), `orbit_camera.gd` (`rotate_by`), `body_view.gd` (`_ready`),
`commands_dialog.gd` (entero), `main.gd` (`set_zones_visible`, botón «Comandos»), `report_section.gd` (`set_open`),
`pruebas/godot/probar_ajustes.gd` (cómo aislar `user://ajustes.cfg`), `pruebas/godot/probar_comandos.gd`.

## 4. Archivos

- **IU.10a — Pista inicial.** Se tocan `settings_file.gd` (`get_hint_seen`/`set_hint_seen`), `orbit_camera.gd`
  (señal `rotated`) y `body_view.gd` (la pista). Prueba nueva `pruebas/godot/probar_pista.gd`;
  `capturar_ventana.gd` gana `7_pista.png`.
- **IU.10b — F1 y ayudas.** Se tocan `godot/project.godot` (`gui/timers/tooltip_delay_sec = 0.4`),
  `commands_dialog.gd` (fila F1) y `main.gd` (atajo F1 en el botón «Comandos»). Se amplía `probar_comandos.gd`.
- **IU.10c — Fundido.** Se crea `godot/app/motion.gd`; se tocan `main.gd` (`set_zones_visible`) y
  `report_section.gd` (`set_open`). Prueba nueva `pruebas/godot/probar_movimiento.gd`.
- **Además:** una línea en `IDEAS.md` («Después del MVP: interfaz»): color de 120 ms al pasar el ratón.
- **No se toca:** el núcleo (`addons/creador/`), el tema (`tema/`), el aviso de cerrar (P.4).

## 5. Diseño

- **IU.10a:**
  - `settings_file.gd`: `get_hint_seen() -> bool` (`_read_bool("pista_vista", false)`) y `set_hint_seen(seen)`.
  - `orbit_camera.gd`: `signal rotated`, emitida al final de `rotate_by` (solo el giro; zoom y Ctrl + arrastrar no
    cuentan: la pista habla de girar).
  - `body_view.gd`: `var hint: Label` (texto de §1, centrado abajo de la vista, `mouse_filter = IGNORE`,
    `theme_type_variation = "TituloZona"` o el texto normal). Se crea en `_ready` solo si
    `not SettingsFile.get_hint_seen()` y el personaje cargó. Conecta `camera.rotated` a `_on_first_rotation()`:
    oculta la pista, `SettingsFile.set_hint_seen(true)` y desconecta la señal (para no escribir el archivo en cada
    movimiento del ratón).
  - **Motivo de guardarlo:** si volviera en cada arranque, molestaría a quien ya sabe usarlo.
- **IU.10b:**
  - `project.godot`, sección `[gui]`: `timers/tooltip_delay_sec=0.4` (por defecto 0,5). **Comprobar** que la clave
    existe en 4.7 con `ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")` antes de escribirla.
  - `COMMANDS` gana `["F1", "Ver esta lista"]`, la primera fila (es la puerta a las demás).
  - `main.gd`: `commands_button.shortcut` = un `Shortcut` con un `InputEventKey` de `KEY_F1` (como `_shortcut` de
    `body_actions.gd`, pero sin Ctrl). **Motivo:** un atajo del botón funciona esté donde esté el foco.
- **IU.10c:**
  - `motion.gd` (`extends RefCounted`, sin `class_name`):
    ```gdscript
    const FADE := 0.18  # s, guía §3 «Movimiento»
    ## Hace visible el control con un fundido; con «Reducir animaciones», de golpe. Devuelve el Tween o null.
    static func fade_in(control: CanvasItem) -> Tween
    ```
    1. `control.visible = true`.
    2. Si `SettingsFile.get_reduce_motion()`: `control.modulate.a = 1.0` y devuelve `null`.
    3. Si no: `modulate.a = 0.0` y `control.create_tween().tween_property(control, "modulate:a", 1.0, FADE)`
       con `set_ease(EASE_OUT)`; devuelve el Tween.
  - Plegar es de golpe (`visible = false`): **motivo:** lo que se va no hace falta mirarlo, y así no se pisan dos
    animaciones.
  - `main.set_zones_visible(on)` y `report_section.set_open(on)`: si `on`, `Motion.fade_in(...)`; si no, como ahora.
  - Se lee el ajuste en cada fundido (no se guarda copia): así el diálogo de Ajustes vale al momento sin más código.

## 6. Prueba

Todas sin ventana; las que tocan ajustes borran `user://ajustes.cfg` al empezar y al terminar (como `probar_ajustes`).

- **`probar_pista.gd`** (con `main.gd`):
  1. Sin archivo: la pista se ve y dice el texto de §1.
  2. `camera.rotate_by(Vector2(10, 0))` → la pista se oculta y `get_hint_seen()` es `true`.
  3. Un `main.gd` nuevo (reinicio) no tiene pista (`hint == null` o invisible).
  4. Con un archivo nuevo, `zoom_by(1)` no oculta la pista.
  - **Detecta el fallo:** no llamar a `set_hint_seen` → falla la 3; emitir `rotated` en `zoom_by` → falla la 4.
- **`probar_comandos.gd`** (ampliado): la primera fila es F1; un `InputEventKey` F1 enviado con
  `Input.parse_input_event` (o `commands_button.shortcut.matches_event`) abre «Comandos»;
  `ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")` = 0,4.
  - **Detecta el fallo:** quitar el atajo → falla.
- **`probar_movimiento.gd`:**
  1. Sin Reducir: tras `set_zones_visible(false)` y `(true)`, `zone_picker.modulate.a < 1` en ese mismo instante y
     `fade_in` devuelve un Tween; tras 0,25 s (esperar fotogramas), `modulate.a == 1`. Igual con `set_open(true)` del
     informe.
  2. Con Reducir (`SettingsFile.set_reduce_motion(true)`): justo después, `modulate.a == 1` y `fade_in` devuelve
     `null` (0 ms).
  3. `Motion.FADE` está entre 0,12 y 0,18 s (guía §3).
  - **Detecta el fallo:** quitar el paso 2 de `fade_in` → falla la 2.

Al cerrar: las 44 sin ventana, `probar_ajustes`, `probar_comandos`, las dos nuevas, `datos`, `licencias` y la
autoprueba.

## 7. Trampas conocidas

- `body_view` es un `SubViewportContainer`: ya enseña una `Label` hija cuando hay error (`_ready`), así que la pista
  debería verse igual. **Comprobarlo** en la captura; si no se ve, ponerla en `main.gd` encima de la vista.
- Las pruebas que cargan `main.gd` con un `ajustes.cfg` limpio verán la pista; ninguna cuenta hijos de `body_view`
  hoy, pero si alguna falla por eso, decirlo antes de cambiarla.
- Sin ventana, los Tween avanzan con los fotogramas del `SceneTree`: esperar con `await process_frame` hasta pasar
  0,25 s de `Time.get_ticks_msec()`, no un número fijo de fotogramas.
- En un `extends SceneTree`, no llamar a una función propia `_process` ni `_init` (CLAUDE.md).
- F1 en algunos escritorios Linux abre la ayuda del sistema: si no llega a Godot, decirlo (no cambiar de tecla sin
  preguntar).

## 8. Juicio visual

Captura `7_pista.png` (y `7_pista_claro.png`) en `pruebas/capturas/ventana/`. ¿Se lee la pista sin tapar al
personaje? El fundido y F1 se juzgan a mano abriendo el editor.

## 9. Si te atascas

Si la clave `gui/timers/tooltip_delay_sec` no existe en 4.7, no inventar otra: decirlo y dejar el retraso por defecto.
Si el Tween no avanza sin ventana, probar la parte 2 (Reducir) sin ventana y la parte 1 a mano, y avisar.
