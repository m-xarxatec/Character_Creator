"""Traje rosa (plano: planos/traje_rosa_referencia.webp): el mono (aquí) y la chaqueta corta (generar_chaqueta.py).

Uso:  python generar_traje.py
Base: la «Malla de cuerpo completo» del pack base (godot/packs/base/tights.glb, CC0). Se recorta por planos: sin
mangas (sisas en el hombro), cuello alto a media garganta y bajo en el tobillo; cerca de cada borde se ciñe a la
piel. Encima: cremallera delante (del cuello al ombligo), costuras en relieve (dos curvas delante, una detrás) y
franjas diagonales (muslo izquierdo y pantorrilla derecha).
Una sola pieza, mono_rosa (ranura «ropa_torso», cubre «ropa_piernas»), como el qipao: hoy de un color, con las zonas
en COLOR_0 para cuando el núcleo admita varios: r = 0 mono, r = 1 franjas (blancas), g = 1 cremallera.
Pesos y formas: de la piel más cercana (8 vértices), lee godot/datos/humana/cuerpo.glb.
"""
import hashlib, json, math, struct, sys
from pathlib import Path
import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree

sys.path.insert(0, str(Path(__file__).parents[1] / "claude_gorra"))
import glb

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / "packs" / "claude_trajes"

# --- medidas (metros) ---
Y_NECK, Y_ANKLE = 1.45, 0.095            # cuello alto (a media garganta) y bajo en el tobillo
X_ARM, Y_ARM = 0.168, 1.05               # sisa: plano |x| = X_ARM, solo por encima de Y_ARM (no toca la cadera)
FIT_GAP, FIT_BAND = 0.003, 0.04          # en los bordes, a 3 mm de la piel (se suaviza en 4 cm)
THICK = 0.002
ZC = 0.03                                # centro del tronco delante-detrás (para las UV)
Y_ZIP = 1.00                             # la cremallera baja hasta aquí
SEAM = [(1.30, 0.135), (1.22, 0.112), (1.10, 0.075), (1.00, 0.080), (0.90, 0.100), (0.75, 0.100), (0.60, 0.085),
        (0.45, 0.075)]                   # costura curva delante: (y, |x|)
STRIPES = [dict(side=1, y=(0.50, 0.86), c=0.64), dict(side=-1, y=(0.14, 0.42), c=0.24)]   # c: altura de la 1.ª franja
STRIPE_W, STRIPE_STEP, STRIPE_SLOPE = 0.020, 0.034, 1.0


# ---------------- cuerpo ----------------
def weld(P, F, *extra):
    _, first, inv = np.unique(np.round(P / 1e-6).astype(np.int64), axis=0, return_index=True, return_inverse=True)
    F = inv.ravel()[F]
    F = F[(F[:, 0] != F[:, 1]) & (F[:, 1] != F[:, 2]) & (F[:, 0] != F[:, 2])]
    return (P[first], F) + tuple(x[first] for x in extra)


body, body_buf = glb.read(ROOT / "godot/datos/humana/cuerpo.glb")
B = glb.mesh_data(body, body_buf)
JN = glb.joint_names(body)
_first = np.unique(np.round(B["POSITION"].astype(float) / 1e-6).astype(np.int64), axis=0, return_index=True)[1]
P0, F0, J, W = weld(B["POSITION"].astype(float), B["indices"].reshape(-1, 3), B["JOINTS_0"].astype(int),
                    B["WEIGHTS_0"].astype(float))
TARGETS = {k: d[_first] for k, d in B["targets"].items()}


def bone_weight(pred):
    ids = [i for i, n in enumerate(JN) if pred(n)]
    return (W * np.isin(J, ids)).sum(1)


ARMISH = bone_weight(lambda n: any(k in n for k in ("UpperArm", "LowerArm", "Hand", "Thumb", "Index", "Middle",
                                                     "Ring", "Little")))
HEADW = bone_weight(lambda n: n == "Head")
BODY_MASK = (ARMISH < 0.3) & (HEADW < 0.3)                           # tronco, cuello y piernas


def vertex_normals(v, f):
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    n = np.zeros_like(v)
    for k in range(3):
        np.add.at(n, f[:, k], fn)
    return n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)


