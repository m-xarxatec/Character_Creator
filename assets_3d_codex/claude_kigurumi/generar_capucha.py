"""Capucha del kigurumi de conejito: parte del pijama (no es una pieza aparte), con cordones y pompones.

No se ejecuta sola: generar_kigurumi.py añade estas partes al pijama. La pieza lleva «cubre: ["pelo"]» (quita el peinado).
Capucha: nace del borde del cuello del pijama (desde las esquinas de la V y por detrás) y envuelve la cabeza sobre una
envolvente redonda del cráneo (+3,5 cm; detrás, más). Abierta: no ciñe el cuello; por los lados la abertura sigue a la
cremallera y arriba se cierra en arco sobre la frente, a la altura de las cejas. Sin orejas (las quitó el responsable).
Cordones: desde el borde de la capucha, junto al cuello, hasta un pompón por delante del pijama.
"""
import math
import numpy as np
from scipy.spatial import cKDTree

import generar_sudadera as sud
import generar_traje as tr

# --- medidas (metros) ---
CENTER = np.array([0.0, 1.545, 0.035])                # centro de la cabeza
OFF_HOOD, OFF_BACK = 0.035, 0.025                     # holgura de la capucha y extra detrás
NA, NE, E_MAX = 72, 24, math.radians(86)              # rejilla: meridianos (vuelta entera), filas y hasta dónde sube
E_ARCH, E_BROW = math.radians(4), math.radians(20)    # la abertura empieza a cerrarse en E_ARCH y acaba en las cejas
CORD_R, POM_R, Y_POM = 0.0028, 0.024, 1.20

P0 = sud.P0
SKULL = P0[sud.main_bone == "Head"] - CENTER


def azimuth(p):
    return np.arctan2(p[:, 0], p[:, 2] - CENTER[2])                         # 0 delante, ±π detrás


def elevation(p):
    d = p - CENTER
    return np.arctan2(d[:, 1], np.hypot(d[:, 0], d[:, 2]))


def reach(u, cone=math.radians(28)):
    """Lo más lejos que llega el cráneo en cada dirección u (cono de 28°): envolvente redonda, sin las orejas."""
    sd = SKULL / np.linalg.norm(SKULL, axis=1, keepdims=True)
    cos = u @ sd.T
    return np.where(cos > math.cos(cone), (SKULL @ u.T).T, 0).max(1)


def hood_grid(neck_arc):
    """Rejilla cerrada (vuelta entera × filas) de la fila 0 (borde del cuello; delante, rellenado entre las esquinas
    de la V: lo quita el corte de la cara) hasta casi lo alto, más un vértice arriba."""
    az = np.mod(azimuth(neck_arc), 2 * np.pi)
    o = np.argsort(az)
    a = np.linspace(0, 2 * np.pi, NA, endpoint=False)
    neck = np.stack([np.interp(a, az[o], neck_arc[o, k], period=2 * np.pi) for k in range(3)], 1)
    d0 = neck - CENTER
    e0 = np.arctan2(d0[:, 1], np.hypot(d0[:, 0], d0[:, 2]))
    rows = [neck]
    for k in range(1, NE):
        e = e0 + (E_MAX - e0) * k / (NE - 1)
        u = np.stack([np.sin(a) * np.cos(e), np.sin(e), np.cos(a) * np.cos(e)], 1)
        back = np.clip(-np.cos(a), 0, 1) * np.clip(e / 0.6, 0, 1)
        w = np.clip((e - e0) / (-e0 + 0.15), 0, 1)
        w = w * w * (3 - 2 * w)
        r = np.linalg.norm(d0, axis=1) * (1 - w) + (reach(u) + OFF_HOOD + OFF_BACK * back) * w
        rows.append(CENTER + u * r[:, None])
    G = np.stack(rows, 1)                                                     # (NA, NE, 3)
    top = G[:, -1].mean(0) + np.array([0, 0.004, 0])
    v = np.concatenate([G.reshape(-1, 3), [top]])
    j, i = np.meshgrid(np.arange(NA), np.arange(NE - 1), indexing="ij")
    a_, b_ = j * NE + i, j * NE + i + 1
    c_, d_ = ((j + 1) % NA) * NE + i, ((j + 1) % NA) * NE + i + 1
    f = np.concatenate([np.stack([a_, c_, b_], -1).reshape(-1, 3), np.stack([b_, c_, d_], -1).reshape(-1, 3)])
    jj = np.arange(NA)
    f = np.concatenate([f, np.stack([jj * NE + NE - 1, ((jj + 1) % NA) * NE + NE - 1, np.full(NA, len(v) - 1)], -1)])
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    if np.mean(np.einsum("ij,ij->i", fn, v[f].mean(1) - CENTER)) < 0:
        f = f[:, ::-1]
    fixed = np.zeros(len(v), bool)
    fixed[np.arange(NA) * NE] = True                                          # el borde del cuello no se mueve
    return sud.taubin(v, f, fixed, 8), f


