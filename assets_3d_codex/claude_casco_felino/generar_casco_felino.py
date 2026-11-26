"""Casco felino neón (plano: planos/Ficha técnica de casco felino futurista neon.webp): casco integral de moto con orejas.

Uso:  python generar_casco_felino.py
Escribe packs/claude_cascos_felinos/: casco_felino, **una sola pieza** en la ranura «pelo» (quita el peinado).
- Carcasa: elipsoide medido sobre la cabeza (la contiene entera) + HOLGURA; cerrada por delante (el visor es opaco) y
  abierta abajo, alrededor del cuello. Visor en relieve sobre la carcasa, mentonera con rejillas, orejas de gato
  (las de claude_orejas, más grandes) con el interior de neón, logo del gato en cada lado, barra de luz detrás,
  franjas de neón y galones.
- Zonas en COLOR_0 (para cuando el núcleo pinte un color por zona): (0,0,0) carcasa, r = 1 visor, g = 1 neón,
  b = 1 galones. Hoy el shader lo pinta todo de un color.
- 100 % del hueso Head; con cada forma se estira y se mueve entero como la caja de la cabeza (como el de astronauta).
Usa las herramientas de claude_casco (burbuja, barrido, torno), claude_orejas (sección de la oreja) y claude_traje
(.glb con COLOR_0 y tarjeta).
"""
import json, math, sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).parent
for d in ("claude_casco", "claude_orejas", "claude_traje"):
    sys.path.insert(0, str(HERE.parent / d))
import generar_casco as cs
import generar_orejas as og
import generar_traje as tr

OUT = HERE / "packs" / "claude_cascos_felinos"
D = math.radians
C, P0, HW = cs.C, cs.P0, cs.HW

# --- medidas (metros; ángulos alrededor de C: az 0 = delante, + = izquierda del personaje; el 0 = altura de C) ---
HOLGURA, GROSOR = 0.022, 0.006        # de la cabeza a la cara de fuera (hueco + espuma + carcasa) y grosor
EL_BOT = D(-47)                       # borde de abajo (la mentonera cubre la barbilla)
VISOR = cs.Outline(D(78), D(38), D(-6), 3.0)       # contorno del visor (az, el)
VISOR_ALTO = (0.002, 0.006)           # visor: de dentro y de fuera, sobre la carcasa
OREJA = dict(az=D(48), el=D(52), alto=0.088, base=0.082, recta=0.55, giro=D(18), hundida=0.022)
LOGO_AZ, LOGO_EL, LOGO_R = D(84), D(10), 0.026      # disco del logo en cada lado (pivote del visor)
RELIEVE = 0.0025                      # lo que sobresalen franjas, galones y rejillas
ZONES = {"carcasa": (0, 0, 0, 1), "visor": (1, 0, 0, 1), "neon": (0, 1, 0, 1), "galon": (0, 0, 1, 1)}
FORMA_MIN = 0.002


# ---------------- carcasa: elipsoide que contiene la cabeza ----------------
_head = P0[HW > 0.5] - C
AX = np.abs(_head).max(0)                                           # semiejes de partida (x, y, z)…
K = np.sqrt(((_head / AX) ** 2).sum(1)).max()                       # …y escala para que la contenga entera


def r_head(A, E):
    """Radio del elipsoide de la cabeza en la dirección (A, E)."""
    u = np.stack([np.cos(E) * np.sin(A), np.sin(E), np.cos(E) * np.cos(A)], -1)
    return K / np.sqrt(((u / AX) ** 2).sum(-1))


def r_out(A, E):
    return r_head(A, E) + HOLGURA


def on_shell(A, E, h=0.0):
    """Punto de la carcasa (cara de fuera) + h hacia fuera, y su normal (aprox. radial)."""
    A, E = np.broadcast_arrays(np.asarray(A, float), np.asarray(E, float))
    n = cs.unit(np.stack([np.cos(E) * np.sin(A), np.sin(E), np.cos(E) * np.cos(A)], -1))
    return C + n * (r_out(A, E) + h)[..., None], n


class Open:
    """Sin abertura: la carcasa solo se corta abajo (bubble lo pide)."""
    def f(self, A, E):
        return np.full_like(A, 2.0)

    def snap(self, A, E):
        return A, E


def shell():
    return cs.bubble(cs.AZ_ALL, cs.rows_to_pole(EL_BOT), lambda A, E: np.ones_like(A, bool), Open(),
                     r_out, lambda A, E: r_out(A, E) - GROSOR, pole=True)


def visor():
    az = np.arange(-VISOR.aw - cs.PASO, VISOR.aw + 1.5 * cs.PASO, cs.PASO / 2)
    el = np.arange(VISOR.e0 - VISOR.eh - cs.PASO, VISOR.e0 + VISOR.eh + 1.5 * cs.PASO, cs.PASO / 2)
    return cs.bubble(az, el, lambda A, E: VISOR.f(A, E) <= 1, VISOR,
                     lambda A, E: r_out(A, E) + VISOR_ALTO[1], lambda A, E: r_out(A, E) + VISOR_ALTO[0], wrap=False)


