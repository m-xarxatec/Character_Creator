"""Zapatillas futuristas (plano: planos/Ficha técnica de zapatillas futuristas.webp).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_zapatillas_futuristas.py
Escribe packs/claude_zapatillas_futuristas/: zapatillas_futuristas, el par en **una sola pieza**, ranura «ropa_pies».
La forma sale del plano, **no de la piel del pie**: una horma propia (caja del pie de sección supereléptica, con
punta redonda y talón recto, unida en suave a una caña elíptica alrededor de la pierna), medida sobre el cuerpo solo
para dejar holgura (pie a ≥ 1 cm, caña a 1,6 cm). La malla se saca con rayos desde un eje que baja por la pierna,
se curva en el tobillo y sigue hasta la punta (rejilla limpia, sin los dedos ni el arco del pie).
- Encima: paneles negros en relieve con canto (cuello acolchado, talón, galón lateral, ojales y dos franjas en
  diagonal sobre el empeine), lengüeta con lengüeta rosa, cinco pares de cordones cruzados, correa con hebilla.
- Suela de plataforma: cuña blanca con ranura, base negra con tacos que suben por la pared, puntera y franjas rosas.
- Tirador rosa detrás, pestaña rosa en el talón y un triángulo (adorno genérico, no logotipo) a cada lado y en la
  lengüeta.
Pesos y formas: los de la piel más cercana (sigue a cualquier edición del cuerpo). El pie derecho es el izquierdo
reflejado.
Zonas en COLOR_0: (0,0,0) negro; r = 1 blanco; g = 1 rosa; b = 1 metal (hebilla y triángulos); r = g = 1 cordones.
"""
import json, math, sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje", "claude_casco", "claude_eva", "claude_botas_medievales"):
    sys.path.insert(0, str(HERE.parent / d))
sys.path.insert(0, str(HERE))
import generar_sudadera as sud
import generar_traje as tr
import generar_casco as casco
import generar_eva as eva
import generar_botas as bt
import horma

OUT = HERE / "packs" / "claude_zapatillas_futuristas"
PID = "zapatillas_futuristas"
P0, SIDES = sud.P0, sud.SIDES
smooth = eva.smoothstep
ZONES = {"negro": (0, 0, 0, 1), "blanco": (1, 0, 0, 1), "rosa": (0, 1, 0, 1), "metal": (0, 0, 1, 1),
         "cordones": (1, 1, 0, 1)}

# --- horma (horma.py; pie izquierdo, metros): las medidas por defecto de Horma son las de estas zapatillas ---
H = horma.Horma()
FX, NA, J0 = H.fx, H.na, H.j0
leg_axis, collar_y, field, cast, build_shell, leg_ray_point = (H.leg_axis, H.collar_y, H.field, H.cast, H.build_shell,
                                                               H.leg_ray_point)
THICK, LINING_ROWS = 0.003, 28                                # forro: solo lo que se ve por la boca
# --- paneles negros ---
LIFT, PAD = 0.0016, 0.003                                     # relieve de los paneles; acolchado del cuello
COLLAR_H = 0.022
# --- suela ---
OUT_W, SOLE_Y0 = 0.007, -0.004
EYELETS = 5
Y_LACE_TOP, Z_LACE_LOW = 0.124, 0.112
TONGUE_Y0, TONGUE_TOP = 0.130, 0.181
STRAP_C, STRAP_K, STRAP_H = np.array([0.0, 0.080, 0.0]), 0.285, 0.009


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


# ---------------- 2. paneles negros en relieve ----------------
def collar_phi(p):
    xc, zc = leg_axis(p[:, 1])
    th = np.arctan2(p[:, 0] - xc, p[:, 2] - zc)
    yc = collar_y(th)
    return p[:, 1] - (yc - COLLAR_H), yc


