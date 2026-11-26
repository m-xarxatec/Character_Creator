"""Kigurumi de conejito rosa (plano: planos/Lámina técnica de kigurumi de conejito rosa.webp).

Uso:  python generar_kigurumi.py
Escribe packs/claude_kigurumis/: kigurumi_conejo (pijama de una pieza, ranura «ropa_exterior»: no quita nada, debajo
se ve la ropa ajustada que lleve el personaje), con la capucha puesta (generar_capucha.py) como parte del pijama:
«cubre: ["pelo"]» quita el peinado.
Hecho como la sudadera y la chaqueta del traje rosa (usa sus herramientas): piel copiada e hinchada, con los pesos y
las formas del cuerpo por índice. Muy holgado: tronco +3,5 cm, mangas abullonadas y perneras bombachas (+6,5 cm en la
pantorrilla) que se recogen en puños oscuros (muñeca y tobillo). Cremallera abierta en V delante, del cuello a la
pelvis (dos cintas y el cursor abajo); detrás, cerrado. Dos franjas diagonales en cada pierna.
Zonas en COLOR_0: (0,0,0) pijama, r = 1 puños, g = 1 franjas, r = g = 1 cremallera,
b = 1 pompones.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent / "claude_sudadera"))
sys.path.insert(0, str(HERE.parent / "claude_traje"))
import generar_sudadera as sud
import generar_traje as tr
import generar_chaqueta as ch

OUT = HERE / "packs" / "claude_kigurumis"

# --- medidas (metros) ---
V_BOTTOM, V_HALF = 0.83, 0.110          # V de la cremallera: fondo (pelvis) y media anchura en el cuello
OFF_TORSO, OFF_NECK, OFF_THIGH, OFF_CALF = 0.035, 0.012, 0.040, 0.065
LEG_CUT = 0.55                          # la piel copiada de la pierna acaba aquí (0 rodilla, 1 tobillo)
CUFF_LEN, CUFF_GAP = 0.050, 0.008       # puño del tobillo
LEG_GAP = 0.006                         # las perneras no pasan de x = ±6 mm (no se cruzan entre las piernas)
STRIPES = [dict(side=1, y=(0.50, 0.90), c=0.66), dict(side=-1, y=(0.22, 0.62), c=0.40)]
STRIPE_W, STRIPE_STEP, STRIPE_SLOPE = 0.026, 0.050, 1.0
ZC = 0.02

P0, F0, SIDES, ARM = sud.P0, sud.F0, sud.SIDES, sud.ARM
ZONES = {"kigurumi": (0, 0, 0, 1), "punos": (1, 0, 0, 1), "franjas": (0, 1, 0, 1), "cremallera": (1, 1, 0, 1),
         "pompones": (0, 0, 1, 1)}
LEG = {s: dict(hip=sud.joint_pos(s + "UpperLeg"), knee=sud.joint_pos(s + "LowerLeg"), ankle=sud.joint_pos(s + "Foot"))
       for s in SIDES}
for a in LEG.values():
    a["dir"] = (a["ankle"] - a["knee"]) / np.linalg.norm(a["ankle"] - a["knee"])
LEG_W = sud.bone_weight([s + b for s in SIDES for b in ("UpperLeg", "LowerLeg", "Foot", "Toes")])
FOOT_LIKE = np.array([("Foot" in b) or ("Toes" in b) for b in sud.main_bone])


def leg_t(p, s):
    a = LEG[s]
    return (p - a["knee"]) @ a["dir"] / np.linalg.norm(a["ankle"] - a["knee"])


def v_half(y):
    return V_HALF * np.clip((y - V_BOTTOM) / (1.40 - V_BOTTOM), 0, 1) ** 0.6


def in_v(p):
    return (p[:, 2] > ZC) & (p[:, 1] > V_BOTTOM) & (np.abs(p[:, 0]) < v_half(p[:, 1]))


def opening(q):
    """Borde del cuello y de la V: delante, en |x| = v_half(y); si no, en el plano del cuello."""
    q = q.copy()
    ny = sud.neck_plane_y(q[:, 2])
    front = (q[:, 2] > ZC + 0.02) & (q[:, 1] < ny - 0.015)
    q[front, 0] = np.sign(q[front, 0]) * v_half(q[front, 1])
    q[~front, 1] = ny[~front]
    return q


def leg_plane(s):
    a = LEG[s]
    p0 = a["knee"] + a["dir"] * LEG_CUT * np.linalg.norm(a["ankle"] - a["knee"])
    return lambda q: q - np.outer((q - p0) @ a["dir"], a["dir"])


# ---------------- 1. piel copiada ----------------
def select_region():
    keep = (P0[:, 1] <= sud.neck_plane_y(P0[:, 2])) & ~in_v(P0) & ~sud.hand_like & ~FOOT_LIKE & \
        (sud.main_bone != "Head")
    for s in SIDES:
        side = np.sign(P0[:, 0]) == SIDES[s]
        keep &= ~(side & (sud.arm_w > 0.5) & (ch.arm_t(P0, s) > ch.T_CUT))
        keep &= ~(side & (LEG_W > 0.5) & (leg_t(P0, s) > LEG_CUT))
    faces = F0[keep[F0].all(1)]
    n = len(P0)
    adj = coo_matrix((np.ones(len(faces) * 3), (faces.ravel(), np.roll(faces, 1, 1).ravel())), (n, n))
    _, lab = connected_components(adj, directed=False)
    big = np.bincount(lab[np.unique(faces)]).argmax()
    faces = faces[lab[faces[:, 0]] == big]
    verts = np.unique(faces)
    remap = -np.ones(n, int); remap[verts] = np.arange(len(verts))
    return verts, remap[faces]


def separate_legs(v, x0, y0):
    m = (np.abs(x0) > 0.015) & (y0 < 0.88)
    sx = np.sign(x0[m])
    v[m, 0] = sx * np.maximum(sx * v[m, 0], LEG_GAP)
    return v


def build_shell():
    idx, f = select_region()
    v = P0[idx].copy()
    kinds = {}
    for lp in sud.boundary_loops(f):
        c = v[lp].mean(0)
        side = "Left" if c[0] > 0 else "Right"
        if abs(c[0]) > 0.2 and c[1] > 0.9:
            kinds["wrist_" + side] = lp
        elif c[1] < 0.5:
            kinds["leg_" + side] = lp
        elif "neck" not in kinds or len(lp) > len(kinds["neck"]):
            kinds["neck"] = lp
    assert len(kinds) == 5, list(kinds)
    planes = {"neck": opening, "wrist_Left": ch.wrist_plane("Left"), "wrist_Right": ch.wrist_plane("Right"),
              "leg_Left": leg_plane("Left"), "leg_Right": leg_plane("Right")}
    aw, lw = sud.arm_w[idx], LEG_W[idx]
    t_arm, t_leg = np.zeros(len(v)), np.zeros(len(v))
    for s in SIDES:
        side = np.sign(v[:, 0]) == SIDES[s]
        a, g = ARM[s], LEG[s]
        ta = np.clip((v - a["upper"]) @ (a["hand"] - a["upper"]) / np.sum((a["hand"] - a["upper"]) ** 2), 0, 1)
        tl = np.clip((v - g["hip"]) @ (g["ankle"] - g["hip"]) / np.sum((g["ankle"] - g["hip"]) ** 2), 0, 1)
        t_arm[side], t_leg[side] = ta[side], tl[side]
    off_arm = ch.OFF_SHOULDER + (ch.OFF_FORE - ch.OFF_SHOULDER) * np.clip((t_arm - 0.35) / 0.45, 0, 1) ** 1.5
    off_leg = OFF_THIGH + (OFF_CALF - OFF_THIGH) * np.clip((t_leg - 0.3) / 0.5, 0, 1)
    rest = np.clip(1 - aw - lw, 0, 1)
    off = OFF_TORSO * rest + aw * off_arm + lw * off_leg
    near_neck = np.clip((sud.neck_plane_y(v[:, 2]) - v[:, 1]) / 0.06, 0, 1)
    off = OFF_NECK + (off - OFF_NECK) * near_neck
    nrm = sud.vertex_normals(v, f)
    x0, y0 = v[:, 0].copy(), v[:, 1].copy()
    v = separate_legs(v + nrm * off[:, None], x0, y0)
    fixed = np.zeros(len(v), bool)
    for k, lp in kinds.items():
        v[lp] = planes[k](v[lp]); fixed[lp] = True
    skin0 = P0[idx]

    def keep_out(v):
        proj = np.einsum("ij,ij->i", v - skin0, nrm)
        return separate_legs(v + nrm * np.maximum(0.5 * off - proj, 0)[:, None], x0, y0)

    for _ in range(5):
        v = keep_out(sud.taubin(v, f, fixed, 10))
    for k, lp in kinds.items():
        if k != "neck":
            v = sud.smooth_loop(v, lp, 10, planes[k])
    return idx, v, f, kinds


# ---------------- 2. puños de las piernas ----------------
def leg_end(v, lp, s):
    """Del corte de la pantorrilla: la pernera sigue abombada, se recoge y acaba en un puño ceñido al tobillo."""
    a = LEG[s]
    axis = a["dir"]
    llen = np.linalg.norm(a["ankle"] - a["knee"])
    p0 = a["knee"] + axis * LEG_CUT * llen
    top = sud.resample_ring(v[sud.loop_ring_order(v, lp, p0, axis)], 64)
    c0 = top.mean(0)
    d = top - c0; d -= np.outer(d @ axis, axis)
    r0 = np.linalg.norm(d, axis=1); u = d / r0[:, None]
    end = a["ankle"] - axis * 0.012
    length = (end - c0) @ axis
    side = np.sign(P0[:, 0]) == SIDES[s]
    ax = (P0 - end) @ axis
    near = P0[side & (LEG_W > 0.5) & ~FOOT_LIKE & (ax > -CUFF_LEN - 0.01) & (ax < 0.005)]
    rel = near - end; rel -= np.outer(rel @ axis, axis)
    rc = np.linalg.norm(rel, axis=1).max() + CUFF_GAP
    cuff = 1 - CUFF_LEN / length
    steps = [(0.0, r0), (0.25, r0 * 1.04), (cuff - 0.18, r0 * 0.88), (cuff - 0.04, rc + 0.007 + 0 * r0),
             (cuff, rc + 0 * r0), (1.0, rc + 0 * r0)]                    # anillos 0-3 pernera, 4-5 puño
    return [c0 + axis * (length * t) + u * np.broadcast_to(r, r0.shape)[:, None] for t, r in steps], 4


# ---------------- 3. cremallera y franjas ----------------
def zipper(shell, f, loop):
    """Dos cintas a lo largo de la V abierta y el cursor abajo, en la pelvis."""
    n = sud.vertex_normals(shell, f)
    ny = sud.neck_plane_y(shell[loop, 2])
    m = (shell[loop, 2] > ZC + 0.02) & (shell[loop, 1] < ny - 0.006)
    parts = []
    for r in tr.runs(m, True):
        p, nn = tr.resample(shell[loop[r]], n[loop[r]], 0.004)
        parts.append(tr.sweep(p, nn, tr.rect(-0.0005, 0.0020, 0.0045)))
    low = shell[loop][m]
    bottom = low[np.argmin(low[:, 1])]
    nb = n[loop][m][np.argmin(low[:, 1])]
    path = np.array([bottom + [0, 0.012, 0], bottom + [0, -0.004, 0]])
    parts.append(tr.sweep(path, np.tile(nb, (2, 1)), tr.rect(0.001, 0.005, 0.007)))       # cursor
    tab = np.array([bottom + [0, -0.004, 0], bottom + [0, -0.032, 0]])
    parts.append(tr.sweep(tab, np.tile(nb, (2, 1)), tr.rect(0.004, 0.0055, 0.0035)))      # tirador
    return parts


def stripes(shell, f):
    """Franjas: trozos de la cara de fuera recortados por planos, separados 1 mm y con grosor."""
    nrm = sud.vertex_normals(shell, f)
    parts = []
    for st in STRIPES:
        s = st["side"]
        for k in range(2):
            c = st["c"] + k * STRIPE_STEP
            V, G, n = shell.copy(), f.copy(), nrm.copy()
            for fn in (lambda v, n: v[:, 1] - STRIPE_SLOPE * s * v[:, 0] - c - STRIPE_W / 2,
                       lambda v, n: c - STRIPE_W / 2 - (v[:, 1] - STRIPE_SLOPE * s * v[:, 0]),
                       lambda v, n: 0.35 - (n[:, 2] + 0.6 * s * n[:, 0]),
                       lambda v, n: 0.03 - s * v[:, 0],
                       lambda v, n: st["y"][0] - v[:, 1],
                       lambda v, n: v[:, 1] - st["y"][1]):
                V, G, n = tr.clip_with(V, G, fn(V, n), n)
            if len(G):
                nn = sud.vertex_normals(V, G)
                parts.append(tr.thick_sheet(V + nn * 0.0012, G, thick=0.0010, K=2)[:2])
    return parts


# ---------------- 4. montaje ----------------
def build_suit():
    idx, shell, f_shell, loops = build_shell()
    verts, faces, zones, src_idx, src_w = [], [], [], [], []

    def add(v, f, zone="kigurumi", skin_idx=None, near_mask=None):
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
    add(shell - shell_n * ch.THICK, f_shell[:, ::-1], skin_idx=idx)
    no_head = sud.main_bone != "Head"
    ends = []
    for s in SIDES:
        a, g = ARM[s], LEG[s]
        rings, k = ch.sleeve_end(shell, loops["wrist_" + s], s)
        ends.append((rings, k, lambda c, a=a: a["lower"] + np.outer((c - a["lower"]) @ a["dir"], a["dir"]),
                     (np.sign(P0[:, 0]) == SIDES[s]) & no_head & (sud.arm_w > 0.5)))
        rings, k = leg_end(shell, loops["leg_" + s], s)
        ends.append((rings, k, lambda c, g=g: g["knee"] + np.outer((c - g["knee"]) @ g["dir"], g["dir"]),
                     (np.sign(P0[:, 0]) == SIDES[s]) & (LEG_W > 0.5)))
    for rings, k, axis_pts, mask in ends:
        vs, fs = sud.orient(rings, axis_pts)
        cen = np.array([r.mean(0) for r in rings])
        vsi = np.concatenate([r - (r - c) / np.linalg.norm(r - c, axis=1, keepdims=True) * ch.THICK
                              for r, c in zip(rings, cen)])
        cuff = np.repeat(np.arange(len(rings)) >= k, len(rings[0]))
        zone = np.array([ZONES["punos"] if c else ZONES["kigurumi"] for c in cuff])
        add(vs, fs, zone, near_mask=mask)
        add(vsi, fs[:, ::-1], zone, near_mask=mask)
    for part in zipper(shell, f_shell, loops["neck"]):
        add(*part, "cremallera", near_mask=no_head & (sud.arm_w < 0.3) & (LEG_W < 0.5))
    for part in stripes(shell, f_shell):
        add(*part, "franjas", near_mask=LEG_W > 0.3)
    import generar_capucha
    for part, zone, mask in generar_capucha.parts(shell, loops["neck"]):
        add(*part, zone, near_mask=mask)
    v, f = np.concatenate(verts), np.concatenate(faces)
    v, f = sud.bridge_open(v, f)                                      # bordes: fuera ↔ dentro
    return write(v, f, np.concatenate(zones), np.concatenate(src_idx), np.concatenate(src_w), "kigurumi_conejo"), shell


def write(v, f, zc, si, sw, pid):
    joints, weights = sud.blend_weights(si, sw)
    targets = {}
    for name, d in sud.B["targets"].items():
        moved = (d[si] * sw[..., None]).sum(1)
        if np.abs(moved).max() >= 0.0005:
            targets[name] = moved.astype(np.float32)
    to_rig = np.array([tr.RIG_JN.index(n) if n in tr.RIG_JN else -1 for n in sud.JN])
    jr = to_rig[joints]
    weights = np.where(jr < 0, 0, weights); weights /= weights.sum(1, keepdims=True)
    jr = np.where(jr < 0, 0, jr)
    path = OUT / (pid + ".glb")
    sha = tr.write_glb(path, v, sud.vertex_normals(v, f), f, jr, weights, targets, pid, zc)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        pid, len(v), len(f), len(targets), path.stat().st_size / 1e6))
    return sha


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sha, _ = build_suit()
    cards = [tr.card("kigurumi_conejo", "Kigurumi de conejito", sha, [0.93, 0.45, 0.62], "ropa", "ropa_exterior",
                     ["pelo"])]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_kigurumis", "nombre": "Kigurumis (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
