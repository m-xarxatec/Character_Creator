# GameMolde · Taller de Assets

## Retomar el trabajo

1. Comprueba la rama y el árbol de trabajo con Git de solo lectura. La auditoría TA.0 se hizo en `taller_asets`.
2. Lee [CLAUDE.md](CLAUDE.md) y el protocolo de [GUIA_MODELOS.md](ruta/GUIA_MODELOS.md). Consulta el estado del Taller y las últimas cinco entradas del registro en [PLAN.md](PLAN.md). Allí se mantiene el punto de reanudación.
3. Sigue [pasos_a_seguir.md](<taller assets/pasos_a_seguir.md>) y la ficha del paso actual en `ruta/pasos/`. [El plan del Taller](<taller assets/plan.md>) define el MVP offline. [Las ideas](<taller assets/ideas.md>) se incorporan únicamente por decisión del responsable.
4. Comprueba qué parte de la ficha tiene aprobación explícita. Dentro de ese alcance, ejecuta los comandos de terminal, las comprobaciones y las correcciones rutinarias de forma autónoma. Presenta al responsable los cambios de alcance, dependencias o decisiones importantes antes de actuar.
5. Cierra cada implementación con los resultados reales de la prueba, el fallo provocado y restaurado, las regresiones y el registro en `PLAN.md`. El responsable aprueba el paso siguiente y realiza todas las operaciones Git de escritura, incluidos commits y pushes.

## Puntos de integración

- Consulta [la arquitectura](ruta/ARQUITECTURA.md) y [la fase AB](propuestas/expansion_v2.md) antes de trabajar en packs, ropa o exportación. Verifica su implementación en `godot/`; `ruta/codigo/` contiene borradores.
- La receta edita el asset, el pack lo conserva y el GLB lo entrega al juego. Mantén el núcleo GDScript independiente de la interfaz. Los cambios al sistema de personajes, al rig o al exportador requieren justificación y aprobación específica.
