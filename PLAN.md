# PLAN — GameMolde (hasta el MVP)

> Paso a paso. Un paso cada vez y siempre con aprobación (ver `CLAUDE.md`).
> Lo que no es del MVP va a `IDEAS.md`.

**Estado actual:** Fase 1 · 1.1 hecho · 1.2 pendiente
**Leyenda:** `[ ]` pendiente · `[~]` en curso · `[x]` hecho

---

## Qué es el MVP

Un programa hecho con Godot, con una pestaña **Cuerpo** que permite:

- Editar un cuerpo humano por zonas (14 zonas) con deslizadores de **forma** y de **proporción**, con simetría.
- Ver el resultado en vivo en un maniquí 3D y probarlo con animaciones.
- Exportar un `.glb` listo para un juego de Godot: huesos reajustados, pesos correctos, perfil humanoide y puntos de anclaje.
- **Estilo ilustración** (anime 3D): sombra a dos tonos y contorno negro grueso, igual en el editor y en el juego.

**Fuera del MVP:** cara y ojos, pelo, ropa (salvo la prenda base), accesorios, catálogo de packs y VRM.

---

## Fase 0 — Preparación

- [x] 0.1 Instalar Blender 4.2 LTS o superior, MPFB2 y el pack "MakeHuman system assets". Anotar versiones en `CLAUDE.md`.
- [x] 0.2 Instalar Godot 4 estable y anotar la versión en `CLAUDE.md`.
- [x] 0.3 Crear el repositorio git con la estructura de `CLAUDE.md` y un `CREDITOS.md` vacío.
- [x] 0.4 Prueba a mano: humano en MPFB2 → `.glb` → Godot con `SkeletonProfileHumanoid` → animación CC0 de Quaternius.
- [x] 0.5 Decidir la licencia del editor (MIT o GPL-3.0) y un nombre provisional.

**Hecho cuando:** el humano de prueba camina en Godot sin deformaciones raras y las versiones están anotadas.

---

## Fase 1 — Pipeline en Blender (sin ventana)

- [x] 1.1 Script `blender/generar_cuerpo.py`: recibe un JSON con valores y crea el humano con MPFB2.
- [ ] 1.2 Aplicar el rig *Game engine*, el proxy ligero y la prenda base. (Ojo: el pack no trae ropa interior; se decide al llegar, buscando material gratuito con licencia limpia.)
- [ ] 1.3 Hornear formas, quitar helpers y resolver las máscaras.
- [ ] 1.4 Exportar `.glb` según `CLAUDE.md` (sección 6) y añadir los 4 puntos de anclaje.
- [ ] 1.5 Renders de frente, perfil y espalda para revisarlos.
- [ ] 1.6 Prueba automática: el `.glb` se abre en Godot sin errores y el BoneMap se rellena solo.

**Hecho cuando:** `blender -b -P blender/generar_cuerpo.py -- cuerpo.json salida.glb` funciona con 5 JSON distintos.

---

## Fase 2 — Datos para Godot

- [ ] 2.1 Tabla de deslizadores del MVP: zona → deslizador → tipo (Forma / Proporción / Por crear) → target de MakeHuman o hueso.
- [ ] 2.2 Definir el formato de `datos/` (manifiesto con `version`).
- [ ] 2.3 Conversor `blender/exportar_datos.py`: malla base, formas, pesos, vértices de cada articulación y anclajes de la prenda.
- [ ] 2.4 Prueba: reajustar los huesos fuera de Blender da el mismo resultado que MPFB2 (diferencia < 1 mm) en 5 cuerpos.

**Hecho cuando:** `datos/` está completa, versionada y probada.

---

## Fase 3 — Núcleo en Godot (sin interfaz)

- [ ] 3.1 Cargar `datos/` y montar malla y esqueleto.
- [ ] 3.2 Deslizadores de forma (*blend shapes*) con simetría.
- [ ] 3.3 Deslizadores de proporción (longitud y escala de huesos).
- [ ] 3.4 Reajuste de huesos (centro de vértices) y *bind poses*.
- [ ] 3.5 Prenda base que sigue al cuerpo.
- [ ] 3.6 Exportar `.glb`: hornear, 4 influencias, anclajes y nombres humanoides.
- [ ] 3.7 Guardar y cargar presets en JSON.
- [ ] 3.8 Pruebas: 10 cuerpos aleatorios → exportar → reimportar → comparar.
- [ ] 3.9 Estilo ilustración: shader de sombra a dos tonos + contorno negro (grosor ajustable), dentro del núcleo.
- [ ] 3.10 Al exportar, el personaje sale con ese estilo listo para el juego (el `.glb` + el material de Godot).

