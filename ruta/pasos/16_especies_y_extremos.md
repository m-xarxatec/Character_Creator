# Fase 16 — Especies y modificaciones extremas (ficha breve)

> Ficha **breve**. Antes de empezar cada paso, un modelo **fuerte** escribe su ficha detallada (`GUIA_MODELOS.md` §6). Casi toda la fase es de nivel fuerte.
> Depende de: MVP cerrado; 16.3 en adelante, de la Fase 13. Decisión D23 (prefijos `largo:` y `grosor:`).
> Diseño de referencia: `ARQUITECTURA.md` §2.2 (largo y grosor), §2.4 (escultura), §5 (especies).

**Objetivo de la fase:** llevar el cuerpo más allá de lo humano sin romper los pesos, el perfil humanoide ni la exportación.

**Hecho cuando:** un personaje con brazos largos y gruesos, piernas cortas y un brazo distinto del otro se exporta, pasa `probar_glb.gd` y se anima con la biblioteca de Quaternius sin que las manos se deformen.

| Paso | Objetivo | Tam. | Riesgo | Nivel | Depende de |
| --- | --- | --- | --- | --- | --- |
| ★ 16.1 | Largo y grosor de **un** hueso (brazo), de punta a punta: tabla → núcleo → panel → `.glb` → prueba | M | Medio: diseño razonado pero **no probado** | **fuerte** | MVP |
| 16.2 | Rangos ampliados y deslizador «Exageración» | S–M | Medio: las formas fuera de rango se rompen | medio | 16.1 |
| 16.3 | Auditoría de especie y segunda base (chibi adulto) | XL | Alto: assets y pipeline de Blender | fuerte | Fase 9, Blender |
| 16.4 | Formas dispersas (solo si las medidas lo piden) | XL | Alto: cambia cómo se dibuja el personaje vivo | fuerte | medidas de 8.5 y O6 |
| 16.5 | Escultura libre (empujar, tirar, alisar) | XL | Muy alto | fuerte | 16.4 o capa de CPU |
| 16.6 | Piernas de animal (talón elevado) | L | Alto: animaciones humanoides sobre otra pierna | fuerte | 16.1, 16.3 |

## Notas de diseño que no deben perderse

- **16.1 empieza con una prueba de un solo hueso**, antes de tocar la tabla: `largo = 1,5` en `LeftUpperArm`. Comprobar: (1) la distancia hombro–codo crece ×1,5 (< 0,1 mm); (2) el antebrazo y la mano conservan su tamaño y forma (distancias entre sus vértices, < 0,1 mm); (3) con el codo a 90°, la mano no se cizalla (ángulos de un triángulo de la palma, < 0,1°); (4) horneado y exportado: huesos con escala 1 y `probar_glb.gd` pasa. Si (3) falla, el diseño del §2.2 está mal: **parar** y replantear.
- **Normales con escala no uniforme:** `MeshBaker` debe transformar las normales con la inversa traspuesta. En vivo, la GPU usa la misma matriz que para los vértices: la luz queda algo inexacta mientras se edita y exacta al exportar. Con el estilo en vivo del 4.6 (malla estática al soltar) el error solo se ve mientras se arrastra.
- **16.2, «Exageración»:** un factor `k` (1 a 2) que aplica `valor' = neutro + (valor − neutro) × k` a todos los deslizadores de tipo Proporción y a los de hueso. Para las Formas, pesos > 1 extrapolan y pueden romper la malla: cada fila de la tabla declara su rango máximo seguro (columna nueva `max_extra`, por defecto 1 = no extrapola), fijado con las medidas del 5.10. La «Exageración» nunca cambia la edad aparente por debajo de adulto: el deslizador de edad queda **fuera** del factor.
- **16.3, auditoría:** quitar una a una las suposiciones «humana» de la tabla del §5 de `ARQUITECTURA.md`, con el manifiesto nuevo (`capacidades`). Prueba: una especie mínima de juguete (una caja con 3 huesos) carga, se edita y se exporta. Después, la base chibi: mismos 53 huesos, otra malla o las mismas formas llevadas al extremo. **El chibi es un adulto estilizado**: lista de revisión de límites en la ficha de la especie.
- **Especies con la misma malla:** elfo, orco, enano y gigante no necesitan base nueva: son **presets + piezas** (orejas, colmillos) + rangos ampliados + color de piel. Salen casi gratis tras 16.1 y 16.2 y la Fase 13. Esqueleto, robot y gólem son piezas rígidas que tapan el cuerpo (Fase 13) o bases nuevas (16.3).
- **16.4:** solo con una medida que lo pida (memoria en Android o cara con más de unas 300 formas). Diseño en el §2.4.
- **16.5:** la escultura trabaja en reposo y se guarda como lista dispersa. Pincel = rayo (el del 13.2) + caída por distancia + simetría opcional. Alisar = media con los vecinos (hace falta la tabla de vecinos por vértice, calculada una vez). Límite de desplazamiento por vértice para que no se rompa el contorno. La regla de «sin detalle anatómico» no se puede comprobar por código: la escultura libre queda fuera de las zonas cubiertas por la prenda base (máscara `garment`), por decisión de diseño.
- **16.6:** una pierna de talón elevado con el mismo número de huesos (muslo, pierna, pie, dedos) cambia las proporciones y la pose de reposo. Las animaciones humanoides seguirán moviéndola como una pierna humana: se verá raro salvo con animaciones propias. Decirlo claro al usuario. Alternativa barata: una **pieza** de pata que tapa la pierna.

## Límites que se revisan en cada paso de esta fase

Parte de un adulto · sin detalle anatómico bajo la prenda base · assets CC0 o propios · las referencias CC-BY-SA solo se miran.

## Juicio visual

Todos los pasos. Hojas con los extremos de cada deslizador nuevo y con las poses del 5.2.

## Si te atascas

Si la prueba de un solo hueso de 16.1 no pasa: no sigas con la tabla ni con el panel. Informa con las 4 medidas.
