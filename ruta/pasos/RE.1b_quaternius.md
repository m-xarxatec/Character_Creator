# RE.1b — Los 5 peinados gratis de Quaternius en un pack propio

> Ficha del 2026-11-21 (Sonnet 5.5, solo lectura; nada implementado). Decisión: D44 de `ruta/DECISIONES.md`. Candidatos: `recursos_externos/candidatos/candidatos.md` §1b y §6 (Q01-Q05).
> Referencia de estilo (para después del MVP): `diseno/referencia_estilo_quaternius.png`.
> Licencia comprobada en el archivo: `recursos_externos/QU01_quaternius_ubc/extraido/Universal Base Characters[Standard]/License_Standard.txt` dice «CC0 1.0 Universal (CC0 1.0) Public Domain Dedication» (y «Models by @Quaternius»). La página de itch.io y la de quaternius.com dicen lo mismo (según `candidatos.md`; no se volvió a mirar sin red). Zip original: sha256 `fdbf1804c90dfc1ea03e992bff7da2dfd1a79318e13270a660180f9308455f40`.

## 1. Objetivo y «Hecho cuando»

Los 5 peinados (Q01 `Hair_Buns` moños, Q02 `Hair_Long` largo, Q03 `Hair_BuzzedFemale` rapado F, Q04 `Hair_Buzzed` rapado M, Q05 `Hair_SimpleParted` raya al lado; sin barba Q06 ni cejas Q07/Q08) como piezas que siguen al cuerpo en `godot/packs/quaternius/`, con el shader actual del MVP (sombra de 3 tonos y contorno negro, sin cambiarlo).
Hecho cuando: los 5 se ponen desde la pestaña Pelo, encajan en la cabeza neutra (medidas del §4), siguen a Cabeza › Tamaño (×0,8 a ×2,5), Cabeza › Ancho/Alto, Complexión, Largo del torso y Largo del cuello sin quedar flotando ni hundidos, el `.glb` exportado los lleva, y el pack pasa `probar_packs` y `probar_piezas`. El responsable aprueba las capturas.

## 2. Nivel de modelo

Fuerte: pipeline de Blender (`blender/`), pesos y formas. Un modelo medio solo para el subpaso b (pack, créditos y pruebas) si el a ya está aprobado.

## 3. Archivos

- **Nuevos:** `blender/exportar_quaternius.py` (GPL-3.0+ como el resto de `blender/`; importa lo que pueda de `exportar_mhclo.py` en vez de copiarlo), `godot/packs/quaternius/` (5 `.glb`, sus `.import` y `pack.json`).
- **Por tocar:** `CREDITOS.md` y su copia `godot/CREDITOS.txt` (fila «Quaternius, Universal Base Characters (Standard)»: autor, CC0 1.0, `License_Standard.txt`, dónde se usa; citar también la imagen de referencia `diseno/referencia_estilo_quaternius.png`, que muestra material CC0 de Quaternius), `propuestas/recursos_3d.csv` (estado Q01-Q05), `pruebas/godot/probar_packs.gd` y `probar_piezas.gd`.
- **No se tocan:** `godot/addons/creador/` (ni `toon.gdshader`, ni `body_material.gd`, ni `pack_library.gd`), `godot/app/`, `CLAUDE.md`, `PLAN.md` salvo cerrar el paso.
- **Subpasos (son más de 3 archivos):** a) script + un peinado (Q04, el más pequeño) hasta pasar su prueba y juicio visual; b) los otros 4, `pack.json`, créditos y pruebas.

## 4. Medido (2026-11-21, solo lectura; scripts en el scratchpad, nada en el proyecto)

**Qué archivos usar:** `Hairstyles/Origin at 0/glTF (Godot)/Hair_*.gltf` (sin esqueleto; ya sobre la cabeza del Superhero). Los «Rigged to Head Bone» traen 65 huesos con nombres de Unreal; `BodyPiece.attach` devuelve null si un hueso del skin no existe en nuestro esqueleto, así que no sirven tal cual. Buns y BuzzedFemale traen nodo con giro de 90° y escala 0,01 (centímetros); los otros 3 ya están en metros. El importador de Blender lo aplica.

