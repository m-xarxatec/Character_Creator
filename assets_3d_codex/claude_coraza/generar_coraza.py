"""Coraza medieval de acero (peto y espaldar unidos por los costados, cresta en el centro del peto, bordes con reborde,
tirantes de cuero con hebilla en los hombros y dos correas con hebilla en cada costado) para la humana de GameMolde.

Uso:  python generar_coraza.py
Lee godot/datos/humana/cuerpo.glb (forma, pesos y formas) y el esqueleto de godot/packs/base/tights.glb; escribe en
packs/claude_corazas/ una sola pieza, coraza_acero (ranura «ropa_exterior»), con todo. Hoy sale de un color (el núcleo
pinta uno por pieza), pero cada zona va marcada en COLOR_0: r = 0 metal, r = 1 cuero; g = 1, además, hebillas y remaches.
Cómo se construye: el tronco se envuelve rodaja a rodaja (envolvente convexa sin brazos ni cabeza, suavizada, más GAP):
cubre el pecho por encima sin meterse entre los senos. El contorno (cuello en V, pestañas de los hombros, sisas y bajo
en pico) sale de la rejilla ángulo × altura. Formas del cuerpo: la envolvente se recalcula con cada forma (sigue al
cuerpo como metal liso); los tirantes, sobre el hombro, copian la piel. Pesos: de la piel, solo huesos del tronco y los
hombros (los brazos y las piernas no doblan el metal).
"""
import hashlib, json, math, struct, sys
from pathlib import Path
import numpy as np
from scipy.spatial import ConvexHull, cKDTree

sys.path.insert(0, str(Path(__file__).parents[1] / "claude_gorra"))
import glb

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / "packs" / "claude_corazas"

# --- medidas (metros) ---
GAP, THICK, ZC = 0.015, 0.003, 0.03              # holgura a la piel, grosor de la chapa, eje de la rejilla (z)
NH, NR = 64, 34                                 # columnas por mitad (NA = 2·NH) y filas
Y_BOT_F, Y_BOT_S, Y_BOT_B, U_V = 0.935, 0.985, 0.968, 1.10   # bajo: pico delante, costado, espalda; ancho del pico (rad)
Y_NECK_F, Y_TAB_F, Y_TAB_B, Y_NECK_B = 1.335, 1.368, 1.385, 1.362   # cuello en V, pestañas de los hombros, cuello atrás
Y_ARM, ARM_P = 1.195, 2.2                       # fondo de la sisa y su forma (|t|^p)
TAB_X = (0.060, 0.102)                          # cada pestaña del hombro, de x a x
ARM_CLEAR = 0.025                               # la sisa deja al menos esto hasta el brazo (en reposo)
RIDGE_H, RIDGE_W = 0.010, 0.12                  # cresta del peto: alto y medio ancho
FLARE, FLARE_H = 0.008, 0.04                    # el bajo se abre hacia fuera
CAIDA, Y_CAIDA, SMOOTH = 0.45, 1.30, 2.5        # bajo el pecho se estrecha ≤ CAIDA m por m; suavizado (filas)
ROLL_R, SEAM_R = 0.0045, 0.0022                 # reborde de los bordes; costura de los costados
X_STRAP, STRAP_W, STRAP_T, STRAP_GAP = 0.080, 0.032, 0.004, 0.010   # tirantes: x, ancho, grosor, hueco al hombro
SIDE_Y, SIDE_L, SIDE_W, SIDE_T = (1.045, 1.125), 0.10, 0.022, 0.003  # correas de los costados
MIN_SHAPE = 0.0015                              # formas que mueven menos que esto, fuera


# ---------------- cuerpo ----------------
body, body_buf = glb.read(ROOT / "godot/datos/humana/cuerpo.glb")
B = glb.mesh_data(body, body_buf)
P0 = B["POSITION"].astype(float)
F0 = B["indices"].reshape(-1, 3)
JN = glb.joint_names(body)
J, W = B["JOINTS_0"].astype(int), B["WEIGHTS_0"].astype(float)
_, _first, _inv = np.unique(np.round(P0 / 1e-6).astype(np.int64), axis=0, return_index=True, return_inverse=True)
P0, J, W = P0[_first], J[_first], W[_first]                         # costuras de UV fundidas
F0 = _inv.ravel()[F0]
F0 = F0[(F0[:, 0] != F0[:, 1]) & (F0[:, 1] != F0[:, 2]) & (F0[:, 0] != F0[:, 2])]
TARGETS = {k: d[_first] for k, d in B["targets"].items()}


def bone_weight(pred):
    ids = [i for i, n in enumerate(JN) if pred(n)]
    return (W * np.isin(J, ids)).sum(1)


