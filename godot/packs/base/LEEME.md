# Pack base

Piezas de serie de GameMolde. Licencia de todo el pack: **CC0-1.0** (dominio público).

| Pieza | Qué es | Cómo se hizo |
| --- | --- | --- |
| `tights.glb` (Malla de cuerpo completo), `hair.glb` (Volumen de melena) | Mallas de ayuda de la malla base de MakeHuman (CC0) | `blender/exportar_helpers.py`: las formas de MakeHuman medidas en sus vértices; las de cara y las propias, copiadas de la piel más cercana |
| Melena con flequillo | El volumen de melena sin lo que cae delante de los ojos | Lo recorta el programa al vuelo (`garment_cut.gd`) |
| Casquete | Caras de la propia piel de la cabeza, separadas 4 mm | Lo hace el programa al vuelo (`body_derived.gd`); no ocupa sitio |
| Cuernos, Orejas de gato, Halo | Generadores por parámetros | Los hace el programa al vuelo (`horn_generator.gd`, `ring_generator.gd`, `rigid_piece.gd`) |

Formato de `pack.json`: `ruta/ARQUITECTURA.md` §6 (más los campos `derivada` y `generador`, pasos AB.9a y AB.11).
Volver a generarlo: `blender -b -P blender/exportar_helpers.py -- godot/datos/humana godot/packs/base`.
