# PE.5 — Exportar el pelo con huesos y física

> Ficha del 2026-11-26 (nivel: fuerte). Sale de `PE_huesos_pelo.md` (PE.5) y sigue a `PE.4_fisica_pelo.md`.
> Decidido por el responsable (2026-11-26): una sola `.tscn`; los huesos de pelo no cuentan en el presupuesto de huesos;
> la prueba en un juego con BoneMap se aplaza a una versión más adelantada. Se ejecuta **después** del paso que corrija el pelo que traspasa
> la piel al moverse (`IDEAS.md`): la `.tscn` hereda lo que haya entonces en `HairPhysics`.

## 1. Objetivo y «Hecho cuando»

Que el `.glb` lleve los huesos `x_pelo_*` del peinado y que al lado salga una `.tscn` que lo instancia con el mismo
simulador del editor, lista para un juego; sin peinado con cadenas, todo como hoy.

1. Con bob02 o long01: el `.glb` tiene los 56 huesos humanoides (nombre y padre del perfil) y los mismos `x_pelo_*`
   que el editor (cada raíz hija de `Head`, cada articulación hija de la anterior); ≤ 4 influencias que suman 1; la
   piel del peinado apunta a los `x_pelo_*`; `CharacterChecks` sin errores; en pose A, igual que sin cadenas (≤ 0,1 mm).
2. Sin peinado con cadenas (neutro, al azar, hair_buzzed): el `.glb` es **idéntico byte a byte** al de antes de PE.5
   (`sha256sum`) y no se escribe `.tscn`.
