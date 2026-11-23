# AB — Pack Base 1: piezas que se anclan al cuerpo

> Ficha del 2026-11-21 (Opus 5.5; no hay Fable). Diseño: `propuestas/expansion_v2.md` §5 y `ruta/ARQUITECTURA.md` §6.
> Pedido por el responsable: seguir el orden de la expansión sin parar. D37 (exportar los helpers): **a)**, decidida por
> el modelo (técnica). D36, D39 y D41 siguen siendo del responsable (licencia, descargas y expresiones).

## 1. Objetivo y «Hecho cuando»

Pelo, ropa y accesorios sobre el personaje, que sigan a todos los deslizadores, a la pose T y a las animaciones, y que
salgan en el `.glb`. Hecho cuando (fase): ver `expansion_v2.md` §5.4, «Hecho cuando (fase AB)».

## 2. Nivel de modelo

Fuerte (AB.3, AB.4, AB.7); medio el resto.

## 3. Archivos

- Núcleo: `pack_library.gd` (AB.2), `body_piece.gd` (AB.4), `body_derived.gd` (AB.9a, AB.10); `character_updater.gd`,
  `character_baker.gd`, `sockets.gd` y `glb_exporter.gd` (AB.7: las piezas detrás del cuerpo en el esqueleto).
- Interfaz: `body_view.gd` (`library`, `set_piece`), `body_actions.gd` (menú «Piezas», provisional hasta AB.13).
- Blender: `blender/exportar_helpers.py` (AB.3). Datos: `godot/packs/base/` (`packs/*` entra en el `.pck`).

## 4. Diseño

- **Dos clases de pieza que sigue al cuerpo:**
  1. Con archivo (AB.3): `helper-tights`, `helper-skirt` y `helper-hair` de la malla base. Formas de MakeHuman medidas en
     sus vértices; las de cara y propias, copiadas del vértice de piel más cercano. Comprobado: los targets las mueven y
     el rig les da pesos. `helper-hair` es un volumen de melena que tapa la cara: queda como base, no como casquete.
  2. Derivadas (AB.9a, AB.10): caras de la piel elegidas por una máscara (huesos + zonas en fracciones de su caja),
     separadas por la normal. Se hacen al vuelo en Godot: no ocupan sitio. Casquete, guantes, calcetines y botas.
- **Seguir al cuerpo** = colgar del mismo `Skeleton3D` + `follow()` tras cada `update` (pesos de forma por nombre y bind
  poses copiadas del cuerpo). Una pieza por ranura, salvo `accesorio`.
- **Exportar:** cada pieza, malla aparte del mismo esqueleto, horneada igual que el cuerpo, con un `StandardMaterial3D`
  de su color. El `.tres` toon es el del cuerpo.

## 5. Prueba

Pendiente (la sesión del 2026-11-21 se hizo sin pruebas, a petición del responsable): `probar_packs.gd` (licencias,
rechazos, fichas), `probar_pieza_cuerpo.gd` (sigue a 10 cuerpos al azar y a «Atacar»; piel por fuera, medida),
`probar_exportar.gd` con piezas (mallas, piel y suelo). Hechas a mano: humo de poner, quitar, seguir y exportar.

## 6. Siguiente

AB.6 (ocultar la piel bajo la ropa), AB.13 (pestañas Ropa y Pelo), AB.11 (accesorios rígidos), AB.5 (cortes de prenda),
AB.8 (largo de falda), AB.9b–d (peinados; necesitan D39 y permiso de red), AB.12 (orejas) y AB.14 (publicar el pack).
