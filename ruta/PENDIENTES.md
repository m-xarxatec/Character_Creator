# Lo que espera al responsable (2026-11-20)

> Los pasos con `[~]` están hechos salvo esta decisión. Cuando se decida, se cierra el paso y se borra su línea de aquí.

| Paso | Qué decidir | Dónde mirar |
| --- | --- | --- |
| 7.1 | Cuando lo decidas: rehacer el build (es de antes de la interfaz nueva) y compararlo con el editor | `build/linux/gamemolde.x86_64` frente a `godot --path godot` |
| 7.2 | ¿Qué 3 o 4 capturas van al README y en qué orden? El vídeo, cuando el editor esté como quieres | `pruebas/capturas/interfaz/iu11/` y `pruebas/capturas/readme_candidatas/` |
| 7.4 | Cuando estén los de arriba, publicar como versión preliminar (D29): `git tag v0.1.0 && git push origin v0.1.0` y `gh release create v0.1.0 build/GameMolde-0.1.0-linux.zip build/GameMolde-0.1.0-linux.zip.sha256 --title "GameMolde 0.1.0" --notes-file build/NOTAS_0.1.0.md --prerelease`. Después, que lo pruebe otra persona sin ayuda | `build/NOTAS_0.1.0.md` |
