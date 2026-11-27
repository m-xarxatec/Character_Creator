"""Zapatillas altas negras (plano: planos/Plancha técnica de zapatillas altas negras.webp).

Uso:  python generar_zapatillas.py   (en Linux: ~/.venvs/gamemolde_assets/bin/python generar_zapatillas.py)
Escribe packs/claude_zapatillas/: zapatillas_altas, el par en **una sola pieza**, ranura «ropa_pies» (no quita nada:
como las botas medievales, van con shorts, mallas y trajes ceñidos; un pantalón holgado asomará, ver P en
plan_assets.md). Sin el parche redondo con estrella del plano: es el logotipo de una marca.
- Lona: una horma propia (../claude_zapatillas_futuristas/horma.py), **no la piel del pie**: no se notan los dedos ni
  la curva del pie. **Grandes, al estilo VTuber**: caña hasta 10 cm sobre el tobillo, a ~1,4 cm de la pierna; puntera
  más alta para asomar sobre la suela. Pesos y formas, de la piel más cercana (sigue a cualquier edición del cuerpo).
- Suela de plataforma **doble** (pared de 6 cm, sube en la punta) con una franja; puntera de goma encima de la lona.
- Lengüeta que asoma por arriba, siete pares de ojales con cordones cruzados, dos ojales de ventilación por dentro
  y tira en el talón.
Zonas en COLOR_0: (0,0,0) lona; r = 1 goma (suela y puntera); g = 1 cordones; r = g = 1 ojales; b = 1 franja.
"""
import json, math, sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje", "claude_casco", "claude_eva", "claude_botas_medievales",
          "claude_zapatillas_futuristas"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_sudadera as sud
import generar_traje as tr
import generar_casco as casco
import generar_eva as eva
import generar_botas as bt
import horma

OUT = HERE / "packs" / "claude_zapatillas"
PID = "zapatillas_altas"

# --- medidas (metros); t: a lo largo de la pierna, 0 rodilla y 1 tobillo ---
SIZE = 1.0                                  # lo «grande»: holguras, puntera y suela
TOP_T = 0.74                                # boca de la caña (unos 10 cm sobre el tobillo)
THICK, LINING_ROWS = 0.003, 24             # forro: solo lo que se ve por la boca
SOLE_OUT, SOLE_Y0, SOLE_Y1, TOE_RISE = 0.007 * SIZE, -0.004, 0.060 * SIZE, 0.010 * SIZE   # suela doble
STRIPE_Y, STRIPE_H = 0.016 * SIZE, 0.004 * SIZE
EYELETS = 7
Z_LACE_LOW = 0.118                          # el último par de ojales, sobre el empeine
TONGUE_W = 0.0095                           # media anchura de la lengüeta (entre los ojales)
CAP_L, CAP_W = 0.055, 0.075                 # puntera de goma: largo desde la punta y ancho

P0, SIDES, LEG = sud.P0, sud.SIDES, bt.LEG
ZONES = {"lona": (0, 0, 0, 1), "goma": (1, 0, 0, 1), "cordones": (0, 1, 0, 1), "ojales": (1, 1, 0, 1),
         "franja": (0, 0, 1, 1)}
LOWER_W, FOOT_W = bt.LOWER_W, bt.FOOT_W
side_of, leg_t = bt.side_of, bt.leg_t


def unit(x):
    return x / np.linalg.norm(x)


# ---------------- 1. lona: la horma ----------------
_g = LEG["Left"]
H = horma.Horma(
    pw=[0.035, 0.038, 0.041, 0.046, 0.052, 0.055, 0.053, 0.047, 0.040],
    pt=[0.096, 0.100, 0.104, 0.110, 0.110, 0.108, 0.106, 0.103, 0.099],   # alta: asoma sobre la suela doble
    collar=(float(_g["knee"][1] + _g["dir"][1] * TOP_T * _g["len"]), 0.004, 0.001),
    y_b=0.125, r_arc=0.100, n_shaft=16, n_arc=34, n_foot=20)
H_SHELL = H.build_shell()[:2]                                 # la horma del pie izquierdo (el derecho se refleja)


# ---------------- 2. suela, franja y puntera ----------------
def sole_outline(shell, s, n=72):
    pts = shell[side_of(shell, s) & (shell[:, 1] < 0.04)]
    c = 0.5 * (pts[:, [0, 2]].min(0) + pts[:, [0, 2]].max(0))
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


