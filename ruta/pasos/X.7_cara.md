# X.7 — Cara sin escalón en la sien y con su propio umbral de luz

> Ficha del 2026-11-23 (nivel: fuerte). **Hecha el 2026-11-23, sin cambio de aspecto; falta el juicio visual (§4).** Decisiones: D51 y D53.

## 1. Objetivo y «Hecho cuando»

- `StyleNormals.temple_blend`: el aplanado de la cara (FACE_DEPTH) entra poco a poco en vez de cortar en el plano de la sien. Con 0 las normales son las de antes. Con 0,35, el salto del giro de la normal en la sien baja al menos a la mitad (medido: 1,421° → 0,155°).
- `face_light` en `toon_soft`: baja el umbral solo en la cara (canal A de `piel.png`), así que la cara recibe más luz; fuera de ella no cambia nada.
- Los dos a 0 hasta que el responsable elija.

## 2. Archivos

`style_normals.gd` (`temple_blend`, `face(…, temple)`), `toon_soft.gdshader` y `eye_layers.gdshader` (`varying edge_from` en el bloque común), `body_material.gd`, `pruebas/godot/probar_cara_x7.gd`.

## 3. Nota

`StyleNormals` lo usa también el estilo clásico. Con `temple_blend` 0,35 en todo el editor, las 6 capturas clásicas cambiarían ≤ 0,004 % (dentro del 0,1 %). La sombra de la nariz es proyectada: se trata con `face_shadow_receive` (SH.4).

## 4. Juicio visual

`pruebas/capturas/cara_x7/hoja_sien.png` (tres cuartos; `temple_blend` 0 / 0,35 / 0,6) y `hoja_luz_cara.png` (`face_light` 0 / 0,15 / 0,3). ¿Qué valores?
