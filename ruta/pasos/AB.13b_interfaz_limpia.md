# AB.13b — Interfaz de piezas limpia: sin autor ni licencia (solo en Créditos)

> Ficha del 2026-11-21 (Sonnet 5.5, solo lectura; nada implementado). Decisión del responsable (2026-11-21): en botones, filas, tooltips y ventanas de piezas y prendas, **solo el nombre y el estado de puesta**. Autor y licencia van **solo** en el panel de Créditos (botón «Licencias»). **Sin miniaturas por ahora** (se harán después del shader nuevo: va a `IDEAS.md`). Este paso no crea caché, generador ni tarjetas con imagen.
> Cambia lo que pedía `propuestas/expansion_v2.md` (AB.13: «autor y licencia siempre visibles»): se registra como D45.

## 1. Objetivo y «Hecho cuando»

Las pestañas Pelo, Ropa y Accesorios enseñan por pieza solo su nombre, si está puesta y su selector de color. El panel de Créditos lista todos los packs (`base`, `makehuman`, `quaternius`, `overscore` y los de `user://packs`) con su autor y su licencia.
Hecho cuando: (1) ningún control de esas pestañas lleva autor, licencia o creador en su texto ni en su tooltip; (2) el diálogo «Licencias» nombra cada pack con autor y licencia, y `CREDITOS.md` tiene una fila para cada carpeta de `godot/packs/`; (3) `expansion_v2.md`, `DECISIONES.md` (D45) e `IDEAS.md` recogen el cambio; (4) las pruebas nuevas pasan y detectan el fallo; (5) las 17 pruebas de la línea base dan lo mismo antes y después.

## 2. Nivel de modelo

Medio: una fila quitada de un panel, una función pura con firma en esta ficha, dos pruebas y documentos. No hay matemática 3D ni formatos. **Sonnet 5.5**. No hace falta un modelo fuerte; Fable no (orden del responsable de hoy; `CLAUDE.md` aún dice «Fable para lo fuerte», pero este paso no es fuerte).

## 3. Contexto mínimo (ya leído; releer solo lo que se toque)

- `godot/app/pieces_panel.gd`: la fila de cada pieza (`_add_row`, líneas 40-70). Líneas 4 y 61 (el `Label credit` con `"%s · %s · %s" % [ranura, autor, licencia]`) son **lo único** de `godot/app/` que muestra autor o licencia (comprobado con `grep -n "autor\|licencia" godot/app/*.gd`: el resto son coincidencias de otras palabras). No hay ventana de piezas; el menú «Piezas» de `body_actions.gd` ya se borró en AB.13.
- `godot/app/licenses_dialog.gd` (diálogo «Licencias»: programa MIT + `res://CREDITOS.txt` + Godot) y `godot/app/main.gd` líneas 146-152 (lo crea y lo abre con el botón «Licencias»).
- `godot/addons/creador/pack_library.gd`: `library.packs` (id → `{"carpeta", "datos"}`); `datos` trae `nombre`, `autor`, `licencia`, `origen`, `piezas`.
- `pruebas/godot/probar_licencias.gd` (ya comprueba que `godot/CREDITOS.txt` es copia de `CREDITOS.md` y que cada fila tiene 5 columnas y licencia admitida).

## 4. Medido hoy (solo lectura)

**¿Créditos lista todos los packs?** Casi:

| Pack | Dónde aparece hoy en `CREDITOS.md` (= `godot/CREDITOS.txt`, copias iguales) | Licencia | Falta |
| --- | --- | --- | --- |
| `base` | Solo dentro de la fila «MakeHuman system assets» («piezas del pack base (`godot/packs/base/`…)») | CC0 (el `pack.json` dice `CC0-1.0`, autor «GameMolde (de la malla base de MakeHuman)») | **Fila propia** con el autor y la licencia del `pack.json` |
| `makehuman` | Fila «MakeHuman system assets» (35 assets) | CC0 | nada |
| `quaternius` | Fila «Universal Base Characters (Standard): 5 peinados» | CC0 1.0 | nada |
| `overscore` | Fila «OverScore Proxy 1.5: 5 prendas» | CC0 | nada (está sin commitear: otro agente la está editando) |

