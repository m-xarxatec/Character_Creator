# AC.0 — Hoja de dirección visual de los ojos

> Ficha del 2026-11-22 (nivel: fuerte). **Aprobada por el responsable el 2026-11-22, con la línea del párpado de §5.3 y la vista de juego de §5.5.** Sin commit: lo pedirá junto con la otra sesión.
> Metas: D46 (ojos por capas) y D47–D48 (shader anime) de `ruta/DECISIONES.md`.
> **Cerrada el 2026-11-22: elegida c2** (§10). Hojas en `pruebas/capturas/ac0/`. Diferencias con el diseño: c1 lleva una bolsa de 9,32 mm (el globo no cabe en 3 mm) y las capas de b) y c) se recortan por el borde real del párpado.

## 1. Objetivo y «Hecho cuando»

Comparar tres formas de montar el ojo sobre la piel elegida en SH.1, para que el responsable elija antes de tocar el programa.

Hecho cuando:

- Existen las 3 hojas y `medidas.md` de §5.5 en `pruebas/capturas/ac0/`.
- Cada variante tiene sus medidas de los extremos y su nota de parpadeo.
- `sha256` de `godot/datos/humana/cuerpo.glb` y de todos los `.glb` de `godot/packs/` iguales antes y después.
- La prueba de §6 da `RESULTADO: TODO BIEN`.

## 2. Nivel de modelo

Fuerte: geometría 3D de la cara y shader. Opus 5.5 en high.

## 3. Contexto mínimo

`blender/cara_anime.py` (`STEPS`, `relax`, `deform`), `blender/exportar_datos.py` (`raw_body`, `face_shapes`), `blender/cara_anime_zonas.json`, `pruebas/godot/capturar_hoja_shader.gd` (columna `anime`, `ROWS`), `pruebas/godot/estilo/toon_suave.gdshader`, `pruebas/godot/estilo/contorno_tenido.gdshader`.

## 4. Archivos

- **Se hace todo en una copia temporal** de la sesión: scripts, datos candidatos y `cuerpo.glb` de prueba.
- **Único resultado dentro del repositorio:** las hojas y `medidas.md` en `pruebas/capturas/ac0/` (git la ignora), porque `/tmp` se borra.
- **No se toca:** `godot/`, `blender/`, `cuerpo.glb`, los packs ni ninguna prueba. El límite del pack MakeHuman solo se mide si el responsable elige b) o c).

## 5. Diseño

### 5.1 Medidas de partida (copiadas de la consulta del 2026-11-22)

**Origen:** Blender 5.2.2 y MPFB 2.0.18, sobre `~/.config/blender/5.2/extensions/blender_org/mpfb/data/3dobjs/base.obj` (hm08) y una copia de nuestro proceso tras el 9.2a. Ojo izquierdo (la malla es simétrica).
**Método:** rayos de frente cada 0,25 mm. El borde de los párpados son los 43 vértices de piel junto a las celdas donde se ve el globo `helper-l-eye`. El área sale del contorno de esos vértices, así que es aproximada. La bolsa es cuánto más atrás del borde queda la primera piel vista de frente.

| Estado | Ancho (mm) | Alto (mm) | Área (mm²) | Hueco central (mm) | Bolsa, mediana / máx. (mm) |
| --- | --- | --- | --- | --- | --- |
| hm08 original | 23,55 | 9,85 | 162,7 | 9,04 | 28,17 / 29,11 |
| Cuerpo neutro, sin cara anime | 22,11 | 8,66 | 136,2 | 7,88 | 27,75 / 28,52 |
| Con `cuenca_plana` (igual con toda la cara anime) | 4,61 | 4,99 | 14,0 | 3,19 | 0,17 / 1,38 |

Globo visible por rayos: 23,0 × 8,75 mm (153,6 mm²) en hm08 y 22,0 × 7,75 mm (131,1 mm²) en el neutro. Con `cuenca_plana` da 15,75 × 15,75 mm, pero **no es abertura**: el globo atraviesa la piel aplanada.

**Caras y topología:**

| Malla | Vértices | Caras | Aristas | De borde | No variedad | Piezas |
| --- | --- | --- | --- | --- | --- | --- |
| `base.obj` completo | 19.158 | 18.486 | | | | 139 grupos |
| Grupo `body` | 13.380 | 13.378 | 26.756 | 0 | 0 | 1 |
| Nuestra malla (`build_base`) | 13.380 | 13.378 (las mismas) | 26.756 | 0 | 0 | 1 |
| `cuerpo.glb` | 14.517 (13.380 soldados) | 26.756 triángulos | 40.134 | 0 | 0 | |