ARMISH = bone_weight(lambda n: any(k in n for k in ("UpperArm", "LowerArm", "Hand", "Thumb", "Index", "Middle",
                                                     "Ring", "Little")))
HEADW = bone_weight(lambda n: n == "Head")
BODY_MASK = (ARMISH < 0.3) & (HEADW < 0.3)
ARM_MASK = ARMISH > 0.5


def vertex_normals(v, f):
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    n = np.zeros_like(v)
    for k in range(3):
        np.add.at(n, f[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


N0 = vertex_normals(P0, F0)
_tri = F0[BODY_MASK[F0].all(1) & (P0[F0][:, :, 1].min(1) > 0.86) & (P0[F0][:, :, 1].max(1) < 1.50)]
_bary = np.array([(i, j, 4 - i - j) for i in range(5) for j in range(5 - i)], float) / 4
DENSE = np.einsum("bk,tkc->tbc", _bary, P0[_tri]).reshape(-1, 3)    # nube densa del tronco


# ---------------- envolvente: radio por altura y ángulo ----------------
TAB_Y = np.arange(0.90, 1.455, 0.005)
TAB_A = np.linspace(-math.pi, math.pi, 361)
BACK = [np.where((np.abs(DENSE[:, 1] - y) < 0.004) & (DENSE[:, 2] < ZC))[0] for y in TAB_Y]   # espalda de cada rodaja
_K = np.exp(-0.5 * (np.arange(-6, 7) / SMOOTH) ** 2)
_K /= _K.sum()


def hull_radius(q):
    """Radio de la envolvente convexa de q (puntos xz respecto al eje) en cada ángulo de TAB_A."""
    h = ConvexHull(q)
    nrm, off = h.equations[:, :2], -h.equations[:, 2]
    d = np.stack([np.sin(TAB_A), np.cos(TAB_A)], 1)
    dn = d @ nrm.T
    t = np.where(dn > 1e-9, off[None] / np.maximum(dn, 1e-9), np.inf)
    return t.min(1)


def envelope(cloud):
    """Radios (altura × ángulo) de cada rodaja de la nube a su altura real (un pecho que cuelga cuenta donde cuelga),
    suavizados en altura (nunca hacia dentro) y con caída bajo el pecho; y cuánto ha subido cada rodaja del cuerpo
    base, medido en la espalda (el pecho no cuenta: al colgar tiraría hacia abajo)."""
    order = np.argsort(cloud[:, 1])
    ys = cloud[order, 1]
    tab = np.zeros((len(TAB_Y), len(TAB_A)))
    for j, y in enumerate(TAB_Y):
        lo, hi = np.searchsorted(ys, [y - 0.004, y + 0.004])
        tab[j] = hull_radius(cloud[order[lo:hi]][:, [0, 2]] - [0, ZC]) if hi - lo >= 8 else tab[j - 1]
    lift = np.array([np.median(cloud[s, 1]) for s in BACK]) - TAB_Y
    tab = np.maximum(tab, np.apply_along_axis(lambda c: np.convolve(np.pad(c, 6, mode="edge"), _K, "valid"), 0, tab))
    for j in range(len(TAB_Y) - 2, -1, -1):
        if TAB_Y[j] < Y_CAIDA:
            tab[j] = np.maximum(tab[j], tab[j + 1] - CAIDA * 0.005)
    return tab, lift


R_TAB, LIFT0 = envelope(DENSE)


def radius(a, y, tab=None):
    tab = R_TAB if tab is None else tab
    a = (np.asarray(a, float) + math.pi) % (2 * math.pi) - math.pi
    fy = np.clip((np.asarray(y, float) - TAB_Y[0]) / 0.005, 0, len(TAB_Y) - 1.001)
    fa = (a + math.pi) / (2 * math.pi) * 360
    y0, a0 = fy.astype(int), np.clip(fa.astype(int), 0, 359)
    ty, ta = fy - y0, fa - a0
    return (tab[y0, a0] * (1 - ty) * (1 - ta) + tab[y0 + 1, a0] * ty * (1 - ta)
            + tab[y0, a0 + 1] * (1 - ty) * ta + tab[y0 + 1, a0 + 1] * ty * ta)


def bottom(u):
    u = np.abs(np.asarray(u, float))
    front = Y_BOT_F + (Y_BOT_S - Y_BOT_F) * np.clip(u / U_V, 0, 1)
    back = Y_BOT_S + (Y_BOT_B - Y_BOT_S) * np.clip((u - U_V) / (math.pi - U_V), 0, 1) ** 2
    return np.where(u <= U_V, front, back)


def shell(a, y):
    """Radio de la cara de fuera de la chapa: envolvente + holgura + grosor + cresta + bajo abierto."""
    a, y = np.asarray(a, float), np.asarray(y, float)
    d = np.abs((a + math.pi) % (2 * math.pi) - math.pi) * 0.14
    ridge = RIDGE_H * np.clip(1 - d / RIDGE_W, 0, 1)
    flare = FLARE * np.clip((bottom(a) + FLARE_H - y) / FLARE_H, 0, 1) ** 2
    return radius(a, y) + GAP + THICK + ridge + flare


def surf(a, y, r=None):
    a, y = np.broadcast_arrays(np.asarray(a, float), np.asarray(y, float))
    r = shell(a, y) if r is None else r
    return np.stack([r * np.sin(a), y, ZC + r * np.cos(a)], -1)


def tab_angles():
    """Ángulos (0 = delante) de las pestañas de los hombros: donde la chapa pasa por las x de TAB_X."""
    u = np.linspace(0, math.pi, 4000)
    xf, xb = surf(u, Y_TAB_F)[:, 0], surf(u, Y_TAB_B)[:, 0]
    half = u < math.pi / 2
    f0, f1 = (u[half][np.argmax(xf[half] >= x)] for x in TAB_X)
    b0, b1 = (u[~half][::-1][np.argmax(xb[~half][::-1] >= x)] for x in TAB_X)
    return f0, f1, b1, b0


UF0, UF1, UB1, UB0 = tab_angles()
print("MEDIDA pestañas: delante %.2f–%.2f rad, detrás %.2f–%.2f rad" % (UF0, UF1, UB1, UB0))
ARM_KD = cKDTree(P0[ARM_MASK])


def clear_table():
    """Altura máxima del borde en cada ángulo de la sisa para quedar a ARM_CLEAR del brazo (suavizada, nunca más alta)."""
    u = np.linspace(UF0, UB0, 240)
    ys = np.arange(Y_ARM - 0.08, Y_TAB_B + 0.002, 0.002)
    uu, yy = np.meshgrid(u, ys)
    d, _ = ARM_KD.query(surf(uu, yy).reshape(-1, 3))
    bad = d.reshape(uu.shape) < ARM_CLEAR                  # de abajo arriba: el borde, bajo el primer roce
    y = np.where(bad.any(0), ys[np.argmax(bad, 0)] - 0.002, Y_TAB_B)
    for _ in range(20):
        y = np.minimum(y, np.convolve(np.pad(y, 3, mode="edge"), np.ones(7) / 7, "valid"))
    return u, y


CLEAR_U, CLEAR_Y = clear_table()
print("MEDIDA sisa: fondo a y=%.3f" % min(CLEAR_Y.min(), Y_ARM))


def top(u):
    """Borde de arriba: cuello en V delante, pestaña, sisa, pestaña y cuello atrás (simétrico)."""
    u = np.abs(np.asarray(u, float))
    neck_f = Y_NECK_F + (Y_TAB_F - Y_NECK_F) * np.clip(u / UF0, 0, 1)
    t = (u - (UF1 + UB1) / 2) / ((UB1 - UF1) / 2)
    tab_y = np.where(t < 0, Y_TAB_F, Y_TAB_B)
    arm = Y_ARM + (tab_y - Y_ARM) * np.clip(np.abs(t), 0, 1) ** ARM_P
    neck_b = Y_NECK_B + (Y_TAB_B - Y_NECK_B) * np.clip((math.pi - u) / (math.pi - UB0), 0, 1) ** 1.6
    y = np.select([u < UF0, u < UF1, u < UB1, u < UB0], [neck_f, Y_TAB_F, arm, Y_TAB_B], neck_b)
    return np.minimum(y, np.where((u >= UF0) & (u <= UB0), np.interp(u, CLEAR_U, CLEAR_Y), 9.0))


# ---------------- rejilla de la chapa ----------------
def columns():
    """Ángulos de las columnas: repartidos por la longitud de los bordes (más donde el borde sube o baja deprisa).
    Siempre hay columna en 0 (cresta y pico) y en π."""
    u = np.linspace(0, math.pi, 6001)
    du = 0.14 * np.diff(u)
    ds = np.hypot(du, np.diff(top(u))) + np.hypot(du, np.diff(bottom(u)))
    s = np.concatenate([[0], np.cumsum(ds)])
    half = np.interp(np.linspace(0, s[-1], NH + 1), s, u)
    return np.concatenate([half, -half[1:-1][::-1]])


def build_plate():
    a = columns()
    na = len(a)
    t = np.linspace(0, 1, NR)[:, None]
    Y = bottom(a)[None] + t * (top(a) - bottom(a))[None]
    A = np.tile(a, (NR, 1))
    pos = surf(A, Y).reshape(-1, 3)
    order = np.argsort(a)                                  # vecinos en ángulo (la lista no va ordenada)
    vid = np.arange(NR * na).reshape(NR, na)
    faces = []
    for j in range(NR - 1):
        for k in range(na):
            i, i1 = order[k], order[(k + 1) % na]
            v00, v01, v10, v11 = vid[j, i], vid[j, i1], vid[j + 1, i], vid[j + 1, i1]
            faces += [(v00, v10, v01), (v01, v10, v11)]
    F = np.array(faces)
    fn = np.cross(pos[F[:, 1]] - pos[F[:, 0]], pos[F[:, 2]] - pos[F[:, 0]])
    c = pos[F].mean(1)
    if (fn * (c - np.c_[np.zeros(len(F)), c[:, 1], np.full(len(F), ZC)])).sum() < 0:
        F = F[:, ::-1]
    return pos, F


# ---------------- hoja con grosor y bordes redondeados ----------------
def boundary(faces):
    e = np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]).tolist()
    keys = set(map(tuple, e))
    return np.array([x for x in e if (x[1], x[0]) not in keys])


