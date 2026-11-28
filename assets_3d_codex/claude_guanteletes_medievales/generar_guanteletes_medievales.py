"""Guanteletes medievales articulados (plano: planos/guantelete_medieval_articulado.png).

Uso:  ~/.venvs/gamemolde_assets/bin/python generar_guanteletes_medievales.py   (numpy y scipy)
Escribe packs/claude_guanteletes_medievales/: guanteletes_medievales, el par en **una sola pieza**, ranura «accesorio».
- **Más grandes que la mano y que los de dragón** (pedido por el responsable).
- Guante de cuero oscuro debajo: el de los guanteletes de dragón (la piel copiada e hinchada, con grosor), más holgado;
  se ve en la palma y entre las placas.
- Acero: una placa curva por falange (rígida con su hueso: articulada), la de la punta cerrada en cúpula; placa del
  dorso y placa de los nudillos (rígidas con la mano); puño de 4 láminas que se solapan y se abre en campana hasta media
  antebrazo; remaches en los lados.
Zonas en COLOR_0: (0,0,0) acero; r = 1 cuero.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_guanteletes", "claude_botas_medievales"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_guanteletes as dg
import generar_botas as bt

sud, tr, eva = dg.sud, dg.tr, dg.eva
OUT = HERE / "packs" / "claude_guanteletes_medievales"
PID = "guanteletes_medievales"
ZONES = {"acero": (0, 0, 0, 1), "cuero": (1, 0, 0, 1)}
P0, SIDES, ARM, FINGERS = sud.P0, sud.SIDES, sud.ARM, dg.FINGERS

# --- guante de cuero (más holgado que el de dragón; bajo el puño de acero, pegado) ---
dg.OFF_HAND, dg.OFF_FINGER = 0.010, 0.0060
dg.CUFF_T, dg.OFF_CUFF, dg.OFF_MOUTH = 0.80, 0.006, 0.006
dg.GROOVE = 0.0
# --- acero (metros) ---
STEEL = 0.0025                               # grosor de las placas grandes
STEEL_F = 0.0018                             # de las placas de los dedos
GAP_F = 0.0012                               # placa del dedo sobre el cuero
ARC_F = 100                                  # placas de los dedos: ± grados alrededor del dorso
THUMB_TWIST = 0.8                            # dorso del pulgar: girado hacia fuera de la mano
LAMES = [(0.99, 0.87), (0.895, 0.76), (0.785, 0.64), (0.665, 0.42)]   # láminas del puño (t: 1 muñeca, 0 codo)
LAME_STEP = 0.0032                           # cada lámina, por encima de la de la mano
GAP_WRIST, GAP_MOUTH = 0.005, 0.018          # holgura del puño: muñeca y boca de la campana
PLATE_LIFT = 0.0025


def unit(x):
    return x / np.linalg.norm(x, axis=-1, keepdims=True)


def perp(v, d):
    return unit(v - d * (v @ d))


def smoothstep(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


# ---------------- puño de láminas ----------------
class ArmRadius:
    """Medias anchuras (dorso, lado) del antebrazo con su guante, por t: elipse que lo envuelve entero."""
    def __init__(self, s, pts):
        a = ARM[s]
        self.o, self.d = a["lower"], a["dir"]
        self.L = np.linalg.norm(a["hand"] - a["lower"])
        self.e1 = perp(dg.hand_frame(s)[0], self.d)
        self.e2 = np.cross(self.d, self.e1)
        q = pts - self.o
        t = q @ self.d / self.L
        x, y = q @ self.e1, q @ self.e2
        self.ts = np.linspace(LAMES[-1][1] - 0.02, LAMES[0][0] + 0.01, 48)
        ang = np.linspace(-math.pi, math.pi, 72, endpoint=False)
        A, B = [], []
        for tk in self.ts:
            m = np.abs(t - tk) * self.L < 0.012
            r, th = np.hypot(x[m], y[m]), np.arctan2(y[m], x[m])
            R = np.array([r[np.abs((th - g + math.pi) % (2 * math.pi) - math.pi) < 0.2].max(initial=0) for g in ang])
            a0, b0 = (R * np.abs(np.cos(ang))).max(), (R * np.abs(np.sin(ang))).max()
            ell = a0 * b0 / np.hypot(b0 * np.cos(ang), a0 * np.sin(ang))
            k = (R / ell).max()
            A.append(a0 * k); B.append(b0 * k)
        self.A, self.B = self._smooth(np.array(A)), self._smooth(np.array(B))

    @staticmethod
    def _smooth(x):
        y = np.maximum.reduce([np.roll(x, i) for i in (-2, -1, 0, 1, 2)])
        y[:2], y[-2:] = x[:2].max(), x[-2:].max()
        for _ in range(6):
            y[1:-1] = np.maximum(0.25 * y[:-2] + 0.5 * y[1:-1] + 0.25 * y[2:], x[1:-1])
        return y

    def gap(self, t):
        return GAP_WRIST + (GAP_MOUTH - GAP_WRIST) * smoothstep((0.80 - t) / (0.80 - LAMES[-1][1])) ** 1.4

    def point(self, t, a, extra):
        A = np.interp(t, self.ts, self.A) + self.gap(t) + extra
        B = np.interp(t, self.ts, self.B) + self.gap(t) + extra
        r = A * B / np.hypot(B * np.cos(a), A * np.sin(a))
        n = unit(np.cos(a)[..., None] / A[..., None] * self.e1 + np.sin(a)[..., None] / B[..., None] * self.e2)
        p = self.o + (t * self.L)[..., None] * self.d + r[..., None] * (np.cos(a)[..., None] * self.e1
                                                                       + np.sin(a)[..., None] * self.e2)
        return p, n


def lames(ar):
    out, rivets = [], []
    a = np.linspace(-math.pi, math.pi, 37)                        # la costura, repetida (placa cerrada)
    for k, (t0, t1) in enumerate(LAMES):
        T, Aa = np.meshgrid(np.linspace(t0, t1, 7), a, indexing="ij")
        inner, n = ar.point(T, Aa, k * LAME_STEP)
        out.append(bt.grid_slab(inner + n * STEEL, inner))
        tr_ = t0 - 0.025 if k else t0 - 0.05                          # remache cerca del borde de la mano
        for side in (math.pi / 2, -math.pi / 2):
            p, nn = ar.point(np.array(tr_), np.array(side), k * LAME_STEP + STEEL)
            rivets.append(bt.rivet(p, nn, 0.0034))
    return out, rivets


# ---------------- dorso y nudillos ----------------
def hand_plates(surf, p, frame, s):
    back, fwd, right = frame
    j = lambda n: sud.joint_pos(s + n)
    W = 0.5 * np.linalg.norm(j("IndexProximal") - j("LittleProximal")) + 0.012
    y_wrist = (ARM[s]["hand"] - p) @ fwd - 0.006
    y_knk = (j("MiddleProximal") - p) @ fwd
    out = []
    for y0f, y1f, lift, w in ((lambda u: np.full_like(u, y_wrist), lambda u: y_knk - 0.010 - 0.010 * u ** 2,
                               PLATE_LIFT, W),
                              (lambda u: y_knk - 0.016 - 0.010 * u ** 2, lambda u: y_knk + 0.010 - 0.006 * u ** 2,
                               PLATE_LIFT + STEEL + 0.0008, W + 0.003)):
        u, q = np.meshgrid(np.linspace(-1, 1, 21), np.linspace(0, 1, 16), indexing="ij")
        y = y0f(u) + q * (y1f(u) - y0f(u))
        base, sn = surf.place(p, np.c_[(u * w).ravel(), y.ravel()], lift, frame)
        base, sn = smooth_grid(base.reshape(21, 16, 3)), smooth_grid(sn.reshape(21, 16, 3))
        out.append(bt.grid_slab(base + unit(sn) * STEEL, base))
    return out


def smooth_grid(g, it=6):
    """Alisa una rejilla n × m (sin mover los bordes de lado a lado: solo hacia dentro de la rejilla)."""
    g = g.copy()
    for _ in range(it):
        g[1:-1, 1:-1] = 0.5 * g[1:-1, 1:-1] + 0.125 * (g[:-2, 1:-1] + g[2:, 1:-1] + g[1:-1, :-2] + g[1:-1, 2:])
    return g


# ---------------- dedos ----------------
def segments(s, n):
    names = ("Proximal", "Distal") if n == "Thumb" else ("Proximal", "Intermediate", "Distal")
    js = [sud.joint_pos(s + n + x) for x in names]
    return [(s + n + x, js[i], js[i + 1] if i + 1 < len(js) else None, js[i - 1] if i else None)
            for i, x in enumerate(names)]


def finger_plate(s, n, bone, ja, jb, jprev, shell, idx):
    m = (sud.main_bone[idx] == bone) & dg.side_of(shell, s)
    pts = shell[m]
    d = unit(jb - ja) if jb is not None else unit(ja - jprev)
    L = np.linalg.norm(jb - ja) if jb is not None else ((pts - ja) @ d).max()
    back, fwd, right = dg.hand_frame(s)
    e1 = perp(back, d)
    if n == "Thumb":                                               # la uña del pulgar mira hacia fuera de la mano
        away = perp(ja - sud.joint_pos(s + "IndexProximal"), d)
        e1 = perp(e1 + THUMB_TWIST * away, d)
    e2 = np.cross(d, e1)
    q = pts - ja
    along = q @ d
    pp = q - np.outer(along, d)
    r, th = np.linalg.norm(pp, axis=1), np.arctan2(pp @ e2, pp @ e1)
    a = np.radians(np.linspace(-ARC_F, ARC_F, 15))
    keep = (along > -0.1 * L) & (along < 1.02 * L)
    R = np.array([r[keep & (np.abs(th - g) < 0.35)].max(initial=r[keep].max()) for g in a])
    for _ in range(3):
        R[1:-1] = np.maximum(0.25 * R[:-2] + 0.5 * R[1:-1] + 0.25 * R[2:], R[1:-1])
    tip = jb is None
    sv = np.linspace(-0.06 * L, (L + 0.0015) if tip else 0.96 * L, 9 if tip else 5)
    S, Aa = np.meshgrid(sv, a, indexing="ij")
    scale = np.ones_like(S)
    if tip:                                                        # cúpula en la punta
        k0 = 0.45 * L
        scale = np.sqrt(np.clip(1 - (np.maximum(S - k0, 0) / (sv[-1] - k0)) ** 2, 0.02, 1))
    rr = (R[None, :] + GAP_F) * scale
    dirs = np.cos(Aa)[..., None] * e1 + np.sin(Aa)[..., None] * e2
    inner = ja + S[..., None] * d + rr[..., None] * dirs
    outer = inner + dirs * STEEL_F * np.maximum(scale, 0.4)[..., None]
    plate = bt.grid_slab(outer, inner)
    rivets = []
    if not tip:
        for g in (-1, 1):
            k = np.argmin(np.abs(a - g * np.radians(72)))
            p = outer[len(sv) // 2, k]
            rivets.append(bt.rivet(p, dirs[len(sv) // 2, k], 0.0019))
    return plate, rivets


# ---------------- montaje ----------------
def build():
    idx, shell, f_shell = dg.build_shell()
    verts, faces, zones, src_idx, src_w, bones = [], [], [], [], [], []

    def add(v, f, zone, skin_idx=None, mask=None, bone=None, rigid=False):
        v = np.asarray(v, float).reshape(-1, 3)
        faces.append(np.asarray(f, int) + sum(len(x) for x in verts))
        verts.append(v)
        zones.append(np.tile(ZONES[zone], (len(v), 1)))
        bones.append(np.full(len(v), sud.JN.index(bone) if bone else -1))
        if skin_idx is not None:
            src_idx.append(np.c_[skin_idx, np.zeros((len(v), 7), int)])
            src_w.append(np.c_[np.ones(len(v)), np.zeros((len(v), 7))])
        elif rigid:
            near = np.unique(sud.nearest_skin(v, 2, mask)[0][:, 0])
            pick = near[np.linspace(0, len(near) - 1, 8).astype(int)]
            src_idx.append(np.tile(pick, (len(v), 1))); src_w.append(np.full((len(v), 8), 1 / 8))
        else:
            i, w = sud.nearest_skin(v, 8, mask)
            src_idx.append(i); src_w.append(w)

    nrm = sud.vertex_normals(shell, f_shell)
    gv = np.vstack([shell, shell - nrm * dg.THICK])
    gf = np.vstack([f_shell, f_shell[:, ::-1] + len(shell)])
    gv, gf = sud.bridge_open(gv, gf)
    add(gv, gf, "cuero", skin_idx=np.r_[idx, idx])
    surf = eva.Surface(shell, f_shell)
    steel = {}
    for s in SIDES:
        side = dg.side_of(shell, s)
        palm = dg.side_of(P0, s) & (sud.main_bone == s + "Hand")
        arm = dg.side_of(P0, s) & dg.NO_HEAD & ((sud.arm_w > 0.5) | sud.hand_like)
        forearm = dg.side_of(P0, s) & dg.NO_HEAD & (sud.arm_w > 0.5) & ~sud.hand_like
        ar = ArmRadius(s, np.vstack([P0[forearm], shell[side & (dg.HAND_W[idx] < 0.5)]]))
        ls, rv = lames(ar)
        for v, f in ls:
            add(v, f, "acero", mask=arm)
        for v, f in rv:
            add(v, f, "acero", mask=arm, rigid=True)
        back, fwd, right = dg.hand_frame(s)
        p = dg.back_point(shell, side & (dg.HAND_W[idx] > 0.5), ARM[s]["hand"] + fwd * 0.050, back)
        for v, f in hand_plates(surf, p, (back, fwd, right), s):
            add(v, f, "acero", mask=palm, bone=s + "Hand")
        for k, n in enumerate(FINGERS):
            finger = dg.side_of(P0, s) & (dg.CHAIN == k)
            for bone, ja, jb, jprev in segments(s, n):
                (v, f), rivets = finger_plate(s, n, bone, ja, jb, jprev, shell, idx)
                steel.setdefault((s, n), []).append(v)
                add(v, f, "acero", mask=finger & (sud.main_bone == bone), bone=bone)
                for rv_, rf in rivets:
                    add(rv_, rf, "acero", mask=finger & (sud.main_bone == bone), bone=bone, rigid=True)
    check(steel)
    v, f = np.concatenate(verts), np.concatenate(faces)
    dg.OUT, dg.PID = OUT, PID
    return dg.write(v, f, np.concatenate(zones), np.concatenate(src_idx), np.concatenate(src_w),
                    np.concatenate(bones))


def check(steel):
    """Hueco entre las placas de dedos vecinos."""
    worst = []
    for s in SIDES:
        for a, b in zip(FINGERS, FINGERS[1:]):
            A, B = np.vstack(steel[(s, a)]), np.vstack(steel[(s, b)])
            worst.append((cKDTree(B).query(A)[0].min() * 1000, s, a, b))
    for w in sorted(worst)[:4]:
        print("MEDIDA placas %s %s-%s: hueco %.1f mm" % (w[1], w[2], w[3], w[0]))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sha = build()
    cards = [tr.card(PID, "Guanteletes medievales", sha, [0.66, 0.68, 0.72], "accesorio", "accesorio")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_guanteletes_medievales",
            "nombre": "Guanteletes medievales (pruebas)", "autor": "GameMolde", "licencia": "propia", "origen": "",
            "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
