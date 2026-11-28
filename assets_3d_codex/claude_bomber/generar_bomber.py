"""Bomber y shorts, pieza 1: bomber verde corta (plano: planos/bomber_verde_y_shorts.webp).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_bomber.py
Escribe packs/claude_bomber/bomber_verde.glb (ranura «ropa_exterior») y su ficha en el pack.json.
- Como el jersey rosa (claude_bodysuits/generar_jersey_rosa.py): la piel del tronco y los brazos, separada por la
  normal (ancha y abombada sobre la cinturilla: pedido por el responsable), alisada; delante cae recta desde el pecho. **Abierta delante como el plano**: los bordes de la
  abertura y el bajo, sueltos; el cuello, pegado. Mangas abullonadas hasta la muñeca, con puño de canalé; bajo con
  cinturilla de canalé. Con grosor; **forro negro** por dentro (se ve por la abertura).
- Cuello de canalé alto, abierto delante. Cremallera en cada borde de la abertura.
- Detalles: dos franjas verde oscuro en el pecho derecho, bolsillo con cremallera en el pecho izquierdo, bolsillo con
  cremallera y lengüeta naranja en la manga izquierda.
Zonas en COLOR_0: (0,0,0) verde; r = 1 verde oscuro; g = 1 metal; b = 1 naranja; r = g = 1 forro negro.
"""
import math
import numpy as np
from scipy.spatial import cKDTree

import pack_bomber as pb
import cortes as ct
import generar_top_arnes as ta
import generar_bodysuit_dorado as dor
import generar_jersey_rosa as jr

sud, tr, bk, bt, P0 = ct.sud, ct.tr, ct.bk, None, ct.P0
ZONES = {"verde": (0, 0, 0, 1), "oscuro": (1, 0, 0, 1), "metal": (0, 1, 0, 1), "naranja": (0, 0, 1, 1),
         "forro": (1, 1, 0, 1)}
PID = "bomber_verde"

JN_Y, HEM = 1.405, 1.000                         # borde del cuello (bajo el cuello de canalé) y bajo (cintura)
J_GAP, THICK = 0.0030, 0.0025
EASE = 0.034                                     # holgura del tronco (ancha: pedido por el responsable)
BLOUSE, BLOUSE_Y = 0.012, 0.06                   # sobre la cinturilla se abomba: cuánto y a qué altura sobre ella
BAND, BAND_EASE = 0.045, 0.014                   # cinturilla del bajo: alto y holgura (recogida)
OPEN = [(1.00, 0.050), (1.20, 0.045), (1.34, 0.032), (1.42, 0.022)]    # abertura delante: media anchura por y
SLEEVE_T, CUFF_T = 1.97, 1.83                    # manga hasta la muñeca; puño desde aquí
GLOBE = [(0.0, 0.034), (0.3, 0.052), (0.7, 0.062), (1.1, 0.068), (1.5, 0.068), (1.70, 0.055), (1.78, 0.022),
         (1.84, 0.006), (2.0, 0.005)]                # mangas anchas (pedido por el responsable); el puño, pegado
GLOBE_SIDE, CUFF_EASE = 0.5, 0.005
RIB_H, RIB_N = 0.0013, 28                        # canalé de puños y cinturilla: alto y cuántos (alrededor)
SMOOTH_IT = 14
LOOSE_ARM = 0.5
MIN_MOVE, REL_MIN_MOVE = 0.001, 0.001
# cuello de canalé
COLLAR_Y0, COLLAR_TOP_BACK, COLLAR_TOP_FRONT = 1.395, 1.475, 1.440
COLLAR_OFF, COLLAR_GAP = 0.016, 0.42             # holgura; media abertura delante (radianes)
COLLAR_COLS, COLLAR_ROWS = 72, 12
# detalles
ZIP_HW, ZIP_T = 0.0035, 0.0022
STRIPES = [(1.335, 0.0065), (1.310, 0.0065)]     # franjas del pecho derecho: y, media altura
STRIPE_X = (-0.135, -0.055)
CHEST_ZIP = [(0.060, 1.330), (0.085, 1.250)]     # bolsillo del pecho izquierdo (de arriba abajo)
POCKET = ("Left", (0.38, 0.70), (-0.42, 0.42))   # bolsillo de la manga: lado, t, ángulo (0 fuera y arriba)
LIFT, REL_T = 0.0010, 0.0016


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


