# GameMolde

Un programa libre para crear personajes 3D moviendo deslizadores y guardarlos listos para un juego hecho con Godot.
El personaje sale en estilo anime (sombra de tres tonos y borde negro), con esqueleto humanoide y en pose T.

## Descargar y abrir

1. Descarga la última versión de la página de versiones: https://github.com/m-xarxatec/Character_Creator/releases
2. Linux: descomprime el `.zip` y dale permiso de ejecución: `chmod +x gamemolde.x86_64`. Ábrelo con doble clic.
3. Necesitas una tarjeta gráfica con **Vulkan**. Sin ella el programa no abre la ventana.

Todo va en un solo archivo: no hace falta instalar Godot.

## Crear un personaje en 5 pasos

1. **Elige una zona** a la derecha (Global, Cabeza, Torso, Brazos…): se despliegan sus deslizadores.
2. **Mueve los deslizadores.** Con «Simetría» marcada, un lado mueve el otro.
3. **Deshacer** (Ctrl+Z) y **Rehacer** (Ctrl+Y) si te equivocas; «Restablecer zona» la deja como al principio.
4. **Probar huesos** (abajo): el personaje se pone en pose T; con la lista de animaciones lo ves caminar, atacar o
   sentarse, y un informe te avisa si alguna articulación se deforma demasiado.
5. **Exportar .glb**: elige dónde guardarlo. Al lado se escribe un `.tres` con el material.

«Guardar preset…» y «Abrir preset…» guardan tu trabajo en un `.json` para seguir otro día.

## Usar el personaje en Godot

1. Copia el `.glb` y el `.tres` a tu proyecto de Godot 4.
2. Selecciona el `.glb` → pestaña «Import» → «Advanced…» → nodo `Skeleton3D` → «Retarget» → «Bone Map» → nuevo
   `BoneMap` con el perfil `SkeletonProfileHumanoid` (se rellena solo: los huesos ya tienen esos nombres) →
   «Reimport». **No hace falta «Overwrite Axis»**: los huesos ya salen con los ejes del perfil humanoide.
   Sin BoneMap, Godot no ajusta `Skeleton3D.motion_scale` y la cadera se desplaza al animar.
3. El `.tres` es el material toon (tres tonos y borde negro): arrástralo a la malla. Sin él, el personaje se ve con
   el material sencillo que lleva el `.glb`.
4. Puntos de anclaje para colgar cosas: `socket_hand_r`, `socket_hand_l`, `socket_back` y `socket_hip`. Por ejemplo:

   ```gdscript
   var sword := preload("res://espada.tscn").instantiate()
   $Personaje.find_child("socket_hand_r").add_child(sword)
   ```

5. Animaciones: sirve cualquier animación humanoide con BoneMap, por ejemplo la
   [Universal Animation Library de Quaternius](https://quaternius.com/packs/universalanimationlibrary.html) (CC0).

## Qué sale en el `.glb`

| Regla | Valor |
| --- | --- |
| Unidades y ejes | Metros; Y arriba; mirando a +Z |
| Pose de reposo | Pose T |
| Esqueleto | 56 huesos con nombres de `SkeletonProfileHumanoid` (los ojos y la mandíbula, sin pesos: para animar la mirada o la boca más adelante), con los ejes del perfil |
| Pesos | Máximo 4 influencias por vértice, y suman 1 |
| Malla | La base completa de MakeHuman (unos 27.000 triángulos), sin detalle anatómico; prenda base pintada, que se puede quitar |
| Anclajes | `socket_hand_r`, `socket_hand_l`, `socket_back`, `socket_hip`: nodos vacíos hijos del hueso |

## Para desarrolladores

- **Godot 4.7.2** (no .NET). Para regenerar `godot/datos/`: **Blender 5.2.2** con **MPFB 2.0.18**.
- **Git LFS** es obligatorio: sin él, `cuerpo.glb` es un archivo de texto de 130 bytes y el editor no carga.
  El botón «Download ZIP» de GitHub no incluye los archivos de Git LFS: clona con `git lfs` instalado.
- Abrir el editor: `godot --path godot`. Una prueba: `godot --headless --path pruebas/godot -s probar_carga.gd`
  (cada script de prueba dice en su cabecera cómo se lanza). El build de Linux: `sh pruebas/fase_7/probar_build_linux.sh`.
  Después, `sh scripts/instalar_lanzador.sh` lo abre con la orden `gamemolde` y desde el menú (sin `sudo`).

| Carpeta | Para qué sirve |
| --- | --- |
| `godot/` | El programa: `addons/creador/` es el núcleo y `app/` la interfaz. |
| `godot/datos/` | El cuerpo base ya preparado y las animaciones de prueba; viaja dentro del programa. |
| `godot/packs/` | Piezas que se ponen al personaje (pelo, ropa, accesorios): el pack base, CC0. |
| `blender/` | Scripts que preparan el cuerpo base con Blender. |
| `pruebas/` | Pruebas automáticas y sus resultados. |
| `scripts/` | Utilidades: instalar la orden `gamemolde`. |
| `diseno/` | Dibujo de cómo se verá el programa. Ábrelo con el navegador. |

Documentos: `PLAN.md` (los pasos), `IDEAS.md` (lo que viene después), `CREDITOS.md` (lo que no hicimos nosotros).

## Licencias y créditos

- El programa: **MIT** (ver `LICENSE`). Puedes usarlo en tu juego, también si es comercial.
- **Los personajes que exportas son tuyos:** salen de datos CC0 y no heredan la licencia del programa. Puedes usarlos
  en juegos comerciales sin pedir permiso ni dar crédito.
- Los datos del cuerpo (`godot/datos/`): **CC0**, de MakeHuman. Las formas propias (cara anime de
  `blender/cara_anime.py` y hombros, glúteos y alisado de `blender/formas_propias.py`) y sus zonas también son CC0:
  son datos de salida de los scripts, no código GPL.
- El pack base (`godot/packs/base/`): **CC0**. Sus mallas salen de la misma malla de MakeHuman; el resto lo genera
  el programa al vuelo.
- Los scripts de `blender/`: GPL-3.0 o posterior.
- El programa exportado lleva Godot Engine (MIT) y sus bibliotecas: sus avisos están en el botón «Licencias».
  Todo lo de terceros, en `CREDITOS.md`.
