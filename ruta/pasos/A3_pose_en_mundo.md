# A3 — `WorldPose`: la pose como giros en el mundo

> Cambio mínimo de arquitectura (`ARQUITECTURA.md` §2.3). Es la base de los pasos 5.1, 5.2 y 5.9, del estudio de poses y del formato de proyecto. Se hace justo antes del 5.1.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** una función del núcleo que ponga una pose descrita como «cuánto ha girado cada hueso en el mundo respecto al reposo», sin depender de los ejes locales de cada hueso.

**Hecho cuando:** `probar_pose_mundo.gd` pasa sin ventana, incluida la comprobación de que dos esqueletos con ejes locales distintos quedan en la misma pose (articulaciones a menos de 0,01 mm).

## 2. Nivel de modelo

**Fuerte** para escribirlo por primera vez (rotaciones encadenadas: es fácil equivocarse en el orden de un producto). Un modelo **medio** puede hacerlo si sigue el algoritmo del §5 al pie de la letra y la prueba del §6 sale bien a la primera. Si no sale, no debe «probar combinaciones»: para y avisa.

## 3. Contexto mínimo

- `godot/addons/creador/t_pose.gd`, entero (58 líneas): hace algo parecido para los brazos y enseña el estilo.
- `godot/addons/creador/bone_refit.gd`, líneas 40–50 (`arc`).
- `ARQUITECTURA.md` §2.3.

## 4. Archivos

- **Se crean:** `godot/addons/creador/world_pose.gd` y `pruebas/godot/probar_pose_mundo.gd`.
- **No se tocan:** `t_pose.gd`, `character_updater.gd`, `character_baker.gd`.

## 5. Diseño

```gdscript
class_name WorldPose
extends RefCounted
## Pose como giros en el mundo respecto al reposo. Ver ruta/ARQUITECTURA.md §2.3.

## deltas: {nombre de hueso: Quaternion}. Un hueso que no está en deltas sigue a su padre (conserva su giro local de reposo).
## Parte siempre del reposo: aplicarla dos veces da lo mismo. Solo escribe el giro de la pose; no toca posición ni escala.
static func apply(skeleton: Skeleton3D, deltas: Dictionary) -> void

## La pose actual como deltas. Solo guarda los huesos cuyo giro en el mundo difiere del de su padre en más de 0,01°.
static func capture(skeleton: Skeleton3D) -> Dictionary

## Copia la pose de source a target (mismos nombres de hueso, misma pose de reposo; por ejemplo, los dos en pose T).
## hips: nombre del hueso de la cadera; su desplazamiento se copia en proporción a la altura de la cadera.
static func copy(source: Skeleton3D, target: Skeleton3D, hips := "Hips") -> void
```

**Datos comunes** (función privada `_rest_bases(skeleton) -> Array[Basis]`): para cada hueso `i`, `skeleton.get_bone_global_rest(i).basis.orthonormalized()`.

**`apply`**, recorriendo los huesos por índice (en un `Skeleton3D` el padre siempre va antes que el hijo):

1. `rest := _rest_bases(skeleton)`.
2. Dos listas del tamaño del esqueleto: `world_delta: Array[Basis]` y `posed: Array[Basis]`.
3. Para cada hueso `i`, con padre `p`:
   1. `world_delta[i] = Basis(deltas[nombre])` si `deltas` tiene el nombre; si no, `world_delta[p]`; si no tiene padre, `Basis.IDENTITY`.
   2. `posed[i] = world_delta[i] * rest[i]`.
   3. `local = posed[i]` si no tiene padre; si lo tiene, `posed[p].inverse() * posed[i]`.
   4. `skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())`.

**`capture`:**

1. `rest := _rest_bases(skeleton)`.
2. `posed[i]`: se encadenan los giros de la pose: `Basis(skeleton.get_bone_pose_rotation(i))` si no tiene padre; si lo tiene, `posed[p] * Basis(skeleton.get_bone_pose_rotation(i))`.
3. `world_delta[i] = posed[i] * rest[i].inverse()`.
4. Se guarda `nombre → world_delta[i].get_rotation_quaternion()` solo si el ángulo entre `world_delta[i]` y el del padre (identidad si no hay padre) supera 0,01°. Ángulo entre dos bases `a` y `b`: `(a.inverse() * b).get_rotation_quaternion().get_angle()`.

