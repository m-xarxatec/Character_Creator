"""Máscara de gas (plano: planos/Imagen de ChatGPT 25 nov 2026, 00_54_07.webp).

Uso:  python generar_mascara.py
Escribe packs/claude_mascaras/: mascara_gas, **una sola pieza** en la ranura «accesorio» (convive con el peinado).
- Máscara: la piel de la cara recortada (de la frente a bajo la barbilla), separada GAP y alisada («tela tensa»: pasa
  sobre la nariz y los ojos); en el borde baja hasta la piel, como un sello de goma.
- Lentes con aro, filtro en la boca y válvulas en las mejillas: rígidas, cada una sigue al punto de la cara en que
  se apoya.
- Correas planas de 2 cm pegadas al cráneo (arriba, sobre las orejas y bajo ellas) hasta una placa detrás, con
  hebillas. Hoy el pelo pasa por encima de ellas (ver O en plan_assets.md).
- Pesos y formas de la piel que tiene debajo (como el bikini): se ajusta a la cara con cualquier deslizador.
- Zonas en COLOR_0: (0,0,0) goma, r = 1 cristales, g = 1 filtro y válvulas, b = 1 correas, placa y hebillas.
Usa las herramientas del bikini (piel, cintas, .glb), del casco (torno, caja) y del traje (hoja con grosor, tarjeta).
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_bikini", "claude_casco", "claude_sudadera", "claude_traje"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_bikini as bk
import generar_casco as cs
sud, tr = bk.sud, bk.tr

OUT = HERE / "packs" / "claude_mascaras"
P0, F0 = bk.P0, bk.F0
D = math.radians
HEAD_W = sud.bone_weight(["Head"])
C = np.array([0.0, 1.545, 0.059])                 # centro de la cabeza (el del casco)

# --- medidas (metros; cuerpo por defecto: barbilla y=1,45, boca 1,48, nariz 1,52, ojos 1,545, frente 1,62) ---
GAP, THICK = 0.006, 0.004                         # máscara: separada de la piel y grosor
EDGE_BAND = 0.008                                 # el borde baja hasta la piel en estos 8 mm (sello)
TENSE_IT = 400
MASK_HW = [(1.425, 0.030), (1.455, 0.042), (1.48, 0.060), (1.51, 0.074), (1.55, 0.080), (1.59, 0.070),
           (1.625, 0.050)]                        # contorno en la vista de frente: (y, media anchura)…
MASK_TOP, MASK_Z = 1.628, 0.055                   # …por debajo de la frente y solo delante
LENS = dict(x=0.032, y=1.548, r=0.020, rim=0.006, alto=0.009, giro=D(12))   # lentes: centro, radio del cristal…
FILTER = dict(y=1.478, r=0.033, largo=0.045, cuello=0.021, baja=D(25))     # filtro en la boca, mirando abajo
VALVE = dict(x=0.052, y=1.497, r=0.015, alto=0.011)                          # válvulas de las mejillas
STRAP_HW = 0.010                                  # correas de 2 cm
STRAPS = {                                        # (az, el) en grados alrededor de C, desde el borde de la máscara
    "arriba": [(0, 62), (0, 88), (180, 62), (180, 32)],
    "sien": [(70, 34), (100, 38), (140, 34), (168, 30)],
    "nuca": [(75, -36), (100, -36), (140, -20), (168, 4), (176, 18)],
}
STRAP_FROM = {"arriba": (0.0, 1.627), "sien": (0.068, 1.595), "nuca": (0.062, 1.488)}   # (|x|, y) en la máscara
PAD = (180, 26)                                   # placa de detrás, donde se juntan
ZONES = {"goma": (0, 0, 0, 1), "cristal": (1, 0, 0, 1), "filtro": (0, 1, 0, 1), "correa": (0, 0, 1, 1)}


# ---------------- máscara ----------------
def mask_field(V):
    x, y, z = np.abs(V[:, 0]), V[:, 1], V[:, 2]
    return np.maximum.reduce([x - np.interp(y, *zip(*MASK_HW)), y - (MASK_TOP - 1.5 * x ** 2), MASK_Z - z,
                              MASK_HW[0][0] - y])


def front_visible(P, tol=0.015):
    """La piel que se ve de frente: a menos de tol de la más adelantada en su (x, y) (fuera boca y ojos por dentro)."""
    key = np.floor(P[:, :2] / 0.004).astype(int)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    zmax = np.full(inv.max() + 1, -np.inf)
    np.maximum.at(zmax, inv.ravel(), P[:, 2])
    return P[:, 2] > zmax[inv.ravel()] - tol


def cut_face():
    """La piel de la cara recortada (sobre la piel) y sus bordes."""
    keep = (HEAD_W > 0.3) & front_visible(P0)
    F = F0[keep[F0].all(1)]
    F = F[mask_field(P0)[F].min(1) < 0.02]
    V, F = bk._compact(P0, F)
    V, F = bk.subdivide(V, F)
    V, F = tr.clip(V, F, mask_field(V))
    V, F = tr.largest_part(V, F)
    loops = sud.boundary_loops(F)
    for _ in range(20):
        for lp in loops:
            V[lp] = bk.on_skin(0.5 * V[lp] + 0.25 * (np.roll(V[lp], 1, 0) + np.roll(V[lp], -1, 0)))[0]
    return V, F, loops


def mask_sheet():
    V, F, loops = cut_face()
    q, _, _, n = bk.on_skin(V)
    O = bk.push_out(q + n * GAP, GAP)
    a, deg = sud.laplacian(F, len(O))
    free = np.ones(len(O), bool)
    free[np.concatenate(loops)] = False
    for _ in range(TENSE_IT):                                         # alisada, sin acercarse a la piel
        O[free] = (0.5 * O + 0.5 * (a @ O) / deg[:, None])[free]
        O = bk.push_out(O, GAP, 1)
    O[free] = bk.push_out(O[free], GAP, 8)
    d = cKDTree(O[np.concatenate(loops)]).query(O)[0]                 # sello: el borde baja a la piel
    t = np.clip(d / EDGE_BAND, 0, 1)
    t = t * t * (3 - 2 * t)
    q, _, _, n = bk.on_skin(O)
    O = O - n * (((O - q) * n).sum(1) * (1 - t))[:, None]
    return O, F


# ---------------- piezas rígidas sobre la máscara ----------------
def on_mask(O, N, x, y):
    """Punto de la máscara (cara de fuera) más cercano a (x, y) en la vista de frente, delante, y su normal."""
    near = np.where(np.hypot(O[:, 0] - x, O[:, 1] - y) < 0.004)[0]
    i = near[O[near, 2].argmax()]
    return O[i], N[i]


def disc_profile(r, h, z0=0.0):
    return [(0.0005, z0), (r, z0), (r, z0 + h), (0.0005, z0 + h)]


def lens(O, N, s):
    p, n = on_mask(O, N, s * LENS["x"], LENS["y"])
    n = cs.unit(n + np.array([s * math.sin(LENS["giro"]), 0, 0]))
    r, w, h = LENS["r"], LENS["rim"], LENS["alto"]
    rim = cs.lathe([(r - 0.001, -0.003), (r + w, -0.003), (r + w, h - 0.003), (r + w - 0.002, h),
                    (r + 0.001, h), (r - 0.001, h - 0.002)], p, n, 48)
    glass = cs.lathe(disc_profile(r, 0.002, 0.002), p, n, 40)
    return [(rim, "goma"), (glass, "cristal")], p


def filter_can(O, N):
    p, n = on_mask(O, N, 0.0, FILTER["y"])
    ax = cs.unit(n * math.cos(FILTER["baja"]) + np.array([0, -1.0, 0]) * math.sin(FILTER["baja"]))
    r, L, rc = FILTER["r"], FILTER["largo"], FILTER["cuello"]
    body = cs.lathe([(0.0005, -0.004), (rc, -0.004), (rc + 0.002, 0.010), (r - 0.002, 0.012), (r, 0.015),
                     (r, L - 0.004), (r - 0.003, L), (0.0005, L)], p, ax, 48)
    parts = [(body, "filtro")]
    e1 = cs.unit(np.cross(ax, [0, 1.0, 0]))
    e2 = np.cross(ax, e1)
    for k in range(8):                                                 # radios de la tapa
        a = 2 * math.pi * k / 8
        u = e1 * math.cos(a) + e2 * math.sin(a)
        parts.append((cs.box(p + ax * (L + 0.0012) + u * (r * 0.55), [0.0014, r * 0.38, 0.0014],
                             np.cross(ax, u), u, ax), "filtro"))
    parts.append((cs.lathe([(r * 0.62, L), (r * 0.80, L), (r * 0.80, L + 0.0026), (r * 0.62, L + 0.0026)],
                           p, ax, 48), "filtro"))
    parts.append((cs.lathe(disc_profile(r * 0.22, 0.003, L), p, ax, 24), "filtro"))
    return parts, p


def valve(O, N, s):
    p, n = on_mask(O, N, s * VALVE["x"], VALVE["y"])
    r, h = VALVE["r"], VALVE["alto"]
    parts = [(cs.lathe([(0.0005, -0.003), (r, -0.003), (r, h - 0.002), (r - 0.002, h), (0.0005, h)], p, n, 32),
              "filtro")]
    e1 = cs.unit(np.cross(n, [0, 0, 1.0]) if abs(n[2]) < 0.95 else np.cross(n, [1.0, 0, 0]))
    e1 = cs.unit(e1 - n * (e1 @ n))
    up = cs.unit(np.array([0, 1.0, 0]) - n * n[1])
    side = np.cross(up, n)
    for k in range(4):                                                 # rejilla
        parts.append((cs.box(p + n * (h + 0.001) + up * (r * (-0.45 + 0.3 * k)), [r * 0.62, 0.0012, 0.0012],
                             side, up, n), "filtro"))
    return parts, p


# ---------------- correas ----------------
def skull_pt(az, el):
    u = np.array([math.cos(D(el)) * math.sin(D(az)), math.sin(D(el)), math.cos(D(el)) * math.cos(D(az))])
    return bk.on_skin((C + u * 0.13)[None])[0][0]


def strap_curve(start, pts):
    c = bk.spline(np.array([start] + [skull_pt(a, e) for a, e in pts]), 0.004)
    for _ in range(4):
        c = bk.on_skin(c)[0]
        c[1:-1] = 0.5 * c[1:-1] + 0.25 * (c[:-2] + c[2:])
    return bk.on_skin(c)[0]


def straps(O):
    out = []
    for name, pts in STRAPS.items():
        x, y = STRAP_FROM[name]
        for s in ((1,) if x == 0 else (1, -1)):
            start = O[np.where(O[:, 2] > 0.03, np.hypot(O[:, 0] - s * x, O[:, 1] - y), np.inf).argmin()]
            c = strap_curve(start, [(s * a, e) for a, e in pts])
            out.append(c)
    return out


def buckle(c):
    """Hebilla sobre la correa, a 4 cm de la máscara."""
    i = min(10, len(c) - 2)
    t = cs.unit(c[i + 1] - c[i - 1])
    n = bk.on_skin(c[i][None])[3][0]
    b = np.cross(n, t)
    p = c[i] + n * 0.006
    return [cs.box(p + b * s * (STRAP_HW + 0.0005), [0.0015, 0.0012, 0.009], b, n, t) for s in (1, -1)] + \
        [cs.box(p + t * s * 0.0075, [STRAP_HW + 0.002, 0.0012, 0.0015], b, n, t) for s in (1, -1)]


# ---------------- pieza ----------------
def build():
    O, F = mask_sheet()
    N = sud.vertex_normals(O, F)
    if (N * (O - C)).sum() < 0:                                       # hacia fuera
        F, N = F[:, ::-1], -N
    verts, faces, zones, src_i, src_w, hgt = [], [], [], [], [], []

    def add(vf, zone, i, w, h):
        v = np.asarray(vf[0], float)
        faces.append(np.asarray(vf[1], int) + sum(len(x) for x in verts))
        verts.append(v)
        zones.append(np.tile(ZONES[zone], (len(v), 1)))
        src_i.append(np.c_[i, np.zeros((len(v), 8 - i.shape[1]), int)])
        src_w.append(np.c_[w, np.zeros((len(v), 8 - w.shape[1]))])
        hgt.append(h)

    def add_sheet(vf, zone):                                           # sigue a la piel de debajo (y su normal)
        _, si, sw, _ = bk.on_skin(vf[0])
        q = (P0[si] * sw[..., None]).sum(1)
        add(vf, zone, si, sw, ((vf[0] - q) * bk.normal_at(bk.SKIN_N, si, sw)).sum(1))

    def add_rigid(parts, anchor):                                      # se traslada con su punto de apoyo
        _, si, sw, _ = bk.on_skin(anchor[None])
        for vf, zone in parts:
            n = len(vf[0])
            add(vf, zone, np.repeat(si, n, 0), np.repeat(sw, n, 0), np.zeros(n))

    v, f, src = tr.thick_sheet(O, F, THICK)
    add_sheet((v, f), "goma")
    for s in (1, -1):
        add_rigid(*lens(O, N, s))
        add_rigid(*valve(O, N, s))
    add_rigid(*filter_can(O, N))
    for c in straps(O):
        S, SF = bk.strap_sheet(c, STRAP_HW)
        add_sheet(tr.thick_sheet(S, SF, 0.0015)[:2], "correa")
        add_rigid([(x, "correa") for x in buckle(c)], c[min(10, len(c) - 2)])
    pad = skull_pt(*PAD)
    pn = bk.on_skin(pad[None])[3][0]
    add_rigid([(cs.lathe([(0.0005, 0.0), (0.020, 0.0), (0.020, 0.004), (0.017, 0.0055), (0.0005, 0.0055)],
                         pad, pn, 32), "correa")], pad)
    v, f = np.concatenate(verts), np.concatenate(faces)
    bk.OUT = OUT
    sha, targets = bk.write(v, f, np.concatenate(zones), np.concatenate(src_i), np.concatenate(src_w),
                            np.concatenate(hgt), "mascara_gas")
    return sha, O, F, targets


def measure(O, F, targets):
    _, si, sw, _ = bk.on_skin(O)
    loops = sud.boundary_loops(F)
    inner = cKDTree(O[np.concatenate(loops)]).query(O)[0] > EDGE_BAND
    q, n = (P0[si] * sw[..., None]).sum(1), bk.normal_at(bk.SKIN_N, si, sw)
    print("MEDIDA máscara (cara de fuera) a la piel (reposo, lejos del borde): mín %.1f mm, máx %.1f mm" % (
        ((O - q) * n).sum(1)[inner].min() * 1000, ((O - q) * n).sum(1)[inner].max() * 1000))
    worst = []
    for name, d in sud.B["targets"].items():
        if name not in targets or "*" in name:
            continue
        P = P0 + d
        Os = O + targets[name][:len(O)]
        Pn = sud.vertex_normals(P, F0)
        h = ((Os - (P[si] * sw[..., None]).sum(1)) * bk.normal_at(Pn, si, sw)).sum(1)
        worst.append((h[inner].min(), name))
    worst.sort()
    print("MEDIDA máscara (cara de fuera) con cada forma: peores %s" % ", ".join(
        "%.1f mm (%s)" % (a * 1000, b) for a, b in worst[:3]))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sha, O, F, targets = build()
    measure(O, F, targets)
    cards = [tr.card("mascara_gas", "Máscara de gas", sha, [0.20, 0.20, 0.21], "accesorio", "accesorio")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_mascaras", "nombre": "Máscaras (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
