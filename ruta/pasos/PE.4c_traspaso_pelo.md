# PE.4c — Que el pelo largo no entre en la espalda, la nuca ni los hombros al moverse

> Ficha del 2026-11-27 (nivel: fuerte), segunda ronda con las medidas de `pruebas/capturas/pe4c/hombros/` (fuera de git: `informe.txt`,
> `tabla_final3.txt`, `d_*.txt`, `c_*.txt`, `t_entrega_*.txt`, `roto.txt`). Sale de `IDEAS.md` («Pelo que traspasa la
> piel al moverse») y va antes de `PE.5_exportar_pelo.md`. Descartado: subir la rigidez (el responsable quiere rigidez 1).
> Lo que falla: con pelo largo las puntas entran en la espalda, la nuca y lo alto de los hombros al caminar y correr.
> Opción elegida: **tiras + holgura por articulación** (ronda 1, ya en el proyecto) **+ tira de lo alto de los hombros
> pegada a la piel + quitar la tira que no puede retirarse** (borrador `hombros/hair_physics.gd`, **ya puesto en el proyecto el 2026-11-27: PE.4c-b hecho**; falta PE.4c-a y el juicio del responsable).

## 1. Objetivo y «Hecho cuando»

Que el pelo largo entre mucho menos en la parte de atrás, sin mover el pelo quieto ni cambiar el movimiento.

1. long01, tamaño normal, vértices de cadena que entran > 6 mm más que en reposo: **caminar ≤ 350, correr ≤ 1450 y
   hombros al correr ≤ 650** (original 1054, 2172 y 1127; ronda 1: 276, 1431 y 725; borrador 275, 1260 y 546). PROVISIONAL.
2. Quieto y tras volver a la pose T ≤ 2 mm; punta media al caminar y correr entre 0,85 y 1,15 × la del original (long01:
   73 y 221 mm; borrador 67 y 229). PROVISIONAL.
3. `probar_fisica_pelo`, `probar_cadenas_pelo` y `probar_piezas` pasan **sin cambiar sus límites** (borrador: TODO BIEN).
4. Juicio del responsable en el programa: menos traspaso y el mismo movimiento que gustó.

## 2. Nivel de modelo

Fuerte: geometría en el marco de los huesos y la configuración por articulación de `SpringBoneSimulator3D`.

## 3. Contexto mínimo

- `godot/addons/creador/hair_physics.gd` (282 líneas, ronda 1) (ya es el borrador de `pruebas/capturas/pe4c/hombros/hair_physics.gd`, 294) con
  `hair_physics_vs_base.diff` (+12 líneas) y `hair_physics.diff` (contra el original de 149).
- `pruebas/capturas/pe4c/hombros/medir.gd`: `_run`, `_on_update`, `_pre_skin`, `_skin`, `_depths`, zonas.

## 4. Archivos

- **PE.4c-a:** `pruebas/godot/probar_traspaso_pelo.gd` (nueva, de `medir.gd` sin opciones).
- **PE.4c-b:** `godot/addons/creador/hair_physics.gd` (sustituir por el borrador).
- **No se tocan:** `hair_chains.gd`, `body_view.gd`, `probar_fisica_pelo.gd` y sus límites, `pack.json`, `blender/`.

## 5. Diseño

**PE.4c-a — prueba de caminar y correr:**

```gdscript
const DEEP_MM := 6.0                                              # PROVISIONAL: «entra» = esto más que en reposo
const LIMITS := {"caminar": 350, "correr": 1450, "hombros": 650}  # PROVISIONAL: medido 275, 1260 y 546
const STILL_MM := 2.0                                             # PROVISIONAL: quieto y tras volver
const TIP_RANGE := [0.85, 1.15]                                   # PROVISIONAL: punta media / la del original
const TIP_TODAY := {"caminar": 0.073, "correr": 0.221}
```

1. Especie, `AnimationSet`, `PoseRetarget`, long01, `HairChains.build`, `HairPhysics.attach` sin ajustes.
2. Fases: reposo, quieto 2 s, «caminar» y «correr» (`reset()` al cambiar, 20 de calentamiento, 150 medidos), vuelta a
   la pose T 2 s. Muestras cada 3 fotogramas **dentro de `skeleton_updated`**.
3. Piel por CPU y profundidad con rejilla de 5 cm; `MEDIDA` por zona (cuello, hombros, espalda alta, espalda media);
   `check` de «hombros» al correr. hair_long y bob02 solo `MEDIDA`.

**PE.4c-b — todo dentro de `refit`** (lo de la ronda 1 sigue igual; cambia esto):

```gdscript
const STRIPS := [["Spine","arriba","atras"], ["Chest","arriba","atras"], ["UpperChest","arriba","atras"],
	["Neck","arriba","atras"], ["UpperChest","ancho","arriba", 0.98]]      # 4.º: su «piel» (PROVISIONAL)
```

1. `_strip(…, grow)`: si la tira trae 4.º valor, su percentil «piel» va de ese valor (cabeza ×1) a `STRIP["piel"]`
   (cabeza ×1,5 o más): `lerpf(entry[3], piel, clampf((grow − 1) × 2, 0, 1))`. `grow` se calcula antes de las tiras.
2. `_retreat`: tras retirar la tira, si algún punto probado sigue a más de `margen` dentro de «gap», **se quita**.
3. Motivo (diagnóstico, `d_long01_base.txt` y `c_long01_base.txt`): el 40 % de los casos de hombros era piel sin
   choque: con 0,9 la tira de arriba quedaba 19–65 mm bajo la piel (franjas de |x| 40–160 mm), porque cada franja
   corta el pecho entero y lo de arriba son pocos puntos. Con 0,98: −0,2 a 14 mm.

