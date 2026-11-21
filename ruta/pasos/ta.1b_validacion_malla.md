# TA.1b — Validar la geometría de un asset

## 1. Objetivo y cierre

Detectar geometría inválida antes de entregarla a Godot y devolver medidas que luego pueda enseñar el visor. Se cierra cuando pasan los casos del apartado 6, una rotura deliberada hace fallar la prueba y se completan las regresiones sin ventana.

## 2. Nivel

Medio para implementar el contrato. El punto delicado es comprobar el cierre de una pieza cuyas caras duplican vértices para usar normales planas o distintos materiales.

## 3. Contexto mínimo

- [Hoja de ruta, TA.1](<../../taller assets/pasos_a_seguir.md>) y [contrato de generación, §4](<../../taller assets/plan.md>).
- [MeshChecks](../../godot/addons/creador/mesh_checks.gd), especialmente `_degenerate`, compara reposo y pose. Un triángulo que ya nace sin área queda fuera de ese cálculo. [CharacterChecks](../../godot/addons/creador/character_checks.gd) requiere una malla con piel y un esqueleto.
- [Prueba de cuernos del borrador](../codigo/pruebas/probar_cuernos.gd) como referencia de orden de caras y contabilidad de aristas. [Prueba de recetas](../../pruebas/godot/probar_receta_asset.gd) como ejemplo de ejecución aislada.

## 4. Archivos propuestos

| Archivo | Responsabilidad |
| --- | --- |
| `godot/addons/creador/taller_assets/asset_validator.gd` | Validación en memoria y medidas. |
| `pruebas/godot/probar_malla_asset.gd` | Casos válidos, entradas defectuosas y comprobación del resultado. |
| `pruebas/godot/taller_fixtures.gd` | Polígonos e imágenes sintéticos reutilizables en TA.4. |

Añadir los `.gd.uid` que genere Godot y registrar el cierre en `PLAN.md`. El código del cuerpo, el rig y la exportación quedan fuera de esta ficha.

## 5. Diseño

1. Exponer `static func validate(surfaces: Array, closed: bool) -> Dictionary`. Una llamada recibe las superficies triangulares de una pieza. Cada superficie usa los slots nativos de `Mesh.ARRAY_MAX`. Así el generador puede validar sus arrays antes de llamar a `ArrayMesh.add_surface_from_arrays`. En caso de éxito devolver `{"error": "", "triangulos": int, "dimensiones_m": Vector3}`. Ante el primer defecto devolver solo `{"error": String}`, con la superficie y el triángulo o campo afectado cuando corresponda.
2. Exigir al menos una superficie, posiciones finitas y una normal finita y no nula por vértice. Admitir triángulos indexados y, con el slot de índices vacío, ternas consecutivas. Comprobar tipos, tamaños, divisibilidad por tres e índices antes de acceder al vértice. Rechazar triángulos sin área y normales que apunten al lado contrario de la cara. Usar la convención horaria de Godot y probarla con una cara frontal conocida.
3. Calcular la caja envolvente de los vértices usados y el número total de triángulos en todas las superficies. Aceptar una dimensión cero en una superficie plana abierta. Las medidas deben ser finitas. Los rangos de longitud y grosor propios de cada receta se contrastarán con estas medidas en TA.3 y TA.4.
4. Cuando `closed` sea verdadero, comprobar el cierre del sólido completo. Identificar cada extremo por su posición exacta dentro de la pieza, también entre superficies. Cada arista debe aparecer dos veces en sentidos contrarios. Para un sólido simple del MVP, comprobar además el signo del volumen orientado con un tetraedro de orientación conocida. Esto distingue un tetraedro correcto de otro con **todas** las caras y normales invertidas. Una prenda puede tener aberturas en cuello y mangas. Los pesos se comprobarán en TA.7.

## 6. Prueba y criterios

| Caso sintético | Resultado esperado |
| --- | --- |
| Triángulo frontal en el plano XY con lados perpendiculares de 1 m, con y sin índices | 1 triángulo y dimensiones (1, 1, 0) en ambos casos. |
| Tetraedro formado por el origen y los tres puntos unidad de los ejes, dividido en dos superficies con vértices duplicados en la costura | Sólido válido, 4 triángulos y dimensiones (1, 1, 1). |
| Quitar una cara, invertir una cara, o repetir una cara del tetraedro | Detectar borde abierto, orientación incoherente o arista con más de dos caras. El caso abierto con las caras restantes bien orientadas se acepta al pedir superficie abierta. |
| Invertir todas las caras y las normales de un tetraedro | Rechazar el sólido vuelto del revés. |
| Superficies vacías, índice negativo o fuera de rango, terna incompleta, tres puntos colineales, coordenada no finita, normal ausente, nula o invertida | Error identificable, salida controlada y datos de entrada intactos. Incluir un defecto en la segunda superficie. |
| Polígonos 2D propios y máscaras de referencia | Cuadrado convexo y L cóncava sin huecos. Crear imágenes de 8 × 8 en memoria con rectángulo opaco sobre transparencia, lienzo transparente vacío, objeto que toca el borde y objeto sobre fondo uniforme. Fijar coordenadas y colores esperados para comprobar los datos ahora y probar la segmentación en TA.4. |

Desde la raíz del repositorio:

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_malla_asset.gd)
```

Para demostrar que detecta el fallo, omitir temporalmente la comprobación de aristas con una sola cara. El tetraedro al que se ha quitado la cara situada en el plano XY conserva volumen orientado y debe producir `FALLO rechaza sólido abierto`, con salida 1. Restaurar el control y exigir `RESULTADO: TODO BIEN`, salida 0. Ejecutar la prueba de recetas y las regresiones de [GUIA_MODELOS.md, §5](../GUIA_MODELOS.md).

## 7. Trampas conocidas

Contar aristas por índice local confunde una costura de material con un agujero. La comprobación topológica debe agrupar posiciones coincidentes sin modificar los vértices ni sus normales. Mantener los límites de deformación del personaje en su prueba original. Cualquier tolerancia numérica nueva debe quedar identificada como provisional y justificarse con la medida correspondiente.

## 8. Revisión

La evidencia son los diagnósticos, las medidas de los ejemplos conocidos y los códigos de salida. Esta ficha solo produce datos y pruebas sin ventana.

## 9. Si aparece un bloqueo

Si un ejemplo válido requiere soldar posiciones por proximidad o interpretar un volumen con cavidades, presentar el ejemplo y el efecto sobre los tres modos antes de ampliar el algoritmo. La conversión de imágenes a contornos y el montaje de la camiseta tienen sus propios pasos.
