"""Casco de astronauta (burbuja con visor, orejeras y anillo de cuello) para la humana de GameMolde.

Uso:  python generar_casco.py
Lee godot/datos/humana/cuerpo.glb (cabeza, cuello, hombros y formas) y el esqueleto de godot/packs/base/tights.glb;
escribe en packs/claude_cascos/ cuatro piezas (un color cada una) y su pack.json:
  casco_astronauta            carcasa, en la ranura «pelo»: quita el peinado (y ponerse un peinado quita el casco)
  casco_astronauta_metal      anillo del cuello, orejeras, marco de la abertura, cierre y remaches
  casco_astronauta_acolchado  forro acolchado interior
  casco_astronauta_visor      visor opaco tipo espejo (sin él, el casco queda abierto y se ve la cara)
- 100 % del hueso Head; las otras tres, ranura «accesorio» (se ponen aparte, como el GM de la gorra).
- Medido sobre la cabeza: la esfera mínima que la contiene + HUECO + ACOLCHADO + GROSOR. El anillo, el más estrecho
  que no toca el cuello por dentro ni los hombros por debajo.
- Se adapta a las formas del cuerpo sin abollarse: cada forma estira y mueve el casco entero como la caja de la
  cabeza (afín por ejes); la parte baja sigue además la altura de los hombros (no se clava al acortar el cuello).
"""
import hashlib, json, math, struct, sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).parents[1] / "claude_gorra"))
import glb

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / "packs" / "claude_cascos"
D = math.radians

# --- medidas (metros; ángulos: az 0 = delante, + = izquierda del personaje; el 0 = altura del centro) ---
HUECO, ACOLCHADO, GROSOR = 0.005, 0.010, 0.005
COJIN = 0.004                         # lo que abulta cada cojín del acolchado hacia la cabeza
PASO = D(3.5)                         # resolución de la burbuja
ANILLO_ALTO, ANILLO_ANCHO = 0.035, 0.014
HOLGURA_HOMBRO, HOLGURA_CUELLO = 0.008, 0.006
ABERTURA_AW, ABERTURA_TOP, ABERTURA_SOBRE_BORDE, ABERTURA_P = D(58), D(27), D(10), 3.0
VISOR_DENTRO, VISOR_FUERA = 0.0035, 0.006
OREJERA_AZ, OREJERA_EL = D(92), D(-4)
FRANJA_ANCHO, FRANJA_ALTO, FRANJA_TOP = 0.014, 0.008, D(34)
FORMA_MIN = 0.002                     # una forma entra si mueve el casco más de 2 mm


# ---------------- cuerpo ----------------
body, body_buf = glb.read(ROOT / "godot/datos/humana/cuerpo.glb")
B = glb.mesh_data(body, body_buf)
P0 = B["POSITION"].astype(float)
JN = glb.joint_names(body)
HW = (B["WEIGHTS_0"] * (B["JOINTS_0"] == JN.index("Head"))).sum(1)
HEAD = np.where(HW > 0.3)[0]


def enclosing_sphere(pts):
    """Centro (en x = 0) y radio de la esfera más pequeña que contiene los puntos: rejilla cada vez más fina."""
    cy, cz, step = pts[:, 1].mean(), pts[:, 2].mean(), 0.01
    for _ in range(4):
        r, cy, cz = min((np.sqrt(pts[:, 0] ** 2 + (pts[:, 1] - y) ** 2 + (pts[:, 2] - z) ** 2).max(), y, z)
                        for y in cy + step * np.arange(-5, 6) for z in cz + step * np.arange(-5, 6))
        step /= 5
    return np.array([0.0, cy, cz]), r


C, R_HEAD = enclosing_sphere(P0[HEAD])
R = R_HEAD + HUECO + ACOLCHADO + GROSOR
HR = np.hypot(P0[:, 0], P0[:, 2] - C[2])      # distancia de cada punto de la piel al eje del anillo