def hood(shell, neck_loop):
    ring = shell[neck_loop]
    arc = ring[ring[:, 1] >= sud.neck_plane_y(ring[:, 2]) - 0.01]             # el borde del cuello, sin la V
    a_c = np.abs(azimuth(arc)).min()                                          # esquinas de la V
    v, f = hood_grid(arc)
    # abertura de la cara: |acimut| < A(elevación); A = a_c abajo y se cierra en arco hasta las cejas
    e = elevation(v)
    s = np.clip((e - E_ARCH) / (E_BROW - E_ARCH), 0, 1)
    A = a_c * np.sqrt(np.clip(1 - s ** 2, 0, 1)) - 1e-3 * (s >= 1)
    v, f = tr.clip(v, f, A - np.abs(azimuth(v)))
    return v, f, a_c


# ---------------- cordones ----------------
def closed_tube(rings):
    n, m = rings.shape[:2]
    v, f = rings.reshape(-1, 3), tr.ring_faces(n, m, False)
    i = np.arange(m)
    c0, c1 = len(v), len(v) + 1
    v = np.concatenate([v, [rings[0].mean(0), rings[-1].mean(0)]])
    f = np.concatenate([f, np.stack([np.full(m, c0), i, (i + 1) % m], -1),
                        np.stack([np.full(m, c1), (n - 1) * m + (i + 1) % m, (n - 1) * m + i], -1)])
    return tr.orient_closed(v, f)


def sphere(c, r, bumps=0.0):
    lat = np.linspace(-np.pi / 2 + 0.25, np.pi / 2 - 0.25, 10)
    lon = np.linspace(0, 2 * np.pi, 18, endpoint=False)
    rr = r * (1 + bumps * np.sin(7 * lon)[None, :] * np.cos(5 * lat)[:, None])
    rings = c + rr[..., None] * np.stack([np.cos(lat)[:, None] * np.cos(lon)[None, :], np.sin(lat)[:, None] *
                                          np.ones_like(lon)[None, :], np.cos(lat)[:, None] * np.sin(lon)[None, :]], -1)
    return closed_tube(rings)


def cords(hood_v, hood_f, suit_v):
    """Desde el borde de la capucha (unos 3 cm sobre la esquina de la V) hasta un pompón, por delante del pijama."""
    bnd = np.unique(np.concatenate(sud.boundary_loops(hood_f)))
    front = suit_v[suit_v[:, 2] > 0.0]
    kd = cKDTree(front[:, :2])
    parts = []
    for s in (1, -1):
        side = bnd[np.sign(hood_v[bnd, 0]) == s]
        low = hood_v[side, 1].min()
        cand = side[(hood_v[side, 1] > low + 0.02) & (hood_v[side, 1] < low + 0.05)]
        start = hood_v[cand[np.argmax(hood_v[cand, 2])]]
        ys = np.linspace(start[1], Y_POM + POM_R, 14)
        xs = np.linspace(start[0], s * 0.085, 14)
        pts = []
        for x, y in zip(xs, ys):
            _, i = kd.query([x, y], k=6)
            pts.append([x, y, max(front[i, 2].max() + 0.008, start[2])])
        pts = np.array(pts)
        prof = [(CORD_R * math.cos(a), CORD_R * math.sin(a)) for a in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
        parts.append((tr.sweep(pts, np.tile([0, 0, 1.0], (len(pts), 1)), prof), "kigurumi"))
        parts.append((sphere(pts[-1] + np.array([0, -POM_R * 0.9, 0.004]), POM_R, 0.10), "pompones"))
    return parts


# ---------------- todo ----------------
def parts(shell, neck_loop):
    """Partes de la capucha para añadir al pijama: lista de ((v, f), zona, máscara de piel para pesos y formas)."""
    v, f, a_c = hood(shell, neck_loop)
    hn = sud.vertex_normals(v, f)
    no_arm = (sud.arm_w < 0.2) & ~sud.hand_like
    chest = np.isin(sud.main_bone, ["UpperChest", "Chest", "Neck"]) & (sud.arm_w < 0.3)
    front = v[(np.abs(azimuth(v)) < 0.3)]
    print("MEDIDA capucha: esquinas de la V a %.0f°; borde de delante a y = %.3f m" % (
        math.degrees(a_c), front[:, 1].min()))
    out = [((v, f), "kigurumi", no_arm), ((v - hn * 0.005, f[:, ::-1]), "kigurumi", no_arm)]
    out += [(vf, zone, chest) for vf, zone in cords(v, f, shell)]
    return out
