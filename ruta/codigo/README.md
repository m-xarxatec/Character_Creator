# `ruta/codigo/` — borradores del código difícil

> Escritos por el modelo fuerte el 2026-11-16, en una máquina **sin Godot**. **Ningún archivo de aquí se ha ejecutado.**
> Son borradores: no están en `godot/` ni en `pruebas/` a propósito, para no chocar con los cambios sin subir del otro ordenador y para que nada sin probar entre en el núcleo.
> Cada pieza es la parte de nivel **fuerte** de un paso. Con esto, colocarla y probarla pasa a ser trabajo de nivel **medio**.

## Qué hay

| Pieza | Código (`nucleo/`) | Prueba (`pruebas/`) | Paso y ficha | Cuándo se usa |
| --- | --- | --- | --- | --- |
| Pose como giros en el mundo | `world_pose.gd` | `probar_pose_mundo.gd` | A3 (`pasos/A3_pose_en_mundo.md`) | Ya: antes del 5.1 |
| IK de dos huesos | `two_bone_ik.gd` | `probar_ik.gd` | 10.10 (`pasos/10_proyecto_y_estudio.md`) | Fase 10 |
| Formato de proyecto `.gmolde` | `project_file.gd` | `probar_proyecto.gd` + `datos/proyecto_v1.gmolde` | 10.1 | Fase 10 |
| Largo y grosor de hueso | `bone_shape.gd` | `probar_forma_hueso.gd` | 16.1 (`pasos/16_especies_y_extremos.md`) | Fase 16 |
| Generador de cuernos | `horn_generator.gd` | `probar_cuernos.gd` | 13.5 (`pasos/13_piezas_y_accesorios.md`) | Fase 13 |
| Transferir formas y pesos a la ropa | `shape_transfer.gd` | `probar_transferencia.gd` | 12.1 (`pasos/12_ropa.md`) | Fase 12 |

`pruebas/esqueleto_de_prueba.gd` es un esqueleto humanoide mínimo hecho por código. Lo usan las pruebas de pose, IK y hueso. Va siempre **en la misma carpeta** que ellas.

Ninguna prueba necesita `datos/`, Blender ni ventana. Ninguna pieza nombra `app/`.

## Cómo probar un borrador (primer paso en la máquina con Godot)

Desde la raíz del repositorio. Las pruebas buscan el núcleo primero en `godot/addons/creador/` y, si no está, en `ruta/codigo/nucleo/`: se pueden lanzar **sin mover nada**.

```sh
R=$(pwd)
for t in pose_mundo ik proyecto forma_hueso cuernos transferencia; do
  echo "== $t"
  (ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s "$R/ruta/codigo/pruebas/probar_$t.gd" 2>&1) | grep -E 'FALLO|MEDIDA|RESULTADO|ERROR'
done
```

- Que `-s` acepte una ruta de fuera del proyecto: **NO VERIFICADO**. Si Godot no encuentra el script, copiar `ruta/codigo/pruebas/*` (con la carpeta `datos/` y `esqueleto_de_prueba.gd`) a `pruebas/godot/` y lanzar con `-s probar_<nombre>.gd`. No hay que cambiar nada dentro: las rutas se calculan solas.
- Resultado esperado de cada una: `RESULTADO: TODO BIEN`.

## Qué puede fallar la primera vez, y quién lo arregla

| Qué sale | Qué es | Quién |
| --- | --- | --- |
| `Parse Error`, `Cannot infer the type`, `Invalid call`, `Invalid operands` | Errores de escritura: el código no se pudo compilar aquí. Se arregla la línea que dice el mensaje (casi siempre, poner el tipo a mano: `var x: Vector3 = …`) | Modelo simple o medio |
| Aviso de variable que tapa a otra (`shadowed`) | No es un error. Se puede renombrar | Modelo simple |
| `FALLO` con una medida **muy cerca** del límite (por ejemplo 0,012 mm con límite 0,01) | Precisión de los números de 32 bits. Los límites son PROVISIONALES: se propone el nuevo con la medida real (regla 9, D26) | Modelo medio, con aprobación |
| `FALLO` con una medida **lejos** del límite (milímetros o grados enteros) | El cálculo está mal. **No probar combinaciones.** Parar y llevarlo a un modelo fuerte con la línea de `FALLO` | Modelo fuerte |
| `probar_forma_hueso`: falla «sin cizalla» o «gira entero» | El diseño de `ARQUITECTURA.md` §2.2 no vale. Parar: hay que replantear la Fase 16 | Modelo fuerte |

Después de que una prueba pase, hacer la comprobación de **«que detecta el fallo»** que está escrita en su cabecera (romper una línea concreta, ver que salta, deshacer).

## Cómo colocar una pieza (cuando llegue su paso)

1. Propuesta y «OK», como cualquier paso (`GUIA_MODELOS.md` §1).
2. Copiar el archivo de `nucleo/` a `godot/addons/creador/` y su prueba (y `esqueleto_de_prueba.gd`, si la usa) a `pruebas/godot/`. Borrarlos de `ruta/codigo/` en el mismo commit, para que no haya dos copias.
3. En la cabecera de la prueba, cambiar la línea «Uso:» por la habitual: `godot --headless --path pruebas/godot -s probar_<nombre>.gd`.
4. Lanzar la prueba y todas las demás sin ventana.
5. Seguir con el resto de la ficha del paso (la integración en la interfaz o en `CharacterUpdater` **no** está hecha aquí).

