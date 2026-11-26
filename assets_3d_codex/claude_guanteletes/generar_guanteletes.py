"""Guanteletes de garras de dragón (plano: planos/Guanteletes de garras de dragón segmentados.webp).

Uso:  python generar_guanteletes.py   (en Linux: ~/.venvs/gamemolde_assets/bin/python generar_guanteletes.py)
Escribe packs/claude_guanteletes/: guanteletes_dragon, el par en **una sola pieza**, ranura «accesorio» (va encima
de cualquier ropa, también del traje EVA).
- Guante: la piel de la mano y del final del antebrazo copiada e hinchada (pesos y formas por índice: sigue a
  cualquier edición del cuerpo y crece con las manos), con grosor. **Más grande que la mano**: dorso y palma a 8 mm,
  dedos a 6 mm (nunca más de 0,45 × el hueco con el dedo de al lado, para que no se peguen), puño acampanado de
  2 a 3,2 cm (tapa el anillo de muñeca del traje EVA). Surco en cada nudillo (dedos segmentados). SIZE escala todo lo «grande» a la vez.
- Garras: una por dedo, curvada hacia la palma (la del pulgar, hacia el índice), rígida con la última falange.
- Dorso: escudo con cresta y chevrón encima (rígidos con la mano); dos correas en X por debajo.
- Muñequera con un bloque encima.
Zonas en COLOR_0: (0,0,0) cuero; r = 1 correas, escudo y muñequera; g = 1 garras.
"""
import json, math, sys
from pathlib import Path
import numpy as np
from scipy.spatial import cKDTree

