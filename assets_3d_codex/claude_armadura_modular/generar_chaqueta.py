"""Armadura modular, pieza 2: chaqueta corta de cuero con correas (plano: planos/armadura_modular.png).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_chaqueta.py
Escribe packs/claude_armadura_modular/armadura_chaqueta.glb (ranura «ropa_exterior») y su ficha en el pack.json.
- Chaqueta corta (bolero): la piel del tronco y de los brazos copiada y separada EASE por la normal, alisada, con
  grosor (cuero). Abierta delante (deja sitio al peto): delante acaba sobre el pecho y baja hacia la axila; detrás, a
  media espalda. Manga corta. Cuello ancho.
- Collarín de cuero alrededor del cuello; dos correas delante y dos detrás, cada una con su hebilla cuadrada.
Zonas en COLOR_0: (0,0,0) cuero; r = 1 metal (hebillas); g = 1 correas.
"""
import math, sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).parent
for d in ("claude_bodysuits", "claude_casco"):
    sys.path.insert(0, str(HERE.parent / d))
import cortes as ct
import generar_top_arnes as ta
import generar_bodysuit_dorado as dor
import generar_casco as casco
import pack_modular as pm

sud, tr, bk, P0, F0 = ct.sud, ct.tr, ct.bk, ct.P0, ct.F0
ZONES = {"cuero": (0, 0, 0, 1), "metal": (1, 0, 0, 1), "correas": (0, 1, 0, 1)}
PID = "armadura_chaqueta"

NECK = (1.415, 0.3, 0.105, 0.090, 0.020)         # cuello ancho: plano y − 0,3·z, elipse (rx, rz)
SLEEVE_T = 0.55                                  # manga corta (0 hombro, 1 codo)
HEM_FRONT = (1.345, 1.270, 0.15)                 # delante: y en el centro, y en |x| = el tercero (hacia la axila)
HEM_BACK = 1.170
EASE, THICK, SMOOTH_IT = 0.0060, 0.0020, 10     # sobre el body (2,5 mm), grosor del cuero, alisado
STRAP_HW, STRAP_T, STRAP_LIFT = 0.0085, 0.0022, 0.0006
COLLAR_HW = 0.011
FRONT_STRAPS = [(0.075, 1.352, 1.418)]           # (|x|, de y, a y) delante
BACK_STRAPS = [(0.070, 1.185, 1.425)]
BUCKLE = (0.013, 0.012, 0.0028, 0.0032)          # media anchura, media altura, barra, grosor
MIN_MOVE = 0.0005


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def hem(V):
    x, y = V[:, 0], V[:, 1]
    back = smooth((ta.phi_of(V[:, :3]) - 60) / 60)
    yf = HEM_FRONT[0] + (HEM_FRONT[1] - HEM_FRONT[0]) * smooth(np.abs(x) / HEM_FRONT[2])
    yh = yf * (1 - back) + HEM_BACK * back
    return np.where(np.maximum(V[:, 4], V[:, 5]) > 0.5, -1.0, yh - y)


def jacket():
    cuts = [ct.neck_round(*NECK), ct.sleeve("Left", SLEEVE_T), ct.sleeve("Right", SLEEVE_T), hem]
    V, F, loops = ct.cut_skin(cuts, (1.05, 1.55))
    q, si, sw, n = bk.on_skin(V)
    O = bk.push_out(q + n * EASE, EASE)
    edge = np.zeros(len(O), bool); edge[np.concatenate(loops)] = True
    O = sud.taubin(O, F, edge, SMOOTH_IT)                              # los bordes, quietos (sin dientes)
    O = bk.push_out(O, EASE)
    q, si, sw, n = bk.on_skin(O)
    h = ((O - q) * n).sum(1)
    v, f, src = tr.thick_sheet(O, F, THICK)
    print("MEDIDA chaqueta: %d vértices; a la piel mín %.1f mm; de y = %.3f a %.3f" % (
        len(O), 1000 * h.min(), O[:, 1].min(), O[:, 1].max()))
    return O, F, loops, (v, f), si[src], sw[src], h[src] - THICK * (np.arange(len(v)) >= len(O))


def strap_line(cloth, pts, hw, extra=0.0):
    p = pts.copy()
    for _ in range(3):
        q, n = cloth.project(p)
        for _ in range(4):
            q[1:-1] = 0.5 * q[1:-1] + 0.25 * (q[:-2] + q[2:])
        p = q
    q, n = cloth.project(p)
    q, n = ta.smooth_line(q, n, 4)
    q = above(cloth, q, n)
    return tr.sweep(q + n * (STRAP_LIFT + extra), n, tr.rect(0, STRAP_T, hw)), q, n


