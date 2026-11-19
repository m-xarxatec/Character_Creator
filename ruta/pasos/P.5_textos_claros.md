# P.5 — Textos claros

> Pulido (2026-11-18). Tres cosas pequeñas que se notan: «Rim» no se entiende, el informe escribe decimales con punto
> y los diálogos de archivo siempre empiezan en la misma carpeta.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** la interfaz habla en español claro y recuerda dónde trabajaste.

**Hecho cuando:**
- El panel Acabado no dice «Rim» en ningún sitio; cada deslizador tiene un texto de ayuda de una línea.
- Los números del informe de deformación llevan coma decimal (`0,6 mm`, `×1,25`).
- Guardar preset, Abrir preset y Exportar .glb se abren en la última carpeta usada, también tras cerrar el programa.

## 2. Nivel de modelo

**Simple.** Textos y un archivo de ajustes; no hay cálculo nuevo.

## 3. Contexto mínimo

`godot/app/finish_panel.gd` (`NAMES`, `_add_slider`), `godot/addons/creador/mesh_checks.gd` (líneas 171–241, los
`%.1f`), `godot/addons/creador/character_checks.gd:76`, `godot/app/symmetry_dialog.gd:43` (ya pone la coma),
`godot/app/body_actions.gd` (`_preset_dialog`, `_add_dialogs`).

## 4. Archivos

Toca más de 3: tres subpasos, cada uno con su prueba.

- **P.5a — Nombres del acabado.** Se toca `finish_panel.gd`; se actualiza la prueba del panel si compara textos.
- **P.5b — Coma decimal.** Se tocan `mesh_checks.gd` y `character_checks.gd`; se actualizan las pruebas que comparan
  esos mensajes (`probar_comprobaciones`, `probar_informe`; buscar con `grep`).
- **P.5c — Última carpeta.** Se crea `godot/app/settings_file.gd`; se toca `body_actions.gd`. Se crea
  `pruebas/godot/probar_ultima_carpeta.gd`.
- **No se toca:** las claves del material (`rim_strength`… siguen en inglés en el código y en el preset).

## 5. Diseño

**P.5a** — Nombres propuestos (**los eliges tú**, ver §8):

| Clave | Hoy | Propuesta | Ayuda |
| --- | --- | --- | --- |
| `softness` | Borde | Suavidad de sombra | Lo suave que es el paso de luz a sombra |
| `rim_strength` | Rim (fuerza) | Brillo de borde | Luz en el contorno del cuerpo, vista a contraluz |
| `rim_width` | Rim (ancho) | Ancho del brillo | Cuánto entra ese brillo hacia dentro |
| `width_px` | Contorno (px) | Grosor de la línea | Grosor del contorno negro, en píxeles |

Hace falta un diccionario `HELP` al lado de `NAMES`; `tooltip_text` se pone en la fila.

**P.5b** — `MeshChecks._num(value: float, decimals: int) -> String`: `("%.*f" % [decimals, value]).replace(".", ",")`.
Todos los `%.Nf` de mensajes pasan por ella. `CharacterChecks` usa la misma (es `static`). **Motivo:** el texto sale
del núcleo, que ya escribe en español; arreglarlo en la interfaz obligaría a reescribir mensajes ya hechos.

**P.5c**
- `settings_file.gd` (`extends RefCounted`, todo `static`): `get_folder() -> String` y `set_folder(path: String)`,
  con `ConfigFile` en `user://ajustes.cfg`, sección `archivos`, clave `carpeta`. **Motivo:** `user://` existe en
  Linux, Windows y Android, también dentro del build.
- Una sola carpeta para los tres diálogos. **Motivo:** lo normal es guardar el preset y el `.glb` juntos.
- `body_actions.gd`: antes de `popup`, `dialog.current_dir = SettingsFile.get_folder()` si existe la carpeta; en
  `file_selected`, `SettingsFile.set_folder(path.get_base_dir())`.

## 6. Prueba

- **P.5a:** la prueba del panel (o una línea nueva en `probar_ventana`): ningún `Label` del panel Acabado contiene
  «Rim» y cada deslizador tiene `tooltip_text`. **Detecta el fallo:** volver a poner «Rim (fuerza)».
- **P.5b:** un resultado de `MeshChecks` con decimales contiene `,` y no `.` entre cifras (regex `\d\.\d`).
  **Detecta el fallo:** quitar el `replace`.
- **P.5c** (`probar_ultima_carpeta.gd`): guardar un preset en `user://prueba_carpeta/`; crear un `BodyActions` nuevo
  (como tras reiniciar) → `current_dir` de los tres diálogos = esa carpeta. Carpeta borrada → no se rompe (usa la
  de siempre). **Detecta el fallo:** no llamar a `set_folder`.

## 7. Trampas conocidas

- Algún test puede comparar el mensaje entero (`"máximo 2.3 mm"`): actualizarlo **es cambiar la prueba, no el
  límite**, pero dilo en el registro.
- `"%.*f"` existe en GDScript 4. **No comprobado en 4.7.2**: si no, `String.num(value, decimals)` (ojo: quita los
  ceros del final).
- En el `.pck`, `res://` es de solo lectura: los ajustes van siempre a `user://`.

## 8. Juicio visual

- Elige los nombres de la tabla de §5 (o dame otros).
- Captura del panel Acabado con los nombres nuevos, para mirarla en Linux.

## 9. Si te atascas

Si un mensaje del núcleo lo usa otra herramienta que espera punto (no se conoce ninguna), se deja el punto en esa y se
apunta en el registro.
