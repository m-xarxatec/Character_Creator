"""Chaqueta cyberpunk (plano: planos/Chaqueta cyberpunk Harajuku_ hoja técnica neon.webp).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_chaqueta_cyber.py   (numpy y scipy)
Escribe packs/claude_chaqueta_cyber/: chaqueta_cyber, **una sola pieza**, ranura «ropa_exterior» (sustituye a la
sudadera; debajo se ve la ropa del torso). Reutiliza la chaqueta del traje rosa (../claude_traje/generar_chaqueta.py):
piel copiada e hinchada, con los pesos y las formas del cuerpo por índice.
- **Abierta delante** (decidido por el responsable): sin la piel de |x| < OPEN; los bordes, alisados sobre ese plano,
  con cremallera. Corta: el bajo a la cintura. Forro rosa.
- Mangas globo (se abomban en el antebrazo) que se recogen en un puño acanalado con franja rosa.
- Capucha bajada grande, levantada alrededor del cuello como un cuello alto, con forro rosa.
- Cinturón en el pecho que cruza la abertura, con hebilla y dos anillas en D; correas rosas delante que bajan del
  hombro y **cuelgan hasta la cadera** (decidido por el responsable: largas cruzarían las piernas) con hebilla de clip
  y puntera; dos cintas cortas que cuelgan detrás.
- Bolsillo con solapa y X rosa en cada antebrazo; kanji 東京 en relieve en la manga izquierda (el único dibujo del
  plano que se hace, decidido por el responsable).
Zonas en COLOR_0: (0,0,0) negro; r = 1 rosa (forro, correas, franjas, X); g = 1 metal (cremalleras, hebilla,
anillas, punteras); b = 1 kanji; r = g = 1 puños; r = b = 1 plástico (hebillas de clip).
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje", "claude_casco", "claude_eva", "claude_botas_medievales"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_sudadera as sud
import generar_traje as tr
import generar_chaqueta as chq
import generar_casco as casco
import generar_eva as eva
import generar_botas as bt

OUT = HERE / "packs" / "claude_chaqueta_cyber"
PID = "chaqueta_cyber"
P0, F0, SIDES, ARM = sud.P0, sud.F0, sud.SIDES, sud.ARM
ZC = chq.ZC
ZONES = {"negro": (0, 0, 0, 1), "rosa": (1, 0, 0, 1), "metal": (0, 1, 0, 1), "kanji": (0, 0, 1, 1),
         "punos": (1, 1, 0, 1), "plastico": (1, 0, 1, 1)}

# --- medidas (metros); las de la chaqueta rosa que cambian ---
chq.Y_BACK, chq.Y_FRONT = 1.06, 1.09            # bajo a la cintura (delante sube un poco)
chq.T_CUT = 0.35                                # la piel copiada del antebrazo acaba aquí (0 codo, 1 muñeca)
chq.OFF_TORSO, chq.OFF_SHOULDER, chq.OFF_FORE, chq.OFF_NECK = 0.024, 0.028, 0.060, 0.012
THICK = 0.003
OPEN = 0.07                                     # media abertura delante
CUFF_LEN, CUFF_GAP, CUFF_RIBS = 0.060, 0.007, 16
HOOD_DROP, HOOD_THICK = 0.13, 0.007
Y_BELT, BELT_H = 1.31, 0.013                    # cinturón del pecho: altura y media anchura
X_STRAP, STRAP_W, HANG = OPEN + 0.035, 0.024, 0.11   # correas rosas delante: x, ancho y lo que cuelgan bajo el bajo
X_BACK, HANG_BACK = 0.06, 0.10
KANJI_S, KANJI_W = 0.042, 0.0048

NO_HEAD = sud.main_bone != "Head"
LEG_W = sud.bone_weight([s + "UpperLeg" for s in SIDES])
TORSO = NO_HEAD & (sud.arm_w < 0.5) & (LEG_W < 0.3) & (P0[:, 1] > 0.9)
UPPER = NO_HEAD & (P0[:, 1] > 1.15) & (sud.arm_w < 0.5)


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


def arm_mask(s):
    return (np.sign(P0[:, 0]) == SIDES[s]) & NO_HEAD & (sud.arm_w > 0.5)


# ---------------- 1. piel copiada, abierta delante ----------------
def edge_plane(q):
    """Borde de la chaqueta: el bajo, la abertura (x = ±OPEN) o el cuello, según dónde esté cada punto."""
    q = q.copy()
    hy, ny = chq.hem_y(q[:, 0], q[:, 2]), sud.neck_plane_y(q[:, 2])
    front = (q[:, 2] > ZC) & (np.abs(q[:, 0]) < OPEN + 0.025) & (q[:, 1] > hy + 0.012) & (q[:, 1] < ny - 0.012)
    neck = ~front & (q[:, 1] > 0.5 * (hy + ny))
    q[front, 0] = np.sign(q[front, 0]) * OPEN
    q[neck, 1] = ny[neck]
    q[~front & ~neck, 1] = hy[~front & ~neck]
    return q


def build_shell():
    """Como chq.build_shell, pero sin la piel de la abertura: el cuello, la abertura y el bajo son un solo borde."""
    idx, f = chq.select_region()
    p = P0[idx]
    gap = (np.abs(p[:, 0]) < OPEN) & (p[:, 2] > ZC)
    f = f[~gap[f].any(1)]
    used = np.unique(f)
    remap = -np.ones(len(idx), int); remap[used] = np.arange(len(used))
    idx, f = idx[used], remap[f]
    v = P0[idx].copy()
    kinds = {}
    for lp in sud.boundary_loops(f):
        c = v[lp].mean(0)
        if abs(c[0]) > 0.2:
            kinds["wrist_" + ("Left" if c[0] > 0 else "Right")] = lp
        elif len(lp) > len(kinds.get("main", [])):
            kinds["main"] = lp
    assert {"wrist_Left", "wrist_Right", "main"} <= set(kinds), list(kinds)
    planes = {"main": edge_plane, "wrist_Left": chq.wrist_plane("Left"), "wrist_Right": chq.wrist_plane("Right")}
    aw = sud.arm_w[idx]
    t_w = np.zeros(len(v))
    for s, a in ARM.items():
        side = np.sign(v[:, 0]) == SIDES[s]
        t = np.clip((v - a["upper"]) @ (a["hand"] - a["upper"]) / np.sum((a["hand"] - a["upper"]) ** 2), 0, 1)
        t_w[side] = t[side]
    balloon = np.clip((t_w - 0.35) / 0.45, 0, 1) ** 1.5
    off = chq.OFF_TORSO * (1 - aw) + aw * (chq.OFF_SHOULDER + (chq.OFF_FORE - chq.OFF_SHOULDER) * balloon)
    near_neck = np.clip((sud.neck_plane_y(v[:, 2]) - v[:, 1]) / 0.06, 0, 1)
    off = chq.OFF_NECK + (off - chq.OFF_NECK) * near_neck
    nrm = sud.vertex_normals(v, f)
    v = v + nrm * off[:, None]
    fixed = np.zeros(len(v), bool)
    for k in ("wrist_Left", "wrist_Right", "main"):
        lp = kinds[k]
        v[lp] = planes[k](v[lp]); fixed[lp] = True
        v = sud.smooth_loop(v, lp, 20, planes[k])
    skin0 = P0[idx]

    def keep_out(v):
        proj = np.einsum("ij,ij->i", v - skin0, nrm)
        return v + nrm * np.maximum(0.5 * off - proj, 0)[:, None]

    for _ in range(4):
        v = keep_out(sud.taubin(v, f, fixed, 10))
    for k in ("wrist_Left", "wrist_Right", "main"):
        v[kinds[k]] = planes[k](v[kinds[k]])
        v = sud.smooth_loop(v, kinds[k], 10, planes[k])
    return idx, v, f, kinds


# ---------------- 2. mangas y capucha ----------------
def sleeve_end(v, lp, s):
    """Del corte del antebrazo: la manga sigue abombada, se recoge y acaba en un puño acanalado hasta la muñeca."""
    a = ARM[s]
    axis = a["dir"]
    flen = np.linalg.norm(a["hand"] - a["lower"])
    p0 = a["lower"] + axis * chq.T_CUT * flen
    n = 4 * CUFF_RIBS
    top = sud.resample_ring(v[sud.loop_ring_order(v, lp, p0, axis)], n)
    c0 = top.mean(0)
    d = top - c0; d -= np.outer(d @ axis, axis)
    r0 = np.linalg.norm(d, axis=1); u = d / r0[:, None]
    length = (a["hand"] - c0) @ axis
    side = np.sign(P0[:, 0]) == SIDES[s]
    wrist = P0[side & (sud.arm_w > 0.3) & (np.abs((P0 - a["hand"]) @ axis) < 0.05)]
    rel = wrist - a["hand"]; rel -= np.outer(rel @ axis, axis)
    rc = np.linalg.norm(rel, axis=1).max() + CUFF_GAP
    lb = length - CUFF_LEN                                                    # largo del globo (metros)
    assert lb > 0.04, lb
    rib = rc * (1 + 0.05 * np.cos(2 * math.pi * CUFF_RIBS * np.arange(n) / n))
    steps = [(0.0, r0), (0.35 * lb, r0 * 1.12), (0.65 * lb, r0 * 1.05), (lb - 0.014, r0 * 0.80),
             (lb - 0.004, rc + 0.010 + 0 * r0), (lb, rib)] + [(lb + CUFF_LEN * k / 3, rib) for k in (1, 2, 3)]
    rings = [c0 + axis * d + u * np.broadcast_to(r, r0.shape)[:, None] for d, r in steps]
    stripe_c = c0 + axis * (lb + 0.5 * CUFF_LEN)
    return rings, 5, stripe_c


def resample_open(pts, n):
    s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    t = np.linspace(0, s[-1], n)
    return np.stack([np.interp(t, s, pts[:, k]) for k in range(3)], 1)


def grid_faces(n, m):
    j, i = np.meshgrid(np.arange(n - 1), np.arange(m - 1), indexing="ij")
    a, b, c, d = j * m + i, j * m + i + 1, (j + 1) * m + i, (j + 1) * m + i + 1
    return np.concatenate([np.stack([a, c, b], -1).reshape(-1, 3), np.stack([b, c, d], -1).reshape(-1, 3)])


def hood(v, lp, m=64, rows=15):
    """Capucha bajada sobre el arco del cuello (de un borde de la abertura al otro), con grosor: fuera y forro."""
    q = v[lp]
    neck = lp[np.abs(q[:, 1] - sud.neck_plane_y(q[:, 2])) < 0.004]
    ang = np.arctan2(-v[neck, 0], -(v[neck, 2] - ZC))                 # 0 detrás; la abertura, cerca de ±180°
    base = resample_open(v[neck[np.argsort(ang)]], m)
    out = base - np.array([0, 0, ZC]); out[:, 1] = 0; out = unit(out)
    back = np.clip(-out[:, 2], 0, 1) ** 1.3
    side = np.abs(out[:, 0])
    rings = []
    for k in range(rows):
        t = k / (rows - 1)
        h = (0.035 + 0.050 * back) * math.sin(math.pi * min(t / 0.55, 1) / 2)
        w = (0.025 + 0.085 * back + 0.025 * side) * math.sin(math.pi * t / 2)
        drop = (0.010 + HOOD_DROP * back) * max(0, (t - 0.45) / 0.55) ** 1.5
        rings.append(base + out * w[:, None] + np.c_[np.zeros(m), h - drop, np.zeros(m)])
    outer = np.stack(rings)
    fg = grid_faces(rows, m)
    nrm = sud.vertex_normals(outer.reshape(-1, 3), fg)
    if np.einsum("ij,ij->", nrm, outer.reshape(-1, 3) - [0, 1.35, ZC]) < 0:
        nrm = -nrm
    inner = outer - (nrm * HOOD_THICK).reshape(outer.shape)
    hv, hf = bt.grid_slab(outer, inner)
    zones = np.vstack([np.tile(ZONES["negro"], (rows * m, 1)), np.tile(ZONES["rosa"], (rows * m, 1))])
    return hv, hf, zones


# ---------------- 3. detalles ----------------
def ribbon(q, n, width, h, lift):
    """Cinta plana (con tapas) por los puntos q, apoyada sobre la superficie de normales n."""
    keep = np.r_[True, np.linalg.norm(np.diff(q, axis=0), axis=1) > 5e-4]   # sin puntos repetidos
    q, n = q[keep], n[keep]
    return tr.sweep(q + n * lift, n, tr.rect(0, h, width / 2))


def surface_line(surf, shell, xs, ys, front=True):
    """Línea sobre la chaqueta por los (x, y) dados, alisada a lo largo (sin la ondulación de los vecinos)."""
    pts = np.array([chq.surface_point(shell, x, y, front) for x, y in zip(xs, ys)])
    for _ in range(6):
        pts[1:-1] = 0.5 * pts[1:-1] + 0.25 * (pts[:-2] + pts[2:])
    return smooth_line(*eva.on_surface(surf, pts, 0.0))


def smooth_line(q, n, iters=6):
    """Alisa una línea (y sus normales) a lo largo; los extremos no se mueven."""
    for _ in range(iters):
        q[1:-1] = 0.5 * q[1:-1] + 0.25 * (q[:-2] + q[2:])
        n[1:-1] = unit(0.5 * n[1:-1] + 0.25 * (n[:-2] + n[2:]))
    return q, n


def edge_line(shell, loop, s, y0, y1, n=40):
    """El borde de la abertura (lado s) entre y0 e y1."""
    e = shell[loop]
    e = e[(np.abs(e[:, 0] - s * OPEN) < 0.002) & (e[:, 2] > ZC) & (e[:, 1] > y0) & (e[:, 1] < y1)]
    e = e[np.argsort(-e[:, 1])]
    return resample_open(e, n)


def zippers(surf, shell, loop):
    out = []
    for s in (1, -1):
        e = edge_line(shell, loop, s, chq.hem_y(np.array([s * OPEN]), np.array([0.12]))[0] + 0.002, 1.37)
        q, n = smooth_line(*eva.on_surface(surf, e + [s * 0.004, 0, 0], 0.0))
        out.append(ribbon(q, n, 0.007, 0.0012, 0.0008))
        if s == 1:                                                    # tirador abajo
            b = q[-1] + n[-1] * 0.003 + [0, 0.004, 0]
            out.append(casco.box(b, np.array([0.004, 0.007, 0.0015]), np.array([1.0, 0, 0]),
                                 np.array([0, 1.0, 0]), n[-1]))
    return out


def side_release(c, n):
    """Hebilla de clip (plástico): cuerpo con dos alas y la lengüeta."""
    right = unit(np.cross([0, 1.0, 0], n))
    up = np.cross(n, right)
    return [casco.box(c + n * 0.004, np.array([0.016, 0.012, 0.004]), right, up, n),
            casco.box(c + n * 0.004 + up * 0.016, np.array([0.011, 0.006, 0.0035]), right, up, n)]


def hanging(p, n, length, w):
    """Correa que cuelga recta desde p (en el bajo); devuelve la cinta, la hebilla de clip y la puntera."""
    pts = p + np.outer(np.linspace(0, length, 12), [0, -1.0, 0])
    nn = np.tile(n, (len(pts), 1))
    strap = ribbon(pts, nn, w, 0.0016, 0.0)
    buck = side_release(p + np.array([0, -0.045, 0]), n)
    tip = casco.box(pts[-1] + n * 0.0015 + [0, 0.006, 0], np.array([w / 2 + 0.001, 0.007, 0.0022]),
                    unit(np.cross([0, 1.0, 0], n)), np.array([0, 1.0, 0]), n)
    return strap, buck, tip


def front_straps(surf, shell):
    """Correas rosas delante: del hombro al bajo sobre la chaqueta y luego cuelgan HANG."""
    pink, plastic, metal = [], [], []
    for s in (1, -1):
        x = s * X_STRAP
        y_hem = chq.hem_y(np.array([x]), np.array([0.12]))[0]
        ys = np.linspace(1.36, y_hem + 0.002, 30)
        q, n = surface_line(surf, shell, np.full(30, x), ys)
        pink.append(ribbon(q, n, STRAP_W, 0.0015, 0.0022))
        st, bk, tp = hanging(q[-1] + n[-1] * 0.001, unit(n[-1] * [1, 0, 1]), HANG, STRAP_W)
        pink.append(st); plastic += bk; metal.append(tp)
    return pink, plastic, metal


def back_straps(surf, shell):
    pink, plastic, metal = [], [], []
    for s in (1, -1):
        x = s * X_BACK
        y_hem = chq.hem_y(np.array([x]), np.array([-0.1]))[0]
        ys = np.linspace(y_hem + 0.05, y_hem + 0.002, 8)
        q, n = surface_line(surf, shell, np.full(8, x), ys, front=False)
        pink.append(ribbon(q, n, 0.020, 0.0015, 0.001))
        st, bk, tp = hanging(q[-1] + n[-1] * 0.001, unit(n[-1] * [1, 0, 1]), HANG_BACK, 0.020)
        pink.append(st); plastic += bk; metal.append(tp)
    return pink, plastic, metal


def belt(surf, shell):
    """Cinturón del pecho: sobre la chaqueta fuera de la abertura y recto por delante de ella; hebilla y anillas."""
    xs = np.linspace(-0.13, 0.13, 53)
    side = np.abs(xs) >= OPEN + 0.004
    Q = np.zeros((len(xs), 3)); N = np.zeros((len(xs), 3))
    for half in (side & (xs < 0), side & (xs > 0)):                   # cada lado por separado (se alisa a lo largo)
        Q[half], N[half] = surface_line(surf, shell, xs[half], np.full(half.sum(), Y_BELT))
    mid = ~side
    k0, k1 = np.where(mid)[0][[0, -1]] + [-1, 1]                      # los últimos puntos sobre la chaqueta
    t = (xs[mid] - xs[k0]) / (xs[k1] - xs[k0])
    bump = np.sin(math.pi * t)[:, None]                               # el puente se separa suave (sin saltos)
    Q[mid] = Q[k0] + np.outer(t, Q[k1] - Q[k0]) + bump * [0, 0, 0.003]
    N[mid] = unit(N[k0] + np.outer(t, N[k1] - N[k0]) + bump * [0, 0, 2.0])
    lift, h = 0.0035, 0.0025
    parts = {"negro": [ribbon(Q, N, 2 * BELT_H, h, lift)], "metal": []}
    c = Q[len(xs) // 2] + N[len(xs) // 2] * (lift + h)
    X, Y, Z = np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), np.array([0, 0, 1.0])
    L, W, b, hh = 0.013, 0.017, 0.0018, 0.0016
    for off, half in [(X * L, (b, W, hh)), (-X * L, (b, W, hh)), (Y * W, (L, b, hh)), (-Y * W, (L, b, hh)),
                      (np.zeros(3), (b * 0.7, W, hh * 0.8))]:
        parts["metal"].append(casco.box(c + off + Z * hh, np.array(half), X, Y, Z))
    ring = [(0.010 + 0.0016 * math.cos(b), 0.0016 * math.sin(b)) for b in np.linspace(0, 2 * math.pi, 8, endpoint=False)]
    for s in (1, -1):                                                 # anillas bajo el cinturón, en las correas
        q, n = eva.on_surface(surf, chq.surface_point(shell, s * X_STRAP, Y_BELT - BELT_H - 0.010)[None], 0.0)
        parts["metal"].append(casco.lathe(ring, q[0] + n[0] * 0.0062, n[0], 20))   # sobre la correa rosa
    return parts


def sleeve_frame(surf, shell, s, t, upper=False):
    """Punto de fuera de la manga (t a lo largo del brazo o del antebrazo) y su marco: arriba, hacia el hombro."""
    a = ARM[s]
    if upper:
        p = a["upper"] + (a["lower"] - a["upper"]) * t
        d = unit(a["lower"] - a["upper"])
    else:
        p = a["lower"] + a["dir"] * t * np.linalg.norm(a["hand"] - a["lower"])
        d = a["dir"]
    out = np.cross(d, [0, 0, 1.0]); out *= np.sign(out[0] * SIDES[s]); out = unit(out)
    _, i = cKDTree(shell).query(p + out * 0.15)
    n = surf.n[surf.kd.query(shell[i], k=6)[1]].mean(0); n = unit(n)
    up = unit(-d - n * (-d @ n))
    return shell[i], (n, up, np.cross(up, n))


def pocket(p, frame, w=0.058, hgt=0.074, depth=0.016, sink=0.006):
    """Bolsillo cargo rígido: caja hundida sink en la manga (la manga es curva), solapa arriba y X rosa delante."""
    n, up, right = frame
    c = p + n * (depth / 2 - sink)
    front = depth / 2
    body = [casco.box(c, np.array([w / 2, hgt / 2, depth / 2]), right, up, n)]
    flap = casco.box(c + up * (hgt / 2 - 0.013) + n * (front + 0.0015), np.array([w / 2 + 0.002, 0.015, 0.0025]),
                     right, up, n)
    xs = []
    for sg in (1, -1):
        a = math.atan2(hgt * 0.55, w * 0.75) * sg
        ex = math.cos(a) * right + math.sin(a) * up
        ey = -math.sin(a) * right + math.cos(a) * up
        xs.append(casco.box(c - up * 0.010 + n * (front + 0.0006), np.array([0.027, 0.0045, 0.0008]), ex, ey, n))
    return body + [flap], xs


# 東京: trazos en una caja de 0 a 1 (x a la derecha, y arriba)
KANJI = [
    [[(0.08, 0.82), (0.92, 0.82)], [(0.25, 0.70), (0.25, 0.38)], [(0.25, 0.70), (0.75, 0.70)], [(0.75, 0.70), (0.75, 0.38)],
     [(0.25, 0.54), (0.75, 0.54)], [(0.25, 0.38), (0.75, 0.38)], [(0.5, 0.97), (0.5, 0.02)],
     [(0.45, 0.38), (0.30, 0.22), (0.08, 0.08)], [(0.55, 0.38), (0.70, 0.22), (0.92, 0.08)]],
    [[(0.5, 0.98), (0.52, 0.88)], [(0.08, 0.84), (0.92, 0.84)], [(0.27, 0.72), (0.27, 0.48)], [(0.27, 0.72), (0.73, 0.72)],
     [(0.73, 0.72), (0.73, 0.48)], [(0.27, 0.48), (0.73, 0.48)], [(0.5, 0.48), (0.5, 0.05), (0.42, 0.12)],
     [(0.32, 0.36), (0.14, 0.16)], [(0.68, 0.36), (0.86, 0.16)]],
]


def kanji(surf, p, frame):
    out = []
    for k, char in enumerate(KANJI):
        oy = (0.5 - k) * (KANJI_S + 0.006)                           # 東 arriba (hacia el hombro), 京 abajo
        for stroke in char:
            s2 = (np.array(stroke) - 0.5) * KANJI_S + [0, oy]
            d0, d1 = unit(s2[1] - s2[0]), unit(s2[-1] - s2[-2])
            s2[0] -= d0 * KANJI_W / 2; s2[-1] += d1 * KANJI_W / 2        # las esquinas se tapan
            dense = np.vstack([np.linspace(a, b, 5, endpoint=False) for a, b in zip(s2[:-1], s2[1:])] + [s2[-1:]])
            q, qn = surf.place(p, dense, 0.0, frame)
            out.append(ribbon(q, qn, KANJI_W, 0.0012, 0.0008))
    return out


# ---------------- 4. montaje ----------------
def build():
    idx, shell, f_shell, loops = build_shell()
    verts, faces, zones, src_idx, src_w, layer = [], [], [], [], [], []

    def add(v, f, zone, skin_idx=None, mask=None, is_layer=False):
        v = np.asarray(v, float).reshape(-1, 3)
        faces.append(np.asarray(f, int) + sum(len(x) for x in verts))
        layer.append(is_layer)
        verts.append(v)
        zones.append(np.tile(ZONES[zone], (len(v), 1)) if isinstance(zone, str) else zone)
        if skin_idx is not None:
            src_idx.append(np.c_[skin_idx, np.zeros((len(v), 7), int)])
            src_w.append(np.c_[np.ones(len(v)), np.zeros((len(v), 7))])
        else:
            i, w = sud.nearest_skin(v, 8, mask)
            src_idx.append(i); src_w.append(w)

    shell_n = sud.vertex_normals(shell, f_shell)
    add(shell, f_shell, "negro", skin_idx=idx, is_layer=True)
    add(shell - shell_n * THICK, f_shell[:, ::-1], "rosa", skin_idx=idx, is_layer=True)
    surf = eva.Surface(shell, f_shell)
    for s in SIDES:
        rings, k_cuff, stripe_c = sleeve_end(shell, loops["wrist_" + s], s)
        a = ARM[s]
        axis_pts = lambda c, a=a: a["lower"] + np.outer((c - a["lower"]) @ a["dir"], a["dir"])
        vs, fs = sud.orient(rings, axis_pts)
        cen = np.array([r.mean(0) for r in rings])
        vsi = np.concatenate([r - (r - c) / np.linalg.norm(r - c, axis=1, keepdims=True) * THICK
                              for r, c in zip(rings, cen)])
        cuff = np.repeat(np.arange(len(rings)) >= k_cuff, len(rings[0]))
        zone = np.array([ZONES["punos"] if c else ZONES["negro"] for c in cuff])
        add(vs, fs, zone, mask=arm_mask(s), is_layer=True)
        add(vsi, fs[:, ::-1], zone, mask=arm_mask(s), is_layer=True)
        cuff_pts = np.concatenate(rings[k_cuff:])
        add(*eva.band(cuff_pts, np.ones(len(cuff_pts), bool), stripe_c, a["dir"], 0.008,
                      eva.bevel_prof(0.008, 0.0015, inner=-0.004, b=0.0008), n=4 * CUFF_RIBS), "rosa", mask=arm_mask(s))
        p, fr = sleeve_frame(surf, shell, s, 0.22)
        body, xs = pocket(p, fr)
        for pv in body:
            add(*pv, "negro", mask=arm_mask(s))
        for pv in xs:
            add(*pv, "rosa", mask=arm_mask(s))
    p, fr = sleeve_frame(surf, shell, "Left", 0.42, upper=True)
    for pv in kanji(surf, p, fr):
        add(*pv, "kanji", mask=arm_mask("Left"))
    hv, hf, hz = hood(shell, loops["main"])
    add(hv, hf, hz, mask=UPPER)
    for pv in zippers(surf, shell, loops["main"]):
        add(*pv, "metal", mask=TORSO)
    for fn in (front_straps, back_straps):
        pink, plastic, metal = fn(surf, shell)
        for pv in pink:
            add(*pv, "rosa", mask=TORSO)
        for pv in plastic:
            add(*pv, "plastico", mask=TORSO)
        for pv in metal:
            add(*pv, "metal", mask=TORSO)
    for zone, ps in belt(surf, shell).items():
        for pv in ps:
            add(*pv, zone, mask=TORSO)
    v = np.concatenate(verts)
    _, fl = sud.bridge_open(v, np.concatenate([x for x, k in zip(faces, layer) if k]))   # bordes de las capas: fuera ↔ dentro
    f = np.concatenate([fl] + [x for x, k in zip(faces, layer) if not k])
    check_fit(shell, idx)
    return v, f, np.concatenate(zones), np.concatenate(src_idx), np.concatenate(src_w)


def check_fit(shell, idx):
    """Hueco de la chaqueta a su piel (por índice) y del cinturón del pecho a la piel con el pecho más grande."""
    gap = np.linalg.norm(shell - P0[idx], axis=1) - THICK
    print("MEDIDA hueco a la piel: mínimo %.1f mm en %s" % (1000 * gap.min(), np.round(shell[gap.argmin()], 3)))
    d = sud.B["targets"]["breast_volume_incr"]
    skin = P0 + d
    m = TORSO & (np.abs(P0[:, 1] - Y_BELT) < 0.03) & (np.abs(P0[:, 0]) < OPEN + 0.01) & (P0[:, 2] > ZC)
    e = shell[(np.abs(shell[:, 1] - Y_BELT) < 0.012) & (np.abs(np.abs(shell[:, 0]) - OPEN) < 0.003) & (shell[:, 2] > ZC)]
    print("MEDIDA cinturón: z del puente %.3f; piel bajo él (pecho +) hasta z %.3f" % (e[:, 2].min(), skin[m, 2].max()))


def write(v, f, zc, si, sw):
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
    path = OUT / (PID + ".glb")
    sha = tr.write_glb(path, v, sud.vertex_normals(v, f), f, jr, weights, targets, PID, zc)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        PID, len(v), len(f), len(targets), path.stat().st_size / 1e6))
    return sha


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sha = write(*build())
    cards = [tr.card(PID, "Chaqueta cyberpunk", sha, [0.16, 0.12, 0.16], "ropa", "ropa_exterior")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_chaqueta_cyber",
            "nombre": "Chaqueta cyberpunk (pruebas)", "autor": "GameMolde", "licencia": "propia", "origen": "",
            "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
