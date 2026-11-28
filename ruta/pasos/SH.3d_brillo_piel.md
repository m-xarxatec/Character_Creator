# SH.3d — Brillo suave de piel

> Ficha del 2026-11-23 (nivel: medio). **Hecha el 2026-11-23, apagada; falta el juicio visual (§5) y elegir `gloss_strength`.** Decisión: D49 en `ruta/DECISIONES.md` (cambia la parte «sin brillo» de D47).

## 1. Objetivo y «Hecho cuando»

Un satinado suave en la piel donde da la luz (hombros, brazos, frente), igual de bonito en piel clara y oscura.

Hecho cuando:

- Con `gloss_strength = 0` (por defecto) nada cambia.
- Encendido, con la luz de frente el centro vale `color · (1 + gloss_color)` (en lineal).
- Sin brillo en la sombra, en la sombra proyectada, en la prenda, con `unlit` ni sin luz.
- No depende del orden de las luces (dentro del tono de cada luz, antes del `max()`).

## 2. Archivos

- **Se cambian:** `toon_soft.gdshader` (`gloss_strength`, `gloss_size`, `gloss_softness`, `gloss_color`; `varying gloss_mask`), `eye_layers.gdshader` (bloque común; el ojo, con `gloss_mask = 0`: sus brillos son AC.5), `body_material.gd` (`SOFT_DEFAULTS`), `pruebas/godot/probar_piel.gd`.

## 3. Diseño

```glsl
// light():
float gloss = smoothstep(1.0 - gloss_size - gloss_softness, 1.0 - gloss_size + gloss_softness,
	dot(NORMAL, normalize(LIGHT + VIEW))) * lit * gloss_mask * gloss_strength;
vec3 tone = full * (base + rim_color * rim * rim_strength + gloss_color * gloss) * reach;
// fragment():
gloss_mask = unlit ? 0.0 : 1.0 - garment;
```

- **Multiplica, no suma.** Una primera versión sumaba un blanco fijo (dividido entre `ALBEDO`, que sí se lee en `light()`): en la piel oscura salía una mancha gris de plástico. Multiplicando, el brillo es proporcional al color y se ve igual de suave en todos los tonos (D46).
- **`* lit`** solo importa dentro de la sombra proyectada: el brillo y la sombra propia nunca coinciden con una luz direccional (en el centro del brillo `dot(NORMAL, LIGHT) ≥ 0`).
- Las piezas usan el mismo shader y hoy reciben los mismos `SOFT_DEFAULTS` que el cuerpo (con 0, sin brillo). Al cambiar el defecto en SH.7 hay que decidir si las piezas lo llevan; el pelo tiene su banda propia (SH.6b).

## 4. Prueba

La de SH.3c (`probar_piel.gd`). La sombra proyectada usa una caja que solo proyecta sombra (`SHADOW_CASTING_SETTING_SHADOWS_ONLY`). Que detecta el fallo (en una copia): el brillo sin `* lit` (sombra proyectada, 82/255); sin `* gloss_mask` (prenda, 66/255); el brillo sumado después del `max()` (orden, 14/255).

## 5. Juicio visual

Columna C de `pruebas/capturas/shader_piel/hoja_cuerpo.png` y `hoja_cara.png` (banda 0,6 y brillo 0,35).

Preguntas: ¿el brillo se lee como piel suave y no como plástico o sudor? ¿Qué `gloss_strength` va a `SOFT_DEFAULTS` en SH.7? ¿Cambio el tamaño (`gloss_size` 0,05) o el borde (`gloss_softness` 0,05)?
