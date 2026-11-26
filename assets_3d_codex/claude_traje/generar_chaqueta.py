"""Chaqueta corta con capucha del traje rosa (plano: planos/traje_rosa_referencia.webp).

No se ejecuta sola: la llama generar_traje.py (mismo pack). Reutiliza las herramientas de la sudadera
(claude_sudadera/generar_sudadera.py): piel copiada e hinchada, con los pesos y las formas del cuerpo por índice.
Cambia: corta (detrás, a media espalda; delante sube en arco hasta encima del pecho), mangas abullonadas que se
recogen en un puño hasta la muñeca, capucha bajada más corta (deja ver la espalda) y logos en relieve: gato delante,
píxeles en el pecho izquierdo, doble flecha detrás y una estrella en cada manga.
Ranura «ropa_exterior» (sustituye a la sudadera). Zonas en COLOR_0: r = 0 chaqueta (blanca), r = 1 puños, g = 1 logos.
"""
import math, sys
from pathlib import Path
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree

sys.path.insert(0, str(Path(__file__).parents[1] / "claude_sudadera"))
import generar_sudadera as sud
import generar_traje as tr

# --- medidas (metros) ---
Y_BACK, Y_FRONT = 1.17, 1.27        # bajo: detrás recto; delante sube en arco (cos² del ángulo)
T_CUT = 0.62                        # la piel copiada del antebrazo acaba aquí (0 codo, 1 muñeca)
OFF_TORSO, OFF_SHOULDER, OFF_FORE, OFF_NECK = 0.020, 0.020, 0.042, 0.010
THICK = 0.003
CUFF_LEN, CUFF_GAP = 0.040, 0.007   # puño: largo y holgura sobre la muñeca
HOOD_DROP = 0.10
ZC = 0.02

P0, F0 = sud.P0, sud.F0
SIDES, ARM = sud.SIDES, sud.ARM
ZONES = {"chaqueta": (0, 0, 0, 1), "punos": (1, 0, 0, 1), "logos": (1, 1, 0, 1)}


def hem_y(x, z):
    a = np.arctan2(x, z - ZC)
    return Y_BACK + (Y_FRONT - Y_BACK) * np.maximum(np.cos(a), 0) ** 2


def arm_t(p, s):
    a = ARM[s]
    return (p - a["lower"]) @ a["dir"] / np.linalg.norm(a["hand"] - a["lower"])


# ---------------- 1. piel copiada ----------------
def select_region():
    torso = (P0[:, 1] >= hem_y(P0[:, 0], P0[:, 2])) & (P0[:, 1] <= sud.neck_plane_y(P0[:, 2])) & (sud.arm_w <= 0.5)
    arm = sud.arm_w > 0.5
    for s in SIDES:
        side = np.sign(P0[:, 0]) == SIDES[s]
        arm &= ~(side & (arm_t(P0, s) > T_CUT))
    keep = (torso | arm) & ~sud.hand_like & (sud.main_bone != "Head")
    faces = F0[keep[F0].all(1)]
    n = len(P0)
    adj = coo_matrix((np.ones(len(faces) * 3), (faces.ravel(), np.roll(faces, 1, 1).ravel())), (n, n))
    _, lab = connected_components(adj, directed=False)
    big = np.bincount(lab[np.unique(faces)]).argmax()
    faces = faces[lab[faces[:, 0]] == big]
    verts = np.unique(faces)
    remap = -np.ones(n, int); remap[verts] = np.arange(len(verts))
    return verts, remap[faces]


def wrist_plane(s):
    a = ARM[s]
    p0 = a["lower"] + a["dir"] * T_CUT * np.linalg.norm(a["hand"] - a["lower"])
    return lambda q: q - np.outer((q - p0) @ a["dir"], a["dir"])


