# TA.3a — Primera malla de espada a partir de una receta

## 1. Objetivo y cierre

Obtener una espada virtual de cuatro superficies a partir de la receta v1 actual. Dos recetas deben producir siluetas distintas, cada superficie debe ser válida como sólido y una misma receta debe reproducir la misma malla. TA.3 continuará con los parámetros adicionales de punta, guarda, mango y pomo y los controles del visor.

## 2. Nivel

Fuerte. El orden de los vértices, las normales facetadas y las uniones entre superficies determinan si el modelo se dibuja bien al girarlo.

## 3. Contexto

Consultar [TA.3 en la hoja de ruta](<../../taller assets/pasos_a_seguir.md>), [la receta v1](../../godot/addons/creador/taller_assets/asset_recipe.gd) y [el validador de superficies](../../godot/addons/creador/taller_assets/asset_validator.gd). La longitud de la receta mide la hoja. La espada existente de la prueba de anclajes tiene su propio cometido.

## 4. Archivos

Crear `godot/addons/creador/taller_assets/sword_generator.gd` y `pruebas/godot/probar_generador_espada.gd`, con sus UID. Actualizar el registro de `PLAN.md`. Guardar las capturas en `pruebas/capturas/interfaz/ta3a/`.

## 5. Diseño

1. Exponer `static func generate(data: Dictionary) -> Dictionary`. Llamar a `AssetRecipe.normalize`, exigir el modo `espada_parametrica` y devolver un error en español si falla. En éxito devolver `{"error": "", "malla": mesh}`, con un recurso ArrayMesh nuevo en cada llamada.
2. Usar el centro del mango como origen local, Y hacia la punta y +Z al frente. La longitud, anchura y grosor de la hoja deben coincidir con los tres parámetros existentes. Crear la hoja con sección romboidal, la guarda transversal, el mango poligonal y el pomo facetado. Derivar las proporciones de muestra de los parámetros existentes hasta incorporar los cuatro controles adicionales.
3. Emitir triángulos con frente horario y normales planas. Validar cada pieza cerrada y el conjunto con `AssetValidator.validate` antes de entregar la malla. Nombrar las superficies `hoja`, `guarda`, `mango` y `pomo`. Asignar los tres colores de la receta, compartiendo el de la guarda con el pomo.

## 6. Pruebas

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_generador_espada.gd)
```

Probar la receta por defecto y otra que cambie las tres dimensiones y los colores. Medir la caja de la hoja en los tres ejes con la comparación aproximada de Godot, el origen dentro del mango y la posición del pomo y la punta a lados opuestos. Verificar nombres, colores y cierre por superficie. Comparar todos los arrays de dos generaciones idénticas. Probar una receta inválida y una de otro modo. Como control negativo, retirar una cara de la hoja y comprobar que la prueba falla. Restaurarla, repetir y ejecutar la autoprueba y las regresiones sin ventana.

## 7. Trampas

El volumen total positivo puede ocultar una pieza invertida. Comprobar cada pieza por separado. Evitar aristas coincidentes entre dos sólidos que el validador identificaría como compartidas por más de dos caras. Una dimensión que no se pueda representar con vértices finitos debe producir un error controlado.

## 8. Revisión visual

Renderizar la malla devuelta en una escena temporal de prueba y capturar frente, perfil y tres cuartos. El responsable revisa la silueta y si distingue las cuatro piezas. La integración interactiva en el Taller llegará en un subpaso posterior.

## 9. Si aparece un bloqueo

Si un caso requiere cambiar la receta v1, el validador o los límites de una prueba existente, registrar el caso y presentarlo al responsable antes de ampliar el alcance.
