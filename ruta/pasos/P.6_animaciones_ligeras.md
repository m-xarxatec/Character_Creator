# P.6 — Paquete más ligero: solo las animaciones que se usan

> Pulido (2026-11-18). `godot/datos/animaciones/UAL1_Standard.glb` pesa 7,4 MB y trae 43 animaciones; el editor usa 5
> (`humanoide.json`: Idle_Loop, Walk_Loop, Jog_Fwd_Loop, Sword_Attack, Sitting_Idle_Loop). Ya estaba en `IDEAS.md`.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** el `.glb` que va en el programa lleva solo las 5 animaciones que se usan.

**Hecho cuando:**
- `godot/datos/animaciones/UAL1_Standard.glb` tiene exactamente las 5 animaciones de `humanoide.json`.
- Nodos, esqueleto (skin), malla y los datos de esas 5 animaciones son **idénticos** byte a byte a los del original.
- El `sha256` nuevo está en `humanoide.json`, y pasan `probar_datos`, `probar_pck.sh` y la autoprueba.
- Se mide el tamaño nuevo del `.glb` y del `.pck`, y se apunta en el registro.

## 2. Nivel de modelo

**Medio.** Hay que entender cómo está hecho un `.glb` por dentro (JSON + datos binarios), pero sin geometría.

## 3. Contexto mínimo

`godot/datos/animaciones/humanoide.json` (los clips), `godot/datos/FORMATO.md` (sección de animaciones),
`godot/addons/creador/animation_set.gd` (cabecera), especificación glTF 2.0: `animations`, `accessors`, `bufferViews`.

## 4. Archivos

- **Se crea:** `blender/recortar_animaciones.py` (script de Python **sin** `bpy`: se lanza igual con
  `blender -b -P … -- entrada.glb salida.glb Idle_Loop …` que con `python`) y `pruebas/fase_7/probar_recorte.py`.
- **Se cambian:** `godot/datos/animaciones/UAL1_Standard.glb` (LFS), su `sha256` en `humanoide.json`, `IDEAS.md`
  (borrar la línea), `CREDITOS.md` (decir que es una versión recortada).
- **No se toca:** `pruebas/godot/UAL1_Standard.glb` (la copia completa: la usan `probar_animacion`, `probar_retarget`
  y `crear_bonemap` con otras animaciones), el código del núcleo.

## 5. Diseño

Recortar el JSON del `.glb`, no volver a exportarlo. **Motivo:** reexportar con Blender o con `GLTFDocument` cambiaría
el esqueleto o los ejes (el 5.7 midió lo delicado que es); recortar deja todo lo demás igual byte a byte.

1. Leer el `.glb`: cabecera de 12 bytes, trozo JSON y trozo BIN.
2. Quedarse con las `animations` cuyo `name` está en la lista, en el mismo orden.
3. Marcar como usados los `accessors` que citan los `samplers` que quedan, más los que usan malla, skin y lo demás
   (recorrer todo el JSON buscando claves que apuntan a accessors).
4. Quitar los accessors y bufferViews que nadie usa; renumerar los índices en todo el JSON.
5. Escribir un BIN nuevo solo con los bufferViews que quedan (con relleno a 4 bytes) y ajustar `byteOffset` y
   `buffers[0].byteLength`.
6. Escribir el `.glb` (JSON con relleno de espacios a 4 bytes, BIN con relleno de ceros).

**Por qué solo esas 5:** la Fase 10 (estudio de poses) puede pedir más; entonces se vuelve a lanzar el script con la
lista nueva. El original queda en `pruebas/godot/`.

## 6. Prueba

`probar_recorte.py` (con `blender -b -P` como las demás, o con `python`):
- El recortado tiene 5 animaciones con los mismos nombres.
- Para cada animación, canal a canal: los bytes de entrada y salida de cada sampler son iguales a los del original.
- `nodes`, `skins` y `meshes` son iguales al original (salvo los índices renumerados de accessors), y los bytes de los
  accessors de la malla también.
- Tamaño < 2 MB (`# PROVISIONAL`, hasta medir).
- **Detecta el fallo:** recortar sin renumerar (o dejar fuera un accessor de la malla) → falla la comparación de bytes.

Además, en Godot: `probar_datos.gd`, `probar_animacion` del editor (si carga desde `datos/`), `probar_pck.sh` y la
autoprueba. A mano: las 5 animaciones se ven igual que antes.

## 7. Trampas conocidas

- **No quitar la malla del maniquí:** Godot construye el `Skeleton3D` a partir del `skin`, y el skin cuelga de la
  malla. Sin ella, los huesos se importarían como nodos sueltos.
- El `.glb` va por **LFS**: el archivo cambia y git tiene que subir el nuevo (`git lfs status`).
- `UAL1_Standard.glb.import` es «Keep File»: no cambia, pero Godot puede necesitar que se borre `.godot/imported`.
- Las bufferViews pueden compartirse entre accessors: un bufferView se queda si **cualquiera** de sus accessors se
  queda.

## 8. Juicio visual

Ninguno nuevo si los bytes de las animaciones son iguales. Si quieres: abre el editor y mira las 5 animaciones.

## 9. Si te atascas

Plan B: hacerlo en Blender (importar, borrar acciones, exportar) **solo** si `probar_retarget` y `probar_animacion`
dan las mismas medidas que con el original. Si no, se deja el `.glb` completo y se apunta el motivo.
