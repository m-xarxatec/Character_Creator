"""Sombrero de bruja grande (estilo RPG) para la humana de GameMolde.

Uso:  python generar_sombrero.py   (en Linux sin numpy: /snap/blender/current/*/python/bin/python3.13 generar_sombrero.py)
Reutiliza claude_orejas/generar_orejas.py (cráneo, tubo y .glb). Escribe en packs/claude_sombreros/ tres piezas
(un color cada una) y su pack.json:
  sombrero_bruja           copa que cede por el peso (pliegues) con la punta caída, y ala ancha y ondulada
  sombrero_bruja_cinta     cinta de cuero alrededor de la copa
  sombrero_bruja_hebilla   hebilla cuadrada delante
- Ranura «accesorio»: va encima de cualquier peinado. La copa deja HOLGURA_* sobre la piel para el pelo.
- 100 % del hueso Head. Formas del cuerpo: el sombrero entero se estira y se mueve con la caja de la cabeza (afín
  por ejes, como el casco), así no se abolla.
"""
import json, math, sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).parents[1] / "claude_orejas"))
import generar_orejas as G

D = math.radians
OUT = Path(__file__).parent / "packs" / "claude_sombreros"
G.OUT = OUT

# --- medidas (metros) ---
SOBRE_OREJA = 0.025            # la banda, por encima de la oreja humana (deja ver los ojos)
INCLINACION = D(8)             # el sombrero entero se echa hacia atrás (el ala sube delante)
HOLGURA_BANDA, HOLGURA_ARRIBA = 0.024, 0.035   # sitio para el pelo (el afro abulta ~3 cm)
GROSOR = 0.004
COPA_LARGO = 0.55              # largo de la copa por su eje (cede y se dobla, así que alza menos)
T_CABEZA = 0.24                # hasta aquí (fracción del largo) la copa rodea la cabeza: sube recta
# Pliegues por el peso: (dónde, cuánto cede el eje, hacia qué lado, ancho). Lado: 0 delante, 180° detrás,
# + izquierda del personaje. Se alternan, como una tela que se aplasta.
PLIEGUES = [(0.32, D(20), D(180), 0.035), (0.43, D(24), D(10), 0.035),
            (0.54, D(20), D(200), 0.035), (0.64, D(14), D(-20), 0.035)]
PUNTA = (0.80, D(120), D(195), 0.11)   # la punta cae hacia atrás (y algo a la derecha), curva larga
PLIEGUE_BULTO = 0.15           # cuánto abulta la tela recogida en cada pliegue (fracción del radio)
ARRUGAS = 0.05                 # arrugas pequeñas encima (fracción del radio)
PLIEGUES_H, PLIEGUES_V = 11, 7  # arrugas pequeñas a lo largo y alrededor
ALA_RADIO = 0.28               # 56 cm de diámetro
ALA_GROSOR, ALA_CAIDA, ALA_ONDA = 0.006, 0.030, 0.014
CINTA_ALTO, CINTA_SOBRE, CINTA_GROSOR = 0.034, 0.008, 0.003
HEBILLA_ANCHO, HEBILLA_ALTO, HEBILLA_BARRA, HEBILLA_GROSOR = 0.036, 0.030, 0.0045, 0.003
FORMA_MIN = 0.002              # una forma entra si mueve el sombrero más de 2 mm
NA, NS, NR = 96, 160, 24        # resolución: alrededor, a lo largo de la copa y del ala
A = np.linspace(-math.pi, math.pi, NA, endpoint=False)   # 0 = delante (+z), + = izquierda del personaje (+x)

# ---------------- cabeza ----------------
SKIN = G.SKIN
Y_BAND = G.O[1] + SOBRE_OREJA
_slab = SKIN[np.abs(SKIN[:, 1] - Y_BAND) < 0.01]
O = np.array([0.0, Y_BAND, (_slab[:, 2].max() + _slab[:, 2].min()) / 2])
_d = SKIN - O
S_R, S_A, S_H = np.hypot(_d[:, 0], _d[:, 2]), np.arctan2(_d[:, 0], _d[:, 2]), _d[:, 1]
H_TOP = S_H.max()


def smooth_periodic(values, harmonics):
    f = np.fft.rfft(values)
    f[harmonics + 1:] = 0
    return np.fft.irfft(f, len(values))


