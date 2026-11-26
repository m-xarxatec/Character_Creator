"""Zapatillas altas negras (plano: planos/Plancha técnica de zapatillas altas negras.webp).

Uso:  python generar_zapatillas.py   (en Linux: ~/.venvs/gamemolde_assets/bin/python generar_zapatillas.py)
Escribe packs/claude_zapatillas/: zapatillas_altas, el par en **una sola pieza**, ranura «ropa_pies» (no quita nada:
como las botas medievales, van con shorts, mallas y trajes ceñidos; un pantalón holgado asomará, ver P en
plan_assets.md). Sin el parche redondo con estrella del plano: es el logotipo de una marca.
- Lona: la piel del pie y del tobillo copiada e hinchada (pesos y formas por índice: sigue a cualquier edición del
  cuerpo), con grosor. **Grandes, al estilo VTuber** (más que las botas): caña hasta 10 cm sobre el tobillo, a 1,4 cm
  de la piel; pie a 1,4 cm; puntera 3,4 cm más larga que los dedos con la forma del plano (cúpula, no la del pie); planta plana
  (sin el arco) y suela casi convexa. SIZE escala todo lo «grande» a la vez.
- Suela de plataforma con pared alta (sube en la punta) y una franja; puntera de goma encima de la lona.
- Lengüeta que asoma por arriba, siete pares de ojales con cordones cruzados, dos ojales de ventilación por dentro
  y tira en el talón.
Zonas en COLOR_0: (0,0,0) lona; r = 1 goma (suela y puntera); g = 1 cordones; r = g = 1 ojales; b = 1 franja.
"""
import json, math, sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje", "claude_casco", "claude_eva", "claude_botas_medievales"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_sudadera as sud
import generar_traje as tr
import generar_casco as casco
import generar_eva as eva
import generar_botas as bt

OUT = HERE / "packs" / "claude_zapatillas"
PID = "zapatillas_altas"

# --- medidas (metros); t: a lo largo de la pierna, 0 rodilla y 1 tobillo ---
SIZE = 1.0                                  # lo «grande»: holguras, puntera y suela
TOP_T = 0.74                                # boca de la caña (unos 10 cm sobre el tobillo)
OFF_SHAFT, OFF_FOOT, OFF_UNDER = 0.014 * SIZE, 0.014 * SIZE, 0.004
TOE_EXTRA, TOE_PUFF = 0.034 * SIZE, 0.014 * SIZE
TOE_P, TOE_DOME = 2.6, 0.004                # puntera: sección supereléptica y cúpula algo más alta que el pie
THICK = 0.003
SOLE_OUT, SOLE_Y0, SOLE_Y1, TOE_RISE = 0.007 * SIZE, -0.004, 0.030 * SIZE, 0.010 * SIZE
STRIPE_Y, STRIPE_H = 0.008 * SIZE, 0.0025 * SIZE
EYELETS = 7

P0, SIDES, LEG = sud.P0, sud.SIDES, bt.LEG
ZONES = {"lona": (0, 0, 0, 1), "goma": (1, 0, 0, 1), "cordones": (0, 1, 0, 1), "ojales": (1, 1, 0, 1),
         "franja": (0, 0, 1, 1)}
LOWER_W, FOOT_W = bt.LOWER_W, bt.FOOT_W
side_of, leg_t = bt.side_of, bt.leg_t


def unit(x):
    return x / np.linalg.norm(x)


# ---------------- 1. lona ----------------
def select_region():
    keep = np.zeros(len(P0), bool)
    for s in SIDES:
        keep |= side_of(P0, s) & (np.abs(P0[:, 0]) > 0.01) & (leg_t(P0, s) > TOP_T) & (LOWER_W + FOOT_W > 0.5)
    faces = sud.F0[keep[sud.F0].all(1)]
    verts = np.unique(faces)
    remap = -np.ones(len(P0), int); remap[verts] = np.arange(len(verts))
    return verts, remap[faces]