def build_shell():
    idx, f = select_region()
    v = P0[idx].copy()
    kinds = {}
    for lp in sud.boundary_loops(f):
        c = v[lp].mean(0)
        if abs(c[0]) > 0.2:
            kinds["wrist_" + ("Left" if c[0] > 0 else "Right")] = lp
        elif c[1] > 1.33 and abs(c[2] - ZC) < 0.05:
            kinds["neck"] = lp
        else:
            kinds.setdefault("hem", lp)
            if len(lp) > len(kinds["hem"]):
                kinds["hem"] = lp
    assert {"wrist_Left", "wrist_Right", "neck", "hem"} <= set(kinds), list(kinds)
    planes = {"hem": lambda q: np.c_[q[:, 0], hem_y(q[:, 0], q[:, 2]), q[:, 2]],
              "neck": lambda q: np.c_[q[:, 0], sud.neck_plane_y(q[:, 2]), q[:, 2]],
              "wrist_Left": wrist_plane("Left"), "wrist_Right": wrist_plane("Right")}
    aw = sud.arm_w[idx]
    t_w = np.zeros(len(v))
    for s, a in ARM.items():
        side = np.sign(v[:, 0]) == SIDES[s]
        t = np.clip((v - a["upper"]) @ (a["hand"] - a["upper"]) / np.sum((a["hand"] - a["upper"]) ** 2), 0, 1)
        t_w[side] = t[side]
    balloon = np.clip((t_w - 0.35) / 0.45, 0, 1) ** 1.5                  # la manga se abomba en el antebrazo
    off = OFF_TORSO * (1 - aw) + aw * (OFF_SHOULDER + (OFF_FORE - OFF_SHOULDER) * balloon)
    near_neck = np.clip((sud.neck_plane_y(v[:, 2]) - v[:, 1]) / 0.06, 0, 1)
    off = OFF_NECK + (off - OFF_NECK) * near_neck
    nrm = sud.vertex_normals(v, f)
    v = v + nrm * off[:, None]
    fixed = np.zeros(len(v), bool)
    for k, lp in kinds.items():
        v[lp] = planes[k](v[lp]); fixed[lp] = True
        v = sud.smooth_loop(v, lp, 20, planes[k])
    skin0 = P0[idx]

    def keep_out(v):
        proj = np.einsum("ij,ij->i", v - skin0, nrm)
        return v + nrm * np.maximum(0.5 * off - proj, 0)[:, None]

    for _ in range(4):
        v = keep_out(sud.taubin(v, f, fixed, 10))
    for k, lp in kinds.items():
        v[lp] = planes[k](v[lp])
        v = sud.smooth_loop(v, lp, 10, planes[k])
    return idx, v, f, kinds


# ---------------- 2. puños y capucha ----------------
def sleeve_end(v, lp, s):
    """Del corte del antebrazo: la manga sigue abombada, se recoge y acaba en un puño ceñido hasta la muñeca."""
    a = ARM[s]
    axis = a["dir"]
    flen = np.linalg.norm(a["hand"] - a["lower"])
    p0 = a["lower"] + axis * T_CUT * flen
    top = sud.resample_ring(v[sud.loop_ring_order(v, lp, p0, axis)], 48)
    c0 = top.mean(0)
    d = top - c0; d -= np.outer(d @ axis, axis)
    r0 = np.linalg.norm(d, axis=1); u = d / r0[:, None]
    length = (a["hand"] - c0) @ axis
    side = np.sign(P0[:, 0]) == SIDES[s]
    wrist = P0[side & (sud.arm_w > 0.3) & (np.abs((P0 - a["hand"]) @ axis) < 0.05)]
    rel = wrist - a["hand"]; rel -= np.outer(rel @ axis, axis)
    rc = np.linalg.norm(rel, axis=1).max() + CUFF_GAP                       # radio del puño
    cuff_start = 1 - CUFF_LEN / length
    steps = [(0.0, r0), (0.25, r0 * 1.03), (cuff_start - 0.12, r0 * 0.90), (cuff_start - 0.03, rc + 0.006 + 0 * r0),
             (cuff_start, rc + 0 * r0), (1.0, rc + 0 * r0)]
    rings = [c0 + axis * (length * t) + u * np.broadcast_to(r, r0.shape)[:, None] for t, r in steps]
    return rings, 4                                                           # los anillos 4.. son el puño


def hood(v, lp):
    """Capucha bajada (como la de la sudadera, más corta: cae HOOD_DROP sobre la espalda)."""
    ring = sud.loop_ring_order(v, lp, np.array([0, 1.40, ZC]), np.array([0, 1.0, 0]))
    base = sud.resample_ring(v[ring], 72)
    c = base.mean(0)
    out = base - c; out[:, 1] = 0; out /= np.linalg.norm(out, axis=1, keepdims=True)
    back = np.clip(-out[:, 2], 0, 1) ** 1.3
    side = np.abs(out[:, 0])
    rings = []
    for k in range(15):
        t = k / 14
        h = (0.030 + 0.040 * back) * math.sin(math.pi * min(t / 0.55, 1) / 2)
        w = (0.020 + 0.070 * back + 0.020 * side) * math.sin(math.pi * t / 2)
        drop = (0.010 + HOOD_DROP * back) * max(0, (t - 0.45) / 0.55) ** 1.5
        rings.append(base + out * w[:, None] + np.c_[np.zeros(72), h - drop, np.zeros(72)])
    return np.stack(rings)


