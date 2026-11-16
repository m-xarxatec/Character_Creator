# Fase 10 — Proyecto compartido y estudio de poses y fotos (ficha breve)

> Ficha **breve**. Antes de empezar cada paso, un modelo fuerte escribe su ficha detallada (`GUIA_MODELOS.md` §6).
> Depende de: MVP cerrado, A3 (`WorldPose`) y A4 (estado como diccionario). Decisiones: D17 (extensión `.gmolde`), D18 (versión más nueva).
> Diseño de referencia: `ARQUITECTURA.md` §1 (formato), §2.3 (pose), §7 (escena).

**Objetivo de la fase:** guardar y abrir proyectos, posar el personaje, elegir cámara y luz, y sacar imágenes para dibujar.

**Hecho cuando:** se abre un proyecto, se posa el personaje, se elige cámara y luz, y sale una hoja de giro en PNG transparente.

| Paso | Objetivo | Tam. | Riesgo | Nivel | Depende de |
| --- | --- | --- | --- | --- | --- |
| 10.1 | `ProjectFile` en el núcleo: leer, escribir y migrar `.gmolde`; prueba de ida y vuelta | M | Medio: un formato mal pensado se arrastra | fuerte para revisar; medio para escribir | 4.7, A4 |
| 10.2 | Guardar, abrir y galería local con miniaturas (`user://proyectos/`) | M | Bajo | medio | 10.1 |
| ★ 10.3 | Pestaña Estudio: girar huesos (FK) → pose en el proyecto → PNG con fondo transparente | L | Medio: selección de huesos y gizmo | medio | 10.1, A3, 5.2 |
| 10.4 | Biblioteca de poses propia (CC0), espejo de pose, partes bloqueadas | M | Bajo | medio | 10.3 |
| 10.5 | Cámara: paneo, zoom hacia el cursor, vistas rápidas, lente, modo ortográfico, cámaras guardadas | M | Bajo | simple–medio | 10.3 |
| 10.6 | Luces: preset de tres puntos, color, mover arrastrando. El toon pasa a usar `ATTENUATION` | M | Medio: **cambia el aspecto aprobado** | medio | 10.3 |
| 10.7 | Imagen en alta resolución y relación de aspecto libre | S | Bajo: memoria de vídeo a 8K | simple | 10.3 |
| 10.8 | Hoja de giro (4 u 8 vistas en una imagen) con líneas de proporción opcionales | S | Bajo | simple | 10.7 |
| 10.9 | Modos de render: solo contorno, silueta, valores (2 o 3 tonos), color plano | S–M | Bajo | medio | 10.7 |
| 10.10 | Posar arrastrando manos y pies (IK de dos huesos, propia) | L | **Alto**: matemática 3D | fuerte | 10.3 |
| 10.11 | Gestos de mano: puño, abierta, señalar, agarrar, pinza | S | Bajo | simple | 10.4 |
| 10.12 | Código de personaje: texto copiable `GM1-…` | S | Bajo | medio | 10.1 |

## Notas de diseño que no deben perderse

- **Regla del §0 de `ARQUITECTURA.md`:** en el estudio el personaje es **horneado**. Al entrar en la pestaña se hornea (sin textura, A5) y se posa esa copia. Al volver a Cuerpo se vuelve al vivo.
- **10.1, pruebas mínimas:** (1) `from_text(to_text(p)) == p`; (2) mismo proyecto → mismo texto byte a byte (claves ordenadas); (3) versión mayor → error (D18); (4) un proyecto v1 guardado en `pruebas/` como archivo fijo se sigue abriendo en todas las versiones futuras (prueba de regresión del formato: **ese archivo no se regenera nunca**); (5) una pieza desconocida se conserva al guardar.
- **Números en JSON:** Godot lee todos los números como `float`. Redondear al escribir (6 decimales) para que «mismo proyecto, mismo texto» se cumpla entre plataformas.
- **10.3, selección de hueso:** por distancia en pantalla al segmento del hueso (`Camera3D.unproject_position` de cabeza y cola), no por física. Vale igual con ratón y con dedo (`PLATAFORMAS.md` §5.3). El gizmo de giro son tres anillos dibujados con `ImmediateMesh` o mallas de toro; tamaño constante en pantalla.
- **Límites de giro por articulación:** reutilizar los rangos del paso 5.9. Con «límites» activado, el codo no dobla al revés. Opción para desactivarlos.
- **10.6, cambio visual:** hoy `toon.gdshader` no multiplica por `ATTENUATION` (`toon.gdshader:45`). Añadirlo hace que las luces omni pierdan fuerza con la distancia y que haya sombras proyectadas. Con la luz direccional sin sombras la imagen debe quedar **idéntica** a la aprobada: comprobarlo con la herramienta del 5.11 antes de enseñar nada nuevo.
- **10.7, imagen grande:** un `SubViewport` aparte con el tamaño pedido, `render_target_update_mode = UPDATE_ONCE`, esperar dos fotogramas, `get_texture().get_image().save_png()`. A 8K con MSAA la memoria de vídeo puede no bastar: límite por plataforma en `Platform.can("alta_resolucion")` (`ARQUITECTURA.md` §8). El contorno se define en píxeles (`width_px`): al doblar la resolución hay que doblarlo para que la imagen sea la misma.
- **10.9:** un `uniform int modo` en `toon.gdshader` (0 normal, 1 color plano, 2 valores en gris, 3 silueta, 4 solo contorno = blanco + contorno). Normales y profundidad se dejan para la Fase 14.
- **10.10, IK:** solución analítica de dos huesos (ley del coseno) para brazo y pierna, con un vector «polo» para el codo y la rodilla. Código propio de unas 80 líneas en el núcleo (`two_bone_ik.gd`), con prueba numérica: la mano llega al objetivo (< 1 mm) si está al alcance; si no, el brazo queda estirado apuntando a él. Los nodos de IK nuevos de Godot (4.5 o posterior): **NO VERIFICADO**; no depender de ellos.
- **10.12, código de personaje:** `GM1-` + base64 URL de: 1 byte de versión, 1 byte por deslizador **en el orden de sus ids ordenados alfabéticamente** (valor × 255), colores (3 bytes cada uno), acabado (1 byte por valor, normalizado a su rango), 2 bytes de suma de control (CRC16). Un deslizador nuevo cambia la longitud: por eso lleva versión propia y una tabla «versión → lista de ids» que **solo crece**.
- **Poses propias (10.4):** se crean con el propio estudio y se guardan como JSON de `WorldPose`. Son nuestras: CC0. No se copian poses de otras apps.

## Juicio visual

10.3, 10.6, 10.8, 10.9 y 10.10: capturas y preguntas al responsable. El 10.6 necesita aprobación explícita porque cambia el shader aprobado.

## Si te atascas

Si un cambio del formato rompe el archivo fijo de la prueba (4): **para**. Falta una migración; no se regenera el archivo.
