# Pack base

Piezas de serie de GameMolde. Licencia de todo el pack: **CC0-1.0** (dominio público).

| Pieza | Qué es | Cómo se hizo |
| --- | --- | --- |
| `tights.glb` (Mallas), `skirt.glb` (Falda), `hair.glb` (Volumen de melena) | Mallas de ayuda de la malla base de MakeHuman (CC0) | `blender/exportar_helpers.py`: las formas de MakeHuman medidas en sus vértices; las de cara y las propias, copiadas de la piel más cercana |
| Casquete, Guantes, Calcetines, Botas altas | Caras de la propia piel, separadas unos milímetros | Las hace el programa al vuelo (`body_derived.gd`); no ocupan sitio |
| Cuernos | Generador por parámetros | Los hace el programa al vuelo (`horn_generator.gd`, `rigid_piece.gd`) |

Formato de `pack.json`: `ruta/ARQUITECTURA.md` §6 (más los campos `derivada` y `generador`, pasos AB.9a y AB.11).
Volver a generarlo: `blender -b -P blender/exportar_helpers.py -- godot/datos/humana godot/packs/base`.
