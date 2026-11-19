# IU.5 — Panel izquierdo: silueta de zonas

> Fase IU (`propuestas/expansion_v2.md` §3, IU.5; `diseno/GUIA_INTERFAZ.md` §2 y §4 «Silueta de zonas»).

## 1. Objetivo y «Hecho cuando»

**Objetivo:** elegir la zona que se ajusta tocando una silueta del cuerpo o una lista, en un panel a la izquierda.

**Hecho cuando:**
- A la izquierda de la vista hay un panel de 280 px con dos pestañas pequeñas: **Zonas** y **Plantillas** («Pronto»,
  fase PL).
- Zonas: una silueta de frente dibujada por nosotros; cada zona se ilumina al pasar el ratón y se elige con un clic.
  Debajo, la lista de las 14 zonas visibles con su número de ajustes, en el orden de `deslizadores.csv`.
- Elegir una zona (silueta, lista, o el botón de zona del informe) abre esa zona en el panel derecho, y la silueta y la
  lista marcan la elegida.

## 2. Nivel de modelo

**Simple–medio.** Dibujo con polígonos y un clic; nada del núcleo.

## 3. Contexto mínimo

`godot/app/slider_panel.gd` (`open`, `open_zone`, `zones`, `HIDDEN_ZONES`), `main.gd` (`_body_page`,
`_on_zone_chosen`), `tema/tokens.gd`, `tema/theme_builder.gd`.

## 4. Archivos

- **IU.5a — Silueta y lista.** Se crean `godot/app/zone_silhouette.gd` (dibujo y clic) y `godot/app/zone_picker.gd`
  (pestañas, silueta y lista); se tocan `tema/tokens.gd` (`PANEL_IZQUIERDO := 280`) y `tema/theme_builder.gd`
  (colores del tipo `Silueta`). Se crea `pruebas/godot/probar_zonas.gd`.
- **IU.5b — Conectar.** Se tocan `main.gd` (el panel a la izquierda de la vista) y `slider_panel.gd` (señal
  `zone_opened` en `open`, para que la silueta siga al panel).
- **No se toca:** el núcleo, las cabeceras plegables del panel derecho (las quita IU.6).

## 5. Diseño

- **Silueta propia, por código** (`_draw` con polígonos), no un SVG. **Motivo:** cada zona tiene que ser una forma que
  se pueda pulsar e iluminar; con polígonos el mismo dato sirve para dibujar y para el clic
  (`Geometry2D.is_point_in_polygon`), y no hay archivo de terceros.
- Coordenadas en una caja de 100 × 200 (x = 50 es el centro), escalada al tamaño del control y centrada. Las partes con
  dos lados se escriben una vez (izquierda) y se reflejan.
- `ZoneSilhouette.SHAPES := {zona: [polígonos]}` para Cabeza, Cuello, Hombros, Pecho, Torso, Cintura, Caderas, Brazos,
  Manos, Dedos, Piernas y Pies. **Global** y **Glúteos** no tienen forma de frente: solo están en la lista.
- Colores del tema (tipo `Silueta`): `relleno` = `panel_2`, `borde` = `borde_fuerte`; al pasar el ratón `relleno_hover`
  = `acento_suave` y `borde_hover` = `acento_linea`; la elegida `relleno_elegida` = `acento`. **Motivo:** ningún color
  a mano fuera de `tema/` (IU.1).
- `ZonePicker`: señal `zone_chosen(zone)`; `setup(zones: Array, counts: Dictionary)`; `select(zone)` marca sin avisar.
  Lista: un botón (`BotonFantasma`, modo alternar, mismo `ButtonGroup`) por zona con «Nombre   n».
- `main.gd`: `picker.zone_chosen` → `slider_panel.open`; `slider_panel.zone_opened` → `picker.select`.
- La ayuda de cada forma de la silueta dice su nombre (`_get_tooltip`).

**IU.5c** (pedido por el responsable): un botón fantasma en el borde, entre el panel y la vista, con icono «<»
(Tabler `chevron-left`, `plegar`) para ocultarlo y «>» (`chevron-right`, `desplegar`) para enseñarlo. Al ocultarlo la
vista gana el sitio y vuelve a encuadrar sola (P.3). Toca `main.gd`, el tema (`ICONS`) y `probar_zonas.gd`.

## 6. Prueba

`probar_zonas.gd` (sin ventana, con `main.gd`):
- La lista tiene las 14 zonas visibles en el orden de `deslizadores.csv`, con su número de ajustes.
- Un clic sintético en el centro de cada forma de la silueta abre su zona (`slider_panel.open_zone`) y la marca.
- Pasar el ratón por una forma la ilumina (`hover_zone`); un clic fuera del cuerpo no cambia nada.
- Pulsar «Glúteos» en la lista abre Glúteos; el botón de zona del informe mueve también la marca.
- Plantillas existe y dice «Pronto».
**Detecta el fallo:** reflejar mal las partes de dos lados (sin `100 - x`) → el clic en el brazo derecho no abre
Brazos.

Siguen pasando `probar_ventana`, `probar_panel`, `probar_informe`, `probar_tema` y `probar_barra_superior`.

## 7. Trampas conocidas

- El centro de un polígono cóncavo puede caer fuera de él: la prueba usa un punto interior calculado (media de un
  triángulo), no el centro de la caja.
- Las formas se tocan entre sí: el clic busca de arriba abajo y gana la primera que contiene el punto.

## 8. Juicio visual

Capturas en `pruebas/capturas/interfaz/iu5/` (oscuro y claro). ¿Se lee la silueta? ¿Quieres otra postura o proporción?

## 9. Si te atascas

Si una zona es muy pequeña para pulsarla (Dedos, Pies), agrandar su forma hasta 24 px de alto como mínimo a 280 px de
ancho.