**Hecho cuando:** todas las pruebas pasan sin tocar la interfaz.

---

## Fase 4 — Interfaz: pestaña Cuerpo

Según `diseno/maqueta-pestana-cuerpo.html`.

- [ ] 4.1 Ventana con pestañas (solo Cuerpo activa).
- [ ] 4.2 Vista 3D con cámara orbital y maniquí en vivo.
- [ ] 4.3 Zonas y deslizadores con etiqueta de tipo.
- [ ] 4.4 Simetría, deshacer y rehacer, y "restablecer zona".
- [ ] 4.5 Botones Probar huesos y Exportar .glb conectados al núcleo.
- [ ] 4.6 El maniquí se ve con el estilo ilustración; control de grosor del contorno.

**Hecho cuando:** se crea y se exporta un personaje usando solo el ratón.

---

## Fase 5 — Banco de pruebas de huesos

- [ ] 5.1 Animaciones de prueba CC0: reposo, caminar, correr, atacar, sentarse.
- [ ] 5.2 Poses extremas: brazos arriba, sentadilla, giro de tronco.
- [ ] 5.3 Comprobaciones automáticas: pesos que suman 1, ≤ 4 influencias, 56 huesos humanoides, anclajes presentes.
- [ ] 5.4 Informe visible (bien / aviso / error) con la zona afectada.

**Hecho cuando:** un cuerpo extremo muestra los avisos correctos.

---

## Fase 6 — Formas propias ("Por crear")

- [ ] 6.1 Esculpir con MakeTarget las formas que faltan (glúteos, pecho, cabeza chibi…).
- [ ] 6.2 Añadirlas a `datos/` y subir la versión.
- [ ] 6.3 Probarlas en el banco de pruebas.

**Hecho cuando:** ningún deslizador del MVP queda como "Por crear".

---

## Fase 7 — Entrega del MVP

- [ ] 7.1 Builds para Linux (y Windows, si se decide).
- [ ] 7.2 README con capturas, vídeo y créditos.
- [ ] 7.3 Revisión de licencias y de `CREDITOS.md`.
- [ ] 7.4 Release en GitHub.

**Hecho cuando:** otra persona descarga el editor, crea un personaje y lo usa en Godot sin ayuda.

---

## Registro

| Fecha | Paso | Qué se hizo |
| --- | --- | --- |
| 2026-11-10 | — | Creación de PLAN.md, IDEAS.md, CLAUDE.md y la maqueta de la pestaña Cuerpo |
| 2026-11-10 | 0.1 / 0.3 | Blender 5.2.2 LTS anotado; carpetas creadas, `README.md` y `CREDITOS.md`; maqueta a `diseno/`, conceptos a `referencias/cuerpos/` |
| 2026-11-10 | 0.1 | MPFB 2.0.18 activado en Blender 5.2.2; prueba sin ventana: humano base de 19158 vértices |
| 2026-11-10 | 0.2 | Godot 4.7.2 estable instalado (`godot` en el PATH) |
| 2026-11-10 | — | Meta visual añadida al MVP: estilo ilustración con contorno (pasos 3.9, 3.10 y 4.6) |
| 2026-11-10 | 0.1 | Pack "MakeHuman system assets" (CC0) instalado en MPFB; zips borrados |
| 2026-11-10 | 0.4 (parcial) | Humano MPFB + rig Game engine → `.glb` → Godot sin ventana: 53 huesos, 1,66 m, mira a +Z, 4 influencias que suman 1. Sale en pose A. Falta la parte a mano: BoneMap y animación |
| 2026-11-10 | 0.4 | BoneMap humanoide por script (53/56), animaciones de Quaternius sobre el humano: caminar, atacar y sentarse sin deformaciones. Hallazgo: la pose A rompe los brazos; hace falta pose T |
| 2026-11-10 | 0.5 | Licencia MIT para el editor (`LICENSE`) y nombre provisional GameMolde. Fase 0 terminada |
| 2026-11-10 | 1.1 | `blender/generar_cuerpo.py`: JSON (versión 1) → cuerpo MPFB con macros y targets, validado y con los pies en el suelo. 5 cuerpos de ejemplo y 23 pruebas |
