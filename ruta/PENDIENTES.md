# Lo que espera al responsable (2026-11-16)

> Se trabaja en remoto: **no hay commits** desde el `fc31de5` (merge de `traspaso`). Todo lo hecho está en el registro de `PLAN.md`.
> Los pasos con `[~]` están hechos salvo esta decisión. Cuando se decida, se cierra el paso y se borra su línea de aquí.

| Paso | Qué decidir | Dónde mirar |
| --- | --- | --- |
| 5.15 / 5.11 | Las capturas de referencia cambian con la pose T nueva (1,6–3,8 %). ¿Pasan las nuevas a `aprobadas/`? | `pruebas/capturas/referencia/vuelta_2/` (y `dif/`); el hombro: `pruebas/capturas/hombro_natural/hombro_natural.png` |
| 6.3 | ¿Se ven bien las formas nuevas al moverse? ¿Aceptas los 2 cruces justificados (manos con brazos delante; muslo–pecho en sentadilla con glúteo redondo)? Propongo pasar el revisor-visual | `pruebas/capturas/formas_propias_banco/` (una carpeta por cuerpo) y registro (6.3) |
| 7.0 | Pruébalo a mano: Guardar preset…, cambia algo, Abrir preset… | `(ulimit -v 4000000; timeout 900 godot --path godot)` |
| 7.1 | Abre el build y compáralo con el editor: ¿alguna diferencia de color, contorno o letra? | `build/linux/gamemolde.x86_64` frente a `godot --path godot` |
| 7.2 | ¿Qué 3 o 4 capturas van al README y en qué orden? ¿Grabas un vídeo de 30–60 s (mover deslizadores, probar huesos, exportar, abrir en Godot)? | `pruebas/capturas/readme_candidatas/` |
| 7.4 | **Aplazado (2026-11-18): antes se pule el programa.** Cuando toque, publicar como versión preliminar (D29): `git tag v0.1.0 && git push origin v0.1.0` y `gh release create v0.1.0 build/GameMolde-0.1.0-linux.zip build/GameMolde-0.1.0-linux.zip.sha256 --title "GameMolde 0.1.0" --notes-file build/NOTAS_0.1.0.md --prerelease`. Después, que lo pruebe otra persona sin ayuda | `build/NOTAS_0.1.0.md` |
| foto | `trapecios_extendidos.png` está en la raíz y no en git: no la subas en el commit, o muévela a `referencias/` | — |
| commits | Hacerlos al volver (uno por paso, como siempre); también subir los `.uid` que creó Godot. `cuerpo.glb` cambió (va por LFS) | `git status` |
