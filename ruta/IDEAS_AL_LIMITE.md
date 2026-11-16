# IDEAS AL LÍMITE — el catálogo evaluado

> Sesión de traspaso (2026-11-16). Evaluación de cada idea del anexo y de las propias (marcadas **★ propia**).
> Nada de esto entra en `PLAN.md` sin aprobación. Las fases son las de `HOJA_DE_RUTA.md` §3.
> **Valor:** 1 (curiosidad) a 5 (cambia el producto). **Coste:** S (un paso de un día), M (varios pasos), L (una fase pequeña), XL (una fase grande).
> **NV** = depende de una API de Godot 4.7 **NO VERIFICADA**; la nota de la fila dice cuál.
> Plataforma: PC, And (Android) o Ambas. Nivel: simple, medio o fuerte.

---

## A. Cuerpo y modificaciones extremas

| Idea | Valor | Coste | Riesgo técnico | Licencia / assets | Plat. | Depende de | Nivel | Fase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Huesos deformables: largo y grosor por separado | 5 | M | Medio: diseño sin probar (`ARQUITECTURA.md` §2.2) | Ninguno | Ambas | MVP | fuerte | 16.1 |
| Piernas de animal (talón elevado) | 3 | L | Alto: las animaciones humanoides se ven raras | Propios | Ambas | 16.1, 16.3 | fuerte | 16.6 |
| Asimetría deliberada | 4 | S | Bajo: las claves `_l` y `_r` ya existen | Ninguno | Ambas | 4.4 (simetría desactivable) | simple | MVP + 16.1 |
| Joroba y cojera de pose | 2 | S | Bajo: es una pose, no un cuerpo | Poses propias | Ambas | 10.4 | simple | 10.4 |
| Huesos y extremidades extra con física | 4 | L | Medio: retargeting con huesos sin mapear (NV) | Propios / generadores | Ambas (física a medir en And) | 11.3, 13.1 | fuerte | 13.6 |
| Tentáculos | 2 | M | Medio: cadenas largas de muelle | Generador propio | PC | 13.6 | medio | 13.6 |
| Cuatro brazos | 2 | L | Alto: nadie los anima; hay que copiar giros | Propios | PC | 13.6 | fuerte | Tras 13.6 |
| Deslizador «Exageración» global | 4 | S–M | Medio: formas extrapoladas se rompen | Ninguno | Ambas | 16.1, medidas del 5.10 | medio | 16.2 |
| Mezclador de dos presets con porcentaje | 4 | S | Bajo: interpolar dos diccionarios | Ninguno | Ambas | 4.7 | simple | Comodín |
| Aleatorio con semilla y candados | 5 | S | Bajo: `probar_aleatorios.gd` ya lo hace sin interfaz | Ninguno | Ambas | 4.4 | simple | Comodín |
| Escultura libre | 4 | XL | Muy alto | Ninguno | PC | 16.4 o capa de CPU | fuerte | 16.5 |
| Calcomanías de piel (escamas, rayas, tatuajes, cicatrices) | 4 | L | Medio: costuras UV; sin `Decal` | Procedurales o propias, CC0 | Ambas | 14.1 | fuerte | 14.4 |
| Venas y musculatura marcada | 2 | M | Medio; ojo con la regla «sin anatomía marcada» de la guía de estilo | Propias | Ambas | 14.4 | medio | 14.4 |
| Materiales especiales (piedra, metal, cristal, fantasma) | 3 | M | Medio: transparencia + contorno | Ninguno (shader) | Ambas | 14.1 | medio | 14.5 |
| Runas o venas que brillan (emisivo) | 3 | S | Bajo, una vez hechas las calcomanías | Propias | Ambas | 14.4 | simple | 14.5 |
| Mutaciones: púas, placas, cuernos que crecen | 4 | M | Bajo: generador + deslizador de largo | Generador propio | Ambas | 13.5 | medio | 13.5 |
| Ojos extra | 2 | M | Medio | Los ojos del 9.4 como pieza | Ambas | 9.4, 13.1 | medio | Tras 13.1 |
| ★ propia: Medidas en cm (altura, envergadura, cabezas de alto) en vivo | 4 | S | Bajo: leer posiciones de huesos | Ninguno | Ambas | MVP | simple | Comodín |
| ★ propia: Código de personaje (texto copiable `GM1-…`) | 5 | S | Bajo | Ninguno | Ambas | 4.7 | medio | 10.12 |

