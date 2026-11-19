# IU.8 — Barra de estado y medidas en vivo

> Fase IU (`propuestas/expansion_v2.md` §3, IU.8; `diseno/GUIA_INTERFAZ.md` §2 y §4 «Barra de estado»).

## 1. Objetivo y «Hecho cuando»

**Objetivo:** una barra fina abajo que dice siempre cómo va el personaje: el informe, la altura y las cabezas de alto,
y el presupuesto (triángulos y huesos).

**Hecho cuando:**
- Abajo del todo hay una barra con: la pastilla del informe (icono + texto, nunca solo color; al pulsarla abre el
  desplegable del P.2), «1,68 m · 6,9 cabezas» y «26.756 triángulos · 53 huesos».
- La altura y las cabezas cambian al mover los deslizadores (con el temporizador del encuadre, P.3), medidas en reposo:
  mientras se prueban los huesos o se anima, se quedan con la última medida en reposo.
- La medida rápida coincide con la medida exacta (toda la malla horneada) del cuerpo: ± 1 mm y ± 0,05 cabezas.

## 2. Nivel de modelo

**Simple–medio.** La medida es la del 3.12 (`probar_estilo.gd`) con la muestra de vértices de P.3 (`CharacterBox`).

## 3. Contexto mínimo

`godot/app/character_box.gd` (entero), `body_view.gd` (`frame_character`, `frame_timer`, `pose_t`, `clip`),
`pruebas/godot/probar_estilo.gd:101–135` (barbilla y máscara de la cabeza), `report_section.gd` (`set_open`),
`report_panel.gd` (`rows`, `summary`).

## 4. Archivos

- **IU.8a — Medidas.** Se crea `godot/app/measures.gd`; se toca `character_box.gd` (muestras extra y `points()`).
  Se crea `pruebas/godot/probar_medidas.gd`.
- **IU.8b — Barra.** Se crea `godot/app/status_bar.gd`; se toca `main.gd` (la barra abajo; la actualiza al encuadrar
  y al cambiar el informe).
- **No se toca:** el núcleo, el encuadre, el informe.

## 5. Diseño

- **Barbilla:** al empezar, entre los vértices cuyo hueso de más peso es `Head`, los del centro (|x| < 10 % del ancho de
  la cabeza) y de delante (z > centro de la cabeza), el más bajo en reposo. **Motivo:** la misma regla del 3.12; se
  elige una vez y se sigue con las formas, como el resto de la muestra.
- `CharacterBox.new(mesh, extra := PackedInt32Array())`: añade esos vértices a la muestra; `points(mesh, skeleton)`
  devuelve las posiciones (`measure` las usa para la caja).
- `Measures.new(mesh)` y `measure(mesh, skeleton) -> {height, head, heads}`: altura = arriba − abajo de la muestra;
  cabeza = arriba − barbilla; cabezas = altura / cabeza.
- Se mide solo en reposo (`not pose_t and clip == ""`); si no, se deja la última medida.
- `StatusBar` (`extends PanelContainer`): pastilla (`Button` con variación `NivelBien/Aviso/Error` e icono
  `bien/aviso/error`; sin informe: «Informe: pulsa Probar huesos», sin variación), medidas y presupuesto en `Pista`.
  Números con coma decimal y punto de miles («26.756»).

## 6. Prueba

`probar_medidas.gd` (sin ventana, con `main.gd`):
- Neutro: la medida rápida contra la exacta (toda la malla horneada con `MeshBaker`, barbilla por la regla de arriba en
  todos los vértices): ± 1 mm de altura y ± 0,05 cabezas. `# PROVISIONAL` hasta medir.
- Global › Altura a 1 multiplica la altura por 1,15 (`escala:Root`) ± 1 mm.
- La barra dice la altura con coma («1,7x m»), las cabezas y «26.756 triángulos · 53 huesos» (los del cuerpo).
- Con Probar huesos, la pastilla cambia al resumen del informe con su icono y al pulsarla se despliega el informe; la
  altura no cambia mientras se prueba.
**Detecta el fallo:** medir con la pose de ahora (sin mirar `pose_t`) → la altura cambia al probar huesos.

## 7. Trampas conocidas

- La muestra de `CharacterBox` incluye los extremos en reposo (coronilla y pies): por eso la altura rápida coincide
  con la exacta.
- En la pose A los pies están en el suelo: la altura es la caja en Y, no la distancia de la coronilla al origen.

## 8. Juicio visual

Capturas en `pruebas/capturas/interfaz/iu8/`.

## 9. Si te atascas

Si la barbilla elegida en reposo se aleja de la real con formas extremas (> 0,05 cabezas), elegir 5 candidatos y
quedarse con el más bajo en cada medida.
