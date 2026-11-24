"""Seis tentáculos (con ventosas) que salen del centro de la espalda hacia los lados, para la humana de GameMolde.

Uso:  python generar_tentaculos.py
Lee godot/datos/humana/cuerpo.glb (espalda y formas) y el esqueleto de godot/packs/base/tights.glb; escribe
packs/claude_tentaculos/tentaculos_espalda.glb y su pack.json.
- Tres por lado: arriba y en medio, grandes; abajo, pequeño. Nacen juntos en el centro de la espalda, bajo los
  omóplatos (la raíz, hundida en la piel), salen un poco hacia atrás y enseguida se abren hacia los lados. Cada uno con
  su propio movimiento (dirección, ondas, punta enroscada y vaivén en profundidad): nada de simetría, no son alas.
- Un color (las ventosas, en relieve). Ranura «accesorio». 100 % del hueso UpperChest (el de esa zona de la espalda).
- Formas del cuerpo: cada tentáculo se mueve entero con su raíz (la media de la piel cercana); no se deforma.
- El tamaño es fijo: cómo hacerlo ajustable está en plan_assets.md.
"""
import hashlib, json, math, struct, sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).parents[1] / "claude_gorra"))
import glb

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / "packs" / "claude_tentaculos"
D = math.radians
HUESO = "UpperChest"
RAIZ_X, RAIZ_HUNDIDA = 0.03, 0.02          # raíces a ±3 cm del centro, 2 cm dentro de la piel
ANILLOS, LADOS = 90, 12                    # resolución del cuerpo del tentáculo

# Cada tentáculo. lado: +1 = izquierda del personaje (+x); y: altura de la raíz; largo y radio de la raíz (m);
# th0: hacia dónde va al salir (0 = de lado, + = arriba); curva: lo que gira poco a poco; onda (amplitud, ondas, fase);
# giro: punta enroscada (+ = hacia arriba); atras (grados hacia atrás una vez fuera) y vaiven (amplitud, ondas, fase)
# en profundidad. Las puntas se enroscan lejos del cuerpo: nunca hacia la cabeza ni los brazos.
TENTACULOS = [
    dict(lado=1, y=1.250, largo=0.60, radio=0.041, th0=D(22), curva=D(-40), onda=(D(24), 1.6, 0.0), giro=D(200),
         atras=D(9), vaiven=(D(8), 1.5, 0.0)),
    dict(lado=1, y=1.190, largo=0.56, radio=0.040, th0=D(-10), curva=D(40), onda=(D(30), 1.1, 0.8), giro=D(-110),
         atras=D(13), vaiven=(D(6), 2.0, 1.2)),
    dict(lado=1, y=1.130, largo=0.34, radio=0.028, th0=D(-45), curva=D(40), onda=(D(15), 1.0, 0.3), giro=D(220),
         atras=D(11), vaiven=(D(5), 1.0, 2.0)),
    dict(lado=-1, y=1.230, largo=0.62, radio=0.042, th0=D(20), curva=D(5), onda=(D(35), 2.0, 1.5), giro=D(-130),
         atras=D(12), vaiven=(D(7), 1.2, 0.6)),
    dict(lado=-1, y=1.170, largo=0.58, radio=0.040, th0=D(-30), curva=D(60), onda=(D(20), 1.3, 2.4), giro=D(170),
         atras=D(8), vaiven=(D(9), 1.8, 2.8)),
    dict(lado=-1, y=1.100, largo=0.36, radio=0.027, th0=D(-15), curva=D(-20), onda=(D(22), 1.5, 0.4), giro=D(190),
         atras=D(12), vaiven=(D(5), 1.4, 1.0)),
]


# ---------------- espalda ----------------
body, body_buf = glb.read(ROOT / "godot/datos/humana/cuerpo.glb")
B = glb.mesh_data(body, body_buf)
P0 = B["POSITION"].astype(float)


def root_point(x, y):
    """Punto de la espalda (la piel más de atrás cerca de x, y), metido RAIZ_HUNDIDA hacia dentro."""
    m = (np.abs(P0[:, 0] - x) < 0.012) & (np.abs(P0[:, 1] - y) < 0.01) & (P0[:, 2] < 0)
    p = P0[np.where(m)[0][P0[m, 2].argmin()]].copy()
    p[2] += RAIZ_HUNDIDA
    return p


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