def loops_of(bnd):
    nxt = {a: b for a, b in bnd}
    out, seen = [], set()
    for s in nxt:
        if s in seen:
            continue
        lp, v = [], s
        while v not in seen and v in nxt:
            seen.add(v); lp.append(v); v = nxt[v]
        out.append(np.array(lp))
    return out


def compact(v, f, *extra):
    used, inv = np.unique(f, return_inverse=True)
    return (v[used], inv.reshape(f.shape)) + tuple(x[used] for x in extra)


def thick_sheet(O, F, thick=THICK, K=3):
    """Hoja con grosor: cara de fuera (O), de dentro (O - normal · thick) y labio redondeado en los bordes. Devuelve
    vértices, caras, lazos del borde, centro del labio de cada vértice del borde, normales y O."""
    O, F = compact(O, F)
    nrm = vertex_normals(O, F)
    I = O - nrm * thick
    bnd = boundary(F)
    bv = np.unique(bnd)
    cen, cnt = np.zeros_like(O), np.zeros(len(O))
    fc = O[F].mean(1)
    for k in range(3):
        np.add.at(cen, F[:, k], fc)
        np.add.at(cnt, F[:, k], 1)
    T = O[bv] - cen[bv] / cnt[bv, None]
    T = T - nrm[bv] * (T * nrm[bv]).sum(1, keepdims=True)
    T /= np.linalg.norm(T, axis=1, keepdims=True)
    n = len(O)
    row = np.zeros((K + 1, n), int)
    row[0], row[K] = np.arange(n), n + np.arange(n)
    V, base = [O, I], 2 * n
    mid, half = (O[bv] + I[bv]) / 2, (O[bv] - I[bv]) / 2
    for k in range(1, K):
        th = math.pi * k / K
        V.append(mid + half * math.cos(th) + T * (thick / 2) * math.sin(th))
        row[k, bv] = base + np.arange(len(bv))
        base += len(bv)
    a, b = bnd[:, 0], bnd[:, 1]
    Fs = [F, F[:, ::-1] + n]
    for k in range(K):
        Fs += [np.stack([row[k, b], row[k, a], row[k + 1, a]], -1), np.stack([row[k, b], row[k + 1, a], row[k + 1, b]], -1)]
    edge = np.full((n, 3), np.nan)
    edge[bv] = mid + T * (thick / 2)
    return np.concatenate(V), np.concatenate(Fs), loops_of(bnd), edge, nrm, O