## B. Especies y bases

| Idea | Valor | Coste | Riesgo técnico | Licencia / assets | Plat. | Depende de | Nivel | Fase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Elfo, orco, enano, gigante (misma malla: presets + piezas + rangos) | 5 | M | Bajo | Presets propios; orejas y colmillos propios | Ambas | 16.1, 16.2, 13.1 | medio | 16.2 |
| Demonio (cuernos, cola, alas) | 4 | M | Medio | Generadores | Ambas | 13.5, 13.6 | medio | 13.6 |
| Bestias antropomorfas (felino, lobo, reptil) | 4 | XL | Alto: cabeza y pelaje son assets nuevos | Propios (no hay CC0 que encaje con seguridad) | Ambas | 16.3 | fuerte | Tras 16.3 |
| Insectoide | 2 | XL | Alto | Propios | PC | 16.3, 13.6 | fuerte | Sin fecha |
| Esqueleto o no muerto | 3 | L | Medio: es otra malla con los mismos huesos | Propios o CC0 por buscar | Ambas | 16.3 | fuerte | Tras 16.3 |
| Gólem, robot, androide (piezas rígidas por hueso) | 4 | L | Medio: una pieza rígida por hueso, sin pesos | Generadores o propios | Ambas | 13.1 | medio | Tras 13.5 |
| Slime | 1 | XL | Muy alto: sin esqueleto humanoide | — | — | — | — | No hacer |
| Bases de estilo (realista, semirrealista, anime, chibi, heroico, esbelto) | 4 | M cada una | Medio: muchas son presets + estilo, no mallas | Presets propios | Ambas | 14.1, 16.2 | medio | 14.7 / 16.3 |
| Cuerpos prefabricados (atlético, culturista, delgado, robusto, mayor, bajo) con miniatura | 5 | S | Bajo: son presets | Presets propios | Ambas | 4.7, 10.2 (miniaturas) | simple | Comodín |
| Galería de personajes de ejemplo | 4 | S–M | Bajo | Proyectos propios | Ambas | 10.2 | simple | 14.7 |

## C. Piezas y assets

| Idea | Valor | Coste | Riesgo técnico | Licencia / assets | Plat. | Depende de | Nivel | Fase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cuernos, colas, alas, orejas, garras, colmillos, halos | 4 | M | Bajo | Generadores o propios | Ambas | 13.1 | medio | 13.5 |
| Generadores procedurales con deslizadores | 5 | M el primero; S los siguientes | Medio | **Ninguno**: licencia limpia por construcción | Ambas | 13.1 | fuerte el primero | 13.5 |
| Armas con la mano que agarra sola | 4 | M | Bajo | Propias o CC0 (Quaternius; por comprobar) | Ambas | 10.11, 13.1 | medio | 13.7 |
| Armaduras por piezas | 3 | L | Medio: atraviesan el cuerpo en extremos | Propias | Ambas | 12.1 (si siguen al cuerpo) | medio | Tras 12 |
| Capas con física | 3 | M | Medio | Propias | Ambas (And a medir) | 11.3, 12.6 | medio | 12.6 |
| Luces como pieza (linterna, antorcha, orbe) | 3 | S | Bajo en el estudio; exportación NV (`KHR_lights_punctual`) | Propias | Ambas | 10.6, 13.1 | medio | Tras 13.1 |
| Efectos: auras, fuego, humo, chispas, rastro | 2 | M | Medio: partículas en Compatibility NV; no viajan en el `.glb` | Texturas procedurales | PC primero | 13.1 | medio | Sin fecha |
| Importar piezas propias (`.glb`) con asistente | 5 | M | Medio: archivos de cualquier origen | Del usuario (elige licencia) | PC | 13.1 | medio | 13.3 |
| Pesos copiados del cuerpo para una pieza importada | 3 | M | Alto | — | PC | 12.1 (misma transferencia) | fuerte | Tras 12.1 |
| Acople magnético | 4 | M | Medio | Ninguno | Ambas | 13.1 | medio | 13.2 |
| Biblioteca de packs con miniaturas, filtros y licencia visible | 4 | M | Bajo | — | Ambas | 11.1 | simple–medio | 13.4 |