| ID | Archivo | Vértices (triángulos) | Con esqueleto de Quaternius | Aristas de borde |
| --- | --- | --- | --- | --- |
| Q01 | `Hair_Buns` | 3502 (3284) | 3501; 100 % al hueso `Head` | 1,9 % |
| Q02 | `Hair_Long` | 3080 (2906) | 3080; 100 % `Head` | 2,8 % |
| Q03 | `Hair_BuzzedFemale` | 466 (830) | 466; 100 % `Head` | 7,7 % |
| Q04 | `Hair_Buzzed` | 466 (830) | 466; 100 % `Head` | 7,7 % |
| Q05 | `Hair_SimpleParted` | 757 (1301) | 757; 100 % `Head` | 4,4 % |

Total 8271 vértices. Cada uno: 1 capa UV, normales, una sola influencia (`Head`, peso 1,0), sin formas, sin colores por vértice. Casi todo son cáscaras cerradas (pocas aristas de borde); Buns tiene casi el doble de vértices que posiciones distintas (1699 soldadas de 3502: costuras de UV y aristas duras). **¿Se pueden pesar a nuestro `Head`?** Sí: el hueso se llama igual y existe en nuestro esqueleto. Pero ver «Pesos» en el §5: con la cabeza a ×2,5 los largos (Buns y Long) no deben ir 100 % al `Head`.

**Encaje con nuestra cabeza** (`godot/datos/humana/cuerpo.glb`, neutro; ejes de Blender: Z arriba, frente −Y; hueso `Head` nuestro en (0; −0,044; 1,5146), cabeza hasta z = 1,6594; la base de `gc.create_body` da el mismo hueso, comprobado):

- Su cabeza es mayor: ancho de cabeza 0,1778 m (F) y 0,1813 m (M) frente a 0,167 m la nuestra (0,938 de factor en el ancho). Su Superhero F mide 1,7666 m de cabeza arriba y el nuestro 1,6594 m. Su hueso `Head` está en z = 1,5496 (F) y 1,5998 (M); el nuestro en 1,5146.
- Ajuste lineal buscado con una optimización por Nelder-Mead sobre 500 vértices (sin ayuda de la superficie exacta: error de ±1 mm esperable). Fórmula: `v' = (v − Head_Quaternius) · s + Head_nuestro + (0, dy, dz)`, con `Head_Quaternius` = (0; 0,0109; 1,5496) en F y (0; 0,0174; 1,5998) en M:

| Peinado | s uniforme | dy (m) | dz (m) | Error del hueco, RMS (mm) |
| --- | --- | --- | --- | --- |
| Buns (F) | 0,938 | −0,003 | −0,060 | 1,9 |
| Long (F) | 0,953 | −0,003 | −0,064 | 2,1 |
| BuzzedFemale (F) | 0,936 | −0,003 | −0,059 | 1,9 |
| Buzzed (M) | 0,945 | +0,008 | −0,055 | 2,2 |
| SimpleParted (M) | 0,959 | +0,008 | −0,058 | 1,6 |

  Escala por eje (3 factores) no mejora de forma clara (RMS entre 1,8 y 2,3 mm): basta la escala uniforme, ≈ 0,94-0,96. Sin escala (solo mover hueso con hueso) el hueco mediano al cuero cabelludo sale de 28 a 56 mm: **hay que escalar y bajar unos 6 cm**.
- Tras el ajuste, el hueco mediano al cuero cabelludo es 2-9 mm (el original sobre su Superhero: 2-9 mm). Vértices por debajo de la piel (más de 1 mm), sobre 500 de muestra: Buns 5,2 % (original 6,2 %), Long 5,4 % (5,4 %), BuzzedFemale 23,6 % (21,5 %), Buzzed 24,9 % (21,9 %), SimpleParted 14,4 % (13,0 %); todos con la escala uniforme. Es parecido a los originales (la capa interior de la cáscara queda bajo la piel); el máximo hundido llega a 12 mm (rapados), 14-17 mm (SimpleParted, Buns) y 26 mm (Long, mechones sobre cuello y hombros). **No medido:** si lo que se hunde es solo la capa interior o también la visible; lo dirá el juicio visual.
- Caja del pelo ya ajustado: techo entre 1,662 y 1,683 m (cabeza: 1,6594): los rapados quedan a 2-3 mm sobre la cabeza y SimpleParted a 2,4 cm.