Además: (a) **nada comprueba** que cada carpeta de `godot/packs/` tenga fila (`probar_licencias.gd` solo mira las filas que hay); (b) los packs del usuario (`user://packs`) no pueden tener fila en `CREDITOS.md`, y al quitar autor y licencia de las filas de la pestaña **no quedaría ningún sitio donde verlos**; (c) el diálogo muestra el texto de `CREDITOS.txt` tal cual, sin leer los `pack.json`.

## 5. Archivos

- **Se tocan (código):** `godot/app/pieces_panel.gd`, `godot/app/licenses_dialog.gd`, `godot/app/main.gd` (una línea).
- **Se tocan (pruebas):** `pruebas/godot/probar_licencias.gd` (ampliada); **nuevo:** `pruebas/godot/probar_piezas_limpias.gd`.
- **Se tocan (documentos):** `CREDITOS.md` y su copia `godot/CREDITOS.txt` (fila del pack `base`; tras el commit del otro agente, que edita ambos), `propuestas/expansion_v2.md`, `ruta/DECISIONES.md`, `IDEAS.md` (también lo está editando el otro agente: añadir al final de su apartado, sin tocar lo demás), `PLAN.md` solo para cerrar. Frases sueltas que dicen lo contrario y se corrigen con la misma decisión: `diseno/GUIA_INTERFAZ.md` línea 46 («con su color, ranura, autor y licencia»), `ruta/pasos/13_piezas_y_accesorios.md` línea 31 («La biblioteca enseña siempre autor y licencia») y `ruta/ARQUITECTURA.md` línea 258 («Autor y licencia se muestran siempre junto a la miniatura»); `ruta/` es de consulta: **proponer el texto al responsable** antes de cambiarlas.
- **No se tocan:** `godot/addons/creador/` (ni `pack_library.gd`: la lista de packs sale de `library.packs`), shaders, `pack.json` (autor y licencia siguen siendo obligatorios en los datos: es la regla 5), `godot/packs/`, `blender/`, `CLAUDE.md`, `project_io.gd`.
- **Subpasos (más de 3 archivos):** a) línea base; b) interfaz limpia + `probar_piezas_limpias.gd`; c) Créditos (diálogo + fila `base` + prueba); d) documentos.

## 6. Paso previo obligatorio: línea base de las 17 pruebas con ventana y `.sh`

Antes de tocar nada. Desde la raíz del repositorio, con ventana (`DISPLAY=:1` en esta máquina). **La lista es la que sale de las cabeceras («Necesita ventana», «Uso:») el 2026-11-21: 11 de Godot y 6 `.sh`. Si el responsable cuenta otras 17, que lo diga antes de empezar** (no hay un archivo con «las 17»). `GUIA_MODELOS.md` §5 está desactualizada: pone `probar_proporciones` y `probar_reajuste_esqueleto` como con ventana (sus cabeceras dicen `--headless`) y le faltan `probar_hombro_natural`, `probar_legibilidad` y `probar_variante_t`.

Prefijo de cada una: `(ulimit -v 4000000; timeout T godot --path pruebas/godot -s X.gd [args] 2>&1 | grep -E 'FALLO|RESULTADO|ERROR|MEDIDA|medida|GUARDADO')`. T y argumentos:

| # | Prueba | T (s) | Argumentos tras `-s X.gd` |
| --- | --- | --- | --- |
| 1 | `probar_animacion` | 300 | ninguno (opcional `-- archivo.glb nombre`) |
| 2 | `probar_cara_anime` | 600 | ninguno |
| 3 | `probar_estilo` | 600 | ninguno |
| 4 | `probar_hombro_natural` | 300 | ninguno (opcional `-- --salida=…`) |
| 5 | `probar_legibilidad` | 600 | ninguno (opcional `-- --doble`) |
| 6 | `probar_normales_cara` | 600 | ninguno; **antes del 13** |
| 7 | `probar_prenda` | 300 | ninguno |
| 8 | `probar_prenda_exportada` | 300 | ninguno |
| 9 | `probar_rendimiento` | 300 | `-- godot/datos/humana/cuerpo.glb` |
| 10 | `probar_valores_estilo` | 600 | ninguno (sin línea `RESULTADO`: pasa si no hay `ERROR`) |
| 11 | `probar_variante_t` | 300 | ninguno (opcional `-- --salida=…`) |

