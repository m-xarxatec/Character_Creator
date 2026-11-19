# IU.1 — Tokens y tema global

> Fase IU (interfaz nueva), primer paso: `propuestas/expansion_v2.md` §3. Diseño: `diseno/GUIA_INTERFAZ.md` §3, §4,
> §5.1, §5.2, §5.4 y §8; maqueta: `diseno/maqueta-v2.html`. Este paso **no mueve ningún panel**: solo cambia cómo se
> ven (colores, radios, letra). La distribución nueva llega en IU.4–IU.6.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** todos los colores y tamaños de la interfaz salen de un único archivo de tokens, y la ventana usa el tema
nuevo: **oscuro por defecto** (D34), letra **Nunito** (D30) y un botón pequeño para cambiar a claro.

**Hecho cuando:**
- `godot/app/tema/tokens.gd` tiene los dos juegos de la guía §3.1–§3.3 (claro y oscuro) con las mismas claves.
- `theme_builder.gd` crea el `Theme` por código, con estilo para cada control de la guía §5.2 y las 9 variaciones.
- `main.gd` pone el tema en la raíz; las etiquetas de tipo y los colores del informe salen de los tokens.
- Un botón pequeño y visible cambia entre oscuro y claro, y el programa lo recuerda al volver a abrir.
- `probar_tema.gd` pasa (las 5 comprobaciones de la guía §8) y siguen pasando todas las pruebas de la ventana.
- Hay capturas de la ventana antes y después, y las juzgas tú.

## 2. Nivel de modelo

**Medio.** No hay cálculo difícil, pero el tema toca toda la ventana y hay que comprobar que no se rompe ninguna prueba.

## 3. Contexto mínimo

`diseno/GUIA_INTERFAZ.md` §3 (tabla de colores, letra, espacio), §4 (componentes: solo botones, pestañas, chips,
insignias, ayudas), §5.2 (tabla control → elementos del tema), §5.4 y §8. Código: `godot/app/main.gd` (`_ready`),
`slider_panel.gd:15–18` y `:171–184` (`TYPE_COLORS` e insignia), `report_panel.gd:11` y `:66` (`LEVEL_COLORS`),
`report_section.gd:61`.

## 4. Archivos

Más de 3 archivos: tres subpasos, cada uno con su prueba. La fuente ya está en `godot/app/tema/fuentes/`
(`nunito.ttf` y `ofl.txt`, con su fila en `CREDITOS.md`).

- **IU.1a — Tokens y constructor, sin aplicar.** Se crean `godot/app/tema/tokens.gd`, `godot/app/tema/theme_builder.gd`
  y `pruebas/godot/probar_tema.gd` (comprobaciones 1 a 4). La ventana no cambia.
- **IU.1b — Aplicar el tema.** Se tocan `main.gd` (pone el `Theme`), `slider_panel.gd` (fuera `TYPE_COLORS`: la
  insignia usa las variaciones `InsigniaForma`, `InsigniaProporcion` e `InsigniaCrear`), `report_panel.gd` y
  `report_section.gd` (colores de nivel desde los tokens `exito`, `aviso` y `error`). `probar_tema.gd` suma la
  comprobación 5. Capturas nuevas en `pruebas/capturas/interfaz/iu1/`.
- **IU.1c — Botón de tema.** Se tocan `main.gd` (botón y cambio en caliente) y `settings_file.gd` (`get_dark()` y
  `set_dark()`, clave `interfaz/oscuro`). `probar_tema.gd` suma la comprobación 6.
- **No se toca:** el núcleo (`addons/creador/`), la vista 3D (`body_view.gd`: su fondo cambia en IU.3), la
  distribución de los paneles, los textos.

## 5. Diseño

**`tokens.gd`** (`extends RefCounted`, solo constantes):
- `CLARO` y `OSCURO`: `Dictionary` de token → `Color`, copiados de la guía §3.1 (los 24 tokens de color más
  `sombra_suelo` y `sombra` como `Color` con alfa).
- `LETRA := {"titulo": 18, "cuerpo": 14, "valor": 13, "pequena": 12}`, `ESPACIO := [4, 8, 12, 16, 24, 32]`,
  `RADIO := {"boton": 8, "tarjeta": 12, "flotante": 16, "pastilla": 999}`, `ALTO_MINIMO := 32`,
  `ALTO_PRINCIPAL := 36`.
- `static func palette(dark: bool) -> Dictionary`.
- **Motivo:** un solo sitio para cambiar un color (guía §3); constantes y no un `.tres`, para revisarlas como texto.

**`theme_builder.gd`** (`extends RefCounted`):
- `static func build(dark := false) -> Theme`. Para cada fila de la guía §5.2, `StyleBoxFlat` con
  `set_corner_radius_all`, `set_content_margin_all`, `set_border_width_all` y `anti_aliasing = true`.
- Variaciones con `theme.set_type_variation(nombre, base)`: `BotonPrincipal` y `BotonFantasma` (base `Button`), `Chip`
  (`Button`), `Tarjeta` (`PanelContainer`), `TituloZona` (`Label`), `InsigniaForma`, `InsigniaProporcion`,
  `InsigniaCrear` (`PanelContainer`, con color de letra para su `Label`) y `Pista` (`Label`).