**Cómo los siguen los deslizadores (leído en el código; no probado en Godot):**

- `Proportions.apply` pone la escala del hueso en la pose: Cabeza › Tamaño (`escala:Head=0,8 … 2,5`) escala todo lo pesado al `Head` desde el punto del hueso (1,5146 m); un peinado con peso 1,0 al `Head` crece igual que el cráneo (3901 de los 4231 vértices de cabeza pesan ≥ 0,99 al `Head`).
- Las formas **sí hacen falta**: `SkeletonRefit.apply` pone la bind pose de cada hueso en su sitio nuevo y la pose igual al reposo; así la malla deja de moverse por el hueso y solo la mueven las formas. Un peinado solo pesado al `Head`, sin formas, **se quedaría quieto** cuando la forma mueve la cabeza. Medido sobre nuestro cuerpo: de 286 formas, 42 mueven los vértices de la cabeza ≥ 0,1 mm y 28 ≥ 5 mm; la cabeza entera se desplaza 78 mm con `torso_length_incr`, 64 mm de media con `gender` (máx. 73), 47 mm con `torso_length_decr`, 30 mm con `neck_length`; `head_height` mueve hasta 23 mm y `head_width` hasta 17 mm. Es lo que ya hace `exportar_mhclo.py` (MH short02: 40 formas).
- `BodyPiece.follow` copia a la pieza los pesos de forma **por nombre** (las que no tiene, las ignora) y las bind poses del cuerpo; `BodyPiece.attach` exige una sola malla con piel y huesos que existan.
- Con Cabeza ×2,5 un mechón que quede 12 cm por debajo del hueso (Long baja hasta z ≈ 1,394 y Buns hasta 1,426 tras el ajuste; el hueso está en 1,5146) se iría a ~30 cm: se metería en hombros y torso. Los 3 cortos quedan en 1,49-1,52, casi en el hueso.

**Materiales y texturas (lo que traen de verdad):**

| Material | Peinados | Textura de color | Normales | Metálico / rugosidad | Otros |
| --- | --- | --- | --- | --- | --- |
| `MI_Hair_1` | Buzzed, BuzzedFemale, SimpleParted (y Beard) | `T_Hair_1_BaseColor.png`: 2048×2048, RGB 8 bits, 1 570 376 B | `T_Hair_1_Normal.png`: 2048×2048, RGBA, 4 326 126 B (alfa 255 fijo) | 0 / sin valor (el 1,0 de glTF) | doble cara, opaco (sin `alphaMode`), sin emisivo |
| `MI_Hair_2` | Buns, Long | `T_Hair_2_BaseColor.png`: 2048×2048, RGB, 1 729 467 B | `T_Hair_2_Normal.png`: 2048×2048, RGBA, 4 710 013 B | 0 / 0,712 | ídem |

La textura de color es casi gris: media RGB (143, 144, 141) y (141, 141, 138), saturación media 0,03-0,04, valor medio 0,56, desviación 14-17 sobre 255: sirve para teñir y da un matiz suave de mechones. No hay transparencia en la textura.

**¿Puede el shader actual usarlas sin modificarse? No.** `toon.gdshader` no tiene ningún `sampler2D` (el color sale de `skin_color`/`garment_color`), `BodyMaterial.apply` pone `material_override` y descarta el material del `.glb`, y fija `ROUGHNESS = 1`, `SPECULAR = 0` (los valores PBR de Quaternius no cuentan) y no usa mapas de normales. Por la decisión D44 el shader del MVP no se toca: **en el MVP los peinados salen en color plano** (el de `pack.json`, editable con el selector de color), con la forma esculpida y la sombra de 3 tonos; se pierde el matiz de mechones de la textura. Las 4 PNG (12,3 MB) **no entran** en `godot/` (los `.glb` pesarían más y Godot las importaría como texturas de 2048²); quedan en `recursos_externos/`.

## 5. Diseño

