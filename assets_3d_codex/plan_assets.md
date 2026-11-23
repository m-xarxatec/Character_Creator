# Plan de assets (extra, fuera del proyecto principal)

Assets 3D propios para ir llenando el programa. **No se toca el repo principal**: cada asset vive en
`assets_3d_codex/claude_<asset>/` y se prueba instalando su pack en
`%APPDATA%/Godot/app_userdata/GameMolde/packs/<id_pack>/` (el `user://packs` del programa).

## Receta para cada asset

1. **Plano**: hoja de referencia en `planos/` (medidas, vistas, partes, colores).
2. **Generador** `generar_<asset>.py` (Python + numpy, sin Blender): construye la malla con código a partir
   del cuerpo real (`godot/datos/humana/cuerpo.glb`) y usa el esqueleto de `godot/packs/base/tights.glb`.
   El lector de `.glb` es `claude_gorra/glb.py`.
3. **Encaje**: medir el cuerpo (y los peinados o prendas con los que convive) y dejar la holgura justa.
4. **Seguir al cuerpo**: pesos al hueso que toque (rígido) o copiados de la piel (flexible), y las formas
   del cuerpo transferidas desde la piel cercana (solo las que mueven esa zona).
5. **Un color por pieza**: el shader de piezas pinta un solo color, así que los detalles de otro color
   (logos, hebillas…) van como **pieza aparte**.
6. **Ranura**: `accesorio` si debe convivir con todo; la de ropa o pelo si debe sustituir a otra.
7. **Licencia**: `propia`; nada de marcas registradas (por eso GM y no NY).
8. **Prueba**: instalar el pack, abrir el programa y juzgarlo a mano (el responsable). Capturas solo si se piden
   (`claude_gorra/capturar_gorra.gd`).

## Assets

| Asset | Estado | Notas |
| --- | --- | --- |
| Gorra plana (holgada + GM) | Aprobada | Para cualquier peinado; deja 1,8–2,8 cm de hueco |
| Gorra plana ajustada (+ GM) | Pendiente de probar | Sin pelo o rapado; hueco de 4–6 mm |
| Falda corta plisada | Aprobada | `claude_falda/`; talle bajo, 25 cm, 16 pliegues, cintura pegada a la piel; en Accesorios (en `ropa_piernas` quitaría los shorts). Adaptable al cuerpo (76 formas, 4,9 MB); aún 100 % `Hips` (pesos de piernas en C) |
| Sudadera oversize con capucha | Aprobada | `claude_sudadera/`; ranura `ropa_exterior` (no sustituye nada); piel copiada e hinchada (pesos y formas del cuerpo), cae recta desde el pecho, bajo a ~0,95 m, mangas hasta los nudillos, capucha bajada, bolsillo; 268 formas dispersas, 6,8 MB. Conocido: 58 caras plegadas en las axilas |
| (siguiente) | — | — |

## Pendiente: se hace en el propio asset (sin tocar el núcleo)

### C. Falda: pesos de piernas para que sea funcional

Hoy va rígida con la cadera (ya se adapta al cuerpo: hecho el 2026-11-23).
- **Pesos**: arriba 100 % `Hips`; hacia el bajo, mezcla gradual con `LeftUpperLeg` / `RightUpperLeg` según el
  lado, y los pliegues del centro (delante y detrás) repartidos entre los dos muslos, para que se mueva al
  andar sin partirse entre las piernas. Máximo 4 influencias y suma 1.
- Riesgo que queda: con la pierna muy levantada («Atacar», sentarse) el muslo atravesará la tela; sin
  físicas no se evita del todo.
- Si se pasa a la ranura `ropa_piernas`, decidir antes qué hacer con los shorts (lo decide el responsable).

## Pendiente: requiere tocar el núcleo (proponer a quien lleva el proyecto)

### A. Cambiar sola de holgada a ajustada según el pelo

Hoy las piezas solo se excluyen por ranura o con `cubre`; no hay variantes condicionales.
Propuesta: un campo en `pack.json`, por ejemplo `"variante_sin_pelo": "gorra_plana_ajustada"`, y que
`body_view.gd` (`set_piece`) cambie a esa variante cuando no hay pieza en la ranura `pelo`, y vuelva a la
holgada al poner pelo. Pequeño, pero es código del programa.

### B. Esconder el pelo bajo la gorra (la solución buena)

Al ponerse la gorra, el pelo que queda por encima de la banda se aplasta hacia dentro, justo bajo la tela
(lo de abajo —melena, coleta, flequillo— no se toca), como hace una gorra de verdad.
- Ventajas: el pelo deja de atravesar la copa y la gorra puede ir siempre ajustada (sin flotar ni variantes;
  haría innecesario A).
