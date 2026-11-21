# PL.10 — Solo Femenino, Masculino y Neutro (pestaña «Género»)

> Pedido por el responsable el 2026-11-21: «quita los cuerpos de plantillas… solo dejaremos femenino, masculino y
> neutro… la pestaña plantillas cambiará a género». Que cada uno haga lo que quiera con los deslizadores, sin imponer
> cuerpos y con un programa más ligero.

## 1. Objetivo y «Hecho cuando»

- La pestaña «Plantillas» se llama «Género» y tiene Aleatorio, Femenino, Masculino y Neutro. «Nuevo personaje»
  enseña las mismas, sin «Más cuerpos».

## 2. Nivel de modelo

**Simple** (borrar datos y ajustar listas).

## 3. Archivos

- **Se borran:** `presets/{atletica,atletico,delgada,delgado,esbelta,esbelto,robusta,robusto}.{json,png,png.import}`.
- **Se renombra:** `presets/femenina.*` → `presets/femenino.*` (nombre «Femenino»).
- **Se tocan:** `manifiesto.json`, `blender/exportar_datos.py` (`TEMPLATES`), `godot/app/template_gallery.gd`
  (`ORDER`), `zone_picker.gd` (título), `start_screen.gd` (sin «Más cuerpos»), `main.gd` (ayuda del botón),
  `godot/datos/FORMATO.md`, `diseno/GUIA_ESTILO.md`, `diseno/GUIA_INTERFAZ.md` y sus pruebas.

## 4. Diseño

- Orden: Femenino, Masculino, Neutro (`anime.json`, el de personaje nuevo, no cambia de nombre).
- «Aleatorio» sigue: primera tarjeta de «Género» y cuarta en «Nuevo personaje».

## 5. Prueba

`probar_plantillas`, `probar_inicio`, `probar_presets`, `probar_zonas` y `probar_comparar` con las tres.