1. **Entrada:** los 5 `Origin at 0/glTF (Godot)/Hair_*.gltf`, leídos en Blender con `--disable-autoexec` (datos no fiables: no se ejecuta nada de ellos). Fase: pose A, como `cuerpo.glb`.
2. **Colocar:** `v' = (v − Head_Quaternius)·s + Head_nuestro + (0, dy, dz)` con la tabla del §4 (constantes dentro del script, con el motivo). Reajustar al implementar con la malla real, no solo con la muestra de 500 vértices. Si en las capturas la piel asoma por debajo del pelo, plan B: empujar a lo largo de la normal de la piel los vértices que queden más de 1 mm por debajo; no se hace de entrada (puede aplastar la cáscara).
3. **Ligar a la piel:** para cada vértice del peinado, el triángulo más cercano de la piel de la malla base (solo los 13 380 vértices de piel, no los helpers), con sus coordenadas baricéntricas. Misma posición → mismo ligado (las costuras de UV no se abren).
4. **Pesos:** baricéntricos de los pesos del cuerpo (como los «pesos interpolados del cuerpo» de `exportar_mhclo.py`), `limit_weights` (máx. 4) y suma 1; así lo largo de Buns y Long baja con cuello y hombros al escalar la cabeza. Motivo: con 100 % `Head` se hunden al ×2,5 (§4). Los 3 cortos salen casi todo `Head` por sí mismos.
5. **Formas:** mismos nombres que `cuerpo.glb`. Para cada forma de `ed.target_names`, el desplazamiento de cada vértice = baricéntrico de los desplazamientos de su triángulo (la distancia al triángulo se mantiene). Se quitan las que mueven menos de 0,1 mm (`MIN_DELTA`). Sin normales de forma (la mitad de tamaño). Los desplazamientos de todos los vértices salen de `eh.measure` / `full_deltas` de `exportar_mhclo.py` (importarlos, no copiarlos).
6. **Material y UV:** sin materiales ni texturas (el color lo pone el programa). Se intenta conservar la capa UV (≈ 66 KB en total) por si la ampliación necesita texturas; **no comprobado** si `export_glb(..., deform_only=True)` la deja pasar: si no, se exporta sin UV y se anota.
7. **Exportar** con `export_glb(clothes, [], out, morph=True, deform_only=True, morph_normals=False)` y `ed.write_full_names` como en `exportar_mhclo.py`; cada `.glb` con su `.import` (`eh.KEEP_IMPORT`); `pack.json` con `"id": "quaternius"`, `"nombre": "Pack Quaternius"`, `"autor": "Quaternius"`, `"licencia": "CC0-1.0"`, `"origen": "https://quaternius.com/packs/universalbasecharacters.html"` (la URL viene de `candidatos.md`; no se pudo comprobar sin red). Ranura `pelo`, tipo `pelo`, `sigue_al_cuerpo: true`, `especies: ["humana"]`, `colores: ["principal"]`, `color: [0.24, 0.16, 0.12]` (el de los demás peinados), `sha256` de cada archivo.
8. **Piezas** (ids y nombres en minúsculas): `hair_buns` «Moños», `hair_long` «Pelo largo», `hair_buzzed_female` «Rapado (F)», `hair_buzzed` «Rapado (M)», `hair_simple_parted` «Raya al lado».
9. **Peso del pack, estimado** (no medido): 8271 vértices × ~42-60 formas × ~10 B (la medida de RE.1a: 0,69 MB para 1755 vértices × 40 formas) ≈ 3,4-5 MB, más ~0,5 MB de base. Los largos pesan la mayor parte. Si hay más formas de las 42 de la cabeza (Long baja al cuello y hombros), el peso sube.

## 6. Pruebas

- **En el script (líneas `MEDIDA`):** por peinado, RMS del hueco al cuero cabelludo y % de vértices bajo la piel. Límites PROVISIONAL (regla 9: los fija el responsable con la medida real): RMS ≤ 3 mm; % bajo la piel como mucho 5 puntos por encima del original de §4; pesos con suma 1 ± 1e-4 y máximo 4 influencias. Detecta el fallo: poner `s = 1,0` en un peinado → el RMS pasa de ~2 mm a decenas.
- **`probar_packs.gd`:** el pack `quaternius` se lee sin avisos; 5 piezas, las 5 en ranura `pelo`, `CC0-1.0`, autor Quaternius, `sigue_al_cuerpo`, sha256 correcto; tamaño del pack ≤ 8 MB (PROVISIONAL, con la medida real). Detecta el fallo: poner `"licencia": "CC-BY-4.0"` en el `pack.json` → «licencia no permitida».
- **`probar_piezas.gd`:** poner cada peinado, que cuelga del esqueleto y tiene las formas `head_width_incr`, `head_height_incr`, `gender_incr`, `torso_length_incr`, `neck_length_incr`; con `torso_length` y `gender` a 1, el centro de la caja del peinado se mueve lo mismo que el de la cabeza (± 3 mm, PROVISIONAL); con Cabeza › Tamaño ×2,5 ningún vértice del peinado queda más de X mm por debajo de la piel del cuello/hombros (X por medir; PROVISIONAL); un peinado quita al anterior (misma ranura); se exporta con el cuerpo. Detecta el fallo: borrar `torso_length_incr` del `.glb` de un peinado → el centro del peinado ya no sigue a la cabeza (el caso medido de 78 mm).
- La batería sin ventana de siempre (`ruta/GUIA_MODELOS.md` §5) sigue en verde.

