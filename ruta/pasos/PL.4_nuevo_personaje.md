# PL.4 — Ventana «Nuevo personaje» (versión simple)

> `propuestas/expansion_v2.md` §4 (PL.4). Aprobado el 2026-11-20 («sigue», en la línea de «simplifícalo»).

## 1. Objetivo y «Hecho cuando»

- Al arrancar y con «Nuevo…» (barra superior) sale una ventana con Femenina, Masculino y Neutro en grande, «Más
  cuerpos», «Recientes», «Abrir preset…» y «Mostrar al arrancar».

## 2. Nivel de modelo

**Simple.**

## 3. Archivos

- **Se crean:** `godot/app/start_screen.gd`, `pruebas/godot/probar_inicio.gd`.
- **Se tocan:** `godot/app/main.gd`, `godot/app/settings_file.gd` (`pantalla_inicio`, `recientes`),
  `godot/app/body_actions.gd` (guardar y abrir apuntan el reciente), `PLAN.md`.

## 4. Diseño (simplificado)

- Un `AcceptDialog` que reutiliza las tarjetas de la galería (nombres, miniaturas y valores). Elegir un cuerpo = la
  galería (solo el cuerpo, Ctrl+Z). Los botones de estilo del 14.7 se añadirán cuando existan.
- Sin «Archivo › Nuevo» (no hay menú Archivo): botón «Nuevo…» en la barra superior; así quien quite «Mostrar al
  arrancar» la puede volver a abrir. La casilla está solo en la ventana (no en Ajustes).
- Se abre sola solo si `main` es la escena principal (no en las pruebas, que crean `main` a mano).
- «Recientes»: se guardan los 8 últimos abiertos o guardados; se enseñan los que aún existen, el más nuevo primero, en
  una zona con desplazamiento (la ventana mide 666 px de alto, quepa lo que quepa).

## 5. Prueba

`probar_inicio.gd`: no se abre sola en las pruebas; «Nuevo…» la abre; 3 grandes y 8 en «Más cuerpos»; elegir Femenina
la cierra y pone ese cuerpo; «Recientes» con un archivo borrado, repetidos y abrir uno.
**Detecta el fallo:** `get_recent` sin mirar si el archivo existe.
