# AC.3 — Base del ojo: forma c y parte blanca

> Ficha del 2026-11-22 (nivel: fuerte). **Aprobada el 2026-11-22** con las decisiones de §1.1. AC.3a, en curso; AC.3b, solo después de cerrar SH.2.
> Parte de la c2 elegida en `ruta/pasos/AC.0_direccion_visual.md` §10. Prototipo y medidas: `pruebas/capturas/ac0/proto/` (git lo ignora).

## 1. Objetivo y «Hecho cuando»

Llevar la forma c al programa en lugar del aplastado de la zona del ojo de `cuenca_plana`, con la parte blanca como primera capa. El resto de la cara anime no cambia.

Hecho cuando:

1. `blender/cara_anime.py` genera la forma c y `cuerpo.glb` está regenerado, con 13.380 vértices y 13.378 caras.
2. **0 invertidos visibles y holgura ≥ 0** en reposo y en todos los extremos de los recorridos elegidos, en los 5 deslizadores de Ojos.
3. **0 cruces visibles** en reposo y en esos extremos (decisión 2 de §1.1).
4. El pack MakeHuman sigue bajo su límite, medido antes de escribir nada en el repositorio.
5. El blanco sigue a los párpados con las mismas formas que la piel y su borde es limpio, también en la esquina exterior y en piel oscura.
6. Los ojos se leen con la cámara del juego en la figura de cabeza grande (§5.7).
7. Las pruebas de §6 dan TODO BIEN y sus roturas dan FALLO.

### 1.1 Decisiones del responsable (2026-11-22)

1. **Forma candidata: sí.** AC.3a en una copia, con hoja A/B frente a la c2 (376 pares cruzados en reposo, 284 triángulos visibles), y se espera su juicio.
2. **0 cruces visibles: sí, como meta.** Si con `WALL` y el suavizado de los anillos 0–2 no se llega a 0, se para y la hoja A/B enseña los cruces que quedan en un color llamativo, con primeros planos. El responsable decide si se ven en el render.
3. **Orden:** AC.3a ahora; AC.3b solo después de cerrar SH.2, porque cambia las 6 capturas aprobadas que SH.2 usa como referencia.
4. **Forma nueva aceptada (2026-11-22)**, al aprobar el ojo del AC.4a, que está hecho sobre ella. Sigue abierto cómo cumplir «0 cruces visibles» (74 en reposo): lo resuelve la ficha `ruta/pasos/AC.3b_ojo_en_programa.md`.

## 2. Nivel de modelo

**Opus 5.5 en high** en los tres subpasos: **AC.3a** (geometría y medidas, en una copia), **AC.3b** (datos y pipeline de Blender) y **AC.3c** (núcleo, vista y exportación).

## 3. Contexto mínimo

`blender/cara_anime.py`, `blender/exportar_datos.py` (`face_shapes`, `shape_specs`, `export_species`), `blender/exportar_helpers.py:102`, `godot/addons/creador/body_derived.gd` (`subset`), `godot/addons/creador/body_material.gd` (`PULL_CODE`), `godot/app/body_view.gd:204-218`, `godot/datos/FORMATO.md`, y en el prototipo `ac0_variante.py`, `ac3_medir.py` y `LEEME.md`.

## 4. Archivos

- **AC.3a (en una copia):** nada del repositorio. Salida en `pruebas/capturas/ac3/` (git la ignora).
- **AC.3b (datos):** `blender/cara_anime.py`, `blender/cara_anime_zonas.json`, `blender/exportar_datos.py`, `godot/datos/humana/{cuerpo.glb,manifiesto.json,ojos.json}`, `godot/datos/FORMATO.md`, `pruebas/fase_3/probar_forma_ojo.py` (nueva). Los `.glb` de `godot/packs/` solo si AC.3a demuestra que caben.
- **AC.3c (blanco):** `godot/addons/creador/eye_base.gd` (nuevo), `godot/addons/creador/eye_white.gdshader` (nuevo), `godot/addons/creador/species_data.gd`, `godot/app/body_view.gd`, `pruebas/godot/probar_base_ojo.gd` (nueva).
- **Documentos:** esta ficha y `PLAN.md`.
- **No se toca:** el resto de formas de la cara anime, `articulaciones.json` (debe salir idéntico), `glb_exporter.gd` (el blanco entra por su lista de piezas) ni el shader de piel.

## 5. Diseño

