# AC.4a — Ojo completo (prototipo en una copia)

> Ficha del 2026-11-22 (nivel: fuerte). **Cerrada el 2026-11-22:** el responsable aprueba el aspecto de `ojo_final.png` y `ojos_primer_plano.png` («imágenes perfectas, así se queda»), con `iris_cover` 30 %. Valores finales en `pruebas/capturas/ac3/ac4a/medidas.md`, que mandan sobre los de partida de esta ficha. Pendiente al llevarlo al programa: engorde de la línea inferior en los extremos (aprox. 0,54–1,74 mm, medido por píxeles) y los apaños de la copia (descarte de piel doblada, hueco del contorno y filas inferiores adelantadas 0,90 mm).
> Parte de la forma nueva del AC.3a, **aún sin aceptar** (`ruta/pasos/AC.3_base_ojo.md` §5.2). No sustituye a AC.3b, AC.3c, AC.4, AC.5 ni AC.6.

## 1. Objetivo y «Hecho cuando»

Ver en una hoja, sin tocar el programa, un ojo anime de mirada relajada completo y montado sobre la malla, para que el responsable juzgue el método.

**Cuándo:** después del juicio del giro de cámara y antes de la prueba del Tamaño propio (AC.3 §5.3 d).

**Juicio del giro:** no consta (buscado el 2026-11-22) y el responsable no puede ver nada hasta la noche. Como es un prototipo en una copia, este paso se adelanta y ese juicio queda pendiente. La prueba del Tamaño propio sigue esperándolo.

Hecho cuando:

1. Existen `pruebas/capturas/ac3/ac4a/hoja.png` (§5.8) y `medidas.md`, con la tabla de parámetros por fila.
2. Cada ojo usa **724 triángulos** de la bolsa, con 0 invertidos en sus coordenadas y 0 triángulos de piel.
3. La tira y las capas siguen a la malla en los 10 extremos: distancia máxima tira–lazo y capa–cuerpo **≤ 0,05 mm** (`# PROVISIONAL`), con el máximo dado en mm.
4. Con la luz apagada, ninguna capa del ojo brilla: canal máximo **≤ 0,01** (`# PROVISIONAL`).
5. Los brillos caen en el mismo lado de la cara en los dos ojos.
6. Las roturas de §6 dan FALLO.
7. `godot/` y `blender/` no cambian (mismo `git status` en esas rutas) y las hojas `ab_*` conservan su `sha256`.

## 2. Nivel de modelo

**Opus 5.5 en high:** geometría sobre formas y huesos, shaders con luz y código de terceros por adaptar.

## 3. Contexto mínimo

- Esta ficha y `ruta/pasos/AC.3_base_ojo.md` §5.2, §5.3 y §5.5.
- `pruebas/capturas/ac3/medidas.md`, `ac3a_hoja.gd` (cámaras, piel y `_save`) y `ac3a_montar.gd`.
- `pruebas/capturas/ac0/proto/LEEME.md` y `pruebas/godot/estilo/toon_suave.gdshader`.
- `godot/addons/creador/body_derived.gd`, `body_piece.gd` (`hang`, `follow`) y `mesh_baker.gd` (`shape_arrays`, `bake`).

## 4. Archivos