- Debe hacerse en CPU (en la malla del pelo, en el espacio del hueso `Head`), no en el shader: el `.glb`
  exportado también tiene que salir con el pelo aplastado.
- Datos: la gorra declara su volumen interior (banda y copa) en `pack.json`; el pelo se ajusta al ponerla o
  quitarla y al cambiar formas.
- Peinados extremos (afro, moños altos): aun aplastados quedarían raros; para esos, ocultarlos
  (`cubre: ["pelo"]` solo en ese caso, o una lista de excepciones).

## Ficha de integración (para cuando se metan en el proyecto)

Hoy viven fuera del repo. Meterlos es un **paso del PLAN con su ficha en `ruta/pasos/`** (reglas 1, 9 y 10 del
`CLAUDE.md`); esta sección es el material para escribirla.

### Qué hay de cada asset

| Asset | Generador | Pack (id) | Piezas | Tipo / ranura | Peso | Hueso / pesos | Formas |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Gorra plana | `claude_gorra/generar_gorra.py` (`ajustada` para la variante) | `claude_gorras` | `gorra_plana`, `gorra_plana_gm`, `gorra_plana_ajustada`, `gorra_plana_ajustada_gm` | accesorio / accesorio | 4,0 + 0,35 MB cada variante | 100 % `Head` | 19 (cráneo) |
| Falda corta plisada | `claude_falda/generar_falda.py` | `claude_faldas` | `falda_plisada` | accesorio / accesorio | 4,9 MB | 100 % `Hips` | 76 (cintura, cadera, muslos) |
| Sudadera con capucha | `claude_sudadera/generar_sudadera.py` | `claude_sudaderas` | `sudadera_capucha` | ropa / ropa_exterior | 6,8 MB | copiados de la piel (4 influencias, suman 1) | 268, dispersas |

Todos: licencia `propia`, autor «GameMolde», color plano (un color por pieza), mismo esqueleto que
`godot/packs/base/tights.glb`, generados con Python + numpy (+ scipy la sudadera), sin Blender. Se regeneran
con `python generar_<asset>.py` desde su carpeta.

### Pasos para integrarlos

1. **Copiar** cada `packs/<id>/` a `godot/packs/<id>/` (nombres en minúsculas). Renombrar los ids
   `claude_*` si se quiere (p. ej. `gorras`, `faldas`, `sudaderas`) y regenerar `pack.json` (el `sha256` cambia
   si cambia el `.glb`).
2. **`.import`**: cada `.glb` con su `<archivo>.glb.import` con `[remap]` / `importer="keep"` (como los demás
   packs), para que viaje tal cual en el `.pck`.
3. **Créditos**: fila propia de cada carpeta de `godot/packs/` en `CREDITOS.md` y su copia
   `godot/CREDITOS.txt` (lo exige `probar_licencias`). Licencia `propia` ya la admite `PackLibrary.LICENSES`.
4. **Pruebas** a pasar (sin tocar límites sin aprobación, regla 9): `probar_packs` (añadir el límite de
   tamaño de cada pack nuevo, `# PROVISIONAL`, con la medida real), `probar_piezas`, `probar_licencias`,
   `probar_piezas_limpias`, autoprueba (`--autoprueba`) y `probar_glb --piezas=N` (piel, mismo esqueleto,
   bind poses y pesos que suman 1).
5. **Peso del programa**: suman unos 20 MB (con las dos variantes de gorra). Valorar quitar la variante
   ajustada si se hace B, y reducir resolución o formas si el build pesa demasiado.
6. **Decisiones del responsable** antes de integrar:
   - Gorra: ¿solo holgada, las dos variantes, o la ajustada + B (pelo aplastado)?
   - Falda: ¿sigue en `accesorio` o pasa a `ropa_piernas` (quitaría los shorts)? Tipo `ropa` para que salga en
     la pestaña Ropa.
   - Monograma GM: ¿pieza aparte o el núcleo admite un segundo color por pieza (p. ej. por color de vértice)?

### Mejoras pendientes por asset

- **Gorra**: A (cambio automático según el pelo) o B (aplastar el pelo), ambos en el núcleo.
- **Falda**: C (pesos de piernas) en el propio asset.
- **Sudadera**:
  - 58 caras plegadas en las axilas (la manga y el costado hinchados se cruzan); arreglo en el asset:
    hinchar menos en la cara interna del brazo y en el costado bajo la axila, o fundir esa zona.
  - El bajo va con los pesos de la piel de la cadera: con la pierna muy levantada puede cruzarse (como C).
  - Capucha subida: pieza aparte, con el mismo problema que la gorra con el pelo (A/B).
  - Los pesos y formas de pretina, puños, capucha y bolsillo salen de los 8 vértices de piel más cercanos;
    revisar con animaciones al integrarla.
