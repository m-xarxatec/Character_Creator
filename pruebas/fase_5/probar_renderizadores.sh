#!/bin/sh
# Paso 5.13: el estilo con Forward+, Mobile y Compatibility. Necesita ventana. No toca los shaders ni project.godot.
# Uso: sh pruebas/fase_5/probar_renderizadores.sh 2>&1 | grep -E 'RENDERIZADOR|MEDIDA|FALLO|GUARDADO|ERROR|media'
# Por renderizador: conjunto de referencia del 5.11, primeros planos (frente, juego, cara, mano), probar_rendimiento y
# probar_valores_estilo, en pruebas/capturas/renderizadores/<nombre>/. Después compara Mobile y Compatibility con Forward+.
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
out="$repo/pruebas/capturas/renderizadores"
for r in forward_plus mobile gl_compatibility; do
	echo "== $r"
	args="--rendering-method $r"
	[ "$r" = gl_compatibility ] && args="$args --rendering-driver opengl3"
	GODOT_ARGS="$args" sh "$here/capturas_de_referencia.sh" "$out/$r/referencia" 2>&1
	(ulimit -v 4000000; timeout 600 godot $args --path "$repo/pruebas/godot" -s capturar_banco.gd -- --salida="$out/$r/cerca" \
		--variantes=t --poses=reposo --vistas=frente,juego,cara,mano 2>&1)
	(ulimit -v 4000000; timeout 300 godot $args --path "$repo/pruebas/godot" -s probar_rendimiento.gd -- "$repo/godot/datos/humana/cuerpo.glb" 2>&1)
	(ulimit -v 4000000; timeout 600 godot $args --path "$repo/pruebas/godot" -s probar_valores_estilo.gd -- --salida="$out/$r/valores" 2>&1)
done
for r in mobile gl_compatibility; do
	echo "== $r contra forward_plus"
	for set in referencia cerca; do
		(ulimit -v 4000000; timeout 300 godot --headless --path "$repo/pruebas/godot" -s comparar_capturas.gd -- \
			"$out/forward_plus/$set" "$out/$r/$set" "$out/$r/dif_$set" --limite=100 2>&1)
	done
done
