"""Botas blindadas medievales (plano: planos/Hoja técnica de botas blindadas medievales.webp).

Uso:  python generar_botas.py   (en Linux: ~/.venvs/gamemolde_assets/bin/python generar_botas.py; numpy y scipy)
Escribe packs/claude_botas/: botas_medievales, el par en **una sola pieza**, ranura «ropa_pies» (no quita nada: van
con shorts, mallas y trajes ceñidos; un pantalón holgado asomará, ver P en plan_assets.md).
- Cuero: la piel de la pantorrilla y del pie copiada e hinchada (pesos y formas por índice: sigue a cualquier edición
  del cuerpo), con grosor. Caña hasta 4 cm bajo la rodilla, a 9 mm de la piel y con arrugas abajo; pie a 6 mm, puntera
  1,5 cm más larga que los dedos y dedos alisados. Suela que sobresale 4 mm, con tacón detrás.
- Acero (rígido con su hueso; las formas, de la piel de debajo): espinillera con cresta y punta arriba, que acaba bajo
  la rodilla (decidido por el responsable), con remaches; empeine de tres láminas (pie y dedos).
- Correas con hebilla: dos arriba, una a media caña, una en el tobillo y una por debajo del pie.
Zonas en COLOR_0: (0,0,0) cuero; r = 1 acero; g = 1 correas; r = g = 1 hebillas y remaches; b = 1 suela.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje", "claude_casco", "claude_eva"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_sudadera as sud
import generar_traje as tr
import generar_casco as casco
import generar_eva as eva

OUT = HERE / "packs" / "claude_botas"
PID = "botas_medievales"

# --- medidas (metros); t: a lo largo de la pierna, 0 rodilla y 1 tobillo ---
TOP_T = 0.10                                # boca de la caña (unos 4 cm bajo la rodilla)
OFF_SHAFT, OFF_FOOT, OFF_UNDER = 0.009, 0.006, 0.003
THICK = 0.003                               # grosor del cuero
TOE_EXTRA = 0.015                           # la puntera, más larga que los dedos
FOLD_AMP, FOLD_STEP, FOLD_T = 0.0035, 0.028, (0.42, 0.86)
SOLE_OUT, SOLE_Y0, SOLE_H, HEEL_H = 0.004, -0.004, 0.012, 0.012
GREAVE_T = (0.15, 0.90)                     # espinillera (la punta de arriba sube 3 cm más)
GREAVE_GAP, STEEL = 0.003, 0.003
STRAP_T = (0.20, 0.31, 0.60, 0.84)

P0, F0, SIDES = sud.P0, sud.F0, sud.SIDES
ZONES = {"cuero": (0, 0, 0, 1), "acero": (1, 0, 0, 1), "correas": (0, 1, 0, 1), "hebillas": (1, 1, 0, 1),
         "suela": (0, 0, 1, 1)}
LEG = {}
for s in SIDES:
    g = dict(knee=sud.joint_pos(s + "LowerLeg"), ankle=sud.joint_pos(s + "Foot"), toes=sud.joint_pos(s + "Toes"))
    g["len"] = np.linalg.norm(g["ankle"] - g["knee"])
    g["dir"] = (g["ankle"] - g["knee"]) / g["len"]
    f = np.array([0, 0, 1.0]) - g["dir"] * g["dir"][2]
    g["fwd"] = f / np.linalg.norm(f)                                 # delante, perpendicular a la pierna
    g["side"] = np.cross(g["dir"], g["fwd"])
    LEG[s] = g
LOWER_W = sud.bone_weight([s + "LowerLeg" for s in SIDES])
FOOT_W = sud.bone_weight([s + b for s in SIDES for b in ("Foot", "Toes")])
NO_HEAD = sud.main_bone != "Head"


def leg_t(p, s):
    g = LEG[s]
    return (p - g["knee"]) @ g["dir"] / g["len"]


def leg_angle(p, s):
    """Ángulo alrededor de la pierna: 0 delante, positivo hacia fuera."""
    g = LEG[s]
    d = p - g["knee"]
    return np.arctan2(SIDES[s] * (d @ g["side"]) * -1, d @ g["fwd"])


def side_of(p, s):
    return np.sign(p[:, 0]) == SIDES[s]


# ---------------- 1. cuero ----------------
def select_region():
    keep = np.zeros(len(P0), bool)
    for s in SIDES:
        keep |= side_of(P0, s) & (np.abs(P0[:, 0]) > 0.01) & (leg_t(P0, s) > TOP_T) & (LOWER_W + FOOT_W > 0.5)
    faces = F0[keep[F0].all(1)]
    verts = np.unique(faces)
    remap = -np.ones(len(P0), int); remap[verts] = np.arange(len(verts))
    return verts, remap[faces]


def offsets(idx, v, nrm):
    fw = FOOT_W[idx]
    off = np.full(len(v), OFF_SHAFT)
    for s in SIDES:
        m = side_of(v, s)
        t, a = leg_t(v[m], s), leg_angle(v[m], s)
        g = LEG[s]
        win = eva.smoothstep((t - FOLD_T[0]) / 0.08) * eva.smoothstep((FOLD_T[1] - t) / 0.08)
        amp = FOLD_AMP * (0.5 + 0.5 * (1 - np.cos(a)) / 2)           # más arrugas detrás y en los lados
        fold = amp * win * (0.5 + 0.5 * np.sin(2 * math.pi * t * g["len"] / FOLD_STEP + 1.3 * np.sin(2 * a)))
        off[m] += fold
    foot = np.where(nrm[:, 1] < -0.5, OFF_UNDER, OFF_FOOT)
    return off * (1 - fw) + foot * fw


def stretch_toes(v, idx):
    """La puntera: los dedos se alargan hacia delante (más en la punta)."""
    for s in SIDES:
        g = LEG[s]
        m = side_of(v, s) & (FOOT_W[idx] > 0.3)
        z_ball, z_tip = g["toes"][2] - 0.03, P0[idx][m, 2].max()
        k = eva.smoothstep((v[m, 2] - z_ball) / (z_tip - z_ball))
        v[m] += np.outer(k * TOE_EXTRA, g["fwd"] * [1, 0, 1])
    return v


def top_plane(s):
    g = LEG[s]
    p0 = g["knee"] + g["dir"] * TOP_T * g["len"]
    return lambda q: q - np.outer((q - p0) @ g["dir"], g["dir"])


def build_shell():
    idx, f = select_region()
    loops = sud.boundary_loops(f)
    assert len(loops) == 2, [len(l) for l in loops]
    skin0 = P0[idx]
    nrm = sud.vertex_normals(skin0, f)
    off = offsets(idx, skin0, nrm)
    v = stretch_toes(skin0 + nrm * off[:, None], idx)
    tops = {("Left" if skin0[lp, 0].mean() > 0 else "Right"): lp for lp in loops}
    fixed = np.zeros(len(v), bool)
    for s, lp in tops.items():
        v[lp] = top_plane(s)(v[lp]); fixed[lp] = True
    foot = FOOT_W[idx] > 0.3
    folds = np.zeros(len(v), bool)
    for s in SIDES:
        t = leg_t(v, s)
        folds |= side_of(v, s) & (t > FOLD_T[0] - 0.05) & (t < FOLD_T[1] + 0.05) & ~foot

    def keep_out(v):
        proj = np.einsum("ij,ij->i", v - skin0, nrm)
        return v + nrm * np.maximum(0.7 * off - proj, 0)[:, None]

    for _ in range(3):
        v = keep_out(sud.taubin(v, f, fixed | folds, 6))
    for _ in range(6):                                               # sin la forma de los dedos
        v = keep_out(sud.taubin(v, f, fixed | ~foot, 10))
    for s, lp in tops.items():
        v = sud.smooth_loop(v, lp, 10, top_plane(s))
    return idx, v, f


# ---------------- 2. suela ----------------
def sole(shell, s, n=72):
    pts = shell[side_of(shell, s) & (shell[:, 1] < 0.035)]
    g = LEG[s]
    c = pts[:, [0, 2]].mean(0)
    d = pts[:, [0, 2]] - c
    ang = np.arctan2(d[:, 0], d[:, 1])                               # 0 = delante (+z)
    bins = ((ang + math.pi) / (2 * math.pi) * n).astype(int) % n
    r = np.array([np.linalg.norm(d[bins == b], axis=1).max() if (bins == b).any() else np.nan for b in range(n)])
    k = np.arange(n); ok = ~np.isnan(r)
    r = np.interp(k, np.r_[k[ok] - n, k[ok], k[ok] + n], np.tile(r[ok], 3))
    th = (k + 0.5) / n * 2 * math.pi - math.pi
    heel = eva.smoothstep((-np.cos(th) - 0.55) / 0.3)
    u = np.c_[np.sin(th), np.cos(th)]
    ro, ri = r + SOLE_OUT + 0.003 * heel, r - 0.008
    y1 = SOLE_Y0 + SOLE_H + HEEL_H * heel

    def ring(rr, y):
        xz = c + u * rr[:, None]
        return np.c_[xz[:, 0], np.broadcast_to(y, n), xz[:, 1]]

    rings = [ring(ro, SOLE_Y0), ring(ro, y1), ring(ri, y1)]
    v = np.vstack(rings + [[c[0], SOLE_Y0, c[1]], [c[0], y1.min(), c[1]]])
    f = []
    i = np.arange(n)
    for j in range(2):
        a, b = j * n + i, j * n + (i + 1) % n
        f += list(np.stack([a, b, a + n], -1)) + list(np.stack([b, b + n, a + n], -1))
    c0, c1 = 3 * n, 3 * n + 1
    f += list(np.stack([np.full(n, c0), (i + 1) % n, i], -1)) + list(np.stack([np.full(n, c1), 2 * n + i,
                                                                              2 * n + (i + 1) % n], -1))
    return tr.orient_closed(v, np.array(f))


# ---------------- 3. acero ----------------
def grid_slab(outer, inner):
    """Placa cerrada entre dos rejillas n × m (fuera y dentro)."""
    n, m = outer.shape[:2]
    j, i = np.meshgrid(np.arange(n - 1), np.arange(m - 1), indexing="ij")
    a, b, c, d = j * m + i, j * m + i + 1, (j + 1) * m + i, (j + 1) * m + i + 1
    top = np.concatenate([np.stack([a, c, b], -1).reshape(-1, 3), np.stack([b, c, d], -1).reshape(-1, 3)])
    N = n * m
    F = [top, top[:, ::-1] + N]
    border = np.r_[np.arange(m), (np.arange(1, n) * m + m - 1), (n - 1) * m + np.arange(m - 2, -1, -1),
                   np.arange(n - 2, 0, -1) * m]
    e0, e1 = border, np.roll(border, -1)
    F += [np.stack([e0, e1, e0 + N], -1), np.stack([e1, e1 + N, e0 + N], -1)]
    v, f = np.vstack([outer.reshape(-1, 3), inner.reshape(-1, 3)]), np.concatenate(F)
    c = v.mean(0)
    vol = np.einsum("ij,ij->i", v[f[:, 0]] - c, np.cross(v[f[:, 1]] - c, v[f[:, 2]] - c)).sum()
    return v, (f if vol > 0 else f[:, ::-1])


class LegRadius:
    """Radio del cuero (alrededor del eje de la pierna) en cada (t, ángulo)."""
    def __init__(self, pts, s):
        self.s, g = s, LEG[s]
        self.t, self.a = leg_t(pts, s), leg_angle(pts, s)
        d = pts - g["knee"]
        self.r = np.linalg.norm(d - np.outer(d @ g["dir"], g["dir"]), axis=1)
        self.kd = cKDTree(np.c_[self.t * g["len"], self.a * 0.05])

    def __call__(self, t, a):
        _, i = self.kd.query(np.c_[np.ravel(t) * LEG[self.s]["len"], np.ravel(a) * 0.05], k=8)
        return self.r[i].max(1).reshape(np.shape(t))

    def point(self, t, a, r):
        g = LEG[self.s]
        sx = SIDES[self.s]
        u = np.cos(a)[..., None] * g["fwd"] - sx * np.sin(a)[..., None] * g["side"]
        return g["knee"] + (t * g["len"])[..., None] * g["dir"] + r[..., None] * u


def greave(lr, nt=44, na=26):
    s_, q = np.meshgrid(np.linspace(0, 1, nt), np.linspace(-1, 1, na), indexing="ij")
    amax = 1.20 - 0.30 * s_
    a = q * amax
    t0 = GREAVE_T[0] - 0.075 * (1 - np.abs(q)) ** 1.5                # punta arriba, en el centro
    t = t0 + s_ * (GREAVE_T[1] - t0)
    crest = 0.0035 * np.clip(1 - np.abs(a) / 0.22, 0, 1)
    r = lr(t, a) + GREAVE_GAP + crest
    for _ in range(4):                                               # sin escalones
        r[1:-1, 1:-1] = 0.5 * r[1:-1, 1:-1] + 0.125 * (r[:-2, 1:-1] + r[2:, 1:-1] + r[1:-1, :-2] + r[1:-1, 2:])
    r = np.maximum(r, lr(t, a) + GREAVE_GAP)
    return grid_slab(lr.point(t, a, r + STEEL), lr.point(t, a, r)), (t, a, r + STEEL)


def rivet(p, n, rad=0.0035):
    prof = [(0, -0.001), (rad, -0.001), (rad * 0.9, 0.0012), (rad * 0.55, 0.0024), (0, 0.0028)]
    return casco.lathe(prof, p, n, 8)


def rivets(lr, tar):
    t, a, r = tar
    out = []
    for qi in (2, -3):                                               # cerca de cada borde
        for j in range(4, t.shape[0] - 2, 7):
            p = lr.point(t[j, qi], a[j, qi], r[j, qi])
            nn = lr.point(t[j, qi], a[j, qi], r[j, qi] + 1) - p
            out.append(rivet(p, nn))
    return out


def sabaton(shell, s):
    """Tres láminas sobre el empeine, de la espinillera a la puntera."""
    g = LEG[s]
    m = side_of(shell, s) & (shell[:, 1] > 0.015) & (shell[:, 1] < 0.13)
    pts = shell[m]
    kd = cKDTree(pts[:, [0, 2]])
    z0, z1 = g["ankle"][2] + 0.035, pts[:, 2].max() - 0.006
    cx = np.median(pts[pts[:, 2] > z0, 0])
    plates = []
    for k, (a, b) in enumerate(((0.0, 0.40), (0.32, 0.70), (0.62, 1.0))):
        zz = np.linspace(z0 + (z1 - z0) * a, z0 + (z1 - z0) * b, 10)
        xs = []
        for z in zz:
            row = pts[np.abs(pts[:, 2] - z) < 0.006]
            xs.append((row[:, 0].min(), row[:, 0].max()))
        xs = np.array(xs)
        q = np.linspace(-1, 1, 14)
        half = 0.42 * (xs[:, 1] - xs[:, 0]) * (1 - 0.35 * np.linspace(a, b, 10) ** 3)
        mid = 0.5 * (xs[:, 0] + xs[:, 1])
        X = mid[:, None] + half[:, None] * q[None]
        Z = np.broadcast_to(zz[:, None], X.shape)
        _, ii = kd.query(np.c_[X.ravel(), Z.ravel()], k=6)
        Y = pts[ii, 1].max(1).reshape(X.shape)
        for _ in range(3):
            Y[1:-1, 1:-1] = 0.5 * Y[1:-1, 1:-1] + 0.125 * (Y[:-2, 1:-1] + Y[2:, 1:-1] + Y[1:-1, :-2] + Y[1:-1, 2:])
        lift = 0.003 + 0.002 * (2 - k)                               # la de arriba pisa a la siguiente
        Y = np.maximum(Y, pts[ii, 1].max(1).reshape(X.shape)) + lift
        inner = np.stack([X, Y, Z], -1)
        outer = inner + [0, STEEL, 0]
        plates.append((grid_slab(outer, inner), "Toes" if k == 2 else "Foot"))
    return plates


# ---------------- 4. correas y hebillas ----------------
def strap(pts, s, t):
    g = LEG[s]
    c = g["knee"] + g["dir"] * t * g["len"]
    return eva.band(pts, np.ones(len(pts), bool), c, g["dir"], 0.009, eva.bevel_prof(0.009, 0.0035), n=64)


def buckle(band_v, s, axis):
    """Hebilla (marco) y cabo de la correa, en el lado de fuera."""
    sx = SIDES[s]
    p = band_v[np.argmax(band_v[:, 0] * sx)]
    nrm = np.array([sx * 1.0, 0, 0]); nrm -= axis * (nrm @ axis); nrm /= np.linalg.norm(nrm)
    up = axis / np.linalg.norm(axis)
    tang = np.cross(up, nrm)
    c = p + nrm * 0.002
    parts = []
    for du, dt, hu, ht in ((0.012, 0, 0.0018, 0.011), (-0.012, 0, 0.0018, 0.011), (0, 0.010, 0.012, 0.0018),
                           (0, -0.010, 0.012, 0.0018), (0, 0, 0.012, 0.0012)):
        parts.append(casco.box(c + up * du + tang * dt, [ht, hu, 0.0015], tang, up, nrm))
    tail = casco.box(c - tang * 0.020 + nrm * 0.0005, [0.010, 0.0080, 0.0014], tang, up, nrm)   # cabo hacia atrás
    return parts, tail


# ---------------- 5. montaje y .glb ----------------
def build():
    idx, shell, f_shell = build_shell()
    verts, faces, zones, src_idx, src_w, bones = [], [], [], [], [], []

    def add(v, f, zone, skin_idx=None, mask=None, bone=None, rigid=False):
        v = np.asarray(v, float).reshape(-1, 3)
        faces.append(np.asarray(f, int) + sum(len(x) for x in verts))
        verts.append(v)
        zones.append(np.tile(ZONES[zone], (len(v), 1)))
        bones.append(np.full(len(v), sud.JN.index(bone) if bone else -1))
        if skin_idx is not None:
            src_idx.append(np.c_[skin_idx, np.zeros((len(v), 7), int)])
            src_w.append(np.c_[np.ones(len(v)), np.zeros((len(v), 7))])
        elif rigid:                                                  # los mismos 8 puntos de piel para todo
            near = np.unique(sud.nearest_skin(v, 2, mask)[0][:, 0])
            pick = near[np.linspace(0, len(near) - 1, 8).astype(int)]
            src_idx.append(np.tile(pick, (len(v), 1))); src_w.append(np.full((len(v), 8), 1 / 8))
        else:
            i, w = sud.nearest_skin(v, 8, mask)
            src_idx.append(i); src_w.append(w)

    nrm = sud.vertex_normals(shell, f_shell)
    add(shell, f_shell, "cuero", skin_idx=idx)
    add(shell - nrm * THICK, f_shell[:, ::-1], "cuero", skin_idx=idx)
    for s in SIDES:
        leg = side_of(P0, s) & ((LOWER_W > 0.3) | (FOOT_W > 0.3))
        foot = side_of(P0, s) & (FOOT_W > 0.3)
        add(*sole(shell, s), "suela", mask=foot)
        lr = LegRadius(shell[side_of(shell, s) & (FOOT_W[idx] < 0.5)], s)
        (gv, gf), tar = greave(lr)
        add(gv, gf, "acero", mask=leg, bone=s + "LowerLeg")
        for rv, rf in rivets(lr, tar):
            add(rv, rf, "hebillas", mask=leg, bone=s + "LowerLeg")
        plates = sabaton(shell, s)
        for (pv, pf), bone in plates:
            add(pv, pf, "acero", mask=foot, bone=s + bone)
        pts = np.vstack([shell[side_of(shell, s) & (FOOT_W[idx] < 0.5)], gv])
        for t in STRAP_T:
            bv, bf = strap(pts, s, t)
            add(bv, bf, "correas", mask=leg)
            parts, tail = buckle(bv, s, LEG[s]["dir"])
            for p in parts:
                add(*p, "hebillas", mask=leg, rigid=True)
            add(*tail, "correas", mask=leg, rigid=True)
        g = LEG[s]
        under = np.vstack([shell[side_of(shell, s) & (FOOT_W[idx] > 0.3)], np.vstack([p[0][0] for p in plates]),
                           sole(shell, s)[0]])
        c = np.array([g["ankle"][0] + SIDES[s] * 0.005, 0.03, g["ankle"][2] + 0.045])
        add(*eva.band(under, np.ones(len(under), bool), c, g["fwd"], 0.008, eva.bevel_prof(0.008, 0.0035), n=64),
            "correas", mask=foot)
    v, f = np.concatenate(verts), np.concatenate(faces)
    v, f = sud.bridge_open(v, f)                                     # boca de la caña: fuera ↔ dentro
    return write(v, f, np.concatenate(zones), np.concatenate(src_idx), np.concatenate(src_w), np.concatenate(bones))


def write(v, f, zc, si, sw, bones):
    joints, weights = sud.blend_weights(si, sw)
    rigid = bones >= 0
    joints[rigid] = np.c_[bones[rigid], np.zeros((rigid.sum(), 3), int)]
    weights[rigid] = [1, 0, 0, 0]
    targets = {}
    for name, d in sud.B["targets"].items():
        moved = (d[si] * sw[..., None]).sum(1)
        if np.abs(moved).max() >= 0.0005:
            targets[name] = moved.astype(np.float32)
    to_rig = np.array([tr.RIG_JN.index(n) if n in tr.RIG_JN else -1 for n in sud.JN])
    jr = to_rig[joints]
    weights = np.where(jr < 0, 0, weights); weights /= weights.sum(1, keepdims=True)
    jr = np.where(jr < 0, 0, jr)
    path = OUT / (PID + ".glb")
    sha = tr.write_glb(path, v, sud.vertex_normals(v, f), f, jr, weights, targets, PID, zc)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        PID, len(v), len(f), len(targets), path.stat().st_size / 1e6))
    return sha


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sha = build()
    cards = [tr.card(PID, "Botas blindadas medievales", sha, [0.42, 0.27, 0.16], "ropa", "ropa_pies")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_botas", "nombre": "Botas (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
