# RE.1a — Pelo y ropa de MakeHuman que ya están en local (AB.9d y arranque del 12.1)

> Ficha del 2026-11-21 (Opus 5.5). Hoja de recursos: `propuestas/recursos_3d.md` y `.csv` (MH01 y MH02).
> Sin red: los «system assets» de MakeHuman ya están instalados con MPFB en
> `~/.config/blender/5.2/extensions/.user/blender_org/mpfb/data/` (`hair/`, `clothes/`, `eyebrows/`, `eyelashes/`).
> Licencia comprobada dos veces: cada `.mhclo` dice «explicitly released as CC0» y `packs/makehuman_system_assets.json`
> dice `CC0` en cada asset. Ya figuran en `CREDITOS.md` (fila «MakeHuman system assets»).

## 1. Objetivo y «Hecho cuando»

Ropa y pelo de MakeHuman hechos para nuestra misma malla, como piezas que siguen al cuerpo (sustituyen a la ropa
quitada el 2026-11-21). Hecho cuando: el responsable elige qué assets entran, están en `godot/packs/makehuman/` y se
ponen desde las pestañas Pelo y Ropa.

## 2. Nivel de modelo

Fuerte (pipeline de Blender y formas); medio para elegir y meter los assets una vez decidido.

## 3. Archivos

- **Hechos (sin commit):** `blender/exportar_mhclo.py` (nuevo) y `blender/exportar_glb.py` (opción `morph_normals`).
- **Por tocar:** `godot/packs/makehuman/` (los `.glb`, sus `.import` y `pack.json`), `CREDITOS.md` (y su copia
  `godot/CREDITOS.txt`: «Dónde se usa»), `propuestas/recursos_3d.csv` (estado), pruebas.

## 4. Diseño (ya probado)

- MPFB encaja cada asset sobre el cuerpo neutro (`HumanService.add_mhclo_asset`, pesos interpolados del cuerpo).
- Formas con los mismos nombres que `cuerpo.glb`: para cada una, el cuerpo neutro + esa forma (todos los vértices,
  helpers incluidos, medidos como en `exportar_helpers.py`) y se vuelve a encajar el asset
  (`ClothesService.fit_clothes_to_human`, pasándole el `Mhclo` cargado: si no, MPFB solo encuentra los de ropa).
  Se quitan las que lo mueven menos de 0,1 mm. Sin normales de forma (la mitad de tamaño).
- Sin texturas: color plano del estilo ilustración (el color de partida va en `pack.json`).

## 5. Medido (prueba del 2026-11-21, en el scratchpad, sin tocar el proyecto)

| Asset | Vértices | Formas | Con normales de forma | Sin ellas |
| --- | --- | --- | --- | --- |
| `hair/short02` | 1755 | 40 | 1,29 MB | 0,69 MB |
| `clothes/shoes01` | 1722 | 30 | 1,39 MB | 0,77 MB |
| `clothes/female_casualsuit01` | 2197 | 211 | 4,81 MB | 1,95 MB |

En el editor (cargando el pack de prueba): encajan, siguen a Complexión, Peso y a «Atacar». Los 55 assets suman
83 432 vértices: todo entero pesaría del orden de 70 MB sin normales. **Hay que elegir.**

## 6. Dónde continuar

1. El responsable mira la captura (`pruebas/capturas/piezas/mh_prueba_hoja.png`) y elige qué assets entran
   (lista en `mpfb/data/hair/` y `clothes/`: 10 peinados, 10 trajes, 6 zapatos, 2 sombreros).
2. Lanzar: `blender -b -P blender/exportar_mhclo.py -- godot/datos/humana godot/packs/makehuman <ranura>:<ruta.mhclo> …`
   (ranuras: `pelo`, `ropa_torso`, `ropa_piernas`, `ropa_pies`, `accesorio`). Tarda unos 8 min.
3. Darles nombres en español en `pack.json`; fila de «Dónde se usa» en `CREDITOS.md` y su copia.
4. Pruebas: `probar_packs` (el pack nuevo, CC0), `probar_piezas` (poner uno de cada ranura, seguir, exportar) y la
   batería. Juicio visual.
5. Después: cejas y pestañas (`eyebrows/`, `eyelashes/`, para la fase 9), ocultar la piel tapada con la lista
   `delete_verts` de cada `.mhclo` (12.3/12.5), y el permiso de red para el resto de MH01/MH02 (D39).