# ---------------- tubos y piezas pequeñas ----------------
def ring_faces(n, m, closed):
    j, i = np.meshgrid(np.arange(n if closed else n - 1), np.arange(m), indexing="ij")
    a, b = j * m + i, j * m + (i + 1) % m
    c, d = ((j + 1) % n) * m + i, ((j + 1) % n) * m + (i + 1) % m
    return np.concatenate([np.stack([a, c, b], -1).reshape(-1, 3), np.stack([b, c, d], -1).reshape(-1, 3)])


def orient_closed(v, f):
    vol = np.einsum("ij,ij->i", v[f[:, 0]], np.cross(v[f[:, 1]], v[f[:, 2]])).sum()
    return v, (f if vol > 0 else f[:, ::-1])


def sweep(pts, up, prof, closed):
    """Perfil prof (m, 2) en el plano (up, binormal) barrido por pts; up: (n, 3). Con tapas si es abierto."""
    t = np.gradient(pts, axis=0) if not closed else np.roll(pts, -1, 0) - np.roll(pts, 1, 0)
    t /= np.linalg.norm(t, axis=1, keepdims=True)
    u = up - t * (up * t).sum(1, keepdims=True)
    u /= np.linalg.norm(u, axis=1, keepdims=True)
    b = np.cross(t, u)
    prof = np.asarray(prof, float)
    rings = pts[:, None] + u[:, None] * prof[None, :, 0:1] + b[:, None] * prof[None, :, 1:2]
    n, m = rings.shape[:2]
    v, f = rings.reshape(-1, 3), ring_faces(n, m, closed)
    if not closed:
        i = np.arange(m)
        c0, c1 = len(v), len(v) + 1
        v = np.concatenate([v, [rings[0].mean(0), rings[-1].mean(0)]])
        f = np.concatenate([f, np.stack([np.full(m, c0), i, (i + 1) % m], -1),
                            np.stack([np.full(m, c1), (n - 1) * m + (i + 1) % m, (n - 1) * m + i], -1)])
    return orient_closed(v, f)


