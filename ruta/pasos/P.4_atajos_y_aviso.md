# P.4 — Atajos de teclado y aviso de cambios sin guardar

> Pulido (2026-11-18). Hoy Guardar, Abrir y Exportar solo van con el ratón, y al cerrar la ventana se pierde lo que no
> se guardó, sin avisar.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** Ctrl+S, Ctrl+O y Ctrl+E abren Guardar preset, Abrir preset y Exportar .glb; al cerrar con cambios sin
guardar, la ventana pregunta antes de salir.

**Hecho cuando:**
- Cada atajo abre su diálogo, y el texto de ayuda del botón muestra el atajo.
- Cerrar sin cambios sale enseguida. Con cambios sale un diálogo **Guardar / Salir sin guardar / Cancelar**.
- «Cambios» = lo que entraría en el preset (valores, colores, prenda y acabado) es distinto de lo último guardado o abierto.
- La autoprueba (`-- --autoprueba`) sigue saliendo sola, sin diálogo.

## 2. Nivel de modelo

**Medio.** Es interfaz con API conocida de Godot, pero el aviso al cerrar toca cómo sale el programa.

## 3. Contexto mínimo

`godot/app/body_actions.gd` (entero, 183 líneas), `godot/app/preset_file.gd` (`save`), `godot/app/main.gd`
(`_ready`, `_self_test`, `_unhandled_key_input`).

## 4. Archivos

Toca 4 archivos: se parte en dos subpasos.

- **P.4a — Atajos.** Se toca `body_actions.gd`. Se crea `pruebas/godot/probar_atajos.gd`.
- **P.4b — Aviso al cerrar.** Se tocan `preset_file.gd` (sacar `to_text`), `body_actions.gd` (`has_changes`) y
  `main.gd` (petición de cierre). Se crea `pruebas/godot/probar_aviso_cerrar.gd`.
- **No se toca:** el núcleo (`addons/creador/`), el formato del preset, `body_editor.gd`.

## 5. Diseño

**P.4a**
- `BodyActions._shortcut(key: Key) -> Shortcut`: un `InputEventKey` con `keycode = key` y
  `command_or_control_autoremap = true` (Ctrl en Linux y Windows, Cmd en Mac: no hay que tocarlo después).
- Se pone en `button.shortcut` de los tres botones (`KEY_S`, `KEY_O`, `KEY_E`). **Motivo:** así Godot lo enseña en el
  texto de ayuda y lo ignora si el botón está desactivado (por ejemplo, mientras exporta, P.1).
- Exportar necesita guardar su botón; Guardar y Abrir pasan a variables (`save_button`, `open_button`).

**P.4b**
1. `PresetFile.to_text(name, view, values) -> String`: lo que hoy hace `save` antes de escribir. `save` la llama.
   **Motivo:** comparar textos del preset cubre de una vez valores, colores, prenda y acabado.
2. `BodyActions.saved_text: String`: se rellena en `setup` (el personaje de partida no cuenta como cambio), al guardar
   bien y al abrir bien. El nombre del preset no se compara (se usa siempre `""`).
3. `BodyActions.has_changes() -> bool`: `PresetFile.to_text("", view, editor.values) != saved_text`.
4. `main.gd`, en `_ready`: `get_tree().auto_accept_quit = false`, salvo en la autoprueba.
   `_notification(what)`: con `NOTIFICATION_WM_CLOSE_REQUEST`, si `has_changes()` abre `close_dialog`; si no,
   `get_tree().quit()`.
5. `close_dialog`: `ConfirmationDialog` con texto «Hay cambios sin guardar.», botón OK = «Guardar…» (abre el diálogo de
   guardar y, si guarda bien, sale), botón extra «Salir sin guardar» (`add_button`, señal `custom_action`) y
   Cancelar (cierra el diálogo y no hace nada).
6. **Exportar .glb no cuenta como guardar:** el `.glb` no se puede volver a abrir para seguir editando.

## 6. Prueba

- `probar_atajos.gd` (sin ventana, con `main.gd`): manda un `InputEventKey` con Ctrl+S, Ctrl+O y Ctrl+E
  (`Input.parse_input_event` y un fotograma) y comprueba que se abre el diálogo correcto; con el botón Exportar
  desactivado, Ctrl+E no abre nada. **Detecta el fallo:** quitar el `shortcut` de un botón → falla esa línea.
- `probar_aviso_cerrar.gd` (sin ventana): sin tocar nada, `has_changes()` es falso; mover un deslizador → verdadero;
  guardar en `user://` → falso; cambiar el color de piel → verdadero; abrir el preset guardado → falso. Mandar
  `NOTIFICATION_WM_CLOSE_REQUEST` con cambios → `close_dialog` visible y el árbol sigue vivo. **Detecta el fallo:**
  hacer que `has_changes` devuelva siempre falso → fallan 2 comprobaciones.
- Pasan `probar_preset*`, `probar_ventana` y la autoprueba.

## 7. Trampas conocidas

- `auto_accept_quit = false` en la autoprueba la dejaría colgada: `_self_test` llama a `quit` directamente, pero
  conviene no activarlo en ese caso.
- Si un `FileDialog` está abierto, el atajo no debe abrir otro: el diálogo es modal y se queda con el teclado
  (comprobarlo a mano).
- `command_or_control_autoremap` y `custom_action` existen en Godot 4.x. **No comprobado aún en 4.7.2**: si falla,
  usar `ctrl_pressed = true`.
- Los floats del preset salen redondeados (`Preset.DECIMALS`): un cambio de una milésima no cuenta como cambio. Es lo
  que se quiere.

## 8. Juicio visual

Solo a mano: abre el editor, prueba los tres atajos, mueve algo y cierra la ventana. ¿Te gustan los textos del diálogo?

## 9. Si te atascas

Si la notificación de cierre no llega en la prueba sin ventana, llamar al método que la atiende
(`_on_close_requested()`) en vez de mandar la notificación, y probar el cierre real a mano.
