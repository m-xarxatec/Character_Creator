"""Pack de 3 piezas (bomber, top y shorts): cada generador escribe su pieza y deja las demás en pack.json."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).parent
sys.path[:0] = [str(HERE.parent / d) for d in ("claude_bodysuits", "claude_armadura_modular", "claude_botas_medievales",
                                              "claude_casco")]
OUT = HERE / "packs" / "claude_bomber"
ORDER = ["bomber_verde", "top_negro", "shorts_negros"]


def cards():
    p = OUT / "pack.json"
    return json.loads(p.read_text(encoding="utf-8"))["piezas"] if p.exists() else []


def save(card):
    """Sustituye o añade la ficha (mismo id) y escribe pack.json."""
    by_id = {c["id"]: c for c in cards()}
    by_id[card["id"]] = card
    piezas = sorted(by_id.values(), key=lambda c: ORDER.index(c["id"]) if c["id"] in ORDER else 99)
    pack = {"formato": "gamemolde-pack", "version": 1, "id": "claude_bomber", "nombre": "Bomber y shorts (pruebas)",
            "autor": "GameMolde", "licencia": "propia", "origen": "", "piezas": piezas}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "pack.json").write_text(json.dumps(pack, ensure_ascii=False, indent=1), encoding="utf-8")