- **Origen, solo lectura:** `pruebas/capturas/ac0/proto/`, y de `pruebas/capturas/ac3/` `datos/nueva/` y `capas_nueva.json` (la forma nueva no está en `proto/`).
- **Copia de trabajo:** en el scratchpad de la sesión, con `godot/` y `pruebas/godot/estilo/`, más `cuerpo.glb`, `manifiesto.json` y `articulaciones.json` de `ac3/datos/nueva/`. No se crea `copia/` dentro de `proto/`, aunque su `LEEME.md` lo sugiera.
- **Se crean, en `pruebas/capturas/ac3/ac4a/` (git la ignora):** `ac4a_ojo.gd`, `ac4a_hoja.gd`, `ac4a_montar.gd`, `ojo_completo.gdshader`, `ojo_linea.gdshader`, `piel_rubor.gdshader`, `celdas/`, `hoja.png` y `medidas.md`. Son más de 3 archivos y unas 350 líneas (señales 1 y 9 de la guía, previstas aquí): todos desechables y fuera del programa.
- **Al cerrar, con su OK:** `PLAN.md` (solo las líneas propias: la línea de otra sesión, SH.2, también lo edita; **releerlo justo antes**) y `CREDITOS.md` (la entrada del shader de origen, aunque sea CC0).
- **No se toca:** `godot/`, `blender/`, `pruebas/capturas/ac0/proto/`, las hojas `ab_*`, `ac3/celdas/`, `pruebas/godot/estilo/` y el resto de fichas.
- **Sin commit.** Habrá uno solo cuando terminen esta línea y la del shader, y lo hace el responsable.

## 5. Diseño

### 5.1 Medidas de partida (2026-11-22)

**Origen:** `ac3/datos/nueva/cuerpo.glb` con las 4 formas de la cara anime a 1, leído sin modificar.

| Dato | Valor |
| --- | --- |
| Lazo en el `.glb` | 42 vértices, sin duplicados; coincide con `capas_nueva.json` a 0,0008 mm |
| Bolsa | 342 vértices interiores + lazo; 412 vértices del `.glb` por costuras |
| Triángulos con los 3 vértices en la bolsa | 730: **724 de la bolsa y 6 de piel** |
| Invertidos en la proyección XY | 0 en los 724; los 6 de piel, invertidos |
| Arco superior, lado izquierdo | índices `23 → 0` (interior → exterior), 24 puntos, 37,38 mm |
| Arco superior, lado derecho | índices `19 → 41, 0`; `rim_r[i]` = reflejo de `rim_l[(42 − i) % 42]`, 0,000 mm |
| Forma nueva (`medidas.md`) | **74 cruces visibles** en reposo; en los 10 extremos, 64–98 cruces y hasta 10 invertidos. Aquí no se arreglan |

- **Las esquinas se fijan por índice en reposo.** Buscarlas por «x máxima» falla: en los extremos saltan a otros índices (exterior 41/0/1, interior 23–25).
- **El reposo del `.glb` no es el ojo anime:** la bolsa solo es un cuenco de 3 mm con `cuenca_plana` a 1. Todas las coordenadas se calculan en ese estado.

### 5.2 Cómo se lleva el iris a la malla

1. Con el preset anime y los 5 deslizadores de Ojos a 0,5, localizar el lazo en el `.glb` por posición.
2. Elegir los triángulos de la bolsa **por contigüidad**: desde un triángulo central, sin cruzar las aristas del lazo. `BodyDerived.subset` no vale aquí porque elige por vértices y se llevaría los 6 de piel.
3. Crear una malla por ojo con esos triángulos y sus **mismos vértices, huesos, pesos y formas**. Así el iris sigue a las formas y al esqueleto sin datos nuevos.
4. Guardar en la UV de esa malla la posición del vértice en ese estado, relativa al centro del lazo: `uv = (x − cx, y − cy)`, en metros. **La `uv.x` no se refleja:** apunta a +X en los dos ojos, y por eso los brillos caen en el mismo lado.
5. Dibujar por capas (D46), con **la misma malla en 3 instancias** y un solo shader con `layer`: 0 blanco (opaco), 1 iris y pupila, 2 brillos. Cada una con su `depth_pull` (0,05, 0,10 y 0,12 mm) y `render_priority`.
6. Cada capa se cuelga con `BodyPiece.hang` y sigue al cuerpo con `BodyPiece.follow` tras cada cambio de valores.

Como la UV queda fija en el vértice, el iris se estira con la abertura en los extremos. Es el comportamiento buscado para «seguir al párpado» y la fila de extremos lo enseña.

### 5.3 Iris