**`copy`:**

1. `deltas := capture(source)`, pero **sin** el filtro del punto 4 (todos los huesos). Para eso, `capture` llama a una función privada `_all_deltas(skeleton) -> Dictionary` y luego filtra.
2. Se quitan de `deltas` los nombres que `target` no tiene.
3. `apply(target, deltas)`.
4. Cadera: `s := source.find_bone(hips)`, `t := target.find_bone(hips)`. `ratio = target.get_bone_global_rest(t).origin.y / source.get_bone_global_rest(s).origin.y`. `target.set_bone_pose_position(t, target.get_bone_rest(t).origin + (source.get_bone_pose_position(s) - source.get_bone_rest(s).origin) * ratio)`.

Decisión técnica: no se usa `get_bone_global_pose()` porque puede devolver un valor viejo en el fotograma en que el esqueleto entra en el árbol (aprendido en el paso 3.3, lo dice la cabecera de `mesh_baker.gd`). Se encadena a mano.

Límite conocido de `copy` en el paso 4: copia el desplazamiento **local** de la cadera; vale si la cadera cuelga de un hueso sin giro (`Root`). Es el caso de los dos esqueletos del proyecto.

## 6. Prueba

`pruebas/godot/probar_pose_mundo.gd`, sin ventana. Carga la especie con `SpeciesData` (como `probar_update.gd`).

| # | Comprobación | Límite |
| --- | --- | --- |
| 1 | `apply(skeleton, {})` deja cada hueso con el giro de su reposo | 0,001° |
| 2 | `apply` con `{"LeftUpperArm": Quaternion(Vector3(0,0,1), PI/2)}`: la dirección codo→muñeca gira exactamente 90° alrededor de Z respecto al reposo | 0,001° |
| 3 | Lo mismo: el antebrazo y la mano (sin delta propio) giran los mismos 90° | 0,001° |
| 4 | `capture()` después del caso 2 devuelve un diccionario con **una** clave, `LeftUpperArm`, y su ángulo es 90° | 0,001° |
| 5 | Aplicar dos veces da la misma pose | 0 exactos |
| 6 | **Ejes distintos:** se crea un segundo `Skeleton3D` con los mismos huesos y las mismas posiciones globales de reposo, pero con cada reposo global girado un ángulo cualquiera (semilla fija) alrededor de un eje cualquiera. Se aplica la misma pose de 6 huesos a los dos. Las posiciones globales de las articulaciones coinciden | 0,01 mm |
| 7 | `copy(source, target)` con el caso 6: mismas posiciones de articulación | 0,01 mm |
| 8 | Cadera: si la de `source` baja 0,10 m y la cadera de `target` está al doble de altura, la de `target` baja 0,20 m | 0,01 mm |

Los límites son PROVISIONALES hasta ver la medida real (D26).

Cómo construir el esqueleto del caso 6: para cada hueso, `global' = Transform3D(global_rest.basis * Basis(eje_al_azar, ángulo_al_azar), global_rest.origin)`; el reposo local es `global'` del padre invertido por `global'` del hueso.

**Que la prueba detecta el fallo:** en `apply`, cambiar `world_delta[i] * rest[i]` por `rest[i] * world_delta[i]`. Los casos 2, 3 y 6 deben fallar. Devolverlo a su sitio.

## 7. Trampas conocidas

- `Basis * Basis` en Godot: `a * b` aplica primero `b` y después `a`. El giro en el mundo va **a la izquierda**.
- `Basis(Quaternion)` y `Quaternion(eje, ángulo)`: el eje debe estar normalizado.
- Con el personaje vivo, los huesos tienen escala en la pose (Proporción). `apply` no la toca: por eso solo escribe el giro.
- En un script `extends SceneTree`, una función propia no puede llamarse `_process` ni `_init` (lo dice `CLAUDE.md`).
- El núcleo no nombra `app/` (lo vigila `probar_ventana.gd`).

## 8. Juicio visual

No hace falta.

## 9. Si te atascas

- Si el caso 6 falla y los casos 1 a 5 pasan, el error está en el orden de un producto. Relee el §5; **no pruebes permutaciones**. Si en dos intentos no sale, para y pregunta.
- Si necesitas tocar `t_pose.gd` o `character_updater.gd`, para: esta ficha no lo permite.
