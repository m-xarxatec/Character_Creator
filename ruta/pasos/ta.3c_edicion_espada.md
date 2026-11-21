# TA.3c — Editar la espada en el visor del Taller

## 1. Objetivo y cierre

Al entrar en Taller → Espada, ver la malla aprobada, editar siete parámetros y tres colores, girar el modelo y restablecer la receta. Cerrar con las pruebas de ventana y el visto bueno visual del responsable.

## 2. Nivel

Medio. El generador y la cámara ya existen. La interfaz debe mantener sincronizados los controles, la receta en memoria y la malla visible.

## 3. Contexto

Consultar [la hoja de ruta, TA.3](<../../taller assets/pasos_a_seguir.md>) y [las proporciones aprobadas](ta.3b_proporciones_espada.md). En `workshop_page.gd`, la página crea una muestra y llama a `select_mode` al abrir. El generador acepta una receta v1 y devuelve `malla` o un mensaje en `error`.

## 4. Archivos

Modificar `godot/app/taller_assets/workshop_page.gd` y `pruebas/godot/probar_ventana.gd`. Crear `godot/app/taller_assets/sword_panel.gd` y su UID para los controles. Registrar los resultados en `PLAN.md` y guardar capturas en `pruebas/capturas/interfaz/ta3c/`.

Ampliación aprobada por el responsable: modificar también `godot/addons/creador/taller_assets/asset_recipe.gd` y `pruebas/godot/probar_receta_asset.gd` para los límites de la receta.

## 5. Diseño propuesto

1. Al elegir Espada, inicializar una receta local desde los valores de `AssetRecipe`, generar con `SwordGenerator.generate` y mostrar el resultado en el visor existente. Al volver de otro modo o de Cuerpo, recuperar la última edición de esta sesión.
2. En el panel derecho, ofrecer campos numéricos con unidades visibles. Para largo, ancho y grosor de la hoja se propone un intervalo de edición del 50 al 150 % de su valor inicial, mostrado en metros. Para punta, guarda, mango y pomo mostrar el porcentaje usando los límites existentes de TA.3b. Los límites de interfaz se aplican en los controles.
3. Añadir tres selectores RGB (hoja, guarda y mango). Cada cambio actualiza la receta y la malla. Restablecer recupera los siete valores y los tres colores de apertura, con una sola regeneración. Usar desplazamiento vertical en el panel si los controles exceden la altura disponible.
4. En Espada, habilitar Generar para volver a generar la receta actual. Guardar, Equipar y Exportar siguen pendientes de sus respectivos pasos. En los otros modos, recuperar la muestra y las acciones de TA.2b. Ajustar el encuadre al entrar y preservar el giro y el zoom elegidos durante la edición. Ante un error, mantener la última malla válida y mostrar el diagnóstico.
5. Ampliación aprobada: `AssetRecipe` rechaza en la espada un largo fuera de 0,5–1,5 m, un ancho fuera de 0,045–0,135 m y un grosor fuera de 0,009–0,027 m. Los controles leen esos mismos límites.
6. Ampliación aprobada: el visor muestra el recuento de triángulos y el tamaño real, y ofrece las vistas Frente, Perfil y ¾, que vuelven a encuadrar la pieza. Las acciones pasan a dos columnas para dejar más alto a los controles.

## 6. Pruebas

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_ventana.gd)
```

Entrar por la pestaña y verificar las cuatro superficies. Operar los controles reales y cotejar vértices y materiales con el generador para los valores elegidos. Probar ambos extremos de longitud, un cambio de cada proporción y de cada color, Generar, Restablecer y regreso desde otro modo y desde Cuerpo. Comprobar el giro y el zoom después de una edición y el aislamiento del historial del personaje. En una copia temporal desconectar un control del refresco del visor y comprobar que falla la comparación de la malla. Restaurar y repetir la prueba, la autoprueba y las regresiones sin ventana. En `probar_receta_asset.gd`, comprobar ambos extremos de cada medida, valores justo fuera y que `grosor_m` de la extrusión no hereda el límite.

## 7. Trampas

Asignar valores a los controles al abrir o restablecer puede disparar sus señales antes de completar la receta. Actualizar el formulario en bloque. Probar también que al volver a Desde imagen o Camiseta se recuperan su panel y su muestra.

## 8. Revisión visual

Capturar la espada desde frente, perfil y tres cuartos en el editor real. Incluir una edición visible y comprobar la accesibilidad de los controles en claro y oscuro a 1280 × 720 y 1920 × 1080.

## 9. Si aparece un bloqueo

Si la edición exige cambiar el contrato de receta, el generador o la cámara compartida, presentar el caso que lo requiere antes de ampliar el alcance.
