#!/bin/sh
# Paso 5.7: importa el personaje exportado con el importador del editor, en un proyecto vacío (sin el addon), con y sin
# «Overwrite Axis» (ajuste retarget/rest_fixer/retarget_method del Skeleton3D), y mide cómo se anima con la biblioteca
# de Quaternius (pruebas/godot/probar_retarget.gd).
# Uso: sh pruebas/fase_5/probar_overwrite_axis.sh 2>&1 | grep -E 'MEDIDA|FALLO|RESULTADO|ERROR'
# Antes: pruebas/godot/probar_exportar.gd (escribe pruebas/fase_3/salida/t/ y a/) y, para el prototipo del 5.7b,
# pruebas/godot/probar_ejes_perfil.gd (escribe pruebas/fase_5/salida/t_perfil.glb; si no está, se mide sin él).
# El nombre de cada copia dice cómo se importa: _con = Overwrite Axis; _sin = sin él; _silueta = además corrige los
# brazos a pose T (fix_silhouette); _sin_mapa = sin BoneMap.
set -e
here=$(cd "$(dirname "$0")" && pwd)
project="$here/salida/proyecto_ejes"
godot_tests="$here/../godot"
rm -rf "$project"
mkdir -p "$project"
printf 'config_version=5\n\n[application]\n\nconfig/name="Prueba de Overwrite Axis"\n' > "$project/project.godot"
for name in t_con t_sin; do cp "$here/../fase_3/salida/t/al_azar.glb" "$project/$name.glb"; done
for name in a_con a_sin a_con_silueta; do cp "$here/../fase_3/salida/a/al_azar.glb" "$project/$name.glb"; done
if [ -f "$here/salida/t_perfil.glb" ]; then
	for name in t_perfil_sin t_perfil_sin_mapa; do cp "$here/salida/t_perfil.glb" "$project/$name.glb"; done
fi
cp "$godot_tests/UAL1_Standard.glb" "$godot_tests/bonemap_UAL1_Standard.tres" "$project/"
run() { (ulimit -v 4000000; timeout 300 godot --headless --path "$project" "$@"); }
run --import || echo "ERROR: la primera importación falló o tardó demasiado"
run -s "$godot_tests/probar_retarget.gd" -- --preparar
rm -rf "$project/.godot/imported"  # sin esto Godot no siempre reimporta al cambiar solo el .import (medido con la biblioteca)
run --import || echo "ERROR: la segunda importación falló o tardó demasiado"
run -s "$godot_tests/probar_retarget.gd"
