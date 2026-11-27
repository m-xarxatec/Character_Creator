"""Top blanco con bodysuit arnés (plano: planos/top_blanco_bodysuit_arnes.png).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_top_arnes.py
Escribe packs/claude_top_arnes/: top_arnes, una sola pieza (ranura «ropa_torso», cubre «ropa_piernas»).
Generador de maillots (cortes.py): la piel recortada, pegada al cuerpo, de una cara; todo en la misma tela.
- Top corto blanco: cuello redondo de canalé negro; acaba bajo el pecho en arco, delante y detrás.
- Mangas globo como el plano (decidido por el responsable): la misma tela, hinchada desde el eje del brazo (poco en el
  hombro, mucho en el antebrazo, sin acercarse al costado), recogida en un puño de canalé negro en la muñeca.
- Tiras blancas: de cada lado del top bajan hasta una anilla delante y otra detrás (en la cadera, sobre el centro).
- Abajo, negro: delante una V con la entrepierna estrecha y dos tiras de la anilla a sus esquinas (bombeadas hacia la
  cadera); una tira por la cadera a cada lado; detrás **hilo delgadito** por el surco hasta la anilla (decidido) y dos
  tiras de la anilla a la cadera. Todas las tiras, pegadas a la piel (decidido: simple).
- En relieve: dos bandas negras en cada manga con una anilla en D, de la que cuelgan dos cintas (decidido: se quedan;
  hoy rígidas con el antebrazo; físicas o huesos, ver U en plan_assets.md), franja negra en el antebrazo, dos zarpazos
  a cada lado del pecho, y las anillas.
Zonas en COLOR_0: (0,0,0) blanco; r = 1 negro; g = 1 metal.
"""
import math
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

import cortes as ct
import generar_bodysuit_dorado as dor

HERE = Path(__file__).parent
sud, tr, bk, P0, F0 = ct.sud, ct.tr, ct.bk, ct.P0, ct.F0
ct.ZONES.update({"negro": (1, 0, 0, 1), "metal": (0, 1, 0, 1)})
WHITE, BLACK = np.array(ct.ZONES["tela"], float), np.array(ct.ZONES["negro"], float)

NECK = (1.43, 0.3, 0.075, 0.070, 0.020)         # cuello redondo: plano y − 0,3·z, elipse (rx, rz) en z = 0,02
COLLAR_H, RIB_H = 0.022, 0.0012                 # cuello de canalé: alto, y lo que sobresale (con su relieve)
CUFF_T = 1.86                                   # puño: desde aquí hasta la muñeca (0 hombro, 1 codo, 2 muñeca)
SLEEVE_T = 1.97
AXIS_Z = [(0.80, 0.020), (0.97, 0.045), (1.22, 0.045)]   # eje del tronco (y, z) para los grados
TOP = [(0, 1.18), (35, 1.17), (65, 1.15), (90, 1.135), (115, 1.135), (145, 1.15), (180, 1.165)]  # bajo del top
# globo: hinchado (m) a lo largo del brazo (t) y nunca más que GLOBE_SIDE × la distancia al costado
GLOBE = [(0.0, 0.0), (0.25, 0.014), (0.7, 0.032), (1.2, 0.052), (1.6, 0.060), (1.76, 0.048), (1.84, 0.014),
         (1.87, 0.004), (2.0, 0.004)]
GLOBE_SIDE = 0.5
# tiras (grados alrededor del eje del tronco, y); media anchura
RING_F, RING_B = (0, 0.972), (180, 0.985)
WHITE_F = [(80, 1.150), (74, 1.10), (60, 1.045), (40, 1.005), (20, 0.983), (4, 0.976)]
WHITE_B = [(100, 1.140), (108, 1.09), (124, 1.040), (146, 1.005), (164, 0.990), (177, 0.987)]
WHITE_HW = 0.012
BLACK_F = [(4, 0.966), (20, 0.950), (38, 0.925), (47, 0.900), (44, 0.880), (35, 0.866)]    # anilla → esquina de la V
BLACK_B = [(176, 0.979), (160, 0.962), (144, 0.938), (136, 0.915), (132, 0.900)]          # anilla → cadera
HIP = [(44, 0.885), (70, 0.895), (95, 0.900), (120, 0.902), (134, 0.900)]               # por la cadera
BLACK_HW = 0.0075
FRONT_HW = [(0.77, 0.010), (0.80, 0.016), (0.83, 0.028), (0.86, 0.052), (0.876, 0.068)]  # V de delante
V_TOP = 0.874
HILO_HW = 0.0045
# relieve
LIFT, REL_T = 0.0008, 0.0012
BANDS = (0.44, 0.60)                            # bandas de la manga (t) y su ancho
BAND_W = 0.018
STRIP = (1.0, 1.72, 0.022)                      # franja del antebrazo: de t a t, ancho
STRIP_ANG = 0.6                                 # su ángulo alrededor del brazo (0 fuera y arriba; + delante)
DRING = (0.66, 0.008, 0.0016)                   # anilla en D: t (bajo la segunda banda), radio, grosor
HANG = [(0.20, 0.0), (0.13, 0.026)]             # cintas que cuelgan: cuánto pasan de la muñeca, separación
HANG_W = 0.016
RING_R, RING_TUBE = 0.011, 0.0022
CLAWS = [((0.112, 1.195), 0.075, 62), ((0.133, 1.188), 0.050, 66)]   # zarpazos: punto medio (|x|, y), largo, grados


