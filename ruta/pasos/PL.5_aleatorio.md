# PL.5 — Aleatorio (versión simple)

> `propuestas/expansion_v2.md` §4 (PL.5). Decidido por el responsable el 2026-11-20: solo el botón «Aleatorio» con el
> dado, en la galería y en «Nuevo personaje»; candados, «Atrevido» y semilla visible van a `IDEAS.md`.

## 1. Objetivo y «Hecho cuando»

- «Aleatorio» (con el icono de dado) en la pestaña Plantillas y en «Nuevo personaje» pone un cuerpo al azar razonable.

## 2. Nivel de modelo

**Simple.**

## 3. Archivos

- **Se crean:** `godot/app/randomizer.gd`, `godot/app/tema/iconos/dado.svg` (+ `.import` `keep`; propio, MIT).
- **Se tocan:** `template_gallery.gd`, `start_screen.gd`, `main.gd`, `pruebas/godot/probar_plantillas.gd`, `IDEAS.md`, `PLAN.md`.

## 4. Diseño

- `Randomizer.values(actuales, sliders, rng)`: cada deslizador Forma o Proporción del cuerpo entre 0,2 y 0,8, igual en
  los dos lados; Complexión, la cara y el alisado no cambian (respeta la plantilla de partida). Un cambio de Deshacer.
- La tarjeta es la primera de la galería y de «Más cuerpos»; `main.rng` con semilla al azar al arrancar.

## 5. Prueba

`probar_plantillas.gd` (+6): la tarjeta está; el cuerpo en 0,2–0,8 con los lados iguales y lo demás sin tocar; Deshacer;
la misma semilla da lo mismo; 10 tiradas sin errores del informe en pose T; «Nuevo personaje» la tiene.
**Detecta el fallo:** un valor distinto en cada lado.
