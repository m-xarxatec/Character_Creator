#!/bin/sh
# Paso 7.4: crea el .zip de la versión de Linux y su suma de control (antes: probar_build_linux.sh, que hace el build),
# y lo prueba descomprimido en una carpeta vacía.
# Uso: sh pruebas/fase_7/empaquetar.sh 0.1.0 2>&1 | grep -E 'AUTOPRUEBA|RESULTADO|ERROR'
set -e
v="$1"; [ -n "$v" ] || { echo "ERROR: falta la versión"; exit 1; }
root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/build/GameMolde-$v-linux"
rm -rf "$out" "$root/build/GameMolde-$v-linux.zip"*; mkdir -p "$out"
cp "$root/build/linux/gamemolde.x86_64" "$root/LICENSE" "$root/CREDITOS.md" "$out/"
cp "$root/README.md" "$out/LEEME.md"
chmod +x "$out/gamemolde.x86_64"
(cd "$root/build" && zip -r -q "GameMolde-$v-linux.zip" "GameMolde-$v-linux" && sha256sum "GameMolde-$v-linux.zip" > "GameMolde-$v-linux.zip.sha256")
echo "RESULTADO $(stat -c %s "$root/build/GameMolde-$v-linux.zip") bytes; $(cat "$root/build/GameMolde-$v-linux.zip.sha256")"
tmp=$(mktemp -d)
(cd "$tmp" && unzip -q "$root/build/GameMolde-$v-linux.zip" && cd "GameMolde-$v-linux" \
	&& (ulimit -v 4000000; timeout 120 ./gamemolde.x86_64 --headless -- --autoprueba))
echo "RESULTADO paquete probado en $tmp"
