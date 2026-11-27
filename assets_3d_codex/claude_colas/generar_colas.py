"""Nueve colas de kitsune (plano: planos/Hoja de referencia_ nueve colas de kitsune.webp).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_colas.py   (numpy y scipy)
Escribe packs/claude_colas/: colas_kitsune, las nueve en **una sola pieza**, ranura «accesorio» (convive con todo).
- Del tamaño del plano (decidido por el responsable): 52–62 cm. Nacen juntas en el coxis (raíces hundidas 2 cm), salen
  hacia atrás y se abren en abanico **simétrico** (decidido por el responsable: en remolino parecían girar). Las de abajo pasan por detrás de las piernas: al andar pueden
  cruzarlas (aceptado; el movimiento llegará después, ver T en plan_assets.md).
- **Muy fur** (decidido): cada cola es un núcleo en forma de lágrima cubierto de mechones aplanados en punta, hacia la
  punta de la cola, solapados como escamas; en la punta se abren un poco (borde dentado, como el plano). El pelo suave
  de verdad necesita el núcleo (capas, ver S).
- Punta roja: zona propia; cada mechón cambia de color a una altura algo distinta (borde en llamas).
- Rígidas: 100 % Hips; con las formas del cuerpo cada cola se mueve entera con su raíz (solo las formas que mueven la
  raíz ≥ ROOT_MIN_MOVE).
Zonas en COLOR_0: (0,0,0) blanco; r = 1 punta roja.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_sudadera as sud
import generar_traje as tr

OUT = HERE / "packs" / "claude_colas"
PID = "colas_kitsune"
P0, D = sud.P0, math.radians
ZONES = {"blanco": (0, 0, 0, 1), "rojo": (1, 0, 0, 1)}
BONE = "Hips"
RNG = np.random.default_rng(9)

# --- medidas (metros) ---
ROOT_Y, ROOT_SINK, ROOT_SPREAD = 0.95, 0.02, 0.015     # raíz común en el coxis, hundida; cada cola a 1,5 cm del centro
# (ángulo desde arriba, + hacia la izquierda del personaje; largo; curva hasta la punta: las de arriba y los lados
# caen hacia fuera, las de abajo se abren lejos de las piernas; izquierda y derecha en espejo)
TAILS = [(0, 0.52, 0), (36, 0.58, 30), (-36, 0.58, -30), (72, 0.62, 30), (-72, 0.62, -30), (110, 0.60, 18),
         (-110, 0.60, -18), (148, 0.55, -12), (-148, 0.55, 12)]
BACK = 0.42                                             # cuánto se va hacia atrás (fracción del largo)
R_MAX = 0.19                                            # radio máximo de la lágrima (fracción del largo)
FLAT = 0.80                                             # sección: profundidad / ancho
TIP_EXTRA = 0.15                                        # el camino sigue tras la punta (los mechones de la punta)
RED_S = 0.72                                            # donde empieza el rojo (± RED_JIT por mechón)
RED_JIT = 0.06
ROOT_MIN_MOVE = 0.008                                   # formas que mueven la raíz menos: no van (está hundida 2 cm)
# mechones
ROW_STEP, LOCK_LEN = 0.09, 0.21                         # entre filas y largo de cada mechón (fracción del largo)
LOCK_W = 0.026                                          # media anchura de un mechón (m)
RINGS, SIDES = 5, 4


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


def profile(s):
    """Radio del núcleo (fracción de R_MAX): lágrima, estrecha en la raíz, ancha a media cola y en punta al final."""
    s = np.asarray(s, float)
    up = 0.3 + 0.7 * np.sin(math.pi / 2 * np.clip(s / 0.45, 0, 1))
    down = np.clip(1 - ((s - 0.45) / 0.55) ** 2, 0, 1) ** 0.8
    return np.where(s < 0.45, up, down) * (s <= 1)


class Tail:
    """Camino de una cola y su marco (e1 hacia atrás, e2 de lado en el abanico), muestreado en s ∈ [0, 1 + TIP_EXTRA]."""
    def __init__(self, root, th0, length, depth, curl):
        self.L = length
        s = np.linspace(0, 1 + TIP_EXTRA, 160)
        th = th0 + curl * s ** 2
        radial = np.stack([np.sin(th), np.cos(th), 0 * th], 1)
        back = (BACK * (1 - np.clip(1 - s, 0, 1) ** 5) + depth) * length    # sale hacia atrás enseguida
        self.s = s
        self.P = root + radial * (length * s)[:, None] + np.outer(back, [0, 0, -1.0])
        t = unit(np.gradient(self.P, axis=0))
        e1 = np.zeros_like(t)
        ref = np.array([0, 0, -1.0])
        for k in range(len(s)):                                       # transporte paralelo
            e = ref - t[k] * (ref @ t[k])
            e1[k] = e / np.linalg.norm(e)
            ref = e1[k]
        self.t, self.e1, self.e2 = t, e1, np.cross(t, e1)

    def at(self, s):
        s = np.asarray(s, float)
        f = lambda A: np.stack([np.interp(s, self.s, A[:, k]) for k in range(3)], -1)
        return f(self.P), unit(f(self.t)), unit(f(self.e1)), unit(f(self.e2))

    def radius(self, s):
        return R_MAX * self.L * profile(s)

    def surf(self, s, phi, r):
        """Punto a radio r alrededor del camino (sección elíptica), con su normal y su dirección alrededor."""
        P, t, e1, e2 = self.at(s)
        c, sn = np.cos(phi)[..., None], np.sin(phi)[..., None]
        p = P + np.asarray(r)[..., None] * (FLAT * c * e1 + sn * e2)
        n = unit(c * e1 / FLAT + sn * e2)
        around = unit(-FLAT * sn * e1 + c * e2)
        return p, n, around


# ---------------- piezas ----------------
def core(tail, rings=40, m=12):
    s = np.linspace(0, 1, rings)
    phi = np.linspace(0, 2 * math.pi, m, endpoint=False)
    S, PH = np.meshgrid(s, phi, indexing="ij")
    p, _, _ = tail.surf(S, PH, tail.radius(S) * 0.85)
    centers = tail.at(s)[0]
    v = np.vstack([p.reshape(-1, 3), centers[0], centers[-1]])
    return v, tube_faces(v, centers, rings, m)


def locks(tail):
    """Mechones: filas a lo largo de la cola, alrededor al tresbolillo. Devuelve (v, f, zona por vértice)."""
    rows = np.arange(0.02, 1.0, ROW_STEP)
    tau = np.linspace(0, 1, RINGS)
    a = np.linspace(0, 2 * math.pi, SIDES, endpoint=False)
    V, F, Z = [], [], []
    for j, s0 in enumerate(rows):
        r_mid = tail.radius(min(s0 + LOCK_LEN / 2, 1.0)) + 0.01
        n_around = int(np.clip(round(2 * math.pi * r_mid / (1.35 * LOCK_W)), 5, 14))
        for k in range(n_around):
            phi0 = 2 * math.pi * (k + 0.5 * (j % 2)) / n_around + RNG.uniform(-0.15, 0.15)
            ln = LOCK_LEN * RNG.uniform(0.85, 1.15)
            w0 = LOCK_W * RNG.uniform(0.85, 1.15) * (0.6 + 0.4 * min(1.0, s0 / 0.2))
            s = s0 + ln * tau
            phi = phi0 + RNG.uniform(-0.2, 0.2) * tau
            wl = w0 * (0.55 + 0.45 * np.sin(math.pi / 2 * np.clip(tau / 0.3, 0, 1))) * (1 - tau) ** 0.85 + 0.0008
            th = 0.38 * wl
            tip = 0.012 * RNG.uniform(0.6, 1.3) * tau ** 2 * (0.5 + s0)            # en la punta se abren más
            r = tail.radius(np.minimum(s, 1.0)) * 0.85 + th * 0.6 + 0.30 * w0 * np.sin(math.pi * tau) + tip
            c, n, around = tail.surf(s, phi, r)
            ring = c[:, None] + wl[:, None, None] * np.cos(a)[None, :, None] * around[:, None] \
                + th[:, None, None] * np.sin(a)[None, :, None] * n[:, None]
            v = np.vstack([ring.reshape(-1, 3), c[0], c[-1]])
            f = tube_faces(v, c, RINGS, SIDES)
            V.append(v); F.append(f + sum(len(x) for x in V[:-1]))
            red = s0 + ln * 0.5 > RED_S + RNG.uniform(-RED_JIT, RED_JIT)
            Z.append(np.tile(ZONES["rojo" if red else "blanco"], (len(v), 1)))
    return np.vstack(V), np.concatenate(F), np.vstack(Z)


def tube_faces(v, centers, n, m):
    """Caras de un tubo cerrado (n anillos de m puntos, luego los centros de las dos tapas), hacia fuera: el costado
    respecto a su eje y cada tapa hacia su extremo (por separado: en las puntas finas no coinciden)."""
    i = np.arange(m)
    side = tr.ring_faces(n, m, False)
    fn = np.cross(v[side[:, 1]] - v[side[:, 0]], v[side[:, 2]] - v[side[:, 0]])
    if np.einsum("ij,ij->", fn, v[side].mean(1) - centers[side[:, 0] // m]) < 0:
        side = side[:, ::-1]
    caps = []
    for c, ring, out in ((n * m, i, centers[0] - centers[1]), (n * m + 1, (n - 1) * m + i, centers[-1] - centers[-2])):
        cf = np.stack([np.full(m, c), ring, ring[(i + 1) % m]], -1)
        cn = np.cross(v[cf[:, 1]] - v[cf[:, 0]], v[cf[:, 2]] - v[cf[:, 0]])
        caps.append(cf if (cn @ out).sum() > 0 else cf[:, ::-1])
    return np.concatenate([side] + caps)


# ---------------- montaje y .glb ----------------
def root_point():
    back = np.where((P0[:, 2] < 0) & (np.abs(P0[:, 0]) < 0.08) & (np.abs(P0[:, 1] - ROOT_Y) < 0.06))[0]
    _, k = cKDTree(P0[back][:, :2]).query([0.0, ROOT_Y], k=8)
    return P0[back[k]].mean(0) + np.array([0, 0, ROOT_SINK]), back[k]


def build():
    root, near = root_point()
    verts, faces, zones = [], [], []
    for k, (deg, length, curl) in enumerate(TAILS):
        th0 = D(deg)
        r0 = root + ROOT_SPREAD * np.array([math.sin(th0), math.cos(th0), 0])
        tail = Tail(r0, th0, length, 0.06 * (k % 3) / 2, D(curl))
        cv, cf = core(tail)
        cz = np.tile(ZONES["blanco"], (len(cv), 1))
        cz[np.r_[np.repeat(np.linspace(0, 1, 40) >= RED_S + 0.05, 12), False, True]] = ZONES["rojo"]   # + tapas
        lv, lf, lz = locks(tail)
        for v, f, z in ((cv, cf, cz), (lv, lf, lz)):
            faces.append(f + sum(len(x) for x in verts))
            verts.append(v); zones.append(z)
    v, f = np.concatenate(verts), np.concatenate(faces)
    check(v, root)
    return v, f, np.concatenate(zones), near


def check(v, root):
    """Hueco de las colas al cuerpo (lejos de la raíz) y hasta dónde llegan."""
    far = v[np.linalg.norm(v - root, axis=1) > 0.10]
    body = P0[sud.main_bone != "Head"]
    d, i = cKDTree(body).query(far)
    print("MEDIDA colas: x %.2f a %.2f, y %.2f a %.2f, z hasta %.2f; hueco mínimo al cuerpo %.1f cm en %s" % (
        v[:, 0].min(), v[:, 0].max(), v[:, 1].min(), v[:, 1].max(), v[:, 2].min(), 100 * d.min(),
        np.round(far[d.argmin()], 3)))


def write(v, f, zc, near):
    to_rig = np.array([tr.RIG_JN.index(n) if n in tr.RIG_JN else -1 for n in sud.JN])
    jr = np.zeros((len(v), 4), int); jr[:, 0] = to_rig[sud.JN.index(BONE)]
    weights = np.zeros((len(v), 4)); weights[:, 0] = 1
    targets = {}
    for name, d in sud.B["targets"].items():
        moved = d[near].mean(0)                                          # todas, enteras con la raíz
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
    cards = [tr.card(PID, "Nueve colas de kitsune", sha, [0.96, 0.92, 0.92], "accesorio", "accesorio")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_colas", "nombre": "Colas (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
