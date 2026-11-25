# Lo que espera al responsable (2026-11-21)

> Los pasos con `[~]` están hechos salvo esta decisión. Cuando se decida, se cierra el paso y se borra su línea de aquí.

| Paso | Qué decidir | Dónde mirar |
| --- | --- | --- |
| 7.2 | ¿Qué 3 o 4 capturas van al README y en qué orden? El vídeo, cuando el editor esté como quieres | `pruebas/capturas/interfaz/iu11/` y `pruebas/capturas/readme_candidatas/` |
| 7.4 | Cuando estén los de arriba, publicar la 0.2.0 como versión preliminar (D29): `git tag v0.2.0 && git push origin v0.2.0` y `gh release create v0.2.0 build/GameMolde-0.2.0-linux.zip build/GameMolde-0.2.0-linux.zip.sha256 --title "GameMolde 0.2.0" --notes-file build/NOTAS_0.2.0.md --prerelease`. Después, que lo pruebe otra persona sin ayuda Si el `.zip` (62,5 MB) no se puede subir a GitHub, se publica con un enlace externo (decisión del responsable, 2026-11-21). | `build/NOTAS_0.2.0.md` |
| AB, 9.4 | Juicio visual que falta: las piezas sueltas y los ojos (interfaz y uso de piezas ya juzgados el 2026-11-22) | `pruebas/capturas/piezas/` (y abrir el editor: pestañas Pelo, Ropa, Accesorios y Cara y ojos) |
| D36 | ¿Lo nuestro sale CC0 y se publica también como pack suelto? (recomendado: sí) | `propuestas/expansion_v2.md` §7 |
| D39 | ¿Se pueden descargar peinados y armas CC0 (Quaternius, Micket, KayKit), uno a uno y con la licencia comprobada? Necesita tu permiso de red | `propuestas/expansion_v2.md` §5.3 |
| 9.6 | Visto bueno a la ficha de la bolsa de la boca (código ya escrito; no cambia nada de lo que se ve) | `ruta/pasos/9.6_bolsa_boca.md` |
| 9.7 | Juicio visual de las expresiones (hoja de 9.7.0, tras regenerar los datos) y del programa | `pruebas/capturas/expresiones/` y la lista «Expresión» de la barra |
