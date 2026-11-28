# PE.3 — Cadenas de huesos para el pelo, creadas por el núcleo

> Ficha del 2026-11-26 (nivel: fuerte). Sale de `PE_huesos_pelo.md` (PE.3). Escrita tras investigar (API de Godot,
> VRMC_springBone 1.0, Hair Tool) y medir los peinados con un prototipo fuera del proyecto. **Pendiente del visto
> bueno del responsable.** Límites marcados PROVISIONAL hasta medirlos.

## 1. Objetivo y «Hecho cuando»

Que el núcleo, dado un peinado ya puesto, le cree cadenas de huesos `x_pelo_*` hijas de `Head` y le reparta los
pesos entre ellas, **sin que cambie nada de lo que se ve en reposo**; y que pueda quitarlas. Sin física ni interfaz
(eso es PE.4).

1. `HairChains.build` crea las cadenas al final del esqueleto: los 60 huesos del cuerpo conservan su índice.
2. Cada vértice del peinado tiene ≤ 4 pesos que suman 1 (±1e-4).
3. En reposo, la malla horneada (`MeshBaker.bake`) es la de antes de crear las cadenas: ≤ 0,1 mm, también después de
   cambiar Altura, Cabeza › Alto, Torso y Cuello con `CharacterUpdater.update` (PE.3b). Con Cabeza › Tamaño el pelo
   crece con la cabeza, como en VRoid (opción A, decidida por el responsable el 2026-11-26): lo que pesaba solo en
   `Head` queda igual y lo de las cadenas crece exactamente como la cabeza.
4. Rapados y `hair_simple_parted`: 0 cadenas. Melenas y pelo largo: cadenas hasta su punta (la última articulación a
   ≤ 1 cm del vértice más bajo de su sector).
5. `HairChains.remove` deja el esqueleto con los 60 huesos, el mismo reposo y la misma pose (PE.3b).
6. Dos veces seguidas, el mismo resultado (determinista).

## 2. Nivel de modelo

Fuerte: huesos, bind poses, pesos y cambios en `SkeletonRefit` (tabla de `GUIA_MODELOS.md` §2).

## 3. Contexto mínimo

- `godot/addons/creador/body_piece.gd` (`attach`, `follow`), `skeleton_refit.gd` (`apply`),
  `character_updater.gd` (`update`: formas → reajuste → Proporción → pose T → `follow`).
- `mesh_baker.gd`: `active_shapes`, `cache_shapes`, `add_shape_arrays` (posiciones con formas), `bake`.
- `body_derived.gd:34-60, 133-160`: cómo rehacer una superficie conservando sus formas y `blend_shape_mode`.
- `pruebas/godot/probar_muelle.gd` (PE.2).

## 4. Archivos

- **PE.3a:** `godot/addons/creador/hair_chains.gd` (nuevo) y `pruebas/godot/probar_cadenas_pelo.gd` (nueva).
- **PE.3b:** `skeleton_refit.gd`, `body_piece.gd`, `hair_chains.gd` (`remove`) y la misma prueba.
- **No se tocan:** `godot/app/` (lo conecta PE.4), `pack.json` (el campo `fisica` lo lee PE.4), `blender/`, los
  packs, `CharacterBaker`, `GlbExporter`, `CharacterChecks` (PE.5).

## 5. Diseño

```gdscript
class_name HairChains
extends RefCounted
const PREFIX := "x_pelo_"
const DEFAULTS := {
	"hueso": "Head",            # perfil humanoide: vale para cualquier especie
	"sectores": 8,              # PROVISIONAL
	"separacion": 0.045,        # m entre articulaciones (PE.2: el choque es por articulación)
	"max_articulaciones": 10,
	"largo_minimo": 0.07,       # m colgando por debajo del inicio; menos = sin cadena (0,06 hasta PE.4b)
	"inicio_frente": 0.10,      # m sobre el origen de la cabeza, delante (flequillo)  PROVISIONAL
	"inicio_lados": 0.04,       # m sobre el origen de la cabeza, a los lados y detrás  PROVISIONAL
	"fundido": 0.03,            # m bajo el inicio en que se pasa de los pesos originales a la cadena
	"isla_pequena": 0.10,       # fracción de vértices: una isla menor va entera a un sector
}
## Crea las cadenas y reparte los pesos. Devuelve una lista de cadenas, cada una con los nombres de sus huesos de la
## raíz a la punta ([] si el peinado no cuelga). piece: ya colgada (BodyPiece.attach) y con follow() hecho.
static func build(piece: MeshInstance3D, skeleton: Skeleton3D, settings := {}) -> Array[PackedStringArray]
static func remove(skeleton: Skeleton3D) -> void      # PE.3b
static func is_chain_bone(bone_name: String) -> bool  # empieza por PREFIX
```

