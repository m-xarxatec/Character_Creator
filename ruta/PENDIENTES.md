# Lo que espera al responsable (2026-11-21)

> Los pasos con `[~]` están hechos salvo esta decisión. Cuando se decida, se cierra el paso y se borra su línea de aquí.

| Paso | Qué decidir | Dónde mirar |
| --- | --- | --- |
| 7.1 | Después de las 8:00 del 2026-11-21: rehacer el build como **0.2.0** (decidido el 2026-11-21; el de ahora es la 0.1.0, de antes de la interfaz nueva) y compararlo con el editor | `build/linux/gamemolde.x86_64` frente a `godot --path godot` |
| 7.2 | ¿Qué 3 o 4 capturas van al README y en qué orden? El vídeo, cuando el editor esté como quieres | `pruebas/capturas/interfaz/iu11/` y `pruebas/capturas/readme_candidatas/` |
| 7.4 | Cuando estén los de arriba, publicar la 0.2.0 como versión preliminar (D29): `git tag v0.2.0 && git push origin v0.2.0` y `gh release create v0.2.0 build/GameMolde-0.2.0-linux.zip build/GameMolde-0.2.0-linux.zip.sha256 --title "GameMolde 0.2.0" --notes-file build/NOTAS_0.2.0.md --prerelease`. Después, que lo pruebe otra persona sin ayuda | `build/NOTAS_0.2.0.md` (se escribe con el build) |
| AB, 9.4 | Juicio visual de las piezas y los ojos (2026-11-21) | `pruebas/capturas/piezas/` (y abrir el editor: pestañas Pelo, Ropa, Accesorios y Cara y ojos) |
| D36 | ¿Lo nuestro sale CC0 y se publica también como pack suelto? (recomendado: sí) | `propuestas/expansion_v2.md` §7 |
| D39 | ¿Se pueden descargar peinados y armas CC0 (Quaternius, Micket, KayKit), uno a uno y con la licencia comprobada? Necesita tu permiso de red | `propuestas/expansion_v2.md` §5.3 |
| D41 | ¿Las expresiones salen de las «Face Units» CC0 (sin comprobar aún)? | `propuestas/expansion_v2.md` §7 |
| RE.1a | Revisar qué assets de MakeHuman se quedan (pack de 43,99 MB, límite provisional `MH_MAX_BYTES`) | `godot/packs/makehuman/` y `pruebas/capturas/piezas_mh/hoja_lote2.png` |
