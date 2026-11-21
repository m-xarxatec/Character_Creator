# TA.4a — De la imagen al contorno

## 1. Objetivo y cierre

Convertir una imagen sencilla en el contorno cerrado de su objeto principal y avisar de lo que ese contorno no representa: otras islas, huecos o recortes. Se cierra con la prueba nueva, el fallo provocado, las regresiones y el visto bueno del responsable a la hoja de contornos. TA.4 continúa con TA.4b (contorno a malla extruida) y TA.4c (importar y ajustar en el Taller).

## 2. Nivel

Fuerte, como marca la hoja de ruta para los contornos. De este resultado depende que la extrusión posterior sea válida.

## 3. Contexto

Consultar [TA.4 en la hoja de ruta](<../../taller assets/pasos_a_seguir.md>), [el §5.2 del plan](<../../taller assets/plan.md>) y [las imágenes de TA.1b](../../pruebas/godot/taller_fixtures.gd).

Comprobado en Godot 4.7.2 con imágenes sintéticas el 2026-11-21:

- `BitMap.opaque_to_polygons` da un polígono por isla sobre las esquinas de los píxeles, con caja y área exactas y sentido horario con Y hacia abajo.
- Solo traza el contorno exterior: un anillo sale relleno. Dos islas que se tocan por una esquina cuentan como dos.
- Al simplificar se conservó el orden de las islas (38 de 38).
- Simplificar puede cruzar el contorno. En 300 formas finas hubo 0 cruces con 2 px o menos, 1 con 4 px y 8 con 8 px, pero una forma fija de tres rectángulos ya se estropea con 1 px. `Geometry2D.triangulate_polygon` no detectó todos, así que hace falta una comprobación propia.
- A 1024 × 1024: recorrer los píxeles, 93 ms; trazar el contorno, 20 ms; reducir desde 2048 px, 14 ms. Comprobar cruces con 1000 vértices, 28 ms.

## 4. Archivos

Crear `godot/addons/creador/taller_assets/image_mask.gd` y `pruebas/godot/probar_mascara_imagen.gd`, con sus UID. Registrar el resultado en `PLAN.md` y guardar la hoja de contornos en `pruebas/capturas/interfaz/ta4a/`. No se tocan los archivos de TA.3c, la receta, el validador ni `taller_fixtures.gd`.

## 5. Diseño

1. Exponer `static func analyze(image: Image, options := {}) -> Dictionary`. En éxito devuelve `{"error": "", "contorno": PackedVector2Array, "tamano": Vector2i, "fondo": "alfa" | "color", "islas": int, "huecos": int, "avisos": PackedStringArray}`. En fallo, `{"error": "mensaje en español"}`. El contorno va en píxeles de la copia de trabajo, con origen arriba a la izquierda. Sin interfaz, archivos ni red.
2. Opciones, con su valor inicial y su rango: `umbral_alfa` 0,5 (0–1), `tolerancia` 0,1 (0–1), `simplificacion` 1 px (0–4) e `invertir` falso. Una opción desconocida o fuera de rango devuelve error.
3. Copia de trabajo: rechazar una imagen nula, vacía o con un lado mayor de 4096 px. Duplicarla, descomprimirla si hace falta, pasarla a RGBA8 y reducir su lado mayor a 1024 px con interpolación bilineal, con aviso. El original no cambia.
4. Fondo: si `detect_alpha()` indica transparencia, es sólido lo que supera `umbral_alfa`. Si no, el fondo es la media de las cuatro esquinas. Si alguna se aleja más que `tolerancia`, devolver el error de fondo no uniforme. Un píxel es sólido si algún canal RGB se aleja más que `tolerancia`, y se avisa de que se usó el color. `invertir` intercambia sólido y fondo.
5. Máscara: en una sola pasada, llenar dos búferes LA8, el sólido y su complemento, y crear con ellos dos `BitMap` mediante `create_from_image_alpha`.
6. Objeto principal: las islas salen de `opaque_to_polygons(rect, 0)`. Sin islas, error. Se elige la de mayor área y, si empatan, la primera. Con menos de 4 px² de área, error. Avisar si hay más islas (se usa solo la mayor) o si toca el borde de la imagen (puede estar recortado).
7. Huecos: contar las regiones del complemento que no tocan el borde de la imagen y tienen un punto interior dentro del contorno principal. Avisar de que se rellenan: el MVP no admite agujeros.
8. Contorno final: tomar la misma posición en `opaque_to_polygons(rect, simplificacion)`. Si la lista cambia de tamaño o el polígono se cruza, usar el contorno exacto y avisar. Con más de 1000 vértices, devolver un error que pida subir la simplificación. Ese tope equivale a unos 4000 triángulos en la malla.

Los límites de 4096 px, 1024 px, 4 px² y 1000 vértices se marcan `# PROVISIONAL` hasta que el responsable los apruebe con la medida real.

## 6. Pruebas

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_mascara_imagen.gd)
```

Usar las cuatro imágenes de `taller_fixtures.gd`: el rectángulo da caja y área exactas, la vacía da error, la del borde avisa y el fondo uniforme da el mismo contorno que el alfa. Añadir imágenes en memoria: L cóncava, anillo, dos islas, isla dentro de un hueco, hueco en una isla secundaria (no cuenta), alfa suave con dos umbrales, fondo con ruido dentro y fuera de la tolerancia, esquinas distintas, `invertir`, formatos RGB8, LA8 y L8, 4097 px (error), 2048 px (reducida en proporción y con aviso) y opciones inválidas. Comprobar que el original no cambia, que dos análisis son idénticos y que todo contorno devuelto es simple y triangulable. Incluir una forma fija que se cruce al simplificar y verificar que vuelve al contorno exacto.

Como controles negativos, en una copia temporal, elegir la primera isla en lugar de la mayor y, por separado, quitar la comprobación de cruces. La prueba debe fallar en ambos. Después, repetirla sobre el código real y pasar la autoprueba y las regresiones sin ventana.

## 7. Trampas

El contorno está con Y hacia abajo: al pasar a 3D, TA.4b debe invertir Y y el orden de los vértices. La reducción bilineal mezcla objeto y fondo en el borde, y con fondo de color esos píxeles cuentan como sólidos. Una imagen RGBA totalmente opaca no tiene transparencia útil y debe seguir el camino del color. Una imagen totalmente transparente es un error, no un contorno vacío.

## 8. Revisión visual

Generar una hoja con las imágenes de prueba y el contorno detectado dibujado encima. El responsable comprueba que sigue la silueta y que los avisos corresponden a cada caso. Si aporta la imagen de la espada usada como referencia, se prueba a mano, sin añadirla al repositorio salvo que lo autorice.

## 9. Si aparece un bloqueo

Si una imagen sencilla no da un contorno usable o hace falta admitir agujeros, presentar el caso y el diagnóstico antes de ampliar el paso. Los agujeros están fuera del MVP.
