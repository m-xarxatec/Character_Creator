# Fase 13 — Piezas y accesorios (ficha breve)

> Ficha **breve**. Antes de empezar cada paso, un modelo fuerte escribe su ficha detallada (`GUIA_MODELOS.md` §6).
> Depende de: Fase 11 (11.1). Diseño de referencia: `ARQUITECTURA.md` §3, §4 y §6.

**Objetivo de la fase:** poner cualquier pieza en cualquier hueso, traer piezas propias y generar piezas con deslizadores.

**Hecho cuando:** una espada propia se suelta sobre la mano, queda en su hueso, se guarda en el proyecto, se exporta y sigue en la mano al animar en un proyecto vacío.

| Paso | Objetivo | Tam. | Riesgo | Nivel | Depende de |
| --- | --- | --- | --- | --- | --- |
| ★ 13.1 | Una pieza rígida (espada propia) en cualquier hueso, con gizmo de mover, girar y escalar | M | Bajo | medio | 11.1 |
| 13.2 | Acople magnético: soltar la pieza sobre el cuerpo y que se pegue al hueso más cercano | M | Medio | medio | 13.1 |
| 13.3 | Importar un `.glb` propio con asistente (escala, anclaje, licencia) | M | Medio: archivos de cualquier origen | medio | 13.1 |
| 13.4 | Biblioteca de packs: miniaturas, filtros, búsqueda y licencia siempre visible | M | Bajo | simple–medio | 11.1 |
| 13.5 | Generadores procedurales con deslizadores: cuernos; después colas, púas, cristales | M por generador | Medio | fuerte el primero; medio los demás | 13.1 |
| 13.6 | Piezas con huesos extra (cola, orejas largas, alas) y física | M | Medio | fuerte | 11.3, 13.1 |
| 13.7 | La mano agarra sola según el tipo de arma | S–M | Bajo | medio | 10.11, 13.1 |

## Notas de diseño que no deben perderse

- **13.1:** en escena, `BoneAttachment3D` + la pieza. En el proyecto: `hueso` + `transform` (8 números, `ARQUITECTURA.md` §1). Al exportar, la pieza queda como nodo hijo del hueso en el `.glb` (malla aparte, sin fundir con el cuerpo): así el juego puede quitarla.
- **13.2:** algoritmo del §4 de `ARQUITECTURA.md` (rayo → triángulo → vértice → hueso de mayor peso). Prueba sin ventana con rayos sintéticos: rayo a la palma → `RightHand`; a la frente → `Head`; al muslo → `RightUpperLeg`; rayo que no toca → la pieza no cambia de sitio.
- **13.3, seguridad y robustez:** un `.glb` ajeno puede ser enorme o estar mal formado. Antes de cargarlo: tamaño de archivo ≤ 50 MB; tras cargarlo: triángulos ≤ 100.000 (aviso por encima del presupuesto), sin scripts (glTF no los lleva; no cargar nunca `.tscn` ni `.res` ajenos, que **sí** pueden llevar código). El asistente obliga a elegir una licencia de la lista; la pieza importada queda como `"propia"` en `user://packs/usuario/`.
- **Escala al importar:** medir la caja de la pieza y proponer una escala para que mida «tamaño de mano» o «altura del personaje» según el tipo. El usuario confirma.
- **13.5, generador de cuernos (el primero, que marca el patrón):** función pura en el núcleo, `HornGenerator.build(params: Dictionary) -> ArrayMesh`. Parámetros: largo, radio en la base, afilado, curva, giro en espiral, segmentos a lo largo, lados, anillos marcados. Algoritmo: una curva central (arco + espiral) muestreada en N puntos; en cada punto, un anillo de M vértices perpendicular a la tangente (marco de transporte paralelo, para que no se retuerza); radio que decrece; tapa en la punta. Normales calculadas de la fórmula. Prueba: número de vértices = N × M + 1, malla cerrada, normales unitarias, caja contenida en el largo pedido. Los parámetros se guardan en el proyecto; la malla se regenera al abrir. **Cero assets, cero licencias.**
- **Mutaciones «que crecen»** (cuernos, púas): son el generador con el parámetro «largo» en un deslizador. No hacen falta formas.
- **13.6:** `PieceAttacher.merge()` (§3). Reglas: huesos `x_…`, siempre al final, nunca entre dos humanoides. Prueba: tras poner y quitar la cola, la lista de huesos es idéntica a la original.
- **13.7:** cada pieza de tipo arma declara `"agarre": "puño" | "pinza" | "dos_manos"` en su ficha. Al anclarla en una mano, se aplica el gesto del 10.11 a esa mano. Nada de IK.
- **Luces y efectos como pieza** (antorcha, orbe, aura): una pieza puede declarar `"luz": {color, energia, radio}` y `"particulas": "<id>"`. En el estudio se crean los nodos; en el `.glb` exportado la luz viaja con la extensión `KHR_lights_punctual` (Godot la exporta: **NO VERIFICADO**) y las partículas **no viajan** (glTF no las tiene): van en la `.tscn` del 11.4. `GPUParticles3D` en Compatibility: **NO VERIFICADO**; alternativa `CPUParticles3D`.
- **Piezas de serie:** hechas por nosotros (generadores o Blender) o CC0 con fila en `CREDITOS.md`. La biblioteca enseña siempre autor y licencia.

## Juicio visual

13.1 (gizmo cómodo), 13.5 (¿los cuernos se ven bien con el toon y el contorno?), 13.6.

## Si te atascas

Si una pieza importada llega con esqueleto propio y pesos: no intentes fundirla en 13.3. Eso es 13.6 o el rig automático de `IDEAS.md`. Impórtala como rígida y avisa.
