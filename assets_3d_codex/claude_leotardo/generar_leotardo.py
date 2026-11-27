"""Leotardo negro (plano: planos/Tablero de referencia 360° de leotardo negro.webp), con la espalda tipo bikini.

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_leotardo.py
Escribe packs/claude_leotardos/: leotardo_negro, una sola pieza (ranura «ropa_torso», cubre «ropa_piernas»), de un color.
Con el generador de maillots (../claude_bodysuits/cortes.py): **la piel recortada y separada 2,5 mm, pegada al cuerpo**
(decidido por el responsable tras el bodysuit de espalda abierta; antes era la malla de cuerpo completo, que hacía
puente en la ingle). Bordes que bajan a la piel, sin ribete.
- Cuello redondo alto (1 cm bajo la base del cuello) y sin mangas (sisa en |x| = 0,15; el hombro queda de tirante).
- Delante, tipo bikini: sube por la ingle y se para en el pliegue (donde la piel pasa a ser muslo: L hecha).
- Detrás, braguita de bikini en curva (pedida por el responsable).
"""
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent / "claude_bodysuits"))
import cortes as ct

NECK = (1.39, 0.3, 0.085, 0.075, 0.025)         # cuello redondo: plano y − 0,3·z, elipse (rx, rz) en z = 0,025
ARM_X, ARM_Y = 0.150, 1.05                      # sisa: |x| = 0,15 por encima de y = 1,05
# abajo: media anchura de la tela a cada altura (y, |x|)
FRONT_HW = [(0.774, 0.030), (0.815, 0.050), (0.865, 0.070), (0.915, 0.100), (0.950, 0.135), (0.975, 0.165),
            (1.000, 0.25)]                      # bikini: sube por la ingle (y no pasa al muslo)
BACK_HW = [(0.774, 0.030), (0.776, 0.035), (0.815, 0.075), (0.885, 0.115), (0.955, 0.155), (0.980, 0.25)]   # en curva


def main():
    cuts = [ct.neck_round(*NECK), ct.armhole(ARM_X, ARM_Y), ct.sleeve("Left", 0.0), ct.sleeve("Right", 0.0),
            ct.bottom(FRONT_HW, BACK_HW, top=1.0)]                 # sin brazos: sisa y manga cero
    ct.build(cuts, HERE / "packs" / "claude_leotardos", "claude_leotardos", "Leotardos (pruebas)", "leotardo_negro",
             "Leotardo negro", [0.10, 0.10, 0.11])


if __name__ == "__main__":
    main()