**Conclusión:** hm08 trae la abertura. La piel no tiene borde porque los párpados se doblan hacia dentro y forman una bolsa. `clean_mesh` solo borra los helpers (`blender/limpiar_malla.py:33`). Lo que aplasta la abertura es `cuenca_plana` (`blender/cara_anime.py:36`): relaja la zona `eyes` (1.352 vértices) hasta una membrana.

- `cuenca_plana` mueve 1.525 vértices, hasta 28,85 mm; junto al globo, 518 vértices (mediana 13,26 mm). El borde se desplaza hasta 10,99 mm.
- hm08 ya trae, por ojo: globo `helper-l-eye` (70 caras, 29,02 mm de ancho), pestañas `helper-l-eyelashes-1` y `-2` (44 + 48 caras) y los puntos `joint-l-eye` y `joint-l-eye-target`.

**Extremos de los targets** (izquierdo, sobre el borde de los párpados, en mm):

| Target | Borde, máx. | Hacia dentro | Hacia fuera | Globo |
| --- | --- | --- | --- | --- |
| `eye-scale-decr` | 3,44 | 0,5 | 2,8 | 0 |
| `eye-scale-incr` | 2,15 | 0,7 | 0,5 | 0 |
| `eye-trans-in` | 3,40 | 0 | 0 | 3,4 |
| `eye-trans-out` | 4,60 | 0 | 0 | 4,6 |
| `eye-height2-decr` | 1,00 | 0 | 0 | 0 |
| `eye-height2-incr` | 2,00 | 0 | 0 | 0 |

Los tres deslizadores a la vez: 0,7 mm hacia dentro y 2,8 mm hacia fuera. De los 56 targets del 9.2, solo los 8 `eye-trans-*` mueven el globo. El frente del globo queda 1,99 mm por delante del borde.

### 5.2 Piel de la hoja

Columna anime de SH.1: `softness` 0,09; `threshold` 0,05; `ground_weight` 0,025; `rim_strength` 0,075; `shade_tint` (0,92; 0,72; 0,72); sombra proyectada activa; contorno teñido × (0,45; 0,30; 0,30) de 1,25 px.
Tonos: clara (0,96; 0,80; 0,70), media (0,72; 0,50; 0,36) y oscura (0,30; 0,19; 0,14).

### 5.3 Las 7 variantes

| Id | Cara | Superficie del ojo |
| --- | --- | --- |
| `a` | Capas sobre la piel aplastada (`cuenca_plana` actual) | Capas finas |
| `b1`, `b2`, `b3` | Cuenca humana: sin aplastar párpados ni bolsa | Globo de hm08, casi plana (flecha 0,2 mm), algo cóncava (0,8 mm) |
| `c1`, `c2`, `c3` | Punto medio anime | Las mismas tres |

1. **Separar la bolsa.** Partiendo del borde (§5.1), buscar el lazo de aristas cerrado que lo contiene. La bolsa es la parte de la zona `eyes` que queda dentro de ese lazo.
2. **b)** Repetir el paso `cuenca_plana` de `relax` con el lazo y la bolsa fijos: se aplana la cara alrededor y el ojo conserva su forma humana.
3. **c)** Sobre b), una forma nueva lleva el lazo a una elipse de **26 × 16 mm** centrada en el ojo (valor inicial, unas 2,4 veces el área neutra) y deja la bolsa a **3 mm** (§5.4). La piel de alrededor se relaja con el lazo fijo.
4. **Capas:** blanco, iris con pupila y brillo como mallas propias detrás del borde. Iris, pupila y brillos salen del shader, sin imágenes externas.
5. **Línea provisional del párpado superior:** una malla mínima, oscura y gruesa, con el mismo grosor y color en las 7 variantes, para que la comparación sea justa. No es la definitiva (AC.6).

### 5.4 Profundidad mínima de la bolsa en c): propuesta, 3 mm

| Capa, de delante a atrás | Detrás del borde (mm) | Por qué |
| --- | --- | --- |
| Holgura del párpado | 0 a 1,00 | Medido: el borde entra 0,7 mm; + 0,3 de margen |
| Brillo | 1,00 | |
| Iris, en su borde | 1,25 | Separación de 0,25 mm |
| Iris, en su fondo | 2,05 | Con la flecha cóncava de 0,8 mm |
| Blanco | 2,30 | |
| Fondo de la bolsa | 2,55 → **3,00** | Redondeado |

