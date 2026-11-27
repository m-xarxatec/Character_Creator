"""Bodysuit arnés negro (plano: planos/bodysuit_arnes_negro.png).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_bodysuit_arnes.py
Escribe packs/claude_bodysuit_arnes/: bodysuit_arnes, una sola pieza (ranura «ropa_torso», cubre «ropa_piernas»).
Generador de maillots (cortes.py): la piel recortada, pegada al cuerpo.
- Top corto sin mangas: cuello redondo alto, sisa honda en curva (el hombro queda de tirante de ~4 cm).
- Abierto delante y detrás desde bajo el pecho (arco de y = 1,22 delante y 1,18 detrás): las aberturas se miden en
  grados alrededor del eje del tronco (0 delante, 180 detrás), así lo que queda en el costado es una tira de ~3 cm.
- Abajo: delante V alta con la entrepierna estrecha; detrás tanga triangular, como el plano (decidido por el
  responsable; se probará). Las tiras bajan por el costado hasta los lados de las dos piezas.
- Una hebilla de clip en cada hombro (decidido por el responsable: solo esas dos), sobre una cinta en relieve.
Zonas en COLOR_0: (0,0,0) tela; r = 1 hebillas; g = 1 cinta de los hombros.
"""
import math
from pathlib import Path
import numpy as np

import cortes as ct
import generar_bodysuit_dorado as dor

HERE = Path(__file__).parent
sud, tr, P0 = ct.sud, ct.tr, ct.P0
ct.ZONES["cinta"] = (0, 1, 0, 1)

NECK = (1.405, 0.3, 0.068, 0.070, 0.020)        # cuello redondo: plano y − 0,3·z, elipse (rx, rz) en z = 0,02
ARM_X = [(1.25, 0.25), (1.28, 0.17), (1.31, 0.138), (1.35, 0.115), (1.40, 0.106), (1.50, 0.106)]   # sisa (y, |x|)
AXIS_Z = [(0.90, 0.020), (0.97, 0.045), (1.22, 0.045), (1.30, 0.020)]  # eje del tronco (y, z) para los grados
DEG_M = 0.0022                                  # grados → metros (radio ~12,5 cm), para que el corte sea suave
TOP = [(0, 1.22), (25, 1.212), (50, 1.19), (70, 1.165), (90, 1.155), (110, 1.15), (135, 1.16), (160, 1.175),
       (180, 1.18)]                             # bajo del top (grados, y): arco delante y detrás
OPEN_F = [(0.90, -40), (0.95, 0), (0.955, 20), (0.965, 35), (0.98, 50), (1.00, 62), (1.03, 72), (1.06, 76),
          (1.30, 76)]                           # abertura de delante: medio ángulo desde el centro (y, grados)
OPEN_B = [(0.93, -40), (0.99, 0), (0.995, 20), (1.005, 38), (1.02, 55), (1.05, 72), (1.09, 85), (1.12, 90),
          (1.30, 90)]                           # abertura de detrás: medio ángulo desde la espalda
FRONT_HW = [(0.77, 0.010), (0.80, 0.014), (0.86, 0.035), (0.92, 0.070), (0.98, 0.110), (1.03, 0.150), (1.06, 0.25)]
BACK_HW = [(0.77, 0.008), (0.80, 0.010), (0.86, 0.030), (0.92, 0.055), (0.98, 0.085), (1.02, 0.120), (1.08, 0.25)]
# hebillas
STRAP_X = 0.086                                 # centro del tirante del hombro
WEB_W, WEB_T, WEB_LEN = 0.026, 0.0012, 0.080    # cinta: ancho, grosor y largo (a lo largo del hombro)
BUCKLE_W, BUCKLE_T = 0.032, 0.0045              # hebilla: ancho y grueso
FEMALE, MALE = 0.022, 0.016                     # largo de la hembra (delante) y del macho (detrás)
LIFT = 0.0008                                   # sobre la tela


def armhole(V):
    return np.where(V[:, 1] > ARM_X[0][0], np.abs(V[:, 0]) - np.interp(V[:, 1], *zip(*ARM_X)), -1.0)


def openings(V):
    """Las dos aberturas (> 0 donde se quita): por debajo del arco del top y dentro del medio ángulo de cada lado."""
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    phi = np.degrees(np.arctan2(np.abs(x), z - np.interp(y, *zip(*AXIS_Z))))
    under = np.interp(phi, *zip(*TOP)) - y
    front = np.minimum(under, (np.interp(y, *zip(*OPEN_F)) - phi) * DEG_M)
    back = np.minimum(under, (np.interp(y, *zip(*OPEN_B)) - (180 - phi)) * DEG_M)
    body = np.maximum(V[:, 4], V[:, 5]) < 0.5
    return np.where(body, np.maximum(front, back), -1.0)


