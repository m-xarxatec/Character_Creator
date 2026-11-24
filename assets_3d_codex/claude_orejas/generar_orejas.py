"""Orejas de gato (sin diadema) para la humana de GameMolde.

Uso:  python generar_orejas.py
Lee godot/datos/humana/cuerpo.glb (cráneo y formas) y el esqueleto de godot/packs/base/tights.glb; escribe en
packs/claude_orejas/ dos piezas (un color cada una) y su pack.json:
  orejas_gato            las dos orejas (fuera y borde)
  orejas_gato_interior   el interior rosa del cuenco
- Ranura «accesorio»: conviven con cualquier peinado. 100 % del hueso Head.
- Nacen del cráneo (la base, algo hundida): sin pelo salen de la piel; con pelo asoman entre él (el 80 % de los
  peinados abulta ≤ 2 cm en esa línea y la oreja mide OREJA_ALTO).
- Formas del cuerpo: cada oreja se mueve entera con su base (la base, como la media del cráneo cercano).
"""
import hashlib, json, math, struct, sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).parents[1] / "claude_gorra"))
import glb

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / "packs" / "claude_orejas"
D = math.radians

# --- medidas (metros) ---
INCLINACION = D(15)            # plano en el que van las dos orejas: arriba, hacia delante
DETRAS_OREJA = 0.008           # el plano pasa por detrás de la oreja humana
OREJA_PHI = D(42)              # cada oreja, a 42° de la cima en ese plano
OREJA_ALTO, OREJA_BASE = 0.062, 0.058
OREJA_HUNDIDA = 0.010          # cuánto entra la base en la cabeza (las esquinas no quedan al aire)
OREJA_CUENCO, OREJA_BORDE, OREJA_LOMO = 0.010, 0.0035, 0.006
OREJA_GIRO = D(20)             # miran algo hacia fuera
OREJA_RECTA = 0.45             # 0 = sale perpendicular al cráneo; 1 = vertical


# ---------------- cráneo ----------------
body, body_buf = glb.read(ROOT / "godot/datos/humana/cuerpo.glb")
B = glb.mesh_data(body, body_buf)
P0 = B["POSITION"].astype(float)
JN = glb.joint_names(body)
HW = (B["WEIGHTS_0"] * (B["JOINTS_0"] == JN.index("Head"))).sum(1)
_tri = B["indices"].reshape(-1, 3)
_tri = _tri[(HW[_tri] > 0.5).all(1)]
_bary = np.array([(i, j, 8 - i - j) for i in range(9) for j in range(9 - i)], float) / 8
SKIN = np.einsum("bk,tkc->tbc", _bary, P0[_tri]).reshape(-1, 3)      # nube densa de la cabeza

_ear = P0[(HW > 0.5) & (np.abs(P0[:, 0]) > 0.075)]                   # orejas humanas
O = np.array([0.0, _ear[:, 1].max(), _ear[:, 2].min() - DETRAS_OREJA])
UP = np.array([0, math.cos(INCLINACION), math.sin(INCLINACION)])
FW = np.array([0, -math.sin(INCLINACION), math.cos(INCLINACION)])   # normal del plano (hacia delante)
EX = np.array([1.0, 0, 0])


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


def head_radius(phi):
    """Distancia del centro O a la piel en el plano, en la dirección phi (franja de ±6 mm y ±2°)."""
    d = SKIN - O
    d = d[np.abs(d @ FW) < 0.006]
    a = np.arctan2(d @ UP, d @ EX)
    return np.hypot(d @ UP, d @ EX)[np.abs(a - phi) < D(2)].max()


# ---------------- malla ----------------
def faces(n, m):
    j, i = np.meshgrid(np.arange(n - 1), np.arange(m), indexing="ij")
    a, b = j * m + i, j * m + (i + 1) % m
    c, d = a + m, b + m
    return np.concatenate([np.stack([a, c, b], -1).reshape(-1, 3), np.stack([b, c, d], -1).reshape(-1, 3)])


def tube(rings):
    """Anillos (n, m, 3) cerrados en m, unidos en n y con tapas: malla cerrada con las caras hacia fuera."""
    n, m = rings.shape[:2]
    v, f = rings.reshape(-1, 3), faces(n, m)
    i = np.arange(m)
    c0, c1 = len(v), len(v) + 1
    v = np.concatenate([v, [rings[0].mean(0), rings[-1].mean(0)]])
    f = np.concatenate([f, np.stack([np.full(m, c0), i, (i + 1) % m], -1),
                        np.stack([np.full(m, c1), (n - 1) * m + (i + 1) % m, (n - 1) * m + i], -1)])
    vol = np.einsum("ij,ij->i", v[f[:, 0]], np.cross(v[f[:, 1]], v[f[:, 2]])).sum()
    return v, (f if vol > 0 else f[:, ::-1])


def ear_frame(side):
    phi = math.pi / 2 - side * (math.pi / 2 - OREJA_PHI)
    radial = math.cos(phi) * EX + math.sin(phi) * UP
    base = O + radial * head_radius(phi)                            # sobre la piel
    up = unit(radial * (1 - OREJA_RECTA) + np.array([0, 1.0, 0]) * OREJA_RECTA)
    g = OREJA_GIRO * side                                           # gira hacia fuera alrededor de up
    f = unit(FW - up * (FW @ up))
    f = unit(f * math.cos(g) + np.cross(up, f) * math.sin(g))
    return base, up, f, np.cross(up, f)