def circle(r, m=6):
    t = np.linspace(0, 2 * math.pi, m, endpoint=False)
    return np.stack([r * np.cos(t), r * np.sin(t)], 1)


def band(w, h):
    """Perfil de una correa: rectángulo (h de grosor en up, w de ancho en binormal)."""
    return np.array([(h, -w), (h, 0), (h, w), (0, w), (-h, w), (-h, 0), (-h, -w), (0, -w)], float) / 2


def lathe(prof, origin, axis, segs):
    axis = np.asarray(axis, float) / np.linalg.norm(axis)
    e1 = np.cross(axis, [0, 0, 1.0] if abs(axis[2]) < 0.9 else [1.0, 0, 0]); e1 /= np.linalg.norm(e1)
    e2 = np.cross(axis, e1)
    pr = np.asarray(prof, float)
    ph = np.linspace(0, 2 * math.pi, segs, endpoint=False)[:, None, None]
    v = origin + axis * pr[None, :, 1, None] + (e1 * np.cos(ph) + e2 * np.sin(ph)) * pr[None, :, 0, None]
    return orient_closed(v.reshape(-1, 3), ring_faces(segs, len(pr), True))


def rivet(c, n, r=0.0048, h=0.003):
    prof = [(max(r * math.sin(t), 1e-4), h * math.cos(t)) for t in np.linspace(0, math.pi / 2, 4)]
    return lathe(prof + [(r, -0.0015), (1e-4, -0.0015)], c, n, 10)


def buckle(c, t, u, half_t, half_b, r=0.0025):
    """Hebilla: marco rectangular redondeado en el plano (t, b) sobre c, más el pasador del centro."""
    t = t / np.linalg.norm(t)
    u = u - t * (u @ t); u /= np.linalg.norm(u)
    b = np.cross(t, u)
    k = np.linspace(0, 2 * math.pi, 28, endpoint=False)
    ct, cb = np.cos(k), np.sin(k)
    sq = lambda x: np.sign(x) * np.abs(x) ** 0.35                 # superelipse: casi rectángulo
    ring = c + np.outer(sq(ct) * half_t, t) + np.outer(sq(cb) * half_b, b)
    parts = [sweep(ring, np.tile(u, (len(ring), 1)), circle(r), closed=True)]
    bar = c + np.outer(np.linspace(-half_b, half_b, 6), b)
    parts.append(sweep(bar, np.tile(u, (6, 1)), circle(r * 0.8), closed=False))
    return parts


def piping_along(loop, sheet_edge, sheet_n, r):
    lp = np.asarray(loop)
    return sweep(sheet_edge[lp], sheet_n[lp], circle(r, 8), closed=True)


# ---------------- tirantes de los hombros ----------------
SKIN_IDX = np.where(BODY_MASK)[0]
SKIN_KD = cKDTree(P0[SKIN_IDX])