### 5.1 Medidas de partida (2026-11-22)

**Origen:** `ac3_medir.py` sobre una copia, ambos ojos, cabeza y cuello (9.032 triángulos). «Se ve» = no queda entero detrás del blanco (1.260 triángulos tapados). «Recorrido» = hasta qué parte del target, de 5 en 5 %, hay 0 invertidos visibles y holgura ≥ 0, con la bolsa siguiendo al borde (§5.3).

| Extremo | Borde, máx. (mm) | c2: recorrido | c2 al 100 %: inv. / cruces | Candidata: recorrido | Candidata al 100 %: inv. / cruces | Holgura al 100 % (mm) |
| --- | --- | --- | --- | --- | --- | --- |
| `eye-scale-decr` | 3,78 | 10 % | 30 / 284 | 30 % | 4 / 78 | 0,05 |
| `eye-scale-incr` | 2,40 | 20 % | 24 / 220 | 90 % | 2 / 40 | 1,22 |
| `eye-trans-in` | 3,40 | 55 % | 4 / 166 | 100 % | 0 / 8 | 1,00 |
| `eye-trans-out` | 4,60 | 15 % | 16 / 188 | 100 % | 0 / 18 | 1,00 |
| `eye-height2-decr` | 1,00 | 30 % | 18 / 130 | 50 % | 0 / 48 | 1,00 |
| `eye-height2-incr` | 1,80 | 15 % | 25 / 210 | 40 % | 5 / 53 | 1,00 |

- **Recortar la c2 no basta:** se pierde del 45 al 90 % del recorrido, y aun así quedan cruces, porque ya los tiene en reposo.
- **Deslizadores propios sobre la c2 tampoco:** a su 100 % dan 14–96 invertidos.
- **Causa medida:** no son solo los targets. La c2 aplasta el párpado: el área de los triángulos del segundo anillo junto al borde baja a ×0,27 de mediana (×0,04 en el 5 % peor). En la candidata, ×0,78 (×0,45).
- **Deslizadores propios sobre la candidata**, al 100 %, invertidos / cruces: tamaño 2/50 y 2/80; alto 2/64 y 0/62; separación 0/38 y 12/40; altura 2/60 y 20/98; inclinación 4/58 y 2/56. Rangos probados: tamaño ±15 %, alto ±20 %, separación −3,4/+4,6 mm, altura −2,9/+6,1 mm, inclinación ±9°.
- **Cruces en reposo:** a) 0 pares, b) 66, c2 376, c1 360, candidata 92 (36 triángulos en la pared de la bolsa, 36 en los anillos 0–1, 8 en el 2 y 10 en los 3–5).
- **Ninguna opción cumple aún el «Hecho cuando».** La candidata es la que más se acerca.

### 5.2 AC.3a: la forma, en una copia

1. Guardar en `cara_anime_zonas.json` el lazo y la bolsa de cada ojo (`borde.json`: 42 y 342 vértices). El derecho es el reflejo del izquierdo.
2. Llevar el lazo a la elipse de 26 × 16 mm sobre la cara aplanada, como en `place_opening`.
3. **Cambio respecto a la c2:** en el párpado se reparte el **movimiento** del borde (`relax` sobre el desplazamiento) en vez de aplanar sus **posiciones**. Así conserva la separación entre sus vértices.
4. La bolsa queda como un cuenco de 3 mm.
5. Quitar los 92 pares que quedan, en este orden: ensanchar la pared (`WALL` de 0,12 hasta 0,30) y suavizar los anillos 0–2 junto al lazo. Si no llega a 0 cruces visibles, **parar** y marcar los que quedan en la hoja A/B en un color llamativo, con primeros planos.
6. Generar la hoja A/B (c2 frente a la forma nueva) con la piel de SH.1 y **esperar el juicio del responsable**, que también decide si los cruces restantes se ven en el render.

**Resultado del AC.3a (2026-11-22), parado en el punto 5:** con pared de 0,12 a 0,30 y de 0 a 32 pasadas en los anillos 1–2, el mínimo es **74 triángulos cruzados visibles** en reposo (c2: 284), con pared 0,30 y sin suavizado. Suavizar también el lazo lo empeora (100 o más). En los 10 extremos al 100 %: 64–98 cruces visibles (c2: 248–354), hasta 10 invertidos y holgura ≥ 0,07 mm. **No cumple aún el «Hecho cuando».** Hojas y tabla en `pruebas/capturas/ac3/` (`ab_aspecto.png`, `ab_cuenca.png`, `ab_cruces.png`, `ab_extremos.png`, `medidas.md`). El límite del pack (§5.4) se mide cuando se acepte una forma.