N0 = vertex_normals(P0, F0)
SKIN_IDX = np.where(BODY_MASK)[0]
SKIN_KD = cKDTree(P0[SKIN_IDX])


def skin_height(v):
    """Altura sobre la piel más cercana (por su normal) y esa normal."""
    _, i = SKIN_KD.query(v)
    p, n = P0[SKIN_IDX[i]], N0[SKIN_IDX[i]]
    return ((v - p) * n).sum(1), n


# ---------------- recortes ----------------
def compact(v, f, *extra):
    used, inv = np.unique(f, return_inverse=True)
    return (v[used], inv.reshape(f.shape)) + tuple(x[used] for x in extra)


def clip(V, F, f):
    """Quita lo que queda donde f > 0 (f: un valor por vértice, lineal en cada arista); corta los triángulos."""
    out = f > 0
    o = out[F]
    keep = F[~o.any(1)]
    V2, cache, new = list(V), {}, []

    def cut(a, b):
        k = (min(a, b), max(a, b))
        if k not in cache:
            t = f[a] / (f[a] - f[b])
            cache[k] = len(V2)
            V2.append(V[a] + (V[b] - V[a]) * t)
        return cache[k]

    for tri in F[o.any(1) & ~o.all(1)]:
        n_in = 3 - out[tri].sum()
        for r in range(3):
            a, b, c = tri[r], tri[(r + 1) % 3], tri[(r + 2) % 3]
            if n_in == 1 and not out[a]:
                new.append([a, cut(a, b), cut(a, c)]); break
            if n_in == 2 and out[a]:
                ab, ac = cut(a, b), cut(a, c)
                new += [[ab, b, c], [ab, c, ac]]; break
    F2 = np.concatenate([keep, np.array(new, int).reshape(-1, 3)])
    return compact(np.array(V2), F2)


def largest_part(V, F):
    adj = coo_matrix((np.ones(len(F) * 3), (F.ravel(), np.roll(F, 1, 1).ravel())), shape=(len(V), len(V)))
    _, lab = connected_components(adj, directed=False)
    big = np.bincount(lab[F[:, 0]]).argmax()
    return compact(V, F[lab[F[:, 0]] == big])


RIG, RIG_BUF = glb.read(ROOT / "godot/packs/base/tights.glb")
RIG_JN = glb.joint_names(RIG)


def build_suit():
    """Mono recortado de la malla. Devuelve vértices, caras y, por vértice, sus pesos (uno por hueso de la malla) y
    sus formas (las de la malla, hechas para seguir al cuerpo), que se interpolan en cada corte."""
    T = glb.mesh_data(RIG, RIG_BUF)
    n = len(T["POSITION"])
    wfull = np.zeros((n, len(RIG_JN)))
    for c in range(4):
        np.add.at(wfull, (np.arange(n), T["JOINTS_0"][:, c].astype(int)), T["WEIGHTS_0"][:, c])
    names = list(T["targets"])
    attrs = np.concatenate([wfull] + [T["targets"][k] for k in names], 1)
    X, F = weld(np.concatenate([T["POSITION"].astype(float), attrs], 1), T["indices"].reshape(-1, 3))
    X, F = clip(X, F, X[:, 1] - Y_NECK)
    X, F = clip(X, F, Y_ANKLE - X[:, 1])
    for s in (1, -1):
        X, F = clip(X, F, np.where(X[:, 1] > Y_ARM, s * X[:, 0] - X_ARM, -1.0))
    X, F = largest_part(X, F)
    V = X[:, :3]
    # cerca de los bordes, ceñido a la piel (si no, se vería el hueco de la malla)
    bv = np.unique(boundary(F))
    d, _ = cKDTree(V[bv]).query(V)
    t = np.clip(1 - d / FIT_BAND, 0, 1) ** 2 * (3 - 2 * np.clip(1 - d / FIT_BAND, 0, 1))
    h, n = skin_height(V)
    V = V - n * (np.maximum(h - FIT_GAP, 0) * t)[:, None]
    h, n = skin_height(V)
    V = V + n * np.maximum(FIT_GAP - h, 0)[:, None]                  # nunca por dentro de la piel
    return V, F, X[:, 3:], names


# ---------------- hoja con grosor ----------------
def boundary(faces):
    e = np.concatenate([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [2, 0]]]).tolist()
    keys = set(map(tuple, e))
    return np.array([x for x in e if (x[1], x[0]) not in keys]).reshape(-1, 2)


