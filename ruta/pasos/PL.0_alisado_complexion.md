# PL.0 — Alisado con complexión y firmeza

> `propuestas/expansion_v2.md` §4 y `IDEAS.md` («`alisado` con género y firmeza»). Aprobado el 2026-11-19.

## 1. Objetivo y «Hecho cuando»

- `alisado` cumple las medidas del 6.2 en los 4 cuerpos con `gender` y `firmness` a 0 y a 1 (las demás macros, neutras).
- Hay una hoja de capturas de esos 4 cuerpos, antes y después del alisado.

## 2. Nivel de modelo

**Medio** (solo mide). Si algún cuerpo falla, la corrección es un paso nuevo de Blender, **fuerte**, antes de PL.1.

## 3. Archivos

- **Se tocan:** `pruebas/fase_6/probar_formas_propias.py`, `PLAN.md`.
- **No se tocan:** `blender/`, `godot/` (ni la app ni `datos/`).

## 4. Diseño

- En la app, con músculo, grasa y pecho neutros, las correcciones `alisado*…` pesan 0: el alisado de esos cuerpos es
  la forma `alisado` del neutro, sin más. La prueba aplica eso mismo a cada cuerpo (`ed.raw_body` + `ed.sample`).
- Medidas (las del 6.2, con sus límites, sin cambiarlos): ningún triángulo invertido; curvatura de `chest` y
  `crotch` baja al menos `SMOOTH_DROP`; volumen cambia menos de `VOLUME_SHARE`.
- Capturas (con `--capturas`): `complexion.png`, filas = 4 cuerpos × (antes, después), columnas frente y ¾, sombreado
  normal, sin prenda. Se hace en Blender, como en la propuesta aprobada (`expansion_v2.md` pedía además toon en Godot:
  queda fuera de este paso).

## 5. Prueba

`blender -b -P pruebas/fase_6/probar_formas_propias.py 2>&1 | grep -E 'FALLO|MEDIDA|RESULTADO'`.
**Detecta el fallo:** con el alisado al revés (`-delta`) salen triángulos invertidos o la curvatura no baja.

## 6. Juicio visual

`pruebas/capturas/formas_propias/complexion.png`.