## D. Cámara y navegación

| Idea | Valor | Coste | Riesgo técnico | Licencia / assets | Plat. | Depende de | Nivel | Fase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Zoom hacia el cursor | 4 | S | Bajo | — | Ambas | — | simple | 10.5 (adelantable) |
| Paneo (botón central, Mayús + arrastrar, dos dedos) | 5 | S | Bajo | — | Ambas | — | simple | 10.5 (adelantable) |
| Doble clic para centrar y girar alrededor de ese punto | 4 | S | Bajo, con el rayo del 13.2 | — | Ambas | Rayo en CPU | medio | 10.5 |
| Lupa flotante | 2 | M | Bajo: segundo `SubViewport` | — | PC | — | medio | Sin fecha |
| Navegador (miniatura con rectángulo) | 1 | M | Bajo | — | PC | — | medio | No hacer |
| Vistas rápidas (frente, perfil, espalda, 3/4, picado, contrapicado) | 5 | S | Bajo: son 6 juegos de números | — | Ambas | — | simple | 10.5 (adelantable) |
| Lente ajustable y modo ortográfico | 5 | S | Bajo; el contorno en ortográfico hay que comprobarlo (usa `VIEWPORT_SIZE`) | — | Ambas | — | simple | 10.5 |
| Cámaras guardadas | 4 | S | Bajo | — | Ambas | 10.1 | simple | 10.5 |
| Vista dividida (2 o 4) | 2 | M | Medio: multiplica el coste de dibujo | — | PC | — | medio | No hacer (la hoja de giro lo cubre) |
| ★ propia: Espejo de la vista (voltear la imagen para detectar errores, hábito de dibujante) | 4 | S | Bajo: escala −1 en X del `TextureRect` | — | Ambas | — | simple | Comodín |

## E. Luces y escena

| Idea | Valor | Coste | Riesgo técnico | Licencia / assets | Plat. | Depende de | Nivel | Fase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Varias luces de colores que se arrastran en la vista | 5 | M | Medio: el toon debe usar `ATTENUATION`; límite de luces en Mobile NV | — | Ambas | 10.3 | medio | 10.6 |
| Animación de luces (órbita, parpadeo, pulso, ciclo de color) | 3 | S | Bajo: función pura `StudioScene.animate` | — | Ambas | 10.6 | simple | Tras 10.6 |
| Presets de iluminación (tres puntos, contraluz, atardecer, luna, vela, neón, terror) | 5 | S | Bajo: son datos | Propios | Ambas | 10.6 | simple | 10.6 |
| Fondos: color y degradado | 4 | S | Bajo | — | Ambas | 10.3 | simple | 10.3 |
| Fondos: cielos HDRI CC0 | 2 | M | Medio: pesan (decenas de MB) y cuestan en móvil | Poly Haven, CC0 (por comprobar al descargar) | PC | 10.6 | medio | Sin fecha |
| Suelo con sombra | 4 | S | Bajo: plano que solo recibe sombra | — | Ambas | 10.6 | simple | 10.6 |
| Suelo con reflejo | 1 | M | Medio: reflejos en Mobile y Compatibility NV | — | PC | — | medio | No hacer |
| Efectos de foto: niebla, resplandor, profundidad de campo, viñeteado | 3 | S–M | Medio: profundidad de campo en Compatibility NV; viñeteado es un shader propio de pantalla | — | PC; And a medir | 10.7 | medio | Tras 10.9 |
| Ciclo de día y noche | 1 | M | Bajo | — | PC | 10.6 | medio | No hacer (lo cubren los presets) |
| Varios personajes en la escena | 4 | M | Medio: memoria; todos horneados | — | PC 4, And 2 | 10.2 | medio | Tras 10.4 |
| Objetos de apoyo (cubo, silla, escalera, pared) | 4 | S | Bajo: primitivas de Godot | Ninguno | Ambas | 10.3 | simple | Tras 10.4 |
| ★ propia: Sombreado facetado (planos de luz, como un maniquí de dibujo tallado) | 4 | S | Bajo: normal por cara con `dFdx`/`dFdy` en el shader (derivadas en Compatibility: NV) | — | Ambas | 10.9 | medio | 10.9 |