def strap_path(s):
    """Camino del tirante en el plano x = s·X_STRAP: envolvente convexa (z, y) de la chapa (pestañas, desde 7 cm bajo
    su borde) y del hombro (piel + STRAP_GAP), de delante a atrás, alisada. Devuelve puntos, normal y cuánto va fuera
    de la chapa (0 sobre la chapa, 1 sobre el hombro)."""
    X = s * X_STRAP
    uu, yy = np.meshgrid(np.linspace(0, math.pi, 1600), np.arange(1.25, 1.40, 0.002))
    uu, yy = uu.ravel(), yy.ravel()
    ok = (yy <= top(uu)) & (yy >= np.where(uu < math.pi / 2, Y_TAB_F - 0.07, Y_TAB_B - 0.065))
    p = surf(s * uu[ok], yy[ok])
    plate = p[np.abs(p[:, 0] - X) < 0.0015]
    sk = P0[SKIN_IDX]
    m = (np.abs(sk[:, 0] - X) < 0.006) & (sk[:, 1] > 1.33)
    skin = sk[m] + N0[SKIN_IDX][m] * STRAP_GAP
    q = np.concatenate([plate, skin])[:, [2, 1]]
    h = ConvexHull(q)
    ring = list(h.vertices)                                  # en sentido antihorario en (z, y)
    i0, i1 = ring.index(max(ring, key=lambda i: q[i, 0])), ring.index(min(ring, key=lambda i: q[i, 0]))
    chain = q[(ring[i0:] + ring[:i0])[:(i1 - i0) % len(ring) + 1]]
    seg = np.linalg.norm(np.diff(chain, axis=0), axis=1)
    cs = np.concatenate([[0], np.cumsum(seg)])
    st = np.linspace(0, cs[-1], max(int(cs[-1] / 0.004), 8))
    c = np.stack([np.interp(st, cs, chain[:, 0]), np.interp(st, cs, chain[:, 1])], 1)
    for _ in range(6):
        c[1:-1] = 0.25 * c[:-2] + 0.5 * c[1:-1] + 0.25 * c[2:]
    tg = np.gradient(c, axis=0)
    nz, ny = tg[:, 1], -tg[:, 0]                             # normal hacia fuera (cadena antihoraria)
    nn = np.stack([np.zeros(len(c)), ny, nz], 1)
    nn /= np.linalg.norm(nn, axis=1, keepdims=True)
    pts = np.stack([np.full(len(c), X), c[:, 1], c[:, 0]], 1) + nn * (STRAP_T / 2 + 0.0008)
    a = np.arctan2(pts[:, 0], pts[:, 2] - ZC)
    off = np.clip((pts[:, 1] - top(a) - 0.004) / 0.03, 0, 1)
    off = np.convolve(np.pad(off, 4, mode="edge"), np.ones(9) / 9, "valid")
    return pts, nn, off


# ---------------- pesos y formas ----------------
ALLOWED = [JN.index(n) for n in ("Hips", "Spine", "Chest", "UpperChest", "LeftShoulder", "RightShoulder")]


def skin_near(v):
    d, ii = SKIN_KD.query(v, k=8)
    w = 1 / (d + 0.004) ** 2
    return SKIN_IDX[ii], w / w.sum(1, keepdims=True)


def weights(v):
    """Pesos de los 8 vértices de piel más cercanos, solo con huesos del tronco y los hombros (4 influencias, suman 1)."""
    idx, w = skin_near(v)
    full = np.zeros((len(v), len(JN)))
    for k in range(8):
        for c in range(4):
            np.add.at(full, (np.arange(len(v)), J[idx[:, k], c]), W[idx[:, k], c] * w[:, k])
    keep = np.zeros(len(JN))
    keep[ALLOWED] = 1
    full *= keep
    full[full.sum(1) < 1e-6, JN.index("UpperChest")] = 1
    top4 = np.argsort(-full, 1)[:, :4]
    tw = np.take_along_axis(full, top4, 1)
    return top4, tw / tw.sum(1, keepdims=True)


# Cuerpo de partida de cada forma: la envolvente no es lineal (la suma de dos formas no es la suma de sus efectos), así
# que las del pecho se miden sobre el cuerpo femenino, donde el pecho cuenta; las demás, sobre el base.
FEMALE = {"gender_decr": 1}


def start_of(name):
    return FEMALE if "breast" in name and "gender" not in name else {}


def dense_delta(name):
    return np.einsum("bk,tkc->tbc", _bary, TARGETS[name][_tri]).reshape(-1, 3)


def state_cloud(base):
    """Nube del cuerpo con esas formas y sus combinaciones («a*b» pesa el producto)."""
    w = {k: np.prod([base.get(p, 0) for p in k.split("*")]) for k in TARGETS}
    return DENSE + sum(dense_delta(k) * x for k, x in w.items() if x)


def shapes(v, off):
    """Formas del cuerpo: la envolvente se recalcula con cada forma (la chapa crece, encoge y sube con el tronco, lisa),
    sobre su cuerpo de partida (start_of), y nunca sale menos que la piel de debajo.
    Lo que va fuera de la chapa (off, tirantes sobre el hombro) copia la piel cercana."""
    torso = np.unique(_tri)
    cand = [k for k, d in TARGETS.items() if np.abs(d[torso]).max() >= MIN_SHAPE]
    a = np.arctan2(v[:, 0], v[:, 2] - ZC)
    sa, ca = np.sin(a), np.cos(a)
    clouds, start = {}, {}
    for k, st in (("base", {}), ("female", FEMALE)):
        clouds[k] = state_cloud(st)
        tab, lift = envelope(clouds[k])
        y = v[:, 1] + np.interp(v[:, 1], TAB_Y, lift - LIFT0)          # altura del punto en ese cuerpo
        start[k] = (tab, lift, y, radius(a, y, tab))
    idx, w = skin_near(v)
    out = {}
    for name in cand:
        dt, dd = TARGETS[name], dense_delta(name)
        skin = (dt[idx] * w[..., None]).sum(1)
        k = "female" if start_of(name) else "base"
        tab0, lift0, y0, r0 = start[k]
        tab, lift = envelope(clouds[k] + dd)
        dy = np.interp(v[:, 1], TAB_Y, lift - lift0)
        dr = np.maximum(radius(a, y0 + dy, tab) - r0, skin[:, 0] * sa + skin[:, 2] * ca)
        d = np.stack([dr * sa, dy, dr * ca], 1)
        d = (1 - off[:, None]) * d + off[:, None] * skin
        if np.abs(d).max() >= MIN_SHAPE:
            out[name] = d.astype(np.float32)
    print("MEDIDA formas: %d candidatas, %d se quedan" % (len(cand), len(out)))
    return out