def thick_sheet(O, F, thick=THICK, K=3):
    """Hoja con grosor: cara de fuera (O, F), de dentro (O - normal · thick) y labio redondeado en los bordes."""
    nrm = vertex_normals(O, F)
    I = O - nrm * thick
    bnd = boundary(F)
    bv = np.unique(bnd)
    cen, cnt = np.zeros_like(O), np.zeros(len(O))
    fc = O[F].mean(1)
    for k in range(3):
        np.add.at(cen, F[:, k], fc)
        np.add.at(cnt, F[:, k], 1)
    T = O[bv] - cen[bv] / cnt[bv, None]
    T = T - nrm[bv] * (T * nrm[bv]).sum(1, keepdims=True)
    T /= np.linalg.norm(T, axis=1, keepdims=True)
    n = len(O)
    row = np.zeros((K + 1, n), int)
    row[0], row[K] = np.arange(n), n + np.arange(n)
    V, base = [O, I], 2 * n
    mid, half = (O[bv] + I[bv]) / 2, (O[bv] - I[bv]) / 2
    for k in range(1, K):
        th = math.pi * k / K
        V.append(mid + half * math.cos(th) + T * (thick / 2) * math.sin(th))
        row[k, bv] = base + np.arange(len(bv))
        base += len(bv)
    a, b = bnd[:, 0], bnd[:, 1]
    Fs = [F, F[:, ::-1] + n]
    for k in range(K):
        Fs += [np.stack([row[k, b], row[k, a], row[k + 1, a]], -1), np.stack([row[k, b], row[k + 1, a], row[k + 1, b]], -1)]
    src = np.concatenate([np.arange(n), np.arange(n)] + [bv] * (K - 1))   # de qué vértice de O sale cada uno
    return np.concatenate(V), np.concatenate(Fs), src


# ---------------- líneas sobre la superficie ----------------
def isolines(V, F, f, nrm):
    """Curvas donde f = 0 sobre la malla: lista de (puntos, normales) ordenados."""
    pt, key = {}, {}

    def at(a, b):
        k = (min(a, b), max(a, b))
        if k not in key:
            t = f[a] / (f[a] - f[b])
            key[k] = len(pt)
            nn = nrm[a] + (nrm[b] - nrm[a]) * t
            pt[key[k]] = (V[a] + (V[b] - V[a]) * t, nn / np.linalg.norm(nn))
        return key[k]

    nb = {}
    s = f > 0
    for tri in F[s[F].any(1) & ~s[F].all(1)]:
        e = [at(tri[i], tri[(i + 1) % 3]) for i in range(3) if s[tri[i]] != s[tri[(i + 1) % 3]]]
        nb.setdefault(e[0], []).append(e[1]); nb.setdefault(e[1], []).append(e[0])
    lines, seen = [], set()
    starts = [x for x in nb if len(nb[x]) == 1] + list(nb)            # primero las abiertas, desde un extremo
    for start in starts:
        if start in seen:
            continue
        line, cur = [], start
        while cur is not None:
            seen.add(cur); line.append(cur)
            nxt = [x for x in nb[cur] if x not in seen]
            cur = nxt[0] if nxt else None
        closed = len(line) > 2 and line[0] in nb[line[-1]]
        lines.append((np.array([pt[i][0] for i in line]), np.array([pt[i][1] for i in line]), closed))
    return lines


def runs(mask, closed):
    """Tramos seguidos donde mask es cierto (índices); en un lazo cerrado, también los que pasan por el inicio."""
    n = len(mask)
    k = int(np.argmin(mask)) if closed and not mask.all() else 0
    out, cur = [], []
    for j in range(n):
        i = (j + k) % n
        if mask[i]:
            cur.append(i)
        elif cur:
            out.append(cur); cur = []
    if cur:
        out.append(cur)
    return [np.array(r) for r in out if len(r) > 2]


def ring_faces(n, m, closed):
    j, i = np.meshgrid(np.arange(n if closed else n - 1), np.arange(m), indexing="ij")
    a, b = j * m + i, j * m + (i + 1) % m
    c, d = ((j + 1) % n) * m + i, ((j + 1) % n) * m + (i + 1) % m
    return np.concatenate([np.stack([a, c, b], -1).reshape(-1, 3), np.stack([b, c, d], -1).reshape(-1, 3)])