**Shader de origen:** «Anime Style Eyes (Procedural Eye Shader)», de ProfesorShader. **Licencia: CC0 1.0, comprobada el 2026-11-22** en `https://godotshaders.com/shader/anime-style-eyes-procedural-anime-eye-shader/` (publicado el 7 jun 2026, actualizado el 6 nov 2026). Etiqueta «CC0 license», enlazada a `creativecommons.org/publicdomain/zero/1.0`. Texto de la página: «The shader code and all code snippets in this post are under CC0 license and can be used freely without the author's permission. Images and videos, and assets depicted in those, do not fall under this license.» Solo se usa el código; las imágenes de la página no.

Adaptación:

- Pupila con `smoothstep`, de color `iris × 0,35`.
- `iris_cover` en lugar de la sombra libre.
- Brillos de como mucho el 12 % del radio del iris.
- Media luna inferior.
- Iris escalado en vertical.
- Fuera: animación de brillos y contorno negro.

**`iris_cover` (c):** fracción de la altura del iris tapada por el párpado.

```text
y_b = borde inferior del lazo en el eje del iris + 0,6 mm      (fijo)
y_L = borde superior del lazo − 0,7 · w(u del eje)             (borde de abajo de la línea)
H   = (y_L − y_b) / (1 − c)                                    (altura del iris)
b   = H / 2;  centro = y_b + b;  a = 6,5 mm                    (semiejes)
```

- El borde inferior y el ancho no cambian: el iris **crece hacia arriba por debajo de la línea**. **`w(u)` no depende de c.**
- La pupila se centra en el **iris entero**: en la altura visible `s = (y − y_b) / (y_L − y_b)` queda en `s_p = 0,5 / (1 − c)` (0,63; 0,71 y 0,83 con c de 20, 30 y 40 %). Así c cambia la mirada.
- El tono saturado y el claro van en coordenadas del iris entero. La sombra casi negra de arriba va en `s`, pegada a la línea.
- Color: arriba casi negro (`iris × 0,12`), en medio saturado, abajo claro con la media luna.
- Pupila: centrada en `s_p`, pequeña y difusa.
- Brillos: uno en `s ≈ 0,72`, en el lado de la luz, y un punto mínimo en `s ≈ 0,16`. El lado sale de la luz real: `signf(light.global_basis.z.x)` (+1 con `LIGHT_ANGLES`).

Los números son **valores de partida**, no límites. Se ajustan a lo que traiga el shader de origen y la tabla da los usados.

### 5.4 Blanco

Capa 0 sobre la bolsa (decisión del AC.3), con una sombra suave en su tercio de arriba.

### 5.5 Luz

- Blanco, iris, brillos, línea y pliegue **copian `light()` de `toon_suave`** con sus `render_mode`. No se parte de `ojo_capas.gdshader`, que es `unshaded`.
- **Sin `EMISSION`:** el rim de `toon_suave` la usa y haría brillar el ojo a oscuras.
- **Normal única por ojo:** la media de las normales de estilo del lazo, también en las formas. Las de la bolsa darían bandas de sombra dentro del cuenco.
- **Pendiente declarado:** `toon_suave` lleva `ambient_light_disabled` hasta el SH.3. No se añade ambiente propio; la respuesta a la luz ambiente queda **sin comprobar** hasta entonces.

### 5.6 Línea del párpado y pliegue

**Tira de malla** generada desde el arco superior (§5.1), con 24 columnas más 3 de cola:

- **Vértices:** `lazo[i] + n[i] · fila`, con `n[i]` perpendicular al lazo sobre la cara, calculado en el estado anime de §5.2 (el reposo del `.glb` tiene otra abertura: 8,7 mm de alto frente a 16). Cada vértice copia huesos, pesos y formas de su vértice del lazo, así que sigue a todas las formas sin datos nuevos.
- **UV:** `u` por longitud de arco, de 0 (interior) a 1 (esquina exterior) **en los dos ojos**; la cola, para las pestañas, llega a `u ≈ 1,08` (3 mm). `v` va a lo ancho.
- **Filas:** de 1,6 mm hacia dentro a 2,8 mm hacia fuera. La del centro cae sobre el lazo y es la que se mide.
- **Filas de fuera y cola, apoyadas en la piel (decisión del coordinador, 2026-11-22):** en el estado anime, cada vértice se proyecta desde fuera sobre la **primera superficie visible** de la piel y guarda su triángulo y sus coordenadas baricéntricas. Su posición, sus formas y sus pesos (los 4 mayores, normalizados a 1) se interpolan de esos 3 vértices, y se eleva 0,12 mm por la normal. El pliegue usa el mismo método.

Shader `ojo_linea.gdshader`, con transparencia y `depth_pull` de 0,18 mm:

- Color burdeos muy oscuro, aprox. (0,18; 0,07; 0,08).
- Grosor `w(u)`: de 0,20 mm en el interior a 1,50 mm hacia `u = 0,80`, repartido 70 % hacia dentro y 30 % hacia fuera. **Se apaga** en `u < 0,12`.
- 3 pestañas cortas en punta en la esquina exterior (`u` de 0,92 a 1,08).
- Casi recta y algo caída hacia fuera: sale de la forma del lazo. **No se cambia la malla para conseguirlo;** si no se lee así, lo dice la hoja.

**Pliegue:** otra tira con el mismo método, a 2,2 mm por encima del lazo, de 0,18 mm y opacidad 0,35.

**Línea inferior negra (decisión del responsable, 2026-11-22, al ver el ojo):** sustituye a «abajo sin línea oscura». Tira propia desde el arco inferior del lazo (izquierdo `23 → 41, 0`; derecho `19 → 0`), casi negra, más fina que la superior, que se apaga hacia la esquina interior y se une a la superior en la exterior.

### 5.7 Rubor provisional

En `piel_rubor.gdshader`, **copia** de `toon_suave` (el original no se toca). Máscara elíptica suave bajo el lazo inferior de cada ojo, con la posición de mundo del fragmento y centros actualizados en cada estado. Color calculado desde la piel (`piel × (1,0; 0,72; 0,74)`) para que valga en piel clara y oscura. **El definitivo es del SH.8.**

### 5.8 La hoja

Mismas cámaras y piel que `ab_aspecto.png`, con iris rojo oscuro aprox. (0,55; 0,08; 0,10).

| Fila | `iris_cover` | Piel | Iris |
| --- | --- | --- | --- |
| 1 | 20 % | clara | rojo |
| 2 | 30 % | clara | rojo |
| 3 | 40 % | clara | rojo |
| 4 | 30 % | oscura | rojo |
| 5 | 30 % | clara | azul (0,12; 0,30; 0,62) |

- **Columnas:** frente, tres cuartos, perfil, primer plano del ojo y cámara de juego (`[0, 45, (0; 0,85; 0), 6]`, 1200 × 800). La de juego usa la figura de cabeza grande del AC.3 §5.7 (Cabeza ×2,5 y Altura ×0,65): con la figura normal, el ojo mide 5,5 × 3,4 px y la línea 0,3 px.
- **Fila 6:** los 10 extremos de los 5 deslizadores de Ojos, con la variante de 30 % en piel clara, en celdas de media anchura y con el encuadre de `ab_extremos.png`.
- **`medidas.md`:** por fila, `iris_cover`, altura del iris, **mm de iris tapado**, **grosor máximo de la línea**, piel y color. Además, cruces e invertidos de la forma, y la distancia máxima de §6.

### 5.9 Anotado para el X.7 (no se toca ahora)

«Anime-style face shader» de godotshaders (código MIT, mapa de sombras de la cara): candidato para la **sombra de la nariz** del X.7. No se ha abierto. La licencia de su mapa se comprobará aparte si algún día se usa: el código MIT no la cubre y los recursos deben ser CC0 o propios.

## 6. Pruebas

Dentro de `ac4a_hoja.gd`, con ventana, y con líneas `MEDIDA` / `FALLO` / `RESULTADO`:

