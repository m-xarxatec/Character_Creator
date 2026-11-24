"""Vestido corto ajustado tipo qipao (cuello mao, sin mangas, rendija en el pecho con alamares, aberturas laterales,
borde de pelo y borlas) para la humana de GameMolde.

Uso:  python generar_vestido.py
Lee godot/datos/humana/cuerpo.glb (forma, pesos y formas) y el esqueleto de godot/packs/base/tights.glb; escribe en
packs/claude_vestidos/ una sola pieza, vestido_qipao (ranura «ropa_torso», cubre «ropa_piernas»), con todo: vestido,
cuello, borlas, ribetes, borde de pelo, perlas y alamares. Hoy sale de un color (el núcleo pinta uno por pieza), pero
cada zona va marcada en COLOR_0 para cuando admita varios: r = 0 vestido (skin_color del shader), r = 1 adornos
(garment_color); g = 1, además, alamares (para un tercer color).
Cómo se construye: el cuerpo se envuelve rodaja a rodaja (envolvente convexa de cada altura, sin brazos ni cabeza, más
HOLGURA): marca cintura y pecho sin meterse entre los senos y, bajo la cadera, es una falda de tubo que abraza los dos
muslos. Sisas, rendija y aberturas se recortan sobre esa rejilla (ángulo × altura). Pesos y formas: de la piel más
cercana (en la falda, el centro se reparte con Hips para que no se rasgue entre las piernas).
"""
import hashlib, json, math, struct, sys
from pathlib import Path
import numpy as np
from scipy.spatial import ConvexHull, cKDTree

sys.path.insert(0, str(Path(__file__).parents[1] / "claude_gorra"))
import glb

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / "packs" / "claude_vestidos"

# --- medidas (metros) ---
Y_HEM, Y_SLIT, SLIT_GAP = 0.730, 0.930, 0.024    # bajo a 4 cm de la entrepierna; aberturas hasta la cadera; abiertas ~5 cm abajo
GAP_TORSO, GAP_SKIRT, THICK = 0.004, 0.006, 0.002
ZC = 0.03                                       # eje vertical de la rejilla (centro del tronco, delante-detrás)
CAIDA, Y_CAIDA = 0.25, 1.30                     # bajo el pecho la tela cae casi recta (se estrecha ≤ 0,25 m por m)
NA, NR = 96, 72                                 # columnas (múltiplo de 4: hay columna en ±90°) y filas
ARM_TOP = 1.372                                 # la sisa no sube más: deja el tirante del hombro
COLLAR_H, COLLAR_OPEN = 0.034, 0.10             # cuello mao: alto y media abertura delante (radianes)
KEYHOLE = dict(top=(0.004, 1.362), bottom=(0.075, 1.252), half_width=0.009)   # rendija: (x, y) de sus extremos


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
BODY_MASK = (ARMISH < 0.3) & (HEADW < 0.3)                           # tronco, cuello y piernas
ARM_MASK = ARMISH > 0.5