# ---------------- curvas sobre la piel ----------------
def axis_z(y):
    return np.interp(y, *zip(*AXIS_Z))


def phi_of(V):
    return np.degrees(np.arctan2(np.abs(V[:, 0]), V[:, 2] - axis_z(V[:, 1])))


TORSO_T = P0[F0[((sud.arm_w < 0.3) & ~sud.hand_like & (sud.main_bone != "Head"))[F0].all(1)]]


def ray_skin(deg, y, s):
    """Punto de la piel del tronco a deg grados (0 delante, 180 detrás) del lado s, a la altura y: rayo horizontal
    desde el eje del tronco hacia fuera (el primer corte)."""
    a = math.radians(deg)
    o, d = np.array([0.0, y, float(axis_z(y))]), np.array([s * math.sin(a), 0.0, math.cos(a)])
    T = TORSO_T
    e1, e2 = T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]
    pv = np.cross(d, e2)
    det = (e1 * pv).sum(1)
    inv = 1 / np.where(np.abs(det) > 1e-12, det, np.inf)
    r = o - T[:, 0]
    u = (r * pv).sum(1) * inv
    q = np.cross(r, e1)
    v = (q @ d) * inv
    t = (q * e2).sum(1) * inv
    hit = (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0)
    return o + d * t[hit].min()


def skin_curve(pts, s, step=0.002):
    """Curva sobre la piel por (grados, y) del lado s, alisada y densa."""
    p = np.array([ray_skin(d, y, s) for d, y in pts])
    p = p[np.r_[True, np.linalg.norm(np.diff(p, axis=0), axis=1) > 1e-4]]
    p = bk.spline(p, step)
    for _ in range(4):
        p[1:-1] = 0.5 * p[1:-1] + 0.25 * (p[:-2] + p[2:])
        p = bk.on_skin(p)[0]
    return p


def strap_keep(curves, hw):
    """> 0 a menos de hw de alguna de las curvas."""
    kd = cKDTree(np.vstack(curves))
    return lambda V: hw - kd.query(V[:, :3])[0]


CURVES = {}


def curves():
    if not CURVES:
        for s in (1, -1):
            CURVES.setdefault("white", []).extend([skin_curve(WHITE_F, s), skin_curve(WHITE_B, s)])
            CURVES.setdefault("black", []).extend([skin_curve(BLACK_F, s), skin_curve(BLACK_B, s), skin_curve(HIP, s)])
    return CURVES


# ---------------- cortes ----------------
def narrow(V):
    """Las tiras estrechas y el hilo (para dividir la piel una vez más cerca de ellos)."""
    c = curves()
    hilo = np.minimum.reduce([HILO_HW - np.abs(V[:, 0]), RING_B[1] - V[:, 1], 0.06 - V[:, 2]])
    return -np.maximum.reduce([strap_keep(c["white"], WHITE_HW)(V), strap_keep(c["black"], BLACK_HW)(V), hilo])


def body_cut(V):
    """Todo lo de debajo del top (> 0 donde se quita): queda el top, las tiras, la V, el hilo y los brazos."""
    c = curves()
    x, y, z = V[:, 0], V[:, 1], V[:, 2]
    phi = phi_of(V)
    top = y - np.interp(phi, *zip(*TOP))
    white = strap_keep(c["white"], WHITE_HW)(V)
    black = strap_keep(c["black"], BLACK_HW)(V)
    front = np.minimum.reduce([np.interp(y, *zip(*FRONT_HW), right=-1) - np.abs(x), V_TOP - y, z - 0.02,
                               (0.4 - V[:, 3]) * 0.05])
    hilo = np.minimum.reduce([HILO_HW - np.abs(x), RING_B[1] - y, 0.06 - z])
    keep = np.maximum.reduce([top, white, black, front, hilo])
    arm = np.maximum(V[:, 4], V[:, 5]) > 0.5
    return np.where(arm, -1.0, -keep)


