#!/bin/sh
# Paso B0.5: prueba scripts/instalar_lanzador.sh con HOME y XDG_DATA_HOME temporales (no toca los de verdad): los tres
# archivos existen, el .desktop es válido y la orden «gamemolde», lanzada desde otra carpeta, pasa la autoprueba.
# Uso: sh pruebas/fase_7/probar_lanzador.sh 2>&1 | grep -E 'FALLO|RESULTADO'
# Antes: el build (sh pruebas/fase_7/probar_build_linux.sh). Necesita desktop-file-validate.
# Que detecta el fallo: en instalar_lanzador.sh, quitar la línea «ln -sf» -> «FALLO la orden gamemolde existe».
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
tmp=$(mktemp -d)
home="$tmp/home"
failures=0
check() {
	if eval "$2"; then echo "  bien  $1"; else echo "  FALLO $1"; failures=$((failures + 1)); fi
}
HOME="$home" XDG_DATA_HOME="$home/.local/share" sh "$root/scripts/instalar_lanzador.sh"
command="$home/.local/bin/gamemolde"
check "la orden gamemolde existe" '[ -x "$command" ]'
check "el programa está copiado" '[ -x "$home/.local/share/gamemolde/gamemolde.x86_64" ]'
check "el icono está copiado" '[ -s "$home/.local/share/gamemolde/icono.png" ]'
check "el acceso del menú es válido" 'desktop-file-validate "$home/.local/share/applications/gamemolde.desktop"'
mkdir -p "$tmp/otra"
cd "$tmp/otra"
out=$( (ulimit -v 4000000; HOME="$home" XDG_DATA_HOME="$home/.local/share" timeout 120 "$command" --headless -- --autoprueba) 2>&1)
check "gamemolde, desde otra carpeta, pasa la autoprueba" 'echo "$out" | grep -q "AUTOPRUEBA: TODO BIEN"'
cd "$root"
rm -rf "$tmp"
if [ "$failures" -eq 0 ]; then echo "RESULTADO: TODO BIEN"; else echo "RESULTADO: $failures FALLOS"; fi