def fit_ring():
    """El anillo más estrecho cuyo volumen (más holguras) no contiene ningún punto de la piel."""
    for ro in np.arange(0.08, R - 0.01, 0.001):
        ri = ro - ANILLO_ANCHO
        y_top = C[1] - math.sqrt(R ** 2 - ro ** 2)      # ahí la burbuja tiene el radio del anillo
        y_bot = y_top - ANILLO_ALTO
        hit = (HR > ri - HOLGURA_CUELLO) & (HR < ro + HOLGURA_HOMBRO) \
            & (P0[:, 1] > y_bot - HOLGURA_HOMBRO) & (P0[:, 1] < y_top)
        if not hit.any():
            return ro, ri, y_bot, y_top
    sys.exit("FALLO: el anillo no cabe entre el cuello y los hombros")


RO, RI, Y_BOT, Y_TOP = fit_ring()
EL_BOT = math.asin((Y_TOP - C[1]) / R)
_under = (HR > RI) & (HR < RO + 0.01) & (P0[:, 1] < Y_BOT)
SHOULDER = np.where(_under & (P0[:, 1] > P0[_under, 1].max() - 0.02))[0]   # piel en la que se apoya el anillo


# ---------------- utilidades ----------------
def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


def sph(az, el, r):
    az, el, r = np.broadcast_arrays(az, el, r)
    return C + np.stack([r * np.cos(el) * np.sin(az), r * np.sin(el), r * np.cos(el) * np.cos(az)], -1)


def faces(n, m, wrap_j, wrap_i):
    """Rejilla n × m (filas j, columnas i): dos triángulos por celda, con vuelta opcional en cada sentido."""
    j, i = np.meshgrid(np.arange(n if wrap_j else n - 1), np.arange(m if wrap_i else m - 1), indexing="ij")
    a, b = j * m + i, j * m + (i + 1) % m
    c, d = ((j + 1) % n) * m + i, ((j + 1) % n) * m + (i + 1) % m
    return np.concatenate([np.stack([a, c, b], -1).reshape(-1, 3), np.stack([b, c, d], -1).reshape(-1, 3)])


def orient_closed(v, f):
    """Malla cerrada con las caras hacia fuera (volumen con signo positivo)."""
    vol = np.einsum("ij,ij->i", v[f[:, 0]], np.cross(v[f[:, 1]], v[f[:, 2]])).sum()
    return v, (f if vol > 0 else f[:, ::-1])


def compact(v, f):
    used, inv = np.unique(f, return_inverse=True)
    return v[used], inv.reshape(f.shape)


class Mesh:
    def __init__(self):
        self.v, self.f = [], []

    def add(self, vf):
        v, f = vf
        self.f.append(np.asarray(f, int) + sum(len(x) for x in self.v))
        self.v.append(np.asarray(v, float))

    def arrays(self):
        return np.concatenate(self.v), np.concatenate(self.f)


class Outline:
    """Contorno superelíptico sobre la esfera: f = |az/aw|^p + |(el - e0)/eh|^p; f = 1 en el borde."""
    def __init__(self, aw, top, bot, p):
        self.aw, self.e0, self.eh, self.p = aw, (top + bot) / 2, (top - bot) / 2, p

    def f(self, az, el):
        return np.abs(az / self.aw) ** self.p + np.abs((el - self.e0) / self.eh) ** self.p

    def snap(self, az, el):
        k = self.f(az, el) ** (-1 / self.p)
        return az * k, self.e0 + (el - self.e0) * k

    def path(self, n, shrink=1.0):
        t = np.linspace(0, 2 * math.pi, n, endpoint=False)
        u = np.sign(np.cos(t)) * np.abs(np.cos(t)) ** (2 / self.p)
        w = np.sign(np.sin(t)) * np.abs(np.sin(t)) ** (2 / self.p)
        return u * self.aw * shrink, self.e0 + w * self.eh * shrink


ABERTURA = Outline(ABERTURA_AW, ABERTURA_TOP, EL_BOT + ABERTURA_SOBRE_BORDE, ABERTURA_P)
FORRO = Outline(ABERTURA_AW + D(3), ABERTURA_TOP + D(3), EL_BOT + ABERTURA_SOBRE_BORDE - D(3), ABERTURA_P)
VISOR = Outline(D(84), ABERTURA_TOP + D(5), EL_BOT + ABERTURA_SOBRE_BORDE - D(3), 3.5)