# ---------------- capa de la bomber ----------------
def cuts():
    hem = lambda V: np.where(np.maximum(V[:, 4], V[:, 5]) > 0.5, -1.0, HEM - V[:, 1])
    front = lambda V: np.where((V[:, 2] > 0.02) & (np.maximum(V[:, 4], V[:, 5]) < 0.5),
                               np.interp(V[:, 1], *zip(*OPEN)) - np.abs(V[:, 0]), -1.0)
    return [ct.neck_top(JN_Y), ct.sleeve("Left", SLEEVE_T), ct.sleeve("Right", SLEEVE_T), hem, front]


def layer():
    """La tela: (O, F, si, sw, loops, suelta)."""
    V, F, loops = ct.cut_skin(cuts(), (0.90, 1.50))
    q, si, sw, n = bk.on_skin(V)
    skin = q
    aL, aR = ta.arm_side(si, sw)
    arm = np.maximum(aL, aR)
    torso = arm < 0.3
    jr.HEM = HEM
    band = torso & (skin[:, 1] < HEM + BAND)
    above_band = skin[:, 1] - HEM - BAND
    blouse = BLOUSE * np.exp(-((above_band - BLOUSE_Y) / 0.07) ** 2)
    ease = np.where(band, BAND_EASE + (EASE - BAND_EASE) * smooth((above_band + 0.01) / 0.02), EASE + blouse)
    D = n * ease[:, None] + jr.drape(skin, torso) * (~band)[:, None]
    free = ~band
    for side, a in (("Left", aL), ("Right", aR)):
        m = a > 0.05
        t, c, _ = ta.axis(side).frame(skin[m])
        g = np.minimum(np.interp(t, *zip(*GLOBE)), GLOBE_SIDE * ta.TORSO_KD.query(V[m])[0])
        g = np.where(t > CUFF_T, CUFF_EASE, g)
        b = np.clip((a[m] - 0.05) / 0.6, 0, 1)[:, None]
        D[m] = D[m] * (1 - b) + ct.unit(V[m] - c) * g[:, None] * b
        free[np.where(m)[0][t > CUFF_T - 0.03]] = False
    bnd = np.unique(np.concatenate(loops))
    neck = bnd[V[bnd, 1] > JN_Y - 0.012]
    D[neck], free[neck] = 0, False
    adj, deg = sud.laplacian(F, len(V))
    for _ in range(40):
        D[free] = (0.5 * D + 0.5 * (adj @ D) / deg[:, None])[free]
    tight = np.r_[neck, bnd[arm[bnd] > 0.5]]                           # cuello y puños: bajan a la piel
    edge = np.clip(cKDTree(V[tight]).query(V)[0] / bk.EDGE_BAND, 0, 1)
    edge = (edge * edge * (3 - 2 * edge))[:, None]
    O = sud.taubin(V + n * J_GAP + D * edge, F, ~free, SMOOTH_IT)
    for side, a in (("Left", aL), ("Right", aR)):                      # canalé del puño
        m = a > 0.5
        t, c, ang = ta.axis(side).frame(skin[m])
        O[m] += ct.unit(O[m] - c) * np.where(t > CUFF_T, RIB_H * (0.5 + 0.5 * np.cos(RIB_N * ang)), 0)[:, None] * edge[m]
    phi = np.radians(ta.phi_of(skin))                                  # canalé de la cinturilla
    O[band] += n[band] * (RIB_H * (0.5 + 0.5 * np.cos(4 * RIB_N * phi[band])))[:, None]
    O = bk.push_out(O, THICK + 0.0015)
    ni, nw = sud.nearest_skin(O, 8, ~sud.hand_like & (sud.main_bone != "Head"))
    arm2 = np.maximum(*ta.arm_side(*bk.on_skin(O)[1:3]))
    tb = np.clip((LOOSE_ARM - arm2) / LOOSE_ARM, 0, 1)[:, None]
    si, sw = np.c_[si, ni], np.c_[sw * (1 - tb), nw * tb]
    top = np.argsort(-sw, 1)[:, :8]
    si, sw = np.take_along_axis(si, top, 1), np.take_along_axis(sw, top, 1)
    sw /= sw.sum(1, keepdims=True)
    print("MEDIDA bomber: %d vértices; de y = %.3f a %.3f" % (len(O), O[:, 1].min(), O[:, 1].max()))
    return O, F, si, sw, loops, arm2 < LOOSE_ARM


