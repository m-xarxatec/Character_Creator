# TA.5 — Biblioteca local del Taller

> **Estado: propuesta pendiente de aprobación.** No hay código de este paso. Presentarla al responsable y esperar su OK, incluidos los límites del §5.6. Cada subpaso se propone, se prueba y se cierra por separado.

## 1. Objetivo y cierre

Que ninguna pieza guardada se pierda al cerrar GameMolde y que todas se puedan reabrir y seguir editando. Se cierra con las pruebas de cada subpaso, sus fallos provocados y el visto bueno del responsable a las capturas. Equipar la pieza en el personaje es TA.6.

| Subpaso | Qué deja hecho | Nivel |
| --- | --- | --- |
| **TA.5a** | Guardar, listar y abrir piezas en disco, sin interfaz | Fuerte |
| **TA.5b** | Guardar y reabrir desde el Taller, con la lista de la biblioteca | Medio |
| **TA.5c** | Eliminar, exportar un `.glb` suelto y avisar de cambios sin guardar | Medio |

## 2. Nivel

Fuerte en TA.5a (formato y archivos) y medio en el resto. Fable ya no está disponible: el responsable autoriza hacerlo con Opus (2026-11-23).

## 3. Contexto

Consultar [TA.5 en la hoja de ruta](<../../taller assets/pasos_a_seguir.md>), [el §7 del plan](<../../taller assets/plan.md>), `ruta/ARQUITECTURA.md` §6 y `godot/addons/creador/pack_library.gd`.

Medido en Godot 4.7.2 (Windows) el 2026-11-23, con un prototipo fuera del proyecto:

- El `.glb` conserva superficies, triángulos y colores. La posición cambia menos de 0,01 mm. La espada ocupa 22,8 KB y tarda 3,7 ms en escribirse y 8,8 ms en leerse.
- El nombre de cada superficie **se pierde** en el `.glb`, salvo que se ponga también en su material: así vuelven `hoja`, `guarda`, `mango` y `pomo`.
- Un contorno guardado en JSON con precisión completa vuelve idéntico y da una malla idéntica.
- Renombrar una carpeta **sobre otra que ya existe falla**. Apartar la vieja y mover la nueva funciona.
- `PackLibrary` descarta un pack dañado y conserva los demás, detecta un `.glb` alterado y admite campos extra en la ficha.
- Una pieza con `"especies": []` no sale en Accesorios para la humana.
- Una miniatura de 256 px tarda de 12 a 36 ms con ventana. Sin ventana no se puede renderizar.

## 4. Archivos

**TA.5a.** Crear `godot/addons/creador/taller_assets/asset_store.gd` y `pruebas/godot/probar_biblioteca_asset.gd`, con sus UID. Cambiar `PLAN.md`.

**TA.5b.** Crear `godot/app/taller_assets/library_panel.gd`, `godot/app/taller_assets/save_asset_dialog.gd` y `godot/app/taller_assets/asset_thumbnail.gd`, con sus UID. Cambiar `workshop_page.gd`, `image_panel.gd`, `probar_ventana.gd` y `PLAN.md`. Capturas en `pruebas/capturas/interfaz/ta5b/`.

**TA.5c.** Cambiar `asset_store.gd`, `library_panel.gd`, `workshop_page.gd`, `godot/app/main.gd` (solo la comprobación de cierre), `probar_biblioteca_asset.gd`, `probar_ventana.gd` y `PLAN.md`. Capturas en `pruebas/capturas/interfaz/ta5c/`.

No se tocan `pack_library.gd`, `asset_recipe.gd`, los generadores ni el exportador del personaje.

## 5. Diseño

### 5.1. Una carpeta por pieza

El plan proponía un único pack `taller_local`. Se cambia a **un pack por pieza**, porque en `pack.json` el autor y la licencia son de todo el pack y porque un archivo dañado invalidaría todas las piezas.

```text
user://packs/taller_<id>/
    pack.json       # formato de ARQUITECTURA §6, con una sola pieza
    pieza.glb
    pieza.png       # miniatura; puede faltar
    edicion.json    # lo necesario para seguir editando
    fuentes/<nombre>.png   # solo en piezas hechas desde imagen
```

La ficha de `pack.json` usa `"tipo": "accesorio"`, `"ranura": "accesorio"` y `"especies": []`: así no aparece en Accesorios hasta que TA.6 sepa equiparla. Añade `"edicion_sha256"`.

`edicion.json` contiene `{"formato": "gamemolde-asset-edicion", "version": 1, "receta": {...}, "contorno": [[x, y], ...], "ajustes": {...}}`. Contorno y ajustes solo existen en piezas desde imagen. La receta v1 no cambia.

### 5.2. Servicio `AssetStore`

