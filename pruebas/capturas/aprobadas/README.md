# Capturas aprobadas

Capturas del motor que el responsable aprueba. Sirven de referencia para detectar retrocesos visuales. Las guarda el constructor cuando el responsable lo pide; el revisor solo las lee.

Estas imágenes **sí van en git**.

## Nombre

Las del 5.11 conservan el nombre de `capturas_de_referencia.sh` (se comparan por nombre) y su origen va en `ORIGEN.md`. Las sueltas:

`<fecha>_<preset>_<pose>_<camara>.png`, por ejemplo `2026-11-11_chibi_reposo-t_juego.png`.

## Archivo `.json` al lado (mismo nombre)

```json
{
  "camara": {"posicion": [0, 0, 0], "mira_a": [0, 0, 0], "fov": 30},
  "luz": "descripción o valores de la luz",
  "resolucion": [1024, 1024],
  "fondo": "#808080",
  "renderizador": "forward_plus | mobile | gl_compatibility",
  "commit": "hash corto"
}
```

## Si pesan

`.gitattributes` solo pasa a LFS los `*.glb`. Si las capturas pesan, habría que añadir (con aprobación):

```
pruebas/capturas/aprobadas/*.png filter=lfs diff=lfs merge=lfs -text
```
