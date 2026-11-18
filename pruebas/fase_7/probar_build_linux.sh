#!/bin/sh
# Paso 7.1: exporta el build de Linux (un solo archivo, con los datos dentro) y lo prueba en una carpeta vacía, fuera
# del repositorio: autoprueba y el .glb que escribe, con probar_glb.gd. Necesita las plantillas de exportación 4.7.2.
# Uso: sh pruebas/fase_7/probar_build_linux.sh 2>&1 | grep -E 'AUTOPRUEBA|RESULTADO|MEDIDA|FALLO|ERROR'
# Que detecta el fallo: en godot/export_presets.cfg, exclude_filter="datos/humana/*" -> «AUTOPRUEBA: FALLO» (con include_filter=""
# sigue pasando: Godot 4.7 ya mete los .json y .csv como recursos).
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
mkdir -p "$root/build/linux"
rm -f "$root/build/linux/gamemolde.x86_64"
(ulimit -v 4000000; timeout 600 godot --headless --path "$root/godot" --export-release "Linux" "$root/build/linux/gamemolde.x86_64")
tmp=$(mktemp -d)
cp "$root/build/linux/gamemolde.x86_64" "$tmp/"
cd "$tmp"
echo "MEDIDA tamaño del build: $(stat -c %s gamemolde.x86_64) bytes"
echo "MEDIDA archivos en la carpeta de la prueba: $(ls | wc -l)"
user="$HOME/.local/share/godot/app_userdata/GameMolde"
rm -f "$user/autoprueba.glb" "$user/autoprueba.tres"
start=$(date +%s.%N)
(ulimit -v 4000000; timeout 120 ./gamemolde.x86_64 --headless -- --autoprueba) || true
echo "MEDIDA autoprueba (sin ventana): $(echo "$(date +%s.%N) - $start" | bc) s"
mkdir -p "$tmp/glb"
cp "$user/autoprueba.glb" "$user/autoprueba.tres" "$tmp/glb/"
(ulimit -v 4000000; timeout 300 godot --headless --path "$root/pruebas/godot" -s probar_glb.gd -- "$tmp/glb")
echo "RESULTADO carpeta de la prueba: $tmp"
