# PE.4 — Pelo con movimiento en el editor

> Ficha del 2026-11-26 (nivel: fuerte). Sale de `PE_huesos_pelo.md` (PE.4) y sigue a `PE.3_cadenas_pelo.md`.
> **Pendiente del visto bueno del responsable.** Valores de movimiento PROVISIONAL hasta su juicio en el programa.

## 1. Objetivo y «Hecho cuando»

Que al poner un peinado en el editor el pelo se mueva solo con las animaciones (cuelga, se balancea, vuelve) y no
atraviese cabeza, cuello, hombros ni espalda; y que todo lo que ya funcionaba siga igual.

1. Quieto, el pelo no se mueve: tras 2 s sin movimiento, cada articulación a ≤ 2 mm de su reposo.
2. Al mover la cabeza, el pelo se queda atrás (la punta se separa ≥ 1 cm de su sitio) y vuelve (≤ 2 mm tras 3 s).
3. Ninguna articulación dentro de las colisiones más de 5 mm durante la prueba.
4. Igual con Altura 0,65 y con Cabeza ×2,5.
5. Poner y quitar peinados, animaciones, pose T, «Probar huesos», informe y exportar: sin errores. El `.glb`
   exportado con un peinado con cadenas pasa `CharacterChecks`, no lleva huesos de pelo, su piel apunta a huesos que
   existen y, en pose A, es el mismo que sin cadenas (≤ 0,1 mm). *Corregido con el OK del responsable (2026-11-26): en
   pose T solo se mide (1,1 mm con bob02: las puntas que pesaban algo en el hombro siguen a la cabeza).*
6. Juicio del responsable en el programa: el pelo se mueve de forma natural con las animaciones.

## 2. Nivel de modelo

Fuerte: física nueva, `PoseRetarget`, `CharacterBaker` y el editor (tabla de `GUIA_MODELOS.md` §2).

## 3. Contexto mínimo

- `godot/addons/creador/hair_chains.gd` (PE.3) y `pruebas/godot/probar_muelle.gd` (PE.2: avance a mano, la pose
  simulada solo se lee en `skeleton_updated`).
- `godot/app/body_view.gd`: `set_piece` (500–554), `set_values` (154–172), `_process` (215–231), `_save_t_pose`.
- `pose_retarget.gd` (`_init`, `apply`), `character_baker.gd` (`prepare_bake`, `_read_mesh`).

## 4. Archivos

- **PE.4a (núcleo):** `godot/addons/creador/hair_physics.gd` (nuevo) y `pruebas/godot/probar_fisica_pelo.gd` (nueva).
- **PE.4b (editor):** `godot/app/body_view.gd`, `pose_retarget.gd`, `character_baker.gd` y casos nuevos en
  `pruebas/godot/probar_piezas.gd`.
- **No se tocan:** `pack.json` (el campo `fisica` queda para después), `blender/`, `CharacterChecks`, el formato
  del `.glb` (los huesos de pelo en el `.glb` son PE.5).

## 5. Diseño

```gdscript
class_name HairPhysics
extends RefCounted
const DEFAULTS := {             # todos PROVISIONAL hasta el juicio del responsable
	"rigidez": 1.0, "rigidez_punta": 0.4,   # curva de la raíz a la punta: la punta se mueve más
	"freno": 0.4, "gravedad": 0.2, "radio": 0.015,
}
## Simulador hijo del esqueleto: una entrada por cadena (raíz = chain[0], final = chain[-1]) y las colisiones.
static func attach(skeleton: Skeleton3D, chains: Array[PackedStringArray], body: MeshInstance3D, settings := {}) -> SpringBoneSimulator3D
## Mide de nuevo las colisiones con el cuerpo de ahora (tras cambiar deslizadores) y reinicia la simulación.
static func refit(simulator: SpringBoneSimulator3D, body: MeshInstance3D) -> void
```

1. **Cadenas.** `set_root_bone_name`, `set_end_bone_name` (la punta de PE.3 no lleva peso: hace de cola, sin
   `extend_end_bone`), `set_stiffness` con su curva de amortiguación de `rigidez` a `rigidez_punta`, `set_drag`,
   `set_gravity` hacia −Y, `set_radius`, `set_enable_all_child_collisions(true)`. Centro: el mundo (el personaje no
   se desplaza en el editor).
