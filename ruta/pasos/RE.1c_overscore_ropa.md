# RE.1c — Ropa de OverScore (shorts, camisetas, tirantes y sudaderas) en un pack propio

> Ficha del 2026-11-21 (Opus 5.5), con el diseño final tras **una sola revisión** pedida por el coordinador, con los mismos límites. Candidatos: `recursos_externos/candidatos/candidatos.md` §2 a §6.
> **Estado:** integradas 5 de las 13 prendas. El paso sigue en `[~]`: falta el juicio visual del responsable (`pruebas/capturas/piezas_overscore/hoja.png`).

## 1. Objetivo y «Hecho cuando»

Prendas de OverScore como piezas que siguen al cuerpo, en `godot/packs/overscore/`, con el shader actual (color plano, sombra de 3 tonos y contorno). Entran **solo** las que pasan todos los límites del §6.

Hecho cuando: las que entran se ponen desde la pestaña Ropa, respetan ranuras y `cubre`, pasan los límites en neutro, Complexión, Largo del torso, Altura y «Atacar», el `.glb` exportado las lleva, pasan `probar_packs`, `probar_piezas` y la batería, y el responsable aprueba las capturas.

| ID | Objeto en el `.blend` | `id` de pieza | Nombre | Ranura | Vértices | ¿Entra? |
| --- | --- | --- | --- | --- | --- | --- |
| OS04 | Golf Shorts | `os_golf_shorts` | Shorts de golf | `ropa_piernas` | 350 | **Sí** |
| OC02 | V-Neck Top | `os_vneck_top` | Camiseta de pico | `ropa_torso` | 342 | **Sí** |
| OC03 | Scrubs Top | `os_scrubs_top` | Casaca sanitaria | `ropa_torso` | 272 | **Sí** |
| OT01 | Tank Top | `os_tank_top` | Camiseta de tirantes | `ropa_torso` | 204 | **Sí** |
| OT02 | Camisole Top | `os_camisole_top` | Top de tirantes finos | `ropa_torso` | 158 | **Sí** |
| OS02 | Jean Shorts | `os_jean_shorts` | Shorts vaqueros | `ropa_piernas` | 144 | No: «Atacar» 6,73 % |
| OS03 | Short Shorts | `os_short_shorts` | Shorts muy cortos | `ropa_piernas` | 180 | No: hueco 2,12 mm |
| OC01 | Scallop Trim T-Shirt | `os_scallop_tshirt` | Camiseta con ribete | `ropa_torso` | 556 | No: «Atacar» 16,0 mm |
| OC04 | Sports Jersey | `os_sports_jersey` | Camiseta deportiva | `ropa_torso` | 502 | No: «Atacar» 5,08 % y 18,9 mm |
| OU01 | Hoodie with Hood Down | `os_hoodie_down` | Sudadera con capucha | `ropa_torso` | 432 | No: hueco 1,46 mm, hundida 6,19 mm, «Atacar» 19,5 mm |
| OU03 | Short-Sleeve Sweatshirt | `os_short_sleeve_sweatshirt` | Sudadera de manga corta | `ropa_torso` | 228 | No: hueco −2,22 mm, hundida 8,27 mm, «Atacar» 12,3 mm |
| OU05 | Turtleneck Sweater | `os_turtleneck_sweater` | Suéter de cuello alto | `ropa_torso` | 408 | No: hueco −4,49 mm, 3,43 % bajo la piel, «Atacar» 5,93 % y 19,9 mm; 60 cruces con pelo corto |
| OU06 | Long Sleeve Athletic Top | `os_long_sleeve_top` | Camiseta deportiva de manga larga | `ropa_torso` | 660 | No: hueco −15,93 mm, 8,18 % bajo la piel, «Atacar» 18,8 mm |

Ninguna lleva `cubre`: unos shorts y una camiseta se llevan a la vez, y los trajes de MakeHuman ya cubren `ropa_piernas`.

**Fuera desde el principio:** `OS05` Boyshorts (el `.blend` la guarda como ropa interior, y el editor admite cuerpos de 5 a 60 años, D42); `OT03` Camisole Crop Top, `OT04` Halter Top y `OU04` Cropped Sweatshirt (no son lo pedido, mismo motivo); `OU02` Hood Up (choca con el pelo y con Cabeza ×2,5); `OC05` Striped Top (solo referencia). OverScore no tiene shorts hasta la rodilla.

## 2. Nivel de modelo

**Fuerte: Opus 5.5 en high.** Pipeline de Blender, pesos, formas y geometría.

## 3. Contexto mínimo

`CLAUDE.md`; `ruta/GUIA_MODELOS.md` §1 y §3; esta ficha; `blender/exportar_overscore.py`; `pruebas/godot/probar_packs.gd` (`_check_overscore`) y `probar_piezas.gd` (`_check_overscore` y siguientes).

