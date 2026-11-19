# IU.6 — Filas de deslizador nuevas, buscador y pestaña Estilo

> Fase IU (`propuestas/expansion_v2.md` §3, IU.6; `diseno/GUIA_INTERFAZ.md` §2 y §4 «Fila de deslizador»).

## 1. Objetivo y «Hecho cuando»

**Objetivo:** el panel derecho enseña una zona con filas claras (valor 0–100 que se puede escribir, ↺, relleno desde el
neutro, ayuda) y un buscador; el Acabado se muda a la pestaña **Estilo**, viendo al personaje.

**Hecho cuando:**
- Cada fila: nombre, insignia de tipo, barra con el relleno **desde el neutro** y una marca en el neutro, número 0–100
  que se puede escribir, ↺ (atenuado si ya está en el neutro), ayuda al pasar el ratón; extremos con nombre donde
  aporta (Complexión: Femenino / Masculino).
- El panel derecho (360 px) enseña solo la zona elegida, con su nombre y número de ajustes; sin cabeceras plegables y
  sin Deshacer/Rehacer (ya están arriba, IU.4).
- Con Simetría, una fila para los dos lados (con ⇆); sin ella, dos filas «(izq.)» y «(der.)».
- «Buscar ajuste…» filtra por nombre y ayuda en todas las zonas: «ancho» encuentra los 6 ajustes de ancho (de 5 zonas: Torso tiene dos).
- La vista y el panel de zonas no cambian al cambiar de pestaña: las pestañas cambian solo el panel derecho. Estilo
  tiene el Acabado; Cuerpo ya no lo tiene.

## 2. Nivel de modelo

**Medio.** Un componente nuevo con dibujo propio y el panel derecho rehecho; muchas pruebas que adaptar.

## 3. Contexto mínimo

`godot/app/slider_panel.gd` (entero), `main.gd` (`_body_page`, `_ready`), `finish_panel.gd`, `body_editor.gd`
(`set_value`, `begin_change`, `end_change`, `reset_zone`, `symmetry`), `deslizadores.csv` (`nombre`, `tipo`, `lados`,
`neutro`), `pruebas/godot/probar_panel.gd`.

## 4. Archivos

- **IU.6a — Fila.** Se crean `godot/app/slider_row.gd`, `godot/app/textos/ayuda_deslizadores.csv`
  (`id,ayuda,extremo_izq,extremo_der`) y `pruebas/godot/probar_fila.gd`; se toca `tema/theme_builder.gd` (variación
  `BarraNeutro` de `HSlider` con agarrador propio dibujado como SVG con los colores del tema) y `tema/tokens.gd`
  (`PANEL_DERECHO := 360`).
- **IU.6b — Panel.** Se reescribe `slider_panel.gd` (una zona, título, buscador, filas `SliderRow`, Simetría). Se
  adaptan `probar_panel.gd`, `probar_zonas.gd` y `probar_informe.gd` si usan lo que se quita.
- **IU.6c — Distribución.** Se toca `main.gd`: zonas | vista + informe | panel derecho (las pestañas); Cuerpo =
  deslizadores, Estilo = Acabado. `refresh_top_bar` también al cambiar un valor (no solo cada 0,3 s). Se adaptan
  `probar_acabado.gd` y `probar_ventana.gd`.
- **No se toca:** el núcleo, `body_editor.gd`, los nombres de las filas (`deslizadores.csv`), `datos/`.

## 5. Diseño

**Fila (`SliderRow`, `extends VBoxContainer`)**
- Línea 1: nombre (+ « ⇆» si es de dos lados con Simetría) e insignia. Línea 2: barra, número y ↺. Línea 3 (solo si
  hay extremos): extremo izquierdo y derecho en `Pista`.
- Barra: `HSlider` con variación `BarraNeutro` (pista y relleno transparentes) y un hijo `show_behind_parent` que dibuja
  la pista (`borde`), el relleno del neutro al valor (`acento`) y la marca del neutro; el agarrador lo dibuja la barra
  encima. **Motivo:** el relleno nativo de Godot va siempre desde la izquierda.