### 5.3 Los recorridos

a) **Siempre:** las capas siguen a los párpados con las mismas formas que la piel. En los targets de ojo, el interior de la bolsa no usa el movimiento de MakeHuman: se recalcula como extensión armónica del movimiento del lazo. Sin esto, `eye-scale-decr` da holgura −0,50 mm; con esto, +0,05 mm.
b) **Medir los 10 extremos** con la forma final. Son los 5 deslizadores de Ojos: los 3 de esta medida más `eye_position` e `eye_corner`, que también mueven los párpados. Un recorte se guarda escalando la forma al exportar: la interfaz no cambia.
c) **Si algún extremo se queda por debajo del 70 %** (`# PROVISIONAL`), proponer con las medidas delante deslizadores propios sobre la forma c para esos rasgos. Se conservan los 5 (tamaño, alto, separación, altura e inclinación) para no perder ninguno de los que ya aprobaste. Hoy, con la candidata, quedarían por debajo `eye-scale-decr` y los dos de `eye-height2`.

d) **Rango útil de Tamaño: objetivo ±25 %** (`# PROVISIONAL`), para cambiar el ojo respecto a la cara con amplitud, también en un chibi con ojos grandes. Útil = desde el reposo y sin cortes: 0 invertidos visibles, holgura ≥ 0 y 0 cruces visibles nuevos respecto al reposo. Tamaño = raíz del área de la abertura.

Medido con la forma nueva (2026-11-22, `pruebas/capturas/ac3/tamano.json`):

| Deslizador | Alcance probado | Útil completo | Útil sin contar los cruces |
| --- | --- | --- | --- |
| MakeHuman, reducir | −11,9 % (ancho −16 %, alto −7,5 %) | 0 % (falla en −0,6 %) | −3,6 % |
| MakeHuman, aumentar | +11,9 % (ancho +15,6 %, alto +7,7 %) | +0,6 % | +10,7 % |
| Propio sobre el lazo, reducir | −40 % | 0 % (falla en −2 %) | −6 % |
| Propio sobre el lazo, aumentar | +60 % | 0 % (falla en +3 %) | +9 % |

- **MakeHuman no puede llegar a ±25 %:** al 100 % solo cambia el tamaño un 11,9 %.
- **El propio tampoco llega todavía:** a −25 % deja 10 invertidos y 22 cruces nuevos fuera del blanco, casi todos en los anillos 0–1. A +25 %, 28 invertidos y 126 cruces, repartidos por la pared y los anillos 0–5.
- **Propuesta (sin aprobar):** sustituir las formas de `eye_size` por dos propias, `decr` e `incr`, que escalan el lazo alrededor de su centro, con la bolsa y las capas siguiéndolo. En la interfaz sigue siendo un solo deslizador. Medido: simetría 0,000 mm y 0 mm fuera de cabeza y cuello. **Antes hay que conseguir que el párpado absorba el cambio**, repartiéndolo por una zona más ancha alrededor del ojo; esa técnica aún no está probada.

### 5.4 Límite del pack MakeHuman

En la copia y **antes de escribir nada en el repositorio**: regenerar las 31 piezas (de 48) que llevan `cuenca_plana` y medir los bytes del pack. Hoy: 43.991.380 de 44.000.000 (quedan **8.620**). Si no cabe, parar: el límite solo lo cambia el responsable (regla 9).

### 5.5 AC.3c: el blanco

- **El blanco es la propia bolsa:** `BodyDerived.subset(cuerpo, bolsa, 0.0)`. Al compartir vértices, sigue a todas las formas y al esqueleto sin datos nuevos, y el fondo no puede atravesarlo.
- **Borde limpio:** el borde de la malla es el lazo real del párpado, sin recorte por píxel (`discard`), que es lo que daba dientes en la esquina exterior del prototipo.
- **El blanco responde a la luz:** a la directa y a la ambiente de la escena, como la piel (decisión del SH.3), aunque sea más plano. En una escena oscura no puede brillar. Si sale más sencillo, usa el mismo shader de piel con su propio color, y entonces `eye_white.gdshader` no se crea.
- Sin contorno y adelantado 0,05 mm con el mecanismo de `PULL_CODE`.
- `ojos.json` guarda los índices de `cuerpo.glb` de cada bolsa, por posición (cada vértice del `.glb` tiene su vértice de la malla base), y entra en el manifiesto. `version` sigue en 3: el archivo es opcional. Ningún dato nuevo va en el RGB del color por vértice.
- **`.glb`:** el blanco sale como una malla más del mismo esqueleto, por la lista de piezas de `GlbExporter`. Sin otras piezas se comprueba con `probar_glb --piezas=1 --rigidas=0`.

