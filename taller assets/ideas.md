# IDEAS — Evolución del Taller de Assets de GameMolde

**Documento de propuestas · 20 de noviembre de 2026 · No es una lista de tareas aprobadas**

> Alcance exclusivo: **Taller de Assets** (generación, edición ligera, organización y exportación de objetos, equipamiento y prendas sencillas). No incluye nuevas especies, creación de personajes, estudio de animaciones ni rediseño global de GameMolde. Las ideas aquí descritas **no se implementan automáticamente**: para pasar al desarrollo necesitan aprobación y una ficha de paso, conforme al [CLAUDE.md del proyecto](https://github.com/m-xarxatec/Character_Creator/blob/main/CLAUDE.md). No sobrescribir el `IDEAS.md` raíz del repositorio; conservar este archivo junto a `plan.md` en `propuestas/taller_assets/`.

## 1. Principio de diseño: un taller potente, no un Blender reducido

Las mejoras deben seguir cinco reglas:

1. **Un control, un resultado comprensible.** Evitar veinte opciones ocultas para conseguir una espada sencilla.
2. **Todos los assets siguen siendo editables por parámetros.** La receta es la fuente de verdad; el `.glb`, la salida.
3. **No añadir servicios ni dependencias pesadas al ejecutable.** Preferir GDScript y los datos ya preparados por GameMolde.
4. **No confundir generación geométrica con reconstrucción exacta.** Una imagen única permite extrusiones o aproximaciones; varias vistas bien alineadas aportan más información.
5. **Compatibilidad antes que cantidad:** un objeto que se equipa, anima y exporta correctamente aporta más que veinte generadores con fallos de pivote, rig o guardado.

## 2. Base aprobada para el MVP del Taller

Estas capacidades son **compromisos del MVP**, detallados en `plan.md`; aquí se recogen para que futuras ideas no lo desvíen:

| Capacidad | Versión mínima |
|---|---|
| Pestaña Taller | Integrada en GameMolde, vista 3D orbital, controles y biblioteca |
| Espada | Generador paramétrico low-poly de hoja, guarda, mango y pomo |
| Desde imagen | PNG sencillo (y JPG de fondo uniforme si supera pruebas) → máscara → extrusión con grosor |
| Camiseta | Malla 3D separada compatible con el cuerpo base y pruebas de rig |
| Edición ligera | Parámetros, colores, tamaño, grosor, orientación/pivote |
| Almacenamiento | Receta versionada + `.glb` + miniatura + licencia en `user://packs` |
| Integración | Equipar espada en socket, camiseta en torso, exportar por separado y con personaje |
| Ejecución | 100 % offline y sin IA obligatoria |

**No añadir más categorías al MVP hasta que se cumplan estas ocho condiciones.**

## 3. Mejoras baratas y de alto valor: siguiente versión

| Idea | Ganancia para el usuario | Coste | Condiciones |
|---|---|---|---|
| Presets de espada | Espada corta, larga, mandoble, daga, hoja rota | Bajo | Misma malla paramétrica; son recetas nuevas |
| Generador de escudos | Redondo, rectangular, cometa, con relieve central | Bajo–medio | Reutilizar contornos/extrusión; permitir curvatura simple |
| Generador de hachas y mazas | Cabeza + asta con primitivas low-poly | Bajo–medio | Reutilizar secciones y materiales |
| Generador de bastones/varitas | Tramos cilíndricos, anillos y remates | Bajo | Reutilizar generadores de anillos |
| Pivotes predefinidos | «Mano derecha», «Mano izquierda», «Espalda», «Cadera», «Suelo» | Bajo | Mantener convención de sockets del repo |
| Simetría X/Y | Objetos alineados sin ajustes manuales repetitivos | Bajo | No cambiar rig ni transformaciones exportadas |
| Duplicar/variar asset | Crear variantes de una receta sin empezar de cero | Bajo | ID nuevo y miniatura distinta |
| Colores por submalla | Hoja, guarda, mango, adorno; paletas listas | Bajo | Materiales compartidos y sin texturas grandes |
| Generación por lotes de variantes | Variaciones de color/tamaño de una misma espada | Bajo–medio | Límites de tamaño y ejecución; sin servicio en segundo plano |
| Historial local de recetas | Recuperar la última versión de un asset | Medio | Guardar diffs o versiones pequeñas, no GLB duplicados indiscriminadamente |
| Exportación de OBJ opcional | Compatibilidad con herramientas clásicas | Medio | Solo si aparece necesidad real; GLB sigue siendo el formato principal |

**Orden recomendado:** presets → escudo → pivotes → hacha/maza → variantes → materiales. Añadir únicamente mejoras con pruebas automáticas del contrato de generación.

## 4. Imagen 2D → 3D: aumentos progresivos sin IA

### Etapa I — Muy asequibles

- **Máscara manual:** cargar un PNG blanco/negro o pintar fuera del Taller la región deseada. Resuelve fondos difíciles sin un segmentador pesado.
- **Separación por color:** seleccionar regiones de una ilustración para darles profundidades distintas, con selector de color y tolerancia. Los colores no siempre corresponden a piezas físicas; el usuario debe poder corregir.
- **Varios contornos y agujeros:** admitir islas múltiples y agujeros de silueta (por ejemplo, un asa). Requiere triangulación adecuada y pruebas de mallas cerradas; no basta con `Geometry2D.triangulate_polygon` sobre un contorno externo.
- **Bisel low-poly:** anillos perimetrales interiores para suavizar filos y bordes. Más útil que una subdivisión global indiscriminada.
- **Modo relieve por capas:** cada región recibe altura diferente. Bueno para escudos, emblemas, hebillas, señales y decoración, pero continúa siendo 2.5D.
- **Textura frontal** del dibujo original con UV y reverso opcional. Elegir entre color plano, textura o mezcla; no hornear texturas gigantes para cada variante.

### Etapa II — Mejora moderada

- **Volumen abombado según distancia al contorno:** mapa de distancia al borde → grosor central y caras curvas. Ideal para escudos, piedras estilizadas y medallas; no adivina geometría oculta.
- **Perfiles de revolución:** jarrones, copas, botellas y piezas cilíndricas desde una silueta lateral y un eje de revolución marcado.
- **Modo voxel:** pixel art → columnas de vóxeles y caras visibles; aplicar *greedy meshing* para eliminar caras internas/combinar caras coplanares. Poner límites de resolución para evitar miles de cubos inútiles.
- **Generación de superficies a partir de varias capas PNG** que el usuario dibuje: delante, centro y detrás. Es controlable, simple y útil para props estilizados.

### Etapa III — Investigación, no prometer automatización perfecta

- **Multivista ortográfica:** frontal + lateral (+ superior) con orientación, escala y centros alineados. Construir volumen aproximado mediante *silhouette intersection* / *visual hull*, extraer superficie y simplificar. **No reconstruye concavidades que ninguna silueta muestra.**
- **Asistente de alineación visual** con cuatro puntos de referencia por vista, recortes y ajuste de escala antes de reconstruir. A menudo aporta más que sofisticar el algoritmo.
- **Fotografías en perspectiva:** requieren calibración/correspondencias y son más complejas que hojas de referencia ortográficas. Evaluar solo si existe demanda y ejemplos suficientes; no meter fotogrametría completa en el Taller por defecto.

**Regla:** un modo nuevo debe añadir valor real en un tipo de objeto. No incluirlo únicamente para tener más botones.

## 5. Catálogo de objetos: expansión por familias

El catálogo debería crecer **por familias de algoritmos**, no por una clase aislada por cada objeto.

| Familia generativa | Assets potenciales | Base técnica reutilizable | Prioridad sugerida |
|---|---|---|---|
| Hojas y varillas | Espadas, cuchillos, lanzas, varitas, bastones | Perfil a lo largo de eje + secciones | Alta |
| Placas/escudos | Escudos, brazales rígidos, insignias, hebillas | Siluetas + extrusión + curvatura | Alta |
| Recipientes | Barriles, pociones, botellas, jarrones | Revolución de perfil / anillos | Media |
| Bloques decorados | Cofres, cajas, muebles muy simples | Primitivas + biseles + piezas | Media |
| Accesorios de cabeza | Coronas, cuernos, halos, gafas sencillas | Curvas, tubos, repetición y sockets | Media; ya contemplados en AB.11 |
| Armadura rígida | Hombreras, grebas, placas de pecho, coderas | Superficies sobre cuerpo + deformación mínima | Media-alta dificultad |
| Calzado | Botas, zapatos, suelas y punteras | Superficie derivada del pie + suela | Media; enlaza AB.10 |
| Ropa ceñida | Camisetas, tops, calcetines, guantes | Helpers o derivación de malla con pesos | Media; enlaza AB.3–AB.7 |
| Ropa amplia | Chaquetas sueltas, faldas complejas, capas | Patrones, peso óseo, correcciones | Baja prioridad; alto coste |

Un asset puede mezclar familias sin crear una infraestructura nueva: por ejemplo, una **armadura ligera** formada por una camiseta ajustada + placas rígidas asociadas a huesos.

## 6. Ropa y armaduras sin convertir el Taller en un simulador textil

**Ruta de mejora realista, compatible con la expansión de GameMolde:**

1. Camiseta básica del MVP.
2. Manga corta/larga, cuello sencillo y holgura limitada **como parámetros** de la misma prenda.
3. Guantes y calcetines: mallas derivadas del cuerpo con pesos heredados.
4. Botas: pieza del pie + suela/caña procedural; mantener mismo esqueleto.
5. Protección rígida: placas en pecho, hombros, rodillas y antebrazos; seguir uno o varios huesos con transformaciones estables.
6. Pantalón sencillo / falda básica después de disponer del helper apropiado.
7. Ocultación de piel bajo prendas con máscara, coordinada con AB.6; combinar capas solo cuando un caso lo pida.

**Evitar por ahora:** patrones de costura editables, simulación de tela en tiempo real, transferencia universal de rig a cualquier fotografía, autorig de ropa arbitraria, cloth painting complejo, colisiones físicas para cada prenda y herramientas estilo Marvelous Designer. Son proyectos aparte, no mejoras ligeras de un Taller de assets.

## 7. Calidad, usabilidad y ligereza

| Mejora | Beneficio | Condición de incorporación |
|---|---|---|
| Vista de silueta superpuesta | Saber si la extrusión respeta el dibujo | Muy barata si ya existe máscara |
| Selector de facetas (4/6/8/12 lados) | Low-poly más controlable | Mantener topología válida |
| Nivel de detalle «ligero / normal» | Evitar assets pesados | Solo si se mide rendimiento/triángulos |
| Vista frente/lado/3⁄4 y rotación | Detectar que la malla no sea un simple plano | Reutilizar cámara actual |
| Indicador de triángulos, tamaño y avisos | Saber si es apto para juego | Datos reales del generador |
| Biblioteca con etiquetas/buscador | Encontrar assets guardados | Sin indexación remota, catálogo local |
| Miniaturas automáticas 256 px | Reconocer piezas | Reutilizar SubViewport/captura |
| Recentrar objeto y restablecer pivote | Exportar objetos bien colocados | Transformación guardada en receta |
| Aviso de cambios sin guardar | No perder ediciones | Reutilizar patrón del editor existente |
| Pruebas de regresión por recetas | Refactorizar sin romper mallas | Fixtures pequeños y deterministas |
| Fichas compactas de licencia | Packs reutilizables limpios | Autor/licencia/procedencia visibles |

**Reglas de presupuesto:** mantener mallas y materiales modestos; limitar tamaño/resolución de imágenes; no procesar en cada frame; no mantener en memoria varias mallas de personaje pesadas para previsualizar una espada; medir antes de optimizar; evitar introducir decenas de dependencias para tareas geométricas simples.

## 8. Fase futura: agente con skill de diseño 3D

**Idea expresada por el usuario:** más adelante conectar un agente que tenga precargada una **skill de diseño 3D**. Esta mejora **no forma parte del MVP** y no debe condicionar su funcionamiento offline.

### Diseño de integración ligero y seguro

- Exponer **operaciones declarativas** existentes: `listar_tipos`, `crear_receta`, `validar_receta`, `generar_preview`, `consultar_medidas`, `guardar_asset`, `equipar_asset`. Nombres ilustrativos, no endpoints implementados.
- El agente **devuelve recetas y revisiones de parámetros**, no código GDScript para ejecutar dentro de GameMolde.
- La skill describiría unidades, topología low-poly, presupuesto de triángulos, convenciones de ejes, sockets, pesos de ropa, normas de exportación y errores comunes.
- El mismo contrato funciona **sin agente** mediante la interfaz; el agente es un cliente más, no el motor de modelado.
- La aplicación **validaría** tipos, rangos, rutas y materiales antes de aplicar peticiones. Guardar/equipar/exportar solo con confirmación del usuario cuando corresponda.
- Un primer puente local podría ser **archivos JSON intercambiados manualmente**; solo considerar HTTP local/MCP si hay una necesidad comprobada. Nada de servidor siempre encendido por defecto.
- La skill puede aprender a componer una espada, escudo o armadura con bloques parametrizados, revisar una captura y ajustar parámetros en iteraciones, pero no obtiene automáticamente formas ocultas de una imagen.

### Ejemplo futuro de uso, no funcionalidad actual

> «Crea una espada oscura low-poly con hoja ancha de 90 cm, guarda curvada y pomo de cristal. Mantén menos de 1.500 triángulos y prepárala para la mano derecha».

El agente escogería una plantilla, produciría una receta, invocaría al motor geométrico y devolvería un resultado verificable en el Taller. La aprobación y el guardado seguirían perteneciendo al usuario.

## 9. Ideas que conviene descartar o aplazar indefinidamente

- «Cualquier fotografía → modelo perfecto 360°» sin IA o información de múltiples vistas: no es una promesa técnicamente fundamentada.
- Escultura libre con cientos de pinceles, remallado avanzado, simulación textil compleja y animación de personajes: demasiado grande para esta expansión.
- Importación/exportación de decenas de formatos desde el día uno. **GLB primero.**
- Añadir OpenCV/Trimesh/Python como **dependencias obligatorias del programa exportado** sin una razón demostrada.
- Crear un segundo motor de rigging, otro sistema de packs o un segundo formato de proyecto: duplicaría funcionalidades ya planificadas en GameMolde.
- Agente obligatorio, generación en la nube o costes por API: contradicen el requisito original de independencia.
- Distribuir packs externos sin comprobar licencias, o declarar CC0 a una imagen importada cuyo autor no lo autorizó.
- Editor de materiales basado en nodos tipo Blender como requisito de uso: complejidad muy superior al beneficio inmediato.

## 10. Hoja de prioridades tras el MVP

| Orden | Lote | Objetivo | Coste relativo |
|---|---|---|---|
| **P1** | Espadas, escudos, hachas, pivotes y presets | Más objetos usando lo ya construido | Bajo–medio |
| **P2** | Siluetas por regiones, bisel y textura frontal | Mejorar imágenes 2D sencillas | Medio |
| **P3** | Botas, guantes, placas y variantes de ropa ceñida | Aprovechar rig y helpers existentes | Medio–alto |
| **P4** | Modo volumen simétrico, revolución y voxel | Ampliar familias geométricas sin IA | Medio |
| **P5** | Varias vistas ortográficas | Volúmenes 3D aproximados mejor informados | Alto |
| **P6** | Interfaz para agente + skill de diseño | Automatización opcional, mismo motor | Medio–alto |
| **P7** | Fotos multivista en perspectiva | Solo si hay casos y calidad medibles | Alto; no prioritario |

**Prioridad no es autorización.** Cada lote se trocea y se aprueba individualmente, después de medir y aceptar el MVP.

## 11. Referencias e inspiración

**Reutilizar decisiones del repositorio:**

- [Expansión v2, fase AB](https://github.com/m-xarxatec/Character_Creator/blob/main/propuestas/expansion_v2.md) — helpers, prendas, rigid props, licencias.
- [Arquitectura, piezas/packs y `.gmolde`](https://github.com/m-xarxatec/Character_Creator/blob/main/ruta/ARQUITECTURA.md) — contratos que no deben duplicarse.
- [IDEAS.md raíz](https://github.com/m-xarxatec/Character_Creator/blob/main/IDEAS.md) — alcance general del creador.
- [GUIA_INTERFAZ.md](https://github.com/m-xarxatec/Character_Creator/blob/main/diseno/GUIA_INTERFAZ.md) — lenguaje visual existente.

**Inspiración open source estudiada, no dependencias incluidas:**

- [Vectify](https://github.com/atdotslash/Vectify) — extracción de contorno y extrusión.
- [GLBForge](https://github.com/glbforge/glbforge) — extrusión y malla en GLB; sus partes con IA no interesan al Taller.
- [ReliefDrop](https://github.com/kcgdz/ReliefDrop) — relieves por capas, previsualización y formatos.
- [Roxel](https://github.com/starzonmyarmz/roxel) — editor voxel, exportación de malla.
- [2D-to-3D Voxelizer](https://github.com/GazPrash/2d-to-3d-voxelizer) — voxelización sin modelos generativos.
- [Drawing to 3D Agent](https://github.com/nyyyaomi/drawing-to-3d-agent) — ideas de multi-vista; no integraremos sus agentes en el MVP.
- [2D-to-3D-Converter](https://github.com/Fatcatcreate/2D-to-3D-Converter) — intersección de siluetas y extracción de superficie; comprobar la licencia.

> La reutilización de **código** está sujeta a auditoría de licencia y dependencias; leer algoritmos como inspiración no implica copiarlos. El núcleo de GameMolde es MIT y su área `blender/` tiene reglas GPL específicas.
