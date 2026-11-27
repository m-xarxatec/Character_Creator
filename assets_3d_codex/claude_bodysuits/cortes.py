"""Generador de maillots: la piel del cuerpo recortada y separada 2,5 mm, como el bikini (../claude_bikini).

Pegada a la piel (el responsable: «como si estuvieran pegados a la piel»; con la malla de cuerpo completo la tela hacía
puente en la ingle y se iba hacia las piernas): marca la forma del cuerpo, y un hilo detrás se mete por el surco.
Cada vértice sigue a su triángulo de piel con cualquier forma (pesos y formas por coordenadas). En los bordes la tela
baja hasta la piel (sin ribete ni escalón).
Cada corte es una función de los vértices (columnas: x, y, z, peso de pierna, peso del brazo izquierdo, del derecho)
que vale > 0 donde se quita la tela. Lo usan los generar_*.py de esta carpeta: cada uno solo da sus cortes.
"""
import json, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_bikini", "claude_sudadera", "claude_traje"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_bikini as bk

sud, tr = bk.sud, bk.tr
P0, F0 = sud.P0, sud.F0
ARM_BONES = ("UpperArm", "LowerArm", "Hand")
ARM_COL = {"Left": 4, "Right": 5}
ZONES = {"tela": (0, 0, 0, 1), "detalle": (1, 0, 0, 1)}          # detalle: franjas, emblemas…


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


def skin_attrs():
    arms = [sud.bone_weight([s + b for b in ARM_BONES]) for s in ("Left", "Right")]
    return np.c_[P0, bk.leg_weight(), arms[0], arms[1]]


# ---------------- cortes (> 0 donde se quita) ----------------
def neck_top(y):
    """Cuello alto: se quita por encima de y."""
    return lambda V: V[:, 1] - y


def neck_round(y, tilt, rx, rz, zc):
    """Cuello redondo: se quita por encima del plano y − tilt·z y dentro de la elipse (rx, rz) alrededor del cuello."""
    def f(V):
        e = np.sqrt((V[:, 0] / rx) ** 2 + ((V[:, 2] - zc) / rz) ** 2)
        return np.minimum(V[:, 1] - (y - tilt * V[:, 2]), (1 - e) * rx)
    return f


def window(xc, yc, hw, hh, r, front=True, zc=0.05):
    """Ventana rectangular de esquinas redondas (media anchura hw, media altura hh, radio r), delante o detrás."""
    def f(V):
        q = np.abs(V[:, :2] - [xc, yc]) - [hw - r, hh - r]
        d = np.linalg.norm(np.maximum(q, 0), axis=1) + np.minimum(q.max(1), 0) - r
        side = V[:, 2] > zc if front else V[:, 2] < -zc
        return np.where(side, -d, -1.0)
    return f


def armhole(x, y_min):
    """Sin mangas: se quita lo que pasa de |x| por encima de y_min."""
    return lambda V: np.where(V[:, 1] > y_min, np.abs(V[:, 0]) - x, -1.0)


def sleeve(side, t):
    """Manga: se quita del brazo lo que pasa de t (0 hombro, 1 codo, 2 muñeca), por un plano perpendicular al hueso."""
    a = sud.ARM[side]
    if t <= 1:
        p0, d = a["upper"] + (a["lower"] - a["upper"]) * t, unit(a["lower"] - a["upper"])
    else:
        p0, d = a["lower"] + (a["hand"] - a["lower"]) * (t - 1), unit(a["hand"] - a["lower"])
    return lambda V: np.where(V[:, ARM_COL[side]] > 0.5, (V[:, :3] - p0) @ d, -1.0)


def oval(yc, rx, ry, back=True, zc=0.0):
    """Abertura ovalada en (x, y), detrás (z < zc) o delante."""
    def f(V):
        e = np.sqrt((V[:, 0] / rx) ** 2 + ((V[:, 1] - yc) / ry) ** 2)
        side = V[:, 2] < zc if back else V[:, 2] > zc
        return np.where(side, (1 - e) * min(rx, ry), -1.0)
    return f


