# AB.16 — Comprobar el `.glb` exportado con piezas

> Ficha del 2026-11-21 (nivel: medio). Aprobada por el responsable. Solo se tocan pruebas; el programa no cambia.

## 1. Objetivo y «Hecho cuando»

`probar_glb.gd` exigía una sola malla, así que un `.glb` con piezas (AB.7) daba FALLO y sus mallas no se comprobaban.
Hecho cuando: (1) `t` y `a --pose-a` siguen en TODO BIEN; (2) el modo con piezas da TODO BIEN sobre un `.glb` real; (3) las roturas de §5 dan FALLO; (4) `git status --short` solo muestra los archivos de este paso.

## 2. Nivel de modelo

Medio: una prueba y un generador, sin tocar el núcleo.

## 3. Archivos

- **Se tocan:** `pruebas/godot/probar_glb.gd`, `pruebas/godot/generar_glb_piezas.gd` (nuevo).
- **Documentos:** esta ficha y `PLAN.md`.
- **No se toca:** `godot/app/`, `godot/addons/`, ningún límite existente.

## 4. Diseño

1. Sin argumentos nuevos, la prueba sigue igual: una sola malla con piel.
2. `--piezas=N --rigidas=M` (van juntos) espera el cuerpo y N mallas de piezas, M de ellas con una sola articulación. Cuenta mallas: unos cuernos son 2.
3. Cada pieza: piel, el mismo esqueleto de 53 huesos, articulaciones que son huesos, bind pose = inversa del reposo, 4 influencias que suman 1.
4. Los accesorios rígidos **también llevan piel** (`RigidPiece.to_skinned`: una articulación, peso 1), así que se comprueban igual.
5. Los pesos se leen además **del archivo**: Godot los normaliza al importar y una suma mala no se ve en la escena.
6. `generar_glb_piezas.gd` exporta con el editor real pelo, ropa y cuernos a `pruebas/godot/salida/glb_piezas/` (ignorada por git).
7. Límites nuevos: bind pose y suma de pesos, 0,001 (ya no son PROVISIONAL: aprobados por el responsable el 2026-11-21).

## 5. Pruebas

```
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s generar_glb_piezas.gd)
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_glb.gd -- "$PWD/pruebas/godot/salida/glb_piezas" --piezas=4 --rigidas=2)
```

**Detecta el fallo** (sobre copias): `.glb` con piezas en modo normal; número de piezas o de rígidas erróneo; pieza sin piel; bind pose movida; pesos que no suman 1; accesorio en otro hueso.

## 6. Si te atascas

Si la prueba encuentra un defecto en el `.glb` exportado, para y dilo: no se arregla aquí ni se relaja la prueba (regla 9).