## Notas de cada pieza

### `world_pose.gd` (A3)

Sigue la ficha A3, con estas diferencias, todas a más:

- `copy` mueve la cadera **en el mundo** (la ficha lo hacía en local y solo valía si el padre de la cadera no tenía giro). Ya no tiene ese límite.
- Funciones añadidas: `all_deltas` (la usa la IK), `mirror` (pose en espejo, paso 10.4), `to_data` y `from_data` (para guardar la pose en el proyecto) y `angle_between`.
- `angle_between` usa `atan2`. `Quaternion.get_angle()` usa `acos` y, con números de 32 bits, no distingue ángulos de menos de unas centésimas de grado: con ella, `capture` guardaría huesos que no se han movido.
- La prueba usa el esqueleto de juguete en dos versiones (ejes del mundo y ejes girados al azar) en lugar de la especie. Al colocarla, conviene añadir un caso con la especie real (`SpeciesData`), como pide la ficha A3 §6.

### `two_bone_ik.gd` (10.10)

- `solve` es una función pura (posiciones → giros). `apply` la usa sobre un esqueleto y escribe la pose con `WorldPose`.
- El codo o la rodilla se doblan hacia el punto `pole`. Sin polo útil, conservan el lado que ya tenían.
- La cadena nunca se estira del todo (99,99 %): así el codo no pierde su plano. Un objetivo en ese último 0,01 % cuenta como «no llega».
- La mano o el pie conservan su giro en el mundo por defecto (`keep_tip_rotation`).
- Falta, y es del paso 10.10: de dónde sale el polo en la interfaz (propuesta: codo hacia atrás y abajo; rodilla hacia delante), los límites de articulación del 5.9 y el arrastre con el ratón.

### `project_file.gd` (10.1)

- No depende de `Preset`: el preset de cada personaje se guarda tal cual. Quien abre el proyecto llama después a `Preset.from_dict` con cada uno.
- Las claves desconocidas se **conservan** y salen como avisos. Las versiones mayores se **rechazan** (D18).
- Los números se escriben a 6 decimales y los enteros sin decimales, para que «mismo proyecto, mismo texto» se cumpla aunque JSON lea `2` como `2.0`. Que el texto sea idéntico entre **versiones distintas de Godot**: NO VERIFICADO (depende de cómo escriba los decimales `JSON.stringify`).
- `datos/proyecto_v1.gmolde` es el archivo fijo de regresión: **no se regenera nunca**. Al colocarlo, va a `pruebas/godot/datos/`.
- No valida poses con `WorldPose.from_data` ni piezas contra los packs: eso lo hace quien las usa.

### `bone_shape.gd` (16.1)

- Es la comprobación del diseño de `ARQUITECTURA.md` §2.2. La prueba mueve una nube de puntos con la misma fórmula que Godot (pose global × *bind pose*).
- Mejora respecto al documento: el hijo no se traslada «a lo largo del hueso», sino a donde la escala lleva su cabeza. Así un hijo fuera del eje (los dedos respecto a la mano) también sigue pegado a la malla.
- **No es idempotente**: hay que llamarla una vez después de cada `SkeletonRefit.apply` y antes de `Proportions.apply`.
- Falta, y es del paso 16.1: el prefijo `largo:` / `grosor:` en `Proportions._parse` (D23), pasar los ejes desde `SkeletonRefit` (`tail − head` de `articulaciones.json`), usar `BoneShape.normal_basis` en `MeshBaker._skin`, y probar con la malla real y con el horneado.

### `horn_generator.gd` (13.5)

- Función pura: parámetros → malla. En el proyecto se guardan los parámetros (`clamped`), no la malla.
- No se fía del orden de los vértices de cada triángulo: lo comprueba con el primero y, si mira hacia dentro, da la vuelta a todos.
- `build_arrays` devuelve también `centers`, la línea central: sirve para poner huesos a lo largo (colas, paso 13.6).
- Falta: la costura de UV (no hay texturas todavía), la ficha de pieza, el panel de deslizadores y el juicio visual con el toon y el contorno.

### `shape_transfer.gd` (12.1)

- Es para la **herramienta** que crea un pack, no para el editor en vivo. Trabaja con listas, sin nodos.
- La prenda se ata al triángulo más cercano **que mire hacia el mismo lado** que su normal. Es lo que resuelve axilas y entrepierna; la prueba tiene ese caso montado a propósito.
- `follow` recoloca cada vértice respecto al triángulo ya movido: la prenda conserva su separación de la piel. Cada forma se calcula al 100 %; al 50 % la tarjeta gráfica mezcla en línea recta (la prueba comprueba que sigue valiendo).
- `covered` y `poking` dan la medida de la Fase 12: vértices de piel que asoman. Debe ser 0.
- Rendimiento: usa una rejilla de celdas. La prueba imprime `MEDIDA` con los tiempos. Con el cuerpo real (26.756 triángulos) y una prenda de unos miles de vértices, por medir.
- Falta, y es del paso 12.1: leer la prenda (`.mhclo` + `.obj`, con lector propio), sacar las listas de la malla del cuerpo (`surface_get_arrays` y `surface_get_blend_shape_arrays`, restando la base), escribir el `.glb` de la pieza con sus formas, y la lista de vértices «dudosos» para revisarlos a mano.
- Límite conocido: una prenda holgada lejos de la piel (una falda) no debe seguir al triángulo más cercano; para eso son los huesos de muelle (12.6).
