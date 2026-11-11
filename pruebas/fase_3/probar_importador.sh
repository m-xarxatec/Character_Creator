#!/bin/sh
# Paso 3.6.5: importa un .glb de cada variante con el importador del editor de Godot, en un proyecto vacío
# (sin el addon), y comprueba la escena importada con pruebas/godot/probar_importado.gd.
# Uso: pruebas/fase_3/probar_importador.sh 2>&1 | grep -E 'FALLO|RESULTADO|ERROR'
# Antes: pruebas/godot/probar_exportar.gd (escribe pruebas/fase_3/salida/t/ y a/).
set -e
here=$(cd "$(dirname "$0")" && pwd)
project="$here/salida/proyecto"
rm -rf "$project"
mkdir -p "$project"
printf 'config_version=5\n\n[application]\n\nconfig/name="Prueba de importar"\n' > "$project/project.godot"
cp "$here/salida/t/al_azar.glb" "$project/t.glb"
cp "$here/salida/a/al_azar.glb" "$project/a.glb"
(ulimit -v 4000000; timeout 300 godot --headless --path "$project" --import) || echo "ERROR: la importación falló o tardó demasiado"
(ulimit -v 4000000; timeout 120 godot --headless --path "$project" -s "$here/../godot/probar_importado.gd")