## 4. Archivos

- **Nuevos:** `blender/exportar_overscore.py` (GPL-3.0+), `godot/packs/overscore/` (5 `.glb`, sus `.import` y `pack.json`).
- **Tocados:** `CREDITOS.md` y `godot/CREDITOS.txt`, `propuestas/recursos_3d.csv` (fila OV), `IDEAS.md` (las 8 que no entran), `pruebas/godot/probar_packs.gd`, `pruebas/godot/probar_piezas.gd`, `PLAN.md`.
- **No se tocan:** `godot/addons/creador/`, `godot/app/`, `blender/exportar_quaternius.py`, los packs `base`, `makehuman` y `quaternius`, `CLAUDE.md`, `recursos_externos/`.

Comando: `blender -b --disable-autoexec -P blender/exportar_overscore.py -- godot/datos/humana godot/packs/overscore recursos_externos/OGA_overscore_proxy/proxy_1.5.blend [id ...]`. Sin ids exporta `ENTRAN`. Con ids mide esas prendas (si una falla, no escribe nada).

## 5. Diseño final

**Entrada.** `proxy_1.5.blend`, sha256 `ac0dcdb2979dab7311e6d95ce6b1b20b118ef80d4de1f69aa9e88f733111b5ea` (se comprueba antes de abrirlo), siempre con `--disable-autoexec`.

1. **Piel:** los 13 380 primeros vértices. Los helpers no cuentan.
2. **Colocar su cuerpo:** escala 0,3378; pies en 0; centrar la banda de cadera en Y (−8,5 mm).
3. **Registro no rígido** del cuerpo de OverScore: ICP con radios 0,10 a 0,018 m, 4 iteraciones por radio.
4. **Triangular la mitad** antes de encajarla: la superficie comprobada es la que se exporta.
5. **Llevar la prenda** con el campo del registro (12 nodos del mismo lado, gaussiana de 0,03 m).
6. **Suavizar lo movido** por las aristas (8 pasadas). La costura es lo que Mirror suelda (`2·|x| ≤ merge_threshold`); los demás vértices se quedan a más de ese umbral para no soldarse.
7. **El bajo baja en bloque** (*revisión*): todos sus vértices con el mismo desplazamiento en Z, y al inflar solo crecen en horizontal.
8. **Inflar en neutro:** rayos desde la piel; donde la tela quede a menos de `MARGIN` = 3 mm, sus esquinas crecen a lo largo de su normal. Tope `MAX_INFLATE` = 45 mm (*revisión*: corrige el inflado desbocado). Cara y palmas no empujan la tela (*revisión*); la **comprobación** sigue midiendo toda la piel, sin filtrar.
9. **Inflar en poses de prueba** (*revisión*): piernas ±40° y ±15°, brazos ±25° y ±30°, tronco ±15° y ±20°. Solo si piel y tela miran hacia el mismo lado. Son poses genéricas: no se usa «Atacar» para ajustar.
10. **Capas** (*revisión*): cada prenda de torso sube sobre los **3** shorts hasta no cruzar ninguno, aunque ese short no entre en el pack.
11. **Modificadores:** Mirror y Solidify, con la tela creciendo hacia fuera. Sin materiales; `shade_smooth`.
12. **Pesos y formas** (*revisión*): de la piel sin cabeza y del mismo lado. En la axila, a menos de 6 cm de brazo y tronco, los pesos mezclan ambos según la distancia. Formas con los nombres de `cuerpo.glb`, sin las que mueven menos de 0,1 mm.
13. **Exportar:** `pack.json` con id `overscore`, CC0-1.0, autor `overscore_media`, origen y `sha256`.

**Medido en las 5 que entran** (1,32 MB en total):

| Prenda | Formas | MB | Hueco mín. | Bajo (mm) | Seguimiento RMS / pico (mm) | «Atacar» | + Golf Shorts: neutro / máx. «Atacar» |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `os_golf_shorts` | 81 | 0,27 | 3,00 | 24 → 24 | 1,41 / 2,47 | 2,58 %, 6,3 mm | — |
| `os_vneck_top` | 134 | 0,32 | 3,00 | 36 → 36 | 1,36 / 5,65 | 2,55 %, 7,0 mm | 0 / 31 |
| `os_scrubs_top` | 134 | 0,27 | 2,75 | 36 → 36 | 1,62 / 5,49 | 1,81 %, 7,3 mm | 0 / 31 |
| `os_tank_top` | 201 | 0,25 | 3,00 | 46 → 46 | 1,31 / 2,21 | 0,33 %, 1,3 mm | 0 / 84 |
| `os_camisole_top` | 193 | 0,21 | 3,00 | 37 → 37 | 1,31 / 2,44 | 2,53 %, 9,2 mm | 0 / 95 |