# ---------------- burbujas: carcasa, acolchado y visor ----------------
def bubble(az, el, keep, outline, r_out, r_in, outer=True, wrap=True, pole=False):
    """Casquete con grosor: rejilla (el × az) sobre la esfera; se quitan las caras fuera de keep y su borde se lleva al
    contorno. Cara de fuera (r_out), de dentro (r_in) y un labio que las une (redondeado; recto si outer=False, que
    deja sin cara de fuera: el acolchado no se ve por detrás)."""
    rows, cols = len(el), len(az)
    A, E = [x.ravel().copy() for x in np.meshgrid(az, el)]
    F = faces(rows, cols, False, wrap)
    if pole:
        last = (rows - 1) * cols + np.arange(cols)
        F = np.concatenate([F, np.stack([last, np.full(cols, len(A)), np.roll(last, -1)], -1)])
        A, E = np.append(A, 0.0), np.append(E, math.pi / 2)
    full = keep(A, E)[F].all(1)
    kept = F[full]
    cut = np.intersect1d(kept.ravel(), F[~full].ravel())
    A[cut], E[cut] = outline.snap(A[cut], E[cut])
    O, I = sph(A, E, r_out(A, E)), sph(A, E, r_in(A, E))
    fn = np.cross(O[kept[:, 1]] - O[kept[:, 0]], O[kept[:, 2]] - O[kept[:, 0]])
    if (fn * (O[kept].mean(1) - C)).sum() < 0:
        kept = kept[:, ::-1]
    e = np.concatenate([kept[:, [0, 1]], kept[:, [1, 2]], kept[:, [2, 0]]]).tolist()
    keys = set(map(tuple, e))
    bnd = np.array([x for x in e if (x[1], x[0]) not in keys])
    bv = np.unique(bnd)
    # hacia dónde se acaba la superficie en cada vértice del borde (tangente a la esfera)
    cen, cnt = np.zeros_like(O), np.zeros(len(O))
    fc = O[kept].mean(1)
    for k in range(3):
        np.add.at(cen, kept[:, k], fc)
        np.add.at(cnt, kept[:, k], 1)
    T = O[bv] - cen[bv] / cnt[bv, None]
    nr = unit(O[bv] - C)
    T = unit(T - nr * (T * nr).sum(1, keepdims=True))
    n, K = len(A), (4 if outer else 1)
    row = np.zeros((K + 1, n), int)
    row[0], row[K] = np.arange(n), n + np.arange(n)
    V, base = [O, I], 2 * n
    half, mid = (O[bv] - I[bv]) / 2, (O[bv] + I[bv]) / 2
    for k in range(1, K):
        th = math.pi * k / K
        V.append(mid + half * math.cos(th) + T * np.linalg.norm(half, axis=1, keepdims=True) * math.sin(th))
        row[k, bv] = base + np.arange(len(bv))
        base += len(bv)
    a, b = bnd[:, 0], bnd[:, 1]
    Fs = [kept[:, ::-1] + n] + ([kept] if outer else [])
    for k in range(K):
        Fs += [np.stack([row[k, b], row[k, a], row[k + 1, a]], -1), np.stack([row[k, b], row[k + 1, a], row[k + 1, b]], -1)]
    return compact(np.concatenate(V), np.concatenate(Fs))


def rows_to_pole(el0):
    return np.linspace(el0, math.pi / 2, int(math.ceil((math.pi / 2 - el0) / PASO)) + 1)[:-1]


AZ_ALL = np.linspace(-math.pi, math.pi, int(round(2 * math.pi / PASO)), endpoint=False)


def shell():
    return bubble(AZ_ALL, rows_to_pole(EL_BOT), lambda A, E: ABERTURA.f(A, E) >= 1, ABERTURA,
                  lambda A, E: np.full_like(A, R), lambda A, E: np.full_like(A, R - GROSOR), pole=True)


def pillow(A, E):
    fa = ((A + math.pi) / D(30)) % 1
    fe = ((E - EL_BOT) / D(24)) % 1
    return (np.sin(math.pi * fa) * np.sin(math.pi * fe)) ** 0.5


def padding():
    return bubble(AZ_ALL, rows_to_pole(EL_BOT + D(1.5)), lambda A, E: FORRO.f(A, E) >= 1, FORRO,
                  lambda A, E: np.full_like(A, R - GROSOR - 0.0005),
                  lambda A, E: R_HEAD + HUECO + COJIN * (1 - pillow(A, E)), outer=False, pole=True)


