# TA.4c — Importar y ajustar una imagen en el Taller

> **Estado: propuesta pendiente de aprobación.** No hay código de este paso. Presentarla al responsable y esperar su OK, incluidos los límites de altura y grosor del §5.2.

## 1. Objetivo y cierre

En el modo «Desde imagen», elegir un PNG, ver su contorno y su pieza 3D y ajustarla. Se cierra con las pruebas, los fallos provocados, las regresiones y el visto bueno del responsable a las capturas. Guardar, Equipar y Exportar siguen desactivados hasta TA.5 y TA.6.

## 2. Nivel

Medio: integra piezas ya probadas, con cuidado en la lectura de archivos.

## 3. Contexto

Consultar [TA.4 en la hoja de ruta](<../../taller assets/pasos_a_seguir.md>), [el §5.2 del plan](<../../taller assets/plan.md>), [TA.4a](ta.4a_contorno_imagen.md), [TA.4b](ta.4b_malla_extruida.md) y, como modelo de panel, [TA.3c](ta.3c_edicion_espada.md).

Medido en Godot 4.7.2 el 2026-11-21:

- Un PNG de 8192 × 8192 y 276 KB ocupó 256 MB y tardó 282 ms en decodificarse. Leer su cabecera tarda 0,003 ms.
- Vacío, texto, cortado, solo firma, firma rota y ancho falso: `load_png_from_buffer` devuelve error y deja la imagen vacía, sin cerrar el programa.
- `ImageMask.analyze` tarda de 113 a 170 ms. `SilhouetteMesh.generate` tarda 0,6 ms con un contorno sencillo y 12 ms en el peor caso medido (960 vértices).

## 4. Archivos

Crear `godot/addons/creador/taller_assets/image_source.gd`, `godot/app/taller_assets/image_panel.gd` y `pruebas/godot/probar_fuente_imagen.gd`, con sus UID. Cambiar `asset_recipe.gd`, `workshop_page.gd`, `pruebas/godot/probar_receta_asset.gd`, `pruebas/godot/probar_ventana.gd` y `PLAN.md`. Guardar las capturas en `pruebas/capturas/interfaz/ta4c/`.

## 5. Diseño

1. `ImageSource.load_png(path)` devuelve `{"error": "", "imagen": Image, "archivo": "fuentes/<nombre>.png", "sha256": String}` o `{"error": "mensaje en español"}`. Lee primero 24 bytes, comprueba la firma PNG y el tamaño de la cabecera IHDR, y rechaza más de 4096 px **antes** de decodificar. El hash se calcula sobre los mismos bytes que se decodifican.
2. La receta limita la extrusión a `altura_m` 0,10–3,00 y `grosor_m` 0,002–0,200 (**por aprobar**). Generalizar `_outside_sword_limits`; la espada conserva sus límites.
3. `image_panel.gd`, como `sword_panel.gd`: no genera nada, emite cambios y carga los valores en bloque. Tiene Elegir imagen, miniatura con el contorno, Altura, Grosor, Umbral o Tolerancia según el fondo, Simplificación, Invertir, Color, avisos y Restablecer.
4. `workshop_page.gd` expone `load_image_file(path)`, que se puede probar sin abrir el diálogo. El `FileDialog` filtra `*.png` y usa la última carpeta, como `body_actions.gd`.
5. Altura, grosor y color rehacen la malla al momento desde el último contorno. Los ajustes del contorno se recalculan con un `Timer` de una vez, 0,15 s después del último cambio.
6. Si falla la carga, el análisis o la malla, se muestra el motivo y se conservan la última pieza válida y su receta. Cambiar de modo no pierde la imagen ni la espada.
7. Los ajustes del contorno viven en la página. Su guardado en la receta pertenece a TA.5. Solo se admite PNG, como exige la receta.

## 6. Pruebas

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_fuente_imagen.gd)
```

Crear los PNG en una carpeta temporal: válidos, con alfa y con fondo de color, de 4096 y 4097 px, dañados, con otra extensión y sin existir. Comprobar en la ventana el recorrido completo: cargar, editar cada control, error con última pieza conservada, Restablecer y cambio de modo. Comprobar los límites nuevos de la receta.

Como controles negativos, en una copia temporal: decodificar antes de leer la cabecera, desconectar un control del panel y quitar la espera del contorno. Después, pasar la autoprueba y las regresiones sin ventana.

## 7. Trampas y notas para continuar

- `godot --path godot --import` crea UID de otros scripts. Crear solo los UID de este paso y revisar `git status`.
- `user://` debe aislarse en las pruebas con `XDG_DATA_HOME` para no tocar los ajustes del responsable.
- El bucle de `ruta/GUIA_MODELOS.md` §5 está desactualizado: añadir a las pruebas con ventana `probar_legibilidad`, `probar_hombro_natural` y `probar_variante_t`. Saltar también `probar_normales_leidas`, que depende de una de ellas. Lanzar cada script como diga su cabecera; `probar_glb` recibe `pruebas/fase_3/salida/t`.
- Si falta `pruebas/fase_2/salida/referencia_reajuste.json`, generarlo con `blender -b -P pruebas/fase_2/referencia_reajuste.py`.
- `_check_core_independent` de `probar_ventana.gd` no recorre subcarpetas, así que no vigila `taller_assets/`. No forma parte de este paso: proponerlo aparte.
- Siguen `# PROVISIONAL`, a la espera de aprobación con su medida: 4096 px, 1024 px, 4 px² y 1000 vértices en `image_mask.gd`, y la tolerancia de volumen 1e-6 en `probar_malla_silueta.gd`.

## 8. Revisión visual

Entregar capturas en claro y oscuro, a 1280 × 720 y 1920 × 1080, sin describirlas. El responsable hace la revisión en persona: no ofrecer el revisor-visual en el Taller.

## 9. Si aparece un bloqueo

Si los controles no caben a 1280 × 720 o la carga exige ampliar la receta, presentar el caso antes de ampliar el paso.
