# Hueco de MPFB en la macro "firmness"

Reproducción mínima para avisar a los autores de MPFB. Solo usa la API de MPFB.

```
blender -b -P pruebas/fase_2/hueco_mpfb/reproducir.py 2>&1 | grep HUECO
```

## Resultado (Blender 5.2.2 LTS, MPFB 2.0.18)

Mujer (`gender` 0) con pecho al máximo (`cupsize` 1); el resto de macros por defecto.
Desplazamiento de la punta del pecho derecho (vértice 1877) respecto a firmeza 0,4997:

| Firmeza | Desplazamiento | Formas de pecho cargadas |
| --- | --- | --- |
| 0,499700 | 0,00 mm | 1 |
| 0,499850 | **90,60 mm** | **0** |
| 0,499896 | **90,60 mm** | **0** |
| 0,499900 | 0,02 mm | 1 |
| 0,500100 | 0,02 mm | 1 |

## Causa

En `data/targets/macrodetails/macro.json` cada macro tiene dos tramos que no se tocan:

- `firmness`: `-0.01 … 0.4998` y `0.4999 … 1.01` → hueco entre 0,4998 y 0,4999.
- `cupsize`, `muscle`, `weight`: `… 0.49998` y `0.49999 …` → hueco entre 0,49998 y 0,49999.

`TargetService._interpolate_macro_components` usa `value > lowest and value < highest`, así que un valor dentro
del hueco no cae en ningún tramo: la macro no aporta nada y desaparecen todas sus formas (en `firmness`, todo el pecho).
El propio 0,4999 no cae en el hueco solo porque la propiedad de Blender es de 32 bits y lo guarda como 0,49990001.

## Summary (English)

In MPFB 2.0.18 (Blender 5.2.2), `macro.json` leaves a gap between the two interpolation parts of each macro
(`firmness`: 0.4998–0.4999; `cupsize`, `muscle`, `weight`: 0.49998–0.49999). A value inside the gap matches no part
in `_interpolate_macro_components` (strict `>`/`<`), so the macro contributes no components and all its targets are
dropped. With `gender` 0 and `cupsize` 1, setting `firmness` to 0.49985 moves the right nipple vertex (1877) by
90.6 mm compared with 0.4997, and 0 breast targets are loaded. Run `reproducir.py` to reproduce.
