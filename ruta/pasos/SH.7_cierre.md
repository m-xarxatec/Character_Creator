# SH.7 — Cierre de la Fase SH: el anime pasa a ser el estilo por defecto

> Ficha del 2026-11-23 (nivel: fuerte). **Hecha el 2026-11-23 en el código; §3 en el PC el 2026-11-24: 1–4 hechos (falta el OK del coste de la sombra); queda el 5.** Decisión: D55.

## 1. Qué cambia

- El personaje nuevo y las tres plantillas son anime: `presets/anime.json`, `femenino.json` y `masculino.json` con `estilo` «anime», `default_finish(true)` y `SKIN_START` (sha256 al día en el manifiesto).
- En Acabado, el interruptor se llama «Estilo anime» (sin «beta»); apagado, el clásico. Las barras van en 400 pasos.
- `BodyMaterial.soft_enabled` sigue en `false`: quien use el addon sin la aplicación sigue teniendo el clásico salvo que llame a `set_style`.
- `diseno/GUIA_ESTILO.md` (§4 y §5) y la fila Estilo de `CLAUDE.md` describen el estilo anime y sus valores.

## 2. Pruebas actualizadas

`probar_presets.gd` (anime.json en anime), `probar_acabado.gd` (empieza en anime; apagar y encender), `probar_pintar_piel.gd` (el clásico se pide apagando el estilo).

## 3. En el PC (necesitan tarjeta gráfica o al responsable)

1. Capturas aprobadas nuevas: `sh pruebas/fase_5/capturas_de_referencia.sh <tmp>`; el responsable las mira y, con su OK, pasan a `pruebas/capturas/aprobadas/` (las de antes eran del clásico; con el anime cambian, como se espera).
2. Miniaturas de las plantillas: `godot --path pruebas/godot -s generar_miniaturas.gd` (salen en anime); comprobar con `probar_presets.gd` (§ miniaturas) y la galería.
3. Rendimiento: `probar_rendimiento.gd` en Forward+ y Mobile; anotar el coste de la sombra proyectada (`probar_sombra.gd`, líneas `ms por fotograma`).
4. `probar_legibilidad.gd`: si su límite de contorno («luminancia < 0,06») falla con la línea teñida, anotar la medida y pedir al responsable el límite nuevo (regla 9).
5. Revisor-visual sobre la hoja de colores (`pruebas/capturas/shader_linea/hoja_colores.png`) y la ropa negra.