## F. Poses y animación

| Idea | Valor | Coste | Riesgo técnico | Licencia / assets | Plat. | Depende de | Nivel | Fase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Posar arrastrando manos y pies (IK) | 5 | L | Alto: IK propia; nodos de IK de Godot NV | — | Ambas | 10.3 | fuerte | 10.10 |
| Biblioteca de poses propia (CC0) | 5 | M | Bajo; el trabajo es crear las poses | Propias, hechas con el estudio | Ambas | 10.3 | simple | 10.4 |
| Pose en espejo | 4 | S | Bajo: intercambiar `Left`/`Right` y reflejar el cuaternión | — | Ambas | A3 | medio | 10.4 |
| Mezcla de poses | 3 | S | Bajo: `slerp` por hueso | — | Ambas | A3 | simple | 10.4 |
| Partes bloqueadas | 4 | S | Bajo | — | Ambas | 10.4 | simple | 10.4 |
| Gestos de mano | 5 | S | Bajo: 5 poses parciales | Propias | Ambas | 10.4 | simple | 10.11 |
| Expresiones de la cara con la pose | 4 | S (con la Fase 9 hecha) | Bajo | — | Ambas | 9.7 | simple | Tras 9.7 |
| Pose desde una foto (IA local) | 3 | XL | Muy alto: modelo, licencia de pesos, dependencia | Pesos de terceros | — | — | — | No hacer |
| Línea de tiempo con fotogramas clave | 2 | XL | Alto | — | PC | — | fuerte | No hacer |
| Grabar el giro en GIF o vídeo | 3 | M | Medio: Godot graba vídeo con `--write-movie` (solo al lanzar); GIF pide codificador propio | — | PC | 10.8 | medio | Sin fecha; alternativa S: secuencia de PNG |
| Física de pelo, ropa y piezas visible al posar | 4 | S (con 11.3 hecho) | Bajo | — | Ambas | 11.3 | simple | 11.3 |
| ★ propia: Temporizador de poses para dibujo de gesto (30 s, 1, 2, 5 min; pasa sola a la pose siguiente) | 5 | S | Bajo: un `Timer` y la biblioteca de poses | Poses propias | Ambas (ideal en And) | 10.4 | simple | Comodín tras 10.4 |
| ★ propia: Maniquí de volúmenes simples (cajas y cilindros por hueso) | 4 | S–M | Bajo: una primitiva por hueso con el tamaño del hueso | Ninguno | Ambas | 10.3 | medio | Tras 10.9 |
| ★ propia: Límites de articulación al posar (reutiliza los rangos del 5.9) | 4 | S | Bajo | — | Ambas | 5.9, 10.3 | medio | 10.3 |

## G. Salidas para dibujantes y cómic