HERE = Path(__file__).parent
for d in ("claude_sudadera", "claude_traje", "claude_casco", "claude_eva", "claude_botas_medievales"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_sudadera as sud
import generar_traje as tr
import generar_casco as casco
import generar_eva as eva
import generar_botas as bt

OUT = HERE / "packs" / "claude_guanteletes"
PID = "guanteletes_dragon"

# --- medidas (metros); t: a lo largo del antebrazo, 0 codo y 1 muñeca ---
SIZE = 1.0                                  # lo «grande»: holguras, puño y garras
CUFF_T = 0.70                               # boca del puño (unos 7 cm sobre la muñeca)
OFF_CUFF, OFF_MOUTH = 0.020 * SIZE, 0.032 * SIZE
OFF_HAND, OFF_FINGER = 0.008 * SIZE, 0.006 * SIZE
OFF_MIN = 0.0009
GROOVE = 0.0018                             # surco en cada nudillo
THICK = 0.003
CLAW = {"Thumb": 0.038, "Index": 0.044, "Middle": 0.046, "Ring": 0.044, "Little": 0.036}
STRAP_T = 0.88                              # muñequera
STEEL = 0.003

P0, F0, SIDES, ARM = sud.P0, sud.F0, sud.SIDES, sud.ARM
ZONES = {"cuero": (0, 0, 0, 1), "correas": (1, 0, 0, 1), "garras": (0, 1, 0, 1)}
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Little")
CHAIN = np.array([next((k for k, n in enumerate(FINGERS) if n in b), -1) for b in sud.main_bone])
FINGER_W = sud.bone_weight([n for n in sud.JN if any(k in n for k in FINGERS)])
HAND_W = eva.HAND_W
NO_HEAD = sud.main_bone != "Head"


def unit(x):
    return x / np.linalg.norm(x)


def side_of(p, s):
    return np.sign(p[:, 0]) == SIDES[s]


def forearm_t(p, s):
    a = ARM[s]
    return (p - a["lower"]) @ (a["hand"] - a["lower"]) / np.sum((a["hand"] - a["lower"]) ** 2)


def hand_frame(s):
    """(dorso, hacia los dedos, de lado) de la mano en reposo."""
    j = lambda n: sud.joint_pos(s + n)
    fwd = ARM[s]["hand_dir"]
    back = SIDES[s] * np.cross(j("IndexProximal") - j("LittleProximal"), j("MiddleProximal") - ARM[s]["hand"])
    back = unit(back - fwd * (back @ fwd))
    return back, fwd, np.cross(fwd, back)


# ---------------- 1. guante ----------------
def select_region():
    keep = np.zeros(len(P0), bool)
    for s in SIDES:
        keep |= side_of(P0, s) & NO_HEAD & (sud.hand_like | ((sud.arm_w > 0.5) & (forearm_t(P0, s) > CUFF_T)))
    faces = F0[keep[F0].all(1)]
    verts = np.unique(faces)
    remap = -np.ones(len(P0), int); remap[verts] = np.arange(len(verts))
    return verts, remap[faces]


def free_room(idx, nrm):
    """Sitio libre delante de cada vértice de la mano: lo más cerca que hay piel de la misma mano en un cono de 60°
    alrededor de la normal (el dedo de al lado, el fondo entre dos dedos)."""
    room = np.full(len(idx), np.inf)
    p = P0[idx]
    for s in SIDES:
        hand = np.where(side_of(P0, s) & sud.hand_like)[0]
        kd = cKDTree(P0[hand])
        mine = np.where(side_of(p, s) & sud.hand_like[idx])[0]
        for i, near in zip(mine, kd.query_ball_point(p[mine], 0.03)):
            d = P0[hand[near]] - p[i]
            dist = np.linalg.norm(d, axis=1)
            ok = (dist > 1e-6) & (d @ nrm[i] > 0.5 * dist)
            if ok.any():
                room[i] = dist[ok].min()
    return room


def grooves(idx):
    """Surco en cada nudillo de cada dedo."""
    g = np.zeros(len(idx))
    p = P0[idx]
    for s in SIDES:
        for k, n in enumerate(FINGERS):
            names = ("Proximal", "Distal") if n == "Thumb" else ("Proximal", "Intermediate", "Distal")
            js = [sud.joint_pos(s + n + x) for x in names]
            m = side_of(p, s) & (CHAIN[idx] == k)
            for a, b in zip(js, js[1:] + [None]):
                ax = unit((b - a) if b is not None else (a - js[-2]))
                d = p[m] - a
                along = d @ ax
                g[m] = np.maximum(g[m], GROOVE * np.exp(-(along / 0.003) ** 2))
    return g


def offsets(idx, f, nrm):
    v = P0[idx]
    t = np.zeros(len(v))
    for s in SIDES:
        m = side_of(v, s)
        t[m] = forearm_t(v[m], s)
    cuff = OFF_CUFF + (OFF_MOUTH - OFF_CUFF) * eva.smoothstep((1 - t) / (1 - CUFF_T))
    fw, hw = FINGER_W[idx], HAND_W[idx]
    hand = OFF_HAND * (1 - fw) + (OFF_FINGER - grooves(idx)) * fw
    off = cuff * (1 - hw) + hand * hw
    cap = np.maximum(0.45 * free_room(idx, nrm), OFF_MIN)
    a, deg = sud.laplacian(f, len(v))
    off = np.minimum(off, cap)
    for _ in range(8):
        off = np.minimum(0.5 * off + 0.5 * (a @ off) / deg, cap)
    return np.maximum(off, OFF_MIN)


def mouth_plane(s):
    a = ARM[s]
    p0 = a["lower"] + (a["hand"] - a["lower"]) * CUFF_T
    return lambda q: q - np.outer((q - p0) @ a["dir"], a["dir"])


def build_shell():
    idx, f = select_region()
    loops = sud.boundary_loops(f)
    assert len(loops) == 2, [len(l) for l in loops]
    skin0 = P0[idx]
    nrm = sud.vertex_normals(skin0, f)
    off = offsets(idx, f, nrm)
    v = skin0 + nrm * off[:, None]
    mouths = {("Left" if skin0[lp, 0].mean() > 0 else "Right"): lp for lp in loops}
    fixed = np.zeros(len(v), bool)
    for s, lp in mouths.items():
        v[lp] = mouth_plane(s)(v[lp]); fixed[lp] = True
    hand = HAND_W[idx] > 0.3

    def keep_out(v):
        proj = np.einsum("ij,ij->i", v - skin0, nrm)
        return v + nrm * np.maximum(0.8 * off - proj, 0)[:, None]

    for _ in range(4):                                               # el puño, liso; la mano no se toca
        v = keep_out(sud.taubin(v, f, fixed | hand, 8))
    for s, lp in mouths.items():
        v = sud.smooth_loop(v, lp, 10, mouth_plane(s))
    return idx, v, f


# ---------------- 2. garras ----------------
def claw(s, n):
    j = lambda x: sud.joint_pos(s + x)
    jd = j(n + "Distal")
    d = unit(jd - j(n + ("Proximal" if n == "Thumb" else "Intermediate")))
    if n == "Thumb":                                                 # el pulgar se curva hacia el índice
        curl = j("IndexDistal") - jd
    else:
        curl = -hand_frame(s)[0]
    curl = unit(curl - d * (curl @ d))
    m = side_of(P0, s) & (sud.main_bone == s + n + "Distal")
    tip = ((P0[m] - jd) @ d).max()
    near = P0[m][((P0[m] - jd) @ d) > 0.4 * tip]
    rb = ((near - jd) @ -curl).max()
    L = CLAW[n] * SIZE
    base = jd + d * (0.55 * tip) - curl * (0.55 * rb)                # encima de la última falange, como una uña
    s_ = np.linspace(-0.35, 1.0, 14)
    length = L + 0.45 * tip
    pts = base + np.outer(s_ * length, d) + np.outer(0.30 * length * np.clip(s_, 0, None) ** 2, curl)
    rad = np.clip(1 - np.clip(s_, 0, None), 0, 1) ** 0.85
    tg = np.gradient(pts, axis=0)
    tg /=np.linalg.norm(tg, axis=1, keepdims=True)
    up = -curl - tg * (tg @ -curl)[:, None]; up /= np.linalg.norm(up, axis=1, keepdims=True)
    side = np.cross(tg, up)
    hw, hh = 0.0078 * SIZE ** 0.5, 0.0062 * SIZE ** 0.5               # sección: hexágono más ancho que alto
    ang = np.linspace(0, 2 * math.pi, 6, endpoint=False) + math.pi / 6
    rings = pts[:-1, None] + rad[:-1, None, None] * (hw * np.cos(ang)[None, :, None] * side[:-1, None]
                                                      + hh * np.sin(ang)[None, :, None] * up[:-1, None])
    m6, nr = 6, len(pts) - 1
    v = np.vstack([rings.reshape(-1, 3), pts[0], pts[-1]])
    f = tr.ring_faces(nr, m6, False)
    i = np.arange(m6)
    f = np.concatenate([f, np.stack([np.full(m6, len(v) - 2), (i + 1) % m6, i], -1),
                        np.stack([np.full(m6, len(v) - 1), (nr - 1) * m6 + i, (nr - 1) * m6 + (i + 1) % m6], -1)])
    return tr.orient_closed(v, f)


# ---------------- 3. dorso y muñequera ----------------
def shield(surf, p, frame, nu=17, nv=22):
    u, w = np.meshgrid(np.linspace(-1, 1, nu), np.linspace(0, 1, nv), indexing="ij")
    W = 0.027 * SIZE
    y0 = -0.036 * SIZE + 0.020 * SIZE * np.abs(u)                    # punta hacia la muñeca
    y1 = 0.030 * SIZE - 0.008 * SIZE * np.abs(u)                     # arriba, en pico
    pts = np.c_[(u * W).ravel(), (y0 + w * (y1 - y0)).ravel()]
    base, sn = surf.place(p, pts, 0.002, frame)
    crest = 0.0030 * np.clip(1 - np.abs(u) / 0.22, 0, 1).ravel()
    inner = base.reshape(nu, nv, 3)
    outer = (base + sn * (STEEL + crest)[:, None]).reshape(nu, nv, 3)
    return bt.grid_slab(outer, inner)


def chevron(surf, p, frame, nu=25, nv=4):
    u, w = np.meshgrid(np.linspace(-1, 1, nu), np.linspace(0, 1, nv), indexing="ij")
    W = 0.036 * SIZE
    y = 0.012 * SIZE + 0.012 * SIZE * (1 - np.abs(u)) + w * 0.013 * SIZE
    base, sn = surf.place(p, np.c_[(u * W).ravel(), y.ravel()], 0.0045, frame)
    return bt.grid_slab((base + sn * 0.0028).reshape(nu, nv, 3), base.reshape(nu, nv, 3))


def strip(surf, p, frame, a, b, half=0.007, n=26):
    """Correa plana sobre el dorso, de a a b (puntos 2D del marco)."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    d = unit(b - a); perp = np.array([-d[1], d[0]])
    t, q = np.meshgrid(np.linspace(0, 1, n), np.linspace(-1, 1, 4), indexing="ij")
    pts = a + t.ravel()[:, None] * (b - a) + q.ravel()[:, None] * half * perp
    base, sn = surf.place(p, pts, 0.0012, frame)
    return bt.grid_slab((base + sn * 0.0022).reshape(n, 4, 3), base.reshape(n, 4, 3))


def back_point(shell, side, p_line, back):
    near = shell[side & (np.linalg.norm(np.cross(shell - p_line, back), axis=1) < 0.012)]
    return near[np.argmax((near - p_line) @ back)]


def wrist_band(shell, sel, s):
    a = ARM[s]
    c = a["lower"] + (a["hand"] - a["lower"]) * STRAP_T
    bv, bf = eva.band(shell, sel, c, a["dir"], 0.011, eva.bevel_prof(0.011, 0.0045), n=64)
    back = hand_frame(s)[0]
    back = unit(back - a["dir"] * (back @ a["dir"]))
    p = bv[np.argmax((bv - c) @ back)]
    tang = np.cross(a["dir"], back)
    block = casco.box(p + back * 0.002, [0.013, 0.0135, 0.004], tang, a["dir"], back)
    return (bv, bf), block


# ---------------- 4. montaje y .glb ----------------
def build():
    idx, shell, f_shell = build_shell()
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
        elif rigid:                                                  # los mismos 8 puntos de piel para todo
            near = np.unique(sud.nearest_skin(v, 2, mask)[0][:, 0])
            pick = near[np.linspace(0, len(near) - 1, 8).astype(int)]
            src_idx.append(np.tile(pick, (len(v), 1))); src_w.append(np.full((len(v), 8), 1 / 8))
        else:
            i, w = sud.nearest_skin(v, 8, mask)
            src_idx.append(i); src_w.append(w)

    nrm = sud.vertex_normals(shell, f_shell)
    add(shell, f_shell, "cuero", skin_idx=idx)
    add(shell - nrm * THICK, f_shell[:, ::-1], "cuero", skin_idx=idx)
    surf = eva.Surface(shell, f_shell)
    for s in SIDES:
        side = side_of(shell, s)
        palm = side_of(P0, s) & (sud.main_bone == s + "Hand")
        hand = side_of(P0, s) & sud.hand_like
        arm = side_of(P0, s) & NO_HEAD & ((sud.arm_w > 0.5) | sud.hand_like)
        for n in FINGERS:
            tip = side_of(P0, s) & (sud.main_bone == s + n + "Distal")
            add(*claw(s, n), "garras", mask=tip, bone=s + n + "Distal", rigid=True)
        back, fwd, right = hand_frame(s)
        p = back_point(shell, side & (HAND_W[idx] > 0.5), ARM[s]["hand"] + fwd * 0.050, back)
        frame = (back, fwd, right)
        add(*shield(surf, p, frame), "correas", mask=palm, bone=s + "Hand", rigid=True)
        add(*chevron(surf, p, frame), "correas", mask=palm, bone=s + "Hand", rigid=True)
        for sx in (1, -1):
            add(*strip(surf, p, frame, (sx * 0.042, 0.040), (-sx * 0.040, -0.042)), "correas", mask=hand)
        sel = side & (HAND_W[idx] < 0.5)
        (bv, bf), block = wrist_band(shell, sel, s)
        add(bv, bf, "correas", mask=arm)
        add(*block, "correas", mask=arm, rigid=True)
    v, f = np.concatenate(verts), np.concatenate(faces)
    v, f = sud.bridge_open(v, f)                                     # boca del puño: fuera ↔ dentro
    return write(v, f, np.concatenate(zones), np.concatenate(src_idx), np.concatenate(src_w), np.concatenate(bones))


def write(v, f, zc, si, sw, bones):
    joints, weights = sud.blend_weights(si, sw)
    rigid = bones >= 0
    joints[rigid] = np.c_[bones[rigid], np.zeros((rigid.sum(), 3), int)]
    weights[rigid] = [1, 0, 0, 0]
    targets = {}
    for name, d in sud.B["targets"].items():
        moved = (d[si] * sw[..., None]).sum(1)
        if np.abs(moved).max() >= 0.0005:
            targets[name] = moved.astype(np.float32)
    to_rig = np.array([tr.RIG_JN.index(n) if n in tr.RIG_JN else -1 for n in sud.JN])
    jr = to_rig[joints]
    weights = np.where(jr < 0, 0, weights); weights /= weights.sum(1, keepdims=True)
    jr = np.where(jr < 0, 0, jr)
    path = OUT / (PID + ".glb")
    sha = tr.write_glb(path, v, sud.vertex_normals(v, f), f, jr, weights, targets, PID, zc)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        PID, len(v), len(f), len(targets), path.stat().st_size / 1e6))
    return sha


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sha = build()
    cards = [tr.card(PID, "Guanteletes de garras de dragón", sha, [0.29, 0.24, 0.27], "accesorio", "accesorio")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_guanteletes", "nombre": "Guanteletes (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