# ---------------- tentáculo ----------------
def centerline(t):
    """Puntos, tangentes, lado de las ventosas y radio a lo largo del tentáculo (s de 0 a 1)."""
    s = np.linspace(0, 1, ANILLOS)
    side = t["lado"]
    amp, waves, ph = t["onda"]
    th = t["th0"] + t["curva"] * s + amp * np.sin(math.pi * waves * s + ph) * (1 - s) - amp * math.sin(ph) * (1 - s)         + t["giro"] * s ** 3.2
    za, zw, zp = t["vaiven"]
    back = D(60) * np.exp(-s / 0.06) + t["atras"] + za * np.sin(2 * math.pi * zw * s + zp)  # sale y se abre de lado
    L = np.array([side, 0.0, 0.0]); Y = np.array([0, 1.0, 0]); Z = np.array([0, 0, -1.0])
    T = (np.cos(back) * np.cos(th))[:, None] * L + (np.cos(back) * np.sin(th))[:, None] * Y + np.sin(back)[:, None] * Z
    ds = t["largo"] / (ANILLOS - 1)
    pts = root_point(side * RAIZ_X, t["y"]) + np.concatenate([[np.zeros(3)], np.cumsum(T[:-1] * ds, 0)])
    inward = np.sign(t["giro"]) * ((-np.sin(th))[:, None] * L + np.cos(th)[:, None] * Y)   # hacia donde se enrosca
    S = unit(inward - T * (inward * T).sum(1, keepdims=True))
    r = t["radio"] * (1 - s) ** 0.85 + 0.0025
    return s, pts, T, S, np.cross(T, S), r


def faces(n, m):
    j, i = np.meshgrid(np.arange(n - 1), np.arange(m), indexing="ij")
    a, b = j * m + i, j * m + (i + 1) % m
    c, d = a + m, b + m
    return np.concatenate([np.stack([a, c, b], -1).reshape(-1, 3), np.stack([b, c, d], -1).reshape(-1, 3)])


def closed(rings):
    """Anillos (n, m, 3) unidos y con tapas: malla cerrada con las caras hacia fuera."""
    n, m = rings.shape[:2]
    v, f = rings.reshape(-1, 3), faces(n, m)
    i = np.arange(m)
    c0, c1 = len(v), len(v) + 1
    v = np.concatenate([v, [rings[0].mean(0), rings[-1].mean(0)]])
    f = np.concatenate([f, np.stack([np.full(m, c0), i, (i + 1) % m], -1),
                        np.stack([np.full(m, c1), (n - 1) * m + (i + 1) % m, (n - 1) * m + i], -1)])
    vol = np.einsum("ij,ij->i", v[f[:, 0]], np.cross(v[f[:, 1]], v[f[:, 2]])).sum()
    return v, (f if vol > 0 else f[:, ::-1])


def sucker(p, n, a):
    """Ventosa: aro en relieve con el centro hundido, de radio a, sobre la piel en p con normal n."""
    prof = np.array([(0.02, -0.4), (1.0, -0.4), (1.0, 0.2), (0.75, 0.5), (0.45, 0.4), (0.02, 0.15)]) * a
    e1 = unit(np.cross(n, [0, 1.0, 0] if abs(n[1]) < 0.9 else [1.0, 0, 0]))
    e2 = np.cross(n, e1)
    ph = np.linspace(0, 2 * math.pi, 8, endpoint=False)[:, None, None]
    rings = p + n * prof[None, :, 1, None] + (e1 * np.cos(ph) + e2 * np.sin(ph)) * prof[None, :, 0, None]
    v = rings.reshape(-1, 3)
    m = len(prof)
    j, i = np.meshgrid(np.arange(8), np.arange(m), indexing="ij")     # perfil cerrado y vuelta cerrada
    q, r_ = j * m + i, j * m + (i + 1) % m
    c, d = ((j + 1) % 8) * m + i, ((j + 1) % 8) * m + (i + 1) % m
    f = np.concatenate([np.stack([q, c, r_], -1).reshape(-1, 3), np.stack([r_, c, d], -1).reshape(-1, 3)])
    vol = np.einsum("ij,ij->i", v[f[:, 0]], np.cross(v[f[:, 1]], v[f[:, 2]])).sum()
    return v, (f if vol > 0 else f[:, ::-1])


def tentacle(t):
    s, pts, T, S, Bn, r = centerline(t)
    ph = np.linspace(0, 2 * math.pi, LADOS, endpoint=False)
    ring_dir = np.cos(ph)[None, :, None] * S[:, None, :] + np.sin(ph)[None, :, None] * Bn[:, None, :]
    parts = [closed(pts[:, None, :] + ring_dir * r[:, None, None])]
    k, arc = 3, 0.0                                     # ventosas por pares hacia dentro de la curva
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    while k < ANILLOS - 3:
        a = 0.30 * r[k]
        if a < 0.0022:
            break
        for g in (D(-30), D(30)):
            n = unit(np.cos(g) * S[k] + np.sin(g) * Bn[k])
            parts.append(sucker(pts[k] + n * r[k] * 0.97, n, a))
        step, arc = 2.9 * a, 0.0
        while k < ANILLOS - 3 and arc < step:
            arc += seg[k]
            k += 1
    return parts, pts[0]


# ---------------- formas: cada tentáculo, rígido con su raíz ----------------
def root_moves(points):
    near = [np.argsort(((P0 - p) ** 2).sum(1))[:12] for p in points]
    out = {}
    for name, delta in B["targets"].items():
        m = np.array([delta[i].mean(0) for i in near])
        if np.abs(m).max() > 0.002:
            out[name] = m
    return out


