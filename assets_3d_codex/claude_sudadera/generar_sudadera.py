"""Sudadera oversize con capucha bajada, hecha a partir de la piel de la humana de GameMolde.

Uso:  python generar_sudadera.py
Lee godot/datos/humana/cuerpo.glb y el esqueleto de godot/packs/base/tights.glb; escribe
packs/claude_sudaderas/sudadera_capucha.glb + pack.json.

Cómo se construye:
1. Tronco y mangas = copia de la piel (de la cadera al cuello y hasta la muñeca), hinchada y alisada.
   Hereda por índice los pesos y las formas del cuerpo: sigue a los brazos y se adapta a cualquier cuerpo.
2. Desde el pecho cae recta (oversize): por debajo de la axila nunca se estrecha.
3. Pretina, mangas largas hasta los dedos con puño, capucha bajada y bolsillo canguro: geometría propia,
   con pesos y formas de la piel más cercana.
Ranura «ropa_exterior» (ningún pack la usa: no sustituye nada).
"""
import hashlib, json, math, struct, sys
from pathlib import Path
import numpy as np
from scipy.sparse import coo_matrix
from scipy.spatial import cKDTree

sys.path.insert(0, str(Path(__file__).parents[1] / "claude_gorra"))
import glb

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / "packs" / "claude_sudaderas"

# --- medidas (metros) ---
Y_CUT = 1.012                 # donde acaba la piel copiada; debajo va la pretina
BAND_H = 0.06                 # pretina de canalé: el bajo queda a ~0,95 (poco por encima de la entrepierna)
OFF_TORSO, OFF_ARM, OFF_WRIST, OFF_NECK = 0.042, 0.032, 0.024, 0.010
Y_ARMPIT = 1.20               # desde aquí hacia abajo el tronco cae recto
THICK = 0.003
SMOOTH_IT = 40

# ---------------- cuerpo ----------------
body, body_buf = glb.read(ROOT / "godot/datos/humana/cuerpo.glb")
B = glb.mesh_data(body, body_buf)
P0 = B["POSITION"].astype(float)
F0 = B["indices"].reshape(-1, 3)
JN = glb.joint_names(body)
J, W = B["JOINTS_0"].astype(int), B["WEIGHTS_0"].astype(float)
IBM = glb.accessor(body, body_buf, body["skins"][0]["inverseBindMatrices"]).reshape(-1, 4, 4)
# el .glb duplica vértices en las costuras de UV: se funden por posición para tener una superficie cerrada
_, _first, _inv = np.unique(np.round(P0 / 1e-6).astype(np.int64), axis=0, return_index=True, return_inverse=True)
P0, J, W = P0[_first], J[_first], W[_first]
F0 = _inv.ravel()[F0]
F0 = F0[(F0[:, 0] != F0[:, 1]) & (F0[:, 1] != F0[:, 2]) & (F0[:, 0] != F0[:, 2])]
B["targets"] = {k: d[_first] for k, d in B["targets"].items()}


def joint_pos(name):
    return np.linalg.inv(IBM[JN.index(name)].T)[:3, 3]


def bone_weight(names):
    ids = [JN.index(n) for n in names if n in JN]
    return (W * np.isin(J, ids)).sum(1)


main_bone = np.array(JN)[J[np.arange(len(J)), W.argmax(1)]]
SIDES = {"Left": 1, "Right": -1}
ARM = {s: dict(upper=joint_pos(s + "UpperArm"), lower=joint_pos(s + "LowerArm"), hand=joint_pos(s + "Hand"),
               knuckle=joint_pos(s + "MiddleProximal")) for s in SIDES}
for s, a in ARM.items():
    a["dir"] = (a["hand"] - a["lower"]) / np.linalg.norm(a["hand"] - a["lower"])
    a["hand_dir"] = (a["knuckle"] - a["hand"]) / np.linalg.norm(a["knuckle"] - a["hand"])