def bottom(front_hw, back_hw, top=1.08, leg_max=0.4, y_low=0.765):
    """Parte de abajo, como la braguita del bikini: media anchura (y, |x|) delante (V, sin pasar al muslo: peso de
    pierna ≤ leg_max) y detrás (tanga: acaba en hilo); por encima de top, y en los brazos, no corta."""
    def f(V):
        p, L = V[:, :3], V[:, 3]
        ax, y, w = np.abs(p[:, 0]), p[:, 1], bk.front_factor(p)
        front = np.maximum(ax - np.interp(y, *zip(*front_hw)), (L - leg_max) * 0.05)
        back = ax - np.interp(y, *zip(*back_hw))
        body = (y < top) & (np.maximum(V[:, 4], V[:, 5]) < 0.5)        # los brazos no (en pose A bajan de top)
        return np.where(body, np.maximum(back + (front - back) * w, y_low - y), -1.0)
    return f


# ---------------- tela ----------------
def refine_near(V, F, field, band=0.03):
    """Divide en 4 los triángulos cerca de un corte (|campo| < band) y en 2 los vecinos que quedan con un lado partido
    (sin grietas); lejos de los cortes, la piel tal cual (ya se pega al cuerpo; dividirlo todo solo pesa más)."""
    f = field(V)
    fF = f[F]
    red = (np.abs(fF).min(1) < band) | ((fF.min(1) < 0) & (fF.max(1) > 0))
    E = np.sort(np.stack([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]], 1), 2)    # lados ab, bc, ca
    ue, inv = np.unique(E.reshape(-1, 2), axis=0, return_inverse=True)
    inv = inv.reshape(-1, 3)
    while True:
        split = np.zeros(len(ue), bool)
        split[inv[red].ravel()] = True
        cnt = split[inv].sum(1)
        grow = ~red & (cnt >= 2)
        if not grow.any():
            break
        red |= grow
    mid = -np.ones(len(ue), int)
    mid[split] = len(V) + np.arange(split.sum())
    V = np.concatenate([V, (V[ue[split, 0]] + V[ue[split, 1]]) / 2])
    m = mid[inv]
    a, b, c = F.T
    r, g = red, ~red & (cnt == 1)
    out = [F[~red & (cnt == 0)],
           np.stack([a[r], m[r, 0], m[r, 2]], 1), np.stack([m[r, 0], b[r], m[r, 1]], 1),
           np.stack([m[r, 2], m[r, 1], c[r]], 1), np.stack([m[r, 0], m[r, 1], m[r, 2]], 1)]
    for k, (t1, t2) in enumerate([((0, 3, 2), (3, 1, 2)), ((0, 1, 3), (0, 3, 2)), ((0, 1, 3), (3, 1, 2))]):
        gk = g & (m[:, k] >= 0)                                        # un solo lado partido: dos triángulos
        cols = np.stack([a[gk], b[gk], c[gk], m[gk, k]], 1)
        out += [cols[:, list(t1)], cols[:, list(t2)]]
    return V, np.concatenate(out)


def cut_skin(cuts):
    """La piel recortada (sobre la piel): vértices, caras y bordes."""
    field = lambda V: np.max([c(V) for c in cuts], 0)
    V = skin_attrs()
    keep = (P0[:, 1] > 0.70) & (P0[:, 1] < 1.50) & ~sud.hand_like & (sud.main_bone != "Head")
    F = F0[keep[F0].all(1)]
    F = F[field(V)[F].min(1) < 0.03]
    V, F = bk._compact(V, F)
    V, F = refine_near(V, F, field)
    V, F = tr.clip(V, F, field(V))
    V, F = tr.largest_part(V, F)
    V, F = bk._compact(V[:, :3], F)
    loops = sud.boundary_loops(F)
    for _ in range(bk.EDGE_IT):                                        # bordes alisados, sin salir de la piel
        for lp in loops:
            V[lp] = bk.on_skin(0.5 * V[lp] + 0.25 * (np.roll(V[lp], 1, 0) + np.roll(V[lp], -1, 0)))[0]
    return V, F, loops


