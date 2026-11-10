# GameMolde

Un programa libre para crear personajes 3D moviendo deslizadores, y guardarlos listos para usar en un juego hecho con Godot.

> **Estado:** en construcción. Todavía no hay nada que ejecutar.

## Qué hará la primera versión

- Cambiar el cuerpo por zonas (cabeza, torso, brazos, piernas…) con deslizadores.
- Ver el personaje en 3D mientras lo cambias.
- Probarlo con animaciones (caminar, atacar…).
- Guardarlo como archivo `.glb` para tu juego.
- Que se vea como un dibujo: estilo anime, con borde negro grueso alrededor.

## Qué hay en cada carpeta

| Carpeta | Para qué sirve |
| --- | --- |
| `diseno/` | Dibujo de cómo se verá el programa. Ábrelo con el navegador. |
| `referencias/` | Imágenes de inspiración (cuerpos y personajes). |
| `blender/` | Scripts que preparan el cuerpo base con Blender. |
| `datos/` | El cuerpo base ya preparado, listo para el programa. |
| `godot/` | El programa en sí. |
| `pruebas/` | Personajes de prueba y sus resultados. |

## Qué necesitas instalar

- **Blender** 4.2 o superior, con el complemento **MPFB2**.
- **Godot 4**.

## Documentos

- `PLAN.md` — los pasos, uno por uno.
- `IDEAS.md` — ideas para más adelante.
- `CREDITOS.md` — de dónde viene cada cosa que no hicimos nosotros.

## Licencia

- El programa: **MIT** (ver `LICENSE`). Puedes usarlo en tu juego, también si es comercial.
- Los scripts de `blender/`: GPL-3.0 o posterior.
- Los datos del cuerpo (`datos/`): CC0, de MakeHuman.