def head_need(h0, h1, holgura):
    """Radio que necesita la copa en cada ángulo para la piel entre h0 y h1 (+ holgura), simétrico y suavizado."""
    m = (S_H >= h0) & (S_H <= h1)
    out = np.zeros(NA)
    if m.any():
        idx = np.round((S_A[m] + math.pi) / (2 * math.pi) * NA).astype(int) % NA
        np.maximum.at(out, idx, S_R[m])
    out = np.max([np.roll(out, k) for k in range(-3, 4)], axis=0)        # sin huecos entre ángulos
    out = np.maximum(out, out[(-np.arange(NA)) % NA])                    # simetría izquierda-derecha
    out = np.where(out > 0, out + holgura, 0)
    return np.maximum(smooth_periodic(out, 6), out)


R_BAND = head_need(-0.01, 0.04, HOLGURA_BANDA) + GROSOR


# ---------------- malla ----------------
def wrap_faces(n, m):
    """Rejilla cerrada en los dos sentidos (n anillos de m puntos, el último unido al primero)."""
    j, i = np.meshgrid(np.arange(n), np.arange(m), indexing="ij")
    a, b = j * m + i, j * m + (i + 1) % m
    c, d = ((j + 1) % n) * m + i, ((j + 1) % n) * m + (i + 1) % m
    return np.concatenate([np.stack([a, c, b], -1).reshape(-1, 3), np.stack([b, c, d], -1).reshape(-1, 3)])


def outward(v, f):
    vol = np.einsum("ij,ij->i", v[f[:, 0]], np.cross(v[f[:, 1]], v[f[:, 2]])).sum()
    return v, (f if vol > 0 else f[:, ::-1])


def rotate(v, axis, ang):
    return v * math.cos(ang) + np.cross(axis, v) * math.sin(ang) + axis * (axis @ v) * (1 - math.cos(ang))


def centerline():
    """Eje de la copa: sube recto mientras rodea la cabeza y luego cede por el peso en cada pliegue y en la punta.
    Cada pliegue gira el eje hacia su lado (campana de Gauss a lo largo); el marco (ex, fw) gira con él.
    Devuelve puntos, ex, fw y s (0..1)."""
    s = np.linspace(0, 1, NS)
    ds, dt = COPA_LARGO / (NS - 1), 1 / (NS - 1)
    T, ex, fw, p = np.array([0, 1.0, 0]), np.array([1.0, 0, 0]), np.array([0, 0, 1.0]), O.copy()
    pts, exs, fws = [], [], []
    for k in range(NS):
        pts.append(p); exs.append(ex); fws.append(fw)
        turn = np.zeros(3)
        for tk, ang, side, w in PLIEGUES + [PUNTA]:
            g = math.exp(-0.5 * ((s[k] - tk) / w) ** 2) / (w * math.sqrt(2 * math.pi))
            turn += ang * g * dt * (math.sin(side) * ex + math.cos(side) * fw)
        n = np.linalg.norm(turn)
        if n > 1e-9:
            axis = np.cross(T, turn / n)
            axis /= np.linalg.norm(axis)
            T, ex, fw = rotate(T, axis, n), rotate(ex, axis, n), rotate(fw, axis, n)
        p = p + T * ds
    return np.array(pts), np.array(exs), np.array(fws), s


def crown_radius(pts, s):
    """Radio de la copa (NS, NA): cono que se estrecha, nunca por dentro de cabeza + pelo, con la tela recogida en
    cada pliegue y arrugas pequeñas."""
    r = R_BAND[None] * np.maximum((1 - s[:, None]) ** 0.75, 0.02)
    for k in range(NS):
        h = pts[k, 1] - O[1]
        if s[k] <= T_CABEZA and h <= H_TOP + HOLGURA_ARRIBA:
            hol = HOLGURA_BANDA + (HOLGURA_ARRIBA - HOLGURA_BANDA) * min(max(h / H_TOP, 0), 1)
            r[k] = np.maximum(r[k], head_need(h - 0.008, h + 0.008, hol) + GROSOR)
    t, a = s[:, None], A[None]
    f = 1 + sag_folds(t, a) + ARRUGAS * wrinkles(t, a)
    f = np.where(t <= T_CABEZA + 0.02, np.maximum(f, 1), f)        # alrededor de la cabeza, nunca hacia dentro
    return r * f


def sag_folds(t, a):
    """La tela que se recoge al ceder: bajo cada pliegue un bulto y encima un estrechamiento, más hondo en el lado
    hacia el que cede el eje y con la línea del pliegue en diagonal."""
    out = np.zeros(np.broadcast(t, a).shape)
    for tk, ang, side, w in PLIEGUES:
        x = (t - tk + 0.06 * np.sin(a - side + 1.0)) / w             # diagonal: más alto en un costado
        lado = 0.35 + 0.65 * ((1 + np.cos(a - side)) / 2) ** 1.5
        out += PLIEGUE_BULTO * lado * (np.exp(-((x + 0.7) / 0.8) ** 2) - 0.6 * np.exp(-((x - 0.5) / 0.45) ** 2))
    return out