def sheet(cuts):
    """La tela: separada, tensa, bajando a la piel en los bordes; y de qué piel sale cada vértice (si, sw)."""
    V, F, loops = cut_skin(cuts)
    q, si, sw, n = bk.on_skin(V)
    O = bk.to_edges(bk.tense(bk.push_out(q + n * bk.GAP, bk.GAP), F, loops), loops)
    q, si, sw, n = bk.on_skin(O)                                       # anclada a la piel que tiene debajo…
    t = np.clip((((O - q) * n).sum(1) - bk.GAP - 0.001) / bk.BRIDGE, 0, 1)[:, None]
    ni, nw = sud.nearest_skin(O, 5)                                    # …o, donde hace de puente, a la más cercana
    return O, F, loops, np.c_[si, ni], np.c_[sw * (1 - t), nw * t]


def measure(O, F, loops, si, sw, targets):
    q, n = (P0[si] * sw[..., None]).sum(1), bk.normal_at(bk.SKIN_N, si, sw)
    inner = cKDTree(O[np.concatenate(loops)]).query(O)[0] > bk.EDGE_BAND
    print("MEDIDA tela a la piel (reposo, lejos de los bordes): mín %.1f mm" % (((O - q) * n).sum(1)[inner].min() * 1000))
    own = []
    for name, d in sud.B["targets"].items():
        if name in targets:
            P = P0 + d
            Os = O + targets[name][:len(O)]
            own.append(((Os - (P[si] * sw[..., None]).sum(1)) * bk.normal_at(sud.vertex_normals(P, F0), si, sw)).sum(1)
                       [inner].min())
    print("MEDIDA tela con cada forma, sobre su piel: mín %.1f mm; %d bordes; baja hasta y = %.3f" % (
        min(own) * 1000, len(loops), O[:, 1].min()))


def pad8(a):
    return np.c_[a, np.zeros((len(a), 8 - a.shape[1]), a.dtype)]


def build(cuts, out, pack_id, pack_name, pid, name, color, extras=None):
    """Escribe el .glb (una pieza, ranura «ropa_torso», cubre «ropa_piernas») y el pack.json.
    extras(O, F) → [((v, f), zona, (índices, pesos) de piel por vértice o una máscara de piel)]: piezas añadidas
    (siguen a su piel por índice o a la piel más cercana de la máscara)."""
    out.mkdir(parents=True, exist_ok=True)
    bk.OUT = out
    O, F, loops, si, sw = sheet(cuts)
    v, f, src = tr.thick_sheet(O, F, bk.THICK)
    i, w = si[src], sw[src]
    V, Fs, Z, I, W = [v], [f], [np.tile(ZONES["tela"], (len(v), 1))], [pad8(i)], [pad8(w)]
    H = [((v - (P0[i] * w[..., None]).sum(1)) * bk.normal_at(bk.SKIN_N, i, w)).sum(1)]
    for (pv, pf), zone, src in (extras(O, F) if extras else []):
        pv = np.asarray(pv, float)
        pi, pw = src if isinstance(src, tuple) else sud.nearest_skin(pv, 8, src)
        Fs.append(np.asarray(pf, int) + sum(len(x) for x in V))
        V.append(pv); Z.append(np.tile(ZONES[zone], (len(pv), 1))); I.append(pad8(pi)); W.append(pad8(pw))
        H.append(np.zeros(len(pv)))
    sha, targets = bk.write(np.concatenate(V), np.concatenate(Fs), np.concatenate(Z), np.concatenate(I),
                            np.concatenate(W), np.concatenate(H), pid)
    measure(O, F, loops, si, sw, targets)
    cards = [tr.card(pid, name, sha, color, "ropa", "ropa_torso", ["ropa_piernas"])]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": pack_id, "nombre": pack_name, "autor": "GameMolde",
            "licencia": "propia", "origen": "", "piezas": cards}
    (out / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
    return O, F, loops
