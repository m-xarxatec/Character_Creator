"""Jersey corto rosa con body crema (plano: planos/conjunto_rosa_jersey_bodysuit.png), sin los dibujos del plano.

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_jersey_rosa.py
Escribe packs/claude_jersey_rosa/: jersey_rosa, una sola pieza (ranura «ropa_torso», cubre «ropa_piernas»).
- Body crema: generador de maillots (cortes.py), la piel recortada y pegada, de una cara. Delante V alta con la
  entrepierna estrecha; detrás **tanga delgada**: hilo de 1,2 cm que se abre en triángulo bajo la cintura (pedido por el responsable). Ribete rosa en las piernas
  (zona por vértice), paneles de los costados a rayas y rayas en la entrepierna (en relieve). Arriba acaba bajo el
  jersey (no se ve).
- Jersey corto **holgado como el plano** (decidido): otra capa de piel, con grosor (el bajo queda suelto y se ve por
  dentro). Holgura por la normal y, delante, la tela cae recta desde el pecho (no se mete bajo él). Mangas globo (como
  las del top blanco, más grandes) recogidas en un puño de canalé con dos rayas crema en relieve; dos franjas crema en
  curva por fuera de cada manga; paneles crema en los hombros (zona por vértice). Bajo recto, suelto.
- Cuello alto de canalé (vertical), doblado arriba: la piel del cuello hinchada, dos capas.
- **Sin dibujos** (decidido: ni la ola de delante ni los arcos de detrás).
Zonas en COLOR_0: (0,0,0) rosa; r = 1 crema.
"""
import math
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

import cortes as ct
import generar_bodysuit_dorado as dor
import generar_top_arnes as ta

HERE = Path(__file__).parent
sud, tr, bk, P0, F0 = ct.sud, ct.tr, ct.bk, ct.P0, ct.F0
ct.ZONES.update({"crema": (1, 0, 0, 1)})
PINK, CREAM = np.array(ct.ZONES["tela"], float), np.array(ct.ZONES["crema"], float)
smooth = dor.smooth

# --- body ---
BODY_TOP = 1.27                                 # bajo el jersey
FRONT_HW = [(0.77, 0.007), (0.80, 0.010), (0.86, 0.032), (0.92, 0.068), (0.98, 0.105), (1.03, 0.140), (1.07, 0.25)]
BACK_HW = [(0.77, 0.006), (0.85, 0.006), (0.89, 0.030), (0.94, 0.065), (0.99, 0.105), (1.03, 0.140), (1.07, 0.25)]  # tanga: hilo
PIPE_W = 0.012                                  # ribete rosa de las piernas
SIDE_PHI = (62, 118)                            # panel a rayas del costado (grados alrededor del tronco)
SIDE_Y = (1.050, 1.150)                         # rayas: de y a y
SIDE_STEP, SIDE_HW = 0.013, 0.0032              # paso y media anchura de las rayas
CROTCH_Y = (0.800, 0.865)                       # rayas de la entrepierna (delante)
CROTCH_STEP = 0.013
# --- jersey ---
JN_Y = 1.415                                    # borde del cuello (bajo el cuello alto)
HEM = 1.115                                     # bajo
J_GAP, J_THICK = 0.0025, 0.0020
EASE = 0.011                                    # holgura del tronco (por la normal)
HEM_FLARE = 0.006                               # algo más suelto abajo
SMOOTH_IT = 12                                  # alisado de la tela (Taubin; cuello y puños quietos)
DRAPE = 0.10                                    # delante, la tela cae recta desde lo que haya hasta DRAPE más arriba
CUFF_T = 1.74                                   # puño: de aquí a la muñeca
SLEEVE_T = 1.97
GLOBE = [(0.0, 0.012), (0.3, 0.028), (0.7, 0.050), (1.1, 0.075), (1.45, 0.085), (1.60, 0.070), (1.68, 0.035),
         (1.73, 0.008), (2.0, 0.004)]
