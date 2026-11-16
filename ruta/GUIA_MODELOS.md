# GUÍA PARA LOS MODELOS — cómo trabajar en GameMolde con una ficha

> Sesión de traspaso (2026-11-16). Para modelos sencillos y baratos que siguen el proyecto.
> `CLAUDE.md` manda. Esta guía dice **cómo** cumplirlo paso a paso. Si algo de aquí choca con `CLAUDE.md`, gana `CLAUDE.md` y se avisa al responsable.
> El responsable es el **auditor visual**: lo visual lo juzga él, no el modelo.

---

## 1. Protocolo de un paso

Siempre en este orden. No se salta ninguno.

1. **Leer.** `CLAUDE.md` entero. La línea «Estado actual» de `PLAN.md` y las 5 últimas filas del registro. La ficha del paso en `ruta/pasos/`. De la ficha, el apartado 3 («Contexto mínimo») dice qué más leer: **eso y nada más**.
2. **Comprobar el nivel.** El apartado 2 de la ficha dice simple, medio o fuerte. Si el nivel es más alto que el tuyo, **dilo y para** (§2 de esta guía).
3. **Comprobar las decisiones.** Si la ficha cita una decisión (`D…`) que en `ruta/DECISIONES.md` no está decidida ni tiene «supuesto», pregunta antes de proponer.
4. **Proponer.** Con el formato de `CLAUDE.md`: `PROPUESTA — Paso X.Y` / Archivos / Qué hace / Cómo se prueba / Riesgos / ¿Apruebas? Máximo 10 líneas. Si la ficha parte el paso en subpasos (a, b, c), una propuesta por subpaso.
5. **Esperar el «OK».** Sin «OK» no se crea, cambia ni borra nada.
6. **Hacer.** Solo los archivos del apartado 4 de la ficha. Siguiendo el diseño del apartado 5: mismas firmas, mismos nombres.
7. **Probar.**
   - La prueba nueva del apartado 6.
   - **Que la prueba detecta el fallo:** romper el código a propósito como dice la ficha, ver que la prueba falla, y deshacer el cambio. Decir en el informe qué se rompió y qué línea de `FALLO` salió.
   - Todas las pruebas sin ventana (§5 de esta guía). Las que necesitan ventana, dar el comando al responsable.
8. **Juicio visual**, si la ficha lo pide (apartado 8): generar las capturas, dar **solo la ruta** y las preguntas. No describirlas ni valorarlas. Esperar.
9. **Cerrar.** Marcar el paso en `PLAN.md`, actualizar «Estado actual» y añadir **una fila** al registro (fecha, paso, qué se hizo, medidas, pruebas que pasan). Informe de 3 líneas: **hecho / cómo se probó / qué sigue**.
10. **Parar.** No empezar el paso siguiente. El commit lo hace el responsable.

Si el paso cambia el aspecto, la malla, los huesos o la exportación: proponer pasar el revisor-visual antes de seguir (`.claude/agents/revisor-visual.md`).

---

## 2. Tabla de reparto

**Simple** = sigue una ficha al pie de la letra. **Medio** = toma decisiones locales dentro de la ficha. **Fuerte** = matemática 3D, formatos, arquitectura o API sin comprobar.

| Tarea | Simple | Medio | Fuerte o con revisión del responsable |
| --- | --- | --- | --- |
| Botones, diálogos y paneles sobre funciones que ya existen | ✔ | | |
| Documentos, README, tablas de medidas, filas del registro | ✔ | | |
| Lanzar pruebas y tabular resultados | ✔ | | |
| Presets, poses, estilos y otros archivos de datos con formato ya definido | ✔ | | |
| Una prueba nueva para una función con firma ya escrita | ✔ | | |
| Función nueva de la interfaz con firma en la ficha | ✔ | | |
| Función nueva del núcleo con firma y algoritmo en la ficha | | ✔ | |
| Refactor mecánico de muchos archivos (por ejemplo A2a) | | ✔ | |
| Cambiar un shader sin cambiar el aspecto por defecto | | ✔ | |
| Elegir entre dos planes B escritos en la ficha | | ✔ | |
| Escribir la ficha detallada de un paso de una ficha breve | | | ✔ |
| Cualquier cosa de transformaciones de huesos, *bind poses*, retargeting o normales | | | ✔ |
| Cambiar el formato de `datos/`, del preset, del proyecto o de un pack | | | ✔ |
| Cambiar `CharacterUpdater`, `SkeletonRefit`, `MeshBaker`, `CharacterBaker` o `GlbExporter` | | | ✔ |
| Hilos, memoria, optimizaciones (`RENDIMIENTO.md` O3, O8, O10) | | | ✔ |
| Una API de Godot marcada «NO VERIFICADO» | | | ✔ |
| Scripts de `blender/` (pipeline de MPFB) | | | ✔ |
| Cambiar el límite de una prueba | | | Solo el responsable (regla 9) |
| Decidir si algo «se ve bien» | | | Solo el responsable |
| Decidir si una licencia vale | | | Solo el responsable |
| Git que cambia el repositorio, instalar, usar la red | | | Solo el responsable (reglas 1 y 8) |

