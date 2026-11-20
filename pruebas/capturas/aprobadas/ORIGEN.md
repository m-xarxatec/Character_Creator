# Origen de las capturas aprobadas

Aprobadas por el responsable el 2026-11-20 (pasos 5.11 y 5.15: pose T con la clavícula al 25 %). Son la
`vuelta_2` de `pruebas/fase_5/capturas_de_referencia.sh`; las de hoy (`vuelta_3`, con los datos de PL.0c) dan 0,000 %
(cámaras, luz y fondo: los de `pruebas/godot/capturar_banco.gd`). Conservan su nombre para compararlas por nombre.
Las anteriores (2026-11-16, pose T sin clavícula) se aprobaron el 2026-11-18 y están en el historial de git.

| Dato | Valor |
| --- | --- |
| Máquina | Linux, NVIDIA GeForce GTX 1650 (controlador 580.178.04) |
| Godot | 4.7.2 estable |
| Renderizador | forward_plus |
| Límite | 0,1 % de píxeles distintos (ruido medido: 0,000 %) |

Solo valen para esta máquina: en otra, vuelve a generarlas y compáralas entre sí antes de usarlas.
