# IU.3 — Vista 3D bonita

> Fase IU (`propuestas/expansion_v2.md` §3, IU.3; `diseno/GUIA_INTERFAZ.md` §5.3). Decidido el 2026-11-19: Opus 5.5
> con esfuerzo alto, sin revisor-visual; lo juzga y aprueba el responsable.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** que la vista 3D se vea cuidada sin tocar el estilo del personaje.

**Hecho cuando:**
- Detrás del personaje hay un degradado radial `vista_centro` → `vista_borde` que cambia con el tema claro u oscuro.
- Bajo los pies hay una sombra suave que sigue al personaje en X y Z y se queda en el suelo (y = 0) al animar.
- En Ajustes, «Vista 3D»: «Rejilla en el suelo» (apagada por defecto, se guarda) y la luz de vista previa: «Giro de
  la luz» (−180° a 180°) e «Intensidad de la luz» (0,5–2). La luz no se guarda ni se exporta.
- El contorno y el color del personaje no cambian con el fondo transparente (medido, §6).

## 2. Nivel de modelo

**Medio.** Opus 5.5, esfuerzo alto (decisión del responsable).

## 3. Contexto mínimo

`body_view.gd` (`_ready`, `_add_world`), `settings_file.gd`, `settings_dialog.gd`, `main.gd` (`set_dark`, Ajustes),
`tema/tokens.gd`, `pruebas/godot/probar_tema.gd` (excepción de `body_view.gd`), `capturar_ventana.gd`.

## 4. Archivos

- **Se crean:** `godot/app/floor_shadow.gd`, `godot/app/tema/suelo.gdshader`, `pruebas/godot/probar_vista_bonita.gd`.
- **Se tocan:** `body_view.gd`, `settings_file.gd` (`get/set_grid`), `settings_dialog.gd` (fila «Vista 3D»),
  `main.gd` (pasa el tema y los ajustes a la vista), `probar_tema.gd` (`body_view.gd` sale de las excepciones),
  `capturar_ventana.gd` (`8_vista*.png` y la medida A/B).
- **No se toca:** el núcleo (`addons/creador/`), `toon`/`outline`, el exportador.

## 5. Diseño

- **Fondo:** `viewport.transparent_bg = true`; un `TextureRect` hijo de `body_view` con `show_behind_parent = true`
  (se dibuja **debajo** de la imagen 3D), a pantalla completa, `mouse_filter = IGNORE`, `GradientTexture2D` radial
  (centro 0,5 / 0,45, radio hasta la esquina). `body_view.set_dark(dark)` pone los dos colores de
  `Tokens.palette(dark)`. Sale `BACKGROUND := Color(...)`: `body_view.gd` deja de ser excepción de §5.4.
  **Motivo:** el degradado de la guía, sin cambiar el `Environment` de la luz.
- **Sombra (`floor_shadow.gd`, `extends MeshInstance3D`):** `PlaneMesh` de 3 × 3 m con `ShaderMaterial`
  (`tema/suelo.gdshader`: `unshaded`, `blend_mix`, `cull_disabled`, `depth_draw_never`). La mancha es negra con
  alfa `SHADOW_ALPHA · (1 − smoothstep(0, 0,55 m, r))`. La rejilla, en el mismo shader (`uniform bool grid`):
  líneas cada 0,5 m que se apagan hacia el borde. `setup(skeleton, hips_bone)` y `_process`: X/Z = las de la cadera
  en el mundo, y = 0. **Motivo:** un solo plano y sin texturas.
- **Luz:** `body_view.set_light(turn_degrees, energy)` gira la `DirectionalLight3D` en Y (parte de `(−40, 30, 0)`)
  y cambia `light_energy`. Solo la vista: el exportador no mira la luz.
- **Ajustes:** `SettingsFile.get_grid()` (`_read_bool("rejilla", false)`), `set_grid`. El diálogo emite
  `grid_chosen(on)` y `light_chosen(turn, energy)`; `main.gd` los aplica a `body_view` (la rejilla además se guarda).
  `refresh` gana la rejilla y la luz actuales. **Motivo de no guardar la luz:** es para mirar; al abrir otra vez, la
  luz de siempre (la que usan las capturas).

## 6. Prueba

- **`probar_vista_bonita.gd`** (sin ventana, con `main.gd`; borra `user://ajustes.cfg` al empezar y al terminar):
  1. `viewport.transparent_bg` y el fondo está detrás (`show_behind_parent`) con los colores del tema oscuro; tras
     `set_dark(false)`, los del claro.
  2. Con una animación, durante 0,5 s: sombra en y = 0 y X/Z de la cadera (± 1 mm).
  3. Rejilla apagada por defecto; `grid_chosen(true)` la enciende y queda guardada.
  4. Exportar a `user://` con la luz normal y con la luz girada 120° y a 2,0: el `.tres` de los dos es igual
     byte a byte (y el `.glb`).
  - **Detecta el fallo:** no seguir a la cadera → falla la 2; no guardar la rejilla → falla la 3.
- **Medida A/B (con ventana, `capturar_ventana.gd`):** la misma vista con fondo opaco gris y con fondo transparente
  compuesto sobre el mismo gris; diferencia máxima por píxel ≤ 2/255 `# PROVISIONAL`. Si pasa de ahí, plan B de la
  guía y avisar.
- Al cerrar: las sin ventana, `probar_tema`, `probar_ajustes`, `datos`, `licencias` y la autoprueba.

## 7. Trampas conocidas

- `show_behind_parent` en un hijo de `SubViewportContainer`: comprobarlo en la captura (si tapa al personaje,
  ponerlo como hermano anterior en `main.gd`).
- El plano de la sombra no debe tapar los pies: `depth_draw_never` y a y = 0 (los pies están en y ≥ 0).
- Sin ventana no hay imagen: la medida A/B solo con ventana.

## 8. Juicio visual

Capturas `8_vista.png`, `8_vista_claro.png` y `8_vista_rejilla.png` en `pruebas/capturas/ventana/`. ¿Ayuda el fondo,
se ve la sombra sin molestar? Lo juzga el responsable.
