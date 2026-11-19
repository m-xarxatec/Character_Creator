# IU.12 — Retoques del revisor (cierre de la fase IU)

> Hallazgos del revisor-visual en IU.11. Decidido el 2026-11-19: se arreglan los tres.

## 1. Objetivo y «Hecho cuando»

- La etiqueta «Zona · clic para editar» lleva fondo (como la ayuda): la malla no la tapa.
- En claro se ve el tirador de los deslizadores normales (luz de Ajustes).
- La lupa de «Buscar ajuste…» se ve en claro y en oscuro, y cambia con el tema.

## 2. Nivel de modelo

**Simple.** Tema y dos líneas de interfaz.

## 3. Archivos

- **Se tocan:** `godot/app/tema/theme_builder.gd`, `godot/app/body_view.gd`, `godot/app/slider_panel.gd`,
  `pruebas/godot/probar_tema.gd`.

## 4. Diseño

- **Etiqueta:** variación `EtiquetaZona` (`Label`): fondo `texto` y letra `panel`, como `TooltipPanel`.
- **Tirador:** `HSlider` usa el mismo icono que `BarraNeutro` (`_grabber`): el de Godot es blanco.
- **Lupa:** Godot no tiñe el `right_icon` de `LineEdit`; el tema guarda `buscar` teñido de `texto_2`
  (`ThemeBuilder.tinted`) y `slider_panel` lo pone al cambiar el tema (lo pide a sí mismo: el aviso le llega antes
  que a `search`). `clear_button_color` = `texto_2`.

## 5. Prueba

`probar_tema.gd`: (8) tirador, lupa y etiqueta ≥ 3:1 sobre su fondo (el límite del agarrador, D43); (6) en claro la
lupa tiene el color `texto_2` del claro. **Detecta el fallo:** sin el tirador → falla la (8); sin teñir → la (6).

## 6. Juicio visual

`pruebas/capturas/ventana/5_ajustes_claro.png`, `9_zona_iluminada.png` y `pruebas/capturas/interfaz/iu11/hoja.png`.