def ear_section(s, inner):
    """Sección (x lateral, z delante) a la altura s (0 = piel, 1 = punta): cuenco delante, lomo detrás, borde redondo."""
    sc = min(max(s, 0.0), 0.985)
    w = OREJA_BASE / 2 * ((1 - sc) * (1 + 0.4 * sc)) ** 0.85
    cup = OREJA_CUENCO * (1 - sc) ** 0.7
    u = np.linspace(-1, 1, 12)
    if inner:                                                       # interior: una lámina dentro del cuenco
        wi = max(w * 0.70 - 0.002, 0.0015)
        x, zf = u * wi, -cup * (1 - (u * wi / w) ** 2) + 0.0012
        thick, bulge = 0.002, 0.0
    else:
        x, zf = u * w, -cup * (1 - u ** 2)
        thick, bulge = OREJA_BORDE, OREJA_LOMO * (1 - sc) ** 0.6
    zb = zf - thick - bulge * (1 - u ** 2)
    rr = thick / 2
    al = np.radians(np.linspace(60, -60, 5))
    right = [(x[-1] + rr * math.cos(a), zf[-1] - rr + rr * math.sin(a)) for a in al]
    left = [(x[0] - rr * math.cos(a), zf[0] - rr - rr * math.sin(a)) for a in al]
    return np.array(list(zip(x, zf)) + right + list(zip(x[::-1], zb[::-1])) + left)


def ear(side, inner):
    base, up, f, b = ear_frame(side)
    if inner:
        h = np.linspace(0.10, 0.86, 26) * OREJA_ALTO
    else:
        h = np.concatenate([[-OREJA_HUNDIDA], np.linspace(0, 1, 34) ** 0.9 * OREJA_ALTO])
    secs = np.stack([ear_section(x / OREJA_ALTO, inner) for x in h])
    rings = base + up * h[:, None, None] + b * secs[..., 0:1] + f * secs[..., 1:2]
    return tube(rings), base


# ---------------- formas ----------------
def base_moves(points):
    """Movimiento de cada base con cada forma: media (inversa a la distancia) de los 12 vértices del cráneo más
    cercanos. Solo las formas que la mueven más de 0,3 mm."""
    crane = np.where((HW > 0.5) & (P0[:, 1] > O[1] - 0.03))[0]
    d = ((points[:, None, :] - P0[crane][None]) ** 2).sum(-1)
    ii = np.argpartition(d, 12, axis=1)[:, :12]
    w = 1 / (np.sqrt(np.take_along_axis(d, ii, 1)) + 0.004) ** 2
    w /= w.sum(1, keepdims=True)
    out = {}
    for name, delta in B["targets"].items():
        m = (delta[crane][ii] * w[..., None]).sum(1)
        if np.abs(m).max() > 0.0003:
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
    head = glb.joint_names(rig).index("Head")
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
    uv = np.stack([np.arctan2(pos[:, 0], pos[:, 2] - O[2]) / (2 * math.pi) + 0.5, pos[:, 1] - pos[:, 1].min()], 1)
    attrs = {
        "POSITION": add(pos.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": add(nrm.astype(np.float32), 5126, "VEC3", 34962),
        "TEXCOORD_0": add(uv.astype(np.float32), 5126, "VEC2", 34962),
        "JOINTS_0": add(np.tile(np.array([head, 0, 0, 0], np.uint16), (n, 1)), 5123, "VEC4", 34962),
        "WEIGHTS_0": add(np.tile(np.array([1, 0, 0, 0], np.float32), (n, 1)), 5126, "VEC4", 34962),
    }
    names = list(tg_all)
    tg = [{"POSITION": add(tg_all[k], 5126, "VEC3", 34962, True)} for k in names]
    ind = add(tris.astype(np.uint32).ravel(), 5125, "SCALAR", 34963)
    ibm_acc = add(ibm.reshape(-1, 16), 5126, "MAT4")
    doc = {
        "asset": {"version": "2.0", "generator": "GameMolde generar_orejas.py"},
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


def export(pid, inner, moves):
    vs, fs, owner = [], [], []
    for k, side in enumerate((1, -1)):
        (v, f), _ = ear(side, inner)
        fs.append(f + sum(len(x) for x in vs))
        vs.append(v)
        owner.append(np.full(len(v), k))
    v, f, owner = np.concatenate(vs), np.concatenate(fs), np.concatenate(owner)
    tg = {name: m[owner].astype(np.float32) for name, m in moves.items()}   # cada oreja, rígida con su base
    sha = write_glb(OUT / (pid + ".glb"), v, vertex_normals(v, f), f, tg, pid)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        pid, len(v), len(f), len(tg), (OUT / (pid + ".glb")).stat().st_size / 1e6))
    return sha


def card(pid, nombre, sha, color):
    return {"id": pid, "nombre": nombre, "archivo": pid + ".glb", "sha256": sha,
            "tipo": "accesorio", "ranura": "accesorio", "especies": ["humana"], "colores": ["principal"],
            "color": color, "sigue_al_cuerpo": True, "fisica": [], "miniatura": "",
            "anclaje": {"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]}}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bases = np.array([ear_frame(side)[0] for side in (1, -1)])
    moves = base_moves(bases)
    cards = [card("orejas_gato", "Orejas de gato con cuenco", export("orejas_gato", False, moves), [0.13, 0.13, 0.14]),
             card("orejas_gato_interior", "Orejas de gato: interior", export("orejas_gato_interior", True, moves),
                  [0.93, 0.6, 0.65])]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_orejas", "nombre": "Orejas (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
    print("MEDIDA bases de las orejas: x=±%.3f y=%.3f z=%.3f" % (bases[0, 0], bases[0, 1], bases[0, 2]))


if __name__ == "__main__":
    main()
