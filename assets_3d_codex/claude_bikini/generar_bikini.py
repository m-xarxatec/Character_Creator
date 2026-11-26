"""Bikini negro liso (plano: planos/Ficha de diseño de bikini floral tradicional.webp, sin flores, borlas ni anillas).

Uso:  python generar_bikini.py
Escribe packs/claude_bikinis/: bikini_negro (una sola pieza: parte de arriba y braguita; ranura «ropa_torso»,
cubre «ropa_piernas»).
La tela es la piel del cuerpo recortada (copas triangulares, tira halter plana que rodea el cuello, banda bajo el
pecho, braguita baja con tiras en la cadera: delante en V por el pliegue de la ingle, detrás tanga que acaba en hilo)
y separada 2,5 mm: cada vértice lleva los pesos y las formas de la piel que tiene debajo (coordenadas en su
triángulo), así se ajusta al cuerpo con cualquier deslizador. Delante se corta también por los pesos de la piel
(donde pasa a ser muslo), así que no se va al muslo. En los bordes la tela baja hasta la piel (sin escalón: así el
contorno negro no parpadea contra la piel).
Lazos (nuca y caderas): tubos con los pesos y las formas de la piel más cercana. Usa las herramientas de la sudadera
y el traje.
Zonas en COLOR_0: (0,0,0) tela, r = 1 lazos. Hoy el shader lo pinta todo de un color.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.interpolate import CubicSpline
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_sudadera as sud
import generar_traje as tr

OUT = HERE / "packs" / "claude_bikinis"
P0, F0 = sud.P0, sud.F0

# --- medidas (metros; cuerpo por defecto: punta del pecho en (±0,07; 1,21; 0,15), entrepierna 0,772) ---
GAP, THICK = 0.0025, 0.0012                    # tela: separada de la piel y grosor
EDGE_BAND = 0.006                              # en los bordes baja hasta la piel en estos 6 mm
CUP = [(0.066, 1.315), (0.010, 1.128), (0.135, 1.134)]   # copa (|x|, y): arriba, abajo dentro, abajo fuera
Z_FRONT = 0.02                                 # las copas solo delante
BAND_Y, BAND_H = 1.133, 0.006                  # banda bajo el pecho (media anchura)
STRAP_HW = 0.006                               # tira halter (media anchura): de la punta de la copa sube por aquí…
STRAP_UP = (0.062, 1.36)                       # …(|x|, y) y rodea el cuello por estos puntos: (grados desde delante
STRAP_NECK = [(75, 1.405), (110, 1.425), (145, 1.435), (180, 1.44)]   # hacia el lado, y); 180 es la nuca
NECK_C = (0.0, 0.02)                           # eje del cuello (x, z)
TOP_F = [(0.0, 0.905), (0.10, 0.912), (0.17, 0.925)]     # cintura de la braguita (|x|, y), delante…
TOP_B = [(0.0, 0.925), (0.10, 0.925), (0.17, 0.930)]     # …y detrás
FRONT_V = [(0.77, 0.016), (0.80, 0.020), (0.905, 0.135)]  # delante: V (y, media anchura)…
LEG_MAX = 0.4                                  # …sin pasar a la piel que pesa más de esto de pierna (el muslo)
BACK_W = [(0.77, 0.006), (0.845, 0.006), (0.885, 0.035), (0.925, 0.075)]  # detrás: tanga (y, media anchura)
HIP_H = 0.005                                  # tira de la cadera (media anchura): cinta sobre la piel…
HIP_RING = [(40, 0.907), (95, 0.912), (150, 0.920)]   # …por estos puntos (grados desde delante, y), de la braguita
HIP_C = (0.0, 0.02)                            # delante a la de detrás; eje de la cadera (x, z)
ZC, Z_BLEND = 0.02, 0.05                       # delante/detrás: z respecto al centro, mezcla en ±5 cm
LEG_SMOOTH = 6                                 # alisado de los pesos de pierna (el pliegue de la ingle)
EDGE_IT = 12                                   # alisado de los bordes sobre la piel
TENSE_IT = 80                                  # «tela tensa»: puentea huecos pequeños
BRIDGE = 0.004                                 # despegada más de esto: sigue a la piel más cercana, no a la de debajo
CORD_R = 0.0022                                # radio de los lazos
ZONES = {"tela": (0, 0, 0, 1), "cordon": (1, 0, 0, 1)}

SKIN_N = sud.vertex_normals(P0, F0)
TRI_TREE = cKDTree(P0[F0].mean(1))


# ---------------- piel ----------------
def leg_weight():
    """Peso de pierna de cada vértice de piel, alisado sobre la malla (pliegue de la ingle sin saltos)."""
    L = sud.bone_weight([s + b for s in sud.SIDES for b in ("UpperLeg", "LowerLeg")])
    a, deg = sud.laplacian(F0, len(P0))
    for _ in range(LEG_SMOOTH):
        L = 0.5 * L + 0.5 * (a @ L) / deg
    return L


def on_skin(p, k=16):
    """Punto de la piel más cercano a cada p: posición, 3 vértices de su triángulo, coordenadas y normal."""
    _, ti = TRI_TREE.query(p, k=k)
    T = P0[F0[ti]]                                                     # (n, k, 3 vértices, 3)
    e1, e2 = T[:, :, 1] - T[:, :, 0], T[:, :, 2] - T[:, :, 0]
    r = p[:, None] - T[:, :, 0]
    d11, d12, d22 = (e1 * e1).sum(-1), (e1 * e2).sum(-1), (e2 * e2).sum(-1)
    r1, r2 = (r * e1).sum(-1), (r * e2).sum(-1)
    den = d11 * d22 - d12 ** 2
    v = (d22 * r1 - d12 * r2) / den
    w = (d11 * r2 - d12 * r1) / den
    b = np.clip(np.stack([1 - v - w, v, w], -1), 0, None)
    b /= b.sum(-1, keepdims=True)
    q = (T * b[..., None]).sum(2)
    best = np.linalg.norm(p[:, None] - q, axis=-1).argmin(1)
    n_ = np.arange(len(p))
    si, sw = F0[ti[n_, best]], b[n_, best]
    nrm = (SKIN_N[si] * sw[..., None]).sum(1)
    return q[n_, best], si, sw, nrm / np.linalg.norm(nrm, axis=1, keepdims=True)


def push_out(p, gap, iters=4):
    """Saca de la piel los puntos que queden a menos de gap (sobre la normal de la piel)."""
    for _ in range(iters):
        q, _, _, n = on_skin(p)
        h = ((p - q) * n).sum(1)
        p = p + n * np.maximum(gap - h, 0)[:, None]
    return p


def subdivide(V, F):
    """Divide cada triángulo en 4 (puntos medios, plano: sigue sobre la piel)."""
    e = np.sort(np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]]), 1)
    ue, inv = np.unique(e, axis=0, return_inverse=True)
    m = len(V) + inv.ravel().reshape(3, -1).T                         # punto medio de cada lado de cada cara
    V = np.concatenate([V, (V[ue[:, 0]] + V[ue[:, 1]]) / 2])
    a, b, c = F.T
    ab, bc, ca = m.T
    return V, np.concatenate([np.stack(x, 1) for x in ((a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca))])


# ---------------- dónde hay tela ----------------
def front_factor(p):
    t = np.clip((p[:, 2] - ZC) / Z_BLEND * 0.5 + 0.5, 0, 1)
    return t * t * (3 - 2 * t)


def cup_field(p, s):
    """< 0 dentro de la copa del lado s (triángulo en la vista de frente), solo delante."""
    q = np.stack([s * p[:, 0], p[:, 1]], 1)
    f = np.full(len(p), -1.0)
    for a, b in zip(CUP, CUP[1:] + CUP[:1]):
        a, b = np.array(a), np.array(b)
        n = np.array([b[1] - a[1], a[0] - b[0]]) / np.linalg.norm(b - a)
        f = np.maximum(f, (q - a) @ n)
    return np.maximum(f, Z_FRONT - p[:, 2])


def bottom_field(p, L):
    """< 0 en la braguita: delante V que no pasa al muslo, detrás tanga que acaba en hilo."""
    ax, y, w = np.abs(p[:, 0]), p[:, 1], front_factor(p)
    top = np.interp(ax, *zip(*TOP_B)) * (1 - w) + np.interp(ax, *zip(*TOP_F)) * w
    front = np.maximum.reduce([y - top, ax - np.interp(y, *zip(*FRONT_V)), (L - LEG_MAX) * 0.05])
    back = np.maximum(y - top, ax - np.interp(y, *zip(*BACK_W)))
    return back + (front - back) * w


def skin_at(x, y):
    """Punto de la piel delante en (x, y): el vértice de delante más cercano en la vista de frente."""
    m = (P0[:, 2] > 0.02) & (sud.main_bone != "Head") & (sud.arm_w < 0.3)
    return on_skin(P0[m][np.hypot(P0[m, 0] - x, P0[m, 1] - y).argmin()][None])[0][0]


def ring_at(deg, y, s, center=NECK_C):
    """Punto de la piel a deg grados alrededor del eje (0 delante, 180 detrás) hacia el lado s, a la altura y."""
    m = (np.abs(P0[:, 1] - y) < 0.006) & (sud.main_bone != "Head") & (sud.arm_w < 0.3) & ~sud.hand_like
    dx, dz = P0[m, 0] - center[0], P0[m, 2] - center[1]
    a = math.radians(deg)
    along = dx * s * math.sin(a) + dz * math.cos(a)
    across = np.abs(dx * math.cos(a) - dz * s * math.sin(a))
    return P0[m][(along - 2 * across).argmax()]


def strap_curve():
    """La tira halter sobre la piel: de la punta de una copa, alrededor de la nuca, a la punta de la otra."""
    side = []
    for s in (1, -1):
        pts = [skin_at(s * (CUP[0][0] - 0.003), CUP[0][1] - 0.025), skin_at(s * CUP[0][0], CUP[0][1]),
               skin_at(s * STRAP_UP[0], STRAP_UP[1])]            # nace dentro de la copa
        side.append(np.array(pts + [ring_at(d, y, s) for d, y in STRAP_NECK]))
    c = spline(np.concatenate([side[0], side[1][-2::-1]]), 0.002)
    for _ in range(3):
        c = on_skin(c)[0]
        c[1:-1] = 0.5 * c[1:-1] + 0.25 * (c[:-2] + c[2:])
    return on_skin(c)[0]


def field(V):
    p, L = V[:, :3], V[:, 3]
    return np.minimum.reduce([cup_field(p, 1), cup_field(p, -1), np.abs(p[:, 1] - BAND_Y) - BAND_H,
                              bottom_field(p, L)])


def hip_curve(s):
    """Tira de la cadera del lado s sobre la piel: de la braguita de delante a la de detrás."""
    c = spline(np.array([ring_at(d, y, s, HIP_C) for d, y in HIP_RING]), 0.004)
    for _ in range(3):
        c = on_skin(c)[0]
        c[1:-1] = 0.5 * c[1:-1] + 0.25 * (c[:-2] + c[2:])
    return on_skin(c)[0]


def strap_sheet(c, hw):
    """Cinta de media anchura hw sobre la piel a lo largo de la curva c (un punto cada ~4 mm), más alta en el
    centro y a ras en los bordes."""
    t = np.gradient(c, axis=0)
    n = on_skin(c)[3]
    b = np.cross(n, t)
    b /= np.linalg.norm(b, axis=1, keepdims=True)
    U = np.array([-1, -0.6, 0, 0.6, 1.0])
    lift = np.array([0, 0.75, 1, 0.75, 0]) * (GAP + 0.0006)            # algo sobre la copa, donde se juntan
    V = np.concatenate([on_skin(c + b * u * hw)[0] for u in U])
    nV = np.concatenate([on_skin(c + b * u * hw)[3] * h for u, h in zip(U, lift)])
    m, k = len(c), len(U)
    i = np.arange(m - 1)[:, None] + m * np.arange(k - 1)[None]
    i = i.ravel()
    F = np.concatenate([np.stack([i, i + 1, i + m + 1], 1), np.stack([i, i + m + 1, i + m], 1)])
    if np.dot(np.cross(V[F[0, 1]] - V[F[0, 0]], V[F[0, 2]] - V[F[0, 0]]), nV[F[0, 0]] + n[0]) < 0:
        F = F[:, ::-1]
    return V + nV, F


# ---------------- tela ----------------
def cut_skin():
    """La piel recortada (sobre la piel; aún sin separar): vértices, caras y bordes."""
    keep = (P0[:, 1] > 0.70) & (P0[:, 1] < 1.45) & (sud.arm_w < 0.5) & ~sud.hand_like & (sud.main_bone != "Head")
    F = F0[keep[F0].all(1)]
    V = np.c_[P0, leg_weight()]
    F = F[field(V)[F].min(1) < 0.03]                                   # solo cerca de la prenda
    V, F = _compact(V, F)
    V, F = subdivide(V, F)
    V, F = tr.clip(V, F, field(V))
    V, F = _compact(V[:, :3], F)
    loops = sud.boundary_loops(F)
    for _ in range(EDGE_IT):                                           # bordes alisados, sin salir de la piel
        for lp in loops:
            V[lp] = on_skin(0.5 * V[lp] + 0.25 * (np.roll(V[lp], 1, 0) + np.roll(V[lp], -1, 0)))[0]
    return V, F, loops


def _compact(V, F):
    used = np.unique(F)
    remap = -np.ones(len(V), int)
    remap[used] = np.arange(len(used))
    return V[used], remap[F]


def tense(O, F, loops):
    """Alisa la tela con los bordes fijos y sin meterla en la piel: puentea los huecos pequeños."""
    a, deg = sud.laplacian(F, len(O))
    free = np.ones(len(O), bool)
    free[np.concatenate(loops)] = False
    for _ in range(TENSE_IT):
        O[free] = (0.5 * O + 0.5 * (a @ O) / deg[:, None])[free]
        O = push_out(O, GAP, 1)
    return O


def to_edges(O, loops):
    """En los bordes la tela baja hasta la piel (en EDGE_BAND), sin escalón."""
    d = cKDTree(O[np.concatenate(loops)]).query(O)[0]
    t = np.clip(d / EDGE_BAND, 0, 1)
    t = t * t * (3 - 2 * t)
    q, _, _, n = on_skin(O)
    return O - n * (((O - q) * n).sum(1) * (1 - t))[:, None]


# ---------------- lazos ----------------
def spline(pts, step=0.003, closed=False):
    s = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
    return CubicSpline(s, pts, bc_type="periodic" if closed else "not-a-knot")(np.arange(0, s[-1] + 1e-9, step))


def circle(r, m=8):
    return [(r * math.cos(a), r * math.sin(a)) for a in np.linspace(0, 2 * math.pi, m, endpoint=False)]


def tube(pts, r, up=None, gap=None):
    """Cordón por pts (sacado de la piel), con la normal de la piel como «arriba» del perfil."""
    if gap is not None:
        pts = push_out(pts, gap)
        pts = spline(pts, closed=False) if len(pts) > 3 else pts
        pts = push_out(pts, gap, 2)
    if up is None:
        up = on_skin(pts)[3]
    return tr.sweep(pts, up, circle(r))


def bow(p, n, up, size=1.0):
    """Lazo sencillo en p (n: hacia fuera de la piel): dos lazadas, dos cabos y el nudo."""
    t = np.cross(up, n)
    t /= np.linalg.norm(t)
    L, H, tail = 0.030 * size, 0.016 * size, 0.050 * size
    s = np.linspace(0, 1, 28)[:, None]
    parts = []
    for side in (1, -1):
        loop = p + t * side * L * np.sin(np.pi * s) + up * 0.5 * H * np.sin(2 * np.pi * s) * side \
            + n * (0.003 + 0.004 * np.sin(np.pi * s))
        parts.append(loop)
        parts.append(p + t * side * (0.004 + 0.012 * s) + up * (-tail * s) + n * 0.003)
    tubes = [tube(spline(q), CORD_R, gap=CORD_R + 0.001) for q in parts]
    knot = p + n * 0.004 + t * np.linspace(-0.004, 0.004, 5)[:, None]
    tubes.append(tube(knot, 0.0045, up=np.tile(n, (5, 1))))
    return tubes


# ---------------- pieza ----------------
def normal_at(N, i, w):
    n = (N[i] * w[..., None]).sum(1)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def write(v, f, zc, si, sw, hgt, pid="bikini_negro"):
    """Como kigurumi.write, pero la separación hgt (sobre la normal de la piel) gira con la piel en cada forma."""
    joints, weights = sud.blend_weights(si, sw)
    n0 = normal_at(SKIN_N, si, sw)
    lift = hgt[:, None]
    targets = {}
    for name, d in sud.B["targets"].items():
        moved = (d[si] * sw[..., None]).sum(1)
        if np.abs(moved).max() < 0.0005:
            continue
        moved += (normal_at(sud.vertex_normals(P0 + d, F0), si, sw) - n0) * lift
        targets[name] = moved.astype(np.float32)
    to_rig = np.array([tr.RIG_JN.index(n) if n in tr.RIG_JN else -1 for n in sud.JN])
    jr = to_rig[joints]
    weights = np.where(jr < 0, 0, weights)
    weights /= weights.sum(1, keepdims=True)
    path = OUT / (pid + ".glb")
    sha = tr.write_glb(path, v, sud.vertex_normals(v, f), f, np.where(jr < 0, 0, jr), weights, targets, pid, zc)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        pid, len(v), len(f), len(targets), path.stat().st_size / 1e6))
    return sha, targets


def build():
    V, F, loops = cut_skin()
    q, si, sw, n = on_skin(V)
    O = to_edges(tense(push_out(q + n * GAP, GAP), F, loops), loops)
    q, si, sw, n = on_skin(O)                                          # anclada a la piel que tiene debajo…
    t = np.clip((((O - q) * n).sum(1) - GAP - 0.001) / BRIDGE, 0, 1)[:, None]
    ni, nw = sud.nearest_skin(O, 5)                                    # …o, donde hace de puente, a la más cercana
    si, sw = np.c_[si, ni], np.c_[sw * (1 - t), nw * t]
    verts, faces, zones, src_i, src_w, hgt = [], [], [], [], [], []

    def add(v, f, zone, i=None, w=None, mask=None):
        v = np.asarray(v, float)
        faces.append(np.asarray(f, int) + sum(len(x) for x in verts))
        verts.append(v)
        zones.append(np.tile(ZONES[zone], (len(v), 1)))
        if i is None:
            i, w = sud.nearest_skin(v, 8, mask)
            hgt.append(np.zeros(len(v)))                               # lazos: siguen a la piel sin más
        else:                                                          # tela: altura sobre su triángulo
            q = (P0[i] * w[..., None]).sum(1)
            hgt.append(((v - q) * normal_at(SKIN_N, i, w)).sum(1))
        src_i.append(np.c_[i, np.zeros((len(v), 8 - i.shape[1]), int)])
        src_w.append(np.c_[w, np.zeros((len(v), 8 - w.shape[1]))])

    v, f, src = tr.thick_sheet(O, F, THICK)
    add(v, f, "tela", si[src], sw[src])
    neck = strap_curve()
    neck = neck[np.unique(np.r_[0:len(neck):2, len(neck) - 1])]       # un punto cada 4 mm
    hips = {s: hip_curve(s) for s in (1, -1)}
    for c, hw in [(neck, STRAP_HW), (hips[1], HIP_H), (hips[-1], HIP_H)]:
        S, SF = strap_sheet(c, hw)                                     # tiras: cintas sobre la piel
        _, ti, tw, _ = on_skin(S)
        v, f, src = tr.thick_sheet(S, SF, THICK)
        add(v, f, "tela", ti[src], tw[src])
    no_head = sud.main_bone != "Head"
    torso = no_head & (sud.arm_w < 0.3) & ~sud.hand_like
    nape = neck[np.where(np.abs(neck[:, 0]) < 0.004, -neck[:, 2], -np.inf).argmax()]   # lazo de la nuca, sobre la tira
    for part in bow(nape + [0, 0, -GAP], np.array([0, 0, -1.0]), np.array([0, 1.0, 0]), 0.8):
        add(*part, "cordon", mask=no_head & (sud.arm_w < 0.3))
    for s in (1, -1):                                                  # lazo de cada cadera, sobre su tira
        hp = hips[s][np.argmax(s * hips[s][:, 0])]
        hn = on_skin(hp[None])[3][0]
        hp = hp + hn * GAP
        for part in bow(hp, hn, np.array([0, 1.0, 0])):
            add(*part, "cordon", mask=torso)
    v, f = np.concatenate(verts), np.concatenate(faces)
    sha = write(v, f, np.concatenate(zones), np.concatenate(src_i), np.concatenate(src_w), np.concatenate(hgt))
    return sha, O, F, loops, v, np.concatenate(zones), si, sw


def measure(O, F, v, zones, targets, si, sw, loops):
    """Huecos a la piel: tela y lazos en reposo; tela con cada forma (sola, al máximo), lejos de los bordes."""
    q, n = (P0[si] * sw[..., None]).sum(1), normal_at(SKIN_N, si, sw)
    inner = cKDTree(O[np.concatenate(loops)]).query(O)[0] > EDGE_BAND  # en los bordes baja a la piel a propósito
    print("MEDIDA tela a la piel (reposo, lejos de los bordes): mín %.1f mm" % (((O - q) * n).sum(1)[inner].min() * 1000))
    cord = v[zones[:, 0] > 0.5]
    cq, _, _, cn = on_skin(cord)
    print("MEDIDA lazos a la piel (reposo): mín %.1f mm (radio %.1f)" % (
        ((cord - cq) * cn).sum(1).min() * 1000, CORD_R * 1000))
    own, near = [], []
    for name, d in sud.B["targets"].items():
        if name not in targets:
            continue
        P = P0 + d
        Os = O + targets[name][:len(O)]
        Pn = sud.vertex_normals(P, F0)
        own.append(((Os - (P[si] * sw[..., None]).sum(1)) * normal_at(Pn, si, sw)).sum(1)[inner].min())
        if "*" not in name:                                            # las combinadas, solas, no son un cuerpo
            dd, ii = cKDTree(P).query(Os[inner], k=4)
            w = 1 / (dd + 0.003) ** 2
            w /= w.sum(1, keepdims=True)
            nn = normal_at(Pn, ii, w)
            near.append((((Os[inner] - (P[ii] * w[..., None]).sum(1)) * nn).sum(1).min(), name))
    near.sort()
    print("MEDIDA tela con cada forma, sobre su piel: mín %.1f mm" % (min(own) * 1000))
    print("MEDIDA tela con cada forma simple, a la piel más cercana: peores %s" % ", ".join(
        "%.1f mm (%s)" % (a * 1000, b) for a, b in near[:3]))
    lw = (leg_weight()[si] * sw).sum(1)
    front = (O[:, 1] < 0.90) & (O[:, 2] > ZC + Z_BLEND)
    print("MEDIDA braguita: peso de pierna máx bajo la tela delante %.2f (0,5 = muslo); baja hasta y=%.3f" % (
        lw[front].max(), O[:, 1].min()))
    print("MEDIDA bordes: %d lazos" % len(sud.boundary_loops(F)))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (sha, targets), O, F, loops, v, zones, si, sw = build()
    measure(O, F, v, zones, targets, si, sw, loops)
    cards = [tr.card("bikini_negro", "Bikini negro", sha, [0.10, 0.10, 0.11], "ropa", "ropa_torso", ["ropa_piernas"])]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_bikinis", "nombre": "Bikinis (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