def toe_factor(v, idx):
    k = np.zeros(len(v))
    for s in SIDES:
        m = side_of(v, s) & (FOOT_W[idx] > 0.3)
        z_ball, z_tip = LEG[s]["toes"][2] - 0.03, P0[idx][m, 2].max()
        k[m] = eva.smoothstep((v[m, 2] - z_ball) / (z_tip - z_ball))
    return k


def offsets(idx, v, nrm):
    fw = FOOT_W[idx]
    puff = TOE_PUFF * toe_factor(v, idx) * (1 - np.clip(nrm[:, 1], 0, 1))      # la punta crece a lo ancho, no hacia arriba
    foot = np.where(nrm[:, 1] < -0.5, OFF_UNDER, OFF_FOOT + puff)
    return OFF_SHAFT * (1 - fw) + foot * fw


def top_plane(s):
    g = LEG[s]
    p0 = g["knee"] + g["dir"] * TOP_T * g["len"]
    return lambda q: q - np.outer((q - p0) @ g["dir"], g["dir"])


def toe_box(v, idx, floor):
    """Puntera del plano, sin la forma del pie: desde la parte ancha del pie hacia delante, una cúpula de sección
    supereléptica (ancho y alto los de esa parte del pie) que baja en elipse hasta la punta. Detrás se mezcla con la
    lona en 3,5 cm."""
    for s in SIDES:
        g = LEG[s]
        fwd = unit(g["fwd"] * [1, 0, 1])
        side = np.cross([0, 1.0, 0], fwd)
        m = side_of(v, s) & (FOOT_W[idx] > 0.1)
        zz, xx = v[m] @ fwd, v[m] @ side
        z0 = g["toes"] @ fwd - 0.005
        sl = np.abs(zz - z0) < 0.004
        cx, W = 0.5 * (xx[sl].min() + xx[sl].max()), 0.5 * (xx[sl].max() - xx[sl].min())
        H = v[m][sl, 1].max() - floor + TOE_DOME
        L = zz.max() - z0
        C = cx * side + z0 * fwd + np.array([0, floor, 0])
        d = v[m] - C
        a, b = d @ side / W, np.clip(d[:, 1], 0, None) / H
        ahead = np.clip(d @ fwd, 0, None)
        F = np.sqrt((np.abs(a) ** TOE_P + b ** TOE_P) ** (2 / TOE_P) + (ahead / L) ** 2)
        along = np.outer(d @ fwd, fwd)
        across = d - along
        F = np.maximum(F, 0.3)
        box = C + across / F[:, None] + along / F[:, None] * (ahead > 0)[:, None] + along * (ahead <= 0)[:, None]
        w = eva.smoothstep((zz - (z0 - 0.035)) / 0.035) * eva.smoothstep(d[:, 1] / 0.008)   # la planta no se toca
        v[m] = v[m] + (box - v[m]) * w[:, None]
    return v


def build_shell():
    idx, f = select_region()
    loops = sud.boundary_loops(f)
    assert len(loops) == 2, [len(l) for l in loops]
    skin0 = P0[idx]
    nrm = sud.vertex_normals(skin0, f)
    off = offsets(idx, skin0, nrm)
    k = toe_factor(skin0, idx)
    foot = FOOT_W[idx] > 0.3
    last = sud.taubin(skin0.copy(), f, ~foot, 80)                    # horma: el pie muy alisado, sin dedos
    v = last + sud.vertex_normals(last, f) * off[:, None]
    for s in SIDES:                                                  # puntera: más larga hacia delante
        m = side_of(v, s)
        v[m] += np.outer(k[m] * TOE_EXTRA, LEG[s]["fwd"] * [1, 0, 1])
    tops = {("Left" if skin0[lp, 0].mean() > 0 else "Right"): lp for lp in loops}
    fixed = np.zeros(len(v), bool)
    for s, lp in tops.items():
        v[lp] = top_plane(s)(v[lp]); fixed[lp] = True
    under = foot & (nrm[:, 1] < -0.3)
    floor = 0.003

    def keep_out(v, k=0.75):
        proj = np.einsum("ij,ij->i", v - skin0, nrm)
        v = v + nrm * np.maximum(k * off - proj, 0)[:, None]
        v[under, 1] = np.minimum(v[under, 1], floor)                 # planta plana: sin el arco del pie
        return v

    for _ in range(4):
        v = keep_out(sud.taubin(v, f, fixed, 8))
    for _ in range(14):                                              # sin la forma de los dedos
        v = keep_out(sud.taubin(v, f, fixed | ~foot, 12), np.where(foot, 0.0, 0.75))
    v = sud.taubin(v, f, fixed | ~foot, 6)                           # el último empuje deja picos: alisarlos
    v[under, 1] = np.minimum(v[under, 1], floor)
    v = toe_box(v, idx, floor)
    v = sud.taubin(v, f, fixed | ~foot, 3)
    v[under, 1] = np.minimum(v[under, 1], floor)
    for s, lp in tops.items():
        v = sud.smooth_loop(v, lp, 10, top_plane(s))
    return idx, v, f


