# A2 — `datos/` dentro del proyecto de Godot

> Cambio mínimo de arquitectura (`ARQUITECTURA.md` §9). Decisión D5. Hacerlo **antes del 5.1** (las animaciones también vivirán dentro del proyecto) y, como muy tarde, antes del 7.1.
> Se hace en tres subpasos, cada uno con su propuesta y su commit: **A2a** mover, **A2b** localizador y autoprueba, **A2c** prueba desde un `.pck`.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** que el editor encuentre `datos/` igual en desarrollo, en un build de Linux o Windows y dentro de un APK.

**Hecho cuando:** el proyecto empaquetado en un `.pck` y lanzado **desde otra carpeta** carga la especie y exporta un `.glb` (la autoprueba imprime `AUTOPRUEBA: TODO BIEN`), y todas las pruebas que ya pasaban siguen pasando.

## 2. Nivel de modelo

**Medio.** A2a es mecánico pero toca unos 25 archivos (una línea en cada uno). A2c tiene 4 puntos «NO VERIFICADO» de Godot (`PLATAFORMAS.md` §2): si alguno falla, hay plan B escrito aquí. Un modelo simple puede hacer A2a con esta ficha; A2b y A2c, mejor uno medio.

## 3. Contexto mínimo

- `PLATAFORMAS.md` §2, entero.
- `godot/app/body_view.gd`, líneas 70–88.
- `godot/addons/creador/species_data.gd`, líneas 27–55 y 77–83.
- `datos/FORMATO.md`, líneas 1–16.
- Para A2a: `grep -rln --exclude-dir={capturas,salida,referencias,__pycache__,.godot} 'datos' pruebas blender godot` (la lista de archivos que nombran la carpeta).

## 4. Archivos

**A2a (mover):**
- Se mueve la carpeta `datos/` → `godot/datos/` (incluido `FORMATO.md`).
- Se cambia la ruta en: cada prueba de `pruebas/godot/*.gd` y `pruebas/fase_*/*.py` que la nombre, `blender/exportar_datos.py` (ruta de salida y su cabecera), `godot/app/body_view.gd` (`_data_folder`), `.gitattributes` (si A1 ya está hecho) y los textos de `CLAUDE.md`, `README.md` y `PLAN.md` que digan `datos/` (estos tres, como propuesta de texto para el responsable).
- Archivos nuevos: `godot/datos/humana/cuerpo.glb.import` y `godot/datos/humana/deslizadores.csv.import` (los escribe el editor de Godot, ver §5).

**A2b:** `godot/app/body_view.gd`, `godot/app/main.gd` (autoprueba), prueba nueva `pruebas/godot/probar_datos.gd`.

**A2c:** `godot/export_presets.cfg` (nuevo; solo el preset «Linux») y `pruebas/fase_7/probar_pck.sh` (nuevo).

**No se toca:** el contenido de ningún archivo de `datos/` (los `sha256` no cambian), `godot/addons/creador/` salvo lo que diga el plan B del §5, y los límites de las pruebas.

## 5. Diseño

### A2a — Mover

1. Mover la carpeta con `mv datos godot/datos` (es un cambio de archivos, no un comando de git; git lo verá como renombrado cuando el responsable haga el commit).
2. En cada archivo de la lista del §3, cambiar `datos/humana` por `godot/datos/humana` **solo cuando sea una ruta desde la raíz del repositorio**. Patrón habitual en las pruebas: `root_dir.path_join("datos/humana")`.
3. Abrir el editor de Godot una vez sobre `godot/` (lo hace el responsable): en el panel Sistema de archivos, seleccionar `datos/humana/cuerpo.glb` → pestaña **Importar** → «Importar como»: **Keep File (exported as is)** → Reimportar. Lo mismo con `deslizadores.csv`. Godot escribe los dos `.import`. Se guardan en git.
4. `body_view.gd`: `_data_folder()` pasa a devolver, de momento, `…/datos/humana` una carpeta por encima del script (antes eran dos). El localizador definitivo es A2b.

Decisión técnica: «Keep File» en vez de una carpeta `.gdignore`, porque «Keep File» es el camino documentado para que un archivo entre tal cual en la exportación (ya lo cita `datos/FORMATO.md`), y con `.gdignore` no está comprobado que el exportador lo incluya.

### A2b — Localizador único y autoprueba

```gdscript
# godot/app/body_view.gd
const DATA_RES := "res://datos"   # dentro del proyecto y del .pck

## Carpeta de la especie. Primero la del proyecto; si no existe (pruebas que cargan este script desde otro proyecto),
## la que está junto a este script.
func _data_folder() -> String:
    var packed := DATA_RES.path_join(SPECIES)
    if FileAccess.file_exists(packed.path_join("manifiesto.json")):
        return packed
    var app_folder := ProjectSettings.globalize_path(get_script().resource_path.get_base_dir())
    return app_folder.path_join("../datos").path_join(SPECIES).simplify_path()
```

```gdscript
# godot/app/main.gd — al final de _ready()
## Autoprueba para builds: `programa -- --autoprueba`. Carga, exporta a user:// y sale con 0 o 1.
func _self_test() -> void
```