```gdscript
func _init(packs_folder := "user://packs", temp_folder := "user://taller_temporal")
func list() -> Dictionary    # {"piezas": [ficha...], "avisos": [texto...]}
func save(entry: Dictionary) -> Dictionary    # {"error": "", "id": String} o {"error}
func open(id: String) -> Dictionary    # {"error": "", "receta", "contorno", "ajustes", "imagen", "avisos"} o {"error"}
```

`entry` lleva `nombre`, `receta`, `malla`, `miniatura` (Image o null) y, si viene de imagen, `fuente_bytes`, `contorno` y `ajustes`. Con `reemplaza` (id) actualiza esa pieza; sin él, crea una nueva.

### 5.3. Guardado seguro

1. Validar la receta, el nombre, la malla y el hash de la fuente.
2. Escribir todo en una carpeta de `temp_folder`, fuera de `user://packs`.
3. Releer lo escrito: `PackLibrary` debe aceptarlo y el `.glb` debe abrir con las mismas superficies.
4. Si la pieza ya existe, apartar la vieja a `temp_folder`, mover la nueva a su sitio y borrar la vieja. Si mover falla, devolver la vieja a su sitio.
5. `list()` recupera una pieza apartada si el programa se cerró a mitad del paso 4, y limpia lo temporal que sobre.

### 5.4. Abrir

Comprobar los hashes y regenerar la malla desde la receta y el contorno guardado. Si la imagen de origen falta o no coincide, se avisa y la pieza sigue abierta: altura, grosor y color se pueden editar, y el contorno queda bloqueado hasta elegir de nuevo la imagen. Una pieza dañada da un aviso y no afecta a las demás.

### 5.5. Interfaz (TA.5b y TA.5c)

- **Biblioteca:** en la columna izquierda, bajo los modos, una lista con miniatura y nombre. Un clic reabre la pieza en su modo.
- **Guardar:** diálogo con Nombre, Autor y Licencia (`propia` o `CC0-1.0`). Si viene de una imagen, exige marcar «Tengo derecho a usar esta imagen»: una obra importada no pasa a ser CC0 por importarla.
- **Reabierta:** Guardar actualiza esa pieza. Un nombre que ya usa otra pieza se rechaza con un aviso, sin sobrescribir.
- **Eliminar:** pide confirmación y borra solo la carpeta de esa pieza.
- **Exportar:** `FileDialog` para un `.glb` independiente. No cambia la biblioteca.
- **Cambios sin guardar:** abrir otra pieza o cerrar el programa pide confirmación.

### 5.6. Límites por aprobar

Nombre de 1 a 40 caracteres, y `edicion.json` de 1 MB como máximo (un contorno de 1000 puntos ocupa unos 15 KB). Se marcan `# PROVISIONAL` hasta tu aprobación.

## 6. Pruebas

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_biblioteca_asset.gd)
```

**TA.5a.** Guardar, crear otro `AssetStore`, abrir y regenerar dos espadas y una extrusión con arrays idénticos. Cada archivo ausente, truncado o alterado da un aviso, sin cierre ni daño a las otras piezas. Un nombre repetido no sobrescribe. Un guardado fallido conserva la pieza anterior. Un cierre simulado a mitad de la sustitución se recupera. Ids y rutas maliciosos no escriben fuera de la carpeta.

**TA.5b.** En `probar_ventana.gd`: guardar, ver la pieza en la lista, cambiar de modo, reabrir, editar y actualizar. Imagen de origen perdida: aviso y controles correctos.

**TA.5c.** Eliminar con y sin confirmar, exportar y releer el `.glb`, avisar de cambios sin guardar. Importar el `.glb` en un proyecto de Godot vacío.

**Controles negativos**, en una copia temporal: TA.5a, quitar la comprobación de hash y sustituir sin apartar la vieja. TA.5b, desconectar la reapertura. TA.5c, borrar sin confirmar. Por decisión del responsable (2026-11-23) se ejecutan solo las pruebas de lo nuevo y de los archivos que cambia cada subpaso.

## 7. Trampas

- `PackLibrary` no valida que `archivo` quede dentro de su carpeta. `AssetStore` solo acepta sus nombres fijos.
- Poner el nombre de la superficie en su material antes de escribir el `.glb`.
- `JSON.stringify` necesita `full_precision = true`.
- La miniatura no existe sin ventana: `save` debe aceptar `null`.
- `user://packs` también guarda packs de otros orígenes: `AssetStore` solo toca carpetas `taller_*` con su propio `edicion.json`.
- Blender no está instalado en este PC: abrir el `.glb` en Blender queda para TA.11 o para el responsable.

## 8. Revisión visual

TA.5b y TA.5c entregan capturas en claro y oscuro, a 1280 × 720 y 1920 × 1080, sin describirlas. El responsable hace la revisión en persona: no ofrecer el revisor-visual en el Taller. TA.5a no cambia nada visible.

## 9. Si aparece un bloqueo

Si hace falta cambiar `pack_library.gd` o el formato de receta, o la lista no cabe a 1280 × 720, presentar el caso antes de ampliar el paso.
