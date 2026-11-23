"""Gorra plana de 6 paneles con monograma GM, ajustada a la cabeza de la humana de GameMolde.

Uso:  python generar_gorra.py            (holgada: deja sitio al pelo)
      python generar_gorra.py ajustada   (sin pelo o rapado)
Lee godot/datos/humana/cuerpo.glb (cabeza y formas) y godot/packs/base/tights.glb (esqueleto) y escribe
sus .glb en packs/claude_gorras/ y añade o actualiza sus fichas en pack.json (las de la otra variante se quedan).

- Va a la ranura «accesorio»: convive con cualquier peinado.
- La copa deja HOLGURA_* sobre el cuero cabelludo para el pelo (medido: el 90 % de los peinados abulta 1-3 cm).
- 100 % del hueso Head (sigue pose y tamaño de cabeza) y lleva las formas del cuerpo que mueven el cráneo.
- Un solo color (el shader de piezas pinta un color): costuras, ojales, botón, GM y puntadas son relieve.
"""
import hashlib, json, math, struct, sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import glb

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / "packs" / "claude_gorras"
AJUSTADA = "ajustada" in sys.argv[1:]   # variante para sin pelo o rapado: casi pegada al cráneo

# --- medidas (metros) ---
K_TILT = 0.30                 # plano de la banda: y = Y0 + K_TILT·z (más alta delante, como se lleva)
Y0 = 1.565
HOLGURA_BANDA, HOLGURA_ARRIBA = (0.004, 0.006) if AJUSTADA else (0.018, 0.028)
GROSOR = 0.003                # tela + estructura
VISERA_LARGO, VISERA_GROSOR, VISERA_CAIDA = 0.070, 0.004, math.radians(20)
NA, NB = 120, 30              # resolución de la copa: alrededor y hacia arriba
COSTURAS = [math.radians(60 * i) for i in range(6)]

up = np.array([0, 1, -K_TILT]) / math.hypot(1, K_TILT)
fw = np.array([0, K_TILT, 1]) / math.hypot(1, K_TILT)
ex = np.array([1.0, 0, 0])


# ---------------- cabeza ----------------
body, body_buf = glb.read(ROOT / "godot/datos/humana/cuerpo.glb")
B = glb.mesh_data(body, body_buf)
H_BODY = glb.joint_names(body).index("Head")
head_w = (B["WEIGHTS_0"] * (B["JOINTS_0"] == H_BODY)).sum(1)
skin_idx = np.where(head_w > 0.5)[0]
# nube densa: puntos repartidos sobre los triángulos de la cabeza (la malla tiene pocos vértices por zona)
_tri = B["indices"].reshape(-1, 3)
_tri = _tri[(head_w[_tri] > 0.5).all(1)]
_bary = np.array([(i, j, 6 - i - j) for i in range(7) for j in range(7 - i)], float) / 6
skin = np.einsum("bk,tkc->tbc", _bary, B["POSITION"][_tri]).reshape(-1, 3)
ZC = 0.048   # centro delante-detrás del cráneo a la altura de la banda (frente 0,144; nuca -0,048)
ORIGIN = np.array([0, Y0 + K_TILT * ZC, ZC])


def to_local(p):
    d = p - ORIGIN
    return np.stack([d @ ex, d @ up, d @ fw], axis=-1)


def to_world(q):
    return ORIGIN + q[..., 0:1] * ex + q[..., 1:2] * up + q[..., 2:3] * fw


sl = to_local(skin)
s_r = np.hypot(sl[:, 0], sl[:, 2])
s_a = np.arctan2(sl[:, 0], sl[:, 2])
s_h = sl[:, 1]


def smooth_periodic(values, harmonics=6):
    f = np.fft.rfft(values)
    f[harmonics + 1:] = 0
    return np.fft.irfft(f, len(values))


# radio de la banda: lo que ocupa la cabeza justo encima del plano + holgura, suavizado y simétrico
bins = np.linspace(-math.pi, math.pi, 73)
band_r = np.zeros(72)
for i in range(72):
    m = (s_a >= bins[i]) & (s_a < bins[i + 1]) & (s_h > -0.01) & (s_h < 0.03)
    band_r[i] = s_r[m].max() + HOLGURA_BANDA
band_r = np.maximum(band_r, band_r[::-1])   # simetría izquierda-derecha
band_r = smooth_periodic(band_r, 4) + 0.002
band_centers = (bins[:-1] + bins[1:]) / 2


