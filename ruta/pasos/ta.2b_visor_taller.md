# TA.2b — Visor y controles del Taller

## 1. Objetivo y cierre

Al entrar en el Taller se puede elegir entre Espada, Desde imagen y Camiseta, consultar el panel correspondiente y girar o acercar un objeto de muestra. El cierre requiere que pasen las pruebas y que el responsable apruebe las capturas.

## 2. Nivel

Medio. Hay que aislar la cámara y los eventos del ratón de la vista del personaje.

## 3. Contexto mínimo

Consultar [TA.2 en la hoja de ruta](<../../taller assets/pasos_a_seguir.md>) y la [guía de interfaz](../../diseno/GUIA_INTERFAZ.md). En `main.gd`, revisar la creación de `workshop_page` y la visibilidad en `_select_page`. La cámara de `orbit_camera.gd` ya interpreta el arrastre y la rueda y ofrece `frame(box, aspect)` para el encuadre.

## 4. Archivos

Crear `godot/app/taller_assets/workshop_page.gd` con su UID de Godot. Integrarlo en `godot/app/main.gd` y ampliar `pruebas/godot/probar_ventana.gd`. Registrar el resultado en `PLAN.md` y guardar las capturas en `pruebas/capturas/interfaz/ta2b/`. El generador de espada corresponde a TA.3.

## 5. Diseño

1. Sustituir la etiqueta central de TA.2a por una página persistente con tres columnas que hereden el tema. Mantener el cambio de página existente.
2. A la izquierda, elegir uno de los tres modos. La función `select_mode(index: int) -> void` sincroniza la selección y el panel derecho. Abrir en Espada y conservar la selección al volver desde Cuerpo.
3. En el centro, montar un SubViewport con mundo 3D propio, cámara orbital existente, luz y una caja rectangular de muestra. Encuadrar al mostrar o redimensionar la vista. La forma alargada permite apreciar el giro.
4. A la derecha, identificar las propiedades previstas del modo, como las dimensiones de la hoja, el espesor de extrusión o el largo de la camiseta. Mostrar Generar, Guardar, Equipar y Exportar desactivados, con una explicación de disponibilidad. Ropa y Accesorios son los destinos para equipar las piezas creadas.

## 6. Pruebas

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_ventana.gd)
```

Entrar por la pestaña real, elegir cada modo y comprobar el panel y las cuatro acciones. Enviar arrastre y rueda por el visor y comprobar que cambian el ángulo y la distancia de su cámara y que la cámara del cuerpo conserva ambos valores. Volver al personaje y repetir la entrada. Como fallo provocado, desconectar temporalmente la selección del panel y verificar que la prueba identifica el modo incorrecto. Restaurar, repetir la prueba, pasar la autoprueba y las regresiones sin ventana.

## 7. Trampas conocidas

Un SubViewport que comparta mundo con Cuerpo podría mostrar el maniquí en el Taller. Probar también el primer encuadre al entrar desde la página inicialmente oculta y comprobar que los paneles laterales dejan espacio para el visor.

## 8. Revisión visual

Capturar el Taller en claro y oscuro a 1280 × 720 y 1920 × 1080. El responsable comprueba que distingue el modo activo, puede girar el objeto y alcanza a leer las propiedades y acciones en la ventana más pequeña.

## 9. Si aparece un bloqueo

Si para aislar el visor hace falta modificar la cámara compartida o la vista del cuerpo, presentar el comportamiento observado y la ampliación de alcance antes de editar esos archivos.