# ---------------- .glb ----------------
def write_glb(path, pos, nrm, tris, joints_body, weights_, targets, name, colors):
    rig, rig_buf = glb.read(ROOT / "godot/packs/base/tights.glb")
    rig_names = glb.joint_names(rig)
    to_rig = np.array([rig_names.index(n) if n in rig_names else -1 for n in JN])
    jr = to_rig[joints_body]
    weights_ = np.where(jr < 0, 0, weights_)
    weights_ /= weights_.sum(1, keepdims=True)
    jr = np.where(jr < 0, 0, jr)
    ibm = glb.accessor(rig, rig_buf, rig["skins"][0]["inverseBindMatrices"]).astype(np.float32)
    blob = bytearray(); views = []; accs = []

    def add(arr, ctype, kind, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": arr.nbytes,
                      **({"target": target} if target else {})})
        blob.extend(arr.tobytes())
        a = {"bufferView": len(views) - 1, "componentType": ctype, "count": len(arr), "type": kind}
        if minmax:
            a["min"] = arr.min(0).tolist(); a["max"] = arr.max(0).tolist()
        accs.append(a)
        return len(accs) - 1

    def add_sparse(delta):
        """Forma dispersa: solo los vértices que se mueven más de 0,2 mm (lo demás, a 0)."""
        moving = np.where(np.abs(delta).max(1) > 2e-4)[0].astype(np.uint32)
        if len(moving) > 0.6 * len(delta):
            return add(delta, 5126, "VEC3", None, True)
        iv = add(moving, 5125, "SCALAR")
        vv = add(delta[moving], 5126, "VEC3")
        a = {"componentType": 5126, "count": len(delta), "type": "VEC3",
             "min": delta.min(0).tolist(), "max": delta.max(0).tolist(),
             "sparse": {"count": int(len(moving)), "indices": {"bufferView": accs[iv]["bufferView"], "componentType": 5125},
                        "values": {"bufferView": accs[vv]["bufferView"]}}}
        accs.append(a)
        return len(accs) - 1

    uv = np.stack([np.arctan2(pos[:, 0], pos[:, 2] - ZC) / (2 * math.pi) + 0.5, pos[:, 1]], 1)
    attrs = {
        "POSITION": add(pos.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": add(nrm.astype(np.float32), 5126, "VEC3", 34962),
        "TEXCOORD_0": add(uv.astype(np.float32), 5126, "VEC2", 34962),
        "JOINTS_0": add(jr.astype(np.uint16), 5123, "VEC4", 34962),
        "WEIGHTS_0": add(weights_.astype(np.float32), 5126, "VEC4", 34962),
        "COLOR_0": add(colors.astype(np.float32), 5126, "VEC4", 34962),
    }
    names = list(targets)
    tg = [{"POSITION": add_sparse(targets[t])} for t in names]
    ind = add(tris.astype(np.uint32).ravel(), 5125, "SCALAR", 34963)
    ibm_acc = add(ibm.reshape(-1, 16), 5126, "MAT4")
    doc = {
        "asset": {"version": "2.0", "generator": "GameMolde generar_coraza.py"},
        "scene": 0, "scenes": rig["scenes"], "nodes": rig["nodes"],
        "skins": [{**rig["skins"][0], "inverseBindMatrices": ibm_acc}],
        "meshes": [{"name": name, "extras": {"targetNames": names},
                    "primitives": [{"attributes": attrs, "indices": ind, "targets": tg, "mode": 4}]}],
        "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(blob)}],
    }
    doc["nodes"][next(i for i, nd in enumerate(doc["nodes"]) if "mesh" in nd)]["name"] = name
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    while len(blob) % 4:
        blob.append(0)
    total = 12 + 8 + len(js) + 8 + len(blob)
    data = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js \
        + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    path.write_bytes(data)
    return hashlib.sha256(data).hexdigest()


ZONES = {"metal": (0, 0, 0, 1), "cuero": (1, 0, 0, 1), "hebillas": (1, 1, 0, 1)}   # COLOR_0 de cada zona


class Piece:
    def __init__(self):
        self.v, self.f, self.c, self.o = [], [], [], []

    def add(self, vf, zone="metal", off=0.0):
        v, f = vf
        self.f.append(np.asarray(f, int) + sum(len(x) for x in self.v))
        self.v.append(np.asarray(v, float))
        self.c.append(np.tile(ZONES[zone], (len(v), 1)))
        self.o.append(np.broadcast_to(np.asarray(off, float), (len(v),)).copy())

    def export(self, pid):
        v, f, c, o = (np.concatenate(x) for x in (self.v, self.f, self.c, self.o))
        joints, wts = weights(v)
        targets = shapes(v, o)
        sha = write_glb(OUT / (pid + ".glb"), v, vertex_normals(v, f), f, joints, wts, targets, pid, c)
        print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
            pid, len(v), len(f), len(targets), (OUT / (pid + ".glb")).stat().st_size / 1e6))
        return sha