def piece(O, F, si, sw, loose):
    """Con grosor: fuera verde, dentro forro negro (y el labio, verde)."""
    v, f, src = tr.thick_sheet(O, F, THICK)
    n = len(O)
    zone = np.full(len(v), "verde", object)
    zone[n:2 * n] = "forro"
    i, w = si[src], sw[src]
    h = ((v - (P0[i] * w[..., None]).sum(1)) * bk.normal_at(bk.SKIN_N, i, w)).sum(1)
    h[loose[src]] = 0                                                  # lo suelto, sin girar con la normal
    return v, f, np.array([ZONES[z] for z in zone], float), i, w, h


# ---------------- cuello ----------------
def collar():
    """Cuello de canalé abierto delante: columnas alrededor del cuello (radio medido con rayos) + holgura y canalé."""
    a = np.linspace(COLLAR_GAP, 2 * math.pi - COLLAR_GAP, COLLAR_COLS)              # 0: delante (abierto)
    u = np.linspace(0, 1, COLLAR_ROWS)
    d = np.c_[np.sin(a), np.zeros_like(a), np.cos(a)]
    top = COLLAR_TOP_BACK - (COLLAR_TOP_BACK - COLLAR_TOP_FRONT) * smooth(np.cos(a) * 0.5 + 0.5)
    y = COLLAR_Y0 + np.outer(u, top - COLLAR_Y0)
    r = np.array([[jr.ray_neck(np.array([0, y[j, i], jr.TN_Z]), d[i]) for i in range(COLLAR_COLS)]
                  for j in range(COLLAR_ROWS)])
    bad = np.isnan(r)
    r[bad] = np.nanmean(np.where(bad, np.nan, r), 1, keepdims=True).repeat(COLLAR_COLS, 1)[bad]
    raw = r.copy()
    for _ in range(8):
        r[:, 1:-1] = 0.5 * r[:, 1:-1] + 0.25 * (r[:, :-2] + r[:, 2:])
        r[1:-1] = 0.5 * r[1:-1] + 0.25 * (r[:-2] + r[2:])
        r = np.maximum(r, raw)
    r = np.maximum.accumulate(r[::-1], 0)[::-1] * 0.5 + r * 0.5
    off = COLLAR_OFF + RIB_H * (0.5 + 0.5 * np.cos(2 * RIB_N * a))[None]
    v = (np.stack([np.zeros_like(y), y, np.full_like(y, jr.TN_Z)], -1) + d[None] * (r + off)[..., None])
    rows, cols = np.meshgrid(np.arange(COLLAR_ROWS - 1), np.arange(COLLAR_COLS - 1), indexing="ij")
    k = rows * COLLAR_COLS + cols
    f = np.concatenate([np.stack([k, k + COLLAR_COLS, k + 1], -1).reshape(-1, 3),
                        np.stack([k + 1, k + COLLAR_COLS, k + COLLAR_COLS + 1], -1).reshape(-1, 3)])
    v = v.reshape(-1, 3)
    nf = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    if (nf * (v[f].mean(1) - [0, 0, jr.TN_Z]) * [1, 0, 1]).sum() < 0:
        f = f[:, ::-1]
    return tr.thick_sheet(v, f, 0.003)[:2]


# ---------------- detalles ----------------
def front_edges(O, loops):
    """Los dos bordes de la abertura (de abajo arriba)."""
    bnd = np.unique(np.concatenate(loops))
    p = O[bnd]
    gap = np.interp(p[:, 1], *zip(*OPEN))
    m = (p[:, 2] > 0.02) & (np.abs(np.abs(p[:, 0]) - gap) < 0.02) & (p[:, 1] > HEM + 0.004) & (p[:, 1] < JN_Y - 0.01)
    out = []
    for s in (1, -1):
        e = p[m & (np.sign(p[:, 0]) == s)]
        out.append(e[np.argsort(e[:, 1])])
    return out


def zipper(cloth, edge):
    y = np.linspace(edge[0, 1], edge[-1, 1], 40)
    pts = np.c_[np.interp(y, edge[:, 1], edge[:, 0]), y, np.interp(y, edge[:, 1], edge[:, 2])]
    pts -= np.c_[np.sign(pts[:, 0]) * 0.004, np.zeros((len(pts), 2))]   # algo hacia dentro del borde
    q, n = cloth.project(pts)
    q, n = ta.smooth_line(q, n, 3)
    return tr.sweep(above(cloth, q, n) + n * LIFT, n, tr.rect(0, ZIP_T, ZIP_HW))