# ---------------- 3. logos en relieve ----------------
class Surface:
    """Proyecta puntos 2D (en un marco local) sobre la superficie de la chaqueta."""
    def __init__(self, v, f):
        self.v, self.n = v, sud.vertex_normals(v, f)
        self.kd = cKDTree(v)

    def frame(self, p):
        _, i = self.kd.query(p, k=6)
        n = self.n[i].mean(0); n /= np.linalg.norm(n)
        up = np.array([0, 1.0, 0]) - n * n[1]; up /= np.linalg.norm(up)
        return n, up, np.cross(up, n)

    def place(self, p, pts2d, lift):
        n, up, right = self.frame(p)
        q = p + np.outer(pts2d[:, 0], right) + np.outer(pts2d[:, 1], up)
        d, i = self.kd.query(q, k=4)
        w = 1 / (d + 1e-4); w /= w.sum(1, keepdims=True)
        sp = (self.v[i] * w[..., None]).sum(1)
        sn = (self.n[i] * w[..., None]).sum(1); sn /= np.linalg.norm(sn, axis=1, keepdims=True)
        q = q - sn * ((q - sp) * sn).sum(1)[:, None] + sn * lift
        return q, sn


def plate(surface, p, poly, lift=0.0012, h=0.0012):
    """Placa con forma de estrella respecto a su centro (abanico), con grosor h."""
    pts = np.vstack([[0, 0], poly])
    top, sn = surface.place(p, pts, lift + h)
    bot = top - sn * h
    m = len(poly)
    i = np.arange(m)
    f = [np.stack([np.zeros(m, int), 1 + i, 1 + (i + 1) % m], -1)]
    f.append(np.stack([np.zeros(m, int), 1 + (i + 1) % m, 1 + i], -1) + m + 1)
    a, b = 1 + i, 1 + (i + 1) % m
    f += [np.stack([a, a + m + 1, b], -1), np.stack([b, a + m + 1, b + m + 1], -1)]
    return tr.orient_closed(np.vstack([top, bot]), np.concatenate(f))


def line_strip(surface, p, path2d, width, lift=0.0012, h=0.0012):
    """Trazo plano (cinta) a lo largo de un camino 2D."""
    q, sn = surface.place(p, np.asarray(path2d, float), lift)
    return tr.sweep(q, sn, tr.rect(0, h, width / 2))


def cat_logo(surface, p, s=0.016):
    """Cara de gato en línea: contorno con orejas y dos ojos rasgados."""
    t = np.linspace(-math.pi / 2, math.pi / 2, 20)                      # mitad derecha, de abajo arriba
    half = [(x, y) for x, y in zip(np.cos(t) * 1.15, np.sin(t) * 0.85) if not (x > 0.3 and y > 0.45)]
    half += [(0.95, 1.25), (0.35, 0.80), (0.0, 0.80)]                     # oreja y frente
    outline = half + [(-x, y) for x, y in half[::-1]][1:]
    parts = [line_strip(surface, p, np.array(outline) * s, 0.0024)]
    for sx in (1, -1):
        eye = np.array([(sx * 0.65, 0.05), (sx * 0.30, -0.10)]) * s
        parts.append(line_strip(surface, p, np.linspace(eye[0], eye[1], 6), 0.0030))
    return parts


def pixel_logo(surface, p, s=0.0045):
    cells = [(0, 0), (1, 0), (2, 1), (0, 1), (1, 2), (2, 2), (3, 0)]
    sq = np.array([(-0.42, -0.42), (0.42, -0.42), (0.42, 0.42), (-0.42, 0.42)])
    return [plate(surface, p, (sq + (cx - 1.5, cy - 1)) * s) for cx, cy in cells]


def chevrons(surface, p, s=0.022):
    out = []
    for k in range(2):
        y0 = k * 0.75
        out.append(line_strip(surface, p, np.array([(-0.8, y0 - 0.6), (0, y0), (0.8, y0 - 0.6)]) * s, 0.008))
    out.append(line_strip(surface, p, np.array([(0, -1.6), (0, -0.7)]) * s, 0.004))
    return out


def star(surface, p, r=0.007):
    a = np.arange(8) * math.pi / 4
    rr = np.where(np.arange(8) % 2 == 0, r, r * 0.28)
    return [plate(surface, p, np.c_[np.sin(a) * rr, np.cos(a) * rr])]


def surface_point(v, x, y, front=True):
    """Punto de la chaqueta en (x, y), delante o detrás."""
    m = (v[:, 2] > ZC) if front else (v[:, 2] < ZC)
    cand = np.where(m)[0]
    _, i = cKDTree(v[cand][:, :2]).query([x, y], k=4)
    return v[cand[i]].mean(0)