def orient_closed(v, f):
    vol = np.einsum("ij,ij->i", v[f[:, 0]], np.cross(v[f[:, 1]], v[f[:, 2]])).sum()
    return v, (f if vol > 0 else f[:, ::-1])


def sweep(pts, up, prof):
    """Perfil prof (m, 2) en el plano (normal, binormal) barrido por pts; con tapas."""
    t = np.gradient(pts, axis=0)
    t /= np.linalg.norm(t, axis=1, keepdims=True)
    u = up - t * (up * t).sum(1, keepdims=True)
    u /= np.linalg.norm(u, axis=1, keepdims=True)
    b = np.cross(t, u)
    prof = np.asarray(prof)
    rings = pts[:, None] + u[:, None] * prof[None, :, 0:1] + b[:, None] * prof[None, :, 1:2]
    n, m = rings.shape[:2]
    v, f = rings.reshape(-1, 3), ring_faces(n, m, False)
    i = np.arange(m)
    c0, c1 = len(v), len(v) + 1
    v = np.concatenate([v, [rings[0].mean(0), rings[-1].mean(0)]])
    f = np.concatenate([f, np.stack([np.full(m, c0), i, (i + 1) % m], -1),
                        np.stack([np.full(m, c1), (n - 1) * m + (i + 1) % m, (n - 1) * m + i], -1)])
    return orient_closed(v, f)


def rect(u0, u1, half):
    return [(u0, -half), (u1, -half), (u1, half), (u0, half)]


def half_round(r, m=6):
    return [(r * math.sin(a), r * math.cos(a)) for a in np.linspace(0, math.pi, m)]


def resample(pts, nrm, step=0.004):
    s = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))])
    q = np.arange(0, s[-1], step)
    p = np.stack([np.interp(q, s, pts[:, k]) for k in range(3)], 1)
    n = np.stack([np.interp(q, s, nrm[:, k]) for k in range(3)], 1)
    return p, n / np.linalg.norm(n, axis=1, keepdims=True)


# ---------------- detalles ----------------
def zipper(O, F, nrm):
    parts = []
    for pts, nn, cl in isolines(O, F, O[:, 0], nrm):
        for r in runs((nn[:, 2] > 0.3) & (pts[:, 1] > Y_ZIP) & (pts[:, 1] < Y_NECK - 0.002), cl):
            p, n = pts[r], nn[r]
            p, n = p[np.argsort(p[:, 1])], n[np.argsort(p[:, 1])]
            p, n = resample(p, n, 0.003)
            parts.append(sweep(p, n, rect(-0.0003, 0.0016, 0.0035)))           # dientes
            top = p[:, 1] > p[-1, 1] - 0.016
            parts.append(sweep(p[top], n[top], rect(0.0010, 0.0042, 0.0055)))   # cursor
            tab = (p[:, 1] > p[-1, 1] - 0.040) & (p[:, 1] < p[-1, 1] - 0.012)
            parts.append(sweep(p[tab], n[tab], rect(0.0042, 0.0058, 0.0030)))   # tirador
    return parts


def seams(O, F, nrm):
    parts = []
    ys, xs = np.array([y for y, _ in SEAM])[::-1], np.array([x for _, x in SEAM])[::-1]
    for s in (1, -1):
        f = s * O[:, 0] - np.interp(O[:, 1], ys, xs)
        for pts, nn, cl in isolines(O, F, f, nrm):
            for r in runs((nn[:, 2] > 0.15) & (pts[:, 1] > ys[0]) & (pts[:, 1] < ys[-1]) & (s * pts[:, 0] > 0.02), cl):
                p, n = resample(pts[r], nn[r])
                parts.append(sweep(p, n, half_round(0.0011)))
    for pts, nn, cl in isolines(O, F, O[:, 0], nrm):                                     # detrás, por el centro
        for r in runs((nn[:, 2] < -0.3) & (pts[:, 1] > 1.02) & (pts[:, 1] < Y_NECK - 0.004), cl):
            p, n = resample(pts[r], nn[r])
            parts.append(sweep(p, n, half_round(0.0011)))
    return parts