## 6. Prueba

- **PE.4c-a** debe **fallar** con el código de la ronda 1 (hombros 725 > 650) y con el original. Tras b, pasa.
- **PE.4c-b:** `probar_traspaso_pelo`, `probar_fisica_pelo`, `probar_cadenas_pelo` y `probar_piezas` en TODO BIEN.
- Detecta el fallo (medido, `roto.txt`): tira a 0,9 → hombros 725 (falla PE.4c-a); sin volver a 0,9 con la cabeza
  grande → `probar_fisica_pelo` 1 FALLO (long01 Cabeza ×2,5 entra 14,3 mm, límite 12,5); sin quitar la tira →
  long01 Cabeza ×0,8 quieto 32,2 mm (solo en `diag_chica.gd`: ninguna prueba mira ×0,8).

Medidas (vértices > 6 mm de más al correr; zonas cuello / hombros / espalda alta / media), original → ronda 1 → borrador:

| Peinado, variante | Correr | Zonas original | Zonas ronda 1 | Zonas borrador |
| --- | --- | --- | --- | --- |
| long01 normal | 2172 → 1431 → 1260 | 110 / 1127 / 244 / 13 | 139 / 725 / 225 / 0 | 118 / 546 / 144 / 13 |
| long01 Altura 0,65 | 2011 → 1529 → 1370 | 92 / 890 / 518 / 141 | 31 / 733 / 342 / 117 | 49 / 689 / 205 / 134 |
| long01 Cabeza ×2,5 | 1853 → 1612 → 1612 | 5 / 242 / 280 / 522 | 2 / 234 / 181 / 476 | igual que ronda 1 |
| hair_long normal | 681 → 586 → 598 | 239 / 34 / 0 / 0 | 208 / 32 / 0 / 0 | 218 / 34 / 0 / 0 |
| hair_long Altura 0,65 | 416 → 116 → 176 | 218 / 14 / 0 / 0 | 80 / 0 / 0 / 0 | 118 / 20 / 0 / 0 |
| hair_long Cabeza ×2,5 | 936 → 931 → 931 | 14 / 328 / 64 / 0 | 10 / 276 / 76 / 0 | igual que ronda 1 |
| bob02 normal / Altura / Cabeza | 391 / 174 / 421 → 290 / 111 / 415 | — | — | cuello 14 / 3 / 2 |

Quieto ≤ 1,12 mm en todo (long01 Altura: 1,38 → 0,00); punta / original entre 0,91 y 1,06.

## 7. Trampas conocidas

- **Godot solo choca puntos** (la punta de cada hueso a la longitud sin escala, `_tail`): la malla lejos de su cadena
  (hombros: 31–117 mm de mediana) no la protege ningún choque. Más sectores no ayudan (16: hombros 833).
- **Cabeza grande:** la punta real queda más lejos que el punto probado; una tira pegada a la piel bajo las puntas de
  las cadenas laterales (x_pelo_6_3) las deja entrar 14–17 mm (×1,9 a ×2,5). Por eso vuelve a 0,9.
- **Retirar hacia dentro no basta si el punto queda de lado:** la tira atraviesa el cuello o sigue tocando. Iterar
  la retirada la hunde 40 mm y empeora; quitarla es lo que funciona.
- Tiras a los lados del cuello (radio 45 mm): bob02 quieto 16–18 mm. Con 25 mm: cuello hair_long 182 y long01 116,
  más código: fuera.
- Tiras en LeftShoulder/RightShoulder: medida idéntica a sin ellas (que no salen por pocos puntos: **NO
  VERIFICADO**). En LeftUpperArm/RightUpperArm: hombros 485, pero
  espalda media 39 (original 13): fuera.
- Cambios pequeños (paso 0,040 → 0,041) mueven hombros 546 → 640: los números de una zona varían ±15 %.
- Cada prueba de choques en su propio proceso: encadenadas salen distintas.
- PE.5: guardar en `.tscn` los valores por articulación **NO VERIFICADO**.

## 8. Juicio visual (del responsable)

Comando: `(ulimit -v 4000000; timeout 900 godot --path godot)`. Poner long01 y hair_long; «caminar» y «correr»; mirar
lo alto de los hombros, la nuca y la espalda de lado y por detrás; luego Altura y Cabeza › Tamaño (también pequeña)
y repetir. Preguntas: ¿entra menos en los hombros? ¿se mueve igual? ¿algo tiembla quieto?

## 9. Si te atascas

- **Límite conocido (no se protege del todo):** hombros al correr siguen 546 (long01; original 1127). Peor que el
  original: nuca de long01 normal 118 (110), hombros de hair_long Altura 20 (14) y espalda alta de hair_long Cabeza
  76 (64, ya en la ronda 1). Causa: malla lejos de su articulación y choque solo por puntos; arreglarlo pide más
  huesos cerca de la malla (`hair_chains.gd`, otro paso) o empujar la malla en el shader: a `IDEAS.md`.
- Ya en el original, sin prueba que lo vea: bob02 Cabeza ×0,8 quieto 8,43 mm; long01 Cabeza ×1,9 entra 10,9 mm
  (límite 9,5). A `IDEAS.md` o paso propio.
- Si `probar_fisica_pelo` falla, parar y medir; no tocar sus límites (regla 9).
- Si `probar_traspaso_pelo` no falla con el código de la ronda 1, la medida está mal: no seguir a b.
- Si sus números salen a más de un 20 % de los del borrador, parar y decirlo.
