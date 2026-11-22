# SH.1 — Hoja A/B del shader anime, sin tocar el programa

> Ficha del 2026-11-22 (nivel: medio). **Cerrada el 2026-11-22:** base elegida, la columna anime, sin su tinte fijo (D48). Meta: D47 en `ruta/DECISIONES.md`.

## 1. Objetivo y «Hecho cuando»

Comparar en una hoja el MVP, el toon suave y el anime, para que el responsable elija antes de tocar el núcleo.

Hecho cuando:

- Existen las 4 hojas de `pruebas/capturas/shader_ab/` y las medidas del lado sin luz.
- La prueba termina en `RESULTADO: TODO BIEN`.
- `git diff --stat -- godot/` sale vacío.
- El responsable ha mirado las hojas y ha decidido qué hacer con el anime y con las luces omni.

## 2. Nivel de modelo

Medio: shaders y script de pruebas, con el diseño ya escrito. Modelo recomendado: barato (Sonnet 5.5). Si aparece una señal de alarma, parar y avisar.

## 3. Contexto mínimo

- `godot/addons/creador/toon.gdshader`, `outline.gdshader` y `body_material.gd` (`PULL_CODE`, `SHADER`, `OUTLINE_SHADER`).
- `godot/app/body_view.gd:413-505` (`_add_world`, `_load_character`, `set_piece`).
- `pruebas/capturas/shader_propuesta/proto/godot/toon2.gdshader` y `proto_hoja.gd` (`_to_new`, `_shot`): prototipo de partida.
- `pruebas/godot/capturar_hoja_iu.gd:17-23`: cómo cargar `godot/app/` con una ruta absoluta.

## 4. Archivos

- **Se crean:**
  - `pruebas/godot/estilo/toon_suave.gdshader`: copia de `toon2.gdshader`, sin cambios.
  - `pruebas/godot/estilo/contorno_tenido.gdshader`.
  - `pruebas/godot/capturar_hoja_shader.gd`.
- **Se tocan al cerrar:** `PLAN.md`.
- **No se tocan:** nada de `godot/`, las capturas aprobadas, los límites de otras pruebas ni la copia `proto/`.

## 5. Diseño

**Uso:** `(ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s capturar_hoja_shader.gd 2>&1 | grep -E 'FALLO|RESULTADO|MEDIDA|ERROR')`. Necesita ventana.

**Carga.** Con `--path pruebas/godot`, cargar `godot/app/body_view.gd` y `preset.gd` por ruta absoluta. Los dos shaders de prueba se leen con `FileAccess.get_file_as_string` y `Shader.new()`. Comprobado el 2026-11-22: la vista carga, las piezas se ponen y ambos shaders compilan.

**Columnas** (constantes al principio del script):

| Valor | MVP | Suave | Anime |
| --- | --- | --- | --- |
| Shader | `BodyMaterial.SHADER` | `toon_suave` | `toon_suave` |
| `softness` | 0,04 | 0,28 | 0,09 |
| `threshold` | — | 0,05 | 0,05 |
| `ground_weight` | — | 0,2 | 0,025 |
| `rim_strength` | 0,25 | 0,08 | 0,075 |
| `shade_tint` | — | (0,70; 0,55; 0,58) | (0,92; 0,72; 0,72) |
| Contorno | Negro, 2,5 px | Teñido × (0,28; 0,22; 0,22), 1,5 px | Teñido × (0,45; 0,30; 0,30), 1,25 px |
| Sombra proyectada | No | Sí | Sí |

Los números del anime son el punto medio de los rangos aprobados. Sus dos tintes son valores de partida, sin medir.

**Filas** (colores sRGB):

| Preset | Piel | Pelo | Ropa OverScore (`os_tank_top`, `os_golf_shorts`) |
| --- | --- | --- | --- |
| `anime` | Clara (0,96; 0,80; 0,70) | `makehuman/toigo_blunt_bob_with_bangs`, verde (0,20; 0,55; 0,35) | Negra (0,10; 0,10; 0,11) |
| `femenino` | Oscura (0,30; 0,19; 0,14) | `quaternius/hair_long`, castaño (0,30; 0,20; 0,15) | Azul grisáceo (0,28; 0,33; 0,45) |
| `masculino` | Media (0,72; 0,50; 0,36) | `makehuman/short02`, rubio (0,62; 0,46; 0,22) | Blanca (0,85; 0,85; 0,82) |

**Hojas** en `pruebas/capturas/shader_ab/`: 3 filas × 3 columnas (MVP, suave, anime), celdas de 420 × 560 px, fondo `Color8(199, 202, 204)`.

| Archivo | Giro | Inclinación | Mira a | Distancia | Nota |
| --- | --- | --- | --- | --- | --- |
| `hoja_cuerpo.png` | 25° | 8° | (0; 0,95; 0) | 4,0 m | |
| `hoja_cara.png` | 25° | 4° | (0; 1,55; 0) | 1,25 m | |
| `hoja_flequillo.png` | 0° | 2° | (0; 1,60; 0) | 0,75 m | Las 3 filas con `toigo_blunt_bob_with_bangs` |
| `hoja_omni.png` | 0° | 8° | (0; 0,95; 0) | 4,0 m | Solo luces omni |

