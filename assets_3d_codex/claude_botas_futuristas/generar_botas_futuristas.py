"""Botas futuristas (plano: planos/Diseño conceptual de botas futuristas.webp).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_botas_futuristas.py   (numpy y scipy)
Escribe packs/claude_botas_futuristas/: botas_futuristas, el par en **una sola pieza**, ranura «ropa_pies» (no quita
nada, ver P en plan_assets.md). Método de calzado de plan_assets.md.
- Cuero crema: horma propia (../claude_zapatillas_futuristas/horma.py), **no la piel**: botín con la caña hasta
  y = 0,205 a ~1,2 cm de la pierna (la pierna medida de las botas medievales) y puntera cuadrada y alta.
- Puño de tela arrugado arriba: rodea la boca de la caña y la tapa.
- En relieve: una banda oscura por cada lado (de bajo el puño a la suela, delante del talón) y dos que se cruzan en X
  delante. Correa con hebilla en el tobillo (triángulo rosa delante) y otra en diagonal sobre el empeine; «///» fuera.
- Suela de plataforma **plana** (decidido por el responsable: el tacón del plano levantaría al personaje): tacos
  abajo y una hendidura en el arco que separa el bloque del talón. Neón rosa: barra delante, tiras en el talón y
  cuña en el arco.
Pesos y formas: los de la piel más cercana (sigue a cualquier edición del cuerpo). El pie derecho es el izquierdo
reflejado.
Zonas en COLOR_0: (0,0,0) crema; r = 1 oscuro (bandas y correas); g = 1 rosa; b = 1 metal (hebillas);
r = g = 1 puño; r = b = 1 suela (y la «///»).
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje", "claude_casco", "claude_eva", "claude_botas_medievales",
          "claude_zapatillas_futuristas", "claude_zapatillas_altas"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_sudadera as sud
import generar_traje as tr
import generar_casco as casco
import generar_eva as eva
import generar_botas as bt
import generar_zapatillas_futuristas as zf
import generar_zapatillas as za
import horma

OUT = HERE / "packs" / "claude_botas_futuristas"
PID = "botas_futuristas"
P0, SIDES = sud.P0, sud.SIDES
smooth, D = eva.smoothstep, np.radians
ZONES = {"crema": (0, 0, 0, 1), "oscuro": (1, 0, 0, 1), "rosa": (0, 1, 0, 1), "metal": (0, 0, 1, 1),
         "puno": (1, 1, 0, 1), "suela": (1, 0, 1, 1)}

# --- horma (pie izquierdo, metros) ---
Y_TOP, GAP_SHAFT = 0.205, 0.012
THICK, LINING_ROWS = 0.003, 18                    # forro: lo que se ve entre la pierna y el puño
H = horma.Horma(
    pw=[0.037, 0.040, 0.043, 0.048, 0.055, 0.058, 0.057, 0.054, 0.049],     # puntera ancha y cuadrada
    pt=[0.086, 0.090, 0.094, 0.098, 0.090, 0.080, 0.075, 0.071, 0.068],     # alta: asoma sobre la plataforma
    toe_r=0.032, axis_y=bt._LY, axis_x=bt._LX, axis_z=bt._LZ, shaft_y=bt._LY,
    shaft_ax=list(np.add(bt._HX, GAP_SHAFT)), shaft_az=list(np.add(bt._HZ, GAP_SHAFT)),
    collar=(Y_TOP, 0.004, 0.0), na=56, n_shaft=26,
    y_bot=0.019)                                  # la planta, dentro de la suela (no asoma por la hendidura)
FX = H.fx
# --- puño: de CUFF_Y0 a CUFF_Y1, abulta CUFF_OUT sobre la caña ---
CUFF_Y0, CUFF_Y1, CUFF_OUT, CUFF_IN = Y_TOP - 0.057, Y_TOP + 0.018, 0.017, -0.0055
# --- suela ---
SOLE_OUT, SOLE_Y0, LUG_Y, REC = 0.008, -0.004, 0.013, 0.010
Z_ARCH = (0.045, 0.100)                           # hendidura del arco (z de la planta)
LUG_STEP, LUG_W = 0.021, 0.0065
NEON_HEEL = (180, 140, -140)                      # tiras rosas del talón (ángulo en planta)
# --- relieve y correas ---
LIFT = 0.0018
STRAP_H, STRAP_T = 0.011, 0.0032                 # media anchura y grosor de las correas
ANKLE = (0.130, (0, 1.0, 0.12), (1.0, 0, 0.7))    # correa del tobillo: y, eje y hacia dónde mira la hebilla
INSTEP = [((FX, 0.030, 0.150), (-1, 0, 0)), ((FX, 0.068, 0.118), (-1, 0.7, 0)), ((FX, 0.060, 0.092), (0, 1, 0.45)),
          ((FX, 0.068, 0.118), (1, 0.7, 0)), ((FX, 0.030, 0.150), (1, 0, 0))]   # empeine: rayos, de suela a suela


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


# ---------------- 1. puño de tela ----------------
def cuff(nth=72):
    """Tubo cerrado alrededor de la boca: pared de dentro pegada a la caña, labio arriba y fuera abultado y arrugado."""
    ym = 0.5 * (CUFF_Y0 + CUFF_Y1)
    ctrl = np.array([[CUFF_IN, CUFF_Y0 + 0.003], [CUFF_IN, CUFF_Y1 - 0.009], [CUFF_IN + 0.002, CUFF_Y1 - 0.002],
                     [0.003, CUFF_Y1 + 0.0015], [0.010, CUFF_Y1 - 0.003], [0.014, CUFF_Y1 - 0.012], [CUFF_OUT, ym + 0.006], [CUFF_OUT * 0.9, ym - 0.012],
                     [0.011, CUFF_Y0 + 0.008], [0.002, CUFF_Y0]])
    prof = eva.catmull(np.vstack([ctrl, ctrl[:1]]), 4)[:-1]
    th = np.linspace(-math.pi, math.pi, nth, endpoint=False)
    T, Dd = np.meshgrid(th, prof[:, 0], indexing="ij")
    Y = np.broadcast_to(prof[:, 1], T.shape)
    out = smooth((Dd - 0.004) / 0.006)                                # solo lo de fuera se arruga (no el labio)
    lump = 1 + 0.28 * np.sin(3 * T + 0.7) + 0.18 * np.sin(5 * T + 2.1)
    crease = 0.0032 * np.sin(7 * T + 70 * (Y - ym))                   # pliegues en diagonal
    d = Dd + out * (Dd * (lump - 1) + crease)
    Y = Y + 0.004 * np.sin(2 * T + 0.5) * smooth((Y - CUFF_Y0) / 0.04)
    base, u = H.leg_ray_point(Y, T, 0.0)
    xc, zc = H.leg_axis(Y)
    r0 = np.linalg.norm(base - np.stack([xc, Y, zc], -1), axis=-1)
    v = np.stack([xc, Y, zc], -1) + u * (r0 + d)[..., None]
    return tr.orient_closed(v.reshape(-1, 3), tr.ring_faces(nth, len(prof), True))


# ---------------- 2. relieve: bandas oscuras y «///» ----------------
def cast1(o, d):
    return H.cast(np.array([o], float), unit(np.array([d], float)))[0]


def leg_pt(y, th):
    return H.leg_ray_point(np.array([y]), np.array([th]), 0.0)[0][0]


def project(p):
    """Lleva los puntos a la superficie exacta de la horma (por el gradiente de su campo) y da su normal."""
    p = np.array(p, float).reshape(-1, 3)
    for _ in range(8):
        g = H.field(p)
        grad = np.stack([(H.field(p + e) - H.field(p - e)) / 2e-4 for e in np.eye(3) * 1e-4], 1)
        p = p - ((g - 1) / np.sum(grad ** 2, 1))[:, None] * grad
    return p, unit(grad)


def curve(ctrl):
    return project(eva.catmull(np.array(ctrl), 24))


def band_curves(surf):
    """[(puntos de la línea central sobre la horma, media anchura)]."""
    out = []
    for s in (1, -1):                                                 # lados: de bajo el puño a la suela
        ctrl = []
        for y, dz in ((CUFF_Y0 + 0.004, 0.004), (0.10, 0.008)):
            xc, zc = H.leg_axis(y)
            ctrl.append(cast1((xc, y, zc + dz), (s, 0, 0)))
        ctrl += [cast1((FX, 0.045, 0.040), (s, 0, 0)), cast1((FX, 0.026, 0.044), (s, 0, 0))]
        out.append((curve(ctrl)[0], 0.011))
    for s in (1, -1):                                                 # X delante
        ctrl = [leg_pt(0.128, s * D(55)), leg_pt(0.098, 0.0), cast1((FX, 0.05, 0.115), (-s, 0, 0.3)),
                cast1((FX, 0.026, 0.12), (-s, 0, 0.3))]
        out.append((curve(ctrl)[0], 0.0085))
    return out


def bands(v, f, surf):
    phi = np.full(len(v), -1.0)
    for pts, w in band_curves(surf):
        phi = np.maximum(phi, w - cKDTree(pts).query(v)[0])
    return za.relief(v, f, phi, LIFT)


def slashes(surf):
    """Tres rayas en diagonal fuera, arriba del talón."""
    p, n = eva.on_surface(surf, leg_pt(0.088, D(122))[None], 0.0)
    n = n[0]
    right = unit(np.cross([0, 1.0, 0], n))
    up = np.cross(n, right)
    along = math.cos(D(62)) * right + math.sin(D(62)) * up
    out = []
    for k in range(3):
        a, w = np.meshgrid(np.linspace(-0.008, 0.008, 6), np.linspace(-0.0014, 0.0014, 2), indexing="ij")
        q = p[0] + (k - 1) * 0.0062 * right + a[..., None] * along + w[..., None] * right
        b, nn = eva.on_surface(surf, q.reshape(-1, 3), 0.0)
        b, nn = b.reshape(q.shape), nn.reshape(q.shape)
        out.append(bt.grid_slab(b + nn * (LIFT + 0.0008), b - nn * 0.0004))
    return out


# ---------------- 3. correas, hebillas y triángulo ----------------
def ankle_strap(pts):
    """Correa del tobillo: un anillo alrededor de la caña."""
    y, axis, _ = ANKLE
    xc, zc = H.leg_axis(y)
    c = np.array([xc, y, zc])
    sv, sf = eva.band(pts, np.ones(len(pts), bool), c, axis, STRAP_H,
                      eva.bevel_prof(STRAP_H, STRAP_T, inner=-0.0008, b=0.001), n=96)
    return (sv, sf), c, unit(np.array(axis, float))


def instep_strap(v, f):
    """Correa del empeine: relieve más alto que las bandas, de la suela por dentro a la suela por fuera."""
    c, n = curve([cast1(o, d) for o, d in INSTEP])
    slab = za.relief(v, f, STRAP_H - cKDTree(c).query(v)[0], LIFT + STRAP_T)
    t = np.gradient(c, axis=0)
    t = unit(t - n * np.sum(t * n, 1, keepdims=True))
    w = np.cross(n, t)
    k = int(np.argmax(c[:, 0] - 9 * (c[:, 1] < 0.066)))          # hebilla fuera, a media altura
    return slab, (c[k] + n[k] * (LIFT + STRAP_T), n[k], t[k], w[k])


def outer_frame(sv, c, axis, d):
    d = unit(np.asarray(d, float)); d = unit(d - axis * (d @ axis))
    p = sv[np.argmax((sv - c) @ d)]
    nb = unit((p - c) - axis * ((p - c) @ axis))
    return p, nb, np.cross(axis, nb)


def buckle(p, nb, t, axis):
    """Hebilla cuadrada (marco y pasador) en p y el cabo de la correa que sale de ella (t: a lo largo de la correa)."""
    L, W, b, h = 0.011, 0.0145, 0.0017, 0.0015
    metal = [casco.box(p + off + nb * h, np.array(half), t, axis, nb) for off, half in
             [(t * L, (b, W, h)), (-t * L, (b, W, h)), (axis * W, (L, b, h)), (-axis * W, (L, b, h)),
              (np.zeros(3), (b * 0.7, W, h * 0.8))]]
    tail = casco.box(p - t * (L + 0.011) + nb * 0.0012, np.array([0.011, STRAP_H * 0.85, 0.0012]), t, axis, nb)
    return metal, tail


def front_triangle(sv, c, axis):
    p, nb, _ = outer_frame(sv, c, axis, (0, 0, 1.0))
    return zf.triangle_mark(p, nb, 0.017, lift=0.0006, r=0.0011)


# ---------------- 4. suela ----------------
def sole_top(ol, th):
    z = ol.point(th, 0.0, 0.0)[..., 2]
    return 0.033 + 0.005 * smooth((z - 0.17) / 0.05)


def arch(z):
    return smooth((z - Z_ARCH[0]) / 0.012) * smooth((Z_ARCH[1] - z) / 0.012)


def sole(ol):
    """Plataforma: abajo metida (los tacos sobresalen) y más en el arco (la hendidura); arriba, la pared entera."""
    th = ol.th
    a = arch(ol.point(th, 0.0, 0.0)[:, 2])
    O, top = SOLE_OUT, sole_top(ol, th)
    low, step = O - 0.004 - REC * a, LUG_Y + 0.004 * a
    rings = [(low - 0.0015, SOLE_Y0), (low, SOLE_Y0 + 0.0015), (low, step), (O - 0.0015, step + 0.0015),
             (O, step + 0.003), (O, top - 0.0025), (O - 0.0015, top), (-0.004, top)]
    return zf.rings_solid(ol, rings, SOLE_Y0, float(top.min()) - 0.004)


def wrap_angle(a):
    return (a + math.pi) % (2 * math.pi) - math.pi


def lugs(ol):
    th = np.r_[ol.th, ol.th[0] + 2 * math.pi]
    p = ol.point(th, 0.0, SOLE_OUT)
    s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))]
    s0 = np.interp(0.0, th, s)
    out = []
    for k in range(int(s[-1] / LUG_STEP)):
        c = wrap_angle(np.interp((s0 + k * LUG_STEP) % s[-1], s, th))
        z = ol.point(np.array([c]), 0.0, 0.0)[0, 2]
        if arch(z) > 0.05 or min(abs(wrap_angle(c - D(n))) for n in NEON_HEEL) < D(10):
            continue
        h = LUG_W * 0.02 / max(np.interp(c + 0.01, th, s) - np.interp(c - 0.01, th, s), 1e-4)
        out.append(zf.wall_slab(ol, lambda q, y, c=c, h=h: c + q * h, SOLE_Y0 + 0.0005, LUG_Y + 0.001,
                                SOLE_OUT + 0.001, SOLE_OUT - 0.006, nq=4, ny=3))
    return out


def neon(ol):
    parts = [zf.wall_slab(ol, lambda q, y: q * D(26), 0.017, 0.025, SOLE_OUT + 0.0012, SOLE_OUT - 0.002, nq=12, ny=4)]
    for n in NEON_HEEL:                                               # tiras del talón, más estrechas abajo
        c = D(n)
        top = float(sole_top(ol, np.array([c]))[0]) - 0.005
        w0, w1 = D(2.0 if n == 180 else 1.8), D(4.5 if n == 180 else 3.5)
        parts.append(zf.wall_slab(ol, lambda q, y, c=c, w0=w0, w1=w1, top=top:
                                  c + q * (w0 + (w1 - w0) * (y - SOLE_Y0) / (top - SOLE_Y0)),
                                  SOLE_Y0 + 0.002, top, SOLE_OUT + 0.0012, SOLE_OUT - 0.006, ny=8))
    for s in (1, -1):                                                 # cuña del arco: ancha abajo, hacia el talón
        thg = np.linspace(0.15, math.pi - 0.15, 200) * s
        zg = ol.point(thg, 0.0, 0.0)[:, 2]
        th_at = lambda z, zg=zg, thg=thg: np.interp(z, zg[::-1], thg[::-1])
        y0, y1 = LUG_Y + 0.0075, float(sole_top(ol, np.array([s * D(90)]))[0]) - 0.004
        za0, za1 = Z_ARCH[0] + 0.004, Z_ARCH[1] - 0.006

        def th_of(q, y, th_at=th_at, y0=y0, y1=y1, za0=za0, za1=za1):
            k = (y - y0) / (y1 - y0)
            hi = za1 + (za0 + 0.016 - za1) * k
            return th_at(za0 + (q + 1) / 2 * (hi - za0))
        parts.append(zf.wall_slab(ol, th_of, y0, y1, SOLE_OUT + 0.0012, SOLE_OUT - 0.002, nq=10, ny=6))
    return parts


# ---------------- 5. montaje ----------------
def build_left():
    v, f, _ = H.build_shell()
    surf = eva.Surface(v, f)
    (lv, lf), (pv, pf) = H.lining(v, f, LINING_ROWS, THICK)
    rel = bands(v, f, surf)
    parts = [((v, f), "crema", "leg"), ((lv, lf), "crema", "leg"), ((pv, pf), "crema", "leg"),
             (rel, "oscuro", "leg"), (cuff(), "puno", "leg")]
    parts += [(p, "suela", "leg") for p in slashes(surf)]
    pts = np.vstack([v[v[:, 1] > 0.024], rel[0]])
    (sv, sf), c, ax = ankle_strap(pts)
    slab, frame = instep_strap(v, f)
    parts += [((sv, sf), "oscuro", "leg"), (slab, "oscuro", "leg"), (front_triangle(sv, c, ax), "rosa", "leg")]
    for fr in (outer_frame(sv, c, ax, ANKLE[2]) + (ax,), frame[:1] + (frame[1], frame[2], frame[3])):
        metal, tail = buckle(*fr)
        parts += [(tail, "oscuro", "leg")] + [(m, "metal", "leg") for m in metal]
    ol = zf.outline(v)
    parts += [(sole(ol), "suela", "foot")] + [(p, "suela", "foot") for p in lugs(ol)]
    parts += [(p, "rosa", "foot") for p in neon(ol)]
    return parts, v, ol


def build():
    parts_l, shell, ol = build_left()
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
    check_fit(shell, ol, parts_l[4][0][0])
    v, f = np.concatenate(verts), np.concatenate(faces)
    return v, f, np.concatenate(zones), np.concatenate(src_idx), np.concatenate(src_w)


def check_fit(shell, ol, cuff_v):
    """Hueco de la piel a la horma (bajo la boca) y al puño; y que la planta no asome bajo la hendidura."""
    m = bt.side_of(P0, "Left") & ((bt.LOWER_W + bt.FOOT_W) > 0.5)
    skin = P0[m]
    low = skin[skin[:, 1] < LUG_Y + 0.004]
    skin = skin[(skin[:, 1] < Y_TOP - 0.005) & (skin[:, 1] > 0.035)]               # bajo 0,035: dentro de la suela
    inside = H.field(skin) < 1
    gap = cKDTree(shell).query(skin)[0] - THICK
    k = np.argmin(gap)
    print("MEDIDA encaje: %d puntos de piel, %d fuera de la horma, hueco mínimo %.1f mm en %s" % (
        len(skin), (~inside).sum(), 1000 * gap[k], np.round(skin[k], 3)))
    leg = P0[m & (P0[:, 1] > CUFF_Y0 - 0.01)]
    print("MEDIDA puño: hueco mínimo a la pierna %.1f mm" % (1000 * cKDTree(cuff_v).query(leg)[0].min()))
    d = low[:, [0, 2]] - ol.c
    th = np.arctan2(d[:, 0], d[:, 1])
    wall = ol.radius(th) + SOLE_OUT - 0.004 - REC * arch(low[:, 2])
    print("MEDIDA suela: la planta queda a ≥ %.1f mm de la pared de abajo" % (1000 * (wall - np.linalg.norm(d, axis=1)).min()))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    zf.OUT, zf.PID = OUT, PID
    sha = zf.write(*build())
    cards = [tr.card(PID, "Botas futuristas", sha, [0.90, 0.87, 0.85], "ropa", "ropa_pies")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_botas_futuristas",
            "nombre": "Botas futuristas (pruebas)", "autor": "GameMolde", "licencia": "propia", "origen": "",
            "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