def vertex_normals(v, f):
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    n = np.zeros_like(v)
    for k in range(3):
        np.add.at(n, f[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


N0 = vertex_normals(P0, F0)
_tri = F0[BODY_MASK[F0].all(1)]
_bary = np.array([(i, j, 4 - i - j) for i in range(5) for j in range(5 - i)], float) / 4
DENSE = np.einsum("bk,tkc->tbc", _bary, P0[_tri]).reshape(-1, 3)    # nube densa del cuerpo sin brazos ni cabeza


# ---------------- envolvente: radio por altura y ángulo ----------------
TAB_Y = np.arange(Y_HEM - 0.02, 1.43, 0.005)
TAB_A = np.linspace(-math.pi, math.pi, 361)


def hull_radius(dense, y):
    """Radio de la envolvente convexa de la rodaja (±4 mm) en cada ángulo de TAB_A, desde el eje (0, ZC)."""
    q = dense[np.abs(dense[:, 1] - y) < 0.004][:, [0, 2]] - [0, ZC]
    h = ConvexHull(q)
    nrm, off = h.equations[:, :2], -h.equations[:, 2]                # n·p = off, n hacia fuera
    d = np.stack([np.sin(TAB_A), np.cos(TAB_A)], 1)
    dn = d @ nrm.T
    t = np.where(dn > 1e-9, off[None] / np.maximum(dn, 1e-9), np.inf)
    return t.min(1)


def envelope(dense):
    """Tabla de radios (altura × ángulo): envolvente de cada rodaja, suavizada en altura y con caída (de arriba abajo,
    desde el pecho y los glúteos la tela no se mete: se estrecha como mucho CAIDA)."""
    tab = np.array([hull_radius(dense, y) for y in TAB_Y])
    k = np.exp(-0.5 * (np.arange(-3, 4) / 1.5) ** 2)
    k /= k.sum()
    tab = np.maximum(tab, np.apply_along_axis(lambda c: np.convolve(np.pad(c, 3, mode="edge"), k, "valid"), 0, tab))
    raw = tab.copy()
    for j in range(len(TAB_Y) - 2, -1, -1):
        if TAB_Y[j] < Y_CAIDA:
            tab[j] = np.maximum(tab[j], tab[j + 1] - CAIDA * 0.005)
    return tab, raw


R_TAB, _ = envelope(DENSE)
# Formas del pecho: con un pecho grande (femenino y volumen al máximo) la tela cuelga bajo él. HANG: cuánto cuelga en
# ese caso; HOLD: la altura de la que cuelga (la primera fila de encima que ya no cuelga).
BUST = [k for k in TARGETS if any(w in k for w in ("breast", "cupsize", "firmness"))]
_big = P0 + TARGETS["gender_decr"] + TARGETS["breast_volume_incr"]
_t, _r = envelope(np.einsum("bk,tkc->tbc", _bary, _big[_tri]).reshape(-1, 3))
HANG = _t - _r
HOLD = np.zeros_like(HANG)
HOLD[-1] = TAB_Y[-1]
for _j in range(len(TAB_Y) - 2, -1, -1):
    HOLD[_j] = np.where(HANG[_j] > 0.001, HOLD[_j + 1], TAB_Y[_j])


def radius(a, y, tab=None, gap=True):
    tab = R_TAB if tab is None else tab
    a = (np.asarray(a) + math.pi) % (2 * math.pi) - math.pi
    fy = np.clip((np.asarray(y) - TAB_Y[0]) / 0.005, 0, len(TAB_Y) - 1.001)
    fa = (a + math.pi) / (2 * math.pi) * 360
    y0, a0 = fy.astype(int), np.clip(fa.astype(int), 0, 359)
    ty, ta = fy - y0, fa - a0
    r = (tab[y0, a0] * (1 - ty) * (1 - ta) + tab[y0 + 1, a0] * ty * (1 - ta)
         + tab[y0, a0 + 1] * (1 - ty) * ta + tab[y0 + 1, a0 + 1] * ty * ta)
    if not gap:
        return r
    return r + GAP_TORSO + (GAP_SKIRT - GAP_TORSO) * np.clip((0.86 - np.asarray(y)) / 0.05, 0, 1)


def surf(a, y, r=None):
    a, y = np.asarray(a, float), np.asarray(y, float)
    r = radius(a, y) if r is None else r
    return np.stack([r * np.sin(a), y, ZC + r * np.cos(a)], -1)


def neck_top(a):
    """Borde de arriba (base del cuello): plano más bajo delante, como la sudadera."""
    r = radius(a, 1.405)
    return 1.400 - 0.30 * (ZC + r * np.cos(a)), r


# ---------------- contornos que se recortan ----------------
class Ellipse:
    """Contorno en (ángulo, altura) pasado a metros con el radio rm: f = |u/hu|^p + |v/hv|^p; f = 1 en el borde."""
    def __init__(self, a0, y0, hu, hv, p=2.0, rot=0.0, rm=0.14):
        self.a0, self.y0, self.hu, self.hv, self.p, self.rot, self.rm = a0, y0, hu, hv, p, rot, rm

    def local(self, a, y):
        u, v = (a - self.a0) * self.rm, y - self.y0
        c, s = math.cos(self.rot), math.sin(self.rot)
        return c * u + s * v, -s * u + c * v

    def f(self, a, y):
        u, v = self.local(a, y)
        return np.abs(u / self.hu) ** self.p + np.abs(v / self.hv) ** self.p

    def snap(self, a, y):
        u, v = self.local(a, y)
        k = self.f(a, y) ** (-1 / self.p)
        u, v = u * k, v * k
        c, s = math.cos(self.rot), math.sin(self.rot)
        return self.a0 + (c * u - s * v) / self.rm, self.y0 + s * u + c * v


def armholes(A, Y, pos):
    """Sisas: la zona de la rejilla a menos de 2,5 cm del brazo, como superelipse; nunca por encima de ARM_TOP."""
    tree = cKDTree(P0[ARM_MASK])
    d, _ = tree.query(pos.reshape(-1, 3))
    near = (d < 0.025).reshape(A.shape) & (Y < ARM_TOP) & (Y > 1.0)
    out = []
    for s in (1, -1):
        m = near & (np.sign(A) == s)
        a, y = A[m], Y[m]
        ymin, ymax = y.min() - 0.012, min(y.max() + 0.012, ARM_TOP)
        a0, ha = (a.min() + a.max()) / 2, (a.max() - a.min()) / 2 + 0.06
        out.append(Ellipse(a0, (ymin + ymax) / 2, ha * 0.14, (ymax - ymin) / 2, p=2.6))
        print("MEDIDA sisa %s: de y=%.3f a %.3f, %.0f° de ancho" % ("izq" if s > 0 else "der", ymin, ymax,
                                                                     math.degrees(2 * ha)))
    return out


def keyhole():
    (x0, y0), (x1, y1) = KEYHOLE["top"], KEYHOLE["bottom"]
    rm = float(radius(0.0, (y0 + y1) / 2))
    a0, a1 = x0 / rm, x1 / rm
    rot = math.atan2(y1 - y0, (a1 - a0) * rm)
    half = math.hypot((a1 - a0) * rm, y1 - y0) / 2
    return Ellipse((a0 + a1) / 2, (y0 + y1) / 2, half, KEYHOLE["half_width"], p=2.0, rot=rot, rm=rm)


# ---------------- rejilla del vestido ----------------
SLIT_COLS = (NA // 4, 3 * NA // 4)                  # columnas en -90° y +90°


def grid():
    a = -math.pi + 2 * math.pi * np.arange(NA) / NA
    yt, rn = neck_top(a)
    t = np.linspace(0, 1, NR - 1)
    Y = np.vstack([Y_HEM + t[:, None] * (yt - 0.008 - Y_HEM)[None], yt[None] + 0.004])
    A = np.tile(a, (NR, 1))
    Rr = radius(A, Y)
    Rr[-1] = rn + GAP_TORSO + 0.002                 # el borde de arriba, ceñido al cuello
    return A, Y, Rr


def slit_offset(A, Y, dup_side):
    """Abre las aberturas: cada lado se aparta de la columna de la abertura (más abajo, más)."""
    da = np.zeros_like(A)
    for s in SLIT_COLS:
        a_s = -math.pi + 2 * math.pi * s / NA
        d = (A - a_s + math.pi) % (2 * math.pi) - math.pi
        g = SLIT_GAP * np.clip((Y_SLIT - Y) / (Y_SLIT - Y_HEM), 0, 1) ** 1.2 / radius(a_s, Y)
        side = np.where(np.abs(d) < 1e-9, np.where(dup_side, 1.0, -1.0), np.sign(d))
        da += side * g * np.exp(-(d / 0.35) ** 2) * (np.abs(d) < math.pi / 2)
    return da


def build_dress():
    A, Y, Rr = grid()
    n0 = NR * NA
    vid = np.arange(n0).reshape(NR, NA)
    dup = -np.ones((NR, NA), int)
    nd = n0
    for s in SLIT_COLS:
        for j in range(NR):
            if Y[j, s] < Y_SLIT:
                dup[j, s] = nd
                nd += 1
    Aall, Yall = np.zeros(nd), np.zeros(nd)
    Aall[:n0], Yall[:n0] = A.ravel(), Y.ravel()
    jj, ii = np.where(dup >= 0)
    Aall[dup[jj, ii]], Yall[dup[jj, ii]] = A[jj, ii], Y[jj, ii]
    is_dup = np.zeros(nd, bool)
    is_dup[n0:] = True
    Aall = Aall + slit_offset(Aall, Yall, is_dup)
    faces = []
    for j in range(NR - 1):
        for i in range(NA):
            i1 = (i + 1) % NA
            v00 = dup[j, i] if dup[j, i] >= 0 else vid[j, i]
            v10 = dup[j + 1, i] if dup[j + 1, i] >= 0 else vid[j + 1, i]
            v01, v11 = vid[j, i1], vid[j + 1, i1]
            faces += [(v00, v10, v01), (v01, v10, v11)]
    F = np.array(faces)
    top_row = np.zeros(nd, bool)
    top_row[vid[-1]] = True
    R = np.where(top_row, np.concatenate([Rr.ravel(), np.zeros(nd - n0)]), np.nan)
    pos = surf(Aall, Yall, np.where(top_row, R, radius(Aall, Yall)))
    # recortes: sisas y rendija
    cuts = armholes(A, Y, surf(A, Y)) + [keyhole()]
    fs = np.stack([c.f(Aall, Yall) for c in cuts])
    full = (fs[:, F] >= 1).all((0, 2))
    kept = F[full]
    cutv = np.intersect1d(kept.ravel(), F[~full].ravel())
    which = fs[:, cutv].argmin(0)
    for k, c in enumerate(cuts):
        m = cutv[which == k]
        Aall[m], Yall[m] = c.snap(Aall[m], Yall[m])
    pos = surf(Aall, Yall, np.where(top_row, R, radius(Aall, Yall)))
    pos = keep_out(pos)
    fn = np.cross(pos[kept[:, 1]] - pos[kept[:, 0]], pos[kept[:, 2]] - pos[kept[:, 0]])
    axis = np.c_[np.zeros(len(kept)), pos[kept].mean(1)[:, 1], np.full(len(kept), ZC)]
    if (fn * (pos[kept].mean(1) - axis)).sum() < 0:
        kept = kept[:, ::-1]
    return pos, kept, Yall


SKIN_TREE = cKDTree(P0[BODY_MASK])
SKIN_N = N0[BODY_MASK]


def keep_out(v, gap=0.003):
    """Ninguna tela a menos de gap de la piel (por su normal)."""
    _, i = SKIN_TREE.query(v)
    p, n = P0[BODY_MASK][i], SKIN_N[i]
    h = ((v - p) * n).sum(1)
    return v + n * np.maximum(gap - h, 0)[:, None]


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


def thick_sheet(O, F, thick=THICK, K=3):
    """Hoja con grosor: cara de fuera (O, F hacia fuera), de dentro (O - normal · thick) y labio redondeado en los
    bordes. Devuelve vértices, caras, lazos del borde (índices de O) y para cada vértice del borde el centro del labio."""
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
    mid = (O[bv] + I[bv]) / 2
    half = (O[bv] - I[bv]) / 2
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


def compact(v, f, *extra):
    used, inv = np.unique(f, return_inverse=True)
    return (v[used], inv.reshape(f.shape)) + tuple(x[used] for x in extra)


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
    prof = np.asarray(prof)
    if prof.ndim == 2:
        prof = np.broadcast_to(prof, (len(pts),) + prof.shape)
    rings = pts[:, None] + u[:, None] * prof[..., 0:1] + b[:, None] * prof[..., 1:2]
    n, m = rings.shape[:2]
    v, f = rings.reshape(-1, 3), ring_faces(n, m, closed)
    if not closed:
        i = np.arange(m)
        c0, c1 = len(v), len(v) + 1
        v = np.concatenate([v, [rings[0].mean(0), rings[-1].mean(0)]])
        f = np.concatenate([f, np.stack([np.full(m, c0), i, (i + 1) % m], -1),
                            np.stack([np.full(m, c1), (n - 1) * m + (i + 1) % m, (n - 1) * m + i], -1)])
    return orient_closed(v, f)


def circle(r, m=8):
    t = np.linspace(0, 2 * math.pi, m, endpoint=False)
    return np.stack([r * np.cos(t), r * np.sin(t)], 1)


def lathe(prof, origin, axis, segs):
    axis = np.asarray(axis, float) / np.linalg.norm(axis)
    e1 = np.cross(axis, [0, 0, 1.0] if abs(axis[2]) < 0.9 else [1.0, 0, 0]); e1 /= np.linalg.norm(e1)
    e2 = np.cross(axis, e1)
    pr = np.asarray(prof, float)
    ph = np.linspace(0, 2 * math.pi, segs, endpoint=False)[:, None, None]
    v = origin + axis * pr[None, :, 1, None] + (e1 * np.cos(ph) + e2 * np.sin(ph)) * pr[None, :, 0, None]
    return orient_closed(v.reshape(-1, 3), ring_faces(segs, len(pr), True))


def torus(c, n, R, r, segs=16, ring=6):
    prof = [(R + r * math.cos(t), r * math.sin(t)) for t in np.linspace(0, 2 * math.pi, ring, endpoint=False)]
    return lathe(prof, c, n, segs)


def sphere(c, r, segs=10):
    prof = [(max(r * math.sin(t), 1e-4), -r * math.cos(t)) for t in np.linspace(0, math.pi, 7)]
    return lathe(prof, c, [0, 1.0, 0], segs)


def runs(loop, mask):
    """Tramos seguidos (cíclicos) del lazo donde mask es cierto."""
    m = mask[loop]
    if m.all():
        return [np.append(loop, loop[0])]
    k = np.argmin(m)
    lp, m = np.roll(loop, -k), np.roll(m, -k)
    out, cur = [], []
    for v, ok in zip(lp, m):
        if ok:
            cur.append(v)
        elif cur:
            out.append(np.array(cur)); cur = []
    if cur:
        out.append(np.array(cur))
    return [r for r in out if len(r) > 2]


# ---------------- cuello mao ----------------
def collar():
    a = np.linspace(COLLAR_OPEN, 2 * math.pi - COLLAR_OPEN, 64)
    yt, rn = neck_top(a)
    d = np.minimum(a - COLLAR_OPEN, 2 * math.pi - COLLAR_OPEN - a)
    hmax = COLLAR_H * (0.72 + 0.28 * np.clip(d / 0.35, 0, 1))         # algo más bajo junto a la abertura
    t = np.linspace(0, 1, 7)
    h = -0.006 + t[:, None] * (hmax + 0.006)[None]
    r = rn[None] + GAP_TORSO + 0.003 - 0.10 * np.clip(h, 0, None)        # se ciñe un poco hacia arriba
    pos = surf(np.tile(a, (7, 1)), yt[None] + h, r).reshape(-1, 3)
    j, i = np.meshgrid(np.arange(6), np.arange(63), indexing="ij")
    q, b = j * 64 + i, j * 64 + i + 1
    F = np.concatenate([np.stack([q, q + 64, b], -1).reshape(-1, 3), np.stack([b, q + 64, b + 64], -1).reshape(-1, 3)])
    fn = np.cross(pos[F[:, 1]] - pos[F[:, 0]], pos[F[:, 2]] - pos[F[:, 0]])
    out = pos[F].mean(1) - np.c_[np.zeros(len(F)), pos[F].mean(1)[:, 1], np.full(len(F), ZC)]
    if (fn * out).sum() < 0:
        F = F[:, ::-1]
    return pos, F, np.tile(t, (64, 1)).T.ravel()


# ---------------- adornos ----------------
def piping_along(paths, sheet_edge, sheet_n, r=0.0026):
    parts = []
    for p in paths:
        c = sheet_edge[p]
        if np.isnan(c).any() or len(p) < 3:
            continue
        closed = np.linalg.norm(c[0] - c[-1]) < 1e-6
        if closed:
            c, p = c[:-1], p[:-1]
        parts.append(sweep(c, sheet_n[p], circle(r), closed))
    return parts


def fur(path_pts, path_n):
    """Borde de pelo: tubo aplastado (2 cm de alto, 1,1 cm de fondo) con mechones (radio ondulado)."""
    n = len(path_pts)
    s = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(path_pts, axis=0), axis=1))])
    ph = np.linspace(0, 2 * math.pi, 14, endpoint=False)
    bump = 1 + 0.16 * np.sin(5 * ph[None] + 160 * s[:, None]) * np.sin(3 * ph[None] - 95 * s[:, None] + 1.3)
    prof = np.stack([0.011 * np.cos(ph)[None] * bump, 0.020 * np.sin(ph)[None] * bump], -1)
    centre = path_pts + np.array([0, 0.011, 0]) + path_n * 0.004
    # el perfil va en el plano (normal de la tela, arriba): la normal hace de «up» del barrido y arriba de binormal
    return sweep(centre, path_n, prof[..., [0, 1]], closed=False)