# ---------------- 2. suela, franja y puntera ----------------
def sole_outline(shell, s, n=72):
    pts = shell[side_of(shell, s) & (shell[:, 1] < 0.04)]
    c = pts[:, [0, 2]].mean(0)
    d = pts[:, [0, 2]] - c
    ang = np.arctan2(d[:, 0], d[:, 1])                               # 0 = delante (+z)
    bins = ((ang + math.pi) / (2 * math.pi) * n).astype(int) % n
    r = np.array([np.linalg.norm(d[bins == b], axis=1).max() if (bins == b).any() else np.nan for b in range(n)])
    k = np.arange(n); ok = ~np.isnan(r)
    r = np.interp(k, np.r_[k[ok] - n, k[ok], k[ok] + n], np.tile(r[ok], 3))
    for _ in range(2):
        r = 0.5 * r + 0.25 * (np.roll(r, 1) + np.roll(r, -1))
    full = r.copy()                                                  # sin la cintura del arco: casi convexa
    for _ in range(4):
        for j in range(1, 13):
            a, b = np.roll(full, j), np.roll(full, -j)
            full = np.maximum(full, 2 * a * b * math.cos(2 * math.pi * j / n) / (a + b))
    r = r + 0.85 * (full - r)
    th = (k + 0.5) / n * 2 * math.pi - math.pi
    return c, r, th


def sole(shell, s):
    c, r, th = sole_outline(shell, s)
    n = len(r)
    front = eva.smoothstep((np.cos(th) - 0.55) / 0.35)
    u = np.c_[np.sin(th), np.cos(th)]
    ro, ri = r + SOLE_OUT, r - 0.010
    y1 = SOLE_Y1 + TOE_RISE * front

    def ring(rr, y):
        xz = c + u * rr[:, None]
        return np.c_[xz[:, 0], np.broadcast_to(y, n), xz[:, 1]]

    hs = np.linspace(0, 1, 6)
    rings = [ring(ro - 0.0015 * (h == 0), SOLE_Y0 + h * (y1 - SOLE_Y0)) for h in hs] + [ring(ri, y1)]
    R = len(rings)
    v = np.vstack(rings + [[c[0], SOLE_Y0, c[1]], [c[0], y1.min(), c[1]]])
    f = []
    i = np.arange(n)
    for j in range(R - 1):
        a, b = j * n + i, j * n + (i + 1) % n
        f += list(np.stack([a, b, a + n], -1)) + list(np.stack([b, b + n, a + n], -1))
    c0, c1 = R * n, R * n + 1
    f += list(np.stack([np.full(n, c0), (i + 1) % n, i], -1))
    f += list(np.stack([np.full(n, c1), (R - 1) * n + i, (R - 1) * n + (i + 1) % n], -1))
    return tr.orient_closed(v, np.array(f))


def stripe(sole_v, s):
    c = sole_v[-2] * [1, 0, 1] + [0, STRIPE_Y, 0]
    return eva.band(sole_v[:-2], np.ones(len(sole_v) - 2, bool), c, [0, 1.0, 0], STRIPE_H,
                    eva.bevel_prof(STRIPE_H, 0.0010, inner=-0.0010, b=0.0006), n=72)


