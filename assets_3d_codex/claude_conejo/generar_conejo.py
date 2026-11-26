"""Orejas de conejo (sin diadema) para la humana de GameMolde.

Uso:  python generar_conejo.py   (en Linux sin numpy: /snap/blender/current/*/python/bin/python3.13 generar_conejo.py)
Reutiliza claude_orejas/generar_orejas.py (cráneo, tubo, formas y .glb) y cambia la forma de la oreja.
Escribe en packs/claude_conejo/ dos piezas (un color cada una) y su pack.json:
  orejas_conejo            las dos orejas (fuera, lomo y borde), blancas
  orejas_conejo_interior   el interior rosa del cuenco
- Ranura «accesorio»: conviven con cualquier peinado. 100 % del hueso Head.
- Largas (OREJA_ALTO), estrechas en la base, anchas a media altura y con la punta redonda y algo hacia delante.
- Formas del cuerpo: cada oreja se mueve entera con su base, como las de gato.
"""
import json, math, sys
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).parents[1] / "claude_orejas"))
import generar_orejas as G

D = math.radians
G.OUT = Path(__file__).parent / "packs" / "claude_conejo"

# --- medidas (metros) ---
G.OREJA_PHI = D(64)            # más juntas y más arriba que las de gato
G.OREJA_RECTA = 0.75           # casi verticales, algo abiertas hacia fuera
G.OREJA_GIRO = D(12)           # miran un poco hacia fuera
G.OREJA_ALTO = 0.17
G.OREJA_HUNDIDA = 0.012
BASE_MEDIA, ANCHO_MEDIO, S_ANCHO = 0.012, 0.024, 0.42   # semiancho en la base y el máximo, y dónde está
CUENCO, BORDE, LOMO = 0.010, 0.0045, 0.006
CURVA = 0.022                  # cuánto se adelanta la punta


def half_width(s):
    if s < S_ANCHO:
        return BASE_MEDIA + (ANCHO_MEDIO - BASE_MEDIA) * math.sin(math.pi / 2 * s / S_ANCHO)
    return ANCHO_MEDIO * math.sqrt(max(1 - ((s - S_ANCHO) / (1 - S_ANCHO)) ** 2, 0.0))


def ear_section(s, inner):
    """Sección (x lateral, z delante) a la altura s (0 = piel, 1 = punta): cuenco delante, lomo detrás, borde redondo."""
    sc = min(max(s, 0.0), 0.99)
    w = max(half_width(sc), 0.002)
    k = w / ANCHO_MEDIO
    cup = CUENCO * k
    u = np.linspace(-1, 1, 14)
    if inner:                                                       # interior: una lámina dentro del cuenco
        wi = max(w * 0.68 - 0.002, 0.0015)
        x, zf = u * wi, -cup * (1 - (u * wi / w) ** 2) + 0.0012
        thick, bulge = 0.002, 0.0
    else:
        x, zf = u * w, -cup * (1 - u ** 2)
        thick, bulge = BORDE, LOMO * k
    zb = zf - thick - bulge * (1 - u ** 2)
    rr = thick / 2
    al = np.radians(np.linspace(60, -60, 5))
    right = [(x[-1] + rr * math.cos(a), zf[-1] - rr + rr * math.sin(a)) for a in al]
    left = [(x[0] - rr * math.cos(a), zf[0] - rr - rr * math.sin(a)) for a in al]
    return np.array(list(zip(x, zf)) + right + list(zip(x[::-1], zb[::-1])) + left)


def ear(side, inner):
    base, up, f, b = G.ear_frame(side)
    if inner:
        h = np.linspace(0.08, 0.90, 40) * G.OREJA_ALTO
    else:
        h = np.concatenate([[-G.OREJA_HUNDIDA], np.linspace(0, 1, 56) ** 0.9 * G.OREJA_ALTO])
    s = np.clip(h / G.OREJA_ALTO, 0, 1)
    secs = np.stack([ear_section(x, inner) for x in s])
    bend = (CURVA * s ** 2)[:, None, None]                          # la punta se adelanta
    rings = base + up * h[:, None, None] + b * secs[..., 0:1] + f * (secs[..., 1:2] + bend)
    return G.tube(rings), base


G.ear_section, G.ear = ear_section, ear


def main():
    G.OUT.mkdir(parents=True, exist_ok=True)
    bases = np.array([G.ear_frame(side)[0] for side in (1, -1)])
    moves = G.base_moves(bases)
    cards = [G.card("orejas_conejo", "Orejas de conejo", G.export("orejas_conejo", False, moves), [0.95, 0.94, 0.93]),
             G.card("orejas_conejo_interior", "Orejas de conejo: interior",
                    G.export("orejas_conejo_interior", True, moves), [0.93, 0.6, 0.65])]
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_conejo", "nombre": "Orejas de conejo (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": cards}
    (G.OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
    print("MEDIDA bases de las orejas: x=±%.3f y=%.3f z=%.3f" % (bases[0, 0], bases[0, 1], bases[0, 2]))
    tips = [ear(side, False)[0][0] for side in (1, -1)]
    top = max(v[:, 1].max() for v in tips)
    print("MEDIDA punta más alta: y=%.3f (%.1f cm sobre la base)" % (top, (top - bases[0, 1]) * 100))


if __name__ == "__main__":
    main()