def tassel(p, n):
    prof = [(0.0004, 0.0), (0.0016, 0.0), (0.0016, -0.018), (0.0045, -0.021), (0.0070, -0.030), (0.0062, -0.033),
            (0.0080, -0.040), (0.0105, -0.078), (0.0004, -0.080)]
    return lathe(prof, p + n * 0.006, [0, 1.0, 0], 12)


def frogs(kh):
    """Cuatro alamares cruzando la rendija: cordón con dos espirales (lila) y una perla en medio (clara)."""
    cords, pearls = [], []
    (x0, y0), (x1, y1) = KEYHOLE["top"], KEYHOLE["bottom"]
    for t in (0.12, 0.38, 0.64, 0.90):
        xc, yc = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        rm = float(radius(0.0, yc))
        xs = xc + np.linspace(-0.026, 0.026, 11)
        a = xs / rm
        pts = surf(a, np.full_like(a, yc))
        nrm = pts - np.c_[np.zeros(len(a)), np.full(len(a), yc), np.full(len(a), ZC)]
        nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
        cords.append(sweep(pts + nrm * 0.003, nrm, circle(0.0019), closed=False))
        for e in (0, -1):
            cords.append(torus(pts[e] + nrm[e] * 0.0025, nrm[e], 0.0062, 0.0021))
        pearls.append(sphere(pts[5] + nrm[5] * 0.0055, 0.0045))
    return cords, pearls