**Algoritmo de `build`:**

1. **Posiciones.** Vértices de la superficie 0 con las formas activas (`MeshBaker.active_shapes` + `cache_shapes` +
   `add_shape_arrays`), en el espacio del esqueleto (`piece.transform`, hoy identidad: comprobarlo y parar si no).
2. **Marco de la cabeza.** Origen = `get_bone_global_rest(Head).origin`; arriba = el eje Y de ese reposo; delante =
   +Z del mundo (regla del personaje) ortogonalizado. De cada vértice: altura `h`, azimut `az` (0° delante, + a la
   izquierda del personaje) y radio `r`.
3. **Islas.** Vértices soldados por posición (0,1 mm) y unidos por triángulos. Una isla con menos de `isla_pequena`
   de los vértices toma el azimut de su vértice más bajo, por donde cuelga (el mechón no se rasga entre dos sectores;
   idea de Hair Tool). *Corregido en PE.4a con el OK del responsable: el más alto, en la coronilla, mandaba mechones
   de la espalda a la cadena de delante.*
4. **Sectores.** `sectores` centrados en `s·360/N` (el 0, delante: el flequillo no queda partido). Cada vértice es del
   sector más cercano. Inicio del sector: `inicio_lados + (inicio_frente − inicio_lados)·max(0, cos(centro))`.
5. **Cadena de un sector.** Caída = inicio − `h` mínima de sus vértices. Si es < `largo_minimo`, no hay cadena.
   Articulaciones: `n = ceil(caída / paso) + 1` con `paso = max(separacion, caída / (max_articulaciones − 1))`,
   repartidas a igual distancia de la altura de inicio hasta la más baja. Cada una, en la media cilíndrica (azimut
   circular, radio y altura `h_k`) de los vértices del sector en su franja `|h − h_k| ≤ paso/2` que están en el
   sector también por su propio azimut (corregido en PE.4a); franja vacía =
   interpolada entre sus vecinas. (Media cilíndrica y no cartesiana: la cartesiana se mete hacia dentro de la
   cabeza.)
6. **Huesos.** `x_pelo_<sector>_<k>`, `add_bone` al final; el 0, hijo de `Head`; los demás, del anterior. Reposo
   local = reposo global del padre⁻¹ × global; global con origen en la articulación y su Y hacia la siguiente (la
   punta, como la anterior). Pose = reposo.
7. **Pesos.** Para cada vértice, con `t` = posición entre los dos sectores vecinos (por azimut):
   - Por cada uno de los dos sectores (parte `1 − t` y `t`): si tiene cadena y `h` < su inicio, la parte se reparte
     entre los dos huesos de la cadena más cercanos por altura (mitad y mitad en cada articulación, entero en el
     centro de cada tramo; la punta no lleva peso). Si no tiene cadena o el vértice está por encima, la parte se
     queda con los pesos originales.
   - Junto al inicio, la parte de la cadena se multiplica por `clamp((inicio − h) / fundido, 0, 1)` y lo que falta
     va a los pesos originales.
   - Se juntan los pesos por hueso, se quedan los 4 mayores y se normalizan.
8. **Malla y piel.** Nuevo `ArrayMesh` con los mismos arrays salvo `ARRAY_BONES` y `ARRAY_WEIGHTS`, las mismas
   formas (nombres, `blend_shape_mode` y arrays de cada forma) y el mismo material. `skin.add_named_bind(nombre,
   reposo global⁻¹)` por cada hueso nuevo: en una malla con `Skin`, `ARRAY_BONES` apunta a los binds, no a los
   huesos.

