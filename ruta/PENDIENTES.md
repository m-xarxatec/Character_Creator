# Lo que espera al responsable (2026-11-21)

> Los pasos con `[~]` están hechos salvo esta decisión. Cuando se decida, se cierra el paso y se borra su línea de aquí.

| Paso | Qué decidir | Dónde mirar |
| --- | --- | --- |
| 7.2 | ¿Qué 3 o 4 capturas van al README y en qué orden? El vídeo, cuando el editor esté como quieres | `pruebas/capturas/interfaz/iu11/` y `pruebas/capturas/readme_candidatas/` |
| 7.4 | Cuando estén los de arriba, publicar la 0.2.0 como versión preliminar (D29): `git tag v0.2.0 && git push origin v0.2.0` y `gh release create v0.2.0 build/GameMolde-0.2.0-linux.zip build/GameMolde-0.2.0-linux.zip.sha256 --title "GameMolde 0.2.0" --notes-file build/NOTAS_0.2.0.md --prerelease`. Después, que lo pruebe otra persona sin ayuda Si el `.zip` (62,5 MB) no se puede subir a GitHub, se publica con un enlace externo (decisión del responsable, 2026-11-21). | `build/NOTAS_0.2.0.md` |
| D36 | ¿Lo nuestro sale CC0 y se publica también como pack suelto? (recomendado: sí) | `propuestas/expansion_v2.md` §7 |
| D39 | ¿Se pueden descargar peinados y armas CC0 (Quaternius, Micket, KayKit), uno a uno y con la licencia comprobada? Necesita tu permiso de red | `propuestas/expansion_v2.md` §5.3 |
| PE.5 | Aplazado a una versión más adelantada (2026-11-26): abrir `heroe.tscn` (exportado con long01) en un proyecto de Godot vacío, sin y con BoneMap: ¿abre sin errores?, ¿el pelo se mueve como en el editor? | `ruta/pasos/PE.5_exportar_pelo.md` §8 |
| 10.3b | Estudio: entrar tarda 1,7 s con 3 piezas (ficha pide 1 s); estudiar horneado en hilo | `godot/app/studio_view.gd` |
| 10.3b | Estudio debe usar el mismo acabado que Cuerpo (máscara de piel, contorno, depth_pull, línea teñida, banda del pelo): tras el juicio de 12.1b-b4 | `godot/app/studio_view.gd` (`_paint`) |
| 12.1b | Prendas por rehacer (responsable): female_casualsuit01, os_golf_shorts, os_short_shorts, cortu_jeans_shorts, os_tank_top, elvs_crude_t-shirt_male, joepal_crude_t-shirt_female, female_sportsuit01, male_casualsuit02, male_casualsuit04, toigo_basic_tucked_t-shirt, namuhekam_male_polo_shirt, toigo_camisole_top, toigo_keyhole_tank_top, toigo_fisherman_sweater, os_vneck_top, os_scrubs_top, os_camisole_top (las 18: hoy la prueba no mide ropa); al tenerlas, sacarlas de `REMAKE` en probar_ropa_extremos.gd | `pruebas/godot/probar_ropa_extremos.gd` |