# ---------------- pesos y formas ----------------
SKIN_IDX = np.where(BODY_MASK)[0]
SKIN_KD = cKDTree(P0[SKIN_IDX])
HIPS = JN.index("Hips")


def skin_moves(pts):
    d, ii = SKIN_KD.query(pts, k=8)
    w = 1 / (d + 0.004) ** 2
    return SKIN_IDX[ii], w / w.sum(1, keepdims=True)


def weights_and_shapes(v, hang=False):
    """Pesos (4 influencias, suman 1) y formas: media de los 8 vértices de piel más cercanos. En la falda, el centro
    (delante y detrás, entre las piernas) se reparte con Hips para que no se rasgue al abrir las piernas.
    hang: con las formas del pecho, bajo el pecho la tela se mueve además como el punto del que cuelga (tanto más
    cuanto más colgaría con un pecho grande; 1 cm o más: del todo): sigue al pecho al crecer y no se mete debajo.
    Cada forma, con su mezcla fija: es lineal y las formas se pueden sumar."""
    d, ii = SKIN_KD.query(v, k=8)
    idx = SKIN_IDX[ii]
    w = 1 / (d + 0.004) ** 2
    w /= w.sum(1, keepdims=True)
    full = np.zeros((len(v), len(JN)))
    for k in range(8):
        for c in range(4):
            np.add.at(full, (np.arange(len(v)), J[idx[:, k], c]), W[idx[:, k], c] * w[:, k])
    beta = 0.8 * np.clip(1 - np.abs(v[:, 0]) / 0.09, 0, 1) * np.clip((0.80 - v[:, 1]) / 0.05, 0, 1)
    full *= (1 - beta)[:, None]
    full[:, HIPS] += beta
    top = np.argsort(-full, 1)[:, :4]
    tw = np.take_along_axis(full, top, 1)
    tw /= tw.sum(1, keepdims=True)
    lam = np.zeros(len(v))
    if hang:
        a = np.arctan2(v[:, 0], v[:, 2] - ZC)
        lam = np.clip(radius(a, v[:, 1], HANG, gap=False) / 0.01, 0, 1)
        ys = radius(a, v[:, 1], HOLD, gap=False)
        hidx, hw = skin_moves(surf(a, ys))
    targets = {}
    for name, dt in TARGETS.items():
        moved = (dt[idx] * w[..., None]).sum(1)
        if hang and name in BUST:
            moved = (1 - lam[:, None]) * moved + lam[:, None] * (dt[hidx] * hw[..., None]).sum(1)
        if np.abs(moved).max() >= 0.001:
            targets[name] = moved.astype(np.float32)
    return top, tw, targets