def r_band(a):
    a = (np.asarray(a) + math.pi) % (2 * math.pi) - math.pi
    return np.interp(a, band_centers, band_r, period=2 * math.pi)


def p_of(a):
    """Exponente de la superelipse: delante más recto (copa estructurada), detrás más redondo."""
    return 2.4 + 0.9 * (np.cos(a) + 1) / 2


def fits(Hc):
    p = p_of(s_a)
    m = s_h > 0
    hh = np.clip(s_h[m] / Hc, 0, 1)
    r = r_band(s_a[m]) * (1 - hh ** p[m]) ** (1 / p[m])
    need = s_r[m] + HOLGURA_BANDA + (HOLGURA_ARRIBA - HOLGURA_BANDA) * hh
    return np.all(r >= need) and s_h.max() + HOLGURA_ARRIBA <= Hc


lo, hi = 0.05, 0.25
for _ in range(40):
    mid = (lo + hi) / 2
    lo, hi = (lo, mid) if fits(mid) else (mid, hi)
H_CROWN = hi * 1.01


# ---------------- copa ----------------
def crown_point(a, h, inset=0.0):
    """Punto local de la copa a la altura h (0 = banda) y ángulo a (0 = delante, + = izquierda del personaje)."""
    p = p_of(a)
    Hc = H_CROWN - inset
    hh = np.clip(h / Hc, 0, 1)
    r = (r_band(a) - inset) * (1 - hh ** p) ** (1 / p)
    return np.stack([r * np.sin(a), np.minimum(h, Hc), r * np.cos(a)], axis=-1)


def crown_phi(a, phi, inset=0.0):
    """Igual, con el parámetro de superelipse phi (reparte mejor los anillos cerca de la cima)."""
    p = p_of(a)
    Hc = H_CROWN - inset
    r = (r_band(a) - inset) * np.cos(phi) ** (2 / p)
    return np.stack([r * np.sin(a), Hc * np.sin(phi) ** (2 / p), r * np.cos(a)], axis=-1)


def phi_of_h(a, h, inset=0.0):
    p = p_of(a)
    return np.arcsin(np.clip(h / (H_CROWN - inset), 0, 1) ** (p / 2))


def seam_groove(a, h):
    d = np.min([np.abs((a - s + math.pi) % (2 * math.pi) - math.pi) for s in COSTURAS], axis=0)
    r = r_band(a)
    return 0.0011 * np.exp(-((d * r) / 0.0022) ** 2)


# abertura trasera (cierre) : de STRAP a ARCH(a) en el panel de atrás
STRAP_H = 0.013
ARCH_W, ARCH_H = math.radians(21), 0.040


def arch_top(a):
    da = np.abs((a - math.pi + math.pi) % (2 * math.pi) - math.pi)
    t = np.clip(1 - (da / ARCH_W) ** 2, 0, 1)
    return STRAP_H + (ARCH_H - STRAP_H) * np.sqrt(t)


class Mesh:
    def __init__(self):
        self.v, self.f = [], []

    def add(self, verts, faces):
        base = sum(len(x) for x in self.v)
        self.v.append(np.asarray(verts, float).reshape(-1, 3))
        self.f.append(np.asarray(faces, int).reshape(-1, 3) + base)

    def arrays(self):
        return np.concatenate(self.v), np.concatenate(self.f)


def weld(verts, faces, eps=1e-7):
    keys = np.round(verts / eps).astype(np.int64)
    _, first, inv = np.unique(keys, axis=0, return_index=True, return_inverse=True)
    faces = inv.ravel()[faces]
    good = (faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) & (faces[:, 0] != faces[:, 2])
    return verts[first], faces[good]


def grid_faces(rows, cols, skip_rows=(), wrap=True, flip=False):
    out = []
    cc = cols if wrap else cols - 1
    for j in range(rows - 1):
        if j in skip_rows:
            continue
        for i in range(cc):
            a, b = j * cols + i, j * cols + (i + 1) % cols
            c, d = a + cols, b + cols
            out += [(a, c, b), (b, c, d)] if not flip else [(a, b, c), (b, d, c)]
    return out


