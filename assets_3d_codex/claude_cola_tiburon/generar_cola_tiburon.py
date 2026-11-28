"""Cola de tiburón (plano: planos/cola_tiburon.png).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_cola_tiburon.py   (numpy y scipy)
Escribe packs/claude_cola_tiburon/: cola_tiburon, **una sola pieza**, ranura «accesorio» (convive con todo).
- Mediana, ~65 cm por su eje (decidido por el responsable): nace en el coxis (raíz hundida 2 cm), sale hacia atrás y
  algo hacia arriba y se dobla hacia abajo en **curva en S como el plano** (decidido); la aleta del final, en media luna,
  cuelga a la altura de las corvas y se abre a los lados (de cara atrás, como las vistas de frente y espalda del plano).
- Sección aplastada de lado (más alta que ancha). Lomo oscuro por fuera de la curva, tripa clara por dentro.
- Aleta dorsal grande en el lomo, dos pares de aletas pequeñas a los lados y **3 branquias en relieve** a cada lado
  de la raíz (decidido).
- Rígida: 100 % Hips; con las formas del cuerpo se mueve entera con su raíz (como las colas de kitsune). Vida
  (movimiento y deslizadores): pendiente, ver V en plan_assets.md.
Zonas en COLOR_0: (0,0,0) lomo; r = 1 tripa clara; g = 1 branquias.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.interpolate import CubicSpline
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje", "claude_colas"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_sudadera as sud
import generar_traje as tr
import generar_colas as kit

OUT = HERE / "packs" / "claude_cola_tiburon"
PID = "cola_tiburon"
P0 = sud.P0
ZONES = {"lomo": (0, 0, 0, 1), "tripa": (1, 0, 0, 1), "branquias": (0, 1, 0, 1)}
BONE = "Hips"

# --- medidas (metros) ---
BODY_LEN = 0.45                                  # cuerpo de la cola por su eje (más la aleta: ~65 cm)
# eje en el plano YZ desde la raíz (dy, dz), se escala a BODY_LEN: atrás y algo arriba, luego cae (curva en S)
AXIS = [(0, 0), (0.025, -0.09), (0.035, -0.18), (0.0, -0.27), (-0.09, -0.335), (-0.21, -0.36), (-0.33, -0.35)]
# media altura (lomo-tripa) y media anchura por s (0 raíz, 1 pedúnculo)
HALF_H = [(0, 0.068), (0.25, 0.060), (0.55, 0.045), (0.85, 0.026), (1.0, 0.018)]
HALF_W = [(0, 0.058), (0.25, 0.048), (0.55, 0.035), (0.85, 0.020), (1.0, 0.014)]
BELLY = 0.35                                     # tripa: cos(ángulo) < -BELLY (por dentro de la curva)
# aletas: (s de la base, largo de la base, alto, cuánto se va hacia atrás la punta, grosor), dirección
DORSAL = (0.14, 0.065, 0.058, 1.15, 0.005)    # la mitad (pedido por el responsable)
SIDE_FINS = [(0.30, 0.07, 0.055, 1.25, 0.005), (0.58, 0.05, 0.040, 1.25, 0.004)]
SIDE_UP = 0.35                                   # las de los lados, algo hacia el lomo
FLUKE_LEN, FLUKE_HW, FLUKE_T = 0.20, 0.17, 0.008 # aleta del final: largo, media envergadura, grosor
FLUKE_NOTCH = 0.55                               # la muesca del centro (fracción del largo)
FLUKE_LIGHT = 0.72                               # borde de atrás claro (fracción de su ancho)
GILLS = [0.10, 0.135, 0.17]                      # branquias: s de cada una
GILL_W, GILL_LIFT = 0.0022, 0.0009
ROOT_MIN_MOVE = 0.008


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


class Axis:
    """Eje de la cola por longitud de arco s ∈ [0, 1]; marco: t (tangente), up (lomo, por fuera de la curva), x."""
    def __init__(self, root):
        c = np.array(AXIS, float)
        P = np.stack([np.zeros(len(c)), c[:, 0], c[:, 1]], 1)
        chord = np.r_[0, np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))]
        sp = CubicSpline(chord, P, bc_type="natural")
        u = np.linspace(0, chord[-1], 400)
        Q = sp(u)
        arc = np.r_[0, np.cumsum(np.linalg.norm(np.diff(Q, axis=0), axis=1))]
        self.s = arc / arc[-1]
        self.P = root + Q * (BODY_LEN / arc[-1])
        self.t = unit(np.gradient(self.P, axis=0))
        self.x = np.array([1.0, 0, 0])
        self.up = unit(np.cross(self.x, self.t))

    def at(self, s):
        s = np.asarray(s, float)
        f = lambda A: np.stack([np.interp(s, self.s, A[:, k]) for k in range(3)], -1)
        return f(self.P), unit(f(self.t)), unit(f(self.up))

    def surf(self, s, phi, scale=1.0):
        """Punto de la piel de la cola (phi: 0 lomo, π/2 lado +x, π tripa) y su normal."""
        P, t, up = self.at(s)
        h, w = np.interp(s, *zip(*HALF_H)) * scale, np.interp(s, *zip(*HALF_W)) * scale
        c, sn = np.cos(phi)[..., None], np.sin(phi)[..., None]
        p = P + h[..., None] * c * up + w[..., None] * sn * self.x
        n = unit(c * up / h[..., None] + sn * self.x / w[..., None])
        return p, n


# ---------------- piezas ----------------
def body(ax, rings=70, m=28):
    s = np.linspace(0, 1, rings)
    phi = np.linspace(0, 2 * math.pi, m, endpoint=False)
    S, PH = np.meshgrid(s, phi, indexing="ij")
    p, _ = ax.surf(S, PH)
    centers = ax.at(s)[0]
    v = np.vstack([p.reshape(-1, 3), centers[0], centers[-1]])
    z = np.where(np.cos(PH).ravel() < -BELLY, 1, 0)
    return v, kit.tube_faces(v, centers, rings, m), np.r_[z, 0, 0]


def plate(origin_fn, a_n, b_n, thick_fn, rim_fn):
    """Lámina con grosor: origin_fn(a, b) -> (punto, normal de la cara) en una rejilla a×b. En el borde (rim_fn) las
    dos caras comparten los vértices (cerrada, sin grosor allí); el borde b = 0 de las aletas queda dentro del cuerpo.
    Devuelve v, f y (a, b) de cada vértice."""
    A, B = np.meshgrid(np.linspace(0, 1, a_n), np.linspace(0, 1, b_n), indexing="ij")
    p, n = origin_fn(A, B)
    rim = rim_fn(A, B).ravel()
    t = np.where(rim_fn(A, B), 0.0, thick_fn(A, B))[..., None]
    top, bot = (p + n * t).reshape(-1, 3), (p - n * t).reshape(-1, 3)
    i, j = np.meshgrid(np.arange(a_n - 1), np.arange(b_n - 1), indexing="ij")
    q = (i * b_n + j).ravel()
    f = np.concatenate([np.stack([q, q + b_n, q + b_n + 1], 1), np.stack([q, q + b_n + 1, q + 1], 1)])
    v = np.vstack([top, bot])
    f = np.vstack([f, f[:, ::-1] + len(top)])
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    ref = np.vstack([n.reshape(-1, 3), -n.reshape(-1, 3)])[f[:, 0]]
    flip = np.einsum("ij,ij->i", fn, ref) < 0
    f[flip] = f[flip][:, ::-1]
    k = np.arange(len(top))
    remap = np.r_[k, np.where(rim, k, k + len(top))]                    # el borde de abajo, el mismo que el de arriba
    f = remap[f]
    f = f[~((f < len(top)).all(1) & (np.arange(len(f)) >= len(f) // 2))]  # sin repetir caras ya del todo en el borde
    v, f, a, b = tr.compact(v, f, np.tile(A.ravel(), 2), np.tile(B.ravel(), 2))
    return v, f, a, b


def fin(ax, spec, side):
    """Aleta de tiburón: borde de delante convexo, el de atrás cóncavo, punta echada hacia atrás.
    side = 0: dorsal (en el lomo); ±1: a ese lado."""
    s0, base, height, sweep, thick = spec
    L = BODY_LEN
    tip = base * sweep

    def origin(A, B):
        uL = tip * B ** 2
        uT = base * (1 - 0.5 * B) + (tip - 0.5 * base) * B ** 3
        u = uL + A * (uT - uL)
        s = np.clip(s0 + u / L, 0, 1)
        phi = np.zeros_like(s) if side == 0 else np.full_like(s, side * math.pi / 2)
        root, _ = ax.surf(s, phi, 0.75)
        _, t, up = ax.at(s)
        d = up if side == 0 else unit(side * ax.x + SIDE_UP * up)
        extra = np.maximum(u - L * (1 - s0), 0)[..., None] * t          # por si pasa del final
        p = root + extra + d * (B * (height + 0.25 * np.interp(s, *zip(*HALF_H))))[..., None]
        return p, unit(np.cross(t, d))

    def thick_fn(A, B):
        return thick * np.sin(math.pi * np.clip(A, 0.02, 0.98)) ** 0.5 * (1 - B) ** 0.7 + 1e-4

    v, f, _, _ = plate(origin, 16, 14, thick_fn, lambda A, B: (A == 0) | (A == 1) | (B == 1))
    return v, f, np.zeros(len(v), int)


def fluke(ax):
    """Aleta del final en media luna, abierta a los lados (de cara atrás). Borde de atrás claro."""
    P, t, up = ax.at(np.array([1.0]))
    P, t, up = P[0], t[0], up[0]
    h_end = HALF_H[-1][1]

    def origin(A, B):
        x = (2 * A - 1) * FLUKE_HW
        xi = np.abs(x) / FLUKE_HW
        u_top = FLUKE_LEN * 0.92 * xi ** 2.6                           # borde de delante abombado
        u_bot = FLUKE_LEN * (FLUKE_NOTCH + (1 - FLUKE_NOTCH) * xi ** 1.3) - 0.04 * FLUKE_LEN * np.exp(-(xi / 0.06) ** 2)
        u = u_top + B * (u_bot - u_top) - 0.5 * h_end
        bend = 0.05 * FLUKE_LEN * xi ** 2                                # las puntas, algo hacia el lomo
        p = P + u[..., None] * t + x[..., None] * ax.x + bend[..., None] * up
        return p, np.broadcast_to(up, p.shape)

    def thick_fn(A, B):
        xi = np.abs(2 * A - 1)
        return FLUKE_T * (1 - xi) ** 0.5 * (1 - B) ** 0.6 * np.minimum(1, B / 0.12) ** 0.5 + 1e-4

    v, f, _, B = plate(origin, 41, 16, thick_fn, lambda A, B: (A == 0) | (A == 1) | (B == 0) | (B == 1))
    return v, f, np.where(B > FLUKE_LIGHT, 1, 0)


def gills(ax):
    """Tres marcas curvas a cada lado de la raíz, en relieve sobre la piel."""
    out = []
    for side in (1, -1):
        for k, s in enumerate(GILLS):
            ang = np.linspace(-0.5, 0.75, 12)                           # de la tripa hacia el lomo, por el lado
            phi = side * (math.pi / 2 - ang)
            ss = s + 0.012 * (1 - (ang / 0.75) ** 2) - 0.006 * k
            p, n = ax.surf(ss, phi)
            v, f = tr.sweep(p + n * GILL_LIFT, n, tr.rect(-GILL_LIFT, GILL_LIFT * 0.6,
                                                          GILL_W * (1 - 0.15 * k)))
            out.append((v, f, np.full(len(v), 2)))
    return out


# ---------------- montaje y .glb ----------------
def root_point():
    back = np.where((P0[:, 2] < 0) & (np.abs(P0[:, 0]) < 0.08) & (np.abs(P0[:, 1] - kit.ROOT_Y) < 0.06))[0]
    _, k = cKDTree(P0[back][:, :2]).query([0.0, kit.ROOT_Y], k=8)
    return P0[back[k]].mean(0) + np.array([0, 0, 0.02]), back[k]


def build():
    root, near = root_point()
    ax = Axis(root)
    parts = [body(ax), fin(ax, DORSAL, 0), fluke(ax)]
    parts += [fin(ax, spec, side) for spec in SIDE_FINS for side in (1, -1)]
    parts += gills(ax)
    verts, faces, zones = [], [], []
    for v, f, z in parts:
        faces.append(f + sum(len(x) for x in verts))
        verts.append(v); zones.append(z)
    v, f, z = np.concatenate(verts), np.concatenate(faces), np.concatenate(zones)
    check(v, root)
    zc = np.array([ZONES["lomo"], ZONES["tripa"], ZONES["branquias"]], float)[z]
    return v, f, zc, near


def check(v, root):
    """Hueco de la cola al cuerpo (lejos de la raíz) y hasta dónde llega."""
    far = v[np.linalg.norm(v - root, axis=1) > 0.12]
    d, _ = cKDTree(P0[sud.main_bone != "Head"]).query(far)
    print("MEDIDA cola: x %.2f a %.2f, y %.2f a %.2f, z hasta %.2f; hueco mínimo al cuerpo %.1f cm en %s" % (
        v[:, 0].min(), v[:, 0].max(), v[:, 1].min(), v[:, 1].max(), v[:, 2].min(), 100 * d.min(),
        np.round(far[d.argmin()], 3)))


def write(v, f, zc, near):
    to_rig = np.array([tr.RIG_JN.index(n) if n in tr.RIG_JN else -1 for n in sud.JN])
    jr = np.zeros((len(v), 4), int); jr[:, 0] = to_rig[sud.JN.index(BONE)]
    weights = np.zeros((len(v), 4)); weights[:, 0] = 1
    targets = {}
    for name, d in sud.B["targets"].items():
        moved = d[near].mean(0)                                          # entera con la raíz
        if np.linalg.norm(moved) >= ROOT_MIN_MOVE:
            targets[name] = np.tile(moved, (len(v), 1)).astype(np.float32)
    path = OUT / (PID + ".glb")
    sha = tr.write_glb(path, v, sud.vertex_normals(v, f), f, jr, weights, targets, PID, zc)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        PID, len(v), len(f), len(targets), path.stat().st_size / 1e6))
    return sha


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sha = write(*build())
    cards = [tr.card(PID, "Cola de tiburón", sha, [0.27, 0.33, 0.45], "accesorio", "accesorio")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_cola_tiburon", "nombre": "Cola de tiburón (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
