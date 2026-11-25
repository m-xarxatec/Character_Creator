# Lo que espera al responsable (2026-11-21)

> Los pasos con `[~]` están hechos salvo esta decisión. Cuando se decida, se cierra el paso y se borra su línea de aquí.

| Paso | Qué decidir | Dónde mirar |
| --- | --- | --- |
| 7.2 | ¿Qué 3 o 4 capturas van al README y en qué orden? El vídeo, cuando el editor esté como quieres | `pruebas/capturas/interfaz/iu11/` y `pruebas/capturas/readme_candidatas/` |
| 7.4 | Cuando estén los de arriba, publicar la 0.2.0 como versión preliminar (D29): `git tag v0.2.0 && git push origin v0.2.0` y `gh release create v0.2.0 build/GameMolde-0.2.0-linux.zip build/GameMolde-0.2.0-linux.zip.sha256 --title "GameMolde 0.2.0" --notes-file build/NOTAS_0.2.0.md --prerelease`. Después, que lo pruebe otra persona sin ayuda Si el `.zip` (62,5 MB) no se puede subir a GitHub, se publica con un enlace externo (decisión del responsable, 2026-11-21). | `build/NOTAS_0.2.0.md` |
| AB, 9.4 | Juicio visual que falta: las piezas sueltas y los ojos (interfaz y uso de piezas ya juzgados el 2026-11-22) | `pruebas/capturas/piezas/` (y abrir el editor: pestañas Pelo, Ropa, Accesorios y Cara y ojos) |
| D36 | ¿Lo nuestro sale CC0 y se publica también como pack suelto? (recomendado: sí) | `propuestas/expansion_v2.md` §7 |
| D39 | ¿Se pueden descargar peinados y armas CC0 (Quaternius, Micket, KayKit), uno a uno y con la licencia comprobada? Necesita tu permiso de red | `propuestas/expansion_v2.md` §5.3 |
| D41 | ¿Las expresiones salen de las «Face Units» CC0? Comprobado en la web el 2026-11-24: son el pack faceunits01 (54 formas ARKit, CC0 según la página de packs; falta ver la licencia dentro del zip) | `ruta/pasos/9.7_expresiones.md` §3 y §5.7 |
| 9.7 | Aprobar la ficha de expresiones y decidir D31, D56 y D57 (con D41) | `ruta/pasos/9.7_expresiones.md` §5.7 |
