"""Pack de varias piezas (armadura modular): cada generador escribe su pieza y deja las demás en pack.json."""
import json
from pathlib import Path

OUT = Path(__file__).parent / "packs" / "claude_armadura_modular"
ORDER = ["armadura_body", "armadura_chaqueta", "armadura_acero"]


def cards():
    p = OUT / "pack.json"
    return json.loads(p.read_text(encoding="utf-8"))["piezas"] if p.exists() else []


def save(old, new):
    """Junta las piezas de antes (old) con las nuevas (new, mismo id: la sustituye) y escribe pack.json."""
    by_id = {c["id"]: c for c in old}
    by_id.update({c["id"]: c for c in new})
    piezas = sorted(by_id.values(), key=lambda c: ORDER.index(c["id"]) if c["id"] in ORDER else 99)
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_armadura_modular",
            "nombre": "Armadura modular (pruebas)", "autor": "GameMolde", "licencia": "propia", "origen": "",
            "piezas": piezas}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")


# abertura de las copas del peto (y la del body debajo, para que se vea la piel): elipse en (x, y), delante
HOLE = (0.072, 1.192, 0.028, 0.021)              # |x| del centro, y, medias anchura y altura


def chest_hole(V):
    """> 0 dentro de la abertura (en metros, más o menos)."""
    import numpy as np
    xc, yc, rx, ry = HOLE
    e = np.sqrt(((np.abs(V[:, 0]) - xc) / rx) ** 2 + ((V[:, 1] - yc) / ry) ** 2)
    return np.where(V[:, 2] > 0.05, (1 - e) * ry, -1.0)