**Escena omni.** Se apaga `view.light` y se añaden dos `OmniLight3D` sin sombra, ambas en el lado −X: (−1,6; 1,9; 1,2) con energía 3 y alcance 6, y (−1,2; 0,7; 0,6) con energía 1,5 y alcance 5. Color (1,0; 0,72; 0,45). **No se cambia cómo responde el shader a las omni.**

**Medida del lado sin luz.** Por cada fila y columna, se repite la captura omni con contorno 0 y `floor_shadow` oculto. En la mitad derecha de la imagen, solo con píxeles de alfa > 0,5:

`MEDIDA omni <preset> <columna>: luminancia_srgb_media=<x> negro=<y>%` (negro = luminancia sRGB < 0,03). Sin límite: es para decidir. Todas las líneas usan **luminancia sRGB**: `Color.get_luminance()` sobre los valores de la imagen final, sin pasarlos a lineal.

**Funciones:**

```gdscript
func _dress(row: Dictionary) -> bool            # preset, colores y piezas; false si falta una pieza
func _use_column(column: Dictionary) -> void    # shader, valores, contorno y sombra en cuerpo y piezas
func _copy_zone_colors(mesh: MeshInstance3D) -> void  # skin_color, garment_color y show_garment al contorno
func _shot(yaw: float, pitch: float, target: Vector3, distance: float) -> Image
func _measure_unlit(shot: Image) -> Array       # [luminancia media, % negro]
func _save_sheet(cells: Array[Image], file: String) -> void
```

**Algoritmo:** para cada fila, `_dress`; para cada columna, `_use_column` y las capturas; al final, guardar las 4 hojas. El cuerpo usa el shader tal cual. Las piezas, con `code.replace("void fragment()", BodyMaterial.PULL_CODE + "void fragment()")`, y conservan su `depth_pull`.

**Contorno teñido:** el `outline.gdshader` actual, con `if (!IN_SHADOW_PASS)` alrededor del empuje y este color:

```glsl
float garment = show_garment ? step(0.5, min(COLOR.r, COLOR.a)) : 0.0;
ALBEDO = mix(skin_color, garment_color, garment) * outline_tint;
```

## 6. Prueba

Dentro del mismo script, con líneas `bien` / `FALLO`:

1. Se ponen todas las piezas.
2. En MVP, el cuerpo usa `BodyMaterial.SHADER`. En suave y anime, no.
3. En `hoja_cuerpo`, por fila: más del `MIN_DIFF = 0.01  # PROVISIONAL` de los píxeles cambia más de 8/255 entre MVP y suave, y entre suave y anime. Si no: `FALLO suave igual a MVP` o `FALLO anime igual a suave`.
4. Existen las 4 hojas.

**Que detecta el fallo:**

- Apuntar la columna suave al shader del MVP → salta la comprobación 2 o `suave igual a MVP`.
- Dar al anime los valores del suave → salta `anime igual a suave`.
- Deshacer ambos cambios.

## 7. Trampas conocidas

- **Ropa negra:** con color × tinte, la línea siempre sale más oscura que la tela, y con negro puro sale negra. D47 pide línea gris. No añadir un suelo de color: se enseña en la hoja y decide el responsable.
- **Línea en la cara:** en SH.1 tiene el mismo grosor que en el resto. «Casi invisible» necesita un grosor por zona, que se decide en SH.4b.
- **Flequillo:** la sombra proyectada va entera porque `shadow_receive` llega en SH.4. La cara puede verse con más sombra de la que tendrá después.
- **Banda de brillo:** no sale en esta hoja, llega en SH.6b.
- **Omni:** el suelo de sombra del prototipo solo existe con luz direccional y el shader ignora la luz ambiental. No «arreglarlo»: es lo que se mide.
- **Contorno por malla:** cada pieza tiene su material de contorno. Hay que copiarle sus colores (`_copy_zone_colors`) o saldrá con los valores por defecto.
- **Volver al MVP:** restaurar `shader`, `width_px` y `light.shadow_enabled` en cada columna, o la siguiente fila hereda el estado.
- **`load()`:** no sirve para los shaders de `pruebas/godot/estilo/` si cambia el proyecto de arranque. Usar `FileAccess`.

## 8. Juicio visual

Dar solo las rutas de las 4 hojas y la tabla de medidas omni, sin describirlas ni valorarlas. Preguntas:

1. ¿El anime va en la dirección de D47, o qué valores cambio?
2. ¿La sombra bajo el flequillo y la línea en la ropa negra son aceptables para seguir?
3. Con solo omni, ¿el lado sin luz debe quedar como está o necesita un suelo?

## 9. Si te atascas

Si una pieza no carga, el shader no compila o la captura sale vacía, para y dilo. No sustituyas piezas ni cambies el diseño de las columnas sin aprobación.
