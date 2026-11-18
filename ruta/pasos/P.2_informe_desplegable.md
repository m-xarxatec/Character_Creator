# P.2 — El informe de deformación, en un desplegable propio

> Pulido (2026-11-18), pedido por el responsable: el informe (5.4) tapa los deslizadores al probar huesos o animar.
> Se mantiene, pero en un apartado opcional, desplegable, fuera de los deslizadores y con un nombre que se reconozca.

## 1. Objetivo y «Hecho cuando»

**Hecho cuando:** los deslizadores no se ocultan nunca; bajo la vista 3D hay una barra «Informe de deformación»
plegada al empezar; su cabecera dice el resumen (con color: verde, ámbar o rojo) mientras se prueban los huesos o hay
una animación, y «pulsa Probar huesos o elige una animación» si no; al pulsarla se despliegan las filas (altura fija,
con barra de desplazamiento); el botón de zona sigue abriendo esa zona.

## 2. Nivel de modelo

**Simple** (panel sobre funciones que ya existen).

## 3. Contexto mínimo

`godot/app/main.gd` (`_body_page`, `update_report`, `_on_zone_chosen`), `report_panel.gd`, `pruebas/godot/probar_informe.gd`.

## 4. Archivos

- **Se crea:** `godot/app/report_section.gd` (cabecera plegable + `ReportPanel` dentro).
- **Se tocan:** `main.gd` (la sección va bajo la vista; `update_report` ya no oculta los deslizadores), `probar_informe.gd`.
- **No se toca:** `report_panel.gd`, el núcleo.

## 5. Diseño

`ReportSection extends VBoxContainer`: `header: Button` (toggle, alineado a la izquierda, «▸ / ▾ Informe de
deformación — <resumen>»), `panel: ReportPanel` (visible solo desplegado, `custom_minimum_size.y = 180`).
`show_results(results)` → `panel.show_results` y cabecera con el resumen y su color; `clear()` → cabecera «pulsa…» y
filas vacías. `set_open(on)`. `main.report_panel` sigue siendo el `ReportPanel` (las pruebas lo leen).

## 6. Prueba

`probar_informe.gd`: al empezar, sección plegada y deslizadores visibles; con Probar huesos los deslizadores **siguen**
visibles, la cabecera dice el resumen y las filas están; desplegar enseña las filas; al quitar la prueba la cabecera
vuelve a «pulsa…»; el botón de zona abre la zona.
Que detecta el fallo: si `update_report` vuelve a ocultar los deslizadores, falla la fila «deslizadores visibles».

## 8. Juicio visual

Sí: captura de la ventana con la sección plegada y desplegada.
