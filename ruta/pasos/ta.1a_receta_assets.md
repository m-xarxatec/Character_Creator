# TA.1a — Contrato de receta del Taller

Propuesta para revisión del responsable.

## 1. Objetivo y cierre

Convertir un diccionario leído de JSON en una receta v1 que se pueda volver a editar. Se cierra cuando los tres modos pasan la prueba de ida y vuelta, las entradas inválidas producen un error identificable y se ha comprobado que la prueba detecta el defecto del apartado 6.

## 2. Nivel

Medio para implementar el contrato aprobado. Su elección afecta a los archivos editables que abrirá la biblioteca en TA.5.

## 3. Contexto mínimo

- [Plan del Taller, §4](<../../taller assets/plan.md>) y [hoja de ruta, TA.1](<../../taller assets/pasos_a_seguir.md>).
- [Preset.from_dict](../../godot/addons/creador/preset.gd), como ejemplo de validación y errores en español. [Arquitectura, §6](../ARQUITECTURA.md), para procedencia y licencias.

## 4. Archivos del paso

Crear `godot/addons/creador/taller_assets/asset_recipe.gd` y `pruebas/godot/probar_receta_asset.gd`, con sus archivos `.gd.uid` si los genera Godot. Actualizar `PLAN.md` al cierre. Quedan fuera la interfaz, los datos de especie, el preset, los packs y el exportador.

## 5. Diseño propuesto

1. Exponer `static func normalize(data: Dictionary) -> Dictionary`. En caso de éxito devuelve `{"error": "", "receta": ...}` con una copia independiente. En caso de rechazo devuelve `{"error": "…"}` indicando el campo. Validar antes de completar opcionales.
2. Exigir `formato` igual a `gamemolde-asset-receta`, `version` numérica igual a 1, `id` local con letras minúsculas ASCII, dígitos o guion bajo, `modo`, `autor` con texto y `licencia` explícita (`propia` o `CC0-1.0`). Aceptar tanto 1 como 1.0 tras leer JSON. Rechazar claves desconocidas en esta versión con su nombre para evitar pérdidas silenciosas.
3. Completar las claves opcionales de `parametros` y `colores` a partir de la tabla. Admitir números finitos positivos en las dimensiones y cero en la holgura. Aceptar colores de seis dígitos hexadecimales precedidos por `#` y normalizarlos a mayúsculas. Usar metros, Y arriba y +Z al frente. Los siguientes son valores iniciales de receta; los rangos geométricos se medirán con cada generador.

| Modo | Parámetros iniciales | Colores iniciales |
| --- | --- | --- |
| `espada_parametrica` | `longitud_m` 1,0 (hoja), `ancho_hoja_m` 0,09 y `grosor_m` 0,018 | `hoja` #B9C0C8, `guarda` #77747A, `mango` #514336 |
| `extrusion_imagen` | `altura_m` 1,0 y `grosor_m` 0,02 | `principal` #FFFFFF |
| `camiseta_basica` | `holgura_m` 0,0 sobre la base preparada | `principal` #FFFFFF |

4. Para `extrusion_imagen`, exigir además `fuente` con `archivo` y `sha256`. Proponer una referencia portable como `fuentes/dibujo.png` y 64 dígitos hexadecimales. El nombre bajo `fuentes/` debe ser un único nombre de archivo PNG, sin separadores adicionales, unidad ni segmentos de ascenso. Validar la referencia en memoria. La lectura, el cotejo del contenido y su copia corresponden a TA.5. Los otros dos modos se crean sin fuente de imagen.

## 6. Pruebas

Desde la raíz, ejecutar:

```sh
(ulimit -v 4000000; timeout 120 godot --headless --path pruebas/godot -s probar_receta_asset.gd)
```

Construir los ejemplos en memoria. Comprobar los tres modos, sus valores iniciales y los valores editados tras serializar y leer JSON. Normalizar dos veces debe dar la misma receta. Editar el resultado tampoco debe modificar la entrada. Rechazar versión futura, modo desconocido, clave obligatoria ausente, tipo incorrecto, color inválido, NaN, dimensión negativa, ruta que salga de `fuentes/` y hash mal formado.

Desactivar temporalmente el rechazo de la versión futura. La prueba debe escribir `FALLO rechaza versión futura` y salir con error. Restaurarlo, repetir y exigir `RESULTADO: TODO BIEN` y código de salida 0. Pasar las regresiones sin ventana con las invocaciones de sus cabeceras según [la guía, §5](../GUIA_MODELOS.md).

## 7. Trampas conocidas

Un diccionario puede compartir referencias internas con otro. Incluir en la prueba un cambio a un color anidado. La licencia de una imagen procede de su autoría declarada; el normalizador nunca debe asignarle CC0 por defecto.

## 8. Revisión

El responsable revisa los campos, los valores iniciales y las reglas de rechazo. La evidencia de este paso es la salida de la prueba de datos.

## 9. Si aparece un bloqueo

Si una receta válida exige cambiar un formato existente, presentar el ejemplo y la decisión mínima al responsable. La validación de mallas y los casos de silueta corresponden a TA.1b.