- `theme.default_font_size = LETRA["cuerpo"]`. Fuente: `nunito.ttf` (variable) con `FontVariation` y
  `variation_opentype = {"wght": 500}` como `default_font`; títulos y valores, su propio `FontVariation` (700 y 600).
  **Motivo:** un solo archivo de fuente da los tres pesos de la guía §3.2.
- Funciones pequeñas, una por control (`_button`, `_tabs`, `_slider`, `_panels`, `_fields`, `_tooltip`, `_scroll`,
  `_popups`, `_variations`).

**IU.1b**
- `main.gd`, al empezar `_ready`: `theme = ThemeBuilder.build(SettingsFile.get_dark())`. **Motivo:** se pone una vez en
  la raíz y los hijos lo heredan (guía §5.2).
- Insignia de tipo (`slider_panel.gd`): `badge.theme_type_variation = "InsigniaForma"` (según el tipo). Desaparecen
  `add_theme_stylebox_override`, `add_theme_color_override` y `add_theme_font_size_override` del archivo.
- Informe: los colores de nivel se leen de la paleta en uso (`exito`, `aviso`, `error`). El color de la cabecera
  (`report_section.gd:61`) usa el mismo token, sin `lightened`.

**IU.1c**
- Botón fantasma pequeño (`BotonFantasma`, 32 px) con «◐» y la ayuda «Tema claro / oscuro», en la barra de abajo
  (junto a Licencias) hasta que IU.4 cree la barra de arriba. **Motivo:** D34 pide que se vea siempre.
- Al pulsarlo: `SettingsFile.set_dark(not oscuro)` y `theme = ThemeBuilder.build(oscuro)`; el informe y las insignias
  vuelven a pintarse (señal `theme_changed`).
- `SettingsFile.get_dark()` devuelve `true` si no hay ajuste (oscuro por defecto).

## 6. Prueba

`probar_tema.gd` (sin ventana, con `--path pruebas/godot`, cargando los scripts de `godot/app/tema/` como las demás):
1. `CLARO` y `OSCURO` tienen exactamente las mismas claves.
2. Contrastes WCAG con la fórmula de luminancia relativa: `texto`, `texto_2` y `texto_3` sobre `panel` y sobre `fondo`;
   blanco sobre `acento`; `acento_texto` sobre `acento_suave`; `exito`, `aviso` y `error` sobre `panel`; el texto de
   cada insignia sobre su fondo. Todos ≥ 4,5. **Medido hoy con los colores de la guía:** el peor es `texto_3` sobre
   `fondo` en claro, 4,65; `error` sobre `panel`, 4,63.
3. El `Theme` tiene estilo para cada control y elemento de la guía §5.2, y las 9 variaciones.
4. Ningún tamaño de letra del tema ni de `LETRA` baja de 12.
5. (IU.1b) En `godot/app/`, fuera de `tema/`, ningún `Color(`, `add_theme_color_override`,
   `add_theme_font_size_override` ni `add_theme_stylebox_override`. **Excepciones con nombre:** `body_view.gd`
   (`BACKGROUND`, hasta IU.3) y `test_sword.gd` (material 3D, no interfaz).

6. (IU.1c) Sin ajustes, el tema es el oscuro; pulsar el botón lo cambia a claro y lo guarda; un `main.gd` nuevo arranca
   en claro.

**Que detecta el fallo:** poner `texto_3` a `#B0B0B0` hace saltar la 2 (guía §8); volver a escribir un `Color(` en
`slider_panel.gd` hace saltar la 5.

Además pasan `probar_ventana`, `probar_panel`, `probar_acciones`, `probar_informe`, `probar_encuadre`,
`probar_acabado`, `probar_edicion` y la autoprueba.

## 7. Trampas conocidas

- **Bordes (D43 b):** solo el agarrador del deslizador tiene que dar ≥ 3:1 (`acento` sobre `panel`: 5,27). Los bordes
  de los campos (`borde_fuerte`, 1,6–1,8) no se miden. La prueba 2 incluye el agarrador.
- Si una prueba de la ventana busca un nodo por su orden y el tema cambia los tamaños, se adapta la prueba en el mismo
  paso y se dice en el registro (guía §8). **No se cambia ningún límite.**
- `Theme.default_font_size` solo vale si el control no tiene un tamaño propio: por eso se quitan los
  `add_theme_font_size_override` de la insignia.
- El fondo gris de la vista 3D sigue como hoy hasta IU.3.
- La fuente variable: si `FontVariation` no aplica el eje `wght` en 4.7.2, plan B: tres `FontFile` estáticos desde el
  repositorio de Nunito (misma licencia), y se dice en el registro.

## 8. Juicio visual y decisiones

Capturas en `pruebas/capturas/interfaz/iu1/` (antes y después, oscuro y claro, 1280 × 720) con `capturar_ventana.gd`.
Decisiones tomadas el 2026-11-19: D30 b (Nunito), D34 b (oscuro + botón), D43 b (3:1 solo el agarrador).

## 9. Si te atascas

Si un elemento de la guía §5.2 no existe en Godot 4.7.2 con ese nombre, comprobarlo con
`ThemeDB.get_default_theme().get_stylebox_list(tipo)` y apuntar el nombre real en la ficha. No inventar nombres.