# ---------------- relieves sobre la carcasa ----------------
def patch(corners, h=RELIEVE, n=8):
    """Cuadrilátero (4 esquinas (az, el), en orden) en relieve: rejilla bilineal, caja cerrada que entra 2 mm."""
    c = np.asarray(corners, float)
    s, t = np.meshgrid(np.linspace(0, 1, n), np.linspace(0, 1, n), indexing="ij")
    ae = ((1 - s) * (1 - t))[..., None] * c[0] + (s * (1 - t))[..., None] * c[1] + (s * t)[..., None] * c[2] \
        + ((1 - s) * t)[..., None] * c[3]
    top = on_shell(ae[..., 0], ae[..., 1], h)[0].reshape(-1, 3)
    bot = on_shell(ae[..., 0], ae[..., 1], -0.002)[0].reshape(-1, 3)
    m = n * n
    f = cs.faces(n, n, False, False)
    ring = np.r_[np.arange(n - 1), (n - 1) + n * np.arange(n - 1), m - 1 - np.arange(n - 1),
                 n * (n - 1) - n * np.arange(n - 1)]                # borde de la rejilla, en orden
    rn = np.roll(ring, -1)
    side = np.concatenate([np.stack([ring, rn, rn + m], 1), np.stack([ring, rn + m, ring + m], 1)])
    return cs.orient_closed(np.concatenate([top, bot]), np.concatenate([f, f[:, ::-1] + m, side]))


def mirror(corners):
    return [(-a, e) for a, e in corners[::-1]]


def both(corners):
    return [patch(corners), patch(mirror(corners))]


def stripes():
    """Neón: barra detrás y franjas inclinadas abajo en los lados; galones blancos arriba en los lados."""
    neon = [patch([(D(166), D(-4)), (D(194), D(-4)), (D(194), D(-1)), (D(166), D(-1))])]   # barra de luz
    neon += both([(D(60), D(-34)), (D(78), D(-34)), (D(70), D(-24)), (D(54), D(-26))])        # junto a la mentonera
    neon += both([(D(122), D(-30)), (D(140), D(-28)), (D(134), D(-20)), (D(118), D(-22))])     # detrás, abajo
    galon = []
    for a0 in (D(111), D(127)):                                                                # dos «<» en cada lado,
        for half in ([(a0 - D(9), D(30)), (a0, D(30)), (a0 - D(6), D(40)), (a0 - D(15), D(40))],   # hacia el visor
                     [(a0 - D(15), D(40)), (a0 - D(6), D(40)), (a0, D(50)), (a0 - D(9), D(50))]):
            galon += both(half)
    return neon, galon


def vents():
    """Rejilla de la mentonera: tres lamas en V a cada lado del centro, y el centro."""
    out = [patch([(D(-4), D(-44)), (D(4), D(-44)), (D(4), D(-30)), (D(-4), D(-30))], 0.004)]
    for k in range(3):
        e = D(-42 + 5 * k)
        out += both([(D(7), e), (D(20), e + D(3)), (D(20), e + D(5)), (D(7), e + D(2))])
    return out


def logo(side):
    """Disco del lado (carcasa), aro y cara de gato de neón."""
    p, n = on_shell(side * LOGO_AZ, LOGO_EL)
    disc = cs.lathe([(0.0005, -0.004), (LOGO_R, -0.004), (LOGO_R, 0.004), (LOGO_R - 0.002, 0.006),
                     (0.0005, 0.006)], p, n, 48)
    ring = cs.lathe([(LOGO_R - 0.006, 0.0055), (LOGO_R - 0.003, 0.0055), (LOGO_R - 0.003, 0.0085),
                     (LOGO_R - 0.006, 0.0085)], p, n, 48)
    face = cs.lathe([(0.0005, 0.0055), (0.009, 0.0055), (0.009, 0.0085), (0.0005, 0.0085)], p, n, 24)
    up = cs.unit(np.array([0, 1.0, 0]) - n * n[1])
    b = np.cross(n, up)
    ears = []
    for s in (-1, 1):                                                # orejitas: prismas triangulares
        tri = [b * s * 0.003 + up * 0.006, b * s * 0.010 + up * 0.004, b * s * 0.008 + up * 0.014]
        v = np.array([p + q + n * h for h in (0.0055, 0.0085) for q in tri])
        f = np.array([[0, 1, 2], [3, 5, 4], [0, 3, 4], [0, 4, 1], [1, 4, 5], [1, 5, 2], [2, 5, 3], [2, 3, 0]])
        ears.append(cs.orient_closed(v, f))
    return [disc], [ring, face] + ears