# ---------------- brazo ----------------
class ArmAxis:
    """Eje del brazo suave (codo redondeado): t de 0 (hombro) a 1 (codo) y 2 (muñeca), con un marco que no gira:
    ángulo 0 por fuera y arriba del brazo (en pose A), creciendo hacia delante."""
    def __init__(self, side, n=400):
        a, s = sud.ARM[side], sud.SIDES[side]
        t = np.linspace(-0.3, 2.3, n)
        p = np.where((t <= 1)[:, None], a["upper"] + np.outer(t, a["lower"] - a["upper"]),
                     a["lower"] + np.outer(t - 1, a["hand"] - a["lower"]))
        for _ in range(60):                                            # redondea el codo
            p[1:-1] = 0.5 * p[1:-1] + 0.25 * (p[:-2] + p[2:])
        self.t, self.p = t, p
        self.d = ct.unit(np.gradient(p, axis=0))
        up = ct.unit(np.cross(self.d, [0, 0, s * 1.0]))
        self.e1 = up * np.sign(up[:, 1:2])
        self.e2 = np.cross(self.d, self.e1) * s
        self.kd = cKDTree(p)

    def frame(self, q):
        """t, punto del eje y ángulo de cada q."""
        k = self.kd.query(q)[1]
        r = q - self.p[k]
        return self.t[k], self.p[k], np.arctan2((r * self.e2[k]).sum(1), (r * self.e1[k]).sum(1))

    def at(self, t):
        k = np.abs(self.t[:, None] - np.atleast_1d(t)[None]).argmin(0)
        return self.p[k], self.d[k], self.e1[k], self.e2[k]


AXES = {}


def axis(side):
    if side not in AXES:
        AXES[side] = ArmAxis(side)
    return AXES[side]


ARM_W = [sud.bone_weight([s + b for b in ct.ARM_BONES]) for s in ("Left", "Right")]


def arm_side(i, w):
    a = [(aw[i] * w).sum(1) for aw in ARM_W]
    return np.array(a[0]), np.array(a[1])


TORSO_KD = cKDTree(P0[(sud.arm_w < 0.1) & ~sud.hand_like & (sud.main_bone != "Head")])


def shape(O, F, si, sw):
    """Mangas globo: un desplazamiento desde el eje del brazo, alisado sobre la malla (sin pliegues en el codo); puño y
    cuello de canalé."""
    skin = (P0[si] * sw[..., None]).sum(1)
    aL, aR = arm_side(si, sw)
    D = np.zeros_like(O)
    free = np.zeros(len(O), bool)
    for side, a in (("Left", aL), ("Right", aR)):
        m = a > 0.05
        t, c, ang = axis(side).frame(skin[m])
        free[np.where(m)[0][t < CUFF_T - 0.04]] = True                   # el puño y la muñeca no se alisan
        g = np.interp(t, *zip(*GLOBE)) * np.clip((a[m] - 0.05) / 0.6, 0, 1)
        g = np.minimum(g, GLOBE_SIDE * TORSO_KD.query(O[m])[0])                 # sin acercarse al costado
        D[m] = ct.unit(O[m] - c) * g[:, None]
    adj, deg = sud.laplacian(F, len(O))
    free[np.concatenate(sud.boundary_loops(F))] = False
    for _ in range(30):
        D[free] = (0.5 * D + 0.5 * (adj @ D) / deg[:, None])[free]
    edge = np.clip(cKDTree(O[np.concatenate(sud.boundary_loops(F))]).query(O)[0] / bk.EDGE_BAND, 0, 1)
    edge = (edge * edge * (3 - 2 * edge))[:, None]                     # en los bordes, la tela sigue bajando a la piel
    O = O + D * edge
    for side, a in (("Left", aL), ("Right", aR)):                      # canalé del puño
        m = a > 0.5
        t, c, ang = axis(side).frame(skin[m])
        rib = np.where(t > CUFF_T, RIB_H * (0.5 + 0.5 * np.cos(28 * ang)), 0)
        O[m] += ct.unit(O[m] - c) * rib[:, None] * edge[m]
    n = bk.on_skin(O)[3]
    col = collar_mask(skin)
    ang = np.arctan2(skin[:, 0], skin[:, 2] - 0.02)
    O[col] += n[col] * (RIB_H * (0.6 + 0.4 * np.cos(60 * ang[col])))[:, None] * edge[col]
    return O