# ---------------- hebillas ----------------
def shoulder_line(cloth, s):
    """Línea de la tela sobre el hombro en x = s·STRAP_X, de delante a detrás, alisada; con sus normales."""
    O = cloth.O
    m = (np.abs(O[:, 0] - s * STRAP_X) < 0.004) & (O[:, 1] > 1.33)
    p = O[m]
    order = np.argsort(np.arctan2(p[:, 2], p[:, 1] - 1.31))[::-1]      # de delante (z > 0) a detrás
    p = p[order]
    d = np.r_[0, np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))]
    pts = np.stack([np.interp(np.arange(0, d[-1], 0.003), d, p[:, j]) for j in range(3)], 1)
    pts[:, 0] = s * STRAP_X
    for _ in range(3):
        q, n = cloth.project(pts)
        for _ in range(8):
            q[1:-1] = 0.5 * q[1:-1] + 0.25 * (q[:-2] + q[2:])
        pts = q
    q, n = cloth.project(pts)
    for _ in range(6):
        q[1:-1] = 0.5 * q[1:-1] + 0.25 * (q[:-2] + q[2:])
        n[1:-1] = ct.unit(0.5 * n[1:-1] + 0.25 * (n[:-2] + n[2:]))
    return q, n


def segment(q, n, s0, s1):
    """Trozo de la línea entre las distancias s0 y s1 (desde lo más alto del hombro; + hacia delante)."""
    d = np.r_[0, np.cumsum(np.linalg.norm(np.diff(q, axis=0), axis=1))]
    d = d[q[:, 1].argmax()] - d                                        # 0 arriba, > 0 delante
    t = np.linspace(s0, s1, max(4, int((s1 - s0) / 0.002)))
    order = np.argsort(d)
    p = np.stack([np.interp(t, d[order], q[order, j]) for j in range(3)], 1)
    nn = ct.unit(np.stack([np.interp(t, d[order], n[order, j]) for j in range(3)], 1))
    return p, nn


def chamfer(u0, u1, half, c=0.0012):
    """Perfil rectangular con las aristas de arriba achaflanadas (la hebilla no parece una caja)."""
    return [(u0, -half), (u1 - c, -half), (u1, -half + c), (u1, half - c), (u1 - c, half), (u0, half)]


def layer(q, n, s0, s1, u0, u1, half, c=0.0):
    p, nn = segment(q, n, s0, s1)
    return tr.sweep(p, nn, chamfer(u0, u1, half, c) if c else tr.rect(u0, u1, half))


def buckle(q, n):
    """Hebilla de clip: hembra delante con una pestaña de soltar a cada lado; macho detrás, más fino y estrecho."""
    b0 = LIFT + WEB_T
    c = 0.004                                                          # junta, algo delante de lo más alto
    parts = [layer(q, n, c, c + FEMALE, b0, b0 + BUCKLE_T, BUCKLE_W / 2, 0.0015),             # hembra
             layer(q, n, c - MALE, c, b0, b0 + BUCKLE_T * 0.65, BUCKLE_W * 0.40, 0.0010)]      # macho
    for side in (1, -1):                                               # pestañas, en la junta
        p, nn = segment(q, n, c + 0.001, c + 0.008)
        t = ct.unit(np.gradient(p, axis=0))
        off = side * ct.unit(np.cross(t, nn)) * (BUCKLE_W / 2 + 0.0010)
        parts.append(tr.sweep(p + off, nn, tr.rect(b0 + 0.0008, b0 + BUCKLE_T - 0.0010, 0.0012)))
    return parts


def extras(O, F):
    cloth = dor.Cloth(O, F)
    out = []
    for s in (1, -1):
        q, n = shoulder_line(cloth, s)
        mask = (np.sign(P0[:, 0]) == s) & (P0[:, 1] > 1.30) & (sud.arm_w < 0.5) & (sud.main_bone != "Head")
        out.append((layer(q, n, -WEB_LEN / 2, WEB_LEN / 2, LIFT, LIFT + WEB_T, WEB_W / 2), "cinta", mask))
        out += [(p, "detalle", mask) for p in buckle(q, n)]
    return out


def main():
    cuts = [ct.neck_round(*NECK), armhole, ct.sleeve("Left", 0.0), ct.sleeve("Right", 0.0), openings,
            ct.bottom(FRONT_HW, BACK_HW)]
    ct.build(cuts, HERE / "packs" / "claude_bodysuit_arnes", "claude_bodysuit_arnes", "Bodysuit arnés (pruebas)",
             "bodysuit_arnes", "Bodysuit arnés negro", [0.08, 0.08, 0.09], extras)


if __name__ == "__main__":
    main()
