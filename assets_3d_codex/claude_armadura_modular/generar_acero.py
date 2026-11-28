"""Armadura modular, pieza 3: el acero (plano: planos/armadura_modular.png).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_acero.py
Escribe packs/claude_armadura_modular/armadura_acero.glb (ranura «accesorio») y su ficha en el pack.json.
**Asimétrica como el plano** (decidido por el responsable): hombrera y pierna blindada en el lado izquierdo del
personaje (+x), como en las vistas de frente y espalda del plano; brazales en los dos brazos.
- Peto: la piel del pecho copiada y separada, alisada, con grosor; de la chaqueta (por debajo de su borde) a bajo el
  pecho; **abertura en cada copa** (pack_modular.HOLE: se ve la piel; decidido); cordón de cuero en el borde de fuera
  y reborde de acero en las aberturas (piezas de verdad, no color: sin escalera); remaches.
- Hombrera: cúpula sobre el hombro y 3 láminas (abiertas hacia el cuello; la de arriba, encima), medidas desde la
  articulación del hombro, y una cresta que sube junto al cuello.
- Brazales: 4 láminas que se solapan (las de los guanteletes medievales), de la muñeca a media antebrazo; remaches.
- Pierna: escarcela en la cadera (escudo con remaches), quijote en el muslo (con arista) y su lámina de abajo,
  rodillera con el hexágono de cuero, greba entera con arista y escarpe de 4 láminas.
Cada placa: una rejilla alrededor del eje de su miembro, con el radio medido sobre la piel (lo más lejano cerca de cada
punto, alisado) + su holgura. Pesos y formas, de la piel más cercana de su miembro.
Zonas en COLOR_0: (0,0,0) acero; r = 1 cuero.
"""
import math, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_bodysuits", "claude_guanteletes_medievales"):
    sys.path.insert(0, str(HERE.parent / d))
import cortes as ct
import generar_top_arnes as ta
import importlib.util
_spec = importlib.util.spec_from_file_location("chaqueta_modular", HERE / "generar_chaqueta.py")   # hay otra
cq = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(cq)                   # en claude_traje
import generar_guanteletes_medievales as gm
import pack_modular as pm
import zonas

dg, bt = gm.dg, gm.bt
sud, tr, bk, P0 = ct.sud, ct.tr, ct.bk, ct.P0
ZONES = {"acero": (0, 0, 0, 1), "cuero": (1, 0, 0, 1)}
PID = "armadura_acero"
S = "Left"                                       # lado de la hombrera y de la pierna (+x)
UP = np.array([0, 1.0, 0])
STEEL, STEP = 0.0028, 0.0035                     # grosor; cada lámina sobre la de al lado
MIN_MOVE = 0.002                                 # en cada forma, lo que se mueve menos se queda quieto (pesa menos)
# --- peto ---
PETO_GAP, PETO_BOTTOM, PETO_SIDE = 0.0085, 1.150, 72    # sobre la piel; bajo; hasta estos grados del eje del tronco
PIPE_R, PIPE_HOLE = 0.0028, 0.0022              # ribete de cuero (borde de fuera) y reborde de las aberturas
# --- hombrera (t a lo largo del brazo: 0 hombro, 1 codo) ---
PAUL_GAP = 0.009                                 # sobre la chaqueta
PAUL = [(0, 34), (30, 50), (46, 64), (60, 80)]   # cúpula y 3 láminas: grados desde el polo (arriba y fuera)
CREST_H, CREST_PH = 0.030, 55                    # cresta junto al cuello: alto y ± grados
# --- brazales ---
gm.LAMES = [(0.95, 0.82), (0.845, 0.71), (0.735, 0.59), (0.615, 0.46)]
gm.GAP_WRIST, gm.GAP_MOUTH = 0.010, 0.015
# --- pierna (muslo: 0 cadera, 1 rodilla; espinilla: 0 rodilla, 1 tobillo; pie: 0 tobillo, 1 dedos) ---
LEG_GAP = 0.010
HEX_R = 0.020


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


def perp(v, *ds):
    for d in ds:
        v = v - d * (v @ d)
    return unit(v)


