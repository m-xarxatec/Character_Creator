# PL.2 — Miniaturas de las plantillas (versión simple)

> `propuestas/expansion_v2.md` §4 (PL.2). Aprobado el 2026-11-20 «simplificado».

## 1. Objetivo y «Hecho cuando»

- Cada preset de `godot/datos/humana/presets/` tiene su `<id>.png` de 256 × 256, hecho con el núcleo del editor.

## 2. Nivel de modelo

**Simple** (un script con ventana y una comprobación sin ventana).

## 3. Archivos

- **Se crean:** `pruebas/godot/generar_miniaturas.gd`; `presets/<id>.png` y su `.png.import` (`importer="keep"`).
- **Se tocan:** `pruebas/godot/probar_presets.gd`, `godot/datos/FORMATO.md`, `PLAN.md`.

## 4. Diseño

- **Simplificado:** solo las de serie, generadas una vez con el script (como los datos). Sin `thumbnailer.gd` en la app
  ni miniaturas de los presets del usuario: llegan con PL.3/PL.4 si hacen falta.
- Render: material toon con contorno (`BodyMaterial` + `Preset.apply_look`), valores con `CharacterUpdater` en reposo,
  luz y ambiente de la vista (`body_view.gd`), cámara de 35° a ¾ (giro de 35°) encuadrando la caja del cuerpo
  horneado. Fondo **transparente**: la tarjeta de la galería pone el del tema (claro u oscuro).
- `importer="keep"` (como `cuerpo.glb`): viajan tal cual en el `.pck` (`include_filter` ya tiene `datos/*`) y se leen con
  `Image.load_from_file`. No van en el manifiesto: no son datos del cuerpo.

## 5. Prueba

Generar: `(ulimit -v 4000000; timeout 300 godot --path pruebas/godot -s generar_miniaturas.gd 2>&1 | grep -E 'GUARDADO|ERROR')`.
`probar_presets.gd` (sin ventana): cada preset tiene su `.png` de 256 × 256 con las esquinas transparentes y el centro
opaco. **Detecta el fallo:** sin una de las `.png`.

## 6. Juicio visual

Las 11 `.png` de `godot/datos/humana/presets/`.
