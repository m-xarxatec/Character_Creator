"""Falda corta plisada (16 pliegues de cuchillo), de talle bajo, ajustada a la humana de GameMolde.

Uso:  python generar_falda.py
Lee godot/datos/humana/cuerpo.glb (forma del cuerpo) y godot/packs/base/tights.glb (esqueleto) y escribe
packs/claude_faldas/falda_plisada.glb + pack.json.

- Ranura «accesorio» (en «ropa_piernas» sustituiría a los shorts).
- 100 % del hueso Hips (pesos de piernas pendientes, ver plan_assets.md).
- Adaptable: lleva las formas del cuerpo que mueven la zona de la falda, copiadas de la piel cercana.
- Un solo color: los pliegues son geometría (zigzag del bajo).
"""
import hashlib, json, math, struct, sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).parents[1] / "claude_gorra"))
import glb

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent / "packs" / "claude_faldas"

# --- medidas (metros) ---
Y_TOP, BAND_H, LENGTH = 0.975, 0.035, 0.25      # talle bajo, bajo el ombligo; 25 cm
GAP_BAND, GAP_SKIRT = 0.0025, 0.008              # holgura con la piel: cintura y resto
PLEATS, FACE_COLS = 16, 6                       # pliegues y columnas por cara de pliegue
FOLD = 0.12                                     # parte del periodo que ocupa el doblez
DEPTH_TOP, DEPTH_HEM = 0.003, 0.016             # profundidad del pliegue arriba y en el bajo
THICK = 0.002
BAND_ROWS, SKIRT_ROWS = 4, 18

body, body_buf = glb.read(ROOT / "godot/datos/humana/cuerpo.glb")
BODY = glb.mesh_data(body, body_buf)
P = BODY["POSITION"]
Y_BAND = Y_TOP - BAND_H
Y_HEM = Y_TOP - LENGTH

# centro del eje: el de la cintura
_w = P[(np.abs(P[:, 1] - Y_TOP) < 0.01) & (np.abs(P[:, 0]) < 0.3)]
ZC = float((_w[:, 2].min() + _w[:, 2].max()) / 2)

# nube densa del tronco y las piernas en la zona de la falda (puntos sobre los triángulos)
_tri = BODY["indices"].reshape(-1, 3)
_bary = np.array([(i, j, 4 - i - j) for i in range(5) for j in range(5 - i)], float) / 4
_c = P[_tri].mean(1)
_keep = (_c[:, 1] > Y_HEM - 0.03) & (_c[:, 1] < Y_TOP + 0.02) & (np.hypot(_c[:, 0], _c[:, 2] - ZC) < 0.3)
S = np.einsum("bk,tkc->tbc", _bary, P[_tri[_keep]]).reshape(-1, 3)
s_a = np.arctan2(S[:, 0], S[:, 2] - ZC)
s_r = np.hypot(S[:, 0], S[:, 2] - ZC)
s_y = S[:, 1]

NA = PLEATS * (FACE_COLS + 1)
A = np.linspace(-math.pi, math.pi, NA, endpoint=False)
ABINS = 72


def smooth_periodic(v, harmonics):
    f = np.fft.rfft(v)
    f[harmonics + 1:] = 0
    return np.fft.irfft(f, len(v))


def skin_radius(y0, y1):
    """Radio máximo de la piel por ángulo entre las alturas y0 y y1 (72 sectores, simétrico)."""
    edges = np.linspace(-math.pi, math.pi, ABINS + 1)
    m = (s_y >= y0) & (s_y <= y1)
    out = np.zeros(ABINS)
    for i in range(ABINS):
        k = m & (s_a >= edges[i]) & (s_a < edges[i + 1])
        out[i] = s_r[k].max() if k.any() else 0
    out = np.maximum(out, out[::-1])
    return (edges[:-1] + edges[1:]) / 2, out


def at(centers, values, a):
    return np.interp(a, centers, values, period=2 * math.pi)


# cintura: pegada a la piel
def band_radius(y):
    """Cintura pegada a la piel a la altura y: sigue entrantes (zona lumbar) sin quedar nunca dentro."""
    c, raw = skin_radius(y - 0.004, y + 0.004)
    r = np.maximum(smooth_periodic(raw, 12), raw)
    r = np.maximum(smooth_periodic(r, 18), raw)
    return c, r + GAP_BAND


