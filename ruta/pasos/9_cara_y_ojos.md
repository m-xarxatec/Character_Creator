# Fase 9 — Cara y ojos (ficha breve)

> Ficha **breve**: objetivo, tamaño, riesgo y dependencias. Antes de empezar cada paso, un modelo **fuerte** escribe su ficha detallada con los 9 apartados (`GUIA_MODELOS.md` §6).
> Depende de: MVP cerrado. Decisiones: D10 (huesos que faltan), D19 (CC-BY).

**Objetivo de la fase:** una cara editable por rasgos, con ojos propios e iris elegible, y expresiones que viajan en el `.glb`.

**Hecho cuando:** un personaje con cara propia, ojos con iris elegido y 5 expresiones se exporta, y las expresiones se ven en un proyecto de Godot sin el addon.

| Paso | Objetivo | Tam. | Riesgo | Nivel | Depende de |
| --- | --- | --- | --- | --- | --- |
| ★ 9.1 | Mostrar la zona Cara con las 5 formas anime que ya existen: panel → preset → `.glb` → prueba | S | Bajo | simple | 4.7 |
| 9.2 | Deslizadores por rasgo (ojos, nariz, boca, mandíbula, orejas) con targets de cara de MakeHuman (CC0) | M | Medio: memoria por forma | medio | 9.1, Blender en Linux, medida O6 |
| 9.3 | Los 3 huesos que faltan del perfil humanoide (ojos y mandíbula) | M | Medio: cambia `datos/` y la cuenta de huesos de las pruebas | fuerte | 9.2 |
| 9.4 | Ojos nuevos: malla propia y shader de iris por parámetros (color, tamaño de pupila, brillo). Sin `Decal` | L | **Alto**: valle inquietante; juicio visual | fuerte | 9.3 |
| 9.5 | Iris intercambiables como archivos de datos; cejas y pestañas | M | Medio | medio | 9.4 |
| 9.6 | Arreglar las bolsas de boca y ojos aplastadas (hasta 58 mm, `IDEAS.md`) | M | Alto: toca la malla base | fuerte | 9.2 |
| 9.7 | Expresiones: alegría, enfado, tristeza, sorpresa, parpadeo | L | Alto: origen de las formas | fuerte | 9.4, 9.6 |
| 9.8 | Visemas A, I, U, E, O | M | Medio | medio | 9.7 |

## Notas de diseño que no deben perderse

- **9.1 es casi gratis:** quitar `Cara` de `HIDDEN_ZONES` (`godot/app/slider_panel.gd:10`) y comprobar el recorrido completo. Sirve para estrenar la pestaña «Cara y ojos» con una rebanada vertical.
- **Memoria antes de añadir formas (9.2):** cada forma ocupa lo mismo que todas (`RENDIMIENTO.md` §1.2 y O6). Medir el coste de una forma **antes** de decidir cuántas se añaden. Si el presupuesto de Android no da, las formas de cara solo se cargan al editar la cara, o se pasa a formas dispersas (16.4).
- **Las expresiones no son deslizadores del usuario.** Son formas que **se quedan en el `.glb`** con su nombre, para que el juego las anime. Es la primera vez que el `.glb` lleva formas: hoy `CharacterBaker` las hornea todas. Hace falta una regla nueva: «formas de identidad se hornean; formas de expresión se exportan». Cambia `glb_exporter.gd`, `probar_glb.gd` y la tabla «Reglas del personaje exportado» de `CLAUDE.md`. Decisión del responsable antes del 9.7 (D31).
- **Las expresiones deben seguir a la cara editada:** una sonrisa creada sobre la cara neutra se suma a la cara del usuario. Con caras muy cambiadas puede verse mal. Prueba obligatoria: expresión a 1 sobre los 10 cuerpos aleatorios de `probar_aleatorios.gd`.
- **Nombres:** usar los de VRM 1.0 para las expresiones (`happy`, `angry`, `sad`, `surprised`, `blink`, `aa`, `ih`, `ou`, `ee`, `oh`), así la Fase 17 no renombra nada. Son nombres de una especificación abierta, no un asset.
- **Origen de las formas de expresión:** MakeHuman trae unidades de expresión en sus assets CC0 (**NO VERIFICADO** que estén en el paquete instalado y que su licencia sea CC0: comprobar en `CREDITOS.md` y en la página de assets antes de usarlas). Plan B: hacerlas por script, como la cara anime.
- **Ojos (9.4):** esfera achatada propia + shader. El iris se dibuja con matemáticas en el shader (círculos y degradados), no con una textura: pesa 0 bytes, no tiene licencia y se anima (pupila). Los ojos provisionales con `Decal` de `probar_estilo.gd` se retiran: no existen en Compatibility (`PLATAFORMAS.md` §3).
- **Límite del proyecto:** edades de 5 a 60 años (D42, X.17). El chibi es estilización, no edad. Revisión del responsable en cada paso con capturas.

## Juicio visual

Toda la fase. Cada paso termina con una hoja de capturas (frente, tres cuartos, perfil) y el revisor-visual.

## Si te atascas

Si un paso pide un asset que no es CC0 ni propio: **para** (D19).