def visor():
    az = np.arange(-VISOR.aw - PASO, VISOR.aw + 1.5 * PASO, PASO)
    el = np.arange(VISOR.e0 - VISOR.eh - PASO, VISOR.e0 + VISOR.eh + 1.5 * PASO, PASO)
    return bubble(az, el, lambda A, E: VISOR.f(A, E) <= 1, VISOR,
                  lambda A, E: np.full_like(A, R + VISOR_FUERA), lambda A, E: np.full_like(A, R + VISOR_DENTRO),
                  wrap=False)


# ---------------- piezas sueltas: franja, anillo, orejeras, marco, cierre, remaches ----------------
def sweep(points, frame_n, frame_b, profile, closed):
    """Perfil (w, h) cerrado barrido a lo largo de points; h sobre frame_n, w sobre frame_b. Tapas si es abierto."""
    pr = np.asarray(profile, float)
    rings = points[:, None, :] + frame_b[:, None, :] * pr[None, :, 0, None] + frame_n[:, None, :] * pr[None, :, 1, None]
    n, m = rings.shape[:2]
    v, f = rings.reshape(-1, 3), faces(n, m, closed, True)
    if not closed:
        i = np.arange(m)
        c0, c1 = len(v), len(v) + 1
        v = np.concatenate([v, [rings[0].mean(0), rings[-1].mean(0)]])
        f = np.concatenate([f, np.stack([np.full(m, c0), i, (i + 1) % m], -1),
                            np.stack([np.full(m, c1), (n - 1) * m + (i + 1) % m, (n - 1) * m + i], -1)])
    return orient_closed(v, f)


def brow_band():
    """Franja en relieve de orejera a orejera por encima de la abertura (el visor se mete por debajo)."""
    az = np.linspace(-(OREJERA_AZ - D(4)), OREJERA_AZ - D(4), 140)
    el = OREJERA_EL + (FRANJA_TOP - OREJERA_EL) * np.cos(az / OREJERA_AZ * math.pi / 2)
    n = unit(sph(az, el, 1.0) - C)
    b = unit(np.cross(n, np.gradient(n, axis=0)))
    W, H, bev = FRANJA_ANCHO / 2, FRANJA_ALTO, 0.0025
    prof = [(-W, -0.002), (-W, H - bev), (-W + bev, H), (W - bev, H), (W, H - bev), (W, -0.002)]
    return sweep(C + n * R, n, b, prof, closed=False)


def lathe(profile, origin, axis, segs):
    axis = unit(np.asarray(axis, float))
    e1 = unit(np.cross(axis, [0, 0, 1.0] if abs(axis[2]) < 0.9 else [1.0, 0, 0]))
    e2 = np.cross(axis, e1)
    pr = np.asarray(profile, float)
    ph = np.linspace(0, 2 * math.pi, segs, endpoint=False)[:, None, None]
    v = origin + axis * pr[None, :, 1, None] + (e1 * np.cos(ph) + e2 * np.sin(ph)) * pr[None, :, 0, None]
    return orient_closed(v.reshape(-1, 3), faces(segs, len(pr), True, True))


def neck_ring():
    yb, yt, ro, ri = Y_BOT, Y_TOP, RO, RI
    prof = [(ri, yb), (ro - 0.002, yb), (ro, yb + 0.002), (ro, yb + 0.012), (ro - 0.0015, yb + 0.0135),
            (ro - 0.0015, yb + 0.0155), (ro, yb + 0.017), (ro, yt - 0.004), (ro - 0.003, yt - 0.002),
            (ro - 0.003, yt + 0.006), (ri, yt + 0.006)]
    return lathe([(r, y - C[1]) for r, y in prof], C, [0, 1, 0], 96)


def ear_disc(side):
    prof = [(0.0005, -0.008), (0.034, -0.008), (0.034, 0.009), (0.032, 0.012), (0.027, 0.012), (0.026, 0.014),
            (0.026, 0.016), (0.024, 0.018), (0.0005, 0.018)]
    n = unit(sph(side * OREJERA_AZ, OREJERA_EL, 1.0) - C)
    return lathe(prof, C + n * R, n, 48)


