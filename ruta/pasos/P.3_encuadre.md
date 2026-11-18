# P.3 — Encuadre: el personaje entero en la vista

> Pulido (2026-11-18). La cámara mira siempre a 1 m de altura desde 3,2 m: con la altura al máximo, con los brazos en
> T, al animar o con el informe desplegado (P.2: la vista se hace más baja) el personaje se sale por arriba o por abajo.

## 1. Objetivo y «Hecho cuando»

**Hecho cuando:** al abrir, al soltar un deslizador, al cambiar Probar huesos o la animación y al cambiar el tamaño de
la vista, la cámara se coloca (con un movimiento suave) para que el personaje entero quepa con margen; la rueda sigue
acercando y alejando (el zoom es relativo al encuadre) y arrastrar sigue girando.

## 2. Nivel de modelo

**Medio** (interfaz; usa `MeshBaker` sin cambiarlo).

## 3. Contexto mínimo

`godot/app/orbit_camera.gd`, `body_view.gd` (`set_values`, `set_animation`, `restyle_timer`), `pruebas/godot/probar_vista.gd`.

## 4. Archivos

- **Se crea:** `pruebas/godot/probar_encuadre.gd`, `godot/app/character_box.gd` (caja rápida con una muestra de vértices: hornear la malla entera tarda 110 ms al soltar cada deslizador).
- **Se tocan:** `orbit_camera.gd` (`frame`, `zoom` relativo, `snap`), `body_view.gd` (`frame_character`).
- **No se toca:** el núcleo.

## 5. Diseño

- `OrbitCamera.frame(box: AABB, aspect: float)`: objetivo = centro de la caja; `fit_distance` = la que hace caber la
  altura (fov vertical) y el radio horizontal (fov horizontal = vertical × aspecto), × `FRAME_MARGIN`, más medio radio
  (la parte del cuerpo más cercana a la cámara). `_process` lleva objetivo y distancia hacia ahí poco a poco; `snap()`
  llega de golpe (pruebas). `distance = clamp(fit × zoom, MIN, MAX)`; `zoom_by` cambia `zoom`. `MAX_DISTANCE` 5 → 8 m.
- `BodyView.frame_character()`: caja de `CharacterBox.measure` (1 de cada 16 vértices y los extremos en reposo, con las formas activas y la pose de ahora; mismo cálculo que `MeshBaker`) → `camera.frame`. Se llama al
  cargar, con su propio temporizador (0,3 s después de mover un deslizador), en `set_pose_t`, en `set_animation` y
  al cambiar el tamaño del `SubViewport`. No en cada fotograma: al caminar la cámara no se mueve.

## 6. Prueba

`probar_encuadre.gd` (sin ventana, con `main.gd`): en cinco casos (inicio; altura 1 en pose T; altura 0; «Caminar»;
informe desplegado con la altura a 1) proyecta todos los vértices horneados con la cámara: todos dentro de la vista y el
personaje ocupa al menos el 60 % del alto o del ancho (`# PROVISIONAL`).
Que detecta el fallo: sin `frame_character`, con la altura a 1 la cabeza o los pies quedan fuera.

## 8. Juicio visual

Abrir el programa, mover la altura y probar huesos: ¿se mueve bien la cámara?
