"""Bomber y shorts, pieza 2: top corto negro de tirantes (plano: planos/bomber_verde_y_shorts.webp).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_top.py
Escribe packs/claude_bomber/top_negro.glb (ranura «ropa_torso», no quita los shorts) y su ficha en el pack.json.
Generador de maillots (claude_bodysuits/cortes.py): la piel recortada, separada y tensa bajo el pecho, de una cara.
Cuello redondo alto, sisas de nadadora, acaba bajo el pecho; alisada (no se marca el pecho). Un color.
"""
import numpy as np

import pack_bomber as pb
import cortes as ct

sud, tr, bk, P0 = ct.sud, ct.tr, ct.bk, ct.P0
PID = "top_negro"
NECK = (1.405, 0.3, 0.075, 0.068, 0.020)         # cuello redondo alto: plano y − 0,3·z, elipse (rx, rz)
ARMHOLE = (0.125, 1.20)                          # sisa de nadadora: |x| y desde qué altura
HEM = 1.165                                      # bajo (bajo el pecho)
MIN_MOVE = 0.0005
SMOOTH_IT = 12


def main():
    cuts = [ct.neck_round(*NECK), ct.armhole(*ARMHOLE), lambda V: HEM - V[:, 1]]
    bk.OUT = pb.OUT
    pb.OUT.mkdir(parents=True, exist_ok=True)
    O, F, loops, si, sw = ct.sheet(cuts, (1.10, 1.50))
    edge = np.zeros(len(O), bool); edge[np.concatenate(loops)] = True
    O = bk.push_out(sud.taubin(O, F, edge, SMOOTH_IT), bk.GAP)        # lisa: sin los relieves del pecho
    i, w = ct.pad8(si), ct.pad8(sw)
    h = ((O - (P0[si] * sw[..., None]).sum(1)) * bk.normal_at(bk.SKIN_N, si, sw)).sum(1)
    sha, targets = bk.write(O, F, np.tile(ct.ZONES["tela"], (len(O), 1)), i, w, h, PID, np.full(len(O), MIN_MOVE))
    ct.measure(O, F, loops, si, sw, targets)
    pb.save(tr.card(PID, "Top corto negro (bomber y shorts)", sha, [0.06, 0.06, 0.07], "ropa", "ropa_torso"))


if __name__ == "__main__":
    main()