def stripes(O, F, nrm):
    """Franjas: trozos de la cara de fuera recortados por planos, separados 0,8 mm y con grosor."""
    parts = []
    for st in STRIPES:
        s = st["side"]
        for k in range(3):
            c = st["c"] + k * STRIPE_STEP
            V, G, n = O.copy(), F.copy(), nrm.copy()
            for fn in (lambda v, n: v[:, 1] - STRIPE_SLOPE * v[:, 2] - c - STRIPE_W / 2,
                       lambda v, n: c - STRIPE_W / 2 - (v[:, 1] - STRIPE_SLOPE * v[:, 2]),
                       lambda v, n: 0.35 - s * n[:, 0],
                       lambda v, n: 0.03 - s * v[:, 0],
                       lambda v, n: st["y"][0] - v[:, 1],
                       lambda v, n: v[:, 1] - st["y"][1]):
                vals = fn(V, n)
                V, G, n = clip_with(V, G, vals, n)
            if len(G) == 0:
                continue
            nn = vertex_normals(V, G)
            parts.append(thick_sheet(V + nn * 0.0010, G, thick=0.0008, K=2))
    return parts


def clip_with(V, F, f, nrm):
    """clip() que además arrastra las normales (para los recortes que dependen de ellas)."""
    V2, F2 = clip(np.concatenate([V, nrm], 1), F, f)
    return V2[:, :3], F2, V2[:, 3:] / np.linalg.norm(V2[:, 3:], axis=1, keepdims=True)


# ---------------- pesos, formas y .glb ----------------
def near_attrs(v, O, A, k=4):
    """Pesos y formas de lo que no es la hoja (cremallera, costuras, franjas): media de los k vértices más cercanos."""
    d, ii = cKDTree(O).query(v, k=k)
    w = 1 / (d + 0.002) ** 2
    return (A[ii] * (w / w.sum(1, keepdims=True))[..., None]).sum(1)


def weights_and_shapes(A, names):
    """Pesos (4 influencias, suman 1) y formas (solo las que mueven algo ≥ 1 mm) a partir de los atributos."""
    nj = len(RIG_JN)
    full = A[:, :nj]
    top = np.argsort(-full, 1)[:, :4]
    tw = np.maximum(np.take_along_axis(full, top, 1), 0)
    tw /= tw.sum(1, keepdims=True)
    targets = {}
    for i, name in enumerate(names):
        dt = A[:, nj + 3 * i: nj + 3 * i + 3]
        if np.abs(dt).max() >= 0.001:
            targets[name] = dt.astype(np.float32)
    return top, tw, targets