### 5.6 Parpadeo (no entra en este paso)

La forma c necesitará un **cierre propio**: los targets `eye-*-closure` de MPFB dejan un hueco de 6,1 mm en una abertura de 15,9 mm, y su licencia sigue sin decidir (D41).

**Para AC.5 o AC.6 (no ahora):** sombra suave del párpado superior sobre la parte de arriba del blanco, típica del anime.

### 5.7 Lectura con la cámara del juego

**No existe un preset chibi:** se quitó en PL.9 y PL.10. Se comprueba con lo más parecido que hay hoy, Cabeza › Tamaño ×2,5 y Altura ×0,65, en los 3 tonos, con la cámara de la prueba 3.12 (45°, 6 m, 35°, 1200 × 800).

## 6. Pruebas

Solo las de este paso. La batería completa, cuando el responsable la pida.

- **`probar_forma_ojo.py` (AC.3b):** vértices y caras iguales; simetría ≤ 0,5 mm; 0 invertidos y 0 cruces visibles y holgura ≥ 0 en reposo y en los 10 extremos; fuera de cabeza y cuello ≤ 0,5 mm. Límites nuevos con `# PROVISIONAL`.
- **`probar_base_ojo.gd` (AC.3c):** el blanco tiene las caras de `ojos.json`, sigue a los 5 deslizadores (0,000 mm respecto a la piel) y sale en el `.glb`. Añade una captura en la **escena omni del SH.1**: en el lado sin luz, el blanco no debe destacar más que la piel.
- **Además:** `probar_carga`, `probar_formas_rasgos`, `probar_formas_cara.py`, `probar_packs`, `probar_glb` y la autoprueba.
- **Detecta el fallo** (sobre copias): volver al `relax` de posiciones (cruces), quitar la extensión armónica (holgura negativa), un `ojos.json` con un índice cambiado y un blanco sin las formas.

## 7. Trampas conocidas

1. **Capturas aprobadas:** las 6 de `pruebas/capturas/aprobadas/` son de la cara anime. AC.3b las cambia y volver a aprobarlas es decisión del responsable (regla 9).
2. **Otra sesión trabaja en SH.2** y en los mismos documentos (decisión 3).
3. **Cruces de la hoja del AC.0:** eran los nuevos respecto al reposo. Comparar siempre contando también los de reposo.
4. **Piezas:** `exportar_helpers.py` copia las formas de cara desde la piel más cercana. Una pieza junto al ojo puede cambiar aunque el pack quepa.
5. **`probar_formas_cara.py`** compara con la maqueta: hay que regenerarla con `cara_anime.py`. `probar_cara_anime.py` solo informa de la diferencia con la cara de la 3.13a-4, que crecerá.
6. **Normales:** `StyleNormals` trata la cabeza como un elipsoide. Comprobar en la hoja que la pared de la bolsa no da sombras raras.
7. **`BodyDerived.subset` elige por vértices:** con la bolsa se lleva 730 triángulos por ojo, 6 de ellos de piel con los 3 vértices en el lazo (medido el 2026-11-22). El AC.3c debe elegir los 724 por contigüidad.

## 8. Juicio visual

- **AC.3a:** hoja A/B de la c2 y la forma nueva, con los cruces restantes marcados si los hay. ¿Se acepta la forma nueva? ¿Esos cruces se ven en el render?
- **AC.3c:** ojo en los 3 tonos y primer plano de la esquina exterior, la cámara del juego con cabeza grande y la escena omni. ¿El borde es limpio? ¿Los ojos se leen? ¿El blanco se oscurece con la piel?

Se dan solo las rutas, sin valorar, y se propone el revisor-visual al cerrar.

## 9. Si te atascas

Para y dilo si: no se llega a 0 cruces visibles, el pack no cabe, `articulaciones.json` cambia, una prueba que pasaba deja de pasar sin causa evidente, o el `.glb` falla. No se relaja ninguna prueba.
