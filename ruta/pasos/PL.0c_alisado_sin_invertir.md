# PL.0c — El alisado no invierte triángulos

> Sigue a PL.0b: con sus correcciones, el alisado propio de cada cuerpo ya invierte triángulos (mujer: 4 en la
> entrepierna; hombre con firmeza 0: 2 junto al borde). Aprobado el 2026-11-20. Cierra PL.0, PL.0b y PL.0c juntos.

## 1. Objetivo y «Hecho cuando»

- `probar_formas_propias.py` pasa entera: PL.0 (4 cuerpos) y las 32 esquinas extremas sin triángulos invertidos.
- `datos/humana` regenerado y todas las pruebas pasan.

## 2. Nivel de modelo

**Fuerte**: algoritmo de `blender/` y datos que viajan con el programa.

## 3. Archivos

- **Se tocan:** `blender/formas_propias.py` (`flipped`, `unflip`, `smoothing` con `triangles`);
  `blender/exportar_datos.py` (`smoothing_corrections` recibe `triangles`; nombres completos, ver §4);
  `pruebas/fase_6/probar_formas_propias.py` (la llamada y «macros extremas»); `pruebas/fase_2/probar_exportar_datos.py`
  (`read_glb`); `IDEAS.md` (lo del hombro); `PLAN.md`.
- **Al regenerar:** `godot/datos/humana/` (`cuerpo.glb`, `articulaciones.json`, `manifiesto.json`); recuentos de
  `probar_carga.gd` y `probar_formas.gd`; texto de `datos/FORMATO.md` y de `probar_exportar_datos.py` («sobre
  músculo, grasa y pecho» pasa a las 5 macros).
- **No se tocan:** los límites de las pruebas, la versión del manifiesto, el núcleo.

## 4. Diseño

- `flipped(before, after, triangles)`: máscara de triángulos cuya normal se da la vuelta (producto ≤ 0, como la prueba).
- `unflip(points, delta, triangles, mirror)`: mientras haya triángulos invertidos (como mucho `UNFLIP_PASSES` veces),
  el desplazamiento de sus vértices y de sus simétricos se reduce a la mitad. Sigue simétrico y determinista.
- `smoothing(points, edges, triangles, zones, mirror)` termina con `unflip`. Así lo usan el neutro y cada esquina de
  `smoothing_corrections`, y las correcciones siguen saliendo de restar alisados.
- **Decidido el 2026-11-20 (A):** Blender corta los nombres de forma a 63 caracteres y 36 de las 115 correcciones
  son más largas. `exportar_datos.write_full_names` reescribe `extras.targetNames` del `.glb` con los nombres
  completos (comprueba antes que cada nombre cortado es el principio del suyo); `target_names` los lee y
  `probar_exportar_datos.read_glb` los usa. Sin cambio de formato ni del núcleo. Quitar esas 36 correcciones no
  vale (4 triángulos invertidos, 12,8 mm de error); corregir sin firmeza tampoco (hombre: 2 invertidos, pecho 26 %).
- **Decidido el 2026-11-20 (A):** «macros extremas» cuenta todas las formas en las 8 esquinas de músculo, grasa y
  pecho (las del 6.2) y solo `alisado` en las 32; las demás formas ahí solo se miden. `shoulder_height_decr`
  invierte 4 triángulos en 4 de las 32: a `IDEAS.md`.

## 5. Prueba

`blender -b -P pruebas/fase_6/probar_formas_propias.py 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO'`.
**Detecta el fallo:** sin `unflip` es la ejecución de PL.0b (4 FALLOS: 4, 4 y 2 triángulos; peor 4 en las esquinas).

## 6. Riesgos

- Cerca de los triángulos que se corrigen, el alisado queda a medias: puede bajar el relieve de la zona. Si no llega
  al 50 % (`SMOOTH_DROP`), se da la medida y no se cambia el límite.

## 7. Juicio visual

`pruebas/capturas/formas_propias/complexion.png` y `alisado.png`. Cambia la malla: proponer el revisor-visual.