# ---------------- .glb ----------------
def write_glb(path, pos, nrm, tris, joints_body, weights, targets, name, colors):
    rig, rig_buf = glb.read(ROOT / "godot/packs/base/tights.glb")
    rig_names = glb.joint_names(rig)
    to_rig = np.array([rig_names.index(n) if n in rig_names else -1 for n in JN])
    jr = to_rig[joints_body]
    weights = np.where(jr < 0, 0, weights)
    weights /= weights.sum(1, keepdims=True)
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
        "WEIGHTS_0": add(weights.astype(np.float32), 5126, "VEC4", 34962),
        "COLOR_0": add(colors.astype(np.float32), 5126, "VEC4", 34962),
    }
    names = list(targets)
    tg = [{"POSITION": add_sparse(targets[t])} for t in names]
    ind = add(tris.astype(np.uint32).ravel(), 5125, "SCALAR", 34963)
    ibm_acc = add(ibm.reshape(-1, 16), 5126, "MAT4")
    doc = {
        "asset": {"version": "2.0", "generator": "GameMolde generar_vestido.py"},
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


ZONES = {"vestido": (0, 0, 0, 1), "adornos": (1, 0, 0, 1), "alamares": (1, 1, 0, 1)}   # COLOR_0 de cada zona


class Piece:
    def __init__(self):
        self.v, self.f, self.c = [], [], []

    def add(self, vf, zone="vestido"):
        v, f = vf
        self.f.append(np.asarray(f, int) + sum(len(x) for x in self.v))
        self.v.append(np.asarray(v, float))
        self.c.append(np.tile(ZONES[zone], (len(v), 1)))

    def export(self, pid, hang=False):
        v, f, c = np.concatenate(self.v), np.concatenate(self.f), np.concatenate(self.c)
        joints, weights, targets = weights_and_shapes(v, hang)
        sha = write_glb(OUT / (pid + ".glb"), v, vertex_normals(v, f), f, joints, weights, targets, pid, c)
        print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
            pid, len(v), len(f), len(targets), (OUT / (pid + ".glb")).stat().st_size / 1e6))
        return sha