3. `heroe.tscn`: hereda de `heroe.glb` por **ruta relativa** (solo el nombre del archivo, sin `res://` ni `\`); el
   simulador cuelga del esqueleto con una entrada por cadena y los mismos choques que el editor, todos con hueso que existe.
4. Cargada (con el `.glb` leído de vuelta), la física va como en PE.4: quieto ≤ 2 mm; al girar la cabeza la punta se
   queda atrás ≥ 1 cm y vuelve a ≤ 2 mm; ninguna articulación dentro de un choque más de 5 mm × tamaño de cabeza.
5. Juicio del responsable en un proyecto de Godot vacío (§8): **aplazado** (decidido el 2026-11-26); el paso se cierra
   sin él y queda en `ruta/PENDIENTES.md`.

## 2. Nivel de modelo

Fuerte: `CharacterBaker`, `CharacterChecks`, formato de lo exportado y una API con trampas (`GUIA_MODELOS.md` §2).

## 3. Contexto mínimo

- `character_baker.gd` 27–28, 65–72 y 93–100 (lo que PE.4b hizo para quitar las cadenas). `sockets.gd` 36–80.
- `character_checks.gd` 94–128 y 170–178. `glb_exporter.gd` 266–291 (`write` libera el personaje).
- `hair_physics.gd` 32–89 (`attach`, `refit`). `hair_chains.gd` 34–35 y 250–276 (toda articulación, punta incluida, con bind).
- `body_view.gd` 241–260 (`export_glb`, `start_export`, `finish_export`) y 506–576. `body_actions.gd` 249–301.
- Pruebas: `probar_comprobaciones.gd` 94–155, `probar_glb.gd` 95–116 y 210–215, `probar_piezas.gd` 741–805.

## 4. Archivos

- **PE.5a (aceptar cadenas):** `character_checks.gd`, `pruebas/godot/probar_comprobaciones.gd`, `pruebas/godot/probar_glb.gd`.
- **PE.5b (el `.glb` con cadenas):** `character_baker.gd` y los casos PE.4b de `pruebas/godot/probar_piezas.gd`.
- **PE.5c (la `.tscn`, núcleo):** `godot/addons/creador/hair_scene.gd` (nuevo) y `pruebas/godot/probar_pelo_exportado.gd` (nueva).
- **PE.5d (editor):** `godot/app/body_view.gd`, `godot/app/body_actions.gd` (el aviso nombra la `.tscn`) y un caso en `probar_piezas.gd`.
- **No se tocan:** `glb_exporter.gd`, `sockets.gd`, `hair_chains.gd`, `hair_physics.gd` (se hereda tal cual),
  `pack.json` (campo `fisica`), `blender/`, `datos/`.

## 5. Diseño

**PE.5a.** `CharacterChecks._profile_bones` y `_manifest_bones`: un hueso con `HairChains.is_chain_bone` no cuenta como
ajeno si su padre es `Head` u otro `x_pelo_*`; si no, error en `huesos_del_perfil`. `_budget` **no** los cuenta (decidido: el pelo no es hueso del cuerpo); la prueba lo comprueba con long01 (sin aviso de huesos).
`probar_glb.gd`: exige los 56 del perfil y admite solo `x_pelo_*` con ese padre; con `--pelo`, exige ≥ 1 cadena.

**PE.5b.** `CharacterBaker`: se quitan los dos cambios de PE.4b (el `break` de `prepare_bake` y el paso del bind a la
cabeza en `_read_mesh`). Las cadenas ya van al final; `Sockets.to_nodes` reindexa por nombre y las conserva.
Comprobado (4.7.2): `GLTFDocument` **borra un hueso que no tiene bind en ninguna Skin** y conserva nombre y padre de los
que lo tienen; `HairChains` da bind a todas las articulaciones del peinado, así que salen todas.

**PE.5c.**

```gdscript
class_name HairScene
extends RefCounted
## Mide la copia del simulador (la de start_export) en el personaje que se exporta: choques con su cuerpo y sus ejes.
## Llamarla tras GlbExporter.finish y antes de write. Deja la copia fuera del esqueleto (si no, entraría en el .glb).
static func measure(copy: SpringBoneSimulator3D, character: Node3D) -> void
## Escribe <glb sin extensión>.tscn: hereda del .glb (ruta relativa) y cuelga la copia de skeleton_path.
static func save(copy: SpringBoneSimulator3D, glb_path: String, skeleton_path: String) -> Error
```

1. `measure`: guarda los radios de la copia; la cuelga del esqueleto exportado; `HairPhysics.refit(copy, cuerpo)`
   (el cuerpo es el primer hijo del esqueleto); repone los radios (refit los saca de la escala de `Head`, que en el
   `.glb` ya es 1: perdería el ×2,5); a cada choque, `shape.bone = skeleton.find_bone(shape.bone_name)`; la descuelga.
   Motivo: en pose T los huesos del perfil salen con otros ejes (`profile_axes`) y copiar los desplazamientos del
   editor los giraría. Así cualquier ajuste futuro de `HairPhysics` (el arreglo del traspaso) se hereda sin copiar valores.
2. `save`: dueño de los choques = la copia; quitar sus `meta`; `PackedScene.pack` y `ResourceSaver.save` a un temporal
   (`user://`); leer el texto, borrar el temporal y unirlo: cabecera `[gd_scene format=3]` + `[ext_resource
   type="PackedScene" path="<archivo>.glb" id="1_glb"]`; los `[sub_resource]` (la curva de rigidez) tal cual; antes del
   primer `[node`, `[node name="<archivo>" instance=ExtResource("1_glb")]`; al nodo del simulador, `parent="<skeleton_path>"`;
   en sus hijos, `parent="."` → `parent="<skeleton_path>/<nombre del simulador>"`; quitar los ` unique_id=…`.
3. `skeleton_path` = `"Armature/" + nombre del esqueleto` (lo que escribe `_add_armature_node`; la prueba lo confirma
   leyendo el `.glb` de vuelta).

Comprobado en 4.7.2 (scripts del borrador): `pack` guarda todos los ajustes y la curva; al cargar, los huesos se
resuelven **por nombre** (el índice guardado no manda) y la cadena se mueve; `position_offset` y `rotation_offset` de un
choque **solo se guardan (y se copian con `duplicate`) si su `bone` está resuelto** (por eso el paso 1); la ruta relativa
del `ext_resource` se resuelve junto a la `.tscn` (también con `..`); un nodo nuevo con `parent="Armature/Skeleton3D"`
bajo la escena instanciada carga y simula. Descartado: poner `scene_file_path` a un `.glb` sin importar y empaquetar: lo
incrusta todo (malla y esqueleto dentro de la `.tscn`).

**PE.5d.** `start_export`: `job["hair"]` = `duplicate()` del simulador del peinado (o null; la ranura de pelo es una
sola). `finish_export`: `finish` → si hay copia, `measure` → `write` → si OK, `save` → liberar la copia (también si falla).

## 6. Pruebas

- **PE.5a** `probar_comprobaciones`: «sano con cadena» (neutro + 3 `x_pelo_0_*` bajo `Head`: todo bien) y «roto 6»
  (`x_pelo_0_0` bajo `Hips`: solo `huesos_del_perfil`). Detecta: quitar la excepción → falla «sano con cadena».
  `probar_glb` sigue en TODO BIEN con los `.glb` de `probar_exportar` (T y A) y de `generar_glb_piezas`.
- **PE.5b** `probar_piezas`: «el `.glb` lleva los huesos de pelo» (los mismos que el editor), «la piel del peinado
  apunta a `x_pelo_*`», y el de pose A (≤ 0,1 mm) sigue; `probar_glb -- … --piezas=4 --rigidas=2 --ojos --pelo`
  (hair_long). `sha256sum` de `pruebas/fase_3/salida/t/` y `a/` antes y después: iguales. Detecta: dejar el `break` →
  falla «lleva los huesos de pelo».
- **PE.5c** `probar_pelo_exportado` (sin ventana): bob02 y long01 (normal y Cabeza ×2,5) con `GlbExporter` +
  `HairScene` en `pruebas/godot/salida/pelo_exportado/`; criterios 3 y 4 (para cargarla, la prueba guarda el `.glb`
  leído como `.tscn` y cambia la ruta del `ext_resource` en una copia). Límites: los de PE.4 (aprobados). `MEDIDA` de
  cada valor. Detecta: quitar `refit` de `measure` → falla «quieto» o «dentro de los choques» (si no falla, quitar
  `shape.bone = …` → falla «mismos choques»).
- **PE.5d** `probar_piezas`: exportar con bob02 deja `.glb`, `.tres` y `.tscn`; con hair_buzzed, sin `.tscn`.
  Detecta: no llamar a `save` → falla «deja la `.tscn`».
- Ya fallaban en `f7e89b9`, antes de PE.4: `probar_animaciones` (Jaw, ojos y anclajes sin pareja) y
  `probar_personaje_horneado` (pose T + codo, 6,77 mm). No son de este paso: no confundirlos.

## 7. Trampas conocidas

- El informe (`check_report`) hornea solo el cuerpo: tendrá los `x_pelo_*` sin bind. Por eso PE.5a va antes que PE.5b.
- Presupuesto: con pelo serían 90 (bob02) o 102 (long01); por eso `_budget` cuenta solo los que no son `x_pelo_*`.
- Al importar con BoneMap, el esqueleto podría cambiar de nombre (`GeneralSkeleton`) y romper `parent=`: **NO
  VERIFICADO** (este borrador no podía importar). Plan B: probarlo en §8 (aplazado); si pasa, decirlo en el README.
- Exportar va en un hilo: la copia se hace en `start_export`; cambiar de peinado mientras tanto no la afecta.
- Una `.tscn` vieja junto a un `.glb` nuevo sin cadenas no se borra (no se borran archivos del usuario).
- Si el arreglo del traspaso pone valores que dependen del cuerpo solo en `attach` (no en `refit`), la copia los
  llevaría medidos en el editor: parar y avisar.
- Con Cabeza ×2,5, hair_long sigue hundido en el `.glb` en reposo (`IDEAS.md`); en el juego lo aparta el simulador.

## 8. Juicio visual (del responsable)

**Aplazado** a una versión más adelantada (decidido el 2026-11-26). Cuando se haga:

Proyecto de Godot vacío: copiar `heroe.glb`, `heroe.tres` y `heroe.tscn` (exportados con long01), abrir `heroe.tscn`
con una animación, primero sin BoneMap y luego con el BoneMap humanoide. Preguntas: ¿abre sin errores? ¿el pelo se
mueve como en el editor? ¿atraviesa algo que en el editor no?

## 9. Si te atascas

- Si unir el texto da problemas, plan B: dos archivos (`heroe_pelo.tscn`, entero de Godot, y `heroe.tscn` de 6 líneas
  que instancia el `.glb` y cuelga `heroe_pelo.tscn` del esqueleto). **NO VERIFICADO** (sí el simulador suelto y el
  envoltorio de un archivo).
- Si `GLTFDocument` cambia el nombre de los `x_pelo_*`, parar: el simulador los busca por nombre.
