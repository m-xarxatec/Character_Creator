# Lo que espera al responsable (2026-11-19)

> Los pasos con `[~]` están hechos salvo esta decisión. Cuando se decida, se cierra el paso y se borra su línea de aquí.

| Paso | Qué decidir | Dónde mirar |
| --- | --- | --- |
| 5.15 / 5.11 | Las capturas de referencia cambian con la pose T nueva (1,6–3,8 %). ¿Pasan las nuevas a `aprobadas/`? | `pruebas/capturas/referencia/vuelta_2/` (y `dif/`); el hombro: `pruebas/capturas/hombro_natural/hombro_natural.png` |
| 6.3 | ¿Se ven bien las formas nuevas al moverse? ¿Aceptas los 2 cruces justificados (manos con brazos delante; muslo–pecho en sentadilla con glúteo redondo)? Propongo pasar el revisor-visual | `pruebas/capturas/formas_propias_banco/` (una carpeta por cuerpo) y registro (6.3) |
| 7.0 | Pruébalo a mano: Guardar preset…, cambia algo, Abrir preset… | `(ulimit -v 4000000; timeout 900 godot --path godot)` |
| 7.1 | Abre el build y compáralo con el editor: ¿alguna diferencia de color, contorno o letra? El build es de antes de la interfaz nueva: rehacerlo antes de mirar | `build/linux/gamemolde.x86_64` frente a `godot --path godot` |
| 7.2 | ¿Qué 3 o 4 capturas van al README y en qué orden? ¿Grabas un vídeo de 30–60 s (mover deslizadores, probar huesos, exportar, abrir en Godot)? Las candidatas son de antes de la interfaz nueva | `pruebas/capturas/readme_candidatas/` |
| 7.4 | Cuando estén los de arriba, publicar como versión preliminar (D29): `git tag v0.1.0 && git push origin v0.1.0` y `gh release create v0.1.0 build/GameMolde-0.1.0-linux.zip build/GameMolde-0.1.0-linux.zip.sha256 --title "GameMolde 0.1.0" --notes-file build/NOTAS_0.1.0.md --prerelease`. Después, que lo pruebe otra persona sin ayuda | `build/NOTAS_0.1.0.md` |
| IU.9 | ¿Se entiende el diálogo «Ajustes»? ¿Se lee bien al 150 %? Al 150 % en 1280 × 720 el panel derecho no cabe y la vista 3D se ve ampliada (se dibuja a tamaño lógico): ¿lo dejamos así, quitamos el 150 % en ventanas pequeñas o va a un paso nuevo? | `pruebas/capturas/ventana/5_ajustes*.png` y `6_tamano_150*.png` |
| Bloque 0 | `propuestas/expansion_v2.md` §2: ¿entran en el plan 0.3 (`probar_rendimiento` con rutas relativas), 0.4 (borde de la prenda en primeros planos) y 0.5 (comando en el PATH)? | `propuestas/expansion_v2.md` §2 |
| Pruebas | Las que necesitan ventana o la salida de Blender no se lanzaron tras integrar `traspaso` | Lista en `ruta/TRABAJO_WINDOWS.md` («En Linux») |