Las 4 de torso dan 0 pares cruzados en neutro con los **3** shorts (medido en el exportador).

**Capucha y cuello alto** (pares cruzados con el pelo, neutro / Cabeza ×2,5 / máx. «Atacar»): capucha + pelo corto (`short02`) 0 / 0 / 0; capucha + pelo largo (`hair_long`) 341 / 443 / 461; cuello alto + pelo corto 60 / 77 / 70; cuello alto + pelo largo 74 / 82 / 95. Ninguna de las dos entra (tabla del §1).

## 6. Pruebas

Límites, todos **`# PROVISIONAL`** hasta que el responsable los apruebe (regla 9). No cambiaron en la revisión.

| Constante | Dónde | Límite | Peor medida de las 5 |
| --- | --- | --- | --- |
| `OS_MAX_BYTES` | `probar_packs` | 12 000 000 | 1,32 MB |
| `MIN_GAP` | script | ≥ 2,5 mm entre piel y cara interior | 2,75 mm |
| `UNDER_MAX`, `UNDER_DEPTH` | script | ≤ 2 % de la tela bajo la piel, ≤ 1 mm | 0,57 %, 0,25 mm |
| `HEM_EXTRA` | script | el rango del bajo crece ≤ 10 mm | 0 mm |
| cruces con los 3 shorts | script | 0 pares en neutro | 0 |
| `OS_GAP_RMS_MAX` | `probar_piezas` | ≤ 3 mm | 1,62 mm |
| `OS_GAP_PEAK_MAX` | `probar_piezas` | ≤ 6 mm | 5,65 mm |
| `OS_ATTACK_SKIN_MAX` | `probar_piezas` | ≤ 5 % | 2,58 % |
| `OS_ATTACK_PEAK_MAX` | `probar_piezas` | ≤ 10 mm | 9,2 mm |
| cruces torso + short | `probar_piezas` | 0 pares en neutro; en «Atacar» solo se mide | 0; hasta 95 |

**Roturas comprobadas** (en una copia del proyecto; deshechas y verificadas con `cmp`):

- `MARGIN = −10 mm` → `FALLO hueco 1,01 mm < 2,5`.
- Sin capas → `FALLO cruza os_golf_shorts (222 pares)`; en `probar_piezas`, `no se cruzan en neutro 226`.
- Sin la regla del bajo → `FALLO el bajo crece 15 mm > 10`.
- Licencia CC-BY en `pack.json` → falla `probar_packs`.
- Sin `ShapeWeights.apply` → `sigue a Complexión, Torso y Altura RMS 12,19, pico 32,91 mm`.
- Pesos todos a `Hips` → `no deja asomar la piel en Atacar 15,94 %, 20,0 mm`.

## 7. Riesgos y trampas

1. **En «Atacar» sí hay cruces** entre camiseta y shorts (hasta 95 pares): el criterio fijado solo los mide.
2. **Golf Shorts toca el cuerpo en neutro:** 32 pares de triángulos cruzados con la piel, aunque ningún vértice de piel lejos del borde asome. Sin límite fijado.
3. **Solo entra un short**, el más largo: faltan los muy cortos, que eran prioridad del responsable.
4. **Ninguna sudadera ni suéter entra.** Las mangas largas y las prendas anchas se cruzan con el tronco al mover los brazos.
5. **Prendas más holgadas** por el inflado (poses y capas). Lo juzga el responsable.
6. **Sombreado suavizado** sobre un original facetado; los materiales de varios colores quedan en uno.
7. **Trampas técnicas:** Godot da los triángulos en sentido contrario a Blender; importar `blender/` crea `__pycache__` si no se desactiva.

## 8. Juicio visual (lo hace el responsable)

Hoja: `pruebas/capturas/piezas_overscore/hoja.png` (cada prenda de frente y de espalda; camiseta + shorts con deslizadores extremos y «Atacar»). Solo se da la ruta.

Preguntas: ¿encajan?, ¿la holgura y el suavizado valen?, ¿cuáles se quedan?

## 9. Si te atascas

No se suben límites ni se añaden `if` por prenda. La revisión de este paso ya se gastó: para recuperar alguna de las 8 prendas que no entran hace falta una decisión nueva del responsable (`IDEAS.md`).

## 10. Licencia

OverScore Proxy 1.5, de overscore_media. La página de OpenGameArt indica «License(s): CC0» y el sitio del autor dice «It's released under a CC0 license» (`candidatos.md`; no se volvió a abrir, sin red). **El `.blend` no trae texto de licencia** (0 bloques de texto). El responsable aceptó OverScore como CC0 con esas dos fuentes (2026-11-21). `CREDITOS.md` cita las dos URL, el sha256 y esta falta de texto.
