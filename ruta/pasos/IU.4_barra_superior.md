# IU.4 — Barra superior y pestañas principales

> Fase IU (`propuestas/expansion_v2.md` §3, IU.4; `diseno/GUIA_INTERFAZ.md` §2). D35 decidida: «Exportar» deja de
> ser pestaña y pasa a botón principal.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** arriba de la ventana, la marca, el nombre del archivo (con `•` si hay cambios), las pestañas principales y
Deshacer, Rehacer, Abrir, Guardar y **Exportar** (botón principal).

**Hecho cuando:**
- Pestañas: Cuerpo, Cara y ojos, Pelo, Ropa, Accesorios, **Estilo** (Exportar ya no es pestaña). Las que no existen
  dicen «Pronto», se pueden abrir y enseñan qué llegará (no se ven grises y muertas).
- Abrir, Guardar y Exportar suben a la barra; Exportar es el botón morado. Hacen lo mismo que antes (mismos atajos).
- El nombre del archivo sale arriba: «Personaje nuevo» o el del preset guardado/abierto, con `•` si hay cambios.

## 2. Nivel de modelo

**Simple.** Mover botones y una barra nueva; las funciones no cambian.

## 3. Contexto mínimo

`godot/app/main.gd` (`_ready`, `TAB_NAMES`), `body_actions.gd` (`save_preset`, `open_preset`, `has_changes`),
`pruebas/godot/probar_ventana.gd:5` y `:30–40`.

## 4. Archivos

- **IU.4a — Barra y pestañas.** Se crea `godot/app/top_bar.gd`; se toca `main.gd` (la barra arriba, `TabContainer` sin
  sus pestañas propias, páginas «Pronto»). Se adapta `probar_ventana.gd` (nombres y «Pronto»).
- **IU.4b — Botones arriba.** Se tocan `main.gd` (mueve Abrir, Guardar y Exportar a la barra; Deshacer y Rehacer),
  `body_actions.gd` (`current_path`, `file_name()`). Se crea `pruebas/godot/probar_barra_superior.gd`.
- **No se toca:** el núcleo; la barra de abajo con Probar huesos, Animación, Prenda base, Licencias, Comandos y tema
  (se vacía en IU.3 e IU.8); los botones Deshacer/Rehacer del panel de deslizadores (los quita IU.6).

## 5. Diseño

- `top_bar.gd` (`extends PanelContainer`): dos filas. **Fila 1:** marca «GameMolde» (`TituloZona`), nombre del archivo
  (`Pista`), hueco, y a la derecha las acciones. **Fila 2:** un `TabBar` con las pestañas. **Motivo:** en una sola fila
  no caben a 1280 px (≈ 1300 px medidos a ojo con iconos y textos).
- `TopBar.setup(titles, icons, soon)`, `add_action(button)` (lo mueve a la fila 1), `set_file(name, changed)`.
- `main.gd`: `tabs.tabs_visible = false`; `tab_bar.tab_changed` → `tabs.current_tab`. Pestañas sin hacer: título
  «<nombre> · Pronto», ayuda con lo que llegará, página con una frase (`Pista`). **Motivo:** la guía pide que no se vean
  muertas.
- Exportar: `export_button.theme_type_variation = "BotonPrincipal"`. Mismo texto, mismo diálogo, mismo atajo.
- Deshacer y Rehacer: botones fantasma con icono, ayuda «Deshacer (Ctrl+Z)», activos según `editor.can_undo/redo`.
- Nombre y `•`: `body_actions.current_path` se rellena al guardar o abrir bien; un `Timer` de 0,3 s llama a
  `set_file(file_name(), has_changes())`. **Motivo:** los colores y el acabado no avisan al editor; mirar cada 0,3 s
  es barato (un texto de preset).

## 6. Prueba

- `probar_ventana.gd` adaptada: 6 pestañas Cuerpo…Estilo; Cuerpo construida y las demás con «Pronto»; se abre en
  Cuerpo; elegir una pestaña en la barra cambia la página.
- `probar_barra_superior.gd` (sin ventana): Abrir, Guardar y Exportar están en la barra de arriba (y no en la de
  abajo); Exportar usa `BotonPrincipal`; al empezar dice «Personaje nuevo» sin `•`; mover un deslizador → `•`;
  guardar en `user://` → nombre del archivo sin `•`; Deshacer de la barra deshace. **Detecta el fallo:** no llamar
  a `set_file` → falla el `•`.
- Siguen pasando `probar_atajos`, `probar_acciones`, `probar_exportar_hilo`, `probar_guardar_abrir`, `probar_tema`,
  `probar_comandos` y la autoprueba.

## 7. Trampas conocidas

- Los atajos de los botones movidos siguen funcionando: un `shortcut` vale esté donde esté el botón.
- `probar_exportar_hilo` mira el texto «Exportar .glb»: no se cambia.

## 8. Juicio visual

Capturas en `pruebas/capturas/interfaz/iu4/` (oscuro y claro).

## 9. Si te atascas

Si la barra no cabe a 1280 px, quitar el texto de Abrir y Guardar (solo icono, con ayuda).
