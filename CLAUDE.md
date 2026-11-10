# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**GameMolde** (nombre provisional): editor libre de personajes 3D hecho con Godot, al estilo de VRoid. Todo en español.

## Dónde está cada cosa (léelo allí, no lo copies aquí)

- `PLAN.md` — pasos, estado actual y registro de lo hecho y decidido.
- `IDEAS.md` — lo que no es del MVP.
- `README.md` — qué es, para qué sirve cada carpeta y licencias.
- `CREDITOS.md` — material de terceros.
- `diseno/maqueta-pestana-cuerpo.html` — cómo es la interfaz.
- Cabecera de cada script — su uso y sus argumentos.

## Reglas de oro (no negociables)

1. **Nada sin mi aprobación.** Antes de crear, cambiar o borrar archivos, instalar algo, usar la red o ejecutar comandos que cambien el sistema: propón y espera mi "OK". Leer y ejecutar comandos de solo lectura sí está permitido.
2. **Un paso cada vez.** Solo el paso actual de `PLAN.md`. Al terminarlo, para, informa y espera.
3. **Si dudas, pregunta** (máximo 3 preguntas a la vez). No asumas decisiones pendientes: nombre definitivo, lista de deslizadores (paso 2.1), plataformas.
4. **No inventes.** Si no puedes comprobar una API, una versión o una licencia, dilo.
5. **Licencias limpias.** Solo CC0, MIT, Apache 2.0 o GPL. Nada de MB-Lab, VRoid ni SMPL. El editor es MIT: no copies código de MPFB2 (GPL), reimplementa desde su documentación. Solo `blender/` es GPL-3.0+. Todo lo de terceros va a `CREDITOS.md`.
6. **Las ideas nuevas no se construyen:** se apuntan en `IDEAS.md`.
7. **Simple y corto.** Código, documentos y este archivo: lo mínimo que funcione. Aquí no se repite lo que ya está en otro archivo o se ve leyendo el código; si algo ya no sirve, bórralo.
8. **Git lo ejecuto yo.** Claude nunca ejecuta comandos `git`: solo me los da escritos. Commits: uno por paso, mensaje corto en español, sin autoría ni `Co-Authored-By`.
9. **Los límites de las pruebas no se tocan solos.** Cambiar el límite de una prueba requiere propuesta y aprobación, con el motivo y la medida real.

## Modo ligero (ahorro de tokens)

- Respuestas de unas 10 líneas, salvo que pida detalle. Muestra solo lo que cambia.
- Lee solo los archivos y las líneas que necesitas.
- Soy junior: cada decisión importante, en **una frase sencilla**.
- Usa Fable para lo difícil; si un paso es sencillo, avísame para cambiar a un modelo más barato.
- Propuesta: `PROPUESTA — Paso X.Y` / Archivos / Qué hace / Cómo se prueba / Riesgos / ¿Apruebas?
- Al cerrar un paso: ejecuta las pruebas, marca el paso y añade una línea al registro de `PLAN.md`, e informa en 3 líneas (**hecho / cómo se probó / qué sigue**).

## Entorno y comandos

- Godot 4.7.2 estable (no .NET), GDScript: `godot`. Blender 5.2.2 LTS + MPFB 2.0.18 (`bl_ext.blender_org.mpfb`), sin ventana: `blender -b -P script.py -- args`.
- Blender 5.2.2 fijo (snap retenido con `snap refresh --hold`): sin actualizaciones automáticas; cambiar de versión solo con un paso del PLAN.
- Sin dependencias nuevas sin aprobación.
- Crear un personaje: `blender -b -P blender/generar_cuerpo.py -- cuerpo.json salida.glb`
- Pruebas de Blender (una por archivo `pruebas/fase_*/probar_*.py`): `blender -b -P <archivo> 2>&1 | grep -E 'FALLO|RESULTADO'`
- Pruebas de Godot: proyecto `pruebas/godot/`, `godot --headless --path pruebas/godot -s <script>.gd`
- En un script `extends SceneTree`, una función propia no puede llamarse `_process` ni `_init`.

## Arquitectura

- `blender/` prepara el cuerpo con MPFB; `datos/` guarda lo preparado (manifiesto con `version`; si cambia el formato, sube); `godot/addons/creador/` es el **núcleo** y `godot/app/` la interfaz.
- El núcleo no depende de la interfaz: se usará también como plugin y en tiempo de juego.
- La humana es una **especie**: el código no debe suponer que es la única.
- Deslizadores de tres tipos: **Forma** (blend shapes), **Proporción** (escala uniforme de hueso) y **Por crear** (forma pendiente, Fase 6).
- `referencias/` es solo inspiración: no la leas salvo que se pida.

## Reglas del personaje exportado

| Regla | Valor |
| --- | --- |
| Unidades y ejes | Metros; Y arriba; mirando a +Z |
| Pose de reposo | Pose T (MPFB sale en pose A, que rompe los brazos al animar) |
| Esqueleto | Nombres de `SkeletonProfileHumanoid`; solo huesos de deformación. En Godot hay que asignar un BoneMap humanoide al importar |
| Pesos | Máximo 4 influencias por vértice, y suman 1 |
| Malla | La base completa de MakeHuman, sin proxy; sin Draco |
| Puntos de anclaje | `socket_hand_r`, `socket_hand_l`, `socket_back`, `socket_hip`: nodos vacíos hijos del hueso |
| Cuerpo | Adulto, neutro, sin detalle anatómico |
| Prenda base | Pintada: color por vértice `garment` (1 = prenda), siempre en la malla; el shader la muestra o la oculta (botón) |
| Estilo | Ilustración (anime 3D): sombra a dos tonos y contorno negro grueso, propio. El shader va en el núcleo, no en el `.glb` |

## Convenciones de código

- Nombres de código en inglés; interfaz, comentarios, documentos y commits en español.
- Funciones pequeñas; un archivo por responsabilidad; cada cálculo con su prueba.

## Referencias

- Licencia de MakeHuman: https://static.makehumancommunity.org/makehuman/faq/are_makehuman_files_free.html
- MPFB2, exportar: https://static.makehumancommunity.org/mpfb/docs/exporting.html
- MPFB2, huesos: https://static.makehumancommunity.org/mpfb/developer/rigging_and_posing.html
- Godot, retargeting: https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- Godot, `GLTFDocument`: https://docs.godotengine.org/en/4.4/classes/class_gltfdocument.html
- Investigación completa: https://claude.ai/artifact/1CgNsWVn8JG78wkVCMgFSi
