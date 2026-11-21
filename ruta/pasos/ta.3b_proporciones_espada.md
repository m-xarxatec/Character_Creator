# TA.3b — Proporciones editables de la espada del Taller

## 1. Objetivo y cierre

Variar de forma independiente la longitud de la punta, la anchura de la guarda, el radio del mango y el tamaño del pomo. La receta de TA.3a debe seguir produciendo la silueta aprobada, también cuando tenga dimensiones personalizadas.

## 2. Nivel

Medio. Se reutiliza la malla existente. El trabajo principal es conservar la compatibilidad y medir el efecto de cada ajuste.

## 3. Contexto

Consultar [TA.3 en la hoja de ruta](<../../taller assets/pasos_a_seguir.md>) y [la ficha del generador](ta.3a_generador_espada.md). Actualmente el generador calcula las cuatro proporciones a partir de las dimensiones de la hoja. El normalizador rechaza claves desconocidas y la prueba de receta comprueba el diccionario completo.

## 4. Archivos

Modificar `godot/addons/creador/taller_assets/asset_recipe.gd`, `godot/addons/creador/taller_assets/sword_generator.gd` y `pruebas/godot/probar_generador_espada.gd`. Registrar el resultado en `PLAN.md` y guardar las capturas en `pruebas/capturas/interfaz/ta3b/`.

## 5. Diseño propuesto

1. Admitir cuatro claves opcionales bajo `parametros` del modo espada: `escala_punta`, `escala_guarda`, `escala_mango` y `escala_pomo`. Son factores relativos a la geometría aprobada. Se propone el intervalo inclusivo 0,5–1,5 (50–150 %) para cada control. Una receta nueva con estas claves requiere el lector actualizado.
2. Conservar la firma de `AssetRecipe.normalize` y devolver las claves opcionales solo si se recibieron. Exigir números finitos dentro del intervalo y señalar la clave inválida. Conservar los datos tras guardar y leer JSON.
3. En `SwordGenerator.generate`, usar 1 para cada factor ausente. El ajuste de punta desplaza el anillo donde empieza el estrechamiento y conserva la longitud total. El de guarda escala su anchura en X. El de mango escala su sección en X y Z. El de pomo escala sus tres ejes alrededor de la unión con el mango. Mantener el origen en el centro del agarre. Restablecer los factores a 1 debe recuperar la malla de TA.3a.

## 6. Pruebas

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_generador_espada.gd)
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_receta_asset.gd)
```

Antes de editar, obtener con el generador de TA.3a los arrays de las dos recetas de su prueba para comparar el resultado final. Probar factores ausentes, neutros, ambos extremos y una combinación de los cuatro. Para cada ajuste individual medir el cambio solicitado en su superficie y comprobar que las otras tres conservan sus vértices. Medir la longitud de punta desde el último anillo hasta su extremo; la caja de la hoja por sí sola no detecta ese cambio. Verificar sólidos cerrados y materiales. Probar normalización tras JSON y rechazo de valores fuera de rango, texto, infinitos y claves de espada en otros modos.

Como control negativo, omitir el factor de punta y comprobar que falla la medida de esa sección. Restaurar, repetir la prueba y pasar la autoprueba y las regresiones sin ventana.

## 7. Trampas

Usar el extremo superior del pomo como centro de su escala evita que aparezca un hueco bajo el mango. Al comparar la compatibilidad, usar también la receta de dimensiones personalizadas de TA.3a para detectar valores absolutos introducidos por error.

## 8. Revisión visual

Capturar el modelo aprobado y dos variantes con la misma cámara y escala. El responsable podrá comparar las proporciones antes de incorporar los controles al visor.

## 9. Si aparece un bloqueo

Si una combinación permitida genera una superficie abierta o requiere cambiar el validador o el formato de otra clase de asset, presentar la receta y el diagnóstico antes de ampliar el paso.