def crown_shell(inset, flip):
    a = np.linspace(-math.pi, math.pi, NA, endpoint=False)
    rows = []
    hs_low = [0.0, STRAP_H / 2, STRAP_H]
    for h in hs_low:
        rows.append(crown_point(a, np.full_like(a, h), inset))
    top = arch_top(a)
    phi0 = phi_of_h(a, top, inset)
    phi_max = math.radians(89.0)
    for t in np.linspace(0, 1, NB):
        rows.append(crown_phi(a, phi0 + (phi_max - phi0) * t, inset))
    pts = np.stack(rows)                       # (filas, NA, 3)
    hh = np.clip(pts[..., 1] / (H_CROWN - inset), 0, 1)
    if inset == 0:                             # costuras hundidas (solo por fuera)
        g = seam_groove(a, None)[None, :] * (1 - hh ** 4)
        rad = pts.copy(); rad[..., 1] = 0
        n = np.linalg.norm(rad, axis=-1, keepdims=True)
        pts = pts - rad / np.maximum(n, 1e-9) * g[..., None]
    nr = pts.shape[0]
    verts = list(pts.reshape(-1, 3))
    faces = grid_faces(nr, NA, skip_rows=(2,), flip=flip)
    pole = len(verts)
    verts.append([0, H_CROWN - inset, 0])
    last = (nr - 1) * NA
    for i in range(NA):
        a_, b_ = last + i, last + (i + 1) % NA
        faces.append((a_, b_, pole) if not flip else (a_, pole, b_))
    return weld(np.array(verts), np.array(faces))


def boundary_loops(faces):
    edges = {}
    for f in faces:
        for k in range(3):
            e = (f[k], f[(k + 1) % 3])
            edges[e] = edges.get(e, 0) + 1
    return [e for e in edges if (e[1], e[0]) not in edges]


# sin scipy: vecino más cercano por fuerza bruta en bloques
def nearest_idx(src, dst):
    out = np.empty(len(src), int)
    for s in range(0, len(src), 2048):
        d = ((src[s:s + 2048, None, :] - dst[None, :, :]) ** 2).sum(-1)
        out[s:s + 2048] = d.argmin(1)
    return out


def build_crown(m):
    vo, fo = crown_shell(0.0, flip=False)
    vi, fi = crown_shell(GROSOR, flip=True)
    base_o = sum(len(x) for x in m.v)
    m.add(vo, fo)
    base_i = sum(len(x) for x in m.v)
    m.add(vi, fi)
    bo = boundary_loops(fo)
    bi_verts = np.unique(np.array(boundary_loops(fi)).ravel())
    near = {}
    ids = np.unique(np.array(bo).ravel())
    idx = nearest_idx(vo[ids], vi[bi_verts])
    for k, v in zip(ids, idx):
        near[k] = bi_verts[v]
    faces = []
    for a, b in bo:   # arista de fuera a→b (abierta); dentro, la cara va al revés
        ia, ib = near[a], near[b]
        faces.append((base_o + a, base_i + ia, base_o + b))
        if ia != ib:
            faces.append((base_o + b, base_i + ia, base_i + ib))
    m.f.append(np.array(faces))
    return vo


# ---------------- visera ----------------
VISERA_A = math.radians(84)