def frame_tube():
    """Marco de metal por dentro del borde de la abertura."""
    az, el = ABERTURA.path(160, 0.97)
    p = sph(az, el, R - GROSOR / 2)
    n = unit(p - C)
    b = unit(np.cross(n, np.roll(p, -1, 0) - np.roll(p, 1, 0)))
    ph = np.linspace(0, 2 * math.pi, 8, endpoint=False)
    prof = [(0.0028 * math.cos(t), 0.0028 * math.sin(t)) for t in ph]
    return sweep(p, n, b, prof, closed=True)


def box(center, half, ex, ey, ez):
    """Caja con vértices propios por cara (aristas vivas)."""
    ax = [np.asarray(x, float) for x in (ex, ey, ez)]
    v, f = [], []
    for k in range(3):
        for s in (-1, 1):
            u, w = ax[(k + 1) % 3] * half[(k + 1) % 3], ax[(k + 2) % 3] * half[(k + 2) % 3]
            c = center + s * ax[k] * half[k]
            q = [c - u - w, c + u - w, c + u + w, c - u + w]
            if np.dot(np.cross(q[1] - q[0], q[2] - q[0]), s * ax[k]) < 0:
                q = q[::-1]
            base = len(v)
            v += q
            f += [(base, base + 1, base + 2), (base, base + 2, base + 3)]
    return np.array(v), np.array(f)


def latch():
    z = C[2] + RO
    yc = (Y_BOT + Y_TOP) / 2 - 0.003
    ex, ey, ez = [1.0, 0, 0], [0, 1.0, 0], [0, 0, 1.0]
    return [box(np.array([0, yc, z + 0.003]), [0.020, 0.008, 0.004], ex, ey, ez),
            box(np.array([0, yc, z + 0.0075]), [0.014, 0.005, 0.0015], ex, ey, ez)]


def rivet(p, n, r=0.0028, h=0.0018):
    prof = [(0.0002, -0.001), (r, -0.001), (r, 0)] + \
           [(r * math.cos(t), h * math.sin(t)) for t in np.radians([25, 50, 70])] + [(0.0002, h)]
    return lathe(prof, p, n, 10)


def rivets():
    out = []
    for k in range(10):                                   # anillo (el cierre va delante, en az 0)
        a = D(18 + 36 * k)
        n = np.array([math.sin(a), 0, math.cos(a)])
        out.append(rivet(np.array([0, Y_BOT + 0.0245, C[2]]) + n * RO, n))
    for s in (-1, 1):
        for az, el, r in [(ABERTURA_AW + D(5), ABERTURA.e0 - ABERTURA.eh + D(5), R),       # esquinas de abajo
                          (D(70), None, R + FRANJA_ALTO)]:                                  # sobre la franja
            if el is None:
                el = OREJERA_EL + (FRANJA_TOP - OREJERA_EL) * math.cos(az / OREJERA_AZ * math.pi / 2)
            n = unit(sph(s * az, el, 1.0) - C)
            out.append(rivet(C + n * r, n))
    return out


