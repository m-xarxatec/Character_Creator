# PT.1 — Poner al día dos pruebas viejas

> Ficha del 2026-11-27 (nivel: medio). Sale del diagnóstico `pruebas/capturas/diagnostico/diagnostico.md` (2026-11-26);
> recomendaciones aprobadas por el responsable el 2026-11-26. Va **antes de PE.5**: mientras `probar_personaje_horneado`
> falle por la cara, taparía un fallo real de PE.5 en pose T.

## 1. Objetivo y «Hecho cuando»

Que `probar_animaciones` y `probar_personaje_horneado` vuelvan a pasar porque comprueban lo que hoy es correcto, no
porque se relajen. El código del editor no cambia.

1. `probar_animaciones`: TODO BIEN; espera sin pareja los anclajes **y** `Jaw`, `LeftEye`, `RightEye`; nada más.
2. `probar_personaje_horneado`: TODO BIEN con la referencia regenerada (hoy: extremo 6,77 mm, al_azar 2,13 mm, solo
   en la cabeza).
3. Las demás pruebas que leen la referencia siguen en TODO BIEN **sin tocar sus límites** (§6).
4. Cada prueba cambiada detecta su fallo (§6).

## 2. Nivel de modelo

Medio: dos cambios pequeños y localizados, pero regenerar la referencia afecta a 9 pruebas. Sonnet 5.5 basta; si
alguna de las 9 falla y hay que entender por qué, parar (§9).

## 3. Contexto mínimo

- `pruebas/capturas/diagnostico/diagnostico.md` (41 líneas): causa de cada fallo, con los commits de origen.
- `pruebas/godot/probar_animaciones.gd:52-54` (comprobación) y `_unpaired` (línea 74).
- `pruebas/fase_2/referencia_reajuste.py`: `slots` (53-56) y `mpfb_inputs` (98-117: lanza `ValueError` con `@`).
- `godot/datos/humana/deslizadores.csv`: filas 48-52 (ojos, `cara_anime.EYE_SHAPES`) y las que llevan `@` (nariz, boca,
  labios, orejas).
- `blender/cara_anime.py:64` (`EYE_SHAPES`) y `fix_eye_shapes` (580): por qué los ojos de `datos/` ya no son los de MPFB.

## 4. Archivos

| Archivo | Cambio |
| --- | --- |
| `pruebas/godot/probar_animaciones.gd` | constante `FACE_BONES` y lo esperado = anclajes + `FACE_BONES`, ordenado |
| `pruebas/fase_2/referencia_reajuste.py` | `slots`: quitar también las filas de `EYE_SHAPES` y las que llevan `@` |
| `PLAN.md` | marcar PT.1 y una línea en el registro |

`pruebas/fase_2/salida/referencia_reajuste.json` se regenera; está en `.gitignore` (no entra en el commit). Antes de
regenerarla, copiar la actual al scratchpad para poder comparar.

## 5. Diseño

**probar_animaciones.gd**

```gdscript
const FACE_BONES := ["Jaw", "LeftEye", "RightEye"]  # paso 9.3: sin pesos y sin pareja en los clips
...
var expected: Array = species.manifest["bones"]["sockets"] + FACE_BONES
expected.sort()
check("todos los huesos de deformación tienen pareja", _unpaired() == expected, str(_unpaired()))
```

**referencia_reajuste.py** — en `slots`, una fila entra solo si MPFB la da tal cual en `datos/`:

```python
def mpfb_rows(rows):
    """Filas Forma que datos/ saca tal cual de MPFB: sin cara, propias, ojos (EyeFit) ni alcances (@)."""
    return [r for r in rows if r["tipo"] == "Forma" and r not in ed.face_rows(rows) and r not in ed.own_rows(rows)
            and not r["id"].startswith(cara_anime.EYE_SHAPES) and "@" not in r["decr"] + r["incr"]]
```

`slots` usa `mpfb_rows`. Actualizar su docstring y la cabecera del archivo (una línea: por qué se quitan). Importar
`cara_anime` como ya se importa `exportar_datos` (comprobarlo leyendo el principio del archivo).

Los ojos y las orejas siguen probados por sus pruebas propias (`probar_forma_ojo.py`, `probar_deslizadores.py`).

## 6. Pruebas

Regenerar: `(ulimit -v 4000000; timeout 900 blender -b -P pruebas/fase_2/referencia_reajuste.py)` (tiempo **NO
VERIFICADO**; si 900 s no bastan, parar y decirlo).

Después, cada una en su proceso, con `(ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s <x>.gd)`:
`probar_animaciones`, `probar_personaje_horneado` y las 8 que leen la referencia: `probar_reajuste`,
`probar_reajuste_esqueleto`, `probar_formas`, `probar_anclajes`, `probar_ejes_perfil`, `probar_exportar`,
`probar_horneado`, `probar_pose_t`. Apuntar en el registro el antes y el después de las cifras que imprimen
(`MEDIDA`).

Que detecta el fallo (romper, mirar que salta y deshacer):
- `probar_animaciones`: quitar `"Jaw"` de `FACE_BONES` → falla «todos los huesos de deformación tienen pareja».
- `probar_personaje_horneado`: con la referencia vieja (la copia del scratchpad) vuelve a fallar con 6,77 / 2,13 mm.

No es la batería completa: el responsable la lanza cuando lo diga.

## 7. Trampas conocidas

- Los cuerpos al azar de la referencia cambian (el `rng` reparte entre menos deslizadores): las cifras de las 8
  pruebas se moverán algo. Que se muevan no es un fallo; salirse de un límite sí (§9).
- En los cuerpos `extremo` (0 o 1), los ojos y las orejas ya no se mueven: si `probar_personaje_horneado` sigue
  fallando en la cabeza, el resto viene de otra cosa (p. ej. la base neutra de los ojos) → **NO VERIFICADO**, parar.
- Que el `.json` actual es anterior a `4022228` (19 `expr_*` que la malla ya no tiene): al regenerarlo desaparecen.
  Si alguna prueba los buscaba, saldrá ahí.
- No cambiar `probar_personaje_horneado.gd` ni su límite: el arreglo está en la referencia.

## 8. Juicio visual (del responsable)

No hay: no cambia el aspecto ni el código del editor.

## 9. Si te atascas

- Si una de las 8 sale de su límite con la referencia nueva: parar y proponer con la medida real (regla 9); no tocar
  límites ni quitar más filas sin aprobación.
- Si `mpfb_inputs` sigue lanzando `ValueError` por `@`: se ha escapado alguna fila; mirar el `.csv`, no tocar
  `mpfb_inputs`.
- Alternativa más débil (ya descartada en el diagnóstico): no contar en Godot los vértices con peso en Head/Neck. Solo
  si el responsable la elige.