## 7. Riesgos

1. **Sin formas el peinado flota** (hasta 78 mm): por eso el §5.5 no es opcional. Medido en el cuerpo; el efecto en el peinado, solo leído en el código.
2. **Cabeza ×2,5 con Buns y Long:** mechones largos a ~30 cm del hueso (§4). Mitigación: pesos del cuerpo (§5.4); si no basta, solo se ofrecen los 3 cortos y se apunta el resto en `IDEAS.md`. No medido en vivo.
3. **Cara a cara con la piel:** hasta 26 mm de hundimiento en Long y 12 mm en los rapados tras el ajuste; el contorno negro y `PIECE_PULL` (5 mm) pueden dejarlo bien o mal: lo juzga el responsable (§8).
4. **Contorno y cara trasera:** los glTF son de doble cara y el shader actual dibuja solo caras delanteras; el contorno es de cáscara invertida (`cull_front`). Con 2-8 % de aristas de borde el riesgo es bajo, pero **no probado** con estas mallas.
5. **Un solo ajuste lineal por peinado** sobre una cabeza distinta (más estrecha un 6 %, más baja): puede dejar un hueco en la frente o las sienes; la escala por eje no lo arregló en la medida.
6. **Texturas perdidas en el MVP** (se ve el peinado liso; el responsable las quiere como acabado final: queda para la ampliación, ver §9).
7. **Peso del pack** (≈ 4-5 MB estimados) suma a los 44 MB del pack de MakeHuman (D12: el responsable no quiere más peso por ahora).
8. **Licencia:** CC0 comprobada en el archivo; la URL de origen y la de las páginas no se pudieron volver a abrir (sin red). La imagen `diseno/referencia_estilo_quaternius.png` es una hoja de renders con material CC0 de Quaternius; se cita en `CREDITOS.md`.

## 8. Juicio visual (lo hace el responsable)

Capturas en `pruebas/capturas/quaternius/` (frente, 3/4 y perfil, con el estilo del MVP): cada peinado en el neutro; con Cabeza › Tamaño ×0,8 y ×2,5; con Complexión 0 y 1; con Largo del torso 0 y 1; y en una animación («Atacar»). Solo se da la ruta y el comando, sin describirlas. Preguntas: ¿encajan en la cabeza?, ¿se ven bien en color plano o falta la textura?, ¿cuáles se quedan?

## 9. Después (nota; no se diseña ni se construye aquí)

El sombreado de la ampliación (meta estilo VRoid, solo inspiración; D44) cambiará el shader. Para que los peinados de Quaternius conserven su acabado haría falta entonces, como mínimo: muestrear la textura de color y teñirla con el color de la pieza (la media de la textura es 0,56: habría que normalizarla), poder usar el material del `.glb` en vez de `material_override`, cara doble, y decidir si se usa el mapa de normales; el metálico/rugosidad de Quaternius (0 / 0,712 o 1,0) no cuenta en un sombreado toon. Y copiar a `godot/` las PNG (12,3 MB en 4 archivos, a recomprimir). Después, igualar el pelo y la ropa de MakeHuman a ese acabado (textura, peso y sombra), con la hoja de referencia.

## 10. Si te atascas

Si el ajuste de una cabeza no baja de 3 mm de RMS, o los largos no aguantan el ×2,5, para y dilo: no se ajustan límites ni se añade un `if` especial (regla 9). Se puede entregar solo con los 3 cortos.
