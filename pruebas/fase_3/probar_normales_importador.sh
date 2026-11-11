#!/bin/sh
# Maqueta 3.13a-2: importa cara.glb con el importador del editor de Godot, en un proyecto vacío (sin el addon),
# y compara sus normales con las enviadas (pruebas/godot/probar_normales_leidas.gd).
# Uso: pruebas/fase_3/probar_normales_importador.sh 2>&1 | grep -E 'FALLO|RESULTADO|ERROR|bien'
# Antes: pruebas/godot/probar_normales_cara.gd (escribe pruebas/fase_3/salida/normales/).
set -e
here=$(cd "$(dirname "$0")" && pwd)
project="$here/salida/normales/proyecto"
rm -rf "$project"
mkdir -p "$project"
printf 'config_version=5\n\n[application]\n\nconfig/name="Prueba de normales"\n' > "$project/project.godot"
cp "$here/salida/normales/cara.glb" "$here/salida/normales/cara_normales.json" "$project/"
(ulimit -v 4000000; timeout 300 godot --headless --path "$project" --import) || echo "ERROR: la importación falló o tardó demasiado"
(ulimit -v 4000000; timeout 120 godot --headless --path "$project" -s "$here/../godot/probar_normales_leidas.gd" -- res://cara.glb)
