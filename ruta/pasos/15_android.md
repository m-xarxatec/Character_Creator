# Fase 15 — Android: estudio de poses (ficha breve)

> Ficha **breve**. Antes de empezar cada paso, un modelo fuerte escribe su ficha detallada (`GUIA_MODELOS.md` §6).
> Depende de: Fase 10 (el estudio existe en PC), A2 (datos en el `.pck`). Decisiones: D20 (deslizadores), D21 (herramientas), D22 (compartir).
> Estudio previo completo: `PLATAFORMAS.md` §4 y §5. Diseño: `ARQUITECTURA.md` §8.

**Objetivo de la fase:** el mismo proyecto de Godot, exportado a Android, como estudio de poses y referencias. Abre personajes, los posa, mueve cámara y luces, y saca imágenes. No exporta archivos para juegos.

**Hecho cuando:** en un móvil de gama media se abre un `.gmolde` hecho en el PC, se posa con el dedo, se guarda un PNG en el almacenamiento del usuario y el proyecto modificado vuelve a abrirse en el PC. Todo dentro del presupuesto de `RENDIMIENTO.md` §2.

| Paso | Objetivo | Tam. | Riesgo | Nivel | Depende de |
| --- | --- | --- | --- | --- | --- |
| 15.1 | Herramientas, firma de pruebas y APK de humo con medidas (si no se hizo el 8.5: es la misma ficha) | M | **Alto**: piezas externas | fuerte | A2, 7.1 |
| 15.2 | Funciones por plataforma: `godot/app/platform.gd` y su tabla | S | Bajo | medio | Fase 10 |
| ★ 15.3 | Abrir un `.gmolde`, posarlo con el dedo y guardar un PNG | L | Alto: disposición táctil nueva | fuerte al diseñar; medio al escribir | 15.1, 15.2 |
| 15.4 | Gestos: un dedo gira, dos dedos acercan y mueven, doble toque centra | M | Medio | medio | 15.3 |
| 15.5 | Guardar y abrir con el selector del sistema; carpeta en la nube | M | Alto: API **NO VERIFICADA** | fuerte | 15.3 |
| 15.6 | Memoria y rendimiento: cumplir el presupuesto en el aparato real | M–L | Alto | fuerte | 15.3 |
| 15.7 | Firma de publicación, nombre de paquete definitivo, icono y distribución | M | Medio: la clave no se puede perder | medio, con el responsable | 15.6 |

## Notas de diseño que no deben perderse

- **Un solo proyecto.** Nada de copiar `godot/` a otra carpeta. Las diferencias viven en `platform.gd` (qué funciones hay) y en una disposición de interfaz distinta para pantalla estrecha. El núcleo no sabe en qué plataforma está.
- **15.2, prueba:** `Platform.can()` con la plataforma simulada (parámetro opcional `platform := ""` para poder probar «android» en el PC): `exportar_glb` es `false` en Android; el botón «Exportar» **no existe** en el árbol de la interfaz (no basta con ocultarlo: `find_child` devuelve `null`).
- **Disposición táctil (15.3):** vista 3D a pantalla completa; barra inferior con 4 modos (Pose, Cámara, Luz, Imagen); paneles que suben desde abajo y ocupan como máximo el 40 % de la altura. Tiradores y botones de 48 px como mínimo (en píxeles independientes de la densidad: multiplicar por `DisplayServer.screen_get_scale()` o usar el modo de estirado del proyecto; decidir en la ficha detallada). Orientación: las dos; la vertical es la habitual al dibujar con el móvil apoyado.
- **Ajuste de ventana:** `display/window/stretch/mode = "canvas_items"` y `aspect = "expand"` para que la interfaz escale con la pantalla. Cambia también el aspecto en PC: comprobar que la interfaz de escritorio queda igual (prueba con la herramienta del 5.11).
- **Personaje vivo solo al editar** (`PLATAFORMAS.md` §5.2). En el estudio de Android se trabaja con el horneado. Al abrir un proyecto: cargar especie → aplicar valores → hornear → **liberar el vivo** (`free` de la malla con formas) → posar. Medir la memoria antes y después de liberar.
- **Pausa y vuelta (ciclo de vida):** Android puede matar la app en segundo plano. Guardar el proyecto en curso en `user://autoguardado.gmolde` al recibir `NOTIFICATION_APPLICATION_PAUSED` y ofrecer recuperarlo al abrir. También en PC al cerrar.
- **15.5:** primero `user://` + galería propia dentro de la app (seguro, sin permisos). Después «Guardar en…» con el diálogo nativo (`FileDialog.use_native_dialog` en Android usa el selector de documentos: **NO VERIFICADO** en 4.7; el selector devuelve una URI `content://` y no una ruta: comprobar que `FileAccess` la abre). Compartir directo: D22.
- **Imágenes:** `Image.save_png_to_buffer()` + escribir los bytes donde diga el selector. Tamaño máximo 4096 px (`Platform`).
- **Batería y calor:** en el estudio, si nada cambia, no hay que redibujar a 60 fps. `OS.low_processor_usage_mode = true` hace que Godot solo redibuje cuando algo cambia (pensado para aplicaciones). Con física de pelo activa hay que redibujar siempre: desactivar el modo solo entonces.
- **15.7:** el almacén de claves de publicación lo crea y lo guarda **el responsable**, fuera del repositorio, con copia de seguridad. Si se pierde, no se puede actualizar la app publicada. Fuera de Google Play (APK directo en GitHub) basta con firmar el APK. Requisitos de Play (AAB, nivel de API objetivo, ficha de privacidad): **NO VERIFICADO**; cambian cada año.
- **Privacidad:** la app no pide permisos ni usa red. Decirlo en la ficha de la tienda y mantenerlo: cualquier función que pida red es una decisión del responsable.

## Juicio visual

15.3 y 15.4 se juzgan con el aparato en la mano: ¿se puede posar con el pulgar sin tapar lo que se mueve? El responsable prueba y decide.

## Si te atascas

- Sin aparato real no se cierra ningún paso de esta fase. El emulador no vale para medir.
- Si la medida de D20 falla: no optimices el núcleo por tu cuenta. `Platform.can("editar_cuerpo")` pasa a `false` en Android y se informa.
