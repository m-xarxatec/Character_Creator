# Fase PE — Pelo con huesos y movimiento

> Ficha del 2026-11-25 (nivel: fuerte). Pedida por el responsable: los peinados que ya hay (Quaternius y MakeHuman), con huesos y movimiento. El pelo anime por parámetros (PE.1) se descartó («las formas están raras»; `IDEAS.md`). Sustituye a la ficha breve `11_pelo.md` en 11.3–11.4.

## Hecho

- **PE.2 (2026-11-25):** `SpringBoneSimulator3D` comprobado en Godot 4.7.2 con `pruebas/godot/probar_muelle.gd`: cadenas por hueso raíz y final (`set_root_bone_name`, `set_end_bone_name`, `set_stiffness`, `set_gravity`, `set_drag`, `set_radius`), colisiones como nodos hijos (`SpringBoneCollisionSphere3D`, `…Capsule3D`) con `set_enable_all_child_collisions`. Avance a mano: `Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL` + `advance(delta)`, un fotograma entre pasos. La pose simulada solo se lee en `skeleton_updated`. El choque es por articulación: huesos de 4–5 cm y algo de margen.

## Decisión técnica (2026-11-25)

Las cadenas no se hacen en Blender (habría que regenerar los packs y reimportar los `.glb`): **el núcleo las crea al poner el peinado**, desde la malla de la pieza. Vale para todos los peinados, también los de packs de usuarios. Ajustes por pieza en el campo `fisica` de `pack.json` (hoy vacío); sin él, valores por defecto.

## Pendiente

- **PE.3 (núcleo):** `godot/addons/creador/hair_chains.gd`. Por debajo de una altura de inicio (sobre el origen de `Head`), los vértices se reparten en N sectores de azimut alrededor de la cabeza; en cada sector con pelo, una cadena `x_pelo_<sector>_<n>` hija de `Head` con articulaciones cada 4,5 cm hasta el vértice más bajo (centro de los vértices de esa franja). Pesos: mezcla de los 2 sectores vecinos × 2 huesos vecinos (≤ 4, suman 1), fundidos con los pesos originales en 3 cm junto al inicio. Binds nuevos en la `Skin` de la pieza. Al quitar el peinado se quitan los huesos `x_`: Skeleton3D no tiene `remove_bone` (solo `add_bone` y `clear_bones`), así que se rehace la lista sin ellos (los `x_` van al final: los índices del cuerpo no cambian). Comprobar antes cómo tratan los huesos de más `SkeletonRefit.apply`, `BodyPiece.attach` (hoy rechaza un hueso que el esqueleto no tiene) y `body_view.set_piece`.
- **PE.4 (editor):** al poner un peinado con cadenas, un `SpringBoneSimulator3D` con una entrada por cadena y colisiones de cabeza (esfera), cuello y hombros (cápsulas). Juicio del responsable en el programa (con animación).
- **PE.5 (exportar):** el `.glb` con los huesos `x_` (que `probar_glb` los acepte y siga exigiendo los humanoides) y una `.tscn` al lado con el simulador (ruta relativa al `.glb`).