LOOSE_ARM = 0.5                                 # menos peso de brazo que esto: tela suelta (sigue a la piel cercana)
LINING, CUFF_LINING = 0.06, 0.015              # forro: solo hasta aquí del bajo y de los puños (lo que se ve)
GLOBE_SIDE = 0.5
CUFF_EASE, RIB_H = 0.0035, 0.0012
CUFF_STRIPES = (1.83, 1.89)                     # rayas crema del puño (t)
CUFF_STRIPE_W = 0.007
# paneles crema de los hombros: borde de dentro |x| por altura, delante y detrás; costura de la manga (t)
PANEL_F = [(1.26, 0.135), (1.32, 0.125), (1.38, 0.105), (1.43, 0.080)]
PANEL_B = [(1.10, 0.095), (1.25, 0.095), (1.35, 0.090), (1.43, 0.075)]
PANEL_F_BOT, SEAM_T = 1.25, 0.05
# franjas de la manga: (t, ángulo) de cada punto de paso (0 fuera y arriba; + delante); ancho
SWOOSH = [([(0.55, 1.60), (0.95, 1.20), (1.30, 0.60), (1.62, 0.10)], 0.014),
          ([(0.95, 1.75), (1.25, 1.35), (1.60, 0.75)], 0.009)]
LIFT, REL_T = 0.0008, 0.0012
SWOOSH_LIFT = 0.0025
J_MIN_MOVE, REL_MIN_MOVE = 0.001, 0.001         # en cada forma, lo que se mueve menos se queda quieto (peso)
# --- cuello alto ---
TN_Y0, TN_TOP_BACK, TN_TOP_FRONT = 1.400, 1.505, 1.435
TN_OFF, TN_RIB, TN_NRIB = 0.013, 0.0014, 24     # holgura, alto del canalé y cuántos
TN_COLS, TN_ROWS = 96, 22                       # columnas (4 por canalé) y anillos
TN_FOLD, TN_FOLD_AT = 0.0035, 0.45              # doblez: escalón y a qué fracción del alto
TN_Z = 0.025                                    # eje del cuello (z)


def skin_point(i, w):
    return (P0[i] * w[..., None]).sum(1)


def attrs_at(i, w):
    return (ct.skin_attrs()[i] * w[..., None]).sum(1)


# ---------------- body ----------------
def no_arms(V):
    return np.maximum(V[:, 4], V[:, 5]) - 0.5


LEG_KD = []


def remember_legs(O, F, si, sw):
    """(shape) guarda los bordes de las piernas para el ribete; la tela no cambia."""
    loops = sud.boundary_loops(F)
    LEG_KD[:] = [cKDTree(np.vstack([O[lp] for lp in loops if O[lp][:, 1].mean() < 1.1]))]
    return O


def body_zone(i, w):
    p = skin_point(i, w)
    pipe = LEG_KD[0].query(p)[0] < PIPE_W
    return np.where(pipe[:, None], PINK, CREAM)


def line_on(cloth, pts, hw, it=6, lift=LIFT):
    """Raya en relieve sobre la tela por los puntos pts (se proyectan y se alisan a lo largo)."""
    pts = pts[np.r_[True, np.linalg.norm(np.diff(pts, axis=0), axis=1) > 1e-4]]
    p = bk.spline(pts, 0.006)
    for _ in range(3):
        q, n = cloth.project(p)
        for _ in range(it):
            q[1:-1] = 0.5 * q[1:-1] + 0.25 * (q[:-2] + q[2:])
        p = q
    q, n = cloth.project(p)
    q, n = ta.smooth_line(q, n, it)
    return tr.sweep(q + n * lift, n, tr.rect(0, REL_T, hw))


def side_stripes(cloth):
    out = []
    for s in (1, -1):
        for y in np.arange(SIDE_Y[0], SIDE_Y[1], SIDE_STEP):
            pts = np.array([ta.ray_skin(d, y, s) for d in np.linspace(*SIDE_PHI, 12)])
            out.append(line_on(cloth, pts, SIDE_HW))
        for d in SIDE_PHI:                                             # bordes del panel
            pts = np.array([ta.ray_skin(d, y, s) for y in np.linspace(SIDE_Y[0] - 0.006, SIDE_Y[1], 10)])
            out.append(line_on(cloth, pts, 0.0018))
    return out


def crotch_stripes(cloth):
    out = []
    for y in np.arange(CROTCH_Y[0], CROTCH_Y[1], CROTCH_STEP):
        hw = np.interp(y, *zip(*FRONT_HW)) - PIPE_W
        if hw < 0.004:
            continue
        pts = np.array([cloth.front(x, y)[0] for x in np.linspace(-hw, hw, 5)])
        out.append(line_on(cloth, pts, SIDE_HW))
    return out


