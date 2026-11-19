# Trabajo desde el equipo Windows

> Desde el 2026-11-19. Godot 4.7.2 instalado aquí (D16 a: `~/tools/godot/`, comando `godot`); Blender no. Lo de
> Godot se prueba aquí; lo de Blender y los commits, en Linux. El detalle va al registro de `PLAN.md`.

## Orden (recomendado)

| # | Qué | Estado | Te toca |
| --- | --- | --- | --- |
| 1 | Fichas P.4–P.7 | Hecho | — |
| 2 | **P.6** Animaciones ligeras (7,6 → 1,46 MB; `.pck` 19,6 MB) | Cerrado | Aprobar el límite PROVISIONAL (< 2 MB) |
| 3 | **P.4** Atajos y aviso al cerrar | Cerrado | — |
| 4 | **P.5** Textos claros | Cerrado | — |
| 5 | **P.7** Icono **a** (maniquí en pose T) | Cerrado | — |
| 6 | Recursos CC0: licencias comprobadas (tabla abajo) | Hecho | Elegir cuándo se descargan |
| 7 | D16: Godot en Windows | Hecho | — |
| 8 | **IU.1** Tema: oscuro, Nunito, botón Claro/Oscuro | Cerrado | — |
| 9 | **IU.2** Iconos Tabler (temporales, D33) | Cerrado | — |
| 10 | **P.8** Ctrl + arrastrar (mano), Inicio y botón «Comandos» | Probado | Probarlo a mano |
| 11 | **IU.4** Barra superior (D35) | Cerrado | — |
| 12 | **IU.5** Silueta de zonas (y plegar) | Cerrado | — |
| 13 | **IU.6** Filas nuevas, buscador, pestaña Estilo | Cerrado | — |
| 14 | **IU.8** Barra de estado (informe, altura, cabezas, presupuesto) | Probado | Juzgar `iu8/`; aprobar ± 1 mm y ± 0,05 cabezas |
| 15 | IU.9–IU.11 (ajustes, microinteracciones, cierre); IU.3 e IU.7 con Fable | Siguiente | — |

## En Linux

- Commits (uno por paso). Nuevos para git: `.uid` e `.import` que creó Godot, `godot/app/tema/`, `icono.svg`,
  `icono.png`, las pruebas nuevas.
- Blender: `probar_recorte.py` también vale con `blender -b -P` (no hace falta: ya pasó con Python).
- **Pruebas que necesitan lo que escribe Blender** (`pruebas/fase_*/salida/`, no va en git): en Windows dan un error al empezar y se quedan colgadas hasta el tope de tiempo. Se lanzan en Linux: `probar_anclajes`, `probar_exportar`, `probar_formas`, `probar_horneado`, `probar_personaje_horneado`, `probar_pose_t`, `probar_reajuste`, `probar_hombro_natural`, `probar_legibilidad`, `probar_variante_t` (y las de importación: `probar_importador.sh`, `probar_overwrite_axis.sh`).

## Recursos CC0 (paso 6)

Solo licencias comprobadas en la página del autor; nada se descarga hasta su paso (regla 2) ni sin fila en
`CREDITOS.md` (regla 5). Resultados abajo.

Comprobado el 2026-11-19 en la página de cada autor (no en el archivo descargado: eso se hace al descargar).

| Recurso | Licencia comprobada | Qué trae (versión gratis) | Para qué paso | Nota |
| --- | --- | --- | --- | --- |
| MakeHuman **system assets** | CC0 (cada pieza, en su tabla) | Pelo (afro, bob ×2, trenza, melena, coleta, cortos ×4), cejas ×12, pestañas ×4, ojos, ropa (trajes, zapatos ×6, sombrero) | 9 (cejas, pestañas), 11 (pelo), 12 (ropa) | Ya en `CREDITOS.md`. Hechos para **nuestra** malla base: encajan sin moldear |
| MakeHuman **hair01** | CC0 (las 25 piezas; zip `hair01_cc0.zip`) | 25 peinados de 11 autores; entre ellos `learning_anime_hair`, 6 bobs de MargaretToigo, trenzas, moños | 11, AB.9d | Misma malla base. El de anime es el primero que miraría |
| Quaternius **Universal Base Characters** | CC0 («Free to use in personal, educational and commercial projects») | 20 peinados, glTF/FBX/OBJ; 6 cuerpos (Superhero, Regular, **Teen**) | AB.9b, 11.5 | La página no nombra cejas ni barba. Trae también cuerpos Teen. Los `.blend` son de pago (Source) |
| Quaternius **Modular Character Outfits – Fantasy** | CC0 (misma frase) | Standard gratis (280 MB); un tercero dice que trae 4 trajes completos + 20 piezas, no los 12 | 12 (con la transferencia del 12.1) | **No comprobado** cuántos trajes trae la versión gratis: mirar el zip |
| KayKit **Adventurers** | CC0 en todas las versiones («no resell unmodified copies») | 5 personajes con armas, escudos y objetos de mano; glTF/FBX | 13 (anclajes `socket_hand_*`) | Las 25+ piezas son de todo el pack; la gratis trae «un puñado» por personaje |
| Micket (OpenGameArt) — peinados low poly | CC0 en «Upcomb» (236 triángulos, `.blend`); los demás aparecen en la colección «CC0 Portraits» | Coleta, punk corto, melena, upcomb, raya al lado | AB.9b (practicar el moldeado) | **No comprobada** la página de cada uno (OpenGameArt dio error 403) |

Fuentes: https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html ·
https://static.makehumancommunity.org/assets/assetpacks/hair01.html ·
https://quaternius.com/packs/universalbasecharacters.html ·
https://quaternius.com/packs/modularcharacteroutfitsfantasy.html · https://kaylousberg.itch.io/kaykit-adventurers ·
https://opengameart.org/content/upcomb-hair-style-for-male-model

**Recomendación:** empezar el pelo por MakeHuman (system assets + hair01): ya encajan en nuestra cabeza, son CC0 y no
hace falta moldear. Quaternius queda para el estilo toon, cuando exista el moldeado (AB.9b).