band_ys = np.linspace(Y_TOP, Y_BAND, BAND_ROWS)
band_rows = [band_radius(y) for y in band_ys]
cb, R_BAND = band_rows[-1]          # la falda arranca del borde de abajo de la cintura
# falda: recta desde el borde de la cintura hasta donde toca la cadera (tangente), y desde ahí cae con poco
# vuelo (FLARE), sin entrar nunca en la piel (+ holgura). Se calcula por sector y luego se suaviza alrededor.
FLARE = 0.10                                    # cuánto se abre por metro de caída tras la cadera
rows_y = np.linspace(Y_BAND, Y_HEM, SKIRT_ROWS)
edges = np.linspace(-math.pi, math.pi, ABINS + 1)
centers = (edges[:-1] + edges[1:]) / 2
rb_bins = at(cb, R_BAND, centers)
profile = np.zeros((SKIRT_ROWS, ABINS))
for i in range(ABINS):
    k = (s_y < Y_BAND - 0.004) & (s_a >= edges[i]) & (s_a < edges[i + 1])
    py, pr = s_y[k], s_r[k] + GAP_SKIRT
    sl = (pr - rb_bins[i]) / (Y_BAND - py)
    j = sl.argmax()
    slope, yt, rt = max(sl[j], 0.0), py[j], max(pr[j], rb_bins[i])
    for row, y in enumerate(rows_y):
        r = rb_bins[i] + slope * (Y_BAND - y) if y >= yt else rt + FLARE * (yt - y)
        near = np.abs(py - y) < 0.006
        profile[row, i] = max(r, pr[near].max() if near.any() else 0)
    profile[:, i] = np.maximum.accumulate(profile[:, i])      # hacia abajo no se cierra
base = []
for row in range(SKIRT_ROWS):
    p = np.maximum(profile[row], profile[row][::-1])
    p = np.maximum(smooth_periodic(np.maximum(smooth_periodic(p, 10), p), 10), p)
    base.append(at(centers, p, A))
base = np.array(base)


def pleat_profile(phase):
    """0 en el valle, sube por la cara del pliegue y baja de golpe en el doblez (0..1 por periodo)."""
    face = 1 - FOLD
    return np.where(phase < face, phase / face, 1 - (phase - face) / FOLD)


def shell(inset):
    ph_raw = []
    for p in range(PLEATS):
        for c in range(FACE_COLS):
            ph_raw.append((1 - FOLD) * c / FACE_COLS)
        ph_raw.append(1 - FOLD)
    ph = np.array(ph_raw)
    ang = (np.repeat(np.arange(PLEATS), FACE_COLS + 1) + ph) * 2 * math.pi / PLEATS - math.pi
    prof = pleat_profile(ph)
    rows = []
    for y, (c, rr) in zip(band_ys, band_rows):               # cintura lisa, pegada a la piel
        r = at(c, rr, ang) + THICK - inset
        rows.append(np.stack([r * np.sin(ang), np.full_like(ang, y), ZC + r * np.cos(ang)], -1))
    for k, y in enumerate(rows_y):
        t = k / (SKIRT_ROWS - 1)
        depth = DEPTH_TOP + (DEPTH_HEM - DEPTH_TOP) * t
        r = np.interp(ang, np.append(A, A[0] + 2 * math.pi), np.append(base[k], base[k][0]),
                      period=2 * math.pi) + depth * prof - inset
        rows.append(np.stack([r * np.sin(ang), np.full_like(ang, y), ZC + r * np.cos(ang)], -1))
    return np.stack(rows)


def grid_faces(rows, cols, flip=False):
    out = []
    for j in range(rows - 1):
        for i in range(cols):
            a, b = j * cols + i, j * cols + (i + 1) % cols
            c, d = a + cols, b + cols
            out += [(a, b, c), (b, d, c)] if not flip else [(a, c, b), (b, c, d)]
    return out


def build():
    out_g = shell(0.0)
    in_g = shell(THICK)
    nr, nc = out_g.shape[:2]
    v = np.concatenate([out_g.reshape(-1, 3), in_g.reshape(-1, 3)])
    n = nr * nc
    f = grid_faces(nr, nc) + [tuple(x + n for x in t) for t in grid_faces(nr, nc, flip=True)]
    for row in (0, nr - 1):            # bordes de arriba y del bajo: une fuera y dentro
        for i in range(nc):
            a, b = row * nc + i, row * nc + (i + 1) % nc
            if row == 0:
                f += [(a, a + n, b), (b, a + n, b + n)]
            else:
                f += [(a, b, a + n), (b, b + n, a + n)]
    return v, np.array(f)


def vertex_normals(v, f):
    fn = np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]])
    nrm = np.zeros_like(v)
    for k in range(3):
        np.add.at(nrm, f[:, k], fn)
    return nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)