Reparto de las fichas existentes (lo dice el apartado 2 de cada una):

- **Simple:** A1, 4.4a, 4.5a, 4.7b, 5.4, 5.5, 5.6, 5.11, 5.12, 5.14, 6.3, 7.2, 7.3b, 7.4, 8.1 (lanzar y tabular), 8.4.
- **Medio:** A2, A4, 4.4b, 4.4c, 4.5b, 4.6, 4.7 (resto), 5.2, 5.3, 5.8, 5.9, 5.10 (implementar con la ficha), 5.13, 6.2, 7.1, 7.3a, 8.2, 8.3.
- **Fuerte:** A3 (pasa a medio si se parte del borrador de `ruta/codigo/`), 5.1, 5.7, 6.1, 8.5 (preparación), y cualquier cambio al diseño del 5.10.

Si esta lista y el apartado 2 de una ficha no coinciden, **manda la ficha**.

Un modelo de nivel inferior puede hacer un paso de nivel superior **solo** si el responsable lo dice expresamente y revisa el resultado línea a línea.

---

## 3. Señales de alarma: para y pregunta

Cuando aparezca una, se para. Se escribe qué pasó, en 3 líneas, y se espera.

1. **Vas a tocar más de 3 archivos** y la ficha no lo decía. (Si la ficha lo prevé, como en el 4.4b o en A2a, dilo en la propuesta.)
2. **Vas a cambiar el límite de una prueba**, o a añadir una excepción, un `if` especial o un «saltar este caso» para que pase.
3. **Vas a usar una función de Godot que no reconoces** o que está marcada «NO VERIFICADO». Antes de usarla, una comprobación mínima: un script de 10 líneas que la llama e imprime el resultado.
4. **Una prueba pasa «a veces».** Una prueba que falla 1 de cada 10 veces está rota o ha encontrado un fallo real. No se relanza hasta que pase.
5. **Te sales de la ficha:** un archivo de «No se toca», una función que no está en el diseño, una mejora «ya que estoy».
6. **Una prueba que pasaba deja de pasar** y el motivo no es evidente en tu cambio.
7. **Dos documentos se contradicen** (ficha y `PLAN.md`, ficha y código). No elijas: pregunta.
8. **El código real no coincide con lo que dice la ficha** (una función con otra firma, un archivo que no existe). Las fichas se escribieron el 2026-11-16 sobre el commit `61aaee9`; el código puede haber cambiado.
9. **Vas a escribir más de unas 150 líneas** en un paso que la ficha describe como pequeño.
10. **Algo toca los límites del proyecto:** personajes adultos, sin detalle anatómico bajo la prenda base, assets solo CC0 o propios, nada de `referencias/` en operaciones geométricas.
11. **Vas a nombrar `app/` desde `godot/addons/creador/`.** El núcleo no conoce la interfaz (`probar_ventana.gd` lo vigila).
12. **Necesitas instalar algo, usar la red o un comando de git que cambia el repositorio.**

Nunca: «arreglar» una prueba cambiando lo que comprueba; borrar una prueba; inventar una medida; describir una captura sin que te lo pidan; marcar un paso como hecho con una prueba en rojo.

---

## 4. Convenciones que no están en `CLAUDE.md`

- **A6 — Pruebas con recursos importados:** una prueba de la interfaz que use `res://` del proyecto principal (animaciones, packs, textos de licencia, datos tras A2) se lanza con `--path godot`, no con `--path pruebas/godot`:
  `(ulimit -v 4000000; timeout 120 godot --headless --path godot -s ../pruebas/godot/<prueba>.gd)`
  Las pruebas del núcleo siguen con `--path pruebas/godot`. La cabecera de cada prueba (línea «Uso:») dice cuál es su caso.
- **Nombres de archivo en minúsculas**, sin espacios ni tildes. Windows no distingue mayúsculas; Linux, Android y el `.pck` sí (`PLATAFORMAS.md` §1).
- **Rutas con `/` y `path_join`**, nunca `\`.
- **Formato de salida de las pruebas:** líneas `  bien  …` / `  FALLO …`, medidas como `MEDIDA <nombre>: <valor>`, y una línea final `RESULTADO: TODO BIEN` o `RESULTADO: N FALLOS`.
- **Límites nuevos:** se escriben como constantes al principio de la prueba, con el comentario `# PROVISIONAL` hasta que el responsable los apruebe con la medida real (D26).
- **Medidas:** se guardan en `ruta/medidas/<fecha>_<máquina>.md`. No se borran las anteriores.
- **Un log largo no se pega en el chat:** solo las líneas `FALLO`, `RESULTADO`, `MEDIDA` y `ERROR`.
- **Cabecera de cada script nuevo:** qué paso lo creó, qué hace y la línea «Uso:».
- **En Windows (Git Bash):** sin `ulimit -v` (no limita); con `timeout`. Ejecutable de consola de Godot (`ruta/pasos/8.1_pruebas_en_windows.md`).
- **`ruta/` es de consulta.** Los modelos no reescriben las fichas. Si una ficha está mal, se propone la corrección al responsable.