def collar_mask(p):
    y_edge = NECK[0] - NECK[1] * p[:, 2]
    return (p[:, 1] > y_edge - COLLAR_H) & (np.hypot(p[:, 0], p[:, 2] - NECK[4]) < 0.11) & (sud_arm(p) < 0.5)


def sud_arm(p):
    return sud.arm_w[cKDTree(P0).query(p)[1]]


def zone_of(i, w):
    p = (P0[i] * w[..., None]).sum(1)
    aL, aR = arm_side(i, w)
    black = (p[:, 1] < RING_F[1] - 0.004) & (np.maximum(aL, aR) < 0.5) | collar_mask(p)
    for side, a in (("Left", aL), ("Right", aR)):
        m = np.where(a > 0.5)[0]
        black[m[axis(side).frame(p[m])[0] > CUFF_T]] = True
    return np.where(black[:, None], BLACK, WHITE)


# ---------------- relieve de las mangas: rayos desde el eje ----------------
class Sleeve:
    """La tela de una manga; sleeve.hit(t, ang): punto y normal de la tela por un rayo desde el eje."""
    def __init__(self, O, F, side):
        self.ax = axis(side)
        near = cKDTree(P0).query(O)[1]
        mv = (sud.arm_w[near] > 0.3) & (np.sign(O[:, 0]) == sud.SIDES[side])
        f = F[mv[F].all(1)]
        self.T = O[f]
        self.N = ct.unit(np.cross(self.T[:, 1] - self.T[:, 0], self.T[:, 2] - self.T[:, 0]))

    def hit(self, t, ang):
        t, ang = np.broadcast_arrays(np.atleast_1d(t), np.atleast_1d(ang))
        c, d, e1, e2 = self.ax.at(t)
        dirs = np.cos(ang)[:, None] * e1 + np.sin(ang)[:, None] * e2
        P, N = [], []
        e1t, e2t = self.T[:, 1] - self.T[:, 0], self.T[:, 2] - self.T[:, 0]
        for o, dr in zip(c, dirs):
            pv = np.cross(dr, e2t)
            det = (e1t * pv).sum(1)
            inv = 1 / np.where(np.abs(det) > 1e-12, det, np.inf)
            r = o - self.T[:, 0]
            u = (r * pv).sum(1) * inv
            q = np.cross(r, e1t)
            v = (q @ dr) * inv
            tt = (q * e2t).sum(1) * inv
            ok = (u >= -1e-6) & (v >= -1e-6) & (u + v <= 1 + 1e-6) & (tt > 0)
            k = np.where(ok)[0][tt[ok].argmax()]                       # la cara de fuera
            n = self.N[k] * np.sign(self.N[k] @ dr)
            P.append(o + dr * tt[k]); N.append(n)
        return np.array(P), np.array(N)


def smooth_line(p, n, it=4):
    for _ in range(it):
        p[1:-1] = 0.5 * p[1:-1] + 0.25 * (p[:-2] + p[2:])
        n[1:-1] = ct.unit(0.5 * n[1:-1] + 0.25 * (n[:-2] + n[2:]))
    return p, n


def band(sl, t):
    p, n = sl.hit(t, np.linspace(0, 2 * math.pi, 73))
    p, n = smooth_line(p, n, 2)
    return tr.sweep(p + n * LIFT, n, tr.rect(0, REL_T, BAND_W / 2))


def strip(sl):
    p, n = sl.hit(np.linspace(STRIP[0], STRIP[1], 60), STRIP_ANG)
    p, n = smooth_line(p, n)
    return tr.sweep(p + n * LIFT, n, tr.rect(0, REL_T, STRIP[2] / 2))


def torus(c, n, r, tube, m=20, k=6, arc=2 * math.pi, e1=None):
    n = ct.unit(np.asarray(n, float))
    e1 = ct.unit(np.cross(n, [0.3, 1.0, 0.1]) if e1 is None else e1 - n * (e1 @ n)); e2 = np.cross(n, e1)
    a = np.linspace(0, arc, m + 1)[:-1] if arc >= 2 * math.pi else np.linspace(-arc / 2, arc / 2, m)
    pts = c + r * (np.outer(np.cos(a), e1) + np.outer(np.sin(a), e2))
    if arc >= 2 * math.pi:
        pts = np.vstack([pts, pts[:1]])
    return tr.sweep(pts, np.tile(n, (len(pts), 1)), bk.circle(tube, k))


