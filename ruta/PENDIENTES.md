# Lo que espera al responsable (2026-11-16)

> Se trabaja en remoto: **no hay commits** desde el `fc31de5` (merge de `traspaso`). Todo lo hecho está en el registro de `PLAN.md`.
> Los pasos con `[~]` están hechos salvo esta decisión. Cuando se decida, se cierra el paso y se borra su línea de aquí.

| Paso | Qué decidir | Dónde mirar |
| --- | --- | --- |
| 5.4 | ¿Se entiende el informe? ¿Orden y colores? (todo a 1 sentado da 37 filas, casi todas cruces de dedos) | `(ulimit -v 4000000; timeout 900 godot --path godot)` → Probar huesos; luego todo a 1 y «Sentarse» |
| 5.10 | Umbrales [aviso, error]. Propuesta: sección 20/35 %, cruce 10/30 mm, estiramiento ×3/×6, degenerados 1/1 (hoy 15/30, 5/15, 1,5/2,5, 1/1) | Medidas en el registro de `PLAN.md` (5.10) |
| 5.5 | Pose de exportación: T horneada o A | `pruebas/capturas/pose_exportacion/` (24 hojas, arriba T, abajo A) y su `medidas.md` |
| 5.6 | ¿La espada sigue bien a la mano? (la hoja va a lo largo de +Y del anclaje y en reposo apunta hacia arriba) | `pruebas/capturas/espada/` |
| 5.11 | Qué capturas pasan a `pruebas/capturas/aprobadas/` y el límite (ruido medido 0,000 % → propuesta 0,1 %) | `pruebas/capturas/referencia/vuelta_1/` |
| 5.12 | Preguntas de la ficha `ruta/pasos/5.12_legibilidad.md` §8 | `pruebas/capturas/legibilidad/*_x4.png` |
| 5.13 | Renderizador para PC y para Android (Mobile = Forward+ al píxel y algo más rápido; Compatibility 0,14–0,65 % distinto y 7 veces más lento) | `pruebas/capturas/renderizadores/` y registro (5.13) |
| 5.14 | Qué valores de `GUIA_ESTILO.md` §7 apruebas (móvil: el cuerpo no cabe en triángulos ni textura) | `pruebas/capturas/revision/2026-11-16_presupuesto/presupuesto.md` |
| commits | Hacerlos al volver; también subir los `.uid` que creó Godot | `git status` |
