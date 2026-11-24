# SH.8 y SH.8b — Rubor, labios y pecas

> Ficha del 2026-11-23 (nivel: medio). **Hecha el 2026-11-23, apagada; falta el juicio visual (§6) y elegir los valores.** Decisiones: D48 (color calculado desde la piel) y D52 (pecas de 1 a 10) en `ruta/DECISIONES.md`. Une el antiguo AC.2 (labios).

## 1. Objetivo y «Hecho cuando»

Rubor en mejillas, nariz, puntas de las orejas, hombros, codos, rodillas y nudillos; labios; y pecas con un deslizador de 1 (pocas, en la cara) a 10 (todo el cuerpo). Todo bonito y nada exagerado, con colores que salen del color de la piel y en cualquier tono.

Hecho cuando:

- Con los valores por defecto (`blush_amount`, `lips_amount` y `freckles` a 0) nada cambia, y sin `piel.png` tampoco.
- Rubor: más saturado, girado hacia el rosa y casi sin oscurecer. Labios: más saturados y algo más oscuros. Un blanco o un gris siguen sin matiz.
- Nada en la prenda.
- Pecas: solo oscurecen; con 0, ninguna; el nivel 1 ya pone alguna en la nariz y las mejillas; más nivel, más pecas; una zona a 0,2 de la distancia máxima no tiene pecas con 5 y sí con 8; nunca en ojos, labios, palmas ni plantas; con 10, como mucho el 25 % de la piel del centro de la cara.
- Las 6 capturas de referencia no cambian (el MVP no usa nada de esto).

## 2. Archivos

| Subpaso | Se crean | Se cambian |
| --- | --- | --- |
| SH.8a, datos | `blender/generar_zonas_piel.py`, `godot/datos/humana/piel.png` y `piel.png.import` (`importer="keep"`) | `manifiesto.json` (sha256), `godot/datos/FORMATO.md`, `blender/exportar_datos.py` (lo incluye si existe), `species_data.gd` (`skin_zones`) |
| SH.8 y SH.8b, shader | — | `toon_soft.gdshader`, `body_material.gd` (`SOFT_DEFAULTS`, `set_skin_zones`), `godot/app/body_view.gd` (una línea), `pruebas/godot/probar_piel.gd` |

`eye_layers.gdshader` no cambia: todo va fuera del bloque común.

## 3. Diseño: el mapa de zonas

No se pinta a mano: `generar_zonas_piel.py` lo calcula desde la geometría de `cuerpo.glb` (pose A, sin formas) y lo rasteriza sobre las UV de MakeHuman. Así es nuestro (CC0) y sigue a la cara al mover los deslizadores, porque las UV no cambian.

- **Referencias:** nariz (el punto más adelantado de la línea media entre 1 y 6 cm bajo los ojos), boca (el más hundido entre 1,5 y 4 cm bajo la nariz), mejillas (bajo y algo por fuera de cada ojo, de `ojos.json`), orejas (el punto más alto de la parte más ancha de la cabeza a la altura de los ojos). Rodillas, codos, hombros y nudillos salen de `articulaciones.json`, con la cara de la piel que mira al lado correcto (rodilla delante, codo detrás, hombro arriba, nudillos por fuera).
- **R, rubor:** suma de manchas gaussianas con su fuerza (mejillas 1, orejas 0,8, nariz 0,6, rodillas 0,6, codos 0,55, nudillos 0,5, hombros 0,45).
- **G, cercanía para las pecas:** `1 - sqrt(distancia / 1,7 m)` desde el centro de la cara; 0 en ojos, labios, palmas, plantas y fuera de la piel. Así, sin textura (negro) no hay pecas.
- **B, labios:** una elipse alrededor de la boca.
- Cada isla se extiende 6 píxeles para que el filtro no mezcle con el fondo. Hay que volver a generarlo si cambian las UV o la forma base.

## 4. Diseño: el shader

```glsl
uniform sampler2D skin_zones : hint_default_black, filter_linear_mipmap, repeat_disable;
color = mix(color, tint_of(color, 0.97, 12.0, 1.45, 0.96), zones.r * blush_amount * skin);  // rubor, hacia el rosa
color = mix(color, tint_of(color, 0.98, 14.0, 1.6, 0.85), zones.b * lips_amount * skin);   // labios
color = mix(color, tint_of(color, 0.07, 10.0, 1.35, 0.72), freckle_cover(UV, zones.g) * skin);  // pecas, hacia el marrón
```

- Se aplica al color antes de la luz: la sombra calculada, la banda y el brillo siguen funcionando encima.
- **Pecas:** el nivel N llega hasta `0,035 · (1 / 0,035)^((N − 1) / 9)` de la distancia máxima (1 = nariz y mejillas, 3 = la cara, 5 = cuello y pecho, 10 = todo). Patrón de puntos sobre las UV (240 celdas por unidad), con tamaño, opacidad y presencia aleatorios por celda; menos densidad lejos de la cara y en los niveles bajos. Opacidad máxima 0,6. Cuando una peca ocupa menos de un píxel se apaga, en vez de parpadear. La cara tiene el doble de UV por metro que el cuerpo: sus pecas salen más finas, como en la realidad.
- El deslizador de 1 a 10 va en la interfaz con SH.7 (sin controles nuevos hasta entonces). No entra en `FINISH` ni en los presets todavía.

## 5. Prueba

`probar_piel.gd` (la de SH.3c). Esferas con una textura de zonas constante; las pecas, en una esfera de 384 píxeles. Que detecta el fallo (en una copia, con `--shader`): el rubor sin `* skin` (prenda, 54/255); `float zone = 1.0;` (zona lejana con 5); `FRECKLE_OPACITY = -0.6` (pecas claras).

## 6. Juicio visual

`pruebas/capturas/shader_piel/`: `hoja_rubor_cuerpo.png` y `hoja_rubor_cara.png` (A sin, B con rubor 0,35 y labios 0,45), `hoja_pecas_cara.png` (primer plano) y `hoja_pecas_cuerpo.png` (columnas: nivel 1, 3, 5 y 10, con el rubor).

Preguntas: ¿qué `blush_amount` y `lips_amount` van a `SOFT_DEFAULTS`? ¿Las pecas, de tamaño y cantidad? ¿Las zonas de rubor caen donde deben? Para SH.8c: ¿rubor y pecas pintados en la textura del `.glb` (recomendado) o nada?