- Número: `LineEdit` de 3 cifras; al pulsar Intro o salir, `clampi(int, 0, 100) / 100.0` como un solo cambio.
  **Motivo:** la guía pide 0–100 para la persona; dentro sigue siendo 0–1.
- ↺: `editor.set_value(key, neutro)` dentro de `begin_change`/`end_change` (un cambio para Deshacer). Doble clic en el
  nombre hace lo mismo.
- Señal `changed_by_user` no hace falta: la fila habla directamente con el editor, como hoy.

**Panel (`slider_panel.gd`)**
- Arriba: título de la zona (`TituloZona`) y «n ajustes» (`Pista`); buscador (`LineEdit` con icono `buscar`); casilla
  Simetría.
- Debajo: una caja por zona con sus filas y «Restablecer zona»; solo se ve la abierta. `open(zone)` igual que hoy
  (misma señal `zone_opened`).
- Buscar: con texto, se ven todas las cajas con al menos una fila que contiene el texto (sin mayúsculas ni tildes) en
  el nombre o en la ayuda; con el título «Resultados: n». Al borrar, vuelve la zona abierta.
- Simetría: con ella, las filas `_r` se ocultan y la `_l` dice « ⇆»; sin ella, las dos con «(izq.)» / «(der.)».
- Se mantienen `sliders` (clave → `HSlider`), `badges`, `zone_boxes`, `reset_buttons`, `symmetry_box`, `zones` y
  `open_zone`, para que las pruebas que ya existen sigan sirviendo. Desaparecen `zone_buttons`, `undo_button` y
  `redo_button`.

**Distribución (`main.gd`)**
- `[zonas] [<] [vista + informe] [panel derecho 360 px]`, y abajo la barra de siempre. El panel derecho es el
  `TabContainer` (sin pestañas propias): Cuerpo = `slider_panel`, Estilo = `finish_panel`, el resto «Pronto».
- Elegir una zona en la silueta lleva a la pestaña Cuerpo.

## 6. Prueba

- `probar_fila.gd` (IU.6a): escribir «73» deja 0,73 (un cambio para Deshacer); «150» deja 1; ↺ vuelve al neutro y se
  deshace con Ctrl+Z; ↺ atenuado en el neutro; el relleno va del neutro al valor (medido en el dibujo: inicio y fin en
  píxeles); Complexión enseña «Femenino» y «Masculino».
- `probar_panel.gd` adaptada (IU.6b): las mismas comprobaciones de valores, simetría, historial y Restablecer zona;
  con Simetría la fila `_r` no se ve y mover `_l` mueve `_r`; sin ella, las dos se ven; buscar «ancho» enseña 6
  filas de 5 zonas; borrar la búsqueda vuelve a la zona abierta. Deshacer/Rehacer con los botones de arriba.
- `probar_acabado.gd` adaptada (IU.6c): el Acabado está en la pestaña Estilo y la vista sigue visible en ella.
- **Detecta el fallo:** relleno desde la izquierda en vez de desde el neutro (falla la medida del relleno); buscar
  solo en el nombre (encuentra 5, no 6).
- Pasan todas las pruebas de la ventana y la autoprueba.

## 7. Trampas conocidas

- `show_behind_parent` dibuja el hijo **antes** que la barra: por eso la pista y el relleno de la variación son
  transparentes.
- El `LineEdit` se queda con Ctrl+Z mientras tiene el foco (deshace el texto, no el personaje): al pulsar Intro suelta
  el foco.
- Las filas `_r` ocultas siguen en `sliders` (las pruebas y el editor las usan).

## 8. Juicio visual

Capturas en `pruebas/capturas/interfaz/iu6/` (oscuro y claro). ¿Se lee bien la fila? ¿Los textos de ayuda?

## 9. Si te atascas

Si `show_behind_parent` no deja ver el relleno, plan B: dibujar la barra entera (pista, relleno y agarrador) en un
`Control` propio que hereda de `Range`.