def build_visor(m):
    ns, nt = 72, 22
    a = np.linspace(-VISERA_A, VISERA_A, ns)
    rb = r_band(a) - GROSOR * 1.5
    inner = np.stack([rb * np.sin(a), np.zeros_like(a), rb * np.cos(a)], -1)
    # dirección hacia fuera: normal de la curva de la banda, algo llevada hacia delante
    tang = np.gradient(inner, axis=0)
    nrm = np.stack([tang[:, 2], np.zeros(ns), -tang[:, 0]], -1)
    nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
    nrm = np.where((nrm * inner).sum(1, keepdims=True) < 0, -nrm, nrm)
    nrm = nrm * 0.35 + np.array([0, 0, 1.0])
    nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
    ext = VISERA_LARGO * np.clip(np.cos(a / VISERA_A * math.pi / 2), 0, 1) ** 0.7 + GROSOR * 1.5
    t = np.linspace(0, 1, nt)
    d = ext[None, :] * t[:, None]                       # distancia hacia fuera (nt, ns)
    pts = inner[None] + nrm[None] * d[..., None]
    drop = np.tan(VISERA_CAIDA)
    top_y = 0.0035 - d * drop
    # puntadas: surcos paralelos al borde (5 líneas a 5, 10, 15, 20, 25 mm del borde)
    from_edge = ext[None, :] - d
    groove = sum(0.00035 * np.exp(-((from_edge - k * 0.005) / 0.0007) ** 2) for k in range(1, 6))
    groove *= (ext[None, :] > 0.03)
    top = pts.copy(); top[..., 1] = top_y - groove
    bot = pts.copy(); bot[..., 1] = top_y - VISERA_GROSOR
    # borde redondeado: medio círculo de la cara de arriba a la de abajo
    edge = []
    nr_out = nrm
    for k in range(1, 6):
        th = math.pi * k / 6
        e = pts[-1] + nr_out * (VISERA_GROSOR / 2 * math.sin(th))
        e = e.copy(); e[:, 1] = top_y[-1] - VISERA_GROSOR / 2 * (1 - math.cos(th))
        edge.append(e)
    rows = list(top) + edge + list(bot[::-1])
    grid = np.stack(rows)
    nrows = grid.shape[0]
    faces = grid_faces(nrows, ns, wrap=False)
    m.add(grid.reshape(-1, 3), faces)
    # cierre interior (queda dentro de la copa) y extremos
    base = sum(len(x) for x in m.v) - nrows * ns
    f2 = []
    first_top, first_bot = 0, (nrows - 1) * ns
    for i in range(ns - 1):
        a_, b_ = base + first_top + i, base + first_top + i + 1
        c_, d_ = base + first_bot + i, base + first_bot + i + 1
        f2 += [(a_, b_, c_), (b_, d_, c_)]
    for i in (0, ns - 1):
        col = [base + j * ns + i for j in range(nrows)]
        for j in range(1, nrows - 1):
            f2.append((col[0], col[j], col[j + 1]) if i == 0 else (col[0], col[j + 1], col[j]))
    m.f.append(np.array(f2))


# ---------------- detalles: botón, ojales, broches, GM ----------------
def surface_frame(a, h):
    p = crown_point(np.array([a]), np.array([h]))[0]
    e = 1e-4
    pa = crown_point(np.array([a + e]), np.array([h]))[0] - crown_point(np.array([a - e]), np.array([h]))[0]
    ph = crown_point(np.array([a]), np.array([h + e]))[0] - crown_point(np.array([a]), np.array([h - e]))[0]
    n = np.cross(pa, ph)
    n /= np.linalg.norm(n)
    if n @ np.array([p[0], 0, p[2]]) < 0:
        n = -n
    return p, n, pa / np.linalg.norm(pa), ph / np.linalg.norm(ph)


def dome(m, center, normal, radius, height, rings=6, segs=24):
    t1 = np.cross(normal, [0, 0, 1] if abs(normal[2]) < 0.9 else [1, 0, 0]); t1 /= np.linalg.norm(t1)
    t2 = np.cross(normal, t1)
    verts, faces = [], []
    for j in range(rings + 1):
        th = math.pi / 2 * j / rings
        rr, hh = radius * math.cos(th), height * math.sin(th) - height * 0.25
        for i in range(segs):
            ph = 2 * math.pi * i / segs
            verts.append(center + normal * hh + (t1 * math.cos(ph) + t2 * math.sin(ph)) * rr)
    faces = grid_faces(rings + 1, segs)
    m.add(verts, faces)


def torus(m, center, normal, R, r, segs=20, ring=8):
    t1 = np.cross(normal, [0, 1, 0] if abs(normal[1]) < 0.9 else [1, 0, 0]); t1 /= np.linalg.norm(t1)
    t2 = np.cross(normal, t1)
    verts = []
    for j in range(ring):
        th = 2 * math.pi * j / ring
        for i in range(segs):
            ph = 2 * math.pi * i / segs
            radial = t1 * math.cos(ph) + t2 * math.sin(ph)
            verts.append(center + radial * (R + r * math.cos(th)) + normal * (r * math.sin(th)))
    rows = [verts[j * segs:(j + 1) * segs] for j in range(ring)] + [verts[:segs]]
    m.add(np.array(rows).reshape(-1, 3), grid_faces(ring + 1, segs, flip=True))