arm_w = bone_weight([s + b for s in SIDES for b in ("UpperArm", "LowerArm", "Hand")])
hand_like = np.array([("Hand" in b) or any(f in b for f in ("Thumb", "Index", "Middle", "Ring", "Little"))
                      for b in main_bone])


def neck_plane_y(z):
    return 1.400 - 0.30 * z      # cuello: más bajo delante


# ---------------- 1. región de piel ----------------
def select_region():
    keep = (P0[:, 1] >= Y_CUT) & (P0[:, 1] <= neck_plane_y(P0[:, 2])) & ~hand_like & (main_bone != "Head")
    for s, a in ARM.items():
        side = np.sign(P0[:, 0]) == SIDES[s]
        t = (P0 - a["lower"]) @ a["dir"] / np.linalg.norm(a["hand"] - a["lower"])
        keep &= ~(side & (arm_w > 0.5) & (t > 0.97))
    faces = F0[keep[F0].all(1)]
    # componente conexa mayor
    n = len(P0)
    adj = coo_matrix((np.ones(len(faces) * 3), (faces.ravel(), np.roll(faces, 1, 1).ravel())), (n, n)).tocsr()
    from scipy.sparse.csgraph import connected_components
    _, lab = connected_components(adj, directed=False)
    used = np.unique(faces)
    big = np.bincount(lab[used]).argmax()
    faces = faces[lab[faces[:, 0]] == big]
    verts = np.unique(faces)
    remap = -np.ones(n, int); remap[verts] = np.arange(len(verts))
    return verts, remap[faces]


def boundary_loops(faces):
    edges = {}
    for f in faces:
        for k in range(3):
            edges[(f[k], f[(k + 1) % 3])] = True
    nxt = {a: b for (a, b) in edges if (b, a) not in edges}
    loops, seen = [], set()
    for start in nxt:
        if start in seen:
            continue
        loop, v = [], start
        while v not in seen:
            seen.add(v); loop.append(v); v = nxt[v]
        loops.append(np.array(loop))
    return loops


