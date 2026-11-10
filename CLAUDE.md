# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Proyecto:** GameMolde (nombre provisional) — editor de personajes 3D

> Instrucciones para Claude Code. Léelo entero al empezar cada sesión.
> Todo en español. El paso a paso está en `PLAN.md`; lo que no es del MVP, en `IDEAS.md`.

## 1. Qué es

Un programa libre, hecho con Godot, para crear personajes 3D al estilo de VRoid.

**MVP:** pestaña **Cuerpo** (humano) con deslizadores por zonas, y exportación de un `.glb` listo para juegos: huesos reajustados, pesos correctos, perfil humanoide de Godot y puntos de anclaje.

**Meta visual:** el personaje debe verse como una ilustración (anime 3D): color plano, sombra a dos tonos y **contorno negro grueso**. Estilo propio, sin copiar el de ningún juego. Un `.glb` no guarda shaders de Godot, así que el núcleo trae el shader y lo aplica en el editor y en el juego.

---

## 2. Reglas de oro (no negociables)

1. **Nada sin mi aprobación.** Antes de crear, cambiar o borrar archivos, instalar algo, usar la red, hacer commits o ejecutar comandos que cambien el sistema: propón y espera mi "OK". Leer archivos y ejecutar comandos de solo lectura sí está permitido.
2. **Un paso cada vez.** Trabaja solo en el paso actual de `PLAN.md`. Al terminarlo, para, informa y espera.
3. **Si dudas, pregunta.** Si algo no está claro o choca con este archivo, pregunta antes de seguir (máximo 3 preguntas a la vez).
4. **No inventes.** Si no puedes comprobar una API, una versión o una licencia, dilo.
5. **Licencias limpias.** Solo CC0, MIT, Apache 2.0 o GPL. Nada de MB-Lab (AGPL), VRoid ni SMPL. **El editor es MIT** (`LICENSE`): no copies código de MPFB2 (GPL), reimplementa a partir de la documentación y los datos CC0. Solo `blender/` es GPL-3.0+; `datos/` es CC0. Todo asset de terceros se anota en `CREDITOS.md`.
6. **Las ideas nuevas no se construyen:** se apuntan en `IDEAS.md`.
7. **Simple y corto.** Código, documentos y este archivo: lo mínimo que funcione. Si añades una línea a `CLAUDE.md`, que sea corta; si algo ya no sirve, bórralo. Nada de detalles que se ven leyendo el código.

---

## 3. Modo ligero (ahorro de tokens)

- Respuestas cortas: unas 10 líneas como máximo, salvo que pida detalle.
- No repitas archivos enteros ni código que no cambia: muestra solo el cambio.
- Lee solo los archivos y las líneas que necesitas.
- Soy junior: explica cada decisión importante en **una frase sencilla**. Sin teoría larga.
- Informe al cerrar un paso: **hecho / cómo se probó / qué sigue** (3 líneas).
- Usa Fable para lo difícil (fórmulas de huesos, ajuste de prendas, arquitectura). Si un paso es sencillo, avísame para cambiar a un modelo más barato.

### Formato de propuesta

```
PROPUESTA — Paso X.Y
Archivos: …
Qué hace: …
Cómo se prueba: …
Riesgos: …
¿Apruebas?
```

---

## 4. Stack

- **Godot 4.7.2 estable** (edición normal, **no** .NET) con GDScript. Comando: `godot` (`~/.local/bin/godot`).
- **Blender 4.2 LTS o superior** + **MPFB2**, en modo sin ventana: `blender -b -P script.py -- args`. Instalado: **Blender 5.2.2 LTS** (snap, `/snap/bin/blender`). **MPFB 2.0.18** instalado y activado (módulo `bl_ext.blender_org.mpfb`); crea el humano base sin ventana. Pack "MakeHuman system assets" (CC0) instalado en los datos de usuario de MPFB; no trae ropa interior (ver paso 1.2).
- **Datos base:** MakeHuman / MPFB2 (malla, formas, pesos, rigs y proxies, todo CC0).
- **Formatos:** `.glb` (glTF 2.0) de salida; JSON para presets y manifiestos.
- **Sin dependencias nuevas** sin aprobación.

