"""Alas demoníacas (plano: planos/Hoja de referencia de alas demoníacas cel-shaded.webp).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_alas.py   (numpy y scipy)
Escribe packs/claude_alas/: alas_demonio, el par en **una sola pieza**, ranura «accesorio» (convive con todo).
- **Pequeñas** (decidido por el responsable): LENGTH = 35 cm de la espalda a la punta; **abiertas** (decidido): a los
  lados, algo hacia atrás y hacia arriba, lejos de los brazos.
- Cada ala, con la silueta medida en el plano: base (placa hundida en la espalda que sale BASE_OUT: asoma sobre la
  ropa), hueso del brazo hasta la muñeca, borde de ataque hasta la punta y tres dedos; membrana con grosor y el borde
  de salida en arcos entre las puntas. El ala se curva un poco hacia atrás hacia la punta.
- Rígidas: 100 % UpperChest; con las formas del cuerpo cada ala se mueve entera con su raíz (la media de la piel
  cercana). Tamaño, ubicación y postura con deslizadores: ver R en plan_assets.md.
Zonas en COLOR_0: (0,0,0) membrana; r = 1 hueso y base.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje", "claude_casco"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_sudadera as sud
import generar_traje as tr
import generar_casco as casco

OUT = HERE / "packs" / "claude_alas"
PID = "alas_demonio"
P0, D = sud.P0, math.radians
ZONES = {"membrana": (0, 0, 0, 1), "hueso": (1, 0, 0, 1)}
BONE = "UpperChest"

# --- medidas (metros) ---
LENGTH = 0.35                                   # de la raíz a la punta (la silueta va en unidades de LENGTH)
ROOT_X, ROOT_Y = 0.055, 1.24                    # raíz de cada ala en la espalda (bajo los omóplatos)
BASE_OUT, BASE_IN = 0.030, 0.012                # la base sale de la piel y se hunde en ella
SWEEP, RAISE, CURL = D(30), D(10), 0.10         # hacia atrás, plano inclinado hacia atrás arriba, curva a la punta
MEMBRANE = 0.0012                               # media grosor de la membrana

# --- silueta del ala izquierda (u fuera, v arriba; medida en el plano, la punta en u = 1) ---
WRIST = (0.248, 0.239)
TIP = (1.0, -0.124)
LEAD_CTRL = (0.513, 0.159)
FINGERS = [(0.664, -0.177), (0.381, -0.212), (0.159, -0.150)]
BASE_LOW = (0.0, -0.088)
SCALLOP = 0.28                                  # hondo de cada arco del borde de salida (fracción de la cuerda)


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


# ---------------- 1. silueta 2D ----------------
def bezier(a, c, b, n):
    t = np.linspace(0, 1, n)[:, None]
    return (1 - t) ** 2 * a + 2 * (1 - t) * t * c + t ** 2 * b


def scallop(a, b, n=10):
    """Arco entre dos puntas, hacia la muñeca."""
    a, b = np.array(a), np.array(b)
    t = np.linspace(0, 1, n)[:, None]
    mid = 0.5 * (a + b)
    inward = unit(np.array(WRIST) - mid)
    return a + t * (b - a) + inward * SCALLOP * np.linalg.norm(b - a) * np.sin(math.pi * t)


def outline():
    """Borde de la membrana, en orden: brazo, borde de ataque, arcos de salida y la base."""
    R, W = np.zeros(2), np.array(WRIST)
    parts = [np.linspace(R, W, 8), bezier(W, np.array(LEAD_CTRL), np.array(TIP), 14)]
    tips = [TIP] + FINGERS + [BASE_LOW]
    parts += [scallop(a, b) for a, b in zip(tips[:-1], tips[1:])]
    parts.append(np.linspace(np.array(BASE_LOW), R, 5))
    pts = np.vstack([p[:-1] for p in parts])                         # sin repetir las esquinas
    return pts


# ---------------- 2. del plano del ala al cuerpo ----------------
class Frame:
    """Plano del ala sobre la espalda: raíz, ejes u (fuera), v (arriba) y n (hacia atrás)."""
    def __init__(self, root, s):
        self.root = root
        eu = np.array([s * math.cos(SWEEP), 0, -math.sin(SWEEP)])
        ev = np.array([0, math.cos(RAISE), -math.sin(RAISE)])
        ev = unit(ev - eu * (ev @ eu))
        en = np.cross(eu, ev)
        self.eu, self.ev, self.en = eu, ev, (en if en[2] < 0 else -en)

    def map(self, uv, off=0.0):
        uv = np.atleast_2d(uv)
        u, v = uv[:, 0], uv[:, 1]
        bend = CURL * np.maximum(u, 0) ** 2                             # se curva hacia atrás hacia la punta
        return (self.root + np.outer(u * LENGTH, self.eu) + np.outer(v * LENGTH, self.ev)
                + np.outer(bend * LENGTH + off, self.en))


def back_point(s):
    """Punto de la piel de la espalda en (ROOT_X, ROOT_Y) y su normal."""
    back = np.where((P0[:, 2] < 0) & (np.abs(P0[:, 0]) < 0.15) & (np.abs(P0[:, 1] - ROOT_Y) < 0.08))[0]
    _, k = cKDTree(P0[back][:, :2]).query([s * ROOT_X, ROOT_Y], k=6)
    p = P0[back[k]].mean(0)
    n = np.array([0, 0, -1.0])
    return p, n, back[k]


# ---------------- 3. piezas ----------------
def membrane(fr, pts, K=8):
    """Membrana con grosor: rejilla polar desde un centro interior, cara de delante y de detrás y canto."""
    c = np.array([0.32, 0.0])
    M = len(pts)
    rings = np.stack([c + (pts - c) * (k / K) for k in range(1, K + 1)])        # K × M
    flat = rings.reshape(-1, 2)
    top = np.vstack([fr.map(c, MEMBRANE), fr.map(flat, MEMBRANE)])
    bot = np.vstack([fr.map(c, -MEMBRANE), fr.map(flat, -MEMBRANE)])
    i = np.arange(M)
    f = [np.stack([np.zeros(M, int), 1 + i, 1 + (i + 1) % M], -1), 1 + tr.ring_faces(K, M, False)]
    f = np.concatenate(f)
    n = len(top)
    rim_t, rim_b = 1 + (K - 1) * M + i, n + 1 + (K - 1) * M + i
    rim = np.concatenate([np.stack([rim_t, rim_b, np.roll(rim_t, -1)], -1),
                          np.stack([np.roll(rim_t, -1), rim_b, np.roll(rim_b, -1)], -1)])
    v = np.vstack([top, bot])
    return tr.orient_closed(v, np.concatenate([f, f[:, ::-1] + n, rim]))


def tube(pts, radii, up, m=10):
    """Tubo que se estrecha (radio por punto), con tapas."""
    t = unit(np.gradient(pts, axis=0))
    u = unit(up - t * (t @ up)[:, None])
    b = np.cross(t, u)
    a = np.linspace(0, 2 * math.pi, m, endpoint=False)
    rings = pts[:, None] + radii[:, None, None] * (np.cos(a)[None, :, None] * u[:, None] + np.sin(a)[None, :, None] * b[:, None])
    v = np.vstack([rings.reshape(-1, 3), pts[0], pts[-1]])
    n, i = len(pts), np.arange(m)
    side = tr.ring_faces(n, m, False)
    fn = np.cross(v[side[:, 1]] - v[side[:, 0]], v[side[:, 2]] - v[side[:, 0]])
    if np.einsum("ij,ij->", fn, v[side].mean(1) - pts[side[:, 0] // m]) < 0:   # el costado, hacia fuera del eje
        side = side[:, ::-1]
    caps = []
    for c, ring, out in ((n * m, i, pts[0] - pts[1]), (n * m + 1, (n - 1) * m + i, pts[-1] - pts[-2])):
        cf = np.stack([np.full(m, c), ring, ring[(i + 1) % m]], -1)
        cn = np.cross(v[cf[:, 1]] - v[cf[:, 0]], v[cf[:, 2]] - v[cf[:, 0]])
        caps.append(cf if (cn @ out).sum() > 0 else cf[:, ::-1])       # cada tapa, hacia su extremo
    return v, np.concatenate([side] + caps)


def bow(a, b, amount, n=16):
    """Curva de a a b, abombada hacia fuera de la muñeca (perpendicular a la cuerda)."""
    a, b = np.array(a, float), np.array(b, float)
    d = b - a
    perp = np.array([d[1], -d[0]]) / np.linalg.norm(d)
    return bezier(a, 0.5 * (a + b) + perp * amount * np.linalg.norm(d), b, n)


def bones(fr):
    W = np.array(WRIST)
    out = []
    arm = np.linspace([0.0, 0.0], W, 10)
    out.append(tube(fr.map(arm), np.linspace(0.011, 0.008, 10), fr.en))
    lead = bezier(W, np.array(LEAD_CTRL), np.array(TIP), 18)
    out.append(tube(fr.map(lead), np.linspace(0.007, 0.0015, 18), fr.en))
    for tip in FINGERS:
        path = bow(W, tip, 0.05)
        out.append(tube(fr.map(path), np.linspace(0.0055, 0.0015, len(path)), fr.en))
    k = np.array([W - [0.035, 0.0], W, W + [0.035, 0.0]])                 # nudillo de la muñeca
    kn = np.linspace(k[0], k[-1], 7)
    out.append(tube(fr.map(kn), 0.0045 + 0.0075 * np.sin(np.linspace(0, math.pi, 7)), fr.en))
    return out


def base(skin_p, n_back, s):
    """Placa de la base: hundida BASE_IN en la piel y sale BASE_OUT."""
    c = skin_p + n_back * (BASE_OUT - BASE_IN) / 2
    ex = np.array([1.0, 0, 0]); ey = np.array([0, 1.0, 0])
    return casco.box(c, np.array([0.014, 0.026, (BASE_OUT + BASE_IN) / 2]), ex, ey, n_back)


# ---------------- 4. montaje y .glb ----------------
def build():
    verts, faces, zones, roots = [], [], [], []
    pts2d = outline()
    for s, sx in (("Left", 1), ("Right", -1)):
        skin_p, n_back, near = back_point(sx)
        root = skin_p + n_back * (BASE_OUT - 0.004)
        fr = Frame(root, sx)
        parts = [(membrane(fr, pts2d), "membrana")] + [(b, "hueso") for b in bones(fr)]
        parts.append((base(skin_p, n_back, sx), "hueso"))
        for (v, f), z in parts:
            v = np.asarray(v, float); f = np.asarray(f, int)
            faces.append(f + sum(len(x) for x in verts))
            verts.append(v)
            zones.append(np.tile(ZONES[z], (len(v), 1)))
            roots.append(np.tile(near, (len(v), 1)))
        check(v_all=np.vstack(verts[-len(parts):]), s=s)
    return np.concatenate(verts), np.concatenate(faces), np.concatenate(zones), np.concatenate(roots)


def check(v_all, s):
    """Distancia del ala a los brazos y a la cabeza (en reposo)."""
    arm = P0[(sud.arm_w > 0.5) & (np.sign(P0[:, 0]) == sud.SIDES[s])]
    head = P0[sud.main_bone == "Head"]
    far = v_all[np.linalg.norm(v_all[:, :2] - [sud.SIDES[s] * ROOT_X, ROOT_Y], axis=1) > 0.06]
    print("MEDIDA ala %s: alto %.3f–%.3f, ancho hasta x = %.3f, a %.1f cm del brazo y %.1f cm de la cabeza" % (
        s, v_all[:, 1].min(), v_all[:, 1].max(), np.abs(v_all[:, 0]).max(),
        100 * cKDTree(arm).query(far)[0].min(), 100 * cKDTree(head).query(far)[0].min()))


def write(v, f, zc, roots):
    jb = sud.JN.index(BONE)
    to_rig = np.array([tr.RIG_JN.index(n) if n in tr.RIG_JN else -1 for n in sud.JN])
    jr = np.zeros((len(v), 4), int); jr[:, 0] = to_rig[jb]
    weights = np.zeros((len(v), 4)); weights[:, 0] = 1
    targets = {}
    for name, d in sud.B["targets"].items():
        moved = d[roots].mean(1)                                          # cada ala, entera con su raíz
        if np.abs(moved).max() >= 0.0005:
            targets[name] = moved.astype(np.float32)
    path = OUT / (PID + ".glb")
    sha = tr.write_glb(path, v, sud.vertex_normals(v, f), f, jr, weights, targets, PID, zc)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        PID, len(v), len(f), len(targets), path.stat().st_size / 1e6))
    return sha


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sha = write(*build())
    cards = [tr.card(PID, "Alas demoníacas", sha, [0.55, 0.13, 0.15], "accesorio", "accesorio")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_alas", "nombre": "Alas (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
