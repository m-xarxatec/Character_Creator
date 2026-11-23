# OPT.1 — Medir la lentitud y quitar lo fácil

> Pedido por el responsable el 2026-11-20 («al abrirlo y moverlo lo sentí un poco lento»; «debemos optimizar un poco»).

## 1. Objetivo y «Hecho cuando»

- Saber dónde se va el tiempo al abrir y al mover un deslizador, y quitar lo que no cambia el resultado.

## 2. Nivel de modelo

**Fuerte** (toca `MeshBaker`, del núcleo, sin cambiar lo que calcula).

## 3. Archivos

- **Se crea:** `pruebas/godot/medir_lentitud.gd` (con ventana, sin límites).
- **Se tocan:** `godot/addons/creador/mesh_baker.gd`, `godot/app/style_view.gd`, `godot/app/character_box.gd`, `PLAN.md`.

## 4. Medido antes (GTX 1650, Forward+)

| Qué | Tiempo |
| --- | --- |
| Arrastrar «Músculo» | 2,4 ms por fotograma (p99 3,5): no es lo lento |
| Al soltar (0,3 s después): normales del estilo | **279 ms** de congelado; 194 de ellos, pedir las 286 formas a la malla (con 5 activas) |
| Abrir hasta el primer fotograma | **3,1 s**: cargar el personaje 1,77 s (leer el glTF 0,95, crear la escena 0,25, `sha256` 0,06, estilo 0,29), medidas 0,42, dibujar el resto |
| Al abrir, las 286 formas se piden | 3 veces (~194 ms cada una: estilo, encuadre, medidas) |

## 5. Cambios (mismo resultado)

- `MeshBaker._add_shapes(…, cache)`: caché opcional de las formas ya usadas; `StyleView` guarda la suya (~0,35 MB por
  forma usada; no las 286, que serían ~100 MB).
- `MeshBaker.shape_arrays(mesh)`: las formas se piden una vez por fotograma y se sueltan en el siguiente;
  `CharacterBox` y `_add_shapes` la usan.

## 6. Prueba

Las de siempre (`probar_vista_estilo`, `probar_medidas`, `probar_encuadre`, exportar…) y `medir_lentitud.gd`.
