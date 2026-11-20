# PL.1 — Plantillas de serie

> `propuestas/expansion_v2.md` §4 (PL.1). Aprobado el 2026-11-20, partido en PL.1a, PL.1b y PL.1c. El campo `orden`
> de las plantillas queda para PL.3 (la galería, que es quien lo usa): PL.1 no cambia el formato del preset.

## 1. Objetivo y «Hecho cuando»

- **PL.1a:** `Measures.proportions()` da las 6 medidas de `GUIA_ESTILO.md` §2 y su prueba comprueba que siguen a
  sus deslizadores; `MEDIDA` del personaje nuevo y de los borradores femenino y masculino de la fase 3.
- **PL.1b:** plantillas Neutro, Femenina y Masculino en `godot/datos/humana/presets/` (versión 2, con cara y
  `alisado` = 1, piel gris neutro); en los rangos de §2 (PROVISIONAL: si una no entra, se da la medida); informe sin
  errores en pose T y en «Atacar»; hoja de frente y ¾.
- **PL.1c:** las otras 8 (Atlética, Atlético, Delgada, Delgado, Robusta, Robusto, Esbelta, Esbelto), igual que PL.1b.

## 2. Nivel de modelo

**Medio.** PL.1b toca `datos/` y regenera el manifiesto con Blender (`cuerpo.glb` con el mismo `sha256`).

## 3. Archivos

- **PL.1a:** `godot/app/measures.gd`, `pruebas/godot/probar_medidas.gd`, `PLAN.md`.
- **PL.1b/c:** `godot/datos/humana/presets/*.json`, `blender/exportar_datos.py` (`FILES` con todas las plantillas),
  `godot/datos/humana/manifiesto.json` (regenerado), `godot/datos/FORMATO.md`, `pruebas/godot/probar_presets.gd`,
  `PLAN.md`.

## 4. Diseño (PL.1a)

`static func proportions(mesh, skeleton) -> Dictionary`, sobre `MeshBaker.bake` (exacta, no para cada fotograma;
llamarla en reposo). Cada vértice cuenta para su hueso de más peso (`dominant_bones`, que usa también `head_mask`).

| Medida | Cómo |
| --- | --- |
| `heads` | altura ÷ cabeza; cabeza = coronilla − barbilla (regla del 3.12) |
| `legs` | ingle ÷ altura; ingle = el vértice más bajo del torso en el centro (\|x\| < 5 mm) |
| `shoulders` | ancho de la malla a la altura de los hombros (cabeza de `UpperArm`, ± 1 cm) ÷ cabeza |
| `waist` | el corte más estrecho del torso (`Hips`, `Spine`, `Chest`, `UpperChest`; cada 5 mm, de la cadera a medio camino entre `UpperChest` y el hombro; cortes de ± 1,5 cm con vértices a los dos lados) ÷ ese ancho de hombros |
| `hand` | de la muñeca (cabeza de `Hand`) al vértice de la mano más lejano ÷ cabeza; media de los dos lados |
| `foot` | largo en Z de los vértices de `Foot` y `Toes` ÷ cabeza; media de los dos lados |

## 5. Prueba (PL.1a)

`probar_medidas.gd`: en el neutro, `heads` = la medida exacta de siempre (± 0,01), mano y pie simétricos (± 1 mm) y
cada medida dentro de un margen de cuerpo humano (PROVISIONAL); cada deslizador mueve su medida en su sentido
(`leg_length`, `shoulder_width`, `waist_width`, `hand_size`, `foot_size` de 0 a 1 la suben; `head_size` baja `heads`).
`MEDIDA` de `anime.json` y de `pruebas/fase_3/estilo/anime_femenino.json` y `anime_masculino.json`.
**Detecta el fallo:** la cintura con el corte más ancho en vez del más estrecho cae en la cadera (`waist_at` < 0,2).
