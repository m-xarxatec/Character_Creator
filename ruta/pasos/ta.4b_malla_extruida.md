# TA.4b — Del contorno a la malla extruida

## 1. Objetivo y cierre

Convertir el contorno de TA.4a en un sólido cerrado con frente, espalda y laterales. Se cierra con la prueba nueva, los fallos provocados, las regresiones y el visto bueno del responsable a la hoja de mallas. TA.4 continúa con TA.4c (importar y ajustar en el Taller).

## 2. Nivel

Fuerte, como marca la hoja de ruta para contornos y triangulación.

## 3. Contexto

Consultar [TA.4 en la hoja de ruta](<../../taller assets/pasos_a_seguir.md>), [el §5.2 del plan](<../../taller assets/plan.md>) y [la ficha de TA.4a](ta.4a_contorno_imagen.md).

Comprobado en Godot 4.7.2 el 2026-11-21 con un prototipo:

- 1652 contornos reales de `image_mask.gd` generan un sólido cerrado con caja, volumen y triángulos correctos. El mayor, de 960 vértices, da 3836 triángulos.
- Otros 1200 contornos de imágenes con ruido no se tocan a sí mismos.
- `triangulate_polygon` aceptó 1137 de 29 675 contornos no simples, así que hace falta una comprobación propia de cruces.

## 4. Archivos

Crear `godot/addons/creador/taller_assets/silhouette_mesh.gd` y `pruebas/godot/probar_malla_silueta.gd`, con sus UID. Registrar el resultado en `PLAN.md` y guardar la hoja en `pruebas/capturas/interfaz/ta4b/`. No se tocan la receta, el validador, `image_mask.gd` ni la interfaz.

## 5. Diseño

1. Exponer `static func generate(data: Dictionary, contour: PackedVector2Array) -> Dictionary`, que devuelve `{"error": "", "malla": ArrayMesh}` o `{"error": "mensaje en español"}`. Sin interfaz, archivos ni red.
2. Validar la receta con `normalize` y exigir el modo `extrusion_imagen`.
3. Limpiar el contorno: quitar puntos repetidos y en línea. Un valor no finito o un retroceso es un error.
4. Rechazar un contorno que se cruce o se toque, y uno que no se pueda triangular. Admitir los dos sentidos de giro.
5. Pasar a metros: invertir Y, escalar para que la altura sea `altura_m`, conservar la proporción, centrar en X y dejar la base en Y = 0.
6. Crear frente en +Z, espalda en -Z y dos triángulos por arista lateral, con normales planas. Un contorno de n vértices da 4n - 4 triángulos.
7. Validar el sólido con `asset_validator.gd` y devolver una superficie `principal` con el color de la receta.

## 6. Pruebas

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_malla_silueta.gd)
```

Probar un prisma, la L de `taller_fixtures.gd`, una espada sintética y contornos reales con varias simplificaciones. Comprobar triángulos, caja, base, centrado, volumen, normales, orientación de la imagen, sentido de giro, puntos sobrantes, reproducibilidad y entradas inválidas.

Como controles negativos, en una copia temporal: no invertir Y, quitar la comprobación de cruces, aceptar retrocesos y omitir los laterales. La prueba debe fallar en todos. Después, pasar la autoprueba y las regresiones sin ventana.

## 7. Trampas

Invertir Y cambia el sentido del contorno. Un contorno sin laterales o con la espalda sin invertir deja de ser un sólido. Los huecos ya llegan rellenos desde TA.4a. Los límites de altura y grosor de la extrusión se deciden en TA.4c, con sus controles.

## 8. Revisión visual

Generar una hoja con cada imagen y su malla de frente, de perfil y en ¾. El responsable comprueba que la silueta se conserva, que no sale invertida y que tiene grosor real.

## 9. Si aparece un bloqueo

Si un contorno válido de TA.4a no genera malla o hace falta admitir agujeros, presentar el caso antes de ampliar el paso.
