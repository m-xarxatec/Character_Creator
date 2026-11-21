# TA.3d — La espada siempre con 144 triángulos

## 1. Objetivo y cierre

Quitar la subdivisión que TA.3b añadía al cambiar una proporción, sin cambiar la forma de la espada. Se cierra con la prueba ampliada, los fallos provocados, las regresiones y el visto bueno del responsable a la hoja de antes y después.

## 2. Nivel

Sencillo: un cambio pequeño en el generador y en su prueba.

## 3. Contexto

La espada son cuatro piezas separadas que se tocan. TA.3b subdividía sus tapas para que el validador no soldara aristas entre piezas al exigir que el conjunto fuera un solo sólido.

Comprobado en Godot 4.7.2 el 2026-11-21 con 5187 recetas (2187 combinaciones de extremos y 3000 al azar):

- Hoy salen entre 144 y 272 triángulos; sin subdivisión, siempre 144.
- Sin subdivisión no hay errores y cada pieza conserva su caja y su volumen. Al 100 % los arrays son idénticos.
- Con hoja de 128 × 27 mm, mango al 90 % y pomo al 80 %, el aro del mango coincide con el del pomo. Cada pieza es un sólido cerrado, pero el conjunto soldado da «Arista compartida por más de dos caras».

## 4. Archivos

Crear esta ficha. Cambiar `godot/addons/creador/taller_assets/sword_generator.gd`, `pruebas/godot/probar_generador_espada.gd` y `PLAN.md`. Guardar la hoja en `pruebas/capturas/interfaz/ta3d/`.

## 5. Diseño

1. Quitar `edge_split` de `_surface` y de sus tres llamadas.
2. El generador valida cada pieza como sólido cerrado y deja de validar el conjunto soldado.
3. La prueba sustituye «conjunto cerrado» y «variante cerrada» por un conjunto válido de 144 triángulos.
4. La prueba añade la receta de aros coincidentes y comprueba que genera, que sus piezas están cerradas y que el conjunto soldado no es un solo sólido, para que el caso siga siendo real.

## 6. Pruebas

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_generador_espada.gd)
```

Como controles negativos, en una copia temporal, restaurar la subdivisión y, por separado, volver a validar el conjunto soldado en el generador. La prueba debe fallar en ambos. Después, pasar la autoprueba y las regresiones sin ventana.

## 7. Trampas

El contador del visor usa `get_faces`: debe seguir diciendo 144. No hay que tocar los límites de la receta ni el validador.

## 8. Revisión visual

Generar una hoja con antes y después de varias recetas, de frente y en ¾, con su número de triángulos.

## 9. Si aparece un bloqueo

Si alguna receta válida cambia de forma o deja de generar, presentar el caso antes de ampliar el paso.