| Idea | Valor | Coste | Riesgo técnico | Licencia / assets | Plat. | Depende de | Nivel | Fase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Hoja de giro automática con líneas de proporción | 5 | S | Bajo | — | Ambas | 10.7 | simple | 10.8 |
| Modos de render: contorno, silueta, valores, color plano | 5 | S–M | Bajo | — | Ambas | 10.7 | medio | 10.9 |
| Modos de render: normales y profundidad | 2 | S | Bajo | — | PC | 10.9 | simple | Fase 14 |
| Exportar por capas en PNG sueltos | 4 | S | Bajo: una captura por modo, misma cámara | — | Ambas | 10.9 | simple | Tras 10.9 |
| Exportar por capas en OpenRaster (`.ora`) | 4 | S–M | Bajo: es un ZIP con PNG y un XML; `ZIPPacker` existe en Godot 4 | Formato abierto | PC | Capas en PNG | medio | Tras 10.9 |
| Rejilla de perspectiva superpuesta | 3 | S–M | Bajo: líneas 2D calculadas de la cámara | — | Ambas | 10.5 | medio | Tras 10.5 |
| Imagen de referencia de fondo | 4 | S | Bajo: `TextureRect` detrás, con opacidad | Del usuario | Ambas (en And pide selector de archivos) | 10.3 | simple | Tras 10.3 |
| Modo viñeta (formatos de cómic y webtoon) | 3 | S | Bajo: son tamaños predefinidos | — | Ambas | 10.7 | simple | 10.7 |
| Alta resolución, transparencia, aspecto libre | 5 | S | Bajo: memoria a 8K | — | PC 8K, And 4K | 10.3 | simple | 10.7 |
| ★ propia: Hoja de modelo con expresiones (giro + rejilla de caras) | 4 | S | Bajo | — | Ambas | 9.7, 10.8 | simple | Tras 9.7 |

## H. Exportación y juego

| Idea | Valor | Coste | Riesgo técnico | Licencia / assets | Plat. | Depende de | Nivel | Fase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Perfil de exportación para Blender (comprobado con la prueba que ya existe) | 3 | S | Bajo | — | PC | MVP | simple | Tras MVP |
| Perfiles para Unity y Unreal | 2 | M | Alto: no se pueden probar aquí | — | PC | Esos motores | — | No hacer sin poder probar |
| LOD automático y reducción de polígonos | 4 | M | Medio: `ImporterMesh.generate_lods` existe; uso en ejecución fuera del editor NV. Conservar pesos y color `garment` | — | PC | MVP | fuerte | Tras MVP (`RENDIMIENTO.md` O8) |
| Atlas de texturas | 2 | M | Medio | — | PC | Fase 12 | medio | Tras 12 |
| Exportar en lote (N personajes aleatorios en unos rangos) | 4 | S | Bajo: aleatorio + `GlbExporter.save` en bucle | — | PC | Aleatorio con semilla | simple | Comodín |
| Generador de multitudes en tiempo de juego | 4 | M | Medio: coste de construir un personaje (46–204 ms de horneado) | — | Juego | Núcleo como addon | medio | Tras MVP |
| Plugin dentro del editor de Godot | 3 | M | Medio: `EditorPlugin` y panel acoplado | — | PC | A2 | medio | Tras MVP |
| VRM 1.0 | 4 | L | Alto | Especificación abierta; sin nada de VRoid | PC | Fases 9 y 11 | fuerte | 17 |
| ★ propia: Semáforo de presupuesto en vivo (triángulos, huesos, materiales, MB frente a `GUIA_ESTILO.md` §7) | 4 | S | Bajo: contar y comparar | — | PC | 5.14 | simple | Tras 5.14 |
| ★ propia: Proyecto de ejemplo de Godot junto al `.glb` (escena lista con el material y una animación) | 4 | S | Bajo: `pruebas/godot_vacio/` es la base | Animación de Quaternius, CC0 | PC | MVP | simple | Tras 7.2 |

## I. Interfaz y producto

