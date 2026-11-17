#!/bin/sh
# Paso A2: empaqueta el proyecto en un .pck y lo lanza desde otra carpeta, sin los archivos sueltos.
# No necesita plantillas de exportación (--export-pack). La autoprueba es la de godot/app/main.gd.
# Uso: sh pruebas/fase_7/probar_pck.sh 2>&1 | grep -E 'AUTOPRUEBA|ERROR'
# Que detecta el fallo: en godot/export_presets.cfg, exclude_filter="datos/humana/*" -> «AUTOPRUEBA: FALLO».
set -e
here=$(cd "$(dirname "$0")" && pwd)
out="$here/salida/pck"
rm -rf "$out"; mkdir -p "$out"
(ulimit -v 4000000; timeout 300 godot --headless --path "$here/../../godot" --export-pack "Linux" "$out/gamemolde.pck")
cd "$out"
(ulimit -v 4000000; timeout 120 godot --headless --main-pack gamemolde.pck -- --autoprueba)