---

## 5. Lanzar todas las pruebas sin ventana

Hasta que exista `pruebas/pasar_sin_ventana.sh` (lo crea la ficha 8.1; se puede adelantar), este bucle hace lo mismo. Desde la raíz del repositorio, en Linux:

```sh
R=$(pwd)
WINDOWED="probar_animacion probar_cara_anime probar_estilo probar_normales_cara probar_prenda probar_prenda_exportada probar_proporciones probar_reajuste_esqueleto probar_rendimiento probar_valores_estilo"
for f in pruebas/godot/probar_*.gd; do
  n=$(basename "$f" .gd)
  case " $WINDOWED " in *" $n "*) echo "$n: SALTADA (necesita ventana)"; continue;; esac
  echo "$n: $( (ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s $n.gd -- "$R" 2>&1) | grep -E 'FALLO|RESULTADO|ERROR' | tail -3 | tr '\n' ' ')"
done
```

Avisos:

- **Los argumentos de cada prueba no son iguales.** El bucle pasa la raíz del repositorio. Antes de fiarse, leer la línea «Uso:» de la cabecera de cada prueba; las que pidan otra cosa (por ejemplo, la ruta a `cuerpo.glb`) se lanzan a mano con su comando. La lista de cuáles son se anota la primera vez en `ruta/medidas/` y se reutiliza.
- La lista `WINDOWED` son las 10 pruebas cuya cabecera dice que necesitan ventana (comprobado con `grep` el 2026-11-16). Una prueba nueva con ventana se añade a la lista.
- Las pruebas con ventana se lanzan sin `--headless`; las lanza el responsable o el modelo si tiene pantalla.
- Las pruebas de Blender (`pruebas/fase_*/probar_*.py`) solo hacen falta si el paso tocó `blender/` o regeneró `datos/`: `(ulimit -v 4000000; timeout 900 blender -b -P <archivo> 2>&1 | grep -E 'FALLO|RESULTADO')`, **una cada vez** (`probar_exportar_datos.py` llegó a tardar 525 s con otras en marcha).
- Resultado esperado: ninguna línea con `FALLO` ni `ERROR`, y el mismo número de pruebas que la vez anterior.

---

## 6. Cómo escribir la ficha detallada de un paso (modelo fuerte)

Las fases 9 a 17 solo tienen ficha breve. Antes de empezar un paso de esas fases, un modelo fuerte escribe `ruta/pasos/<número>_<nombre>.md` con estos 9 apartados, en este orden:

1. **Objetivo** en una frase y **«Hecho cuando»** medible.
2. **Nivel de modelo** y por qué.
3. **Contexto mínimo:** archivos y líneas.
4. **Archivos que se tocan** y **que no se pueden tocar**.
5. **Diseño:** firmas en GDScript, datos que entran y salen, algoritmo en pasos numerados. Cada decisión técnica, tomada y con su motivo en una frase.
6. **Prueba:** qué mide, límite numérico (PROVISIONAL hasta medir) y cómo comprobar que detecta el fallo.
7. **Trampas conocidas.**
8. **Juicio visual:** capturas y preguntas.
9. **Si te atascas.**

Reglas para quien la escribe:

- Leer el código real antes de escribir firmas. No fiarse de la ficha breve.
- Resolver **antes** cada «NO VERIFICADO» que afecte al paso, con una comprobación mínima o con la documentación (con permiso para usar la red). Si no se puede, dejar escrito el plan B.
- Si el paso toca más de 3 archivos, partirlo en subpasos (a, b, c), cada uno con su prueba.
- Empezar cada pestaña o sistema nuevo por la rebanada vertical (★): poca función, de punta a punta.
- La ficha la aprueba el responsable antes de que nadie la ejecute.
- Fichas de ejemplo para copiar el tono y el nivel de detalle: `4.4_simetria_deshacer_restablecer.md` (medio, con subpasos) y `A2_datos_en_el_proyecto.md` (con planes B).

---

## 7. Propuesta de cambios a `CLAUDE.md`

Está en `ruta/propuesta_CLAUDE.md`, como diff. **No está aplicada.** La aplica el responsable al juntar las ramas. Resumen: una línea en «Dónde está cada cosa» que apunta a `ruta/`, una regla 10 sobre las fichas, la tabla de plataformas ya decidida (regla 3) y el modo ligero adaptado a varios modelos. `CLAUDE.md` crece 8 líneas.

---

## 8. Orden recomendado de los próximos pasos

1. **A1** (simple, 2 líneas; pide D4).
2. **4.4** (medio; incluye A4). Subpasos 4.4a, 4.4b, 4.4c.
3. **4.5** (simple; incluye A5).
4. **A2** (medio; pide D5). Antes del 5.1.
5. **4.6**, **4.7** (medio).
6. **A3** + **5.1**, **5.2** (fuerte): banco de pruebas.
7. Resto de la Fase 5 → Fase 6 → Fase 7 → Fase 8.

Cada paso, con su ficha. Si una ficha no existe todavía con los 9 apartados, **no se empieza el paso**.