# ---------------- .glb ----------------
def vertex_normals(v, f):
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    n = np.zeros_like(v)
    for k in range(3):
        np.add.at(n, f[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


def write_glb(path, pos, nrm, tris, tg_all, name):
    rig, rig_buf = glb.read(ROOT / "godot/packs/base/tights.glb")
    bone = glb.joint_names(rig).index(HUESO)
    ibm = glb.accessor(rig, rig_buf, rig["skins"][0]["inverseBindMatrices"]).astype(np.float32)
    blob = bytearray(); views = []; accs = []

    def add(arr, ctype, kind, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": arr.nbytes,
                      **({"target": target} if target else {})})
        blob.extend(arr.tobytes())
        a = {"bufferView": len(views) - 1, "componentType": ctype, "count": len(arr), "type": kind}
        if minmax:
            a["min"] = arr.min(0).tolist(); a["max"] = arr.max(0).tolist()
        accs.append(a)
        return len(accs) - 1

    n = len(pos)
    uv = np.stack([pos[:, 0], pos[:, 1]], 1)
    attrs = {
        "POSITION": add(pos.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": add(nrm.astype(np.float32), 5126, "VEC3", 34962),
        "TEXCOORD_0": add(uv.astype(np.float32), 5126, "VEC2", 34962),
        "JOINTS_0": add(np.tile(np.array([bone, 0, 0, 0], np.uint16), (n, 1)), 5123, "VEC4", 34962),
        "WEIGHTS_0": add(np.tile(np.array([1, 0, 0, 0], np.float32), (n, 1)), 5126, "VEC4", 34962),
    }
    names = list(tg_all)
    tg = [{"POSITION": add(tg_all[k], 5126, "VEC3", 34962, True)} for k in names]
    ind = add(tris.astype(np.uint32).ravel(), 5125, "SCALAR", 34963)
    ibm_acc = add(ibm.reshape(-1, 16), 5126, "MAT4")
    doc = {
        "asset": {"version": "2.0", "generator": "GameMolde generar_tentaculos.py"},
        "scene": 0, "scenes": rig["scenes"], "nodes": rig["nodes"],
        "skins": [{**rig["skins"][0], "inverseBindMatrices": ibm_acc}],
        "meshes": [{"name": name, "extras": {"targetNames": names},
                    "primitives": [{"attributes": attrs, "indices": ind, "targets": tg, "mode": 4}]}],
        "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(blob)}],
    }
    doc["nodes"][next(i for i, nd in enumerate(doc["nodes"]) if "mesh" in nd)]["name"] = name
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    while len(blob) % 4:
        blob.append(0)
    total = 12 + 8 + len(js) + 8 + len(blob)
    data = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js \
        + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    path.write_bytes(data)
    return hashlib.sha256(data).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    vs, fs, owner, roots = [], [], [], []
    for t in TENTACULOS:
        parts, root = tentacle(t)
        for v, f in parts:
            fs.append(f + sum(len(x) for x in vs))
            vs.append(v)
            owner.append(np.full(len(v), len(roots)))
        roots.append(root)
    v, f, owner = np.concatenate(vs), np.concatenate(fs), np.concatenate(owner)
    tg = {name: m[owner].astype(np.float32) for name, m in root_moves(np.array(roots)).items()}
    pid = "tentaculos_espalda"
    sha = write_glb(OUT / (pid + ".glb"), v, vertex_normals(v, f), f, tg, pid)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB; ancho total %.2f m, alto %.2f m" % (
        pid, len(v), len(f), len(tg), (OUT / (pid + ".glb")).stat().st_size / 1e6, np.ptp(v[:, 0]), np.ptp(v[:, 1])))
    print("MEDIDA lo más atrás: z=%.3f (espalda en z = -0.07); de alto, de y=%.2f a %.2f" % (
        v[:, 2].min(), v[:, 1].min(), v[:, 1].max()))
    JN = glb.joint_names(body)
    arm = np.isin(B["JOINTS_0"][:, 0], [JN.index(n) for n in JN if "Arm" in n or n.endswith("Hand")])
    gap = min(np.sqrt(((v[i:i + 2000, None] - P0[arm][None]) ** 2).sum(-1)).min() for i in range(0, len(v), 2000))
    print("MEDIDA distancia mínima a los brazos (reposo): %.1f cm" % (gap * 100))
    card = {"id": pid, "nombre": "Tentáculos de la espalda", "archivo": pid + ".glb", "sha256": sha,
            "tipo": "accesorio", "ranura": "accesorio", "especies": ["humana"], "colores": ["principal"],
            "color": [0.5, 0.44, 0.54], "sigue_al_cuerpo": True, "fisica": [], "miniatura": "",
            "anclaje": {"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]}}
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_tentaculos", "nombre": "Tentáculos (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": [card]}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
