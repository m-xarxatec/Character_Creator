# Fase 14 — Aspecto y estilos (ficha breve)

> Ficha **breve**. Antes de empezar cada paso, un modelo fuerte o medio escribe su ficha detallada (`GUIA_MODELOS.md` §6).
> Depende de: 4.7 (`BodyMaterial.set_param`, preset v2). Los pasos 14.1 a 14.3 se pueden adelantar a cualquier momento tras el MVP.

**Objetivo de la fase:** que el estilo visual sea un archivo de datos elegible, que la piel admita marcas y materiales especiales, y que el programa tenga el aspecto de `diseno/`.

**Hecho cuando:** el usuario elige entre al menos 3 estilos con miniatura, el estilo se guarda en el proyecto, y el `.tres` exportado reproduce el estilo elegido en un proyecto vacío.

| Paso | Objetivo | Tam. | Riesgo | Nivel | Depende de |
| --- | --- | --- | --- | --- | --- |
| ★ 14.1 | Estilo como archivo de datos: dos estilos (3 tonos y 2 tonos) elegibles y guardados | S | Bajo | simple | 4.7 |
| 14.2 | Contorno por zona (dónde se guarda el grosor: SH.4b) y color del contorno | M | Medio | medio | 14.1 |
| 14.3 | Tinte de sombra: lo cubre SH.2 con la sombra calculada (D48); la sombra a mano queda en `IDEAS.md` | — | — | — | SH.2 |
| 14.4 | Calcomanías de piel: manchas, rayas, tatuajes, cicatrices | L | Medio: UV y costuras | fuerte | 14.1 |
| 14.5 | Materiales especiales: piedra, metal, cristal, fantasma, emisivo | M | Medio: transparencia + contorno | medio | 14.1 |
| 14.6 | Tema de la interfaz según `diseno/GUIA_ESTILO.md` | M | Bajo | medio | — |
| 14.7 | Pantalla de inicio con estilos y personajes de ejemplo | M | Bajo | simple–medio | 10.2, 14.1 |
| 14.8 | Historial de Deshacer visual, con miniaturas | M | Bajo | medio | 4.4, 10.2 |

## Notas de diseño que no deben perderse

- **14.1, formato:** `godot/estilos/<id>.json`: `{"formato": "gamemolde-estilo", "version": 1, "nombre": "…", "acabado": {…las 6 claves del preset v2…}, "contorno": {"color": [0,0,0], "width_px": 2.5}}`. La fuerza de la sombra calculada (SH.2, D48) se añade al formato cuando exista. Aplicar un estilo = copiar su `acabado` al estado. El estado guarda los valores, no el id: un proyecto no se rompe si el estilo se borra.
- **Estilos propuestos** (todos por parámetros, sin assets): Anime 3 tonos (el aprobado), Anime 2 tonos, Cómic (contorno más grueso, 2 tonos duros), Suave (borde de tono ancho), Boceto (modo solo contorno del 10.9), Arcilla (sin contorno, un tono, para ver volumen).
- **14.2, contorno por zona:** un grosor por zona permite que los dedos y la cara lleven línea más fina, como en la ilustración. Dónde se guarda ese grosor se decide con medidas en SH.4b (`PLAN.md`), junto con las normales suavizadas. Cambia `outline.gdshader`; si cambia la malla exportada, hay que revisar `probar_glb.gd`.
- **14.4, calcomanías sin `Decal`:** el nodo `Decal` no existe en Compatibility y se deforma (`PLATAFORMAS.md` §3). Se hacen en el **espacio UV**: cada calcomanía es una imagen + posición, giro y escala en UV; el shader mezcla hasta N (4) capas sobre el color de piel, o se hornean todas a una textura de 1024 px al soltar (como `GarmentTexture.bake`). Recomendación: hornear a textura; el shader solo lee una textura más y el coste por fotograma no crece con el número de calcomanías. Las costuras UV limitan dónde quedan bien: la ficha detallada debe incluir un mapa de «zonas seguras».
- **Imágenes de las calcomanías:** procedurales (rayas, manchas con ruido, escamas con un patrón de celdas) o dibujadas por nosotros. CC0. Nada descargado sin fila en `CREDITOS.md`.
- **14.5:** cada material especial es un `modo_material` del toon o un shader hermano pequeño. Emisivo (runas, venas): máscara de calcomanía + color de emisión; con resplandor activado en el estudio brilla. Fantasma: transparencia + contorno apagado (el contorno por caras invertidas se ve a través de una malla transparente). En el `.glb` exportado, el material estándar solo aproxima estos efectos; el fiel es el `.tres`.
- **14.6:** un único `Theme` (`godot/app/tema.tres` o construido por código en `godot/app/theme_builder.gd`). Recomendación: **por código**, leyendo colores y medidas de una tabla; es texto revisable y no depende del editor. Fuentes: la de Godot hasta que se apruebe una OFL (decisión nueva: D30).
- **14.8:** `ValueHistory` (4.4) ya guarda copias del estado. Añadir una miniatura por entrada (64 px, `SubViewport` pequeño, generada en un fotograma libre, no al arrastrar). Límite de memoria: 50 entradas × 64 × 64 × 4 bytes = 0,8 MB.

## Juicio visual

Toda la fase es visual. Cada estilo nuevo se aprueba con una hoja (frente y tres cuartos, con y sin prenda).

## Si te atascas

Si un estilo nuevo obliga a cambiar el aspecto del estilo aprobado (el de por defecto): **para**. El estilo por defecto solo cambia con aprobación explícita.