def above(cloth, q, n):
    d, i = cloth.kd.query(q, k=8)
    s = np.einsum("ijk,ijk->ij", q[:, None] - cloth.O[i], cloth.n[i]).min(1)
    return q + n * np.maximum(-s, 0)[:, None]


def line(cloth, pts, hw, t=REL_T):
    q, n = cloth.project(pts)
    for _ in range(3):
        q[1:-1] = 0.5 * q[1:-1] + 0.25 * (q[:-2] + q[2:])
        q, n = cloth.project(q)
    q, n = ta.smooth_line(q, n, 3)
    return tr.sweep(above(cloth, q, n) + n * LIFT, n, tr.rect(0, t, hw))


def details(O, F):
    cloth = dor.Cloth(O, F)
    out = []
    for y, hh in STRIPES:
        pts = np.array([cloth.front(x, y)[0] for x in np.linspace(*STRIPE_X, 16)])
        out.append((line(cloth, pts, hh), "oscuro"))
    (x0, y0), (x1, y1) = CHEST_ZIP
    pts = np.array([cloth.front(x0 + (x1 - x0) * k, y0 + (y1 - y0) * k)[0] for k in np.linspace(0, 1, 12)])
    out.append((line(cloth, pts, 0.0025, ZIP_T), "metal"))
    side, (t0, t1), (a0, a1) = POCKET
    sl = ta.Sleeve(O, F, side)
    T, A = np.meshgrid(np.linspace(t0, t1, 10), np.linspace(a0, a1, 9), indexing="ij")
    p, n = sl.hit(T.ravel(), A.ravel())
    p, n = p.reshape(10, 9, 3), n.reshape(10, 9, 3)
    base = p + n * LIFT
    import generar_botas as bt_
    out.append((bt_.grid_slab(base + n * 0.0025, base), "verde"))
    zp, zn = p[:, 1], n[:, 1]                                          # cremallera del bolsillo, junto a su borde
    out.append((tr.sweep(zp + zn * (LIFT + 0.0025), zn, tr.rect(0, ZIP_T, 0.0022)), "metal"))
    tp, tn = p[-2:, 6].mean(0), n[-2:, 6].mean(0)                     # lengüeta naranja abajo
    along = ct.unit(p[-1, 6] - p[-3, 6])
    side_v = np.cross(tn, along)
    import generar_casco as casco
    out.append((casco.box(tp + tn * (LIFT + 0.0035), [0.006, 0.010, 0.0012], side_v, along, tn), "naranja"))
    flap = base[:2] + n[:2] * 0.0028                                   # tapeta verde oscuro arriba
    out.append((bt_.grid_slab(flap + n[:2] * 0.0015, flap), "oscuro"))
    return out


# ---------------- montaje ----------------
def main():
    bk.OUT = pb.OUT
    pb.OUT.mkdir(parents=True, exist_ok=True)
    O, F, si, sw, loops, loose = layer()
    v, f, z, i, w, h = piece(O, F, si, sw, loose)
    V, Fs, Z, I, W, H, M = [v], [f], [z], [ct.pad8(i)], [ct.pad8(w)], [h], [np.full(len(v), MIN_MOVE)]
    upper = (sud.main_bone != "Head") & ~sud.hand_like & (P0[:, 1] > 0.95)
    cloth = dor.Cloth(O, F)
    parts = [(collar(), "verde", (P0[:, 1] > 1.34) & (sud.arm_w < 0.3))]
    parts += [(zipper(cloth, e), "metal", upper) for e in front_edges(O, loops)]
    parts += [(m, zone, upper) for m, zone in details(O, F)]
    for (pv, pf), zone, mask in parts:
        pi, pw = sud.nearest_skin(pv, 8, mask)
        Fs.append(np.asarray(pf) + sum(len(x) for x in V))
        V.append(pv); I.append(ct.pad8(pi)); W.append(ct.pad8(pw))
        Z.append(np.tile(ZONES[zone], (len(pv), 1)))
        H.append(np.zeros(len(pv))); M.append(np.full(len(pv), REL_MIN_MOVE))
    sha, _ = bk.write(np.concatenate(V), np.concatenate(Fs), np.concatenate(Z), np.concatenate(I),
                      np.concatenate(W), np.concatenate(H), PID, np.concatenate(M))
    pb.save(tr.card(PID, "Bomber verde (bomber y shorts)", sha, [0.42, 0.48, 0.32], "ropa", "ropa_exterior"))


if __name__ == "__main__":
    main()