def relief(v, f, phi, lift, sink=0.0004):
    """Placa en relieve sobre la horma donde phi > 0: recortada por su borde, despegada lift, con canto que entra en
    la horma (el borde sale limpio, sin dientes)."""
    n = sud.vertex_normals(v, f)
    pv, pf = tr.clip(np.c_[v, n], f, -phi)
    pv, pn = pv[:, :3], pv[:, 3:] / np.linalg.norm(pv[:, 3:], axis=1, keepdims=True)
    bnd = tr.boundary(pf)
    edge = np.unique(bnd)
    idx = -np.ones(len(pv), int); idx[edge] = len(pv) + np.arange(len(edge))
    V = np.vstack([pv + pn * lift, pv[edge] - pn[edge] * sink])
    a, b = bnd[:, 0], bnd[:, 1]
    return V, np.concatenate([pf, np.stack([b, a, idx[a]], -1), np.stack([b, idx[a], idx[b]], -1)])


def toe_cap(v, f):
    """Puntera de goma del plano: un arco desde la punta (5,5 cm delante, 7,5 cm de ancho), en relieve."""
    tip = v[:, 2].max()
    e = np.sqrt(((tip - v[:, 2]) / CAP_L) ** 2 + ((v[:, 0] - H.pc[-2]) / CAP_W) ** 2)
    return relief(v, f, (1 - e) * CAP_L, 0.0018)


# ---------------- 3. lengüeta, ojales, cordones y talón ----------------
def lace_line(v):
    """Línea central de la abertura (columna de delante de la horma), de la boca al empeine."""
    cl = v[:-1].reshape(-1, H.na, 3)[:, H.j0]
    k0 = int(np.argmax(cl[:, 1] <= H.collar[0] - 0.012))
    k1 = int(np.argmax(cl[:, 2] >= Z_LACE_LOW))
    return cl, k0, k1


def lace_points(v, surf):
    """Pares de ojales (izquierda, derecha) a lo largo de la línea central, a la misma distancia."""
    cl, k0, k1 = lace_line(v)
    seg = cl[k0:k1 + 1]
    s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(seg, axis=0), axis=1))]
    q = np.linspace(0, s[-1], EYELETS)
    mid = np.stack([np.interp(q, s, seg[:, j]) for j in range(3)], 1)
    mid, nm = eva.on_surface(surf, mid, 0.0)
    left, right = [], []
    for k in range(EYELETS):
        across = unit(np.array([1.0, 0, 0]) - nm[k] * nm[k][0])
        w = 0.0125 + 0.0025 * k / (EYELETS - 1)
        left.append(mid[k] + across * w); right.append(mid[k] - across * w)
    return eva.on_surface(surf, np.array(left), 0.0006), eva.on_surface(surf, np.array(right), 0.0006)


def tongue(v, surf):
    """Lengüeta: entre las dos filas de ojales, de bajo el último ojal a 2,4 cm sobre la boca, bajo los cordones."""
    cl, k0, k1 = lace_line(v)
    rows = list(range(min(k1 + 3, len(cl) - 1), -1, -1))           # de abajo a la boca
    q = np.linspace(-1, 1, 7)
    base, nrm = [], []
    for k in rows:
        p, n = eva.on_surface(surf, cl[k][None], 0.0)
        a = unit(np.array([1.0, 0, 0]) - n[0] * n[0][0])
        b, nn = eva.on_surface(surf, p[0] + np.outer(q * TONGUE_W, a), 0.0)
        base.append(b); nrm.append(nn)
    p, n = eva.on_surface(surf, cl[0][None], 0.0)
    a = unit(np.array([1.0, 0, 0]) - n[0] * n[0][0])
    up = unit(np.cross(n[0], a)) * np.sign(np.cross(n[0], a)[1])
    for k in range(1, 8):                                          # sobre la boca, algo hacia delante
        h = 0.0034 * k
        w = TONGUE_W * (1 - 0.35 * (k / 7) ** 3)
        base.append(p[0] + up * h + n[0] * (0.0012 * k) + np.outer(q * w, a)); nrm.append(np.tile(n[0], (7, 1)))
    base, nrm = np.array(base), np.array(nrm)
    return bt.grid_slab(base + nrm * 0.0018, base + nrm * 0.0003)


