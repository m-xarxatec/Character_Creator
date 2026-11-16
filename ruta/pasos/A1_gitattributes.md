# A1 — Finales de línea de `datos/`

> Cambio mínimo de arquitectura (`ARQUITECTURA.md` §9). Decisión D4. Puede hacerse hoy mismo.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** que git nunca cambie los finales de línea de los archivos de `datos/`, para que su `sha256` sea el mismo en Linux y en Windows.

**Hecho cuando:** `git ls-files --eol datos/` muestra `attr/-text` en todos los archivos de `datos/humana/` y `probar_carga.gd` sigue pasando.

## 2. Nivel de modelo

**Simple.** Son dos líneas en un archivo. La única dificultad es no tocar nada más.

## 3. Contexto mínimo

- `.gitattributes` (1 línea hoy: `*.glb filter=lfs diff=lfs merge=lfs -text`).
- `godot/addons/creador/species_data.gd`, líneas 42–44 (la comprobación del `sha256`).
- `PLATAFORMAS.md` §1 (por qué).

## 4. Archivos

- **Se toca:** `.gitattributes`.
- **No se toca:** nada de `datos/`. Si un `sha256` cambia, el paso está mal hecho.

## 5. Diseño

Añadir al final de `.gitattributes`:

```
# datos/ se comprueba por sha256: git no debe cambiar ni un byte (finales de línea)
datos/** -text
```

Si se aprueba la ficha A2 (mover `datos/` a `godot/datos/`), la línea pasa a ser `godot/datos/** -text`.

Motivo de usar `-text` y no `eol=lf`: `-text` le dice a git «no es texto, no lo toques»; no depende de la configuración de cada máquina.

## 6. Prueba

1. Antes y después: `sha256sum datos/humana/articulaciones.json datos/humana/deslizadores.csv datos/humana/presets/anime.json datos/humana/manifiesto.json`. Los 4 valores deben ser idénticos antes y después.
2. `git ls-files --eol datos/` → todos con `attr/-text`.
3. `(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_carga.gd 2>&1 | grep -E 'FALLO|RESULTADO|ERROR')` → `TODO BIEN`.

**Cómo comprobar que la protección sirve** (solo lectura del resultado, en una carpeta temporal fuera del repositorio; lo ejecuta el responsable porque usa `git clone`):
`git -c core.autocrlf=true clone <repo> /tmp/prueba_crlf` y `sha256sum /tmp/prueba_crlf/datos/humana/deslizadores.csv`. Con la línea nueva, el valor coincide con el del manifiesto. Sin ella, no.

## 7. Trampas conocidas

- **No ejecutar `git add --renormalize`** ni ningún otro comando de git que cambie el repositorio (regla 8). El archivo se edita y el commit lo hace el responsable.
- Los archivos ya están guardados con LF (`i/lf` en `git ls-files --eol`): no hay nada que convertir.
- Medido hoy en esta máquina Windows: `core.autocrlf=false` y los 4 `sha256` coinciden con el manifiesto. El problema aparece en un clon con `core.autocrlf=true`.

## 8. Juicio visual

No hace falta.

## 9. Si te atascas

Si después del cambio algún `sha256` es distinto, **para**: deshaz tu edición de `.gitattributes` y avisa. No regeneres el manifiesto.