Los 6 `.sh` (desde la raíz, `sh <ruta> 2>&1 | grep -E 'FALLO|RESULTADO|ERROR|MEDIDA|AUTOPRUEBA|bien'`):

| # | Script | Necesita antes |
| --- | --- | --- |
| 12 | `pruebas/fase_3/probar_importador.sh` | `probar_exportar.gd` (sin ventana: `(ulimit -v 4000000; timeout 300 godot --headless --path pruebas/godot -s probar_exportar.gd …)`) |
| 13 | `pruebas/fase_3/probar_normales_importador.sh` | la prueba 6 |
| 14 | `pruebas/fase_5/probar_overwrite_axis.sh` | `probar_exportar.gd` (y, si existe, `probar_ejes_perfil.gd`) |
| 15 | `pruebas/fase_5/probar_renderizadores.sh` | nada; lanza Forward+, Mobile y Compatibility (tarda) |
| 16 | `pruebas/fase_7/probar_pck.sh` | nada (no necesita plantillas) |
| 17 | `pruebas/fase_7/probar_readme.sh` | nada |

Orden: `probar_exportar` → 6 → 1-5, 7-11 → 12, 13, 14 → 15, 16, 17. **No se lanzan** (no son del paso): `probar_build_linux.sh`, `probar_lanzador.sh`, `empaquetar.sh` (build y release solo si el responsable lo pide), `capturas_de_referencia.sh` y los `capturar_*`, `medir_*`, `generar_miniaturas.gd` (escriben datos o capturas; este último escribe en `godot/datos/`).
Resultado esperado: ninguna línea `FALLO` ni `ERROR`. **Si ya hay un `FALLO` en la base: parar y avisar, no arreglarlo aquí** (señal 6 de `GUIA_MODELOS.md`). Apuntar la tabla (17 filas: pasa o falla, `MEDIDA` si la hay) en el informe y en la fila de `PLAN.md`. Al acabar, `git status --short` no debe mostrar nada nuevo de estas pruebas (sus salidas están en rutas ignoradas: `pruebas/**/salida/`, `pruebas/**/capturas/`).
Después de b y de c se repiten **las mismas 17** y se compara con la base (mismo resultado). Además, sin ventana: `probar_piezas`, `probar_packs`, `probar_licencias`, `probar_panel` y `probar_ventana` (esta última vigila que el núcleo no nombre `app/`).

## 7. Diseño

**b) Interfaz limpia (`pieces_panel.gd`)**
1. Borrar el `Label credit` de `_add_row` (el texto `ranura · autor · licencia` y su `add_child`). Dejar la fila: botón de alternar con `card["nombre"]` (su estado pulsado = puesta, ya lo mantiene `refresh`) y el `ColorPickerButton`.
2. Tooltips: el del botón hoy dice «Poner o quitar (una pieza por ranura: ropa_torso)»; el de la ranura es un nombre interno, no es autor ni licencia, pero tampoco ayuda: queda «Poner o quitar». El del selector («Color de la pieza») no cambia.
3. Cabecera del archivo: quitar «y, siempre a la vista, su ranura, autor y licencia» y dejar «su nombre y su color». Mensaje vacío («Todavía no hay piezas de este tipo.») igual.
4. Sin imágenes ni columnas nuevas: el diseño de filas no cambia. (Si el responsable quiere ver la ranura, es otro paso.)

**c) Créditos (`licenses_dialog.gd`, `main.gd`, `CREDITOS.md`)**
5. Función pura nueva, sin ventana:
   `static func packs_text(packs: Dictionary) -> String` — recibe `library.packs` y devuelve un bloque «== Packs de piezas ==» con una línea por pack, ordenados por id: `<nombre> (<id>) — <autor> — <licencia> — <origen> — <N> piezas`. Sin packs, una línea «Ninguno.».
