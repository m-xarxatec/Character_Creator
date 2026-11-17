# ESTADO DEL TRASPASO — qué hay en `ruta/`

> Sesión de traspaso terminada el 2026-11-16 (se cortó una vez por el límite de uso y se retomó el mismo día).
> Todo se escribió sobre el commit `61aaee9` de la rama `traspaso`, **sin ejecutar nada**: esta máquina (Windows) no tiene Godot ni Blender.
> Nada de `ruta/` está aplicado: son propuestas. No se tocó ningún archivo fuera de `ruta/`.

## Entregables

| Entregable | Archivo | Estado |
| --- | --- | --- |
| 3.1 Mapa completo | `HOJA_DE_RUTA.md` | Completo |
| 3.2 Arquitectura | `ARQUITECTURA.md` | Completo |
| 3.3 Windows y Android | `PLATAFORMAS.md` | Completo |
| 3.4 Cambios mínimos de arquitectura | `pasos/A1` a `A4` (A5, A6 y A7 van dentro de otras fichas) | Detalladas |
| 3.4 MVP pendiente | `pasos/4.4` a `4.7`, `5.1` a `5.14`, `6.1` a `6.3`, `7.1` a `7.4` | Detalladas (25 fichas) |
| 3.4 Primera fase tras el MVP (Windows) | `pasos/8.1` a `8.5` | Detalladas |
| 3.4 Resto de fases | `pasos/9_…` a `17_…` | Breves (9 fichas, una por fase) |
| 3.5 Catálogo de ideas | `IDEAS_AL_LIMITE.md` | Completo |
| 3.6 Rendimiento | `RENDIMIENTO.md` | Completo, **sin medidas nuevas** (comandos en su §1.3) |
| 3.7 Decisiones | `DECISIONES.md` | D1 a D31 |
| 3.8 Guía para modelos | `GUIA_MODELOS.md` y `propuesta_CLAUDE.md` | Completo; el diff no está aplicado |

## Extra: borradores del código difícil (`ruta/codigo/`)

Además de los entregables, quedó escrita la parte de nivel fuerte de seis pasos, cada una con su prueba: `WorldPose` (A3), IK de dos huesos (10.10), formato `.gmolde` (10.1), largo y grosor de hueso (16.1), generador de cuernos (13.5) y transferencia de formas a la ropa (12.1). **Sin ejecutar.** Empezar por `ruta/codigo/README.md`: dice cómo lanzar las seis pruebas sin mover nada, qué hacer con cada tipo de fallo y qué le falta a cada pieza.

Con esto, A3 pasa de nivel fuerte a **medio** (colocar, probar y añadir el caso con la especie real).

## Al juntar con la máquina Linux (2026-11-16)

- Las 6 pruebas de `ruta/codigo/` pasan en Godot 4.7.2 y las 6 detectan el fallo de su cabecera. Arreglos, solo en `probar_transferencia.gd`: un `%` sin escapar; el «desplazamiento de lado» se mide solo si el punto cae dentro del triángulo (en una arista del tubo de caras planas es 1,96 mm por geometría); la «piel que asoma» no cuenta el borde exacto de la prenda (y = 0,2 y 0,8), donde decide el redondeo.
- Decisiones y fichas borradas: `DECISIONES.md`, apartado «Tomadas al juntar las ramas». Las fichas que siguen pueden citar `WorldPose` o fichas borradas: se revisan al empezar su paso.

## Lo que queda por hacer (no se pudo en esta sesión)

1. **Medir.** Lanzar en la máquina Linux los comandos M1 a M6 de `RENDIMIENTO.md` §1.3 y guardar el resultado en `ruta/medidas/`. M2 a M4 piden crear antes `pruebas/godot/probar_medidas.gd` (paso simple, con propuesta).
2. **Resolver los «NO VERIFICADO».** Cada uno tiene su comprobación en una ficha. Los que más pesan: los cuatro de A2c (leer `datos/` desde un `.pck`), `SpringBoneSimulator3D` en 4.7 (11.3) y el selector de archivos en Android (15.5).
3. **Fichas detalladas de las fases 9 a 17.** Se escriben una a una, justo antes de cada paso, por un modelo fuerte (`GUIA_MODELOS.md` §6).
4. **Juntar con el otro ordenador.** Allí hay un informe de arranque y quizá `propuestas/hoja_de_ruta.md`. `ruta/` no existe allí: no habrá choques de archivos. Si los dos análisis discrepan en algo, decide el responsable; anotarlo en `DECISIONES.md`.

## Repaso de coherencia hecho

- Todas las fichas citadas desde otros documentos existen (comprobado con `grep`).
- Los apartados de `RENDIMIENTO.md` citados desde fuera (§1.2, §2, O1, O3, O6, O8) existen con ese número.
- Los niveles de la lista de `GUIA_MODELOS.md` §2 se copiaron del apartado 2 de cada ficha.
- Los «Hecho cuando» de las fases 8 a 17 son los mismos en `HOJA_DE_RUTA.md` §3 y en las fichas.
- Códigos de decisión: D1 a D31, sin huecos ni repetidos. Cambios de arquitectura: A1 a A7.