def smooth(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def envelope(R, wrap=False, it=6, dil=1, keep_raw=True):
    """Radio sin dientes: el máximo de cada vecindad, alisado (no baja de la piel: queda por encima)."""
    raw = R
    pad = lambda X: np.pad(X, 1, mode="edge") if not wrap else np.pad(np.pad(X, ((1, 1), (0, 0)), mode="edge"),
                                                                      ((0, 0), (1, 1)), mode="wrap")
    if wrap:
        R = R[:, :-1]; raw = raw[:, :-1]
    for _ in range(dil):
        P = pad(R)
        R = np.max([P[i:i + R.shape[0], j:j + R.shape[1]] for i in range(3) for j in range(3)], 0)
    for _ in range(it):
        P = pad(R)
        R = 0.5 * R + 0.125 * (P[:-2, 1:-1] + P[2:, 1:-1] + P[1:-1, :-2] + P[1:-1, 2:])
    if keep_raw:
        R = np.maximum(R, raw)
    return np.c_[R, R[:, :1]] if wrap else R


class Limb:
    """Miembro: eje (o, d, largo L), marco (e1: a = 0; e2: a = +π/2) y el radio de la piel alrededor del eje."""
    def __init__(self, o, end, e1_hint, e2_hint, pts, ascale=0.05):
        self.o, self.L = o, np.linalg.norm(end - o)
        self.d = (end - o) / self.L
        self.e1 = perp(e1_hint, self.d)
        self.e2 = perp(e2_hint, self.d, self.e1)
        q = pts - o
        t, a = q @ self.d / self.L, np.arctan2(q @ self.e2, q @ self.e1)
        r = np.hypot(q @ self.e1, q @ self.e2)
        self.ascale = ascale
        self.kd = cKDTree(np.c_[np.tile(t, 3) * self.L, np.r_[a - 2 * math.pi, a, a + 2 * math.pi] * ascale])
        self.r = np.tile(r, 3)

    def radius(self, t, a):
        _, i = self.kd.query(np.c_[np.ravel(t) * self.L, np.ravel(a) * self.ascale], k=10)
        return self.r[i].max(1).reshape(np.shape(t))

    def dirs(self, a):
        return np.cos(a)[..., None] * self.e1 + np.sin(a)[..., None] * self.e2

    def point(self, t, a, r):
        return self.o + (t * self.L)[..., None] * self.d + r[..., None] * self.dirs(a)

    def plate(self, t0, t1, a0, a1, gap, nt=16, na=24, bulge=None, it=6):
        """Placa: filas de t0(a) a t1(a) (números o funciones de a), columnas de a0 a a1. Devuelve (v, f) y la rejilla
        (t, a, r de fuera) para los remaches."""
        a = np.linspace(a0, a1, na)
        f0 = t0(a) if callable(t0) else np.full(na, t0)
        f1 = t1(a) if callable(t1) else np.full(na, t1)
        q = np.linspace(0, 1, nt)[:, None]
        T, A = f0[None] + q * (f1 - f0)[None], np.broadcast_to(a, (nt, na))
        R = envelope(self.radius(T, A), wrap=abs(a1 - a0) > 6.2, it=it)
        R = R + gap + (bulge(T, A) if bulge else 0)
        return bt.grid_slab(self.point(T, A, R + STEEL), self.point(T, A, R)), (T, A, R + STEEL)

    def rivet(self, t, a, r, rad=0.0032):
        p = self.point(np.array(t), np.array(a), np.array(r))
        return bt.rivet(p, self.dirs(np.array(a)), rad)


# ---------------- peto ----------------
def peto():
    hem = cq.hem
    cuts = [lambda V: np.where(np.maximum(V[:, 4], V[:, 5]) > 0.5, 1.0, -1.0),
            lambda V: (ta.phi_of(V[:, :3]) - PETO_SIDE) * 0.002,
            lambda V: 0.004 - hem(V),                                       # bajo el borde de la chaqueta
            lambda V: PETO_BOTTOM - V[:, 1], pm.chest_hole]
    V, F, loops = ct.cut_skin(cuts, (1.10, 1.40))
    q, si, sw, n = bk.on_skin(V)
    O = bk.push_out(q + n * PETO_GAP, PETO_GAP)
    edge = np.zeros(len(O), bool); edge[np.concatenate(loops)] = True
    O = bk.push_out(sud.taubin(O, F, edge, 10), PETO_GAP)
    v, f, src = tr.thick_sheet(O, F, STEEL)
    holes = [lp for lp in loops if pm.chest_hole(np.c_[V[lp], np.zeros((len(lp), 3))]).max() > -0.004]
    nrm = tr.vertex_normals(O, F)
    parts = [(v, f, None)]
    for lp in loops:                                                   # ribete: cordón de cuero en el borde de
        hole = any(lp is h for h in holes)                             # fuera; reborde de acero en las aberturas
        parts.append((*piping(O, nrm, lp, PIPE_HOLE if hole else PIPE_R), None if hole else 1))
    rivets = []
    for x, y in ((0.125, 1.215), (0.105, 1.165), (0.035, 1.300)):
        for s in (1, -1):
            k = np.argmin(np.hypot(O[:, 0] - s * x, O[:, 1] - y) + 10 * (O[:, 2] < 0))
            rivets.append(bt.rivet(O[k], nrm[k], 0.0030))
    print("MEDIDA peto: %d vértices; de y = %.3f a %.3f" % (len(O), O[:, 1].min(), O[:, 1].max()))
    return parts, rivets


def piping(O, nrm, lp, r, m=8):
    """Cordón redondo que abraza el borde lp de la placa (O, de grosor STEEL), alisado a lo largo."""
    p, n = O[lp].copy(), nrm[lp].copy()
    for _ in range(4):
        p = 0.5 * p + 0.25 * (np.roll(p, 1, 0) + np.roll(p, -1, 0))
        n = unit(0.5 * n + 0.25 * (np.roll(n, 1, 0) + np.roll(n, -1, 0)))
    c = p - n * STEEL / 2
    c, n = np.vstack([c, c[:2]]), np.vstack([n, n[:2]])               # cerrado (solapa un poco)
    ang = np.linspace(0, 2 * math.pi, m, endpoint=False)
    return tr.sweep(c, n, [(r * math.cos(a), r * math.sin(a)) for a in ang])


# ---------------- hombrera ----------------
class Dome:
    """Cúpula del hombro: direcciones (θ desde el polo P, arriba y fuera; φ alrededor, 0 hacia el cuello) desde el
    centro c; el radio, la piel más cercana en un cono de 12° alrededor de cada dirección (la primera que corta: más allá
    sigue el brazo)."""
    def __init__(self, c, pole, neck, pts):
        self.c, self.P = c, unit(pole)
        self.ref = perp(neck, self.P)
        self.side = np.cross(self.P, self.ref)
        self.q = pts - c

    def dirs(self, th, ph):
        th, ph = np.radians(th), np.radians(ph)
        return (np.cos(th)[..., None] * self.P + np.sin(th)[..., None] *
                (np.cos(ph)[..., None] * self.ref + np.sin(ph)[..., None] * self.side))

    def radius(self, D):
        qn = unit(self.q)
        cos = D.reshape(-1, 3) @ qn.T
        proj = D.reshape(-1, 3) @ self.q.T
        near = np.where(cos > math.cos(math.radians(12)), proj, np.inf)
        first = near.min(1, keepdims=True)                             # la primera piel que corta…
        return np.where(near < first + 0.01, near, -np.inf).max(1).reshape(D.shape[:-1])   # …y su lado lejano

    def band(self, th0, th1, ph0, ph1, gap, nt=8, nph=40):
        th, ph = np.meshgrid(np.linspace(th0, th1, nt), np.linspace(ph0, ph1, nph), indexing="ij")
        D = self.dirs(th, ph)
        R = self.radius(D)
        R = np.where(np.isfinite(R) & (R > 0), R, np.nanmax(np.where(np.isfinite(R), R, np.nan), 1, keepdims=True))  # sin piel
        R = envelope(R, wrap=(ph1 - ph0) >= 359, it=40, dil=3, keep_raw=False) + gap
        inner = self.c + D * R[..., None]
        return bt.grid_slab(inner + D * STEEL, inner), (th, ph, R + STEEL)


def pauldron():
    a = sud.ARM[S]
    sx = sud.SIDES[S]
    out_v = np.array([sx * 1.0, 0, 0])
    m = (np.sign(P0[:, 0]) == sx) & ~sud.hand_like & (sud.main_bone != "Head") & (P0[:, 1] > 1.05)
    O = cq.jacket()[0]                                                 # sobre la chaqueta (y la piel que no cubre)
    O = O[np.sign(O[:, 0]) == sx]
    bare = cKDTree(O).query(P0[m])[0] > 0.012
    dome = Dome(a["upper"], UP * 0.75 + out_v * 0.65, -out_v, np.vstack([O, P0[m][bare]]))
    out = []
    for k, (th0, th1) in enumerate(PAUL):
        full = k == 0
        (v, f), g = dome.band(th0, th1, 0 if full else 50, 360 if full else 310,
                              PAUL_GAP + (len(PAUL) - 1 - k) * STEP, nt=7 if full else 6, nph=37 if full else 28)
        out.append((v, f))
        if not full:
            th, ph, R = g
            for j in (len(ph[0]) // 5, 4 * len(ph[0]) // 5):
                p = dome.c + dome.dirs(th[1, j], ph[1, j]) * R[1, j]
                out.append(bt.rivet(p, dome.dirs(th[1, j], ph[1, j]), 0.0028))
        else:
            out.append(crest(dome, g))
    return out, m


def crest(dome, g):
    """Cresta junto al cuello: sube desde el borde de la cúpula, más alta en el centro."""
    th, ph, R = g
    sel = np.where((ph[-1] <= CREST_PH) | (ph[-1] >= 360 - CREST_PH))[0]
    sel = np.r_[sel[ph[-1][sel] >= 360 - CREST_PH], sel[ph[-1][sel] <= CREST_PH]]
    D = dome.dirs(th[-1, sel] - 4, ph[-1, sel])
    base = dome.c + D * (R[-1, sel] - STEEL)[:, None]
    w = np.linspace(-1, 1, len(sel))
    h = CREST_H * np.sqrt(np.clip(1 - w ** 2, 0, 1))
    rise = unit(dome.P + 0.3 * UP)
    rows = np.linspace(0, 1, 6)[:, None, None]
    inner = base[None] + rows * h[None, :, None] * rise
    nf = unit(np.cross(np.gradient(base, axis=0), rise))
    nf *= -np.sign((nf @ dome.ref).mean())                              # hacia fuera (lejos del cuello)
    return bt.grid_slab(inner + nf[None] * STEEL, inner)


# ---------------- brazales ----------------
def bracers():
    out = []
    for s in sud.SIDES:
        forearm = (np.sign(P0[:, 0]) == sud.SIDES[s]) & (sud.main_bone != "Head") & (sud.arm_w > 0.5) & ~sud.hand_like
        ar = gm.ArmRadius(s, P0[forearm] + 0.0025 * 0)
        ls, rv = gm.lames(ar)
        out.append((ls + rv, forearm | ((np.sign(P0[:, 0]) == sud.SIDES[s]) & sud.hand_like)))
    return out


# ---------------- pierna ----------------
def leg_limbs():
    j = lambda n: sud.joint_pos(S + n)
    sx = sud.SIDES[S]
    out = np.array([sx * 1.0, 0, 0])
    fwd = np.array([0, 0, 1.0])
    side = np.sign(P0[:, 0]) == sx
    body = ~sud.hand_like & (sud.main_bone != "Head") & (sud.arm_w < 0.3)
    thigh_pts = P0[side & body & (P0[:, 1] > 0.38) & (P0[:, 1] < 1.02)]
    shin_pts = P0[side & body & (P0[:, 1] < 0.52)]
    foot_m = side & body & (P0[:, 1] < 0.12)
    thigh = Limb(j("UpperLeg"), j("LowerLeg"), fwd, out, thigh_pts)
    shin = Limb(j("LowerLeg"), j("Foot"), fwd, out, shin_pts)
    toe = P0[foot_m][np.argmax(P0[foot_m][:, 2])]
    foot = Limb(j("Foot"), toe + np.array([0, 0.004, -0.004]), UP, out, P0[foot_m])   # eje del tobillo a la punta
    masks = dict(thigh=side & body & (P0[:, 1] > 0.40) & (P0[:, 1] < 1.0), shin=side & body & (P0[:, 1] < 0.55),
                 foot=foot_m)
    return thigh, shin, foot, masks


def leg():
    thigh, shin, foot, masks = leg_limbs()
    parts = []                                                         # (v, f, zona por vértice o None, máscara)
    ridge = lambda T, A: 0.0035 * np.clip(1 - np.abs(A) / 0.25, 0, 1)
    # quijote: más alto por fuera; por dentro, lejos de la ingle
    (v, f), _ = thigh.plate(lambda a: 0.07 + 0.17 * smooth(-a / 0.9), 0.84, -0.9, 1.9, LEG_GAP, nt=16, na=24,
                            bulge=ridge)
    parts.append((v, f, None, masks["thigh"]))
    (v, f), _ = thigh.plate(0.80, 0.93, -1.0, 1.7, LEG_GAP + STEP, nt=5, na=24, bulge=ridge)
    parts.append((v, f, None, masks["thigh"]))
    # rodillera con el hexágono de cuero
    (v, f), g = thigh.plate(0.89, 1.13, -1.45, 1.45, LEG_GAP + 2 * STEP, nt=12, na=22,
                            bulge=lambda T, A: 0.007 * np.cos(A / 1.45 * math.pi / 2) *
                            np.sin(np.clip((T - 0.89) / 0.24, 0, 1) * math.pi))
    T, A, R = g
    u, w = (T - 1.01) * thigh.L, A * R
    hexd = np.maximum(np.abs(w) * 0.866 + np.abs(u) * 0.5, np.abs(u))
    f, new, inside = zonas.split(f, np.tile((HEX_R - hexd).ravel(), 2))   # borde del hexágono, nítido
    v = zonas.lerp(v, new)
    parts.append((v, f, inside.astype(int), masks["thigh"] | masks["shin"]))
    # greba entera (costura detrás, repetida) con arista
    (v, f), g = shin.plate(0.10, 0.87, -math.pi, math.pi, LEG_GAP - 0.001, nt=16, na=33, bulge=ridge)
    parts.append((v, f, None, masks["shin"]))
    T, A, R = g
    for tt in (3, 12):
        for aa in (-1.4, 1.4):
            j = np.argmin(np.abs(A[0] - aa))
            parts.append((*shin.rivet(T[tt, j], A[tt, j], R[tt, j]), None, masks["shin"]))
    # escarpe: 4 láminas (la del tobillo, encima)
    for k, (t0, t1) in enumerate([(0.02, 0.30), (0.26, 0.52), (0.48, 0.74), (0.70, 0.96)]):
        (v, f), _ = foot.plate(t0, t1, -1.25, 1.25, 0.008 + (3 - k) * STEP * 0.6, nt=5, na=16)
        v[:, 1] = np.maximum(v[:, 1], 0.004)
        parts.append((v, f, None, masks["foot"]))
    # escarcela en la cadera: escudo con remaches
    (v, f), g = thigh.plate(-0.10, lambda a: 0.30 - 0.13 * np.abs(a - 1.55) / 0.75, 0.80, 2.30, LEG_GAP + 0.006,
                            nt=12, na=16, bulge=lambda T, A: 0.003 * np.cos((A - 1.55) / 0.75 * math.pi / 2))
    parts.append((v, f, None, masks["thigh"]))
    T, A, R = g
    for tt, jj in ((2, 2), (2, 13), (7, 2), (7, 13), (10, 8)):
        parts.append((*thigh.rivet(T[tt, jj], A[tt, jj], R[tt, jj]), None, masks["thigh"]))
    return parts


# ---------------- montaje ----------------
def build():
    verts, faces, zones, src_idx, src_w = [], [], [], [], []

    def add(v, f, zone, mask):
        v = np.asarray(v, float).reshape(-1, 3)
        faces.append(np.asarray(f, int) + sum(len(x) for x in verts))
        verts.append(v)
        z = np.zeros(len(v), int) if zone is None else np.asarray(zone)
        zones.append(np.array([ZONES["acero"], ZONES["cuero"]], float)[z])
        i, w = sud.nearest_skin(v, 8, mask)
        src_idx.append(i); src_w.append(w)

    torso = (sud.arm_w < 0.3) & ~sud.hand_like & (sud.main_bone != "Head") & (P0[:, 1] > 1.08)
    parts, rivets = peto()
    for v, f, z in parts:
        add(v, f, z if z is None else np.full(len(v), z), torso)
    for rv in rivets:
        add(*rv, None, torso)
    pd, pm_mask = pauldron()
    for v, f in pd:
        add(v, f, None, pm_mask)
    for items, mask in bracers():
        for v, f in items:
            add(v, f, None, mask)
    for v, f, z, mask in leg():
        add(v, f, z, mask)
    v, f = np.concatenate(verts), np.concatenate(faces)
    check(v)
    bk.OUT = pm.OUT
    sha, _ = bk.write(v, f, np.concatenate(zones), np.concatenate(src_idx), np.concatenate(src_w),
                      np.zeros(len(v)), PID, np.full(len(v), MIN_MOVE))
    return sha


def check(v):
    """Lo más cerca que queda el acero de la piel (con el body y la chaqueta encima, deja ≥ 4 mm)."""
    d, i = cKDTree(P0[(sud.main_bone != "Head") & ~sud.hand_like]).query(v)
    print("MEDIDA acero a la piel: mín %.1f mm en %s; y de %.3f a %.3f" % (
        1000 * d.min(), np.round(v[d.argmin()], 3), v[:, 1].min(), v[:, 1].max()))


def main():
    old = pm.cards()
    pm.OUT.mkdir(parents=True, exist_ok=True)
    sha = build()
    card = tr.card(PID, "Armadura de acero (armadura modular)", sha, [0.66, 0.67, 0.70], "accesorio", "accesorio")
    pm.save(old, [card])


if __name__ == "__main__":
    main()
