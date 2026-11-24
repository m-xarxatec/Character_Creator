# SH.5 — Exportar el aspecto anime en el `.tres`

> Ficha del 2026-11-23 (nivel: fuerte). **Hecha el 2026-11-23.** Decisión: D53.

## 1. Objetivo y «Hecho cuando»

El `.tres` que va al lado del `.glb` reproduce el estilo de la vista. En estilo anime: `toon_soft` y el contorno incrustados (sin rutas), con colores, acabado, piel y el mapa de zonas; se vuelve a leer y pesa menos de 1,5 MB. En estilo clásico, igual que antes. El `.glb` no cambia.

## 2. Archivos

`body_material.gd` (`standalone`, `_small_zones`, `EXPORT_ZONES_SIZE`), `probar_material.gd`.

## 3. Diseño

El mapa de zonas va reducido a 256² con mipmaps: son manchas suaves y a 1024² el `.tres` de texto pesaba 14,2 MB (256²: 0,9 MB). `PortableCompressedTexture2D` sin pérdida no se volvía a leer en Godot 4.7.2. Las piezas siguen saliendo en el `.glb` con `StandardMaterial3D` de su color. El contorno teñido llegará al `.tres` con SH.4b; el rubor y las pecas en el `.glb`, con SH.8c.

## 4. Prueba

`probar_material.gd`, con y sin ventana.
