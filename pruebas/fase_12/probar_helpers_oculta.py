# SPDX-License-Identifier: GPL-3.0-or-later
"""Paso 12.1b-b5: exportar_helpers.write_pack conserva el campo oculta de godot/packs/base/pack.json al reescribirlo.

Uso: (ulimit -v 4000000; timeout 120 blender -b -P pruebas/fase_12/probar_helpers_oculta.py 2>&1 | grep -E 'FALLO|RESULTADO')
Sobre una copia temporal del pack.json real: las fichas sin oculta (como las rehace export_pieces) vuelven a dar el mismo
archivo, byte a byte; una ficha sin oculta antes no la gana; sin pack.json previo, se escribe sin oculta.
Que detecta el fallo: en write_pack, sin copiar oculta -> fallan «mismo archivo» y «tights conserva oculta».
"""
import copy
import json
import os
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "blender"))
import exportar_helpers as eh  # noqa: E402

failures = 0


def check(label, ok, detail=""):
    global failures
    print(("  bien  " if ok else "  FALLO ") + label, detail)
    failures += 0 if ok else 1


def main():
    real = os.path.join(ROOT, "godot/packs/base/pack.json")
    with open(real, encoding="utf-8") as file:
        text = file.read()
    cards = json.loads(text)["piezas"]
    fresh = [{k: v for k, v in card.items() if k != "oculta"} for card in copy.deepcopy(cards)]
    with tempfile.TemporaryDirectory() as folder:
        path = os.path.join(folder, "pack.json")
        with open(path, "w", encoding="utf-8") as file:
            file.write(text)
        eh.write_pack(path, copy.deepcopy(fresh))
        with open(path, encoding="utf-8") as file:
            again = file.read()
        check("12.1b: write_pack da el mismo pack.json", again == text)
        kept = {c["id"]: c.get("oculta") for c in json.loads(again)["piezas"]}
        check("12.1b: tights conserva oculta", kept.get("tights") == next(c for c in cards if c["id"] == "tights").get("oculta"),
              str(kept.get("tights")))
        check("12.1b: las que no tenían oculta no la ganan",
              all(kept[c["id"]] is None for c in cards if "oculta" not in c))
        os.remove(path)
        eh.write_pack(path, copy.deepcopy(fresh))
        with open(path, encoding="utf-8") as file:
            check("12.1b: sin pack.json previo, sin oculta", all("oculta" not in c for c in json.load(file)["piezas"]))
    print("RESULTADO: TODO BIEN" if not failures else f"RESULTADO: {failures} FALLOS")


main()