### Comandos

Aún no hay código, así que no hay comandos de pruebas. Añade aquí cada comando real cuando exista (una línea cada uno).

- Crear un cuerpo: `blender -b -P blender/generar_cuerpo.py -- "$PWD/pruebas/fase_1/cuerpos/neutro.json"` (imprime `RESUMEN:` con las medidas; el `.glb` llega en el paso 1.4). El formato del JSON está en la cabecera del script.
- Pruebas de Fase 1 (una por archivo `pruebas/fase_1/probar_*.py`): `blender -b -P pruebas/fase_1/probar_generar_cuerpo.py 2>&1 | grep -E 'bien|FALLO|RESULTADO'`
- Prueba 0.4, desde `pruebas/paso_0_4/proyecto/` (cada script explica su uso en la cabecera):
  - `godot --headless --path . -s crear_bonemap.gd` y luego `godot --headless --path . --import`
  - `godot --headless --path . -s comprobar.gd` (huesos, tamaño, pesos)
  - `godot --path . -s probar_animacion.gd` (con ventana; guarda `../capturas/animaciones.png`)
- GDScript: una función propia no puede llamarse `_process` ni `_init` en un script `extends SceneTree`.

---

## 5. Estructura del repositorio

```
juego_demo/
├── CLAUDE.md · PLAN.md · IDEAS.md · CREDITOS.md · README.md
├── diseno/
│   └── maqueta-pestana-cuerpo.html   # referencia visual de la interfaz
├── blender/                          # scripts Python sin ventana (GPL-3.0+)
├── datos/                            # datos preparados (CC0), con versión
├── referencias/cuerpos/              # conceptos de personajes (solo inspiración; no leer salvo que se pida)
├── godot/
│   ├── addons/creador/               # NÚCLEO: formas, huesos, piezas, exportar
│   └── app/                          # el programa con pestañas
└── pruebas/                          # cuerpos de prueba, renders, informes
```

- Las carpetas ya existen pero están vacías.

- El **núcleo** no depende de la interfaz: se podrá usar después como plugin dentro de Godot o en tiempo de juego.
- La base humana es una **especie**: el código no debe suponer que solo existe la humana.

---

## 6. Reglas técnicas del personaje exportado

| Regla | Valor |
| --- | --- |
| Unidades y ejes | Metros; Y hacia arriba; mirando a +Z (convención de Godot) |
| Pose de reposo | Pose T. MPFB sale en pose A: sin corregir, los brazos se rompen al animar. En la prueba 0.4 se corrigió con *Fix Silhouette* de Godot solo en brazos; en Fase 1 se exporta ya en pose T |
| Esqueleto | Compatible con `SkeletonProfileHumanoid` (56 huesos). El rig *Game engine* cubre 53 (faltan ojos y mandíbula, no obligatorios). Se exporta con los nombres del perfil para no depender del autorrelleno del BoneMap |
| Pesos | Máximo 4 influencias por vértice, y suman 1 |
| Huesos exportados | Solo de deformación |
| Compresión | Sin Draco |
| Puntos de anclaje | `socket_hand_r`, `socket_hand_l`, `socket_back`, `socket_hip` |
| Malla | La base completa de MakeHuman (~13.400 vértices), sin proxy: una sola malla para todos los cuerpos |
| Cuerpo por defecto | Neutro, sin detalle anatómico, con prenda base **pintada** (top y short): atributo de color por vértice `garment` (1 = prenda), que el shader corta en 0,5. No es geometría. **Se puede quitar con un botón** y exportar con o sin ella (nos diferencia de VRoid): la marca `garment` viaja siempre en la malla y lo que se enciende o apaga es el shader |
| Carpeta `datos/` | Manifiesto con `version`; si cambia el formato, sube la versión |