# ---------------- jersey ----------------
def arm_t(p, side):
    return ta.axis(side).frame(p)[0]


def panel_field(V):
    """> 0 en los paneles crema de los hombros (en metros, más o menos)."""
    x, y = V[:, 0], V[:, 1]
    back = smooth((ta.phi_of(V) - 70) / 40)
    x_in = np.interp(y, *zip(*PANEL_F)) * (1 - back) + np.interp(y, *zip(*PANEL_B)) * back
    t = np.where(x > 0, arm_t(V[:, :3], "Left"), arm_t(V[:, :3], "Right"))
    return np.minimum.reduce([np.abs(x) - x_in, (SEAM_T - t) * 0.24, np.where(back < 0.5, y - PANEL_F_BOT, 1.0)])


def jersey_cuts():
    hem = lambda V: np.where(np.maximum(V[:, 4], V[:, 5]) > 0.5, -1.0, HEM - V[:, 1])
    return [ct.neck_top(JN_Y), ct.sleeve("Left", SLEEVE_T), ct.sleeve("Right", SLEEVE_T), hem]


def drape(skin, torso):
    """Lo que se separa cada punto del tronco: delante la tela cae recta desde lo más saliente de encima (hasta DRAPE)."""
    phi = ta.phi_of(skin)
    c = np.c_[np.zeros(len(skin)), skin[:, 1], ta.axis_z(skin[:, 1])]
    r = np.hypot(skin[:, 0] - c[:, 0], skin[:, 2] - c[:, 2])
    pb = np.clip(phi // 6, 0, 30).astype(int) + 31 * (skin[:, 0] < 0)       # cada lado aparte
    yb = np.clip((skin[:, 1] - HEM + 0.02) // 0.01, 0, None).astype(int)
    R = np.full((62, yb.max() + 1), -1.0)
    np.maximum.at(R, (pb[torso], yb[torso]), r[torso])
    k = int(DRAPE / 0.01)
    up = np.array([R[pb[j], yb[j]:yb[j] + k + 1].max() for j in range(len(skin))])
    gain = np.maximum(up - r, 0) * (1 - smooth((phi - 40) / 40))       # solo delante
    gain = np.where(torso, gain, 0)
    radial = np.c_[skin[:, 0], np.zeros(len(skin)), skin[:, 2] - c[:, 2]]
    return ct.unit(radial + 1e-9) * gain[:, None]


JERSEY = {}


def jersey():
    """La capa del jersey: (O, F, si, sw, zona) ya con su forma."""
    if JERSEY:
        return JERSEY["d"]
    V, F, loops = ct.cut_skin(jersey_cuts(), (0.70, 1.50), refine=panel_field)
    q, si, sw, n = bk.on_skin(V)
    skin = q
    aL, aR = ta.arm_side(si, sw)
    arm = np.maximum(aL, aR)
    torso = arm < 0.3
    D = n * (EASE + HEM_FLARE * smooth((1.18 - skin[:, 1]) / 0.06))[:, None] + drape(skin, torso)
    free = np.ones(len(V), bool)
    for side, a in (("Left", aL), ("Right", aR)):
        m = a > 0.05
        t, c, _ = ta.axis(side).frame(skin[m])
        g = np.minimum(np.interp(t, *zip(*GLOBE)), GLOBE_SIDE * ta.TORSO_KD.query(V[m])[0])
        g = np.where(t > CUFF_T, CUFF_EASE, g)
        b = np.clip((a[m] - 0.05) / 0.6, 0, 1)[:, None]
        D[m] = D[m] * (1 - b) + ct.unit(V[m] - c) * g[:, None] * b
        free[np.where(m)[0][t > CUFF_T - 0.03]] = False                # el puño no se alisa
    neck = [lp for lp in loops if V[lp][:, 1].mean() > 1.38]
    hem = [lp for lp in loops if V[lp][:, 1].mean() < 1.2 and arm[lp].mean() < 0.3]
    for lp in neck:
        D[lp], free[lp] = 0, False
    adj, deg = sud.laplacian(F, len(V))
    for _ in range(40):
        D[free] = (0.5 * D + 0.5 * (adj @ D) / deg[:, None])[free]
    tight = np.concatenate([lp for lp in loops if not any(lp is h for h in hem)])
    edge = np.clip(cKDTree(V[tight]).query(V)[0] / bk.EDGE_BAND, 0, 1)
    edge = (edge * edge * (3 - 2 * edge))[:, None]
    O = sud.taubin(V + n * J_GAP + D * edge, F, ~free, SMOOTH_IT)     # tela lisa: sin los relieves de la piel
    for side, a in (("Left", aL), ("Right", aR)):                      # canalé del puño
        m = a > 0.5
        t, c, ang = ta.axis(side).frame(skin[m])
        O[m] += ct.unit(O[m] - c) * np.where(t > CUFF_T, RIB_H * (0.5 + 0.5 * np.cos(28 * ang)), 0)[:, None] * edge[m]
    O = bk.push_out(O, J_THICK + 0.0015)                               # la cara de dentro, fuera de la piel (axila)
    cuffs = [lp for lp in loops if arm[lp].mean() > 0.5]
    JERSEY["edges"] = [(np.concatenate(hem), LINING)] + [(lp, CUFF_LINING) for lp in cuffs]
    # pesos: las mangas, con su piel; el tronco suelto, con la piel más cercana (con los brazos: la axila), como la
    # tela que hace de puente en cortes.py: si el pecho crece hacia el lado, la tela lo sigue
    ni, nw = sud.nearest_skin(O, 8, ~sud.hand_like & (sud.main_bone != "Head"))
    arm = np.maximum(*ta.arm_side(*bk.on_skin(O)[1:3]))                # el brazo de la piel que tiene más cerca
    tb = np.clip((LOOSE_ARM - arm) / LOOSE_ARM, 0, 1)[:, None]
    si, sw = np.c_[si, ni], np.c_[sw * (1 - tb), nw * tb]
    top = np.argsort(-sw, 1)[:, :8]                                    # caben 8: las de más peso
    si, sw = np.take_along_axis(si, top, 1), np.take_along_axis(sw, top, 1)
    sw /= sw.sum(1, keepdims=True)
    JERSEY["loose"] = arm < LOOSE_ARM
    zone = np.where((panel_field(np.c_[skin, np.zeros((len(skin), 3))]) > 0)[:, None], CREAM, PINK)
    JERSEY["d"] = (O, F, si, sw, zone)
    return JERSEY["d"]


def lined(O, F, edges):
    """Hoja con grosor solo cerca de los bordes que se ven por dentro (bordes: [(vértices del borde, ancho)], el bajo y
    los puños): fuera entera; dentro y labio solo ahí (el resto no se ve)."""
    v, f, src = tr.thick_sheet(O, F, J_THICK)
    near = np.any([cKDTree(O[e]).query(O)[0] < wd for e, wd in edges], 0)
    on_hem = np.zeros(len(O), bool); on_hem[np.concatenate([e for e, _ in edges])] = True
    n = len(F)
    keep = np.r_[np.ones(n, bool), near[F].all(1), on_hem[src[f[2 * n:]]].all(1)]
    f = f[keep]
    used = np.unique(f)
    remap = -np.ones(len(v), int); remap[used] = np.arange(len(used))
    return v[used], remap[f], src[used]


def jersey_piece():
    O, F, si, sw, zone = jersey()
    v, f, src = lined(O, F, JERSEY["edges"])
    i, w = si[src], sw[src]
    h = ((v - skin_point(i, w)) * bk.normal_at(bk.SKIN_N, i, w)).sum(1)
    h[JERSEY["loose"][src]] = 0                                        # lo suelto, sin girar con la normal
    measure_jersey(v, i, w, h)
    return (v, f), zone[src], (ct.pad8(i), ct.pad8(w)), h, J_MIN_MOVE


def closest_signed(p, T, TN):
    """Distancia con signo de cada p al más cercano de sus triángulos T (n, k, 3, 3), por la normal de los vértices
    interpolada (TN, igual que T): la de la cara engaña donde una forma da la vuelta a triángulos («alisado»)."""
    a, ab, ac = T[..., 0, :], T[..., 1, :] - T[..., 0, :], T[..., 2, :] - T[..., 0, :]
    v2 = p[:, None] - a
    d00, d01, d11 = (ab * ab).sum(-1), (ab * ac).sum(-1), (ac * ac).sum(-1)
    d20, d21 = (v2 * ab).sum(-1), (v2 * ac).sum(-1)
    den = d00 * d11 - d01 * d01
    u, v = np.clip((d11 * d20 - d01 * d21) / den, 0, 1), np.clip((d00 * d21 - d01 * d20) / den, 0, 1)
    s = np.maximum(u + v, 1)
    u, v = u / s, v / s
    q = a + ab * u[..., None] + ac * v[..., None]
    nn = TN[..., 0, :] * (1 - u - v)[..., None] + TN[..., 1, :] * u[..., None] + TN[..., 2, :] * v[..., None]
    j = np.linalg.norm(p[:, None] - q, axis=-1).argmin(1)
    r = np.arange(len(p))
    return ((p - q[r, j]) * nn[r, j]).sum(1)


SKIN_T = F0[((sud.main_bone != "Head") & ~sud.hand_like)[F0].all(1)]


def measure_jersey(v, i, w, h):
    """Lo más metida que queda la tela (las dos caras) en la piel, en reposo y con cada forma (punto más cercano de la
    piel y la normal de su cara)."""
    n0 = bk.normal_at(bk.SKIN_N, i, w)
    low = []
    for name, d in [("reposo", np.zeros_like(P0))] + list(sud.B["targets"].items()):
        P = P0 + d
        N = sud.vertex_normals(P, F0)
        vs = v + (d[i] * w[..., None]).sum(1) + (bk.normal_at(N, i, w) - n0) * h[:, None]
        T = P[SKIN_T]
        k = cKDTree(T.mean(1)).query(vs, k=12)[1]
        s = closest_signed(vs, T[k], N[SKIN_T][k])
        low.append((s.min(), (s < 0).sum(), name))
    worst = min(low)
    print("MEDIDA jersey a la piel: mín %.1f mm (reposo), %.1f mm (con cada forma; peor %s, %d vértices dentro); "
          "%d formas con algo dentro" % (low[0][0] * 1000, worst[0] * 1000, worst[2], worst[1],
                                        sum(x[0] < 0 for x in low)))


# ---------------- relieve del jersey ----------------
def sleeve_bands(sl, cloth):
    out = []
    for t in CUFF_STRIPES:
        p, n = sl.hit(t, np.linspace(0, 2 * math.pi, 49))
        p, n = ta.smooth_line(p, n, 3)
        out.append(tr.sweep(p + n * (LIFT + 0.0004), n, tr.rect(0, REL_T, CUFF_STRIPE_W / 2)))
    for pts, wdt in SWOOSH:
        tt, aa = np.array(pts).T
        t = np.linspace(tt[0], tt[-1], 45)
        a = np.interp(t, tt, aa)
        out.append(line_on(cloth, sl.hit(t, a)[0], wdt / 2, 10, SWOOSH_LIFT))   # la media de vecinos queda bajo
                                                                              # la manga (curva): más alta
    return out


# ---------------- cuello alto ----------------
NECK_T = P0[F0[((sud.arm_w < 0.3) & ~sud.hand_like & (P0[:, 1] > TN_Y0 - 0.03) & (P0[:, 1] < TN_TOP_BACK + 0.03))[F0]
                .all(1)]]


def ray_neck(o, d):
    """Primer corte con la piel del cuello (y la mandíbula: el cuello alto no la atraviesa) del rayo o + t·d."""
    T = NECK_T
    e1, e2 = T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]
    pv = np.cross(d, e2)
    det = (e1 * pv).sum(1)
    inv = 1 / np.where(np.abs(det) > 1e-12, det, np.inf)
    r = o - T[:, 0]
    u = (r * pv).sum(1) * inv
    q = np.cross(r, e1)
    v = (q @ d) * inv
    t = (q * e2).sum(1) * inv
    ok = (u >= -1e-7) & (v >= -1e-7) & (u + v <= 1 + 1e-7) & (t > 0)
    return t[ok].min() if ok.any() else np.nan


def turtleneck():
    """Tubo de anillos y columnas (bordes limpios): el radio del cuello medido con rayos desde su eje, más la holgura,
    el canalé (columnas) y el doblez; con grosor y labio arriba y abajo."""
    a = np.linspace(-math.pi, math.pi, TN_COLS, endpoint=False)
    u = np.linspace(0, 1, TN_ROWS)
    d = np.c_[np.sin(a), np.zeros_like(a), np.cos(a)]
    top = TN_TOP_BACK - (TN_TOP_BACK - TN_TOP_FRONT) * smooth(np.cos(a) * 0.5 + 0.5)
    y = TN_Y0 + np.outer(u, top - TN_Y0)                                  # (filas, columnas)
    r = np.array([[ray_neck(np.array([0, y[j, i], TN_Z]), d[i]) for i in range(TN_COLS)] for j in range(TN_ROWS)])
    bad = np.isnan(r)                                                     # algún rayo entre dos triángulos
    r[bad] = np.nanmean(np.where(bad, np.nan, r), 1, keepdims=True).repeat(TN_COLS, 1)[bad]
    print("MEDIDA cuello alto: %d rayos sin corte" % bad.sum())
    raw = r.copy()
    for _ in range(8):                                                    # sin dientes (alrededor y a lo alto), sin
        r = 0.5 * r + 0.25 * (np.roll(r, 1, 1) + np.roll(r, -1, 1))       # meterse nunca en la piel (mandíbula)
        r[1:-1] = 0.5 * r[1:-1] + 0.25 * (r[:-2] + r[2:])
        r = np.maximum(r, raw)
    r = np.maximum.accumulate(r[::-1], 0)[::-1] * 0.5 + r * 0.5           # el tubo no se cierra hacia abajo
    ramp = smooth(u / 0.12)[:, None]
    off = 0.004 + (TN_OFF + TN_FOLD * smooth((u - TN_FOLD_AT) / 0.04)[:, None]
                   + TN_RIB * (0.5 + 0.5 * np.cos(TN_NRIB * a))[None]) * ramp
    v = np.stack([np.zeros_like(y), y, np.full_like(y, TN_Z)], -1) + d[None] * (r + off)[..., None]
    v = v.reshape(-1, 3)
    f = tr.ring_faces(TN_ROWS, TN_COLS, False)
    nf = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    if (nf * (v[f].mean(1) - [0, 0, TN_Z]) * [1, 0, 1]).sum() < 0:      # caras hacia fuera
        f = f[:, ::-1]
    v, f, _ = tr.thick_sheet(v, f, 0.003)
    head = P0[sud.main_bone == "Head"]
    print("MEDIDA cuello alto: %d vértices; a la cabeza (piel) mín %.1f mm" % (
        len(v), 1000 * cKDTree(head).query(v)[0].min()))
    return v, f


# ---------------- montaje ----------------
def rel(m, zone, mask):
    """Pieza en relieve: sigue a la piel cercana; en cada forma, quieta si se mueve menos de REL_MIN_MOVE (pesa menos)."""
    return m, zone, mask, np.zeros(len(m[0])), REL_MIN_MOVE


def extras(O, F):
    cloth = dor.Cloth(O, F)
    torso = (sud.main_bone != "Head") & (sud.arm_w < 0.3) & ~sud.hand_like
    neck = (P0[:, 1] > 1.36) & (sud.arm_w < 0.3)
    tn = turtleneck()
    parts = [jersey_piece(), (tn, "tela", neck, np.zeros(len(tn[0])), J_MIN_MOVE)]
    parts += [rel(m, "tela", torso) for m in side_stripes(cloth) + crotch_stripes(cloth)]
    Oj, Fj = jersey()[:2]
    jcloth = dor.Cloth(Oj, Fj)
    for side in ("Left", "Right"):
        sl = ta.Sleeve(Oj, Fj, side)
        arm = (np.sign(P0[:, 0]) == sud.SIDES[side]) & ~sud.hand_like & (sud.main_bone != "Head") & (sud.arm_w > 0.3)
        parts += [rel(m, "crema", arm) for m in sleeve_bands(sl, jcloth)]
    return parts


def main():
    cuts = [ct.neck_top(BODY_TOP), no_arms, ct.bottom(FRONT_HW, BACK_HW)]
    ct.build(cuts, HERE / "packs" / "claude_jersey_rosa", "claude_jersey_rosa", "Jersey rosa (pruebas)", "jersey_rosa",
             "Jersey corto rosa con body crema", [0.80, 0.47, 0.52], extras, body_zone, 0.0005, thick=False,
             shape=remember_legs)


if __name__ == "__main__":
    main()