def vertex_normals(v, f):
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    n = np.zeros_like(v)
    for k in range(3):
        np.add.at(n, f[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def laplacian(f, n):
    rows = np.concatenate([f[:, 0], f[:, 1], f[:, 2], f[:, 1], f[:, 2], f[:, 0]])
    cols = np.concatenate([f[:, 1], f[:, 2], f[:, 0], f[:, 0], f[:, 1], f[:, 2]])
    a = coo_matrix((np.ones(len(rows)), (rows, cols)), (n, n)).tocsr()
    a.data[:] = 1
    deg = np.asarray(a.sum(1)).ravel()
    return a, deg


def taubin(v, f, fixed, iters, lam=0.5, mu=-0.53):
    a, deg = laplacian(f, len(v))
    free = ~fixed
    for _ in range(iters):
        for k in (lam, mu):
            d = a @ v / deg[:, None] - v
            v[free] += k * d[free]
    return v


def smooth_loop(v, loop, iters, plane=None):
    """Alisa un borde cerrado sin encogerlo: cada punto conserva su distancia al centro."""
    c = v[loop].mean(0)
    r0 = np.linalg.norm(v[loop] - c, axis=1)
    for _ in range(iters):
        v[loop] = 0.5 * v[loop] + 0.25 * (np.roll(v[loop], 1, 0) + np.roll(v[loop], -1, 0))
        d = v[loop] - c
        r = np.linalg.norm(d, axis=1)
        v[loop] = c + d * (np.maximum(r, np.minimum(r0, r * 1.5)) / r)[:, None]
        if plane is not None:
            v[loop] = plane(v[loop])
    return v


def build_shell():
    idx, f = select_region()
    v = P0[idx].copy()
    loops = boundary_loops(f)
    kinds = {}
    for lp in loops:
        c = v[lp].mean(0)
        if abs(c[0]) > 0.2:
            kinds["wrist_" + ("Left" if c[0] > 0 else "Right")] = lp
        elif c[1] > 1.3:
            kinds["neck"] = lp
        else:
            kinds["hem"] = lp
    assert set(kinds) == {"wrist_Left", "wrist_Right", "neck", "hem"}, (len(loops), list(kinds))

    def wrist_plane(s):
        a = ARM[s]; p0 = a["lower"] + a["dir"] * 0.97 * np.linalg.norm(a["hand"] - a["lower"])
        return lambda q: q - np.outer((q - p0) @ a["dir"], a["dir"])

    planes = {"hem": lambda q: np.c_[q[:, 0], np.full(len(q), Y_CUT), q[:, 2]],
              "neck": lambda q: np.c_[q[:, 0], neck_plane_y(q[:, 2]), q[:, 2]],
              "wrist_Left": wrist_plane("Left"), "wrist_Right": wrist_plane("Right")}
    # hinchado: tronco > brazo > muñeca; cerca del cuello, poco
    aw = arm_w[idx]
    t_w = np.zeros(len(v))
    for s, a in ARM.items():
        side = np.sign(v[:, 0]) == SIDES[s]
        t = np.clip((v - a["upper"]) @ (a["hand"] - a["upper"]) / np.sum((a["hand"] - a["upper"]) ** 2), 0, 1)
        t_w[side] = t[side]
    off = OFF_TORSO * (1 - aw) + aw * (OFF_ARM + (OFF_WRIST - OFF_ARM) * t_w)
    dn = neck_plane_y(v[:, 2]) - v[:, 1]
    near_neck = np.clip(dn / 0.06, 0, 1)
    off = OFF_NECK + (off - OFF_NECK) * near_neck
    nrm = vertex_normals(v, f)
    v = v + nrm * off[:, None]
    fixed = np.zeros(len(v), bool)
    for k, lp in kinds.items():
        v[lp] = planes[k](v[lp]); fixed[lp] = True
        v = smooth_loop(v, lp, 20, planes[k])
    skin0 = P0[idx]

    def keep_out(v):
        """Ninguna tela por debajo de la mitad de su holgura respecto a su propia piel."""
        proj = np.einsum("ij,ij->i", v - skin0, nrm)
        return v + nrm * np.maximum(0.5 * off - proj, 0)[:, None]

    for _ in range(4):
        v = keep_out(taubin(v, f, fixed, SMOOTH_IT // 4))
    v = keep_out(drape(v, aw, f, fixed))
    v = keep_out(taubin(v, f, fixed, 4))
    for k, lp in kinds.items():
        v[lp] = planes[k](v[lp])
        v = smooth_loop(v, lp, 10, planes[k])
    return idx, v, f, kinds


def drape(v, aw, f, fixed):
    """Oversize: por debajo de la axila, el tronco nunca se estrecha (cae recto desde el pecho)."""
    torso = (aw < 0.3) & (v[:, 1] < Y_ARMPIT)
    zc = 0.02
    a = np.arctan2(v[:, 0], v[:, 2] - zc)
    r = np.hypot(v[:, 0], v[:, 2] - zc)
    nb = 48
    ab = ((a + math.pi) / (2 * math.pi) * nb).astype(int) % nb
    ys = np.arange(Y_ARMPIT, Y_CUT - 0.02, -0.01)
    src = (aw < 0.3) & (v[:, 1] < Y_ARMPIT + 0.03) & (v[:, 1] > Y_ARMPIT - 0.10)   # pecho y espalda bajo la axila
    env = np.zeros(nb)
    for b in range(nb):
        m = src & (ab == b)
        env[b] = r[m].max() if m.any() else 0
    env = np.maximum(env, env[::-1])
    f_ = np.fft.rfft(env); f_[6:] = 0; env = np.maximum(np.fft.irfft(f_, nb), env * 0.97)
    cen = (np.arange(nb) + 0.5) / nb * 2 * math.pi - math.pi
    target = np.interp(a, cen, env, period=2 * math.pi)
    # mezcla suave: del todo a 6 cm bajo la axila
    k = np.clip((Y_ARMPIT - v[:, 1]) / 0.06, 0, 1) * torso
    newr = np.maximum(r, r + (target - r) * k)
    s = newr / np.maximum(r, 1e-9)
    v[:, 0] *= np.where(torso, s, 1)
    v[:, 2] = np.where(torso, zc + (v[:, 2] - zc) * s, v[:, 2])
    return taubin(v, f, fixed, 15)


# ---------------- 2. pretina, puños, capucha y bolsillo ----------------
def loop_ring_order(v, lp, center, axis):
    """Ordena el lazo por ángulo alrededor de axis (para extrusiones)."""
    ref = np.cross(axis, [0, 0, 1.0]) if abs(axis[2]) < 0.9 else np.cross(axis, [1.0, 0, 0])
    ref /= np.linalg.norm(ref); ref2 = np.cross(axis, ref)
    d = v[lp] - center
    ang = np.arctan2(d @ ref2, d @ ref)
    o = np.argsort(ang)
    return lp[o]


def resample_ring(pts, n):
    seg = np.linalg.norm(np.diff(np.vstack([pts, pts[:1]]), axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    t = np.linspace(0, s[-1], n, endpoint=False)
    closed = np.vstack([pts, pts[:1]])
    return np.stack([np.interp(t, s, closed[:, k]) for k in range(3)], 1)


class Part:
    def __init__(self):
        self.v, self.f = [], []

    def add(self, verts, faces):
        base = sum(len(x) for x in self.v)
        self.v.append(np.asarray(verts, float).reshape(-1, 3))
        self.f.append(np.asarray(faces, int).reshape(-1, 3) + base)
        return base

    def arrays(self):
        return np.concatenate(self.v), np.concatenate(self.f)


def tube_faces(rows, cols, flip=False):
    out = []
    for j in range(rows - 1):
        for i in range(cols):
            a, b = j * cols + i, j * cols + (i + 1) % cols
            c, d = a + cols, b + cols
            out += [(a, b, c), (b, d, c)] if not flip else [(a, c, b), (b, c, d)]
    return np.array(out)


def orient(rings, outward_ref):
    """Comprueba que las caras miran hacia fuera (respecto a outward_ref) y si no, invierte."""
    f = tube_faces(len(rings), len(rings[0]))
    v = np.concatenate(rings)
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    c = v[f].mean(1)
    flip = np.mean(np.einsum("ij,ij->i", fn, c - outward_ref(c))) < 0
    return v, tube_faces(len(rings), len(rings[0]), flip=flip)


SKIN_TREE = cKDTree(P0)


def skin_clear(pts, gap):
    """Empuja hacia fuera (desde el eje dado) los puntos que queden a menos de gap de la piel."""
    d, i = SKIN_TREE.query(pts)
    return d < gap


def hem_band(v, lp):
    ring = loop_ring_order(v, lp, np.array([0, Y_CUT, 0.02]), np.array([0, 1.0, 0]))
    top = resample_ring(v[ring], 96)
    zc = 0.02
    a = np.arctan2(top[:, 0], top[:, 2] - zc)
    r = np.hypot(top[:, 0], top[:, 2] - zc)
    rings = [top]
    # radio de la pretina: recoge un 8 %, pero nunca a menos de 1,2 cm de la piel
    sk = P0[(P0[:, 1] > Y_CUT - BAND_H - 0.01) & (P0[:, 1] < Y_CUT) & (np.abs(P0[:, 0]) < 0.25)]
    sa = np.arctan2(sk[:, 0], sk[:, 2] - zc); sr = np.hypot(sk[:, 0], sk[:, 2] - zc)
    need = np.array([sr[np.abs((sa - x + math.pi) % (2 * math.pi) - math.pi) < 0.15].max() for x in a]) + 0.012
    rb = np.maximum(r * 0.92, need)
    for y, rr in ((Y_CUT - 0.008, rb + 0.004), (Y_CUT - BAND_H * 0.5, rb), (Y_CUT - BAND_H, rb - 0.002)):
        rings.append(np.c_[rr * np.sin(a), np.full(len(a), y), zc + rr * np.cos(a)])
    return top, rings


def sleeve_end(v, lp, s):
    a = ARM[s]
    axis = a["dir"]
    p0 = a["lower"] + axis * 0.97 * np.linalg.norm(a["hand"] - a["lower"])
    ring = loop_ring_order(v, lp, p0, axis)
    top = resample_ring(v[ring], 48)
    c0 = top.mean(0)
    hd = a["hand_dir"]
    # la manga sigue recta un poco y luego se dobla hacia la mano; el puño acaba en los nudillos
    length = (a["knuckle"] - c0) @ hd + 0.005
    side = np.sign(P0[:, 0]) == SIDES[s]
    t_arm = (P0 - a["lower"]) @ a["dir"] / np.linalg.norm(a["hand"] - a["lower"])
    hand = P0[side & (hand_like | ((arm_w > 0.3) & (t_arm > 0.85)))]   # mano y final del antebrazo
    steps = [(0.0, 1.0), (0.35, 1.06), (0.62, 1.0), (0.72, 0.84), (0.86, 0.84), (1.0, 0.82)]
    rings = []
    for t, scale in steps:
        c = c0 + hd * (length * t)
        q = c + (top - c0) * scale
        # cada vértice, al menos a 8 mm de la piel en su dirección (radio de la piel por sector alrededor de c)
        d = q - c; d -= np.outer(d @ hd, hd); rr = np.linalg.norm(d, axis=1); u = d / rr[:, None]
        rel = hand - c
        near = np.abs(rel @ hd) < 0.02
        if near.any() and t > 0:
            hr = rel[near] - np.outer(rel[near] @ hd, hd)
            hlen = np.linalg.norm(hr, axis=1)
            cosang = (u @ (hr / hlen[:, None]).T)            # (anillo, piel)
            reach = np.where(cosang > 0.94, hlen[None, :] * cosang, 0).max(1) + 0.008
            push = np.maximum(reach - rr, 0)
            for _ in range(3):   # sin picos: el empuje se reparte con los vecinos del anillo
                push = np.maximum(push, 0.5 * push + 0.25 * (np.roll(push, 1) + np.roll(push, -1)))
            q = q + u * push[:, None]
        rings.append(q)
    return top, rings


def hood(v, lp):
    """Capucha bajada: desde el cuello sube un poco, se abre y cae sobre la espalda (gran pliegue doble)."""
    nz = 0.02
    ring = loop_ring_order(v, lp, np.array([0, 1.40, nz]), np.array([0, 1.0, 0]))
    base = resample_ring(v[ring], 72)
    c = base.mean(0)
    out = base - c; out[:, 1] = 0; out /= np.linalg.norm(out, axis=1, keepdims=True)
    back = np.clip(-out[:, 2], 0, 1) ** 1.3            # 1 detrás, 0 delante
    side = np.abs(out[:, 0])
    rings = []
    ns = 14
    for k in range(ns + 1):
        t = k / ns
        # perfil: sube (h), sale (w) y baja sobre la espalda (drop), mucho detrás y poco delante
        h = (0.030 + 0.045 * back) * math.sin(math.pi * min(t / 0.55, 1) / 2)
        w = (0.020 + 0.075 * back + 0.020 * side) * math.sin(math.pi * t / 2)
        drop = (0.010 + 0.200 * back) * max(0, (t - 0.45) / 0.55) ** 1.5
        rings.append(base + out * w[:, None] + np.c_[np.zeros(72), h - drop, np.zeros(72)])
    outer = np.stack(rings)
    # que la parte que cae no entre en la sudadera: separarla de la superficie
    return outer


def pocket(shell_v, shell_n, front_mask):
    """Bolsillo canguro en relieve: trapecio delante, encima de la pretina."""
    tree = cKDTree(shell_v[front_mask][:, :2])
    sv, sn = shell_v[front_mask], shell_n[front_mask]
    nx, ny = 24, 10
    y0, y1 = Y_CUT + 0.006, Y_CUT + 0.125
    pts = []
    for j in range(ny + 1):
        y = y0 + (y1 - y0) * j / ny
        half = 0.125 - 0.035 * (j / ny) ** 1.2              # más estrecho arriba (aberturas en diagonal)
        for i in range(nx + 1):
            x = -half + 2 * half * i / nx
            _, ii = tree.query([x, y], k=4)
            z = sv[ii, 2].max()
            n = sn[ii].mean(0); n /= np.linalg.norm(n)
            pts.append((np.array([x, y, z]), n))
    P = np.array([p for p, _ in pts]).reshape(ny + 1, nx + 1, 3)
    N = np.array([n for _, n in pts]).reshape(ny + 1, nx + 1, 3)
    top = P + N * 0.005
    bot = P - N * 0.002
    return top, bot


# ---------------- pesos y formas para la geometría nueva ----------------
def nearest_skin(pts, k=8, mask=None):
    cand = np.where(mask)[0] if mask is not None else np.arange(len(P0))
    tree = cKDTree(P0[cand])
    d, i = tree.query(pts, k=k)
    w = 1 / (d + 0.004) ** 2
    return cand[i], w / w.sum(1, keepdims=True)


def blend_weights(idx, w):
    """Media de los pesos de varios vértices de piel → 4 influencias que suman 1 (índices del cuerpo)."""
    n = len(idx)
    full = np.zeros((n, len(JN)))
    for k in range(idx.shape[1]):
        for c in range(4):
            np.add.at(full, (np.arange(n), J[idx[:, k], c]), W[idx[:, k], c] * w[:, k])
    top = np.argsort(-full, 1)[:, :4]
    tw = np.take_along_axis(full, top, 1)
    tw /= tw.sum(1, keepdims=True)
    return top, tw


def main():
    idx, shell, f_shell, loops = build_shell()
    part = Part()
    # cada vértice: (pesos/formas) = por índice de piel, o media de vecinos
    src_idx, src_w = [], []

    def add(verts, faces, skin_idx=None, near_mask=None):
        verts = np.asarray(verts).reshape(-1, 3)
        part.add(verts, faces)
        if skin_idx is not None:
            src_idx.append(np.c_[skin_idx, np.zeros((len(skin_idx), 7), int)])
            src_w.append(np.c_[np.ones(len(skin_idx)), np.zeros((len(skin_idx), 7))])
        else:
            i, w = nearest_skin(verts, 8, near_mask)
            src_idx.append(i); src_w.append(w)

    shell_n = vertex_normals(shell, f_shell)
    inner = shell - shell_n * THICK
    nsh = len(shell)
    add(shell, f_shell, idx)
    add(inner, f_shell[:, ::-1], idx)
    no_head = main_bone != "Head"
    torso_mask = no_head & (arm_w < 0.3) & ~hand_like
    # pretina (fuera y dentro) unida a los bordes de la piel copiada por un anillo remuestreado
    top, rings = hem_band(shell, loops["hem"])
    vb, fb = orient(rings, lambda c: np.c_[np.zeros(len(c)), c[:, 1], np.full(len(c), 0.02)])
    add(vb, fb, near_mask=torso_mask)
    vbi = np.concatenate([r - (r - np.array([0, r[0, 1], 0.02])) * np.array([1, 0, 1]) *
                          (THICK / np.linalg.norm((r - np.array([0, r[0, 1], 0.02])) * [1, 0, 1], axis=1))[:, None]
                          for r in rings])
    add(vbi, fb[:, ::-1], near_mask=torso_mask)
    sleeves = {}
    for s in SIDES:
        top_s, rings_s = sleeve_end(shell, loops["wrist_" + s], s)
        a = ARM[s]
        axis_pts = lambda c, a=a: a["hand"] + np.outer((c - a["hand"]) @ a["hand_dir"], a["hand_dir"])
        vs, fs = orient(rings_s, axis_pts)
        side_mask = (np.sign(P0[:, 0]) == SIDES[s]) & no_head & ((arm_w > 0.5) | hand_like)
        add(vs, fs, near_mask=side_mask)
        cen = np.array([r.mean(0) for r in rings_s])
        vsi = np.concatenate([r - (r - c) / np.linalg.norm(r - c, axis=1, keepdims=True) * THICK
                              for r, c in zip(rings_s, cen)])
        add(vsi, fs[:, ::-1], near_mask=side_mask)
        sleeves[s] = (vs, vsi, len(rings_s), len(rings_s[0]))
    # capucha: hoja doble (fuera y dentro) cerrada por el borde
    hv = hood(shell, loops["neck"])
    rows, cols = hv.shape[:2]
    hood_ref = np.array([0, 1.30, 0.02])
    vh, fh = orient(list(hv), lambda c: np.tile(hood_ref, (len(c), 1)))
    hn = vertex_normals(vh, fh)
    upper_mask = no_head & (P0[:, 1] > 1.15) & (arm_w < 0.5)
    add(vh, fh, near_mask=upper_mask)
    add(vh - hn * 0.006, fh[:, ::-1], near_mask=upper_mask)
    # bolsillo
    front = (shell[:, 2] > 0.02) & (shell[:, 1] < Y_CUT + 0.2) & (np.abs(shell[:, 0]) < 0.2)
    ptop, pbot = pocket(shell, shell_n, front)
    ny, nx = ptop.shape[0] - 1, ptop.shape[1] - 1
    fq = []
    for j in range(ny):
        for i in range(nx):
            a_, b_ = j * (nx + 1) + i, j * (nx + 1) + i + 1
            c_, d_ = a_ + nx + 1, b_ + nx + 1
            fq += [(a_, b_, c_), (b_, d_, c_)]
    fq = np.array(fq)
    vp = ptop.reshape(-1, 3)
    fn = np.cross(vp[fq[:, 1]] - vp[fq[:, 0]], vp[fq[:, 2]] - vp[fq[:, 0]])
    if fn[:, 2].mean() < 0:
        fq = fq[:, ::-1]
    # paredes del bolsillo (borde) bajando hasta la tela
    edge = [(0, i) for i in range(nx + 1)] + [(j, nx) for j in range(1, ny + 1)] + \
           [(ny, i) for i in range(nx - 1, -1, -1)] + [(j, 0) for j in range(ny - 1, 0, -1)]
    et = np.array([ptop[j, i] for j, i in edge]); eb = np.array([pbot[j, i] for j, i in edge])
    vw, fw = orient([et, eb], lambda c: np.tile([0, Y_CUT + 0.06, 0.0], (len(c), 1)))
    add(np.concatenate([vp]), fq, near_mask=torso_mask)
    add(vw, fw, near_mask=torso_mask)
    v, f = part.arrays()
    # cierres: bordes abiertos entre fuera y dentro (bajo, puños, capucha) → se unen con su copia interior
    v, f = bridge_open(v, f)
    si = np.concatenate(src_idx); sw = np.concatenate(src_w)
    joints, weights = blend_weights(si, sw)
    names = list(B["targets"])
    targets = {}
    for name in names:
        d = B["targets"][name].astype(float)
        moved = (d[si] * sw[..., None]).sum(1)
        if np.abs(moved).max() >= 0.0005:
            targets[name] = moved.astype(np.float32)
    nrm = vertex_normals(v, f)
    OUT.mkdir(parents=True, exist_ok=True)
    sha = write_glb(OUT / "sudadera_capucha.glb", v, nrm, f, joints, weights, targets, "sudadera_capucha")
    pack = {
        "formato": "gamemolde-pack", "version": 1, "id": "claude_sudaderas", "nombre": "Sudaderas (pruebas)",
        "autor": "GameMolde", "licencia": "propia", "origen": "",
        "piezas": [{
            "id": "sudadera_capucha", "nombre": "Sudadera oversize con capucha", "archivo": "sudadera_capucha.glb",
            "sha256": sha, "tipo": "ropa", "ranura": "ropa_exterior", "especies": ["humana"],
            "colores": ["principal"], "color": [0.27, 0.29, 0.33], "sigue_al_cuerpo": True, "fisica": [],
            "miniatura": "", "anclaje": {"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]}}],
    }
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
    print("MEDIDA %d vértices, %d triángulos, %d formas, %.2f MB; bajo a %.3f m" % (
        len(v), len(f), len(targets), (OUT / "sudadera_capucha.glb").stat().st_size / 1e6, v[:, 1].min()))


def bridge_open(v, f):
    """Une cada borde abierto con el borde abierto más cercano (fuera ↔ dentro) con una tira de caras."""
    loops = boundary_loops(f)
    used = set()
    extra = []
    cents = [v[lp].mean(0) for lp in loops]
    for i, lp in enumerate(loops):
        if i in used:
            continue
        best, bd = None, 1e9
        for j, lq in enumerate(loops):
            if j == i or j in used or len(lq) != len(lp):
                continue
            d = np.linalg.norm(cents[i] - cents[j])
            if d < bd:
                best, bd = j, d
        if best is None or bd > 0.02:
            continue
        used |= {i, best}
        lq = loops[best]
        tree = cKDTree(v[lq])
        _, m = tree.query(v[lp])
        # lq va en sentido contrario (copia invertida): cada arista a→b de fuera con su pareja dentro
        for k in range(len(lp)):
            a, b = lp[k], lp[(k + 1) % len(lp)]
            ia, ib = lq[m[k]], lq[m[(k + 1) % len(lp)]]
            extra.append((a, ia, b))
            if ia != ib:
                extra.append((b, ia, ib))
    return v, np.concatenate([f, np.array(extra, int).reshape(-1, 3)])


def write_glb(path, pos, nrm, faces, joints_body, weights, targets, name):
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
        """Forma dispersa: solo los vértices que se mueven más de 0,01 mm (como cuerpo.glb)."""
        moving = np.where(np.abs(delta).max(1) > 1e-5)[0].astype(np.uint32)
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

    uv = np.stack([np.arctan2(pos[:, 0], pos[:, 2]) / (2 * math.pi) + 0.5, pos[:, 1]], 1)
    attrs = {
        "POSITION": add(pos.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": add(nrm.astype(np.float32), 5126, "VEC3", 34962),
        "TEXCOORD_0": add(uv.astype(np.float32), 5126, "VEC2", 34962),
        "JOINTS_0": add(jr.astype(np.uint16), 5123, "VEC4", 34962),
        "WEIGHTS_0": add(weights.astype(np.float32), 5126, "VEC4", 34962),
    }
    names = list(targets)
    tg = [{"POSITION": add_sparse(targets[t])} for t in names]
    ind = add(faces.astype(np.uint32).ravel(), 5125, "SCALAR", 34963)
    ibm_acc = add(ibm.reshape(-1, 16), 5126, "MAT4")
    doc = {
        "asset": {"version": "2.0", "generator": "GameMolde generar_sudadera.py"},
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


if __name__ == "__main__":
    main()
