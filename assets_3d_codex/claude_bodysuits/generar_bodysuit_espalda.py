"""Bodysuit de espalda abierta (plano: planos/bodysuit_espalda_abierta.png).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_bodysuit_espalda.py
Escribe packs/claude_bodysuit_espalda/: bodysuit_espalda, una sola pieza (ranura «ropa_torso», cubre «ropa_piernas»),
de un color. Generador de maillots (cortes.py): la piel recortada, pegada al cuerpo.
- Cuello alto (y = 1,455) y manga corta (hasta media parte de arriba del brazo).
- Espalda abierta: un óvalo de bajo el cuello (y ≈ 1,36) a la cintura (y ≈ 1,00), hasta los omóplatos.
- Abajo: delante, la V sube casi hasta la cintura (13,5 cm de media anchura a y = 1,04) sin pasar al muslo; detrás,
  **tanga** (pedido por el responsable): triángulo bajo la cintura que acaba en un hilo de 1,2 cm que se mete por el
  surco y marca la entrepierna.
"""
from pathlib import Path
import cortes as ct

HERE = Path(__file__).parent

NECK_Y = 1.455                                  # cuello alto
SLEEVE_T = 0.45                                 # manga corta: del hombro (0) al codo (1)
BACK_OVAL = (1.18, 0.118, 0.18)                 # abertura de la espalda: centro y, media anchura, media altura
# abajo: media anchura de la tela a cada altura (y, |x|)
FRONT_HW = [(0.77, 0.016), (0.80, 0.022), (0.86, 0.045), (0.92, 0.075), (0.98, 0.105), (1.04, 0.135), (1.08, 0.25)]
BACK_HW = [(0.77, 0.006), (0.845, 0.006), (0.885, 0.030), (0.93, 0.060), (0.98, 0.100), (1.03, 0.140), (1.08, 0.25)]


def main():
    cuts = [ct.neck_top(NECK_Y), ct.sleeve("Left", SLEEVE_T), ct.sleeve("Right", SLEEVE_T),
            ct.oval(*BACK_OVAL), ct.bottom(FRONT_HW, BACK_HW)]
    ct.build(cuts, HERE / "packs" / "claude_bodysuit_espalda", "claude_bodysuit_espalda", "Bodysuit espalda (pruebas)",
             "bodysuit_espalda", "Bodysuit de espalda abierta", [0.12, 0.10, 0.13])


if __name__ == "__main__":
    main()