# ---------------- orejas ----------------
def ear(side, inner):
    """La oreja de claude_orejas, más grande, sobre la carcasa (la base se hunde en ella)."""
    o = OREJA
    og.OREJA_ALTO, og.OREJA_BASE, og.OREJA_HUNDIDA = o["alto"], o["base"], o["hundida"]
    og.OREJA_CUENCO, og.OREJA_BORDE, og.OREJA_LOMO = 0.014, 0.005, 0.012
    base, n = on_shell(side * o["az"], o["el"])
    up = cs.unit(n * (1 - o["recta"]) + np.array([0, 1.0, 0]) * o["recta"])
    f = cs.unit(np.array([0, 0, 1.0]) - up * up[2])
    g = o["giro"] * side
    f = cs.unit(f * math.cos(g) + np.cross(up, f) * math.sin(g))
    b = np.cross(up, f)
    if inner:
        h = np.linspace(0.10, 0.86, 26) * o["alto"]
    else:
        h = np.concatenate([[-o["hundida"]], np.linspace(0, 1, 34) ** 0.9 * o["alto"]])
    secs = np.stack([og.ear_section(x / o["alto"], inner) for x in h])
    rings = base + up * h[:, None, None] + b * secs[..., 0:1] + f * secs[..., 1:2]
    return og.tube(rings)


# ---------------- comprobaciones ----------------
def clearance(fields, names):
    """Hueco de la piel a la cara de dentro (por su dirección desde C), en reposo y con cada forma (la piel llevada
    al casco en reposo con la inversa de su afín). Solo piel cercana, por encima del borde de abajo."""
    def gap(P):
        d = P - C
        r = np.linalg.norm(d, axis=1)
        A, E = np.arctan2(d[:, 0], d[:, 2]), np.arcsin(d[:, 1] / r)
        ro = r_out(A, E)
        m = (E > EL_BOT + D(2)) & (r < ro + 0.005)                    # dentro del casco o en su pared
        return (ro[m] - GROSOR - r[m]).min()

    print("MEDIDA hueco a la piel por dentro (reposo): mín %.1f mm" % (gap(P0) * 1000))
    worst = []
    for k in names:
        s, t, c, _ = fields[k]
        P = c + (P0 + cs.B["targets"][k] - c - t) / (1 + s)
        worst.append((gap(P), k))
    worst.sort()
    print("MEDIDA hueco con cada forma: peores %s" % ", ".join("%.1f mm (%s)" % (a * 1000, b) for a, b in worst[:3]))


def deltas(pos, field):
    s, t, c, _ = field
    return (s * (pos - c) + t).astype(np.float32)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    parts = [(shell(), "carcasa"), (visor(), "visor")]
    neon, galon = stripes()
    parts += [(p, "neon") for p in neon] + [(p, "galon") for p in galon] + [(p, "carcasa") for p in vents()]
    for s in (1, -1):
        disc, glow = logo(s)
        parts += [(p, "carcasa") for p in disc] + [(p, "neon") for p in glow]
        parts += [(ear(s, False), "carcasa"), (ear(s, True), "neon")]
    v, f, c, base = [], [], [], 0
    for (pv, pf), zone in parts:
        v.append(np.asarray(pv, float))
        f.append(np.asarray(pf, int) + base)
        c.append(np.tile(ZONES[zone], (len(pv), 1)))
        base += len(pv)
    v, f, c = np.concatenate(v), np.concatenate(f), np.concatenate(c)
    fields = cs.shape_fields()
    names = [k for k, fl in fields.items() if np.abs(deltas(v, fl)).max() > FORMA_MIN]
    print("MEDIDA cabeza: elipsoide de semiejes %s cm; casco de %.1f a %.1f m de alto, %.1f cm de ancho" % (
        np.round(AX * K * 100, 1), v[:, 1].min(), v[:, 1].max(), np.ptp(v[:, 0]) * 100))
    clearance(fields, names)
    head = tr.RIG_JN.index("Head")
    jr = np.tile(np.array([head, 0, 0, 0]), (len(v), 1))
    w = np.tile(np.array([1.0, 0, 0, 0]), (len(v), 1))
    pid = "casco_felino"
    sha = tr.write_glb(OUT / (pid + ".glb"), v, cs.vertex_normals(v, f), f, jr, w,
                       {k: deltas(v, fields[k]) for k in names}, pid, c)
    print("MEDIDA %s: %d vértices, %d triángulos, %d formas, %.2f MB" % (
        pid, len(v), len(f), len(names), (OUT / (pid + ".glb")).stat().st_size / 1e6))
    cards = [tr.card(pid, "Casco felino neón", sha, [0.13, 0.10, 0.14], "accesorio", "pelo")]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_cascos_felinos", "nombre": "Cascos felinos (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