def card(pid, nombre, sha, color, tipo, ranura, cubre=None):
    c = {"id": pid, "nombre": nombre, "archivo": pid + ".glb", "sha256": sha, "tipo": tipo, "ranura": ranura,
         "especies": ["humana"], "colores": ["principal"], "color": color, "sigue_al_cuerpo": True, "fisica": [],
         "miniatura": "", "anclaje": {"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]}}
    if cubre:
        c["cubre"] = cubre
    return c


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    dress = Piece()
    # vestido
    pos, F, Yall = build_dress()
    v, f, loops, edge, nrm, O = thick_sheet(pos, F)
    dress.add((v, f))
    Yc = O[:, 1]
    for lp in loops:
        c = O[lp].mean(0)
        if c[1] > 1.37:                                   # borde del cuello: lo tapa el cuello mao
            continue
        if c[1] < 1.0:                                    # bajo y aberturas
            for r in runs(lp, Yc > Y_HEM + 0.022):        # ribete en las aberturas
                dress.add(piping_along([r], edge, nrm)[0], "adornos")
            for r in runs(lp, Yc < Y_HEM + 0.004):        # borde de pelo en el bajo (delante y detrás)
                dress.add(fur(O[r], nrm[r]), "adornos")
        else:                                             # sisas y rendija
            for part in piping_along([np.append(lp, lp[0])], edge, nrm):
                dress.add(part, "adornos")
    # cuello mao
    cpos, cF, ct = collar()
    cv, cf, cloops, cedge, cn, cO = thick_sheet(cpos, cF)
    dress.add((cv, cf))
    _, _, ctc = compact(cpos, cF, ct)
    for lp in cloops:
        for r in runs(lp, ctc > 0.05):
            for part in piping_along([r], cedge, cn):
                dress.add(part, "adornos")
    # borlas en el bajo de cada abertura
    for s in SLIT_COLS:
        a_s = -math.pi + 2 * math.pi * s / NA
        p = surf(a_s, Y_HEM)
        n = np.array([math.sin(a_s), 0, math.cos(a_s)])
        dress.add(tassel(p, n))
    # alamares y perlas
    cords, pearls = frogs(keyhole())
    for c in cords:
        dress.add(c, "alamares")
    for p in pearls:
        dress.add(p, "adornos")
    cards = [card("vestido_qipao", "Vestido qipao", dress.export("vestido_qipao", hang=True), [0.86, 0.12, 0.16],
                  "ropa", "ropa_torso", ["ropa_piernas"])]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_vestidos", "nombre": "Vestidos (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