def write_glb(path, pos, nrm, tris, jr, weights, targets, name, colors):
    rig, rig_buf = RIG, RIG_BUF
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

    def add_sparse(delta):
        """Forma dispersa: solo los vértices que se mueven más de 0,2 mm (lo demás, a 0)."""
        moving = np.where(np.abs(delta).max(1) > 2e-4)[0].astype(np.uint32)
        if len(moving) > 0.6 * len(delta):
            return add(delta, 5126, "VEC3", None, True)
        iv = add(moving, 5125, "SCALAR")
        vv = add(delta[moving], 5126, "VEC3")
        a = {"componentType": 5126, "count": len(delta), "type": "VEC3",
             "min": delta.min(0).tolist(), "max": delta.max(0).tolist(),
             "sparse": {"count": int(len(moving)), "indices": {"bufferView": accs[iv]["bufferView"], "componentType": 5125},
                        "values": {"bufferView": accs[vv]["bufferView"]}}}
        accs.append(a)
        return len(accs) - 1

    uv = np.stack([np.arctan2(pos[:, 0], pos[:, 2] - ZC) / (2 * math.pi) + 0.5, pos[:, 1]], 1)
    attrs = {
        "POSITION": add(pos.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": add(nrm.astype(np.float32), 5126, "VEC3", 34962),
        "TEXCOORD_0": add(uv.astype(np.float32), 5126, "VEC2", 34962),
        "JOINTS_0": add(jr.astype(np.uint16), 5123, "VEC4", 34962),
        "WEIGHTS_0": add(weights.astype(np.float32), 5126, "VEC4", 34962),
        "COLOR_0": add(colors.astype(np.float32), 5126, "VEC4", 34962),
    }
    names = list(targets)
    tg = [{"POSITION": add_sparse(targets[t])} for t in names]
    ind = add(tris.astype(np.uint32).ravel(), 5125, "SCALAR", 34963)
    ibm_acc = add(ibm.reshape(-1, 16), 5126, "MAT4")
    doc = {
        "asset": {"version": "2.0", "generator": "GameMolde generar_traje.py"},
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


ZONES = {"mono": (0, 0, 0, 1), "franjas": (1, 0, 0, 1), "cremallera": (0, 1, 0, 1)}   # COLOR_0 de cada zona


class Piece:
    """Una pieza hecha de partes; cada parte trae sus atributos (pesos y formas) o los toma de la hoja (O, A)."""
    def __init__(self, O, A, names):
        self.O, self.A, self.names = O, A, names
        self.v, self.f, self.c, self.a = [], [], [], []

    def add(self, vf, zone="mono", attrs=None):
        v, f = np.asarray(vf[0], float), vf[1]
        self.f.append(np.asarray(f, int) + sum(len(x) for x in self.v))
        self.v.append(v)
        self.c.append(np.tile(ZONES[zone], (len(v), 1)))
        self.a.append(attrs if attrs is not None else near_attrs(v, self.O, self.A))

    def export(self, pid):
        v, f, c = np.concatenate(self.v), np.concatenate(self.f), np.concatenate(self.c)
        joints, weights, targets = weights_and_shapes(np.concatenate(self.a), self.names)
        sha = write_glb(OUT / (pid + ".glb"), v, vertex_normals(v, f), f, joints, weights, targets, pid, c)
        print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
            pid, len(v), len(f), len(targets), (OUT / (pid + ".glb")).stat().st_size / 1e6))
        return sha


def card(pid, nombre, sha, color, tipo, ranura, cubre=None):
    c = {"id": pid, "nombre": nombre, "archivo": pid + ".glb", "sha256": sha, "tipo": tipo, "ranura": ranura,
         "especies": ["humana"], "colores": ["principal"], "color": color, "sigue_al_cuerpo": True, "fisica": [],
         "miniatura": "", "anclaje": {"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]}}
    if cubre:
        c["cubre"] = cubre
    return c


def check_shapes(O, A, names):
    """Comprobación: con cada forma al máximo (sola), ¿cuánto se mete el mono en la piel? Muestra las peores."""
    nj, worst = len(RIG_JN), []
    for i, name in enumerate(names):
        if name not in TARGETS:
            continue
        P = P0 + TARGETS[name]
        N = vertex_normals(P, F0)
        _, j = cKDTree(P[SKIN_IDX]).query(O + A[:, nj + 3 * i: nj + 3 * i + 3])
        q = O + A[:, nj + 3 * i: nj + 3 * i + 3]
        h = ((q - P[SKIN_IDX[j]]) * N[SKIN_IDX[j]]).sum(1)
        worst.append((h.min(), int((h < -0.001).sum()), name))
    worst.sort()
    print("MEDIDA formas, peor hueco (mm) y vértices dentro > 1 mm:",
          ", ".join("%s %.1f/%d" % (n, m * 1000, c) for m, c, n in worst[:8]))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    O, F, A, names = build_suit()
    h, _ = skin_height(O)
    print("MEDIDA hueco a la piel (mm): mín %.1f, mediana %.1f" % (h.min() * 1000, np.median(h) * 1000))
    check_shapes(O, A, names)
    nrm = vertex_normals(O, F)
    suit = Piece(O, A, names)
    v, f, src = thick_sheet(O, F)
    suit.add((v, f), attrs=A[src])
    for part in zipper(O, F, nrm):
        suit.add(part, "cremallera")
    for part in seams(O, F, nrm):
        suit.add(part)
    for part in stripes(O, F, nrm):
        suit.add(part, "franjas")
    cards = [card("mono_rosa", "Mono rosa", suit.export("mono_rosa"), [0.95, 0.62, 0.74], "ropa", "ropa_torso",
                  ["ropa_piernas"])]
    import generar_chaqueta
    cards.append(generar_chaqueta.build(OUT))
    pack ={"formato": "gamemolde-pack", "version": 1, "id": "claude_trajes", "nombre": "Trajes (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