| Idea | Valor | Coste | Riesgo técnico | Licencia / assets | Plat. | Depende de | Nivel | Fase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Historial de Deshacer visual | 3 | M | Bajo | — | PC | 4.4, miniaturas | medio | 14.8 |
| Comparar antes y después con cortina | 3 | M | Medio: dos personajes vivos doblan la memoria; usar una imagen del «antes» | — | PC | 4.4 | medio | Tras 14.8 |
| Deslizadores favoritos | 2 | S | Bajo | — | Ambas | 4.3 | simple | Sin fecha |
| Buscador de deslizadores | 4 | S | Bajo: filtrar filas por texto | — | Ambas | 4.3 | simple | Comodín (necesario cuando la cara añada decenas) |
| Galería local con miniaturas | 5 | M | Bajo | — | Ambas | 10.1 | medio | 10.2 |
| Pantalla de inicio con estilos | 4 | M | Bajo | — | Ambas | 14.1, 10.2 | simple–medio | 14.7 |
| Tutorial interactivo | 3 | M | Bajo; se queda viejo con cada cambio de interfaz | — | Ambas | Interfaz estable | medio | Al final |
| Modo presentación (gira solo) | 3 | S | Bajo | — | Ambas | — | simple | Comodín |
| Temas de la interfaz | 3 | M | Bajo | Fuentes OFL (D30) | Ambas | — | medio | 14.6 |
| Traducciones | 3 | M | Bajo: `tr()` y un CSV de traducciones (aquí sí como traducción de Godot) | Propias | Ambas | Interfaz estable | simple | Al final |
| Tamaño de letra | 4 | S | Bajo: escala del tema | — | Ambas | 14.6 | simple | 14.6 |
| ★ propia: Autoguardado y recuperación tras cierre | 5 | S | Bajo | — | Ambas | 10.1 | simple | 10.2 |

## J. IA opcional y local

| Idea | Valor | Coste | Riesgo técnico | Licencia / assets | Plat. | Depende de | Nivel | Fase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Texto a personaje con un modelo local | 3 | XL | Muy alto: dependencia, cientos de MB, licencias de pesos | Pesos de terceros | PC | — | — | No hacer |
| ★ propia: Texto a personaje **sin IA**: palabras clave → presets y piezas («alto», «musculoso», «orco», «cuernos») | 3 | S–M | Bajo: tabla de palabras; 0 dependencias | Tabla propia | Ambas | Presets, 13.5 | simple | Tras 13.5 |
| Foto o dibujo a proporciones | 2 | XL | Muy alto | Pesos de terceros | — | — | — | No hacer |
| ★ propia: Ajuste **manual** a una referencia: imagen de fondo + medidas en cm + cabezas de alto | 4 | S | Bajo: suma de tres ideas baratas | Del usuario | Ambas | Imagen de fondo, medidas | simple | Tras 10.3 |
| Rig automático de piezas sin huesos | 2 | XL | Muy alto (ya en `IDEAS.md`, con su condición) | Pesos de terceros | PC | GPU > 8 GB | — | No cambia |

---

## Top 10 por relación valor/coste

1. **Aleatorio con semilla y candados** (5 / S). La lógica ya existe en `probar_aleatorios.gd`; falta un botón y los candados por zona. Es lo que más «juego» da con menos trabajo.
2. **Vistas rápidas, paneo y zoom hacia el cursor** (5 / S). Tres cambios pequeños en `orbit_camera.gd` que hacen que el editor se sienta profesional. Se pueden adelantar al MVP si se aprueba.
3. **Código de personaje** (5 / S). Compartir un personaje pegando un texto de 150 caracteres; resuelve PC ⇄ Android sin archivos, sin nube y sin permisos.
4. **Hoja de giro con líneas de proporción + modos de render** (5 / S–M). Es el uso «referencias de dibujo» completo con un `SubViewport` y un `uniform`.
5. **Cuerpos prefabricados con miniatura** (5 / S). Son presets: cero código nuevo en el núcleo. El usuario nuevo empieza de algo que ya se ve bien.
6. **Temporizador de poses para dibujo de gesto** (5 / S). Convierte la app de Android en una herramienta de práctica diaria. Con poses propias y aleatorio de cuerpo, las combinaciones no se acaban.
7. **Lente ajustable y modo ortográfico** (5 / S). Imprescindible para referencias: el teleobjetivo quita la deformación y el ortográfico da hojas de modelo limpias.
8. **Presets de iluminación** (5 / S). Son datos sobre el sistema de luces: mucho efecto visible por línea de código.
9. **Generadores procedurales** (5 / M). Cuernos, colas y púas sin un solo asset externo: licencia limpia por construcción y variedad infinita. Es lo que más diferencia al editor.
10. **Elfo, orco, enano y gigante como presets + piezas** (5 / M). Especies «gratis» una vez hechos largo y grosor de hueso y el primer generador.