def check(v):
    """Distancias mínimas de la chapa a la piel del tronco y a los brazos (en reposo)."""
    d_skin, _ = cKDTree(P0[BODY_MASK]).query(v)
    d_arm, _ = cKDTree(P0[ARM_MASK]).query(v)
    print("MEDIDA chapa: a %.1f mm de la piel (mín.), a %.1f mm de los brazos (mín.)" % (d_skin.min() * 1e3,
                                                                                         d_arm.min() * 1e3))


def radial(p):
    n = np.c_[p[..., 0], np.zeros(len(p)), p[..., 2] - ZC]
    return n / np.linalg.norm(n, axis=1, keepdims=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    armor = Piece()
    # chapa (peto y espaldar en una) con reborde en todos los bordes
    pos, F = build_plate()
    v, f, loops, edge, nrm, O = thick_sheet(pos, F)
    check(v)
    armor.add((v, f))
    for lp in loops:
        armor.add(piping_along(lp, edge, nrm, ROLL_R))
    # costuras de los costados
    for s in (1, -1):
        a0 = s * math.pi / 2
        ys = np.linspace(bottom(a0) + 0.012, top(a0) - 0.010, 24)
        p = surf(np.full_like(ys, a0), ys)
        armor.add(sweep(p, radial(p), circle(SEAM_R), closed=False))
    # tirantes de los hombros: correa, hebilla delante y remaches en los dos extremos
    for s in (1, -1):
        pts, nn, off = strap_path(s)
        m = len(band(STRAP_W, STRAP_T))
        armor.add(sweep(pts, nn, band(STRAP_W, STRAP_T), closed=False), "cuero",
                  np.concatenate([np.repeat(off, m), off[[0, -1]]]))
        k = int(np.argmax(pts[:, 1] > Y_TAB_F + 0.012))       # hebilla, justo por encima de la pestaña de delante
        tg = pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]
        for part in buckle(pts[k] + nn[k] * (STRAP_T / 2 + 0.002), tg, nn[k], 0.015, STRAP_W / 2 + 0.005):
            armor.add(part, "hebillas", off[k])
        for e in (3, len(pts) - 4):
            armor.add(rivet(pts[e] + nn[e] * STRAP_T / 2, nn[e]), "hebillas")
    # correas de los costados: correa, hebilla hacia delante y remaches
    for s in (1, -1):
        for y in SIDE_Y:
            r = float(shell(s * math.pi / 2, y))
            ha = SIDE_L / 2 / r
            aa = s * (math.pi / 2 + np.linspace(-ha, ha, 21))
            p = surf(aa, np.full_like(aa, y))
            n = radial(p)
            p = p + n * (SEAM_R + SIDE_T / 2 + 0.0006)
            armor.add(sweep(p, n, band(SIDE_W, SIDE_T), closed=False), "cuero")
            kb = 7                                            # hacia delante del costado
            for part in buckle(p[kb] + n[kb] * (SIDE_T / 2 + 0.002), p[kb + 1] - p[kb - 1], n[kb], 0.012, SIDE_W / 2 + 0.004):
                armor.add(part, "hebillas")
            for e in (1, 19):
                armor.add(rivet(p[e] + n[e] * SIDE_T / 2, n[e], 0.004), "hebillas")
    cards = [{"id": "coraza_acero", "nombre": "Coraza de acero", "archivo": "coraza_acero.glb",
              "sha256": armor.export("coraza_acero"), "tipo": "ropa", "ranura": "ropa_exterior", "especies": ["humana"],
              "colores": ["principal"], "color": [0.62, 0.64, 0.67], "sigue_al_cuerpo": True, "fisica": [],
              "miniatura": "", "anclaje": {"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]}}]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_corazas", "nombre": "Corazas (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