def wrinkles(t, a):
    """Arrugas pequeñas (0..1, solo hacia fuera): anillos torcidos, surcos que serpentean y pliegues apretados por
    dentro de la punta doblada."""
    ridge = lambda x, k: (1 - np.abs(np.sin(x))) ** k
    rings = ridge(math.pi * (PLIEGUES_H * t + 0.35 * np.sin(2 * a + 1.3) + 0.2 * np.sin(5 * a) + 0.15 * np.sin(9 * t)), 2)
    creases = ridge(PLIEGUES_V / 2 * a + 4 * t + 0.8 * np.sin(7 * t + a), 3)
    tk, _, side, w = PUNTA
    bend = ridge(math.pi * 20 * t + 0.4 * np.sin(3 * a), 2) * (1 + np.cos(a - side)) / 2 \
        * np.exp(-0.5 * ((t - tk) / (1.5 * w)) ** 2)
    ramp = np.clip((t - 0.08) / 0.12, 0, 1)                         # la base, lisa bajo la cinta
    return ramp * (0.5 * rings + 0.3 * creases + 1.2 * bend)


def crown():
    pts, exs, fws, s = centerline()
    r = crown_radius(pts, s)
    rings = pts[:, None] + r[..., None] * (np.sin(A)[None, :, None] * exs[:, None] + np.cos(A)[None, :, None] * fws[:, None])
    return G.tube(rings), r


def brim():
    """Ala: para cada ángulo, un perfil cerrado (arriba hacia fuera, borde redondo, abajo hacia dentro)."""
    u = np.linspace(0, 1, NR)
    loops = []
    for i, a in enumerate(A):
        r0 = R_BAND[i] - GROSOR - 0.004                                  # entra un poco en la copa
        rr = r0 + u * (ALA_RADIO - r0)
        y = -ALA_CAIDA * u ** 2 + ALA_ONDA * u ** 2 * math.sin(3 * a + 0.6)
        t = ALA_GROSOR / 2
        edge = np.radians(np.linspace(80, -80, 7))
        prof = ([(x, yy + t) for x, yy in zip(rr, y)] +
                [(rr[-1] + t * math.cos(e), y[-1] + t * math.sin(e)) for e in edge] +
                [(x, yy - t) for x, yy in zip(rr[::-1], y[::-1])])
        prof = np.array(prof)
        dirv = np.array([math.sin(a), 0, math.cos(a)])
        loops.append(O + prof[:, :1] * dirv + prof[:, 1:2] * np.array([0, 1.0, 0]))
    v = np.stack(loops)
    return outward(v.reshape(-1, 3), wrap_faces(*v.shape[:2]))