6. `build_text(program, credits, packs := "")`: añade el bloque entre `Material de terceros` y `Godot Engine` si `packs != ""`. **El tercer argumento es opcional** para que la llamada actual de `probar_licencias.gd` siga valiendo.
7. `func set_packs(library) -> void`: guarda `packs_text(library.packs)` y rehace el texto del `TextEdit` (guardar el nodo en una variable al crearlo en `_init`). `main.gd`: tras crear `licenses`, `licenses.set_packs(body_view.library)`. **A comprobar al implementar:** que `body_view.library` ya existe en ese punto (se usa en la línea 140 con `body_view.species`); si es `null`, no se llama.
   Motivo: los packs de `user://packs` no tienen fila en `CREDITOS.md`; así sus autores se ven en Créditos sin copiar nada de `pack.json` a mano. Los de serie salen dos veces (fila de `CREDITOS.md`, con el origen y el sha256, y línea del bloque): aceptable.
8. `CREDITOS.md` (+ `godot/CREDITOS.txt`, copia exacta): fila nueva «Pack base (`godot/packs/base/`: mallas de ayuda de la malla base de MakeHuman)» | autor del `pack.json` | CC0 | su `origen` | dónde se usa. Texto exacto a acordar con el responsable al proponer; la licencia es la del `pack.json` (`CC0-1.0`), ya cubierta por la fila de MakeHuman. Hacerlo **después** de que el otro agente commitee sus cambios en esos dos archivos.

**d) Documentos**
9. `propuestas/expansion_v2.md`, AB.13 (línea 445): cambiar «y **autor y licencia siempre visibles**» por «y **sin autor ni licencia en las tarjetas o filas de piezas: van solo en el panel de Créditos (D45)**». En la misma línea, «galería de miniaturas (PL.2)» pasa a «por ahora solo el nombre (las miniaturas, en `IDEAS.md`)». Línea 447 (Prueba): «la licencia de cada miniatura coincide con su `pack.json`» → «ninguna fila de piezas muestra autor ni licencia, y Créditos lista cada pack con la licencia de su `pack.json`». Línea 453 («todas las piezas enseñan su licencia») → «todos los packs aparecen con su autor y licencia en Créditos». La línea 400 («ficha con autor y licencia») habla de los datos del `pack.json`: no cambia.
10. `ruta/DECISIONES.md`: fila **D45**, junto a D44 (último código usado: D44). Columnas: Código D45 | Paso AB.13b | Pregunta: «¿Autor y licencia de las piezas, siempre a la vista en cada pieza?» | Opciones: a) Sí (lo que pedía AB.13) · b) No: solo el nombre; autor y licencia, solo en Créditos | Recomendación b) | **Decidida el 2026-11-21 (responsable): b).** Sin miniaturas por ahora: se hacen después del shader nuevo (`IDEAS.md`). Los datos no cambian: `pack.json` sigue exigiendo autor y licencia (regla 5) y `CREDITOS.md` los muestra.
11. `IDEAS.md`: una línea con este texto exacto: «Miniaturas de piezas después del shader nuevo: imágenes comprimidas (WebP o PNG), generadas con un solo comando, sin depender del shader en tiempo de ejecución». Va con las ideas de la interfaz o de las piezas; no se borra nada del archivo.

## 8. Pruebas

Límites: ninguno numérico (todo es presencia o ausencia de texto), así que no hay `# PROVISIONAL`.