def toe_cap(shell, f, nrm, idx):
    """Puntera de goma: la lona de delante y abajo, despegada hasta 1,8 mm; en el borde baja hasta la lona (sin
    escalón dentado)."""
    phi = np.full(len(shell), -1.0)
    for s in SIDES:
        m = side_of(shell, s) & (FOOT_W[idx] > 0.3)
        z0 = shell[m, 2].max() - 0.050 * SIZE
        y_top = SOLE_Y1 + 0.022 * SIZE * eva.smoothstep((shell[m, 2] - z0) / (0.03 * SIZE))
        phi[m] = np.minimum(shell[m, 2] - z0, y_top - shell[m, 1]) / 0.008
    fc = f[(phi[f] > -0.3).all(1)]
    vs = np.unique(fc)
    remap = -np.ones(len(shell), int); remap[vs] = np.arange(len(vs))
    lift = 0.0002 + 0.0016 * eva.smoothstep(phi[vs])
    return shell[vs] + nrm[vs] * lift[:, None], remap[fc], idx[vs]


# ---------------- 3. lengüeta, ojales, cordones y talón ----------------
def tongue(lr):
    s_, q = np.meshgrid(np.linspace(0, 1, 18), np.linspace(-1, 1, 14), indexing="ij")
    t0 = TOP_T - 0.045 + 0.030 * q ** 4                              # asoma por arriba, con las esquinas redondas
    t = t0 + s_ * (TOP_T + 0.16 - t0)
    a = q * 0.50
    r = lr(t, a) + 0.0012
    return bt.grid_slab(lr.point(t, a, r + 0.003), lr.point(t, a, r))


def heel_stay(lr, surf):
    s_, q = np.meshgrid(np.linspace(0, 1, 24), np.linspace(-1, 1, 5), indexing="ij")
    t = TOP_T + 0.01 + s_ * (0.99 - TOP_T)
    a = (math.pi + 0.11 * q + math.pi) % (2 * math.pi) - math.pi
    base, sn = eva.on_surface(surf, lr.point(t, a, lr(t, a)).reshape(-1, 3), 0.0004)
    return bt.grid_slab((base + sn * 0.0018).reshape(24, 5, 3), base.reshape(24, 5, 3))


def eyelet(p, n, size=1.0):
    ri, ro, h = 0.0021 * size, 0.0036 * size, 0.0008
    return casco.lathe([(ri, -h), (ro, -h), (ro, h), (ri, h)], p, n, 12)


def lace_points(shell, surf, s):
    """Pares de ojales (izquierda, derecha) a lo largo de la abertura: de arriba de la caña al empeine."""
    g = LEG[s]
    lr = bt.LegRadius(shell[side_of(shell, s) & (FOOT_W[surf.idx] < 0.5)], s)
    t_top = TOP_T + 0.035
    p_top = lr.point(np.array(t_top), np.array(0.0), lr(np.array([t_top]), np.array([0.0]))[0])
    foot = shell[side_of(shell, s) & (FOOT_W[surf.idx] > 0.3)]
    z_low = g["toes"][2] - 0.035
    row = foot[np.abs(foot[:, 2] - z_low) < 0.006]
    p_low = row[np.argmax(row[:, 1])]
    base = p_top + np.outer(np.linspace(0, 1, EYELETS), p_low - p_top)
    mid, nm = eva.on_surface(surf, base, 0.0)
    left, right = [], []
    for k in range(EYELETS):
        across = np.array([1.0, 0, 0]) - nm[k] * nm[k][0]
        across = unit(across)
        w = (0.0105 + 0.0025 * (1 - k / (EYELETS - 1))) * SIZE ** 0.5
        left.append(mid[k] + across * w); right.append(mid[k] - across * w)
    L, nl = eva.on_surface(surf, np.array(left), 0.0006)
    R, nr = eva.on_surface(surf, np.array(right), 0.0006)
    return (L, nl), (R, nr), lr


