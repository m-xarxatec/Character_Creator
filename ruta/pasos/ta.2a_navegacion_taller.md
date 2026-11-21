# TA.2a — Entrar al Taller y volver al cuerpo

## 1. Objetivo y cierre

Abrir una séptima pestaña, «Taller de Assets», y volver a Cuerpo con la misma edición y el mismo historial. Este primer subpaso cubre la navegación. TA.2b incorporará el visor orbital, los tres modos y las acciones del Taller.

## 2. Nivel

Medio. La barra superior gobierna hoy el panel derecho. El Taller necesita alternar toda la zona de trabajo.

## 3. Contexto mínimo

Leer [TA.2 en la hoja de ruta](<../../taller assets/pasos_a_seguir.md>), la distribución de [GUIA_INTERFAZ.md](../../diseno/GUIA_INTERFAZ.md) y las funciones `_ready`, `_body`, `refresh_top_bar` y `_unhandled_key_input` de [main.gd](../../godot/app/main.gd). Consultar los atajos de [body_actions.gd](../../godot/app/body_actions.gd).

## 4. Archivos del subpaso

Modificar `godot/app/main.gd` y `pruebas/godot/probar_ventana.gd`. Registrar el resultado en `PLAN.md`. La barra ya acepta los títulos e iconos que le proporciona la ventana.

## 5. Diseño

1. Conservar las seis páginas de personaje con sus índices actuales. Añadir el acceso al Taller al final del menú superior usando un icono existente.
2. Conservar montado el contenedor que devuelve `_body()`. Crear una página hermana que herede el tema y muestre el título «Taller de Assets». Al entrar, ocultar el contenedor del personaje y mostrar la página del Taller. Al elegir una de las seis pestañas de personaje, invertir la visibilidad y seleccionar el panel derecho correspondiente.
3. En el Taller ocultar las acciones y medidas exclusivas del cuerpo y evitar que sus atajos modifiquen, guarden o exporten el personaje. Conservar el aviso de cambios pendientes al cerrar la aplicación. Al volver, recalcular la disponibilidad de las acciones a partir del estado real del editor.

## 6. Pruebas

Extender `probar_ventana.gd` para distinguir siete accesos superiores y seis paneles de personaje. Cambiar un deslizador, entrar al Taller, enviar los atajos de deshacer, guardar y exportar y comprobar que se conservan valor e historial y que ningún diálogo de archivo se abre. Volver a Cuerpo, comprobar el indicador de edición pendiente y deshacer el cambio. Repetir la navegación desde Estilo.

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_ventana.gd)
```

Como control negativo, quitar temporalmente la protección de Deshacer en el Taller. La prueba debe detectar que el valor cambió. Restaurar y ejecutar las regresiones sin ventana de la guía. Comprobar manualmente que al volver a Cuerpo se puede exportar.

## 7. Trampas conocidas

La actualización periódica de la barra puede reactivar botones. Comprobar también el comportamiento después de ese refresco. Mantener el mismo `BodyEditor` y comprobar su identidad en la prueba.

## 8. Revisión visual

Capturas de la navegación en claro y oscuro a 1280 × 720 y 1920 × 1080. El responsable revisa la legibilidad de las siete pestañas y la recuperación de la vista del cuerpo. Usar la carpeta de capturas de prueba del proyecto.

## 9. Si aparece un bloqueo

Si la séptima pestaña queda recortada a la resolución mínima, presentar la captura y una alternativa de acceso antes de modificar la barra. Pedir aprobación de TA.2b tras cerrar TA.2a.