def transfer_targets(pos):
    """Cada vértice se mueve como la media (inversa a la distancia) de los 12 vértices de piel más cercanos de
    cintura, cadera y muslos. Solo las formas que mueven esa zona más de 0,3 mm."""
    zone = np.where((P[:, 1] > Y_HEM - 0.05) & (P[:, 1] < Y_TOP + 0.03)
                    & (np.hypot(P[:, 0], P[:, 2] - ZC) < 0.3))[0]
    zp = P[zone]
    k = 12
    idx = np.empty((len(pos), k), int); w = np.empty((len(pos), k))
    for s in range(0, len(pos), 1024):
        d = ((pos[s:s + 1024, None, :] - zp[None]) ** 2).sum(-1)
        ii = np.argpartition(d, k, axis=1)[:, :k]
        dd = np.sqrt(np.take_along_axis(d, ii, 1))
        idx[s:s + 1024] = ii
        w[s:s + 1024] = 1 / (dd + 0.004) ** 2
    w /= w.sum(1, keepdims=True)
    out = {}
    for name, delta in BODY["targets"].items():
        dz = delta[zone]
        if np.abs(dz).max() >= 0.0003:
            out[name] = (dz[idx] * w[..., None]).sum(1).astype(np.float32)
    return out


def write_glb(path, pos, nrm, faces, name, bone, targets):
    rig, rig_buf = glb.read(ROOT / "godot/packs/base/tights.glb")
    joint = glb.joint_names(rig).index(bone)
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
    uv = np.stack([np.arctan2(pos[:, 0], pos[:, 2] - ZC) / (2 * math.pi) + 0.5, pos[:, 1]], 1)
    attrs = {
        "POSITION": add(pos.astype(np.float32), 5126, "VEC3", 34962, True),
        "NORMAL": add(nrm.astype(np.float32), 5126, "VEC3", 34962),
        "TEXCOORD_0": add(uv.astype(np.float32), 5126, "VEC2", 34962),
        "JOINTS_0": add(np.tile(np.array([joint, 0, 0, 0], np.uint16), (n, 1)), 5123, "VEC4", 34962),
        "WEIGHTS_0": add(np.tile(np.array([1, 0, 0, 0], np.float32), (n, 1)), 5126, "VEC4", 34962),
    }
    names = list(targets)
    tg = [{"POSITION": add(targets[t], 5126, "VEC3", 34962, True)} for t in names]
    ind = add(faces.astype(np.uint32).ravel(), 5125, "SCALAR", 34963)
    ibm_acc = add(ibm.reshape(-1, 16), 5126, "MAT4")
    doc = {
        "asset": {"version": "2.0", "generator": "GameMolde generar_falda.py"},
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
    v, f = build()
    targets = transfer_targets(v)
    sha = write_glb(OUT / "falda_plisada.glb", v, vertex_normals(v, f), f, "falda_plisada", "Hips", targets)
    print("MEDIDA %d formas del cuerpo" % len(targets))
    pack = {
        "formato": "gamemolde-pack", "version": 1, "id": "claude_faldas", "nombre": "Faldas (pruebas)",
        "autor": "GameMolde", "licencia": "propia", "origen": "",
        "piezas": [{
            "id": "falda_plisada", "nombre": "Falda corta plisada", "archivo": "falda_plisada.glb",
            "sha256": sha, "tipo": "accesorio", "ranura": "accesorio", "especies": ["humana"],
            "colores": ["principal"], "color": [0.169, 0.169, 0.247], "sigue_al_cuerpo": True, "fisica": [],
            "miniatura": "", "anclaje": {"hueso": "", "transform": [0, 0, 0, 0, 0, 0, 1, 1]}}],
    }
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
    top = v[np.abs(v[:, 1] - Y_TOP) < 1e-6]
    hem = v[np.abs(v[:, 1] - Y_HEM) < 1e-6]
    def perim(q):
        a = np.arctan2(q[:, 0], q[:, 2] - ZC); o = np.argsort(a); q = q[o][:, [0, 2]]
        return np.linalg.norm(np.diff(np.vstack([q, q[:1]]), axis=0), axis=1).sum()
    print("MEDIDA cintura %.0f cm de contorno; bajo %.0f cm de ancho; largo %.0f cm; %d vértices, %.2f MB" % (
        perim(top[:len(top) // 2]) * 100, np.ptp(hem[:, 0]) * 100, LENGTH * 100, len(v),
        (OUT / "falda_plisada.glb").stat().st_size / 1e6))


if __name__ == "__main__":
    main()