def lace(surf, a, b, high, n=14):
    pts = a + np.outer(np.linspace(0, 1, n), b - a)
    q, sn = eva.on_surface(surf, pts, 0.0)
    bump = np.sin(np.linspace(0, math.pi, n))
    lift = 0.0014 + (0.0008 + (0.0016 if high else 0.0)) * bump
    return eva.tube(q + sn * lift[:, None], sn, 0.0019 * SIZE ** 0.5, ribs=1.0, m=8)


class Shell(eva.Surface):
    def __init__(self, v, f, idx):
        super().__init__(v, f)
        self.idx = idx


# ---------------- 4. montaje y .glb ----------------
def build():
    idx, shell, f_shell = build_shell()
    verts, faces, zones, src_idx, src_w = [], [], [], [], []

    def add(v, f, zone, skin_idx=None, mask=None):
        v = np.asarray(v, float).reshape(-1, 3)
        faces.append(np.asarray(f, int) + sum(len(x) for x in verts))
        verts.append(v)
        zones.append(np.tile(ZONES[zone], (len(v), 1)))
        if skin_idx is not None:
            src_idx.append(np.c_[skin_idx, np.zeros((len(v), 7), int)])
            src_w.append(np.c_[np.ones(len(v)), np.zeros((len(v), 7))])
        else:
            i, w = sud.nearest_skin(v, 8, mask)
            src_idx.append(i); src_w.append(w)

    nrm = sud.vertex_normals(shell, f_shell)
    add(shell, f_shell, "lona", skin_idx=idx)
    add(shell - nrm * THICK, f_shell[:, ::-1], "lona", skin_idx=idx)
    cv, cf, ci = toe_cap(shell, f_shell, nrm, idx)
    add(cv, cf, "goma", skin_idx=ci)
    surf = Shell(shell, f_shell, idx)
    for s in SIDES:
        leg = side_of(P0, s) & ((LOWER_W > 0.3) | (FOOT_W > 0.3))
        foot = side_of(P0, s) & (FOOT_W > 0.3)
        sv, sf = sole(shell, s)
        add(sv, sf, "goma", mask=foot)
        add(*stripe(sv, s), "franja", mask=foot)
        (L, nl), (R, nr), lr = lace_points(shell, surf, s)
        add(*tongue(lr), "lona", mask=leg)
        add(*heel_stay(lr, surf), "lona", mask=leg)
        for k in range(EYELETS):
            add(*eyelet(L[k], nl[k]), "ojales", mask=leg)
            add(*eyelet(R[k], nr[k]), "ojales", mask=leg)
        add(*lace(surf, L[-1], R[-1], False), "cordones", mask=leg)            # abajo, recto
        for k in range(EYELETS - 1, 0, -1):                                    # cruzados hacia arriba
            add(*lace(surf, L[k], R[k - 1], False), "cordones", mask=leg)
            add(*lace(surf, R[k], L[k - 1], True), "cordones", mask=leg)
        # ventilación: dos ojales por dentro del pie
        g = LEG[s]
        inside = shell[side_of(shell, s) & (FOOT_W[idx] > 0.3)]
        for dz in (0.0, 0.016):
            z = g["ankle"][2] + 0.045 + dz
            row = inside[(np.abs(inside[:, 2] - z) < 0.005) & (inside[:, 1] > 0.045) & (inside[:, 1] < 0.065)]
            p = row[np.argmin(row[:, 0] * SIDES[s])]
            q, nn = eva.on_surface(surf, p[None], 0.0006)
            add(*eyelet(q[0], nn[0], 0.85), "ojales", mask=foot)
    v, f = np.concatenate(verts), np.concatenate(faces)
    v, f = sud.bridge_open(v, f)                                     # boca de la caña: fuera ↔ dentro
    return write(v, f, np.concatenate(zones), np.concatenate(src_idx), np.concatenate(src_w))


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
    sha = build()
    cards = [tr.card(PID, "Zapatillas altas negras", sha, [0.13, 0.13, 0.14], "ropa", "ropa_pies")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_zapatillas", "nombre": "Zapatillas (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
