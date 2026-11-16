# Fase 11 — Pelo (ficha breve)

> Ficha **breve**. Antes de empezar cada paso, un modelo fuerte escribe su ficha detallada (`GUIA_MODELOS.md` §6).
> Depende de: Fase 10 (10.1 y 10.2: las piezas se guardan en el proyecto). Diseño de referencia: `ARQUITECTURA.md` §3 (huesos extra) y §6 (packs).

**Objetivo de la fase:** peinados como piezas, con color y con física, que también funcionan en el juego. De paso nace el sistema de piezas que usarán Ropa y Accesorios.

**Hecho cuando:** una coleta se mueve al caminar en el editor y en un proyecto vacío de Godot.

| Paso | Objetivo | Tam. | Riesgo | Nivel | Depende de |
| --- | --- | --- | --- | --- | --- |
| 11.1 | Sistema de piezas mínimo en el núcleo: `PackLibrary` (ficha, licencia, `sha256`, carga) | M | Medio | fuerte para revisar; medio para escribir | 10.1 |
| ★ 11.2 | Un peinado en `Head`, con color, guardado en el proyecto y exportado dentro del `.glb` | M | Medio: encaje con cabezas distintas | medio | 11.1 |
| 11.3 | Física con `SpringBoneSimulator3D` y colisiones de cabeza y torso | M | Medio: API reciente | medio | 11.2 |
| 11.4 | La física viaja al juego: escena `.tscn` junto al `.glb` | M | Medio | medio | 11.3 |
| 11.5 | Más peinados, cejas y barba | M | Bajo (assets) | simple | 11.2 |

## Notas de diseño que no deben perderse

- **Assets:** Quaternius «Universal Base Characters» trae peinados CC0 (**NO VERIFICADO**: comprobar en su página que el pack concreto es CC0 y apuntarlo en `CREDITOS.md` antes de descargar nada; descargar pide permiso). Plan B: peinados propios hechos en Blender por el responsable.
- **Encaje con la cabeza (11.2):** el cráneo cambia con los deslizadores (tamaño de cabeza, formas de cara). Un peinado rígido en `Head` sigue la escala del hueso pero no las formas. Dos niveles: (1) pieza rígida en el hueso, con `transform` ajustable: vale para el primer paso; (2) si la piel atraviesa el pelo, el peinado pasa a `"sigue_al_cuerpo": true` con las formas transferidas (herramienta del 12.1). Medir: vértices de cráneo por fuera del pelo en los 10 cuerpos aleatorios.
- **Un solo esqueleto:** los huesos del peinado se copian al esqueleto del personaje con `PieceAttacher.merge()` (`ARQUITECTURA.md` §3). Nombres `x_pelo_01`… Al final de la lista. `probar_glb.gd` debe aceptar huesos extra con prefijo `x_` y seguir exigiendo los 53 humanoides intactos.
- **`SpringBoneSimulator3D` (11.3):** existe desde Godot 4.4 como hijo de `Skeleton3D`; se configura por cadenas (hueso raíz y hueso final) y admite colisiones (`SpringBoneCollisionSphere3D`, `SpringBoneCollisionCapsule3D`). Nombres exactos de propiedades en 4.7: **NO VERIFICADO**; la ficha detallada empieza con una prueba mínima de una cadena de 3 huesos que cuelga y oscila.
- **Prueba de la física sin ojo:** soltar la cadena horizontal y medir: (a) acaba colgando hacia abajo (ángulo con −Y < 5° tras 3 s); (b) nunca atraviesa la esfera de colisión de la cabeza (distancia ≥ radio); (c) mismo resultado al repetir con paso fijo.
- **11.4:** glTF no transporta la física. Junto al `.glb` se escribe `<nombre>.tscn`: una escena que instancia el `.glb` y añade el `SpringBoneSimulator3D` configurado. Quien quiera física usa la `.tscn`; quien no, el `.glb`. Hacer que la `.tscn` apunte al `.glb` con ruta **relativa** para que sobreviva al copiarla a otro proyecto (cómo resuelve Godot las rutas de una `.tscn` externa: comprobar en la ficha detallada).
- **Color:** el pelo usa el mismo `toon.gdshader` con su propio color y un parámetro de brillo. Sin texturas en el primer paso.
- **Presupuesto:** `GUIA_ESTILO.md` §7: 75 huesos en PC. Un peinado no debería pasar de 12 huesos ni de 6.000 triángulos (PROVISIONAL). `PackLibrary.scan` avisa si una pieza lo supera.
- **El pincel de mechones no se hace** (`HOJA_DE_RUTA.md` §4).

## Juicio visual

11.2 (¿encaja el peinado?), 11.3 (¿el movimiento es natural o gomoso?): vídeo corto o el propio editor.

## Si te atascas

Si el peinado CC0 no encaja con la cabeza anime sin retocar su malla: **para**. Retocar un asset es trabajo de Blender del responsable.