def hanging(sl, side):
    """Anilla en D bajo la segunda banda y dos cintas que bajan por fuera de la manga y cuelgan al pasar la muñeca."""
    c, n = sl.hit(DRING[0], 0.0)
    _, d, _, _ = sl.ax.at(DRING[0])
    out = [(torus(c[0] + n[0] * (LIFT + DRING[2]), n[0], DRING[1], DRING[2], arc=math.pi * 1.3, e1=-d[0]), "metal")]
    down = ct.unit(np.array([sud.SIDES[side] * 0.15, -1.0, -0.05]))
    for extra, sep in HANG:
        a0 = -0.25 - sep / 0.08                                        # hacia atrás de la franja (radio ~8 cm)
        p, nn = sl.hit(np.linspace(DRING[0] + 0.04, 1.93, 50), a0)
        p, nn = smooth_line(p, nn)
        p = p + nn * (LIFT + 0.002)
        tail = p[-1] + np.outer(np.linspace(0.006, extra, 24), down) + np.outer(np.linspace(0, 0.01, 24), nn[-1])
        path = np.vstack([p, tail])
        nrm = np.vstack([nn, np.tile(nn[-1], (24, 1))])
        path, nrm = smooth_line(path, nrm, 3)                          # sin pico al pasar la muñeca
        out.append((tr.sweep(path, nrm, tr.rect(0, REL_T * 1.3, HANG_W / 2)), "negro"))
    return out


def claw(cloth, s, mid, length, deg):
    """Zarpazo: media luna fina en punta por los dos lados, sobre la tela de delante."""
    p0, fr = cloth.front(s * mid[0], mid[1])
    n, up, right = fr
    a = math.radians(deg)
    ax = s * math.cos(a) * right + math.sin(a) * up
    perp = np.cross(n, ax)
    u = np.linspace(-0.5, 0.5, 18)
    width = 0.0070 * np.sin(math.pi * (u + 0.5)) ** 0.8
    bow = 0.010 * (1 - (2 * u) ** 2)
    outer = p0 + np.outer(u * length, ax) + np.outer(bow, perp)
    inner = outer - np.outer(width, perp)
    q, nq = cloth.project(np.vstack([outer, inner]))
    top, bot = q + nq * (LIFT + REL_T), q + nq * LIFT
    k = len(u)
    v = np.vstack([top, bot])
    f = []
    for i in range(k - 1):
        o0, o1, i0, i1 = i, i + 1, k + i, k + i + 1
        f += [[o0, i0, o1], [o1, i0, i1]]                                   # arriba
        f += [[2 * k + o0, 2 * k + o1, 2 * k + i0], [2 * k + o1, 2 * k + i1, 2 * k + i0]]   # abajo
        f += [[o0, o1, 2 * k + o1], [o0, 2 * k + o1, 2 * k + o0]]           # borde de fuera
        f += [[i0, 2 * k + i0, 2 * k + i1], [i0, 2 * k + i1, i1]]           # borde de dentro
    return tr.orient_closed(v, np.array(f))


def extras(O, F):
    cloth = dor.Cloth(O, F)
    torso = (sud.main_bone != "Head") & (sud.arm_w < 0.3) & ~sud.hand_like
    out = []
    for name, (deg, y) in (("f", RING_F), ("b", RING_B)):
        c, n = cloth.project(ray_skin(deg + 0.01, y, 1)[None])
        out.append((torus(c[0] + n[0] * (LIFT + RING_TUBE), n[0], RING_R, RING_TUBE), "metal", torso))
    for side in ("Left", "Right"):
        s = sud.SIDES[side]
        sl = Sleeve(O, F, side)
        arm = (np.sign(P0[:, 0]) == s) & ~sud.hand_like & (sud.main_bone != "Head") & (sud.arm_w > 0.3)
        fore = arm & np.isin(sud.main_bone, [side + "LowerArm"])
        out += [(band(sl, t), "negro", arm) for t in BANDS]
        out.append((strip(sl), "negro", fore))
        out += [(m, z, arm if z == "metal" else fore) for m, z in hanging(sl, side)]
        out += [(claw(cloth, s, mid, ln, dg), "negro", torso) for mid, ln, dg in CLAWS]
    return out


def main():
    cuts = [ct.neck_round(*NECK), ct.sleeve("Left", SLEEVE_T), ct.sleeve("Right", SLEEVE_T), body_cut]
    ct.build(cuts, HERE / "packs" / "claude_top_arnes", "claude_top_arnes", "Top arnés (pruebas)", "top_arnes",
             "Top blanco con bodysuit arnés", [0.92, 0.91, 0.90], extras, zone_of, 0.0005, thick=False, shape=shape,
             refine=narrow)


if __name__ == "__main__":
    main()