Con 0,25 mm entre capas, un búfer de profundidad de 24 bits y `near` 0,05 m no deberían parpadear hasta unos 14 m (cálculo `d² / (near · 2²⁴)`, **sin medir**).

### 5.5 Qué se genera

- `aspecto.png`: 7 variantes en piel clara (0,96; 0,80; 0,70) × frente, tres cuartos, perfil y cámara de juego (desde arriba, a unos 45°, a distancia de juego, como en la prueba de estilo 3.12).
- `extremos.png`: 7 variantes × los 6 extremos de §5.1, en tono medio, de frente y tres cuartos.
- `cuenca.png`: primer plano de las 7 variantes en los 3 tonos, para ver sombras feas en la cuenca.
- `medidas.md`, por variante y extremo: triángulos invertidos visibles y cruces visibles (criterio de `9.2_deslizadores_cara.md` §5.6), distancia entre el centro de la abertura y el del iris, y holgura mínima entre el borde y la primera capa.

### 5.6 Nota de parpadeo por variante (a confirmar con la hoja)

- **a)** Sin abertura real: cambio de capa o textura.
- **b)** Forma de malla: MPFB trae `eye-left-closure` y `eye-right-closure` en `targets/expression/units/{african,asian,caucasian}/`. Su licencia está sin comprobar (D41).
- **c)** Esos targets están hechos para una abertura de unos 9 mm: con 16 mm haría falta un cierre propio.

## 6. Prueba

El script de la hoja acaba en `RESULTADO: TODO BIEN` si: las variantes b) y c) conservan 13.380 vértices y 13.378 caras; las 7 variantes dan imágenes distintas entre sí; salen todos los archivos de §5.5; y los `sha256` del repositorio no cambian.
**Detecta el fallo:** hacer que c) use la forma de b) debe dar «c igual a b».

## 7. Trampas conocidas

1. **Sombra provisional:** `shade_tint` fijo se usa porque es lo elegido en SH.1, pero D48 lo sustituye en SH.2 por un color calculado. El color de sombra de la hoja puede cambiar después.
2. **Lazo del borde:** los 43 vértices salen de rayos y pueden no formar un lazo cerrado. Si la bolsa «se escapa» por un hueco, para y dilo.
3. **Forma de cara ya aprobada:** b) y c) cambian `cuenca_plana`, que aprobaste con los deslizadores del 9.2. Las medidas de §5.1 de los extremos son de hm08 neutro: la hoja mide las reales.
4. **Globo:** con `eye-scale` y `eye-height2` no se mueve, solo cambian los párpados.
5. **Piezas:** 31 de 48 llevan `cuenca_plana`. En la copia no se regeneran, así que la hoja va sin pelo ni ropa.

## 8. Juicio visual

Se dan solo las rutas de `pruebas/capturas/ac0/`. Preguntas: ¿qué forma de montar el ojo y qué superficie? ¿Se ven sombras feas en la cuenca? ¿La abertura de c) tiene el tamaño que buscas?

## 9. Si te atascas

Si el lazo no cierra, una variante cambia el número de vértices o de caras, o el `sha256` de un archivo del repositorio cambia: para y dilo. No se recorta la hoja para que salga.

## 10. Elección del responsable (2026-11-22)

**Elegida c2:** punto medio anime con superficie casi plana, bolsa de 3 mm y abertura de 26 × 16 mm.

| Descartada | Motivo |
| --- | --- |
| a) Capas sobre la piel aplastada | No sigue a los párpados, 216–318 invertidos en los extremos y sin parpadeo con malla |
| b) Cuenca humana | Tamaño humano: no llega a la meta anime |
| c1) Con el globo de hm08 | Bolsa de 9,32 mm y aro de perfil |
| c3) Algo cóncava | Igual que c2, pero más compleja |

**Pendiente para el AC.3:** en los extremos, c2 da 4–90 invertidos y 130–296 cruces, y el fondo de la bolsa atraviesa el blanco (holgura de hasta −1,50 mm).
**Corrección de la hoja (2026-11-22):** sus cruces son los nuevos respecto al reposo. En reposo, las caras ya tienen estos pares cruzados: a) 0, b) 66, c2 y c3 376 (284 triángulos visibles) y c1 360. Medido después de elegir; detalle en `pruebas/capturas/ac0/medidas.md`.
**Prototipo y datos candidatos:** `pruebas/capturas/ac0/proto/` (git lo ignora; instrucciones en su `LEEME.md`).