# ---------------- formas: el casco se estira con la caja de la cabeza ----------------
def shape_fields():
    """Por forma: escala y desplazamiento por ejes de la caja de la cabeza (media de los extremos) y lo que sube o baja
    la piel bajo el anillo."""
    head = np.where(HW > 0.5)[0]
    ext = []
    for k in range(3):
        o = head[np.argsort(P0[head, k])]
        nn = max(5, len(o) * 3 // 100)
        ext.append((o[:nn], o[-nn:]))
    lo_p = np.array([P0[lo, k].mean() for k, (lo, hi) in enumerate(ext)])
    hi_p = np.array([P0[hi, k].mean() for k, (lo, hi) in enumerate(ext)])
    out = {}
    for name, d in B["targets"].items():
        dlo = np.array([d[lo, k].mean() for k, (lo, hi) in enumerate(ext)])
        dhi = np.array([d[hi, k].mean() for k, (lo, hi) in enumerate(ext)])
        out[name] = ((dhi - dlo) / (hi_p - lo_p), (dhi + dlo) / 2, (hi_p + lo_p) / 2, float(d[SHOULDER, 1].mean()))
    return out


def deltas(pos, field):
    s, t, c, dy = field
    d = s * (pos - c) + t
    w = np.clip((pos[:, 1] - Y_BOT) / (C[1] - Y_BOT), 0, 1)
    w = w * w * (3 - 2 * w)
    d[:, 1] = w * d[:, 1] + (1 - w) * dy
    return d.astype(np.float32)


# ---------------- .glb ----------------
def vertex_normals(v, f):
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    n = np.zeros_like(v)
    for k in range(3):
        np.add.at(n, f[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def write_glb(path, pos, nrm, tris, targets, name):
    rig, rig_buf = glb.read(ROOT / "godot/packs/base/tights.glb")
    head = glb.joint_names(rig).index("Head")
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

    n = len(pos)
    uv = np.stack([np.arctan2(pos[:, 0], pos[:, 2] - C[2]) / (2 * math.pi) + 0.5, pos[:, 1] - pos[:, 1].min()], 1)
    attrs = {
        "POSITION": add(pos.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": add(nrm.astype(np.float32), 5126, "VEC3", 34962),
        "TEXCOORD_0": add(uv.astype(np.float32), 5126, "VEC2", 34962),
        "JOINTS_0": add(np.tile(np.array([head, 0, 0, 0], np.uint16), (n, 1)), 5123, "VEC4", 34962),
        "WEIGHTS_0": add(np.tile(np.array([1, 0, 0, 0], np.float32), (n, 1)), 5126, "VEC4", 34962),
    }
    names = list(targets)
    tg = [{"POSITION": add(targets[k], 5126, "VEC3", 34962, True)} for k in names]
    ind = add(tris.astype(np.uint32).ravel(), 5125, "SCALAR", 34963)
    ibm_acc = add(ibm.reshape(-1, 16), 5126, "MAT4")
    doc = {
        "asset": {"version": "2.0", "generator": "GameMolde generar_casco.py"},
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


def card(pid, nombre, sha, color, ranura):
    return {"id": pid, "nombre": nombre, "archivo": pid + ".glb", "sha256": sha,
            "tipo": "accesorio", "ranura": ranura, "especies": ["humana"], "colores": ["principal"],
            "color": color, "sigue_al_cuerpo": True, "fisica": [], "miniatura": "",
            "anclaje": {"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]}}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    carcasa, metal, forro, cristal = Mesh(), Mesh(), Mesh(), Mesh()
    carcasa.add(shell()); carcasa.add(brow_band())
    metal.add(neck_ring()); metal.add(ear_disc(1)); metal.add(ear_disc(-1)); metal.add(frame_tube())
    for part in latch() + rivets():
        metal.add(part)
    forro.add(padding())
    cristal.add(visor())
    pieces = [("casco_astronauta", "Casco de astronauta", carcasa, [0.86, 0.85, 0.81], "pelo"),
              ("casco_astronauta_metal", "Casco de astronauta: metal", metal, [0.56, 0.57, 0.6], "accesorio"),
              ("casco_astronauta_acolchado", "Casco de astronauta: acolchado", forro, [0.2, 0.2, 0.22], "accesorio"),
              ("casco_astronauta_visor", "Casco de astronauta: visor (espejo)", cristal, [0.09, 0.1, 0.13], "accesorio")]
    fields = shape_fields()
    shell_v = carcasa.arrays()[0]
    names = [k for k, fl in fields.items() if np.abs(deltas(shell_v, fl)).max() > FORMA_MIN]
    print("MEDIDA cabeza: esfera de %.1f cm de radio, centro y=%.3f z=%.3f; casco: %.1f cm de radio" % (
        R_HEAD * 100, C[1], C[2], R * 100))
    print("MEDIDA anillo: radio %.1f-%.1f cm, de y=%.3f a %.3f; formas: %d de %d" % (
        RI * 100, RO * 100, Y_BOT, Y_TOP, len(names), len(fields)))
    cards = []
    for pid, nombre, m, color, ranura in pieces:
        v, f = m.arrays()
        sha = write_glb(OUT / (pid + ".glb"), v, vertex_normals(v, f), f, {k: deltas(v, fields[k]) for k in names}, pid)
        print("MEDIDA %s: %d vértices, %d triángulos, %.2f MB" % (
            pid, len(v), len(f), (OUT / (pid + ".glb")).stat().st_size / 1e6))
        cards.append(card(pid, nombre, sha, color, ranura))
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_cascos", "nombre": "Cascos (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
