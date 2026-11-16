# A4 — El estado del personaje y las migraciones

> Cambio mínimo de arquitectura (`ARQUITECTURA.md` §0 y §1). **No es un paso aparte:** es el contrato que deben cumplir las fichas 4.4, 4.5 y 4.7. Coste extra: cero. Léela antes de empezar cualquiera de las tres.

## 1. Objetivo y «Hecho cuando»

**Objetivo:** que todo lo que el usuario elige viva en **un solo diccionario** (el estado), y que el preset tenga una **cadena de migraciones**. Con eso, Deshacer, el preset, el proyecto compartido y Android usan lo mismo.

**Hecho cuando** (se comprueba al cerrar el 4.7):
- La interfaz tiene `get_state()` y `set_state()` y nada más cambia el personaje.
- `ValueHistory` guarda estados completos, sin saber qué hay dentro.
- `Preset.migrate()` convierte un preset v1 en v2 y rechaza una versión futura con un mensaje claro.

## 2. Nivel de modelo

**Medio.** Es un contrato, no código difícil. El riesgo es que un modelo lo ignore y guarde cosas sueltas (una variable para el color, otra para el grosor…).

## 3. Contexto mínimo

- `ARQUITECTURA.md` §0 y §1.
- `godot/addons/creador/preset.gd`, líneas 1–31.

## 4. Archivos

Los de las fichas 4.4, 4.5 y 4.7. Esta ficha no añade ninguno.

## 5. Diseño (el contrato)

### 5.1 El estado

```gdscript
# godot/app/body_page.gd (se crea en la ficha 4.4b)
## Todo lo que el usuario ha elegido. Copia profunda: quien la recibe puede guardarla.
func get_state() -> Dictionary
## Pone el personaje, el material y los controles como dice el estado. Lo que falta vale su valor por defecto.
func set_state(state: Dictionary) -> void
```

| Clave | Tipo | Aparece en | Por defecto si falta |
| --- | --- | --- | --- |
| `valores` | `{clave: float}` | 4.4 | Los del preset de personaje nuevo |
| `prenda_visible` | `bool` | 4.5 | `true` |
| `colores` | `{"skin_color": Color, "garment_color": Color}` | 4.7 | Los de `BodyMaterial.DEFAULTS` |
| `acabado` | `{"softness", "rim_strength", "rim_width", "width_px", "mid_shade", "shadow_shade": float}` | 4.7 | Los de `BodyMaterial.DEFAULTS` y `OUTLINE_DEFAULTS` |

Reglas:

1. **Una sola puerta.** Cualquier cambio del usuario hace: cambiar el personaje → al terminar el gesto, `history.commit(get_state())`.
2. **Deshacer = `set_state(history.undo())`.** Nunca se deshace «a mano» una sola cosa.
3. `set_state` no llama a `history.commit` (si no, deshacer apilaría un paso nuevo).
4. `set_state` actualiza los controles **sin emitir señales** (`set_value_no_signal`, o `set_block_signals(true)` alrededor).
5. Cuando una fase nueva añada algo (piezas, pose), añade **una clave** aquí. No crea otro historial.

### 5.2 Las migraciones del preset

```gdscript
# godot/addons/creador/preset.gd (ficha 4.7a)
const VERSION := 2
## Lleva un preset de cualquier versión anterior a VERSION. Devuelve {"error": "", "data": Dictionary}.
static func migrate(data: Dictionary) -> Dictionary
```

Algoritmo:

1. Si `data` no tiene `version` o no es un número → error «falta el campo 'version'».
2. Si `version > VERSION` → error «preset de la versión %d; este programa lee hasta la %d. Actualiza el programa.»
3. Copia profunda de `data`. Mientras `version < VERSION`: se llama a la función del salto (`_v1_to_v2`) y se suma 1.
4. Devuelve la copia.

`_v1_to_v2(data)`: añade `"acabado"` con los 6 valores por defecto y pone `"version": 2`. No toca nada más.

Regla para el futuro: **una función por salto, nunca se edita una ya publicada.** El salto v2→v3 será otra función.

`from_dict` llama a `migrate` lo primero y trabaja con el resultado. Así un preset v1 guardado en disco sigue abriéndose siempre.

### 5.3 Qué no hace este contrato

- No decide carpetas ni nombres de archivo (igual que hoy `preset.gd`).
- No cambia la carga estricta: campos desconocidos = error (decidido en el paso 3.7).

## 6. Prueba

Se reparte entre las fichas:

- 4.4a: `probar_historial.gd` (el historial con diccionarios anidados).
- 4.4c y 4.7b: tras cualquier secuencia de cambios, deshacer hasta el principio deja `get_state()` **igual** al estado inicial (comparación clave a clave, diferencia 0).
- 4.7a: `probar_presets.gd`: un texto v1 carga con los mismos `valores` y `colores` que antes (diferencia 0) y con el acabado por defecto; un texto con `"version": 3` da error y el mensaje contiene «Actualiza».

**Que la prueba detecta el fallo:** en la interfaz, cambiar el color de piel sin llamar a `commit`; la prueba «deshacer devuelve el color anterior» debe fallar.

## 7. Trampas conocidas

- `Dictionary.duplicate(true)` copia en profundidad diccionarios y listas. `Color` es un valor, no hace falta copiarlo.
- En el estado los colores son `Color`; en el JSON del preset son `[r, g, b]`. La conversión la hace `Preset` (`to_dict` y `_load_colors`), no la interfaz.
- No comparar estados con `==` ni con `hash()` sin comprobarlo antes: usa la función `_same` de la ficha 4.4a.

## 8. Juicio visual

No hace falta.

## 9. Si te atascas

Si una función nueva necesita guardar algo que no cabe en una clave del estado (por ejemplo, un archivo grande), para y pregunta: probablemente va como referencia (nombre + `sha256`), igual que las piezas.
