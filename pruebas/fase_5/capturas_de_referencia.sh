#!/bin/sh
# Paso 5.11: genera siempre el mismo conjunto de capturas (preset anime, variante T) para compararlo con comparar_capturas.gd.
# GODOT_ARGS: opciones de Godot (p. ej. "--rendering-method mobile"; paso 5.13).
# Uso: sh pruebas/fase_5/capturas_de_referencia.sh <carpeta de salida> [más opciones de capturar_banco.gd] 2>&1 | grep -E 'GUARDADO|ERROR'
# Ejemplo de ruido: generar dos carpetas y compararlas:
#   godot --headless --path pruebas/godot -s comparar_capturas.gd -- <carpeta 1> <carpeta 2> <salida>
set -e
here=$(cd "$(dirname "$0")" && pwd)
out="$1"; shift
(ulimit -v 4000000; timeout 600 godot $GODOT_ARGS --path "$here/../godot" -s capturar_banco.gd -- --salida="$out" --cuerpo=anime --variantes=t \
	--poses=reposo,brazos_arriba,sentadilla,giro_tronco,caminar@0.5,atacar@0.5 --vistas=frente,tres_cuartos,lado,espalda,juego "$@")
