#!/bin/sh
# Paso 7.2: el README no tiene rutas rotas ni imágenes que falten o pesen demasiado, y dice lo imprescindible.
# Uso: sh pruebas/fase_7/probar_readme.sh 2>&1 | grep -E 'FALLO|RESULTADO'
# Que detecta el fallo: renombrar una captura enlazada (o una ruta citada) -> dice cuál falta.
cd "$(dirname "$0")/../.." || exit 1
fails=0
fail() { echo "  FALLO $1"; fails=$((fails + 1)); }
# Rutas entre comillas invertidas que empiezan por una carpeta o un archivo de la raíz del repositorio.
for path in $(grep -o '`[^` ]*`' README.md | tr -d '`' | sort -u); do
	top=${path%%/*}
	case "$path" in *'*'*|*'<'*) continue;; esac
	if [ -e "$top" ] && [ "$top" != "$path" -o -f "$path" ]; then
		[ -e "$path" ] || fail "ruta del README que no existe: $path"
	fi
done
# Imágenes enlazadas: existen y pesan menos de 1 MB (5 MB si es GIF).
for image in $(grep -o '!\[[^]]*\]([^)]*)' README.md | sed 's/.*(\(.*\))/\1/'); do
	if [ ! -f "$image" ]; then fail "imagen que no existe: $image"; continue; fi
	limit=1048576; case "$image" in *.gif) limit=5242880;; esac
	[ "$(stat -c %s "$image")" -lt "$limit" ] || fail "imagen demasiado grande: $image"
done
for word in "Git LFS" "BoneMap" "socket_hand_r" "MIT" "CC0"; do
	grep -q "$word" README.md || fail "el README no dice «$word»"
done
grep -q "en construcción" README.md && fail "el README todavía dice «en construcción»"
echo "RESULTADO: $([ $fails -eq 0 ] && echo 'TODO BIEN' || echo "$fails FALLOS")"
