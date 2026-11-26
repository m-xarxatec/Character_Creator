"""Leotardo negro (plano: planos/Tablero de referencia 360° de leotardo negro.webp), con la espalda tipo bikini.

Uso:  python generar_leotardo.py
Hecho como el mono rosa (usa sus herramientas, claude_traje/generar_traje.py): la «Malla de cuerpo completo» del pack
base (godot/packs/base/tights.glb, CC0) recortada: cuello redondo, sin mangas y piernas de corte alto con una tira
estrecha en la entrepierna. Cuello redondo alto (1 cm bajo la base del cuello). Delante, tipo bikini: sube por la ingle sin pasar a los muslos; detrás, a petición del responsable,
más estrecho que el plano y en curva (tipo braguita de bikini).
Luego, «tela tensa»: se alisa la malla (puentea los pliegues de la ingle, entre los glúteos y entre los senos) sin
meterse en la piel, y los bordes se alisan a lo largo. En cada borde, un ribete enrollado sobre una curva suave.
Una sola pieza, leotardo_negro (ranura «ropa_torso», cubre «ropa_piernas»), de un color.
Pesos y formas: los de la malla (interpolados en los cortes); con cada forma, nunca por dentro de la piel.
El ribete, de la hoja más cercana.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.interpolate import CubicSpline
from scipy.sparse import coo_matrix, diags
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE.parent / "claude_traje"))
import generar_traje as tr

OUT = HERE / "packs" / "claude_leotardos"

# --- medidas (metros) ---
NECK_Y, NECK_TILT = 1.39, 0.3                 # cuello redondo: sobre y = NECK_Y − NECK_TILT·z (1 cm bajo la base del cuello)…
NECK_RX, NECK_RZ, NECK_ZC = 0.085, 0.075, 0.025  # …y dentro de esta elipse alrededor del cuello (el hombro queda de tirante)
X_ARM, Y_ARM = 0.150, 1.05                    # sisa: plano |x| = X_ARM, solo por encima de Y_ARM
Y_LEG_TOP = 1.00                              # el corte de las piernas no pasa de aquí
# línea de la pierna, (|x|, y): bajo ella se quita. Empieza a la altura de la entrepierna de la malla (y = 0,774)
LEG_FRONT = [(0.000, 0.774), (0.035, 0.776), (0.050, 0.815), (0.070, 0.865), (0.100, 0.915), (0.135, 0.950),
             (0.165, 0.975)]                                  # bikini: sube por la ingle sin pasar a los muslos
LEG_BACK = [(0.000, 0.774), (0.035, 0.776), (0.075, 0.815), (0.115, 0.885), (0.155, 0.955)]   # bikini, en curva
Y_CROTCH, GUSSET_W = 0.774, 0.030             # tira de la entrepierna: lo que está a menos de 3 cm del centro, medido
                                              # |x| + lo que baja por el muslo (la malla es una V cerrada: los muslos casi
                                              # se tocan); así cubre todo el surco y su borde va paralelo al centro
ZC, Z_BLEND = 0.03, 0.05                      # delante/detrás: z respecto al centro del tronco, mezcla en ±5 cm
GAP, FIT_BAND = 0.0025, 0.04                  # hueco mínimo a la piel; cerca de los bordes, ceñido a él (4 cm)
POKE_GAP = 0.001                              # la piel, al menos 1 mm por debajo de la tela (entre vértices)
SHAPE_PUSH = 1.2                              # con cada forma, se devuelve lo que se come del hueco y un 20 % más
SMOOTH_IT, SMOOTH_EDGE_IT = 20, 40            # alisado de la tela y de los bordes
BIND_W, BIND_T = 0.0040, 0.0012               # ribete plano de 8 mm: media anchura (sobre el borde) y medio grosor


# ---------------- cortes ----------------
def front_factor(V):
    """1 delante, 0 detrás, con transición suave por los costados."""
    t = np.clip((V[:, 2] - ZC) / Z_BLEND * 0.5 + 0.5, 0, 1)
    return t * t * (3 - 2 * t)


def leg_cut(V):
    """> 0 donde se quita: por debajo de la línea de la pierna."""
    ax = np.abs(V[:, 0])
    yf = np.interp(ax, *zip(*LEG_FRONT))
    yb = np.interp(ax, *zip(*LEG_BACK))
    w = front_factor(V)
    leg = np.where(V[:, 1] < Y_LEG_TOP, yb + (yf - yb) * w - V[:, 1], -1.0)
    gusset = ax + np.maximum(Y_CROTCH - V[:, 1], 0) - GUSSET_W
    return np.minimum(leg, gusset)


def neck_cut(V):
    """> 0 donde se quita: por encima del plano del cuello y dentro de la elipse (en metros, aprox.)."""
    above = V[:, 1] - (NECK_Y - NECK_TILT * V[:, 2])
    e = np.sqrt((V[:, 0] / NECK_RX) ** 2 + ((V[:, 2] - NECK_ZC) / NECK_RZ) ** 2)
    return np.minimum(above, (1 - e) * NECK_RX)


def cut_tights():
    """La malla recortada: vértices, caras y, por vértice, pesos (uno por hueso) y formas."""
    T = tr.glb.mesh_data(tr.RIG, tr.RIG_BUF)
    n = len(T["POSITION"])
    wfull = np.zeros((n, len(tr.RIG_JN)))
    for c in range(4):
        np.add.at(wfull, (np.arange(n), T["JOINTS_0"][:, c].astype(int)), T["WEIGHTS_0"][:, c])
    names = list(T["targets"])
    attrs = np.concatenate([wfull] + [T["targets"][k] for k in names], 1)
    X, F = tr.weld(np.concatenate([T["POSITION"].astype(float), attrs], 1), T["indices"].reshape(-1, 3))
    X, F = tr.clip(X, F, neck_cut(X))
    for s in (1, -1):
        X, F = tr.clip(X, F, np.where(X[:, 1] > Y_ARM, s * X[:, 0] - X_ARM, -1.0))
    X, F = tr.clip(X, F, leg_cut(X))
    X, F = tr.largest_part(X, F)
    return X[:, :3], F, X[:, 3:], names


# ---------------- tela tensa ----------------
SKIN_IDX = np.where(tr.HEADW < 0.3)[0]                               # toda la piel menos la cabeza (con los brazos:
SKIN, SKIN_N = tr.P0[SKIN_IDX], tr.N0[SKIN_IDX]                      # el hombro lleva pesos de brazo)
SKIN_KD = cKDTree(SKIN)


def skin_height(v, k=8):
    """Altura sobre la piel (media de los k vértices más cercanos: sin saltos de un vértice a otro) y su normal."""
    d, ii = SKIN_KD.query(v, k=k)
    w = 1 / (d + 0.003) ** 2
    w /= w.sum(1, keepdims=True)
    p = (SKIN[ii] * w[..., None]).sum(1)
    n = (SKIN_N[ii] * w[..., None]).sum(1)
    n /= np.linalg.norm(n, axis=1, keepdims=True)
    return ((v - p) * n).sum(1), n


def boundary_loops(F):
    """Bordes de la hoja como lazos cerrados de vértices."""
    nxt = {a: b for a, b in tr.boundary(F)}
    loops, seen = [], set()
    for start in nxt:
        if start in seen:
            continue
        loop, cur = [], start
        while cur not in seen:
            seen.add(cur); loop.append(cur)
            cur = nxt[cur]
        loops.append(np.array(loop))
    return loops


def neighbor_mean(n, F, loops):
    """Matriz de media de vecinos: dentro, los de la malla; en el borde, solo los dos del lazo."""
    e = np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]])
    e = np.concatenate([e, e[:, ::-1]])
    on_edge = np.zeros(n, bool)
    for lp in loops:
        on_edge[lp] = True
    e = e[~on_edge[e[:, 0]]]
    le = np.concatenate([np.stack([lp, np.roll(lp, 1)], 1) for lp in loops] +
                        [np.stack([lp, np.roll(lp, -1)], 1) for lp in loops])
    e = np.unique(np.concatenate([e, le]), axis=0)
    M = coo_matrix((np.ones(len(e)), (e[:, 0], e[:, 1])), shape=(n, n)).tocsr()
    return diags(1 / np.asarray(M.sum(1)).ravel()) @ M


def tension(V, F):
    """Alisa la tela (puentea pliegues) sin meterla en la piel; los bordes, además, alisados a lo largo y ceñidos."""
    loops = boundary_loops(F)
    M = neighbor_mean(len(V), F, loops)
    edge = np.concatenate(loops)
    for it in range(max(SMOOTH_IT, SMOOTH_EDGE_IT)):
        S = V + 0.5 * (M @ V - V)
        if it < SMOOTH_IT:
            V = S
        else:
            V[edge] = S[edge]
        h, n = skin_height(V)
        V = V + n * np.maximum(GAP - h, 0)[:, None]
    d, _ = cKDTree(V[edge]).query(V)
    t = np.clip(1 - d / FIT_BAND, 0, 1)
    t = t * t * (3 - 2 * t)
    h, n = skin_height(V)
    V = V - n * (np.maximum(h - GAP, 0) * t)[:, None]                 # cerca del borde, pegado a la piel
    return V, loops


def height_on(P, N, v, k=8):
    """Como skin_height, sobre la piel P (normales N) ya cambiada por una forma."""
    d, ii = cKDTree(P).query(v, k=k)
    w = 1 / (d + 0.003) ** 2
    w /= w.sum(1, keepdims=True)
    p, n = (P[ii] * w[..., None]).sum(1), (N[ii] * w[..., None]).sum(1)
    n /= np.linalg.norm(n, axis=1, keepdims=True)
    return ((v - p) * n).sum(1), n


def skin_up(G, F, S, anchor):
    """Altura de cada punto de la piel S sobre la tela G (4 vértices más cercanos; > 0: la atraviesa), solo bajo la
    tela y lejos de los bordes (si no, 0), con esos vértices, sus pesos y las normales de la tela."""
    Gn = tr.vertex_normals(G, F)
    d, ii = cKDTree(G).query(S, k=4)
    ok = anchor[ii[:, 0]] & (d[:, 0] < 0.03)                          # bajo la tela, lejos de los bordes
    w = 1 / (d + 0.003) ** 2
    w /= w.sum(1, keepdims=True)
    up = ((S[:, None] - G[ii]) * Gn[ii]).sum(2)
    return np.where(ok, np.maximum((up * w).sum(1) + POKE_GAP, 0), 0), ii, Gn


def skin_poke(G, F, S, anchor, rest_up):
    """Empuje de cada vértice de la tela G para que la piel S no la atraviese entre vértices (la malla va cada 3 cm):
    solo lo que la forma empeora respecto al reposo (rest_up), si pasa de 0,3 mm."""
    up, ii, Gn = skin_up(G, F, S, anchor)
    need = up - rest_up
    push = np.zeros(len(G))
    m = need > 0.0003
    np.maximum.at(push, ii[m].ravel(), np.repeat(need[m], 4))
    return push, Gn


def skin_shapes(O, A, names, F):
    """Formas de la malla, pero si una forma (sola, al máximo) se come parte del hueco a la piel, la tela se empuja
    hacia fuera eso y un 20 % más (las formas se suman: deja margen). Solo donde se come: formas dispersas.
    La malla está pensada a 5 mm de la piel; el leotardo va a 2,5. Devuelve el peor hueco antes de empujar."""
    h0, _ = skin_height(O)
    edge = np.unique(tr.boundary(F))
    anchor = cKDTree(O[edge]).query(O)[0] > 0.02
    rest_up = skin_up(O, F, tr.P0[SKIN_IDX], anchor)[0]
    A = A.copy()
    nj, worst = len(tr.RIG_JN), []
    for i, name in enumerate(names):
        if name not in tr.TARGETS:
            continue
        sl = slice(nj + 3 * i, nj + 3 * i + 3)
        P = tr.P0 + tr.TARGETS[name]
        N = tr.vertex_normals(P, tr.F0)
        h, n = height_on(P[SKIN_IDX], N[SKIN_IDX], O + A[:, sl])
        worst.append((h.min(), name))
        A[:, sl] += n * (SHAPE_PUSH * np.maximum(h0 - h, 0))[:, None]
        push, Gn = skin_poke(O + A[:, sl], F, P[SKIN_IDX], anchor, rest_up)
        A[:, sl] += Gn * push[:, None]
    return A, min(worst)


# ---------------- ribete ----------------
def closed_curve(p, n, step=0.002):
    """Curva cerrada suave (spline periódica) por los puntos p, remuestreada cada step; con sus normales."""
    q = np.concatenate([p, p[:1]])
    m = np.concatenate([n, n[:1]])
    s = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(q, axis=0), axis=1))])
    u = np.arange(0, s[-1], step)
    P = CubicSpline(s, q, bc_type="periodic")(u)
    N = CubicSpline(s, m, bc_type="periodic")(u)
    return P, N / np.linalg.norm(N, axis=1, keepdims=True)


def binding(P, N, segs=10):
    """Tubo aplastado cerrado que abraza el borde: BIND_W a cada lado, BIND_T de grosor, algo por fuera de la tela."""
    t = np.roll(P, -1, 0) - np.roll(P, 1, 0)
    t /= np.linalg.norm(t, axis=1, keepdims=True)
    u = N - t * (N * t).sum(1, keepdims=True)
    u /= np.linalg.norm(u, axis=1, keepdims=True)
    b = np.cross(t, u)
    a = np.linspace(0, 2 * math.pi, segs, endpoint=False)
    cu, cb = BIND_T * 0.5 + BIND_T * np.cos(a), BIND_W * np.sin(a)
    rings = P[:, None] + u[:, None] * cu[None, :, None] + b[:, None] * cb[None, :, None]
    v, f = rings.reshape(-1, 3), tr.ring_faces(len(P), segs, True)
    return tr.orient_closed(v, f)


# ---------------- pieza ----------------
def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tr.OUT = OUT                                                       # Piece.export escribe en tr.OUT
    O, F, A, names = cut_tights()
    O, loops = tension(O, F)
    A, (wh, wn) = skin_shapes(O, A, names, F)
    print("MEDIDA formas: peor hueco antes de empujar %.1f mm (%s)" % (wh * 1000, wn))
    h, _ = skin_height(O)
    print("MEDIDA hueco a la piel (mm): mín %.1f, mediana %.1f, máx %.1f" % (h.min() * 1000, np.median(h) * 1000,
                                                                         h.max() * 1000))
    print("MEDIDA bordes: %d lazos" % len(loops))
    print("MEDIDA tira de la entrepierna: baja hasta y=%.3f (entrepierna 0,774)" % O[:, 1].min())
    neck = max(loops, key=lambda lp: O[lp, 1].mean())
    print("MEDIDA cuello: |x| hasta %.3f (tirante hasta la sisa, 0,150); y delante %.3f, detrás %.3f" % (
        np.abs(O[neck, 0]).max(), O[neck][O[neck, 2].argmax(), 1], O[neck][O[neck, 2].argmin(), 1]))
    nrm = tr.vertex_normals(O, F)
    suit = tr.Piece(O, A, names)
    v, f, src = tr.thick_sheet(O, F)
    suit.add((v, f), attrs=A[src])
    for lp in loops:
        suit.add(binding(*closed_curve(O[lp], nrm[lp])))
    cards = [tr.card("leotardo_negro", "Leotardo negro", suit.export("leotardo_negro"), [0.10, 0.10, 0.11], "ropa",
                     "ropa_torso", ["ropa_piernas"])]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_leotardos", "nombre": "Leotardos (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
