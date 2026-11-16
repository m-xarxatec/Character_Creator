# Fase 12 — Ropa (ficha breve)

> Ficha **breve**. Antes de empezar cada paso, un modelo fuerte escribe su ficha detallada (`GUIA_MODELOS.md` §6).
> Depende de: Fase 11 (11.1: sistema de piezas). Diseño de referencia: `ARQUITECTURA.md` §2 (capa 8) y §6.
> **Es la fase más difícil del proyecto.** El paso 12.1 es de nivel fuerte sin discusión.

**Objetivo de la fase:** ropa por capas que sigue al cuerpo en todos sus extremos y oculta la piel de debajo.

**Hecho cuando:** con el cuerpo en sus extremos, la piel no atraviesa la camiseta (medido: 0 vértices de piel visibles por fuera).

| Paso | Objetivo | Tam. | Riesgo | Nivel | Depende de |
| --- | --- | --- | --- | --- | --- |
| 12.1 | Herramienta de pack: transfiere a una prenda las formas y los pesos del cuerpo (Godot sin ventana, MIT) | L | **Alto**: es el corazón de la fase | **fuerte** | 11.1 |
| ★ 12.2 | Una camiseta CC0 de MakeHuman que sigue al cuerpo en vivo y se exporta | M | Alto | medio (con 12.1 hecho) | 12.1 |
| 12.3 | Ocultar la piel de debajo (máscara por vértice + `discard`) | M | Medio | medio | 12.2 |
| 12.4 | Capas y orden (interior, torso, piernas, pies, exterior) | M | Medio: prendas que se atraviesan entre sí | medio | 12.3 |
| 12.5 | Al exportar, borrar las caras de piel ocultas | S–M | Medio: no romper índices ni pesos | medio | 12.3 |
| 12.6 | Faldas y capas con huesos de muelle | M | Medio | medio | 11.3, 12.2 |

## Notas de diseño que no deben perderse

- **Idea central (12.1):** una prenda sigue al cuerpo si lleva **las mismas formas, con los mismos nombres**. Entonces en ejecución basta `ShapeWeights.apply(prenda, pesos)`: cero código nuevo en el editor. Todo el trabajo se hace una vez, al crear el pack.
- **Algoritmo de la transferencia (propio, MIT; no copiar el de MPFB, que es GPL):**
  1. Para cada vértice `v` de la prenda, en reposo: buscar el punto más cercano sobre la superficie del cuerpo (triángulo + coordenadas baricéntricas `b0, b1, b2`) y guardar el desplazamiento `d` respecto a ese punto, expresado en la base local del triángulo (normal y dos aristas).
  2. Para cada forma `F` del cuerpo: el delta de `v` es la mezcla baricéntrica de los deltas de los tres vértices del triángulo. Opcional (más exacto): recalcular la base del triángulo deformado y reaplicar `d`.
  3. Pesos de hueso: mezcla baricéntrica de los pesos de los tres vértices, quedarse con los 4 mayores y dividir por su suma.
  4. Descartar las formas cuyo delta máximo en la prenda sea < 0,01 mm (ahorra memoria).
  5. Escribir el `.glb` de la pieza con `GLTFDocument` y su ficha.
- **Búsqueda del punto más cercano:** 14.517 vértices y 26.756 triángulos de cuerpo contra una prenda de unos miles de vértices. A fuerza bruta en GDScript son minutos; aceptable para una herramienta que se lanza una vez por prenda. Con una rejilla espacial baja a segundos. Empezar por fuerza bruta y medir.
- **Trampa de las axilas y la entrepierna:** el punto más cercano puede caer en el brazo cuando el vértice es del costado. Filtro: descartar triángulos cuya normal mire en contra del desplazamiento (`d · n < 0`) o cuya distancia supere un máximo. Prueba: la camiseta con «brazos arriba» no se estira hacia el brazo.
- **Prueba de la fase (medible):** para N cuerpos (las 243 esquinas de la tabla, o los 10 aleatorios + extremos de cada deslizador), contar los vértices de piel **dentro de la zona cubierta** que quedan por fuera de la prenda (distancia con signo a lo largo de la normal > 0). Límite final: 0. Límite intermedio aceptable con 12.3 activo: los que queden ocultos por la máscara.
- **12.3, máscara:** la ficha de la prenda guarda qué vértices del cuerpo tapa (se calcula en 12.1: vértices del cuerpo con prenda a menos de X mm por encima). En vivo, un segundo color por vértice o una textura 1D pasa la máscara al shader, que hace `discard`. Varias prendas: máscara = unión.
- **La prenda base pintada** (color `garment`) sigue existiendo debajo. La regla del 6.1 no cambia: sin detalle anatómico bajo ninguna capa.
- **Assets:** la ropa de «MakeHuman system assets» es CC0 (ya en `CREDITOS.md`). Viene en formato `.mhclo` + `.obj` (texto). Leerlos con un lector propio escrito desde la documentación del formato; **no** usar el código de MPFB ni de MakeHuman para ello (GPL/AGPL). El `.mhclo` ya trae, por vértice, 3 vértices del cuerpo y pesos baricéntricos: si se confirma leyendo su documentación (**NO VERIFICADO**), el paso 1 del algoritmo sale gratis para esas prendas.
- **Topología de la malla:** las prendas de MakeHuman están hechas para la malla base **con** sus vértices auxiliares. Comprobar que los índices que cita el `.mhclo` existen en nuestra malla limpia (el paso 1.x del PLAN quitó auxiliares). Si no, se usa el algoritmo general por cercanía.
- **Memoria:** una prenda con 60 formas × 3.000 vértices es pequeña frente al cuerpo, pero suma. Presupuesto en `RENDIMIENTO.md` §2.

## Juicio visual

12.2, 12.4 y 12.6, con hoja de capturas en cuerpos extremos y en poses del 5.2.

## Si te atascas

- Si tras 12.1 quedan vértices de piel por fuera en cuerpos extremos: no subas el límite ni engordes la prenda a ojo. Da la medida por cuerpo y por zona.
- Si la única ropa disponible que encaja no es CC0: **para** (D19).
