# IU.7 — Elegir zona tocando el cuerpo

> Fase IU (`propuestas/expansion_v2.md` §3, IU.7). Decidido el 2026-11-19: dos partes, Opus 5.5 con esfuerzo alto;
> **apagado por defecto** y se enciende en Ajustes (la silueta de zonas ya está abierta y a veces molesta).

## 1. Objetivo y «Hecho cuando»

**Objetivo:** con el ajuste encendido, un clic en el personaje abre la zona tocada, y al pasar el ratón la zona se
ilumina con una descripción breve.

**Hecho cuando:**
- Ajustes tiene la casilla «Elegir zona tocando el cuerpo», apagada por defecto y guardada en `user://ajustes.cfg`.
  Al encenderla, debajo sale una descripción breve: «Haz clic en el cuerpo para abrir su zona. Al pasar el ratón,
  la zona se ilumina».
- **IU.7a:** con la casilla encendida, un clic sin arrastrar en el cuerpo abre su zona (la silueta y el panel
  derecho la siguen). Si se arrastra (girar) o el clic no toca el cuerpo, no cambia nada. Con la casilla apagada,
  todo sigue como antes.
- **IU.7b:** con la casilla encendida, al dejar quieto el ratón sobre el cuerpo, su zona se tiñe del color de
  acento y una etiqueta junto al cursor dice «Brazos · clic para editar». La tinta no se exporta.
- **Para el manual:** explicar la casilla, su descripción y que está apagada por defecto.

## 2. Nivel de modelo

**Fuerte** (rayo + shader). Opus 5.5, esfuerzo alto (decisión del responsable).

## 3. Contexto mínimo

`body_view.gd`, `orbit_camera.gd` (cómo gira con el ratón), `settings_file.gd`, `settings_dialog.gd`, `main.gd`
(Ajustes, `zone_picker`, `slider_panel.open`), `zone_silhouette.gd` (`PARTS`), `addons/creador/character_baker.gd`
(solo para leer las posiciones horneadas), `ruta/ARQUITECTURA.md` §4 (el algoritmo).

## 4. Archivos

- **IU.7a:** se crean `godot/app/zone_ray.gd` y `pruebas/godot/probar_zona_rayo.gd`; se tocan `body_view.gd`
  (señal `zone_touched`), `settings_file.gd` (`get/set_touch_zones`), `settings_dialog.gd` (casilla + descripción),
  `main.gd` (conecta y aplica).
- **IU.7b:** se crean `godot/app/tema/zona.gdshader`; se tocan `zone_ray.gd` (máscara de huesos), `body_view.gd`
  (paso del ratón, etiqueta); se amplía `probar_zona_rayo.gd`.
- **No se toca:** el núcleo (`addons/creador/`), `toon.gdshader`, el exportador.

## 5. Diseño

- **`zone_ray.gd`** (`extends RefCounted`): `BONE_ZONES` (hueso del perfil humanoide → zona de `deslizadores.csv`;
  por ejemplo `Head → Cabeza`, `Neck → Cuello`, `LeftShoulder → Hombros`, `Chest → Pecho`, `Spine → Torso`,
  `Hips → Caderas`, `LeftUpperArm`/`LeftLowerArm → Brazos`, `LeftHand → Manos`, dedos `→ Dedos`, `LeftUpperLeg`/
  `LeftLowerLeg → Piernas`, `LeftFoot`/`LeftToes → Pies`). Un hueso fuera de la tabla → "" (otra especie no rompe).
  - `refresh(mesh, skeleton)`: hornea las posiciones de ahora (formas + pose) con lo que ya da el núcleo, y guarda
    vértices, triángulos, huesos y pesos. Se llama solo si algo cambió desde el último rayo (valores, pose, clip).
  - `pick(from, direction) -> String`: (1) el triángulo más cercano que toca el rayo
    (`Geometry3D.ray_intersects_triangle`); (2) su vértice más cercano al punto; (3) el hueso de mayor peso;
    (4) su zona. Sin choque → "".
  - **Motivo de la CPU:** el algoritmo ya descrito en la arquitectura, sin física (no verificada). Se **mide**
    el tiempo; si un clic tarda más de 100 ms, decirlo antes de seguir.
- **Clic sin arrastrar (`body_view.gd`):** al pulsar, se guarda el punto; al soltar, si se movió menos de 4 px y
  `touch_zones` está encendido, se lanza el rayo (`camera.project_ray_origin/normal`) y, si da zona, se emite
  `zone_touched(zone)`. `main.gd` lo conecta a `slider_panel.open` (como la silueta). La cámara sigue girando igual.
- **Ajuste:** `SettingsFile.get_touch_zones()` (`_read_bool("tocar_zonas", false)`), `set_touch_zones`. El diálogo
  emite `touch_zones_chosen(on)` y enseña la descripción (`theme_type_variation = "Pista"`) solo con la casilla
  encendida.
- **IU.7b:**
  - `zona.gdshader`: `material_overlay` del cuerpo (`unshaded`, `blend_add`, `depth_test` normal): tiñe del color
    de acento, al 25 %, los vértices cuyo hueso de mayor peso está en `uniform float zone_mask[64]` (índice = hueso
    del `Skin`). El color llega de `Tokens` (`acento`). Sin zona → máscara a 0 y `material_overlay = null`.
  - Paso del ratón: un `Timer` de 0,12 s que se reinicia al moverse; al acabar, un rayo. Así no hay un rayo por
    cada movimiento. La etiqueta (`Label`, `mouse_filter = IGNORE`, tipo «Pista») va junto al cursor.
  - **Motivo del overlay:** no cambia el shader del núcleo ni lo exportado (el exportador usa su propio material).

## 6. Prueba (sin ventana)

- **`probar_zona_rayo.gd`** (borra `user://ajustes.cfg` al empezar y al terminar):
  1. Rayos sintéticos de frente, a la altura de cada parte, medida en los huesos: a la frente → Cabeza; a la palma
     → Manos; al muslo → Piernas; al pie → Pies; por encima de la cabeza → "".
  2. Con la casilla apagada (por defecto), un clic sintético en el pecho no cambia la zona abierta; encendida, la
     abre; un arrastre de 20 px no la abre.
  3. La casilla se guarda y la descripción se ve solo encendida.
  4. (IU.7b) Al pasar el ratón, `material_overlay` tiene la máscara de la zona; fuera del cuerpo, `null`. Exportar
     con la zona iluminada da el mismo `.glb` que sin ella.
  - **MEDIDA:** ms de un `refresh` y de un `pick`.
  - **Detecta el fallo:** no mirar si se arrastró → falla la 2; tabla sin `Head` → falla la 1.

## 7. Trampas conocidas

- Los índices de `BONE_INDICES` en el shader son los del `Skin`, no los del esqueleto: la máscara se arma con
  `skin.get_bind_name`/`get_bind_bone`.
- El rayo va contra el personaje en su pose actual, no en reposo: si se anima, se hornea al hacer clic.
- La rueda y Ctrl + arrastrar no deben lanzar rayos.

## 8. Juicio visual

IU.7b: captura `9_zona_iluminada.png` en `pruebas/capturas/ventana/`. ¿Se ve la zona sin tapar el estilo?