def tube(m, path_ah, width, height, segs=8):
    """Trazo de bordado: media caña sobre la copa a lo largo de path_ah [(a, h)], con tapas."""
    verts = []
    frames = [surface_frame(a, h) for a, h in path_ah]
    P = np.array([f[0] for f in frames]); N = np.array([f[1] for f in frames])
    T = np.gradient(P, axis=0); T /= np.linalg.norm(T, axis=1, keepdims=True)
    for p, n, t in zip(P, N, T):
        b = np.cross(n, t); b /= np.linalg.norm(b)
        for k in range(segs + 1):
            th = math.pi * k / segs
            verts.append(p + b * (width / 2) * math.cos(th) + n * (height * math.sin(th) - 0.0004))
    rows = len(P)
    faces = grid_faces(rows, segs + 1, wrap=False, flip=True)
    base = len(verts)
    verts += [P[0] - N[0] * 0.0004, P[-1] - N[-1] * 0.0004]
    for k in range(segs):
        faces.append((base, k, k + 1))
        o = (rows - 1) * (segs + 1)
        faces.append((base + 1, o + k + 1, o + k))
    m.add(verts, faces)


def monogram(m):
    """GM en relieve delante, centrado en la costura frontal. Unidades de letra: alto 1."""
    L, HC, R0 = 0.044, 0.026, float(r_band(0.0))
    strokes = []
    # G
    cx, rx, ry = -0.55, 0.42, 0.5
    ang = np.radians(np.linspace(48, 345, 40))
    strokes.append([(cx + rx * math.cos(t), 0.5 + ry * math.sin(t)) for t in ang])
    xr = cx + rx * math.cos(math.radians(345))
    strokes.append([(xr, 0.5 + ry * math.sin(math.radians(345))), (xr, 0.47)])
    strokes.append([(xr, 0.47), (cx + 0.02, 0.47)])
    # M
    mx = 0.55
    for seg in [[(mx - 0.4, 0.0), (mx - 0.4, 1.0)], [(mx - 0.4, 1.0), (mx, 0.32)],
                [(mx, 0.32), (mx + 0.4, 1.0)], [(mx + 0.4, 1.0), (mx + 0.4, 0.0)]]:
        strokes.append(seg)
    for s in strokes:
        pts = np.array(s, float)
        if len(pts) == 2:   # rectas: puntos intermedios para que se peguen a la curva de la copa
            pts = np.array([pts[0] + (pts[1] - pts[0]) * k / 12 for k in range(13)])
        # u (metros por la superficie) → ángulo; la letra se lee de frente: +x del personaje es su izquierda
        path = [((u * L) / R0, HC + w * L) for u, w in pts]
        tube(m, path, 0.0062, 0.0020)


def details(m):
    dome(m, np.array([0, H_CROWN - 0.001, 0]), np.array([0, 1.0, 0]), 0.009, 0.006)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        h = H_CROWN * 0.66
        p, n, _, _ = surface_frame(a, h)
        torus(m, p + n * 0.0003, n, 0.0028, 0.0011)
    for k in range(-3, 4):   # broches del cierre
        a = math.pi + math.radians(4.2 * k)
        p, n, _, _ = surface_frame(a, STRAP_H * 0.5)
        dome(m, p, n, 0.0022, 0.0018, rings=3, segs=12)