2. **Colisiones** (hijas del simulador, pegadas a su hueso con `bone_name`): esfera en `Head`; cápsulas en `Neck`,
   `LeftShoulder`, `RightShoulder`, `UpperChest` y `Chest` (el pelo largo cae por la espalda). Tamaño medido del
   cuerpo horneado (`MeshBaker.bake`): para cada hueso, los vértices que pesan sobre todo en él; eje = el del hueso;
   radio = percentil 40 de su distancia al eje (dentro de la piel: el pelo en reposo no debe estar ya chocando).
   Nombres del perfil humanoide: vale para cualquier especie que los tenga; los que falten se saltan.
3. **Comprobación mínima antes de escribir nada** (§3.3 de la guía): con un script de 10 líneas, si una colisión
   pegada a un hueso con escala de pose (×2,5) escala su radio o no, y qué hace `reset()`. Según salga, `refit`
   compensa el radio o no.

**PE.4b:**

1. `body_view.set_piece`: tras `follow`, si la ranura es «pelo», `HairChains.build` y, si hay cadenas,
   `HairPhysics.attach`. Al quitarlo: liberar el simulador, `BodyPiece.detach` y `HairChains.remove`.
2. `set_values`: `HairPhysics.refit` (con el `frame_timer` que ya hay: al soltar, no en cada paso del deslizador).
3. `PoseRetarget.apply` y `capture`: recorren solo los huesos que había al crearlo (`pairs.size()`); los de cadena
   se quedan con su pose. `_save_t_pose` y su bucle de `_process` (ROM): solo hasta el menor de los dos tamaños.
4. Exportar sin huesos de pelo hasta PE.5: en `CharacterBaker.prepare_bake`, los huesos de cadena (los últimos) no
   entran en `names`/`parents`, y en `_read_mesh` cada bind de cadena pasa al primer antecesor que no es de cadena
   (`Head`). Exacto: en reposo y en pose T la cadena está quieta respecto a la cabeza.

## 6. Pruebas

- **`probar_fisica_pelo.gd` (PE.4a, sin ventana, avance a mano como PE.2):** con `bob02` y `long01` sobre la
  especie: quieto 2 s (criterio 1); la cabeza gira 30° y vuelve (criterio 2); ninguna articulación dentro de las
  colisiones (criterio 3); lo mismo con Altura 0,65 y Cabeza ×2,5 (criterio 4). `MEDIDA` de cada valor.
  Que detecta el fallo: `set_stiffness` a 0 → falla «vuelve».
- **`probar_piezas.gd` (PE.4b):** poner y quitar `bob02` con un clip en marcha y en ROM sin errores; con cadenas,
  el `.glb` pasa `CharacterChecks` y hornea igual que sin cadenas (≤ 0,1 mm); tras quitarlo, 60 huesos.
  Que detecta el fallo: quitar el cambio de `_read_mesh` → falla «pasa CharacterChecks».

## 7. Trampas conocidas

- La pose simulada no se ve con `get_bone_global_pose` fuera de `skeleton_updated` (PE.2): el informe y la
  exportación leen la pose sin simular, que es la que deben leer.
- El simulador se reinicia (`reset()`) al cambiar el cuerpo o la animación; si no, la cadena salta.
- Pelo largo y Cabeza ×2,5: el pelo crece con la cabeza (PE.3b, opción A) y puede llegar al suelo; las colisiones
  de pecho y espalda lo apartan del cuerpo, no del suelo.
- Rendimiento: long01 tiene 8 cadenas y 68 huesos. Medir el coste por fotograma (`MEDIDA`); si pasa de ~1 ms,
  avisar antes de seguir.

## 8. Juicio visual (del responsable)

Comando: `(ulimit -v 4000000; timeout 900 godot --path godot)`. Poner bob02, long01, ponytail01 y hair_long;
reproducir varias animaciones. Preguntas: ¿se mueve de forma natural? ¿demasiado rígido o demasiado suelto?
¿atraviesa algo? Los valores de `DEFAULTS` se ajustan con lo que diga.

## 9. Si te atascas

- Si las colisiones medidas dejan el pelo empujado en reposo, bajar el percentil o el radio y medir; no quitar
  colisiones sin avisar.
- Si `SpringBoneSimulator3D` se comporta distinto en el editor que en la prueba (modo de proceso), parar y medir.