def above(cloth, q, n):
    """Saca cada punto por encima de la tela (alisar una línea sobre una superficie curva la mete dentro)."""
    d, i = cloth.kd.query(q, k=8)
    s = np.einsum("ijk,ijk->ij", q[:, None] - cloth.O[i], cloth.n[i]).min(1)
    return q + n * np.maximum(-s, 0)[:, None]


def buckle(c, n, along):
    hw, hh, bw, th = BUCKLE
    ey = ct.unit(along - n * (along @ n))
    ex = np.cross(ey, n)
    base = c + n * (STRAP_LIFT + STRAP_T + th / 2)
    return [casco.box(base + ey * (hh - bw / 2), [hw, bw / 2, th / 2], ex, ey, n),
            casco.box(base - ey * (hh - bw / 2), [hw, bw / 2, th / 2], ex, ey, n),
            casco.box(base + ex * (hw - bw / 2), [bw / 2, hh, th / 2], ex, ey, n),
            casco.box(base - ex * (hw - bw / 2), [bw / 2, hh, th / 2], ex, ey, n),
            casco.box(base, [0.0012, hh * 0.85, th * 0.6], ex, ey, n)]


def side_point(O, x, y, front):
    m = np.where(O[:, 2] > 0.0 if front else O[:, 2] < 0.0)[0]
    k = np.argsort(np.hypot(O[m, 0] - x, O[m, 1] - y))[:4]
    return O[m[k]].mean(0)


def straps(O, F, loops):
    cloth = dor.Cloth(O, F)
    out = []
    for front, specs in ((True, FRONT_STRAPS), (False, BACK_STRAPS)):
        for ax, y0, y1 in specs:
            for s in (1, -1):
                pts = np.array([side_point(O, s * ax, y, front) for y in np.linspace(y0, y1, 14)])
                (v, f), q, n = strap_line(cloth, pts, STRAP_HW)
                out.append(((v, f), "correas"))
                k = 3 if front else len(q) - 4                         # hebilla: abajo delante, arriba detrás
                out += [(b, "metal") for b in buckle(q[k], n[k], q[k + 1] - q[k - 1])]
    neck = max(loops, key=lambda lp: O[lp][:, 1].mean())
    ring = O[neck]
    ring = np.vstack([ring, ring[:3]])
    q, n = cloth.project(ring)
    q, n = ta.smooth_line(q, n, 6)
    q = above(cloth, q, n)
    inward = ct.unit(np.c_[-q[:, 0], np.zeros(len(q)), -(q[:, 2] - 0.0)])
    q = q - inward * 0.004                                             # el collarín, algo por fuera del borde
    out.append((tr.sweep(q + n * STRAP_LIFT, n, tr.rect(-0.001, 0.0035, COLLAR_HW)), "correas"))
    return out


def main():
    old = pm.cards()
    bk.OUT = pm.OUT
    pm.OUT.mkdir(parents=True, exist_ok=True)
    O, F, loops, (v, f), si, sw, h = jacket()
    V, Fs, Z, I, W, H, M = [v], [f], [np.tile(ZONES["cuero"], (len(v), 1))], [ct.pad8(si)], [ct.pad8(sw)], [h], \
        [np.full(len(v), MIN_MOVE)]
    mask = (sud.main_bone != "Head") & ~sud.hand_like & (P0[:, 1] > 1.10)
    for (pv, pf), zone in straps(O, F, loops):
        pi, pw = sud.nearest_skin(pv, 8, mask)
        Fs.append(np.asarray(pf) + sum(len(x) for x in V))
        V.append(pv); I.append(ct.pad8(pi)); W.append(ct.pad8(pw))
        Z.append(np.tile(ZONES[zone], (len(pv), 1)))
        H.append(np.zeros(len(pv))); M.append(np.full(len(pv), MIN_MOVE if zone == "correas" else 0.004))
    sha, _ = bk.write(np.concatenate(V), np.concatenate(Fs), np.concatenate(Z), np.concatenate(I),
                      np.concatenate(W), np.concatenate(H), PID, np.concatenate(M))
    card = tr.card(PID, "Chaqueta corta de cuero (armadura modular)", sha, [0.30, 0.20, 0.17], "ropa", "ropa_exterior")
    pm.save(old, [card])


if __name__ == "__main__":
    main()