# ---------------- normales, formas y .glb ----------------
def vertex_normals(v, f):
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    n = np.zeros_like(v)
    for k in range(3):
        np.add.at(n, f[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def transfer_targets(cap_world):
    """Cada vértice de la gorra se mueve como la media (inversa a la distancia) de los 12 puntos más cercanos del
    cráneo por encima de la banda. Solo las formas que mueven el cráneo más de 0,3 mm."""
    crane = skin_idx[to_local(B["POSITION"][skin_idx])[:, 1] > -0.005]
    cp = B["POSITION"][crane]
    k = 12
    idx = np.empty((len(cap_world), k), int); w = np.empty((len(cap_world), k))
    for s in range(0, len(cap_world), 1024):
        d = ((cap_world[s:s + 1024, None, :] - cp[None]) ** 2).sum(-1)
        ii = np.argpartition(d, k, axis=1)[:, :k]
        dd = np.sqrt(np.take_along_axis(d, ii, 1))
        idx[s:s + 1024] = ii
        w[s:s + 1024] = 1 / (dd + 0.004) ** 2
    w /= w.sum(1, keepdims=True)
    out = {}
    for name, delta in B["targets"].items():
        dc = delta[crane]
        if np.abs(dc).max() < 0.0003:
            continue
        out[name] = (dc[idx] * w[..., None]).sum(1).astype(np.float32)
    return out


def write_glb(path, pos, nrm, faces, targets, name):
    rig, rig_buf = glb.read(ROOT / "godot/packs/base/tights.glb")
    joints = glb.joint_names(rig)
    head = joints.index("Head")
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
    uv = np.stack([np.arctan2(pos[:, 0], pos[:, 2]) / (2 * math.pi) + 0.5, pos[:, 1] - pos[:, 1].min()], 1)
    attrs = {
        "POSITION": add(pos.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": add(nrm.astype(np.float32), 5126, "VEC3", 34962),
        "TEXCOORD_0": add(uv.astype(np.float32), 5126, "VEC2", 34962),
        "JOINTS_0": add(np.tile(np.array([head, 0, 0, 0], np.uint16), (n, 1)), 5123, "VEC4", 34962),
        "WEIGHTS_0": add(np.tile(np.array([1, 0, 0, 0], np.float32), (n, 1)), 5126, "VEC4", 34962),
    }
    names = list(targets)
    tg = [{"POSITION": add(targets[k], 5126, "VEC3", 34962, True)} for k in names]
    ind = add(faces.astype(np.uint32).ravel(), 5125, "SCALAR", 34963)
    accs[ind]["count"] = faces.size
    ibm_acc = add(ibm.reshape(-1, 16), 5126, "MAT4")
    doc = {
        "asset": {"version": "2.0", "generator": "GameMolde generar_gorra.py"},
        "scene": 0, "scenes": rig["scenes"], "nodes": rig["nodes"],
        "skins": [{**rig["skins"][0], "inverseBindMatrices": ibm_acc}],
        "meshes": [{"name": name, "extras": {"targetNames": names},
                    "primitives": [{"attributes": attrs, "indices": ind, "targets": tg, "mode": 4}]}],
        "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(blob)}],
    }
    mesh_node = next(i for i, nd in enumerate(doc["nodes"]) if "mesh" in nd)
    doc["nodes"][mesh_node]["name"] = name
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    while len(blob) % 4:
        blob.append(0)
    total = 12 + 8 + len(js) + 8 + len(blob)
    data = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js \
        + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    path.write_bytes(data)
    return hashlib.sha256(data).hexdigest()


def export(name, m):
    v_local, f = m.arrays()
    v = to_world(v_local)
    sha = write_glb(OUT / (name + ".glb"), v, vertex_normals(v, f), f, transfer_targets(v), name)
    print("MEDIDA %s: %d vértices, %d triángulos, %.2f MB" % (
        name, len(v), len(f), (OUT / (name + ".glb")).stat().st_size / 1e6))
    return v, sha


def card(pid, nombre, sha, color):
    return {"id": pid, "nombre": nombre, "archivo": pid + ".glb", "sha256": sha,
            "tipo": "accesorio", "ranura": "accesorio", "especies": ["humana"], "colores": ["principal"],
            "color": color, "sigue_al_cuerpo": True, "fisica": [], "miniatura": "",
            "anclaje": {"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]}}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pid, nombre = ("gorra_plana_ajustada", "Gorra plana ajustada") if AJUSTADA else ("gorra_plana", "Gorra plana")
    cap = Mesh()
    build_crown(cap)
    build_visor(cap)
    details(cap)
    v, sha_cap = export(pid, cap)
    logo = Mesh()
    monogram(logo)
    _, sha_logo = export(pid + "_gm", logo)
    path = OUT / "pack.json"
    pack = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {
        "formato": "gamemolde-pack", "version": 1, "id": "claude_gorras", "nombre": "Gorras (pruebas)",
        "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": []}
    new = [card(pid, nombre, sha_cap, [0.106, 0.137, 0.2]),
           card(pid + "_gm", nombre + ": monograma GM", sha_logo, [0.96, 0.96, 0.96])]
    ids = {c["id"] for c in new}
    pack["piezas"] = sorted([c for c in pack["piezas"] if c["id"] not in ids] + new, key=lambda c: c["id"])
    path.write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
    print("MEDIDA copa %.1f cm de alto; gorra %.1f cm de ancho y %.1f cm de fondo" % (
        H_CROWN * 100, np.ptp(v[:, 0]) * 100, np.ptp(v[:, 2]) * 100))


if __name__ == "__main__":
    main()