def panel_phi(p, n):
    """> 0 dentro de algún panel negro (metros, aproximado)."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    lat = x - FX
    col, _ = collar_phi(p)
    heel = (0.010 - 0.30 * (y - 0.035)) - z
    d3 = z + 0.55 * np.abs(y - 0.072)
    chevron = np.minimum(d3 - 0.040, 0.088 - d3)
    d = z + 0.8 * y
    band_b = np.minimum(d - 0.162, 0.183 - d)
    band_a = np.minimum(d - 0.205, 0.226 - d)
    front = (n[:, 1] * 0.6 + n[:, 2] * 0.8 - 0.25) * 0.04
    eyestay = np.minimum(np.minimum(0.027 - np.abs(lat), front), 0.175 - d)
    return np.max([col, heel, chevron, band_b, band_a, eyestay], 0)


def sheet_lift(p):
    col, yc = collar_phi(p)
    return LIFT + PAD * smooth(col / 0.006) * smooth((yc - p[:, 1]) / 0.005)


def panels(v, f):
    """La horma partida por los bordes de los paneles: lo blanco se queda; lo negro se despega (relieve) y un canto
    lo une con el borde de lo blanco (sin capa doble)."""
    n = sud.vertex_normals(v, f)
    phi = panel_phi(v, n)
    phi[:NA] = np.maximum(phi[:NA], 0.001)                   # el cuello llega a la boca
    pv, pf = tr.clip(np.c_[v, n], f, -phi)
    pv, pn = pv[:, :3], unit(pv[:, 3:])
    top = pv + pn * sheet_lift(pv)[:, None]
    bnd = tr.boundary(pf)
    bv = np.unique(bnd)
    on_rim = bv[np.abs(pv[bv, 1] - collar_y(np.arctan2(pv[bv, 0] - leg_axis(pv[bv, 1])[0],
                                                       pv[bv, 2] - leg_axis(pv[bv, 1])[1]))) < 0.0015]
    edge = np.setdiff1d(bv, on_rim)
    low = pv[edge]                                           # el canto baja hasta el borde de lo blanco
    idx = -np.ones(len(pv), int); idx[edge] = len(pv) + np.arange(len(edge))
    V = np.vstack([top, low])
    keep = np.isin(bnd[:, 0], edge) & np.isin(bnd[:, 1], edge)
    a, b = bnd[keep, 0], bnd[keep, 1]
    F = np.concatenate([pf, np.stack([b, a, idx[a]], -1), np.stack([b, idx[a], idx[b]], -1)])
    wv, wf = tr.clip(v, f, phi)
    return (V, F), (wv, wf)


# ---------------- 3. suela ----------------
def outline(shell, n=96):
    pts = shell[(shell[:, 1] < 0.03) & (shell[:, 1] > -0.001)]
    c = 0.5 * (pts[:, [0, 2]].min(0) + pts[:, [0, 2]].max(0))
    d = pts[:, [0, 2]] - c
    ang = np.arctan2(d[:, 0], d[:, 1])
    bins = ((ang + math.pi) / (2 * math.pi) * n).astype(int) % n
    r = np.array([np.linalg.norm(d[bins == b], axis=1).max() if (bins == b).any() else np.nan for b in range(n)])
    k = np.arange(n); ok = ~np.isnan(r)
    r = np.interp(k, np.r_[k[ok] - n, k[ok], k[ok] + n], np.tile(r[ok], 3))
    for _ in range(3):
        r = np.maximum(r, 0.5 * r + 0.25 * (np.roll(r, 1) + np.roll(r, -1)))
    th = (k + 0.5) / n * 2 * math.pi - math.pi
    return Outline(c, th, r)


class Outline:
    """Contorno de la suela en planta: radio desde el centro c en cada ángulo (0 delante, +90° fuera)."""
    def __init__(self, c, th, r):
        self.c, self.th, self.r = c, th, r

    def radius(self, th):
        t = np.r_[self.th - 2 * math.pi, self.th, self.th + 2 * math.pi]
        return np.interp((np.asarray(th) + math.pi) % (2 * math.pi) - math.pi, t, np.tile(self.r, 3))

    def point(self, th, y, add):
        th = np.asarray(th, float)
        rr = self.radius(th) + add
        return np.stack([self.c[0] + np.sin(th) * rr, np.broadcast_to(y, th.shape), self.c[1] + np.cos(th) * rr], -1)

    def top(self, th):
        z = self.point(th, 0.0, 0.0)[..., 2]
        return 0.040 + 0.018 * smooth((0.05 - z) / 0.10) + 0.004 * smooth((z - 0.19) / 0.035)


def orient_out(v, f, ref):
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    bad = np.einsum("ij,ij->i", fn, v[f].mean(1) - ref) < 0
    f = f.copy(); f[bad] = f[bad][:, ::-1]
    return v, f


def rings_solid(ol, rings, cap_lo, cap_hi):
    """Sólido de anillos [(sobre el contorno, y)] cerrado con dos tapas."""
    th = ol.th
    v = [ol.point(th, y, a) for a, y in rings]
    n, R = len(th), len(rings)
    v = np.vstack(v + [[ol.c[0], cap_lo, ol.c[1]], [ol.c[0], cap_hi, ol.c[1]]])
    i = np.arange(n)
    f = [tr.ring_faces(R, n, False),
         np.stack([np.full(n, R * n), (i + 1) % n, i], -1),
         np.stack([np.full(n, R * n + 1), (R - 1) * n + i, (R - 1) * n + (i + 1) % n], -1)]
    return orient_out(v, np.concatenate(f), np.r_[ol.c[0], 0.5 * (cap_lo + cap_hi), ol.c[1]])


def midsole(ol):
    top = ol.top(ol.th)
    O = OUT_W
    rings = [(O - 0.0015, 0.006), (O, 0.009), (O, 0.024), (O - 0.0018, 0.0265), (O, 0.029), (O, top - 0.004),
             (O - 0.0012, top - 0.001), (O - 0.004, top), (-0.004, top)]
    v = [ol.point(ol.th, y, a) for a, y in rings]
    n, R = len(ol.th), len(rings)
    v = np.vstack(v + [[ol.c[0], 0.006, ol.c[1]], [ol.c[0], top.min() - 0.004, ol.c[1]]])
    i = np.arange(n)
    f = np.concatenate([tr.ring_faces(R, n, False), np.stack([np.full(n, R * n), (i + 1) % n, i], -1),
                        np.stack([np.full(n, R * n + 1), (R - 1) * n + i, (R - 1) * n + (i + 1) % n], -1)])
    return orient_out(v, f, np.r_[ol.c[0], 0.02, ol.c[1]])


def outsole(ol):
    O = OUT_W
    return rings_solid(ol, [(O - 0.001, SOLE_Y0), (O + 0.0015, SOLE_Y0 + 0.002), (O + 0.0015, 0.007),
                            (O + 0.0005, 0.0095), (O - 0.003, 0.0105)], SOLE_Y0, 0.0105)


def wall_slab(ol, th_of, y0, y1, a_out, a_in, nq=8, ny=6, top_bevel=0.0012):
    """Placa sobre la pared de la suela: th_of(q, y) da el ángulo (q de -1 a 1)."""
    q, y = np.meshgrid(np.linspace(-1, 1, nq), np.linspace(0, 1, ny), indexing="ij")
    yy = y0 + y * (np.asarray(y1) - y0) if np.ndim(y1) == 0 else y0 + y * (y1 - y0)
    th = th_of(q, yy)
    bev = top_bevel * smooth((y - 0.75) / 0.25)
    return bt.grid_slab(ol.point(th, yy, a_out - bev), ol.point(th, yy, a_in))


def sole_details(ol):
    parts = []
    O = OUT_W
    D = np.radians
    for c, hb, ht, yt in [(180, 14, 9, 0.024), (132, 9, 5, 0.021), (-132, 9, 5, 0.021), (104, 6, 3, 0.018),
                          (-104, 6, 3, 0.018), (52, 6, 3, 0.017), (-52, 6, 3, 0.017)]:
        def th_of(q, y, c=c, hb=hb, ht=ht, yt=yt):
            k = (y - 0.006) / (yt - 0.006)
            return D(c) + q * D(hb + (ht - hb) * k)
        parts.append((wall_slab(ol, th_of, 0.006, yt, O + 0.0018, O - 0.002), "negro"))
    for s in (1, -1):                                        # franja rosa a cada lado
        def th_of(q, y, s=s):
            top = ol.top(D(80 * s)) - 0.007
            k = (y - 0.014) / (top - 0.014)
            return s * (D(72) + D(13) * k) + q * D(8)
        top = ol.top(D(80 * s)) - 0.007
        parts.append((wall_slab(ol, th_of, 0.014, top, O + 0.0012, O - 0.002), "rosa"))
    # puntera rosa: delante, de abajo a casi arriba de la cuña
    def th_bump(q, y):
        return q * D(52)
    q = np.linspace(-1, 1, 15)
    y1 = 0.021 + 0.004 * (1 - q ** 2) - 0.006 * q ** 4
    qq, yy = np.meshgrid(q, np.linspace(0, 1, 7), indexing="ij")
    ys = SOLE_Y0 + 0.0005 + yy * (y1[:, None] - SOLE_Y0 - 0.0005)
    bev = 0.0014 * smooth((yy - 0.7) / 0.3)
    parts.append((bt.grid_slab(ol.point(th_bump(qq, ys), ys, O + 0.0034 - bev), ol.point(th_bump(qq, ys), ys, O - 0.002)),
                  "rosa"))
    parts += [(p, "rosa") for p in tread_pads(ol)]
    return parts


def tread_pads(ol):
    """Planta: almohadillas rosas en la punta y el talón (1 mm bajo la base)."""
    out = []
    for c, half, r0 in [(0.0, 0.85, 0.62), (math.pi, 0.80, 0.55)]:
        q, k = np.meshgrid(np.linspace(-1, 1, 17), np.linspace(0, 1, 5), indexing="ij")
        th = c + q * half
        rr = ol.radius(th) + OUT_W - 0.004
        rad = rr * (r0 + (1 - r0) * k) - 0.004 * (np.abs(q) ** 6)
        pt = np.stack([ol.c[0] + np.sin(th) * rad, 0 * th, ol.c[1] + np.cos(th) * rad], -1)
        lo, hi = pt.copy(), pt.copy()
        lo[..., 1], hi[..., 1] = SOLE_Y0 - 0.001, SOLE_Y0 + 0.0005
        out.append(bt.grid_slab(lo, hi))
    return out


# ---------------- 4. lengüeta, cordones, correa, tirador y adornos ----------------
def tongue():
    q, s = np.meshgrid(np.linspace(-1, 1, 13), np.linspace(0, 1, 16), indexing="ij")
    th = q * 0.45
    ytop = TONGUE_TOP - 0.012 * q ** 4
    y = TONGUE_Y0 + s * (ytop - TONGUE_Y0)
    yc = collar_y(th)
    base_lift = sheet_lift(leg_ray_point(y, th, 0.0)[0].reshape(-1, 3)).reshape(y.shape) + 0.0012
    flare = 0.009 * smooth((y - yc + 0.004) / 0.03)
    outer, d = leg_ray_point(y, th, base_lift + flare + 0.0025)
    inner, _ = leg_ray_point(y, th, base_lift + flare)
    tv, tf = bt.grid_slab(outer, inner)
    # lengüeta rosa arriba, con su triángulo
    q2, s2 = np.meshgrid(np.linspace(-1, 1, 9), np.linspace(0, 1, 8), indexing="ij")
    th2 = q2 * 0.27
    yt2 = TONGUE_TOP - 0.003 - 0.012 * (q2 * 0.6) ** 4
    y2 = yt2 - 0.026 + s2 * 0.026
    bl2 = sheet_lift(leg_ray_point(y2, th2, 0.0)[0].reshape(-1, 3)).reshape(y2.shape) + 0.0012
    fl2 = 0.009 * smooth((y2 - collar_y(th2) + 0.004) / 0.03)
    o2, _ = leg_ray_point(y2, th2, bl2 + fl2 + 0.0025 + 0.0014)
    i2, _ = leg_ray_point(y2, th2, bl2 + fl2 + 0.0020)
    tab = bt.grid_slab(o2, i2)
    c = o2[4, 4]
    nrm = unit(np.cross(o2[5, 4] - o2[3, 4], o2[4, 5] - o2[4, 3]))
    if nrm[2] < 0:
        nrm = -nrm
    return (tv, tf), tab, (c, nrm)


def tube_out(pts, up, r, m=8):
    """Tubo por pts con las caras hacia fuera: el costado, por mayoría; cada tapa, hacia su extremo."""
    v, f = eva.tube(pts, up, r, ribs=1.0, m=m)
    from scipy.spatial import cKDTree
    f = f.copy()
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    c = v[f].mean(1)
    side, cap0, cap1 = slice(0, len(f) - 2 * m), slice(len(f) - 2 * m, len(f) - m), slice(len(f) - m, len(f))
    _, k = cKDTree(pts).query(c[side])
    if np.einsum("ij,ij->", fn[side], c[side] - pts[k]) < 0:
        f[side] = f[side][:, ::-1]
    for sl, out in ((cap0, pts[0] - pts[1]), (cap1, pts[-1] - pts[-2])):
        if (fn[sl] @ out).sum() < 0:
            f[sl] = f[sl][:, ::-1]
    return v, f


def triangle_mark(c, n, size, lift=0.0006, r=0.0011, surf=None):
    up = np.array([0, 1.0, 0]) - n * n[1]; up = unit(up)
    right = np.cross(up, n)
    a = np.radians([90, 210, 330])
    corners = [c + size / math.sqrt(3) * (math.cos(t) * right + math.sin(t) * up) for t in a]
    pts = []
    for k in range(3):
        p, q = corners[k], corners[(k + 1) % 3]
        pts += list(p + np.outer(np.linspace(0, 1, 9, endpoint=False), q - p))
    pts = np.array(pts + [corners[0]])
    if surf is not None:
        pts, nn = eva.on_surface(surf, pts, lift)
    else:
        pts, nn = pts + n * lift, np.tile(n, (len(pts), 1))
    return tube_out(pts, nn, r, m=6)


def lace_points(v, surf):
    cl = v[:-1].reshape(-1, NA, 3)[:, J0]
    k0 = np.argmax(cl[:, 1] <= Y_LACE_TOP)
    k1 = np.argmax(cl[:, 2] >= Z_LACE_LOW)
    seg = cl[k0:k1 + 1]
    s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(seg, axis=0), axis=1))]
    q = np.linspace(0, s[-1], EYELETS)
    mid = np.stack([np.interp(q, s, seg[:, j]) for j in range(3)], 1)
    mid, nm = eva.on_surface(surf, mid, 0.0)
    L, R = [], []
    for k in range(EYELETS):
        across = unit(np.array([1.0, 0, 0]) - nm[k] * nm[k][0])
        w = 0.0115 + 0.002 * k / (EYELETS - 1)
        L.append(mid[k] + across * w); R.append(mid[k] - across * w)
    return eva.on_surface(surf, np.array(L), 0.0), eva.on_surface(surf, np.array(R), 0.0)


def lace(surf, a, b, high, n=14):
    pts = a + np.outer(np.linspace(0, 1, n), b - a)
    q, sn = eva.on_surface(surf, pts, 0.0)
    bump = np.sin(np.linspace(0, math.pi, n))
    lift = LIFT + 0.0008 + (0.0014 + (0.0018 if high else 0.0)) * bump
    return tube_out(q + sn * lift[:, None], sn, 0.0020)


def strap(points):
    axis = unit(np.array([0, 1.0, -STRAP_K]))
    xc, _ = leg_axis(STRAP_C[1])
    c = np.array([xc, STRAP_C[1], STRAP_C[2]])
    sv, sf = eva.band(points, np.ones(len(points), bool), c, axis, STRAP_H,
                      eva.bevel_prof(STRAP_H, 0.0032, inner=-0.0008, b=0.001), n=96)
    return (sv, sf), c, axis


def buckle(sv, c, axis):
    d = np.array([1.0, 0, 0.62]); d = unit(d - axis * (d @ axis))
    p = sv[np.argmax((sv - c) @ d)]
    nb = p - c; nb = unit(nb - axis * (nb @ axis))
    t = np.cross(axis, nb)
    p = p + nb * 0.0005
    parts = []
    L, W, b, h = 0.011, 0.0125, 0.0014, 0.0014
    for off, half, ax in [(t * L, (b, W, h), (t, axis, nb)), (-t * L, (b, W, h), (t, axis, nb)),
                          (axis * W, (L, b, h), (t, axis, nb)), (-axis * W, (L, b, h), (t, axis, nb)),
                          (np.zeros(3), (b * 0.8, W, h * 0.8), (t, axis, nb))]:
        parts.append(casco.box(p + off + nb * h, np.array(half), *ax))
    # franja rosa en la correa, delante de la hebilla
    q = p + t * (L + 0.016) * np.sign(t[2] if abs(t[2]) > 0.1 else 1)
    a, w = np.meshgrid(np.linspace(-1, 1, 4), np.linspace(-1, 1, 4), indexing="ij")
    along = a * 0.004 + w * 0.003
    base = q + along[..., None] * t + (w * STRAP_H * 0.7)[..., None] * axis
    slash = bt.grid_slab(base + nb * 0.0008, base - nb * 0.0004)
    return parts, slash


def heel_loop(v):
    top = v[0]                                               # columna de atrás (θ = -180°), en la boca
    zb, yt, x = top[2], top[1], top[0]
    zo, zi = zb - LIFT - 0.0025, zb + THICK + 0.0012
    ctrl = np.array([[zo, yt - 0.014], [zo, yt - 0.002], [zo - 0.004, yt + 0.014], [0.5 * (zo + zi) - 0.002, yt + 0.029],
                     [zi + 0.004, yt + 0.014], [zi, yt - 0.002], [zi, yt - 0.014]])
    pts2 = eva.catmull(ctrl, 8)
    pts = np.c_[np.full(len(pts2), x), pts2[:, 1], pts2[:, 0]]
    return tr.sweep(pts, np.array([1.0, 0, 0]), tr.rect(-0.007, 0.007, 0.00125))


def heel_tab(surf, v):
    back = v[:-1].reshape(-1, NA, 3)[:, 0]
    ys = np.linspace(0.060, collar_y(np.array(math.pi)) - COLLAR_H - 0.004, 14)
    a = np.linspace(-0.008, 0.008, 5)
    pts = []
    for y in ys:
        k = np.argmin(np.abs(back[:, 1] - y) + 10 * (back[:, 2] > 0.02))
        pts.append(back[k] + np.outer(a, [1.0, 0, 0]))
    pts = np.array(pts).reshape(-1, 3)
    base, sn = eva.on_surface(surf, pts, 0.0)
    o = (base + sn * (LIFT + 0.0016)).reshape(len(ys), len(a), 3)
    i = (base + sn * (LIFT - 0.0004)).reshape(len(ys), len(a), 3)
    return bt.grid_slab(o, i)


def side_mark(surf, v, s):
    """Triángulo sobre el galón de cada lado (s = 1 fuera, -1 dentro)."""
    p = v[(np.abs(v[:, 1] - 0.058) < 0.004) & (np.abs(v[:, 2] - 0.064) < 0.004)]
    p = p[np.argmax((p[:, 0] - FX) * s)]
    c, n = eva.on_surface(surf, p[None], 0.0)
    return triangle_mark(c[0], n[0], 0.019, lift=LIFT + 0.0007, r=0.0011, surf=surf)


# ---------------- 5. montaje ----------------
def build_left():
    v, f, R = build_shell()
    surf = eva.Surface(v, f)
    (lv, lf), (pv, pf) = H.lining(v, f, LINING_ROWS, THICK, LIFT)
    sheet, white = panels(v, f)
    parts = [(white, "blanco", "leg"), (sheet, "negro", "leg"), ((lv, lf), "negro", "leg"), ((pv, pf), "negro", "leg")]
    ol = outline(v)
    parts += [(midsole(ol), "blanco", "foot"), (outsole(ol), "negro", "foot")]
    parts += [(p, z, "foot") for p, z in sole_details(ol)]
    tg, tab, (tc, tn) = tongue()
    parts += [(tg, "negro", "leg"), (tab, "rosa", "leg"), (triangle_mark(tc, tn, 0.011, lift=0.0008, r=0.0008), "metal", "leg")]
    (L, nl), (Rr, nr) = lace_points(v, surf)
    laces = [lace(surf, L[0], Rr[0], False)]
    for k in range(EYELETS - 1):                             # de arriba abajo, cruzados
        laces += [lace(surf, L[k], Rr[k + 1], False), lace(surf, Rr[k], L[k + 1], True)]
    parts += [(lc, "cordones", "leg") for lc in laces]
    pts = np.vstack([v, sheet[0]] + [lc[0] for lc in laces])
    (sv, sf), c, axis = strap(pts)
    parts.append(((sv, sf), "negro", "leg"))
    bk, slash = buckle(sv, c, axis)
    parts += [(b, "metal", "leg") for b in bk] + [(slash, "rosa", "leg")]
    parts += [(heel_loop(v), "rosa", "leg"), (heel_tab(surf, v), "rosa", "leg")]
    parts += [(side_mark(surf, v, s), "metal", "leg") for s in (1, -1)]
    return parts, v


def build():
    parts_l, shell = build_left()
    verts, faces, zones, src_idx, src_w = [], [], [], [], []
    for s in SIDES:
        mirror = np.array([SIDES[s], 1, 1])
        masks = {"leg": bt.side_of(P0, s) & ((bt.LOWER_W > 0.3) | (bt.FOOT_W > 0.3)),
                 "foot": bt.side_of(P0, s) & (bt.FOOT_W > 0.3)}
        for (v, f), zone, mk in parts_l:
            v = np.asarray(v, float).reshape(-1, 3) * mirror
            f = np.asarray(f, int)
            if s == "Right":
                f = f[:, ::-1]
            faces.append(f + sum(len(x) for x in verts))
            verts.append(v)
            zones.append(np.tile(ZONES[zone], (len(v), 1)))
            i, w = sud.nearest_skin(v, 8, masks[mk])
            src_idx.append(i); src_w.append(w)
    check_fit(shell)
    v, f = np.concatenate(verts), np.concatenate(faces)
    return v, f, np.concatenate(zones), np.concatenate(src_idx), np.concatenate(src_w)


def check_fit(shell):
    """Hueco entre la piel (pie y tobillo, bajo la boca) y la cara de dentro."""
    from scipy.spatial import cKDTree
    m = bt.side_of(P0, "Left") & ((bt.LOWER_W + bt.FOOT_W) > 0.5)
    skin = P0[m]
    xc, zc = leg_axis(skin[:, 1])
    skin = skin[(skin[:, 1] < collar_y(np.arctan2(skin[:, 0] - xc, skin[:, 2] - zc)) - 0.005) & (skin[:, 1] > 0.012)]
    inside = field(skin) < 1
    gap = cKDTree(shell).query(skin)[0] - THICK
    k = np.argmin(gap)
    print("MEDIDA encaje: %d puntos de piel, %d fuera de la horma, hueco mínimo %.1f mm en %s" % (
        len(skin), (~inside).sum(), 1000 * gap[k], np.round(skin[k], 3)))


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
    cards = [tr.card(PID, "Zapatillas futuristas", sha, [0.17, 0.16, 0.19], "ropa", "ropa_pies")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_zapatillas_futuristas",
            "nombre": "Zapatillas futuristas (pruebas)", "autor": "GameMolde", "licencia": "propia", "origen": "",
            "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