# ---------------- 4. montaje ----------------
def build(out_dir):
    """Genera chaqueta_capucha.glb en out_dir y devuelve su ficha para el pack.json."""
    idx, shell, f_shell, loops = build_shell()
    verts, faces, zones, src_idx, src_w = [], [], [], [], []

    def add(v, f, zone="chaqueta", skin_idx=None, near_mask=None):
        v = np.asarray(v, float).reshape(-1, 3)
        faces.append(np.asarray(f, int) + sum(len(x) for x in verts))
        verts.append(v)
        zones.append(np.tile(ZONES[zone], (len(v), 1)) if isinstance(zone, str) else zone)
        if skin_idx is not None:
            src_idx.append(np.c_[skin_idx, np.zeros((len(v), 7), int)])
            src_w.append(np.c_[np.ones(len(v)), np.zeros((len(v), 7))])
        else:
            i, w = sud.nearest_skin(v, 8, near_mask)
            src_idx.append(i); src_w.append(w)

    shell_n = sud.vertex_normals(shell, f_shell)
    add(shell, f_shell, skin_idx=idx)
    add(shell - shell_n * THICK, f_shell[:, ::-1], skin_idx=idx)
    no_head = sud.main_bone != "Head"
    for s in SIDES:
        rings, k_cuff = sleeve_end(shell, loops["wrist_" + s], s)
        a = ARM[s]
        axis_pts = lambda c, a=a: a["lower"] + np.outer((c - a["lower"]) @ a["dir"], a["dir"])
        side_mask = (np.sign(P0[:, 0]) == SIDES[s]) & no_head & (sud.arm_w > 0.5)
        vs, fs = sud.orient(rings, axis_pts)
        cen = np.array([r.mean(0) for r in rings])
        vsi = np.concatenate([r - (r - c) / np.linalg.norm(r - c, axis=1, keepdims=True) * THICK
                              for r, c in zip(rings, cen)])
        cuff = np.repeat(np.arange(len(rings)) >= k_cuff, len(rings[0]))          # el puño, en su zona
        zone = np.array([ZONES["punos"] if c else ZONES["chaqueta"] for c in cuff])
        add(vs, fs, zone, near_mask=side_mask)
        add(vsi, fs[:, ::-1], zone, near_mask=side_mask)
    hv = hood(shell, loops["neck"])
    vh, fh = sud.orient(list(hv), lambda c: np.tile([0, 1.30, ZC], (len(c), 1)))
    hn = sud.vertex_normals(vh, fh)
    upper = no_head & (P0[:, 1] > 1.15) & (sud.arm_w < 0.5)
    add(vh, fh, near_mask=upper)
    add(vh - hn * 0.006, fh[:, ::-1], near_mask=upper)
    # logos
    surf = Surface(shell, f_shell)
    logos = cat_logo(surf, surface_point(shell, 0.0, 1.325)) + pixel_logo(surf, surface_point(shell, 0.085, 1.31))
    logos += chevrons(surf, surface_point(shell, 0.0, 1.24, front=False))
    for s in SIDES:                                                    # estrella: fuera del antebrazo
        a = ARM[s]
        p = a["lower"] + a["dir"] * 0.30 * np.linalg.norm(a["hand"] - a["lower"])
        out = np.cross(a["dir"], [0, 0, 1.0]); out *= np.sign(out[0] * SIDES[s])
        _, i = cKDTree(shell).query(p + out * 0.1)
        logos += star(surf, shell[i])
    for lv, lf in logos:
        add(lv, lf, "logos")
    v, f = np.concatenate(verts), np.concatenate(faces)
    v, f = sud.bridge_open(v, f)                                      # bordes: fuera ↔ dentro
    zc = np.concatenate(zones)
    joints, weights = sud.blend_weights(np.concatenate(src_idx), np.concatenate(src_w))
    si, sw = np.concatenate(src_idx), np.concatenate(src_w)
    targets = {}
    for name, d in sud.B["targets"].items():
        moved = (d[si] * sw[..., None]).sum(1)
        if np.abs(moved).max() >= 0.0005:
            targets[name] = moved.astype(np.float32)
    to_rig = np.array([tr.RIG_JN.index(n) if n in tr.RIG_JN else -1 for n in sud.JN])
    jr = to_rig[joints]
    weights = np.where(jr < 0, 0, weights); weights /= weights.sum(1, keepdims=True)
    jr = np.where(jr < 0, 0, jr)
    path = out_dir / "chaqueta_capucha.glb"
    sha = tr.write_glb(path, v, sud.vertex_normals(v, f), f, jr, weights, targets, "chaqueta_capucha", zc)
    print("MEDIDA chaqueta_capucha: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        len(v), len(f), len(targets), path.stat().st_size / 1e6))
    return tr.card("chaqueta_capucha", "Chaqueta corta con capucha", sha, [0.96, 0.94, 0.95], "ropa", "ropa_exterior")