Mención: **gestos de mano** (5 / S), **autoguardado** (5 / S), **espejo de la vista** (4 / S) y **medidas en cm** (4 / S).

## Lo que hace único al editor

No hay, que yo conozca, un editor libre que junte estas cuatro cosas: (1) personaje para juegos con huesos humanoides estándar; (2) estudio de poses para dibujantes con salidas por capas; (3) el mismo personaje en el móvil con un código de texto; (4) piezas procedurales sin assets. La apuesta es esa combinación, no competir en cantidad de ropa o de peinados con programas que tienen equipos de artistas.

## Las que descartaría

| Idea | Motivo |
| --- | --- |
| Pincel de mechones | Coste XL para lo que las piezas con física cubren en su mayor parte. |
| Pose desde foto, texto a personaje y foto a proporciones con IA | Dependencias nuevas, modelos de cientos de MB y licencias de pesos sin aclarar. Las variantes sin IA (tabla de palabras, ajuste manual) dan buena parte del valor con coste S. |
| Línea de tiempo con fotogramas clave | Es otro programa. Blender y Godot ya animan. |
| Perfiles para Unity y Unreal | No se pueden probar aquí; publicar sin probar es inventar. |
| Slime y especies sin esqueleto humanoide | Rompen la pose T, el retargeting y todas las pruebas. |
| Vista dividida y navegador en miniatura | Coste de dibujo multiplicado; las vistas rápidas y la hoja de giro cubren el uso. |
| Suelo con reflejo y ciclo de día y noche | Adorno caro en móvil; los presets de luz cubren el uso. |
| Tela simulada de verdad | Godot no tiene tela fiable para mallas con esqueleto (`SoftBody3D` con piel: NV). Los huesos de muelle bastan. |
| Venas y musculatura muy marcadas, como opción por defecto | Choca con la guía de estilo (§8: anatomía demasiado marcada). Solo como calcomanía opcional y nunca bajo la prenda base. |
| Lector de QR dentro de la app | Pide cámara y decodificador. El móvil ya lee QR con su cámara. |

## Resumen de «NO VERIFICADO» de este catálogo

| Tema | Qué hay que comprobar | Dónde afecta |
| --- | --- | --- |
| Nodos de IK de Godot 4.5+ | Si existen en 4.7, sus nombres y si sirven en ejecución | 10.10 (por eso se propone IK propia) |
| `SpringBoneSimulator3D` | Nombres de propiedades en 4.7 y coste en Android | 11.3, 12.6, 13.6 |
| Retargeting con huesos sin mapear (`x_…`) | Que el importador los deje intactos | 13.6 |
| Partículas (`GPUParticles3D`) en Compatibility | Disponibilidad y coste | Efectos |
| Derivadas de pantalla (`dFdx`, `dFdy`) en Compatibility | Disponibilidad | Sombreado facetado |
| Profundidad de campo y resplandor en Mobile y Compatibility | Disponibilidad | Efectos de foto |
| Límite de luces por malla en Mobile | Número exacto en 4.7 | 10.6 |
| `KHR_lights_punctual` al exportar | Que `GLTFDocument` la escriba | Luces como pieza |
| `ImporterMesh.generate_lods` en ejecución | Que funcione fuera del editor y conserve pesos | LOD |
| `ZIPPacker` y `ZIPReader` en Android | Que escriban en `user://` | `.ora`, `.gmoldez` |
| `SoftBody3D` sobre malla con esqueleto | Que exista un camino fiable | Tela (descartada) |
