# Propuesta de cambios a `CLAUDE.md`

> Sesión de traspaso (2026-11-16). **No está aplicada.** La aplica el responsable al juntar la rama `traspaso`.
> Objetivo: que `CLAUDE.md` apunte a `ruta/` y siga siendo corto. Crece 8 líneas (de 86 a 94).
> Hay dos bloques: el **bloque 1** se puede aplicar ya; el **bloque 2** depende de decisiones (se indica cuál).

## Bloque 1 — Aplicable ya

```diff
@@ ## Dónde está cada cosa (léelo allí, no lo copies aquí)
 - `PLAN.md` — pasos, estado actual y registro de lo hecho y decidido.
 - `IDEAS.md` — lo que no es del MVP.
+- `ruta/` — el mapa después del traspaso. Antes de cada paso lee **su ficha** en `ruta/pasos/` y `ruta/GUIA_MODELOS.md` (protocolo y señales de alarma). El resto de `ruta/` solo si la ficha lo cita. Es una propuesta: no sustituye a `PLAN.md`.
 - `README.md` — qué es, para qué sirve cada carpeta y licencias.

@@ ## Reglas de oro (no negociables)
-3. **Si dudas, pregunta** (máximo 3 preguntas a la vez). No asumas decisiones pendientes: nombre definitivo, lista de deslizadores (paso 2.1), plataformas.
+3. **Si dudas, pregunta** (máximo 3 preguntas a la vez). No asumas decisiones pendientes: están en `ruta/DECISIONES.md` (nombre definitivo, renderizador, pose de exportación…). Plataformas ya decididas: Linux y Windows, editor completo; Android, solo estudio de poses (no exporta `.glb`).
 9. **Los límites de las pruebas no se tocan solos.** Cambiar el límite de una prueba requiere propuesta y aprobación, con el motivo y la medida real.
+10. **Sin ficha no hay paso.** Cada paso se hace con su ficha de `ruta/pasos/`: solo los archivos que lista y con el diseño que da. Si la ficha pide un nivel de modelo mayor que el tuyo, o aparece una señal de alarma de `ruta/GUIA_MODELOS.md` §3, para y dilo.

@@ ## Modo ligero (ahorro de tokens)
-- Usa Fable para lo difícil; si un paso es sencillo, avísame para cambiar a un modelo más barato.
+- Cada ficha dice su nivel (simple, medio o fuerte). Si el paso es más difícil que tu nivel, avísame para cambiar de modelo; si es más fácil, también.
 - Al cerrar un paso: ejecuta las pruebas, marca el paso y añade una línea al registro de `PLAN.md`, e informa en 3 líneas (**hecho / cómo se probó / qué sigue**).
+- Antes de cerrar: comprueba que la prueba nueva **detecta el fallo** (rompe el código a propósito, mira que salta, deshaz el cambio).

@@ ## Entorno y comandos
 - Pruebas de Godot: proyecto `pruebas/godot/`, `godot --headless --path pruebas/godot -s <script>.gd`
+- Pruebas que usan recursos del proyecto principal (`res://` de `godot/`): `godot --headless --path godot -s ../pruebas/godot/<script>.gd`. Lanzar todas: `ruta/GUIA_MODELOS.md` §5.
+- Nombres de archivo siempre en minúsculas y rutas con `/`: Windows no distingue mayúsculas; Linux, Android y el `.pck` sí.
+- En Windows (Git Bash): sin `ulimit -v` (no limita); con `timeout`.

@@ ## Convenciones de código
 - Cada prueba guarda sus capturas con su propio nombre o carpeta, sin pisar las de otras.
+- Un límite nuevo de una prueba se marca `# PROVISIONAL` hasta que lo apruebe con la medida real.
```


## Bloque 2 — Depende de decisiones

Aplicar cada línea solo cuando su decisión esté tomada.

```diff
@@ ## Arquitectura   (si D5 = a y A2 está hecho)
-- `blender/` prepara el cuerpo con MPFB; `datos/` guarda lo preparado (manifiesto con `version`; si cambia el formato, sube); `godot/addons/creador/` es el **núcleo** y `godot/app/` la interfaz.
+- `blender/` prepara el cuerpo con MPFB; `godot/datos/` guarda lo preparado (manifiesto con `version`; si cambia el formato, sube) y viaja dentro del programa; `godot/addons/creador/` es el **núcleo** y `godot/app/` la interfaz.
+- El personaje es un **diccionario de estado**; todo se recalcula desde él. Solo se edita el personaje vivo; solo se anima, se posa y se exporta el horneado (`ruta/ARQUITECTURA.md` §0).

@@ ## Arquitectura   (si D23 = a, al llegar a la Fase 16)
-- Deslizadores de tres tipos: **Forma** (blend shapes), **Proporción** (escala uniforme de hueso) y **Por crear** (forma pendiente, Fase 6).
+- Deslizadores de tres tipos: **Forma** (blend shapes), **Proporción** (escala de hueso: `escala:`, `largo:`, `grosor:`) y **Por crear** (forma pendiente, Fase 6).

@@ ## Reglas del personaje exportado   (tras decidir D11 con el 5.5 y el 5.7)
-| Pose de reposo | Pose T (MPFB sale en pose A, que rompe los brazos al animar) |
+| Pose de reposo | <la decidida en D11> |

@@ ## Reglas del personaje exportado   (tras el 5.3, si D10 = a)
-| Esqueleto | Nombres de `SkeletonProfileHumanoid`; solo huesos de deformación. En Godot hay que asignar un BoneMap humanoide al importar |
+| Esqueleto | 53 huesos con nombres de `SkeletonProfileHumanoid` (faltan 3 del perfil hasta la Fase 9); solo huesos de deformación; los huesos extra de piezas llevan prefijo `x_` y van al final. En Godot hay que asignar un BoneMap humanoide al importar |

@@ ## Entorno y comandos   (tras fijar el renderizador, A7)
+- Renderizador fijado en `project.godot`: <el decidido tras el 5.13>. No cambiarlo sin un paso del PLAN.
```

## Lo que **no** propongo cambiar

- Las reglas 1, 2, 4, 5, 6, 7, 8 y 9: siguen igual y siguen mandando.
- «Lo visual lo juzgo yo»: sigue igual.
- No se copia a `CLAUDE.md` nada de las fichas ni de `ruta/`: solo se apunta allí (regla 7: simple y corto).

## También habría que tocar, fuera de `CLAUDE.md` (propuestas, sin aplicar)

| Archivo | Cambio | Cuándo |
| --- | --- | --- |
| `PLAN.md`, Fase 7 | El 7.1 pasa a decir «Builds para Linux» (Windows es la Fase 8) y enlaza con A2 | Al aprobar D5 |
| `PLAN.md`, tras la Fase 7 | Añadir las fases 8 a 17 de `ruta/HOJA_DE_RUTA.md` §3, las que se aprueben (D25) | Al cerrar el MVP |
| `PLAN.md`, Fases 4 a 6 | Añadir A1, A2, A3 y el subpaso 4.7c (D27) como pasos, si se aprueban | Ya |
| `IDEAS.md` | «Android (tablet)» pasa a «Android: estudio de poses (decidido)»; las ideas aprobadas de `ruta/IDEAS_AL_LIMITE.md` | Cuando se aprueben |
| `README.md` | «Blender 4.2 o superior» → 5.2.2; requisito de Git LFS | Ficha 7.2 |
| `diseno/GUIA_ESTILO.md` §7 | «56 humanoides» → 53 (D10); aprobar o cambiar las cifras «PROPUESTA» | Paso 5.14 |
