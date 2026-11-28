"""Bomber y shorts, pieza 3: shorts de ciclista negros (plano: planos/bomber_verde_y_shorts.webp).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_shorts.py
Escribe packs/claude_bomber/shorts_negros.glb (ranura «ropa_piernas») y su ficha en el pack.json.
La piel recortada de la cintura (talle alto) a medio muslo, separada GAP por su normal y de una cara (ceñidos: sin
«tela tensa», como las mallas de la armadura). Cinturilla y bajos algo más gruesos (relieve). Un color.
"""
import numpy as np

import pack_bomber as pb
import cortes as ct

sud, tr, bk, P0 = ct.sud, ct.tr, ct.bk, ct.P0
PID = "shorts_negros"
GAP = 0.0018                                     # sobre la piel
WAIST = [(0, 1.020), (90, 1.035), (180, 1.050)]  # (grados, y): talle alto, algo más alto detrás
LEG_Y = 0.600                                    # bajo (medio muslo)
AXIS_Z = [(0.90, 0.020), (0.97, 0.045), (1.22, 0.045)]
BAND, BAND_H = 0.030, 0.0012                     # cinturilla: alto y relieve
CUFF, CUFF_H = 0.015, 0.0009                     # bajos
MIN_MOVE = 0.0005


def cut(V):
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    phi = np.degrees(np.arctan2(np.abs(x), z - np.interp(y, *zip(*AXIS_Z))))
    f = np.maximum(y - np.interp(phi, *zip(*WAIST)), LEG_Y - y)
    return np.where(np.maximum(V[:, 4], V[:, 5]) > 0.5, 1.0, f)


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def main():
    bk.OUT = pb.OUT
    pb.OUT.mkdir(parents=True, exist_ok=True)
    V, F, loops = ct.cut_skin([cut], (0.50, 1.15))
    q, si, sw, n = bk.on_skin(V)
    phi = np.degrees(np.arctan2(np.abs(q[:, 0]), q[:, 2] - np.interp(q[:, 1], *zip(*AXIS_Z))))
    top = np.interp(phi, *zip(*WAIST))
    off = GAP + BAND_H * smooth((q[:, 1] - (top - BAND)) / 0.004) + CUFF_H * smooth((LEG_Y + CUFF - q[:, 1]) / 0.004)
    O = bk.to_edges(q + n * off[:, None], loops)
    q, si, sw, n = bk.on_skin(O)
    h = ((O - q) * n).sum(1)
    print("MEDIDA shorts: %d vértices; a la piel mín %.1f mm; de y = %.3f a %.3f" % (
        len(O), 1000 * h[h > GAP * 0.9].min(), O[:, 1].min(), O[:, 1].max()))
    sha, _ = bk.write(O, F, np.tile(ct.ZONES["tela"], (len(O), 1)), ct.pad8(si), ct.pad8(sw), h, PID,
                      np.full(len(O), MIN_MOVE))
    pb.save(tr.card(PID, "Shorts de ciclista negros (bomber y shorts)", sha, [0.06, 0.06, 0.07], "ropa",
                    "ropa_piernas"))


if __name__ == "__main__":
    main()