**PE.3b:**

1. `SkeletonRefit.apply`: un hueso que no está en `joints` conserva su reposo local (global = global del padre ×
   reposo local; el padre va antes en el bucle). Así las cadenas siguen a la cabeza.
2. `BodyPiece.follow`: un bind de la pieza cuyo hueso no está en la piel del cuerpo pasa a `get_bone_global_rest⁻¹`
   (con el reposo nuevo, en reposo la piel vuelve a ser la identidad).
3. `HairChains.remove`: guarda nombre, padre, reposo y pose (posición, giro y escala) de los huesos que no son de
   cadena; `clear_bones()`; los vuelve a añadir en el mismo orden (Skeleton3D no tiene `remove_bone`: comprobado en
   4.7.2).

## 6. Prueba: `pruebas/godot/probar_cadenas_pelo.gd`

Uso: `(ulimit -v 4000000; timeout 300 godot --headless --path godot -s ../pruebas/godot/probar_cadenas_pelo.gd)`
(lee los packs: A6).

- **PE.3a**, con `bob02`, `long01`, `ponytail01`, `hair_buzzed` y `hair_long`:
  - Cuenta de cadenas y huesos (`MEDIDA`); los 60 primeros, con el mismo nombre e índice.
  - ≤ 4 pesos y suma 1; padres correctos; la punta a ≤ 1 cm del vértice más bajo de su sector.
  - Reposo: horneado antes y después ≤ `MAX_REST_MM` = 0,1 (PROVISIONAL).
  - `hair_buzzed`: 0 cadenas. Dos veces: lo mismo.
- **PE.3b:** con cadenas, `update` con Altura 0,65 y 1,15, Cabeza › Tamaño ×2,5 y Cabeza › Alto: horneado igual a
  la misma pieza sin cadenas (≤ `MAX_REST_MM`). `remove`: 60 huesos, mismo reposo y pose; el cuerpo hornea igual.
- **Que detecta el fallo:** PE.3a, el bind de los huesos nuevos con la identidad (el horneado se mueve
  centímetros); PE.3b, quitar el cambio de `follow` (falla tras `update` con Altura 0,65).

## 7. Trampas conocidas

- **Prueba con ventana o sin ella:** `bake` lee el esqueleto, no la GPU; debe valer sin ventana.
- **Cambiar la forma de la cabeza después de poner el pelo** deja las cadenas unos milímetros fuera (siguen a la
  cabeza, no a la forma). En reposo no se ve (criterio 3). Si en PE.4 molesta, se rehacen al soltar el deslizador.
- **Para PE.4:** `PoseRetarget` (`pairs` y `target_ref` se dimensionan al crearlo) y `body_view._save_t_pose` usan la
  cuenta de huesos de entonces: con cadenas puestas después, se salen del array. El pelo largo pesaba en
  `UpperChest`/`Spine`: con cadenas cuelga de la cabeza y necesita cápsulas de pecho y espalda, no solo de cuello y
  hombros. El simulador funciona con huesos padre escalados (comprobado: ×0,65 y ×2,5, 0,0 mm).
- **Para PE.5:** con cadenas, el `.glb` lleva huesos que `CharacterChecks` rechaza. PE.4 no se puede cerrar sin
  quitarlos al exportar o sin hacer PE.5.

## 8. Juicio visual

Ninguno en PE.3 (no cambia nada en reposo). El juicio es de PE.4, con el pelo en movimiento.

## 9. Si te atascas

- Si `add_surface_from_arrays` rechaza las formas (formato comprimido de la importación), copiar el patrón de
  `body_derived.subset` con arrays sin comprimir.
- Si tras `clear_bones` la malla del cuerpo deja de seguir al esqueleto, parar: plan B, no quitar los huesos y
  dejarlos inertes (sin pesos) hasta exportar, y avisar.
- Si un peinado sale con cadenas raras (articulación fuera del pelo), medir y proponer otros `DEFAULTS`; no tocar el
  algoritmo sin aprobación.