---

## 7. Diseño de la interfaz (pestaña Cuerpo)

**Referencia visual:** `diseno/maqueta-pestana-cuerpo.html` (ábrela en el navegador).

```
┌──────────────────────────────────────────────────────────────────┐
│ [Cuerpo]  Cara y ojos   Pelo   Ropa   Accesorios   Exportar       │
├─────────────────────────────────┬────────────────────────────────┤
│ [Reposo][Caminar][Atacar]  ☑ Simetría │ [Global][Cabeza][Cuello]…  │
│                                 │                                │
│          maniquí 3D             │ Cabeza                         │
│      ● puntos de anclaje        │ Tamaño  ─────●────  Proporción │
│                                 │ Ancho   ────●─────  Forma      │
│                                 │ Alto    ─────●────  Forma      │
├─────────────────────────────────┴────────────────────────────────┤
│                              [Probar huesos]   [Exportar .glb]     │
└──────────────────────────────────────────────────────────────────┘
```

- **Pestañas:** Cuerpo (la única activa en el MVP), Cara y ojos, Pelo, Ropa, Accesorios, Exportar.
- **Vista 3D:** maniquí en vivo, cámara orbital, botones de pose y un interruptor de simetría.
- **Zonas:** Global, Cabeza, Cuello, Hombros, Torso, Pecho, Cintura, Caderas, Glúteos, Brazos, Manos, Dedos, Piernas, Pies.
- **Cada deslizador lleva una etiqueta de tipo:**
  - **Forma:** mezcla de formas (*blend shapes*).
  - **Proporción:** cambia la longitud o la escala de un hueso; la piel lo sigue.
  - **Por crear:** forma propia pendiente de esculpir (Fase 6).
- **Abajo, siempre visibles:** Probar huesos y Exportar .glb.
- **Estilo:** plano y sobrio. Textos de la interfaz en español.

---

## 8. Convenciones de código

- Nombres de código (variables, funciones, archivos de código) en inglés. Textos de interfaz, comentarios, documentación y commits en español.
- Funciones pequeñas; un archivo por responsabilidad.
- Cada cálculo tiene su prueba: mezcla, reajuste de huesos, pesos y exportación.
- **Git lo ejecuto yo.** Claude nunca ejecuta comandos `git` (ni `add`, ni `commit`, ni ningún otro): solo me los da escritos.
- **Commits:** uno por paso, mensaje corto y descriptivo en español, sin autoría ni `Co-Authored-By`.

---

## 9. Al cerrar cada paso

1. Ejecuta las pruebas.
2. Marca el paso en `PLAN.md` y añade una línea al registro.
3. Si surgió una idea fuera del paso, apúntala en `IDEAS.md`.
4. Informe de 3 líneas y espera.

---

## 10. Decisiones pendientes (no las asumas)

- Nombre definitivo (el provisional es GameMolde).
- Lista final de deslizadores del MVP (paso 2.1).
- Plataformas de la primera versión (Linux, Windows).

---

## 11. Referencias

- Datos y licencia de MakeHuman: https://static.makehumancommunity.org/makehuman/faq/are_makehuman_files_free.html
- Exportar desde MPFB2: https://static.makehumancommunity.org/mpfb/docs/exporting.html
- Estrategias de huesos de MPFB2: https://static.makehumancommunity.org/mpfb/developer/rigging_and_posing.html
- Retargeting en Godot: https://docs.godotengine.org/en/4.4/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- `GLTFDocument` (exportar `.glb`): https://docs.godotengine.org/en/4.4/classes/class_gltfdocument.html
- Investigación completa (para el usuario, en claude.ai): https://claude.ai/artifact/1CgNsWVn8JG78wkVCMgFSi