- **Nueva `probar_piezas_limpias.gd` (sin ventana; se lanza como `probar_piezas.gd`: `--headless --path pruebas/godot`):** monta un `BodyView` con su `library` y un `PiecesPanel` por cada tipo (`pelo`, `ropa`, `accesorio`) y comprueba:
  1. Hay un botón por cada pieza de la biblioteca de ese tipo que sigue al cuerpo o es accesorio, con `text == card["nombre"]`.
  2. Recorriendo todo el árbol del panel: ningún `text` ni `tooltip_text` contiene el autor ni la licencia de **ningún** pack cargado, ni las palabras «autor», «licencia», «creador», «CC0», «CC-BY». (Se arma la lista de palabras prohibidas con `library.packs`, no a mano: así vale para packs nuevos.)
  3. Un clic en un botón (`view.set_piece`) deja `button_pressed == view.is_on(key)`; quitar la pieza lo desmarca (`refresh`).
  4. La fuente de `pieces_panel.gd` no contiene `["autor"]` ni `["licencia"]`.
  **Detecta el fallo:** volver a añadir el `Label credit` con `card["autor"]` → falla la 2 (y la 4).
- **`probar_licencias.gd` ampliada (sin ventana, `--path godot` como hoy):**
  1. Con una `PackLibrary` que lee `res://packs`: `build_text(…, packs_text(library.packs))` contiene, para cada pack, su id, su autor y su licencia (y «Pack MakeHuman», «Pack Quaternius», «Pack OverScore», «Pack base»).
  2. Una biblioteca con un pack falso en una carpeta temporal de `user://` aparece en el texto con su autor (los packs de usuario se ven en Créditos).
  3. Para cada carpeta de `godot/packs/` con `pack.json`: `CREDITOS.md` tiene una fila que contiene `godot/packs/<id>/` y su columna de licencia empieza por una de `ALLOWED`. La comprobación va en una función que recibe el texto, para poder pasarle una copia rota.
  **Detecta el fallo:** pasar a la función el texto de `CREDITOS.md` sin la fila de `quaternius` (o sin la nueva de `base`) → «falta la fila del pack …»; y `packs_text` sin el autor → falla la 1.
- Regresión: `probar_piezas`, `probar_packs`, `probar_panel`, `probar_ventana`, `probar_licencias` y las 17 de la línea base, igual que antes.

## 9. Riesgos

1. **Las 17 son una lista deducida**, no una fija del proyecto (§6): confirmar con el responsable. Algunas tardan (`probar_renderizadores.sh` corre tres renderizadores) y necesitan pantalla.
2. **Concurrencia:** otro agente edita ahora `CREDITOS.md`, `godot/CREDITOS.txt`, `IDEAS.md`, `godot/packs/overscore/` y `probar_packs.gd`. Los subpasos c y d se hacen cuando ese trabajo esté commiteado, o `probar_licencias` (copia exacta de `CREDITOS.md`) fallará por su causa.
3. **Sin autor ni licencia en la pestaña, un pack de usuario sin fila** solo se ve en Créditos gracias a `packs_text`; sin ese bloque no se vería en ningún sitio. Por eso va en este paso y no se deja para después.
4. `body_view.library` podría ser `null` al crear el diálogo (§7.7). Plan B: pasar la biblioteca al abrirlo (`popup`), no al crearlo.
5. **Frases sueltas contradictorias** en `GUIA_INTERFAZ.md`, `13_piezas_y_accesorios.md` y `ARQUITECTURA.md` (§5): si no se corrigen, el próximo modelo las leerá como regla (señal 7 de `GUIA_MODELOS.md`). Proponer el texto, no reescribir `ruta/` por cuenta propia.
6. `pack.json` conserva el campo `miniatura` (vacío, sin uso): no se toca; no hay formato nuevo.

## 10. Juicio visual (lo hace el responsable)

Capturas en `pruebas/capturas/piezas_limpias/` de las pestañas Pelo, Ropa y Accesorios y del diálogo «Licencias» (bloque «Packs de piezas»); solo se da la ruta. Preguntas: ¿la fila (nombre, estado, color) se entiende sin la línea de autor y licencia?, ¿el bloque de Créditos es suficiente?

## 11. Si te atascas

Si la línea base ya trae un `FALLO`, o `body_view.library` no está al crear el diálogo y el plan B no basta, para y dilo. No se cambian pruebas ni límites para que pasen (regla 9) y no se añade nada de miniaturas ni caché en este paso.