def heel_stay(v, surf):
    """Tira vertical detrás, de la boca a la suela."""
    back = v[:-1].reshape(-1, H.na, 3)[:, 0]
    back = back[: int(np.argmax(back[:, 1] < SOLE_Y1 - 0.004)) + 1]
    q = np.linspace(-1, 1, 5)
    base, nn = eva.on_surface(surf, (back[:, None] + np.outer(q * 0.0065, [1.0, 0, 0])[None]).reshape(-1, 3), 0.0)
    base, nn = base.reshape(len(back), 5, 3), nn.reshape(len(back), 5, 3)
    return bt.grid_slab(base + nn * 0.0018, base - nn * 0.0004)


def eyelet(p, n, size=1.0):
    ri, ro, h = 0.0021 * size, 0.0036 * size, 0.0008
    return casco.lathe([(ri, -h), (ro, -h), (ro, h), (ri, h)], p, n, 12)


def lace(surf, a, b, n=14):
    """Cordón entre dos ojales, por encima de la lengüeta."""
    pts = a + np.outer(np.linspace(0, 1, n), b - a)
    q, sn = eva.on_surface(surf, pts, 0.0)
    bump = np.sin(np.linspace(0, math.pi, n)) ** 0.4
    lift = 0.0010 + 0.0034 * bump
    v, f = eva.tube(q + sn * lift[:, None], sn, 0.0017, ribs=1.0, m=8)
    return v, f[:, ::-1] if np.einsum("ij,ij->", np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]]),
                                     v[f].mean(1) - q.mean(0)) < 0 else f


# ---------------- 4. montaje y .glb ----------------
def build_left():
    """Las piezas del pie izquierdo: [((v, f), zona, «leg» o «foot»)]."""
    v, f = H_SHELL
    surf = eva.Surface(v, f)
    parts = [((v, f), "lona", "leg")] + [(p, "lona", "leg") for p in H.lining(v, f, LINING_ROWS, THICK)]
    parts.append((toe_cap(v, f), "goma", "foot"))
    sv, sf = sole(v, "Left")
    parts += [((sv, sf), "goma", "foot"), (stripe(sv, "Left"), "franja", "foot")]
    parts += [(tongue(v, surf), "lona", "leg"), (heel_stay(v, surf), "lona", "leg")]
    (L, nl), (R, nr) = lace_points(v, surf)
    for k in range(EYELETS):
        parts += [(eyelet(L[k], nl[k]), "ojales", "leg"), (eyelet(R[k], nr[k]), "ojales", "leg")]
    parts.append((lace(surf, L[-1], R[-1]), "cordones", "leg"))            # abajo, recto
    for k in range(EYELETS - 1, 0, -1):                                     # cruzados hacia arriba
        parts += [(lace(surf, L[k], R[k - 1]), "cordones", "leg"), (lace(surf, R[k], L[k - 1]), "cordones", "leg")]
    g = LEG["Left"]                                                         # ventilación: dos ojales por dentro
    for dz in (0.0, 0.016):
        z = g["ankle"][2] + 0.045 + dz
        row = v[(np.abs(v[:, 2] - z) < 0.005) & (v[:, 1] > 0.072) & (v[:, 1] < 0.092)]
        q, nn = eva.on_surface(surf, row[np.argmin(row[:, 0])][None], 0.0006)
        parts.append((eyelet(q[0], nn[0], 0.85), "ojales", "foot"))
    return parts


def build():
    verts, faces, zones, src_idx, src_w = [], [], [], [], []
    for s in SIDES:
        mirror = np.array([SIDES[s], 1, 1])
        masks = {"leg": side_of(P0, s) & ((LOWER_W > 0.3) | (FOOT_W > 0.3)), "foot": side_of(P0, s) & (FOOT_W > 0.3)}
        for (v, f), zone, mk in build_left():
            v = np.asarray(v, float).reshape(-1, 3) * mirror
            f = np.asarray(f, int)
            faces.append((f if s == "Left" else f[:, ::-1]) + sum(len(x) for x in verts))
            verts.append(v)
            zones.append(np.tile(ZONES[zone], (len(v), 1)))
            i, w = sud.nearest_skin(v, 8, masks[mk])
            src_idx.append(i); src_w.append(w)
    v, f = np.concatenate(verts), np.concatenate(faces)
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
