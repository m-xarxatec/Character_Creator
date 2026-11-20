#!/bin/sh
# Paso B0.5: instala el build de Linux para abrir GameMolde con la orden «gamemolde» y desde el menú, sin sudo.
# Uso: sh scripts/instalar_lanzador.sh [build]   (por defecto build/linux/gamemolde.x86_64; antes, el paso 7.1)
# Copia el build y el icono a ${XDG_DATA_HOME:-~/.local/share}/gamemolde/, enlaza ~/.local/bin/gamemolde y escribe
# applications/gamemolde.desktop. Tras rehacer el build, vuelve a lanzarlo. Desinstalar: borrar esos tres sitios.
# Prueba: pruebas/fase_7/probar_lanzador.sh
set -e
root=$(cd "$(dirname "$0")/.." && pwd)
build="${1:-$root/build/linux/gamemolde.x86_64}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
share="$data/gamemolde"
bin="$HOME/.local/bin"
[ -f "$build" ] || { echo "ERROR: no existe $build (haz antes el build: sh pruebas/fase_7/probar_build_linux.sh)"; exit 1; }
mkdir -p "$share" "$bin" "$data/applications"
cp "$build" "$share/gamemolde.x86_64"
chmod +x "$share/gamemolde.x86_64"
cp "$root/godot/app/icono.png" "$share/icono.png"
ln -sf "$share/gamemolde.x86_64" "$bin/gamemolde"
cat > "$data/applications/gamemolde.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=GameMolde
Comment=Editor de personajes 3D
Exec="$share/gamemolde.x86_64"
Icon=$share/icono.png
Terminal=false
Categories=Graphics;3DGraphics;
EOF
echo "INSTALADO: $bin/gamemolde"
case ":$PATH:" in
	*":$bin:"*) ;;
	*) echo "AVISO: $bin no está en el PATH. Añade a ~/.profile: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