`(ulimit -v 4000000; XDG_DATA_HOME=<scratch>/xdg/data XDG_CONFIG_HOME=<scratch>/xdg/config XDG_CACHE_HOME=<scratch>/xdg/cache timeout 280 godot --path <copia>/godot --resolution 320x240 -s <ruta>/ac4a_hoja.gd)`

| Medida | Límite (`# PROVISIONAL`) | Rotura que debe dar FALLO |
| --- | --- | --- |
| Alineación de la copia con `capas_nueva.json` | ≤ 0,6 mm (el del AC.3a) | Cargar la `c2` |
| Triángulos de la bolsa e invertidos | 724 y 0 por ojo | Elegir por vértices (730) |
| Arco del ojo derecho | Reflejo ≤ 0,001 mm | Usar los índices del izquierdo |
| Tira–lazo y capa–cuerpo con `MeshBaker.bake`, en los 10 extremos | ≤ 0,05 mm | Tira sin las formas |
| Filas exteriores de la tira respecto a la piel, en el estado anime y en los 10 extremos | Altura mínima ≥ −0,18 mm (su `depth_pull`) | Hundir 1 mm la fila exterior |
| Brillos, lado en cada ojo | Mismo signo de x | Reflejar la `uv.x` en el derecho |
| Borde inferior y `w` al cambiar c | Sin cambios | Hacer `w` dependiente de c |
| Luz apagada: canal máximo de las capas | ≤ 0,01 | Añadir `EMISSION` |

Las roturas se hacen sobre la copia y se deshacen. No se lanza la batería completa.

## 7. Trampas conocidas

1. **Rutas fijas:** `ac3a_hoja.gd` apunta a la copia de otra sesión y escribe en `ac3/celdas/`. No se reutiliza tal cual: pisaría las celdas de las hojas `ab_*`.
2. **Otra sesión edita `PLAN.md` y puede cambiar `toon_suave`:** copiar el shader al empezar y anotar su `sha256` en `medidas.md`.
3. **Tira bajo la piel (medido el 2026-11-22):** con filas rectas se hunde hasta −0,70 mm en el estado anime y −2,74 mm en los extremos; por eso las filas de fuera se apoyan en la piel (§5.6). Si aún falla, no se sube `depth_pull` ni se cambia el límite: la hoja se genera igual, con el `FALLO` en `medidas.md`, y el paso no se cierra.
4. **`inclinación` y `alto` deforman el iris**, porque la UV va con los vértices (§5.2). No se corrige aquí.
5. **Cruces de la forma:** pueden asomar en el borde del ojo. No se arreglan; se dan en la tabla.
6. **`render_priority` y transparencia:** comprobar en la hoja el orden blanco → iris → brillos → línea, también con pelo delante.
7. **`Mesh.surface_get_blend_shape_arrays`** devuelve posiciones absolutas (así lo usa `BodyDerived._shapes`): sumar a ellas el desplazamiento de la fila.

## 8. Juicio visual

Se entregan solo las rutas de `hoja.png` y `medidas.md` y la tabla de parámetros, **sin describir ni valorar**.

Preguntas al responsable:

1. ¿Qué `iris_cover` se acerca más a la mirada buscada: 20, 30 o 40 %?
2. ¿La línea, las pestañas y el pliegue se leen como un párpado?
3. ¿El método aguanta en piel oscura y con otro color de iris?
4. ¿La línea y el iris siguen bien al párpado en los extremos?

Como es un prototipo fuera del programa, no se propone el revisor-visual hasta llevarlo al núcleo, salvo que el responsable lo pida.

## 9. Si te atascas

Para y dilo si: la licencia no es CC0 o no se puede comprobar, el shader de origen no permite la adaptación de §5.3, la tira no sigue al lazo dentro del límite, las capas brillan a oscuras, o haría falta tocar `godot/`, `blender/` o la forma. No se relaja ningún límite ni se arreglan aquí los cruces.