Algoritmo de `_self_test` (solo si `"--autoprueba" in OS.get_cmdline_user_args()`):
1. Si `body_view.error != ""` → `print("AUTOPRUEBA: FALLO ", body_view.error)` y `get_tree().quit(1)`.
2. `var path := "user://autoprueba.glb"`; `var err := GlbExporter.save(species.mesh, species.skeleton, species.manifest["bones"]["sockets"], path, true)`.
3. Si `err != OK` o no existen `user://autoprueba.glb` y `user://autoprueba.tres` → FALLO y `quit(1)`.
4. `print("AUTOPRUEBA: TODO BIEN")` y `quit(0)`.

Motivo: un build de Windows o un APK no pueden lanzar las pruebas de `pruebas/`; esta autoprueba es lo único que se puede ejecutar dentro del programa ya exportado.

### A2c — Prueba desde un `.pck`

1. Crear `godot/export_presets.cfg` **desde el editor** (Proyecto → Exportar → Añadir → Linux). No escribirlo a mano: las opciones cambian entre versiones de Godot. En la pestaña Recursos: «Exportar todos los recursos» y, en «Filtros para exportar archivos que no son recursos», `datos/*`.
2. `pruebas/fase_7/probar_pck.sh`:
   ```sh
   #!/bin/sh
   # A2c: empaqueta el proyecto y lo lanza desde otra carpeta, sin los archivos sueltos.
   # Uso: pruebas/fase_7/probar_pck.sh 2>&1 | grep -E 'AUTOPRUEBA|ERROR'
   set -e
   here=$(cd "$(dirname "$0")" && pwd)
   out="$here/salida/pck"
   rm -rf "$out"; mkdir -p "$out"
   (ulimit -v 4000000; timeout 300 godot --headless --path "$here/../../godot" --export-pack "Linux" "$out/gamemolde.pck")
   cd "$out"
   (ulimit -v 4000000; timeout 120 godot --headless --main-pack gamemolde.pck -- --autoprueba)
   ```
3. Si el paso 2 falla, aplicar el plan B que corresponda y repetir:

| Síntoma | Plan B (en `species_data.gd`; cambio del núcleo: pide aprobación) |
| --- | --- |
| «No se puede abrir …cuerpo.glb» | En `_load_scene`: `var bytes := FileAccess.get_file_as_bytes(path)` y `document.append_from_buffer(bytes, "", state)` en vez de `append_from_file` |
| «El sha256 de … no coincide» con archivos correctos | Calcularlo con `HashingContext` sobre `FileAccess.get_file_as_bytes(path)` |
| «No se puede leer manifiesto.json» | El `.json` no entró en el `.pck`: revisar el filtro `datos/*` del preset |
| `deslizadores.csv` vacío o con extensión `.translation` | No está como «Keep File»: repetir A2a, punto 3 |

## 6. Prueba

- **A2a:** todas las pruebas sin ventana que pasaban antes. Lista mínima: `probar_carga`, `probar_formas`, `probar_update`, `probar_presets`, `probar_exportar`, `probar_panel`, `probar_vista`, `probar_ventana`. Mismo número de comprobaciones y `TODO BIEN`. Además: los 4 `sha256` de los archivos movidos, idénticos a los de antes.
- **A2b:** `probar_datos.gd` (sin ventana): `_data_folder()` devuelve una carpeta con `manifiesto.json`; `(ulimit -v 4000000; timeout 120 godot --headless --path godot -- --autoprueba)` imprime `AUTOPRUEBA: TODO BIEN`. Medida: `MEDIDA carga del maniquí` (hoy 695 ms): no debe subir más de un 20 %.
- **A2c:** `probar_pck.sh` imprime `AUTOPRUEBA: TODO BIEN`.
- **Que la prueba detecta el fallo:** quitar `datos/*` del filtro del preset y repetir A2c: debe imprimir `AUTOPRUEBA: FALLO`. Volver a ponerlo.

## 7. Trampas conocidas

- `--export-pack` sin plantillas de exportación instaladas: **NO VERIFICADO**. Si Godot las pide, este subpaso espera a la ficha 7.1 (instalar plantillas requiere red y aprobación).
- Formato del `.import` de «Keep File»: **NO VERIFICADO**; por eso lo escribe el editor y no el modelo.
- Tras clonar el repositorio hay que importar el proyecto una vez: `(ulimit -v 4000000; timeout 300 godot --headless --path godot --import)`. Sin eso, `res://` no conoce los recursos.
- `pruebas/godot` es **otro proyecto**: para él, `res://datos` no existe y `_data_folder()` usa la segunda rama. Es lo esperado.
- `cuerpo.glb` está en Git LFS: al moverlo sigue en LFS porque la regla es `*.glb`.
- `blender/exportar_datos.py` escribe en la carpeta: comprobar su ruta por defecto (`grep -n "datos" blender/exportar_datos.py`). No ejecutar Blender en este paso.
- Windows: `ulimit -v` no existe en Git Bash; quitarlo de los comandos al probar allí (ficha 8.1).

## 8. Juicio visual

No hace falta. El maniquí debe verse igual que antes: comando para abrirlo, `(ulimit -v 4000000; timeout 900 godot --path godot)`.

## 9. Si te atascas

- Si una prueba que pasaba deja de pasar tras A2a y el motivo no es una ruta: **para** y enseña la línea de `FALLO`.
- Si ningún plan B del §5 arregla A2c: **para**. No cambies el formato de `datos/` ni quites la comprobación del `sha256`.
- Si el responsable no aprueba mover la carpeta (D5 = b): no hagas A2a; A2b cambia a buscar primero junto al ejecutable (`OS.get_executable_path().get_base_dir().path_join("datos")`) y A2c no aplica. Android queda sin resolver.