def band(r_crown):
    """Cinta: tira de sección redondeada pegada a la copa, de CINTA_SOBRE a CINTA_SOBRE + CINTA_ALTO."""
    hs = np.linspace(CINTA_SOBRE, CINTA_SOBRE + CINTA_ALTO, 6)
    ks = [int(round(h / COPA_LARGO * (NS - 1))) for h in hs]
    outer = [r_crown[k] + CINTA_GROSOR for k in ks]
    inner = [r_crown[k] - 0.002 for k in ks]
    prof = [(outer[j], hs[j]) for j in range(6)] + [(inner[j], hs[j]) for j in range(5, -1, -1)]
    loops = []
    for i, a in enumerate(A):
        dirv = np.array([math.sin(a), 0, math.cos(a)])
        loops.append(np.array([O + rad[i] * dirv + np.array([0, h, 0]) for rad, h in prof]))
    v = np.stack(loops)
    return outward(v.reshape(-1, 3), wrap_faces(*v.shape[:2])), max(outer[j][NA // 2] for j in range(6))


def box(center, half, axes):
    c = np.array([[sx, sy, sz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)], float) * half
    v = center + c @ np.array(axes)
    f = np.array([[0, 1, 3], [0, 3, 2], [4, 6, 7], [4, 7, 5], [0, 4, 5], [0, 5, 1],
                  [2, 3, 7], [2, 7, 6], [0, 2, 6], [0, 6, 4], [1, 5, 7], [1, 7, 3]])
    vol = np.einsum("ij,ij->i", (v - center)[f[:, 0]], np.cross((v - center)[f[:, 1]], (v - center)[f[:, 2]])).sum()
    return v, (f if vol > 0 else f[:, ::-1])


def buckle(front_r):
    """Hebilla: marco cuadrado de 4 barras delante de la cinta."""
    c = O + np.array([0, CINTA_SOBRE + CINTA_ALTO / 2, front_r + HEBILLA_GROSOR / 2])
    ax = [np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), np.array([0, 0, 1.0])]
    w, h, b, t = HEBILLA_ANCHO / 2, HEBILLA_ALTO / 2, HEBILLA_BARRA / 2, HEBILLA_GROSOR / 2
    parts = [box(c + [0, h - b, 0], [w, b, t], ax), box(c - [0, h - b, 0], [w, b, t], ax),
             box(c + [w - b, 0, 0], [b, h, t], ax), box(c - [w - b, 0, 0], [b, h, t], ax),
             box(c + [0, 0, t * 0.5], [b * 0.6, h, t * 1.5], ax)]                       # el pasador
    return merge(parts)


def merge(parts):
    vs, fs, n = [], [], 0
    for v, f in parts:
        vs.append(v); fs.append(f + n); n += len(v)
    return np.concatenate(vs), np.concatenate(fs)


# ---------------- formas ----------------
def shape_fields():
    """Por forma: escala y desplazamiento por ejes de la caja de la cabeza (media de los extremos), como el casco."""
    head = np.where(G.HW > 0.5)[0]
    P0 = G.P0
    ext = []
    for k in range(3):
        o = head[np.argsort(P0[head, k])]
        nn = max(5, len(o) * 3 // 100)
        ext.append((o[:nn], o[-nn:]))
    lo_p = np.array([P0[lo, k].mean() for k, (lo, hi) in enumerate(ext)])
    hi_p = np.array([P0[hi, k].mean() for k, (lo, hi) in enumerate(ext)])
    out = {}
    for name, d in G.B["targets"].items():
        dlo = np.array([d[lo, k].mean() for k, (lo, hi) in enumerate(ext)])
        dhi = np.array([d[hi, k].mean() for k, (lo, hi) in enumerate(ext)])
        out[name] = ((dhi - dlo) / (hi_p - lo_p), (dhi + dlo) / 2, (hi_p + lo_p) / 2)
    return out


def targets(pos, fields):
    out = {}
    for name, (s, t, c) in fields.items():
        d = s * (pos - c) + t
        if np.abs(d).max() > FORMA_MIN:
            out[name] = d.astype(np.float32)
    return out


# ---------------- salida ----------------
def tilt(v):
    """Gira alrededor del centro de la banda: lo de delante sube, lo de detrás baja."""
    c, s = math.cos(INCLINACION), math.sin(INCLINACION)
    d = v - O
    return O + np.stack([d[:, 0], d[:, 1] * c + d[:, 2] * s, -d[:, 1] * s + d[:, 2] * c], 1)


def export(pid, mesh, fields):
    v, f = tilt(mesh[0]), mesh[1]
    tg = targets(v, fields)
    sha = G.write_glb(OUT / (pid + ".glb"), v, G.vertex_normals(v, f), f, tg, pid)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        pid, len(v), len(f), len(tg), (OUT / (pid + ".glb")).stat().st_size / 1e6))
    return sha


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    fields = shape_fields()
    (cv, cf), r_crown = crown()
    hat = merge([(cv, cf), brim()])
    cinta, front_r = band(r_crown)
    cards = [G.card("sombrero_bruja", "Sombrero de bruja", export("sombrero_bruja", hat, fields), [0.2, 0.18, 0.22]),
             G.card("sombrero_bruja_cinta", "Sombrero de bruja: cinta",
                    export("sombrero_bruja_cinta", cinta, fields), [0.11, 0.1, 0.11]),
             G.card("sombrero_bruja_hebilla", "Sombrero de bruja: hebilla",
                    export("sombrero_bruja_hebilla", buckle(front_r), fields), [0.66, 0.52, 0.3])]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_sombreros", "nombre": "Sombreros (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
    print("MEDIDA banda: y=%.3f, ancho %.1f cm, fondo %.1f cm" % (
        Y_BAND, 2 * R_BAND[NA * 3 // 4] * 100, (R_BAND[NA // 2] + R_BAND[0]) * 100))
    print("MEDIDA alto total: %.1f cm sobre la banda; ala de %.0f cm" % ((hat[0][:, 1].max() - Y_BAND) * 100,
                                                                         2 * ALA_RADIO * 100))
    print("MEDIDA hueco mínimo piel-sombrero: %.1f mm" % (gap(tilt(hat[0])) * 1000))


def gap(hat_v):
    """Distancia mínima de la piel de la cabeza (por encima de la nariz) a cualquier punto del sombrero."""
    pts = SKIN[S_H > -0.05][::5]
    best = np.inf
    for k in range(0, len(pts), 512):
        best = min(best, ((pts[k:k + 512, None, :] - hat_v[None, ::2]) ** 2).sum(-1).min())
    return math.sqrt(best)


if __name__ == "__main__":
    main()
