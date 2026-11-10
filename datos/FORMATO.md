# Formato de `datos/` (versión 1)

Una carpeta por especie (`datos/humana/`, …). El núcleo no supone que solo existe la humana.
Lo genera `blender/exportar_datos.py` (paso 2.3), salvo `deslizadores.csv`, que se escribe a mano.
Unidades y ejes de Godot: metros, Y arriba, mirando a +Z.

| Archivo | Qué guarda |
| --- | --- |
| `manifiesto.json` | Versión, especie y lista de archivos con su `sha256` |
| `cuerpo.glb` | Malla base completa en **pose A**, esqueleto, pesos, color `garment` y formas |
| `articulaciones.json` | Dónde está cada hueso en el cuerpo base y cuánto lo mueve cada forma |
| `deslizadores.csv` | La tabla del paso 2.1 |

Si el formato cambia de forma incompatible, sube `version`.

## `manifiesto.json`

```json
{
  "version": 1,
  "species": "humana",
  "pose": "A",
  "source": "MakeHuman system assets (CC0) con MPFB 2.0.18",
  "vertex_count": 13380,
  "bone_count": 57,
  "files": {"cuerpo.glb": {"sha256": "…"}, "articulaciones.json": {"sha256": "…"}, "deslizadores.csv": {"sha256": "…"}}
}
```

Al cargar, el núcleo comprueba `version` y el `sha256` de cada archivo; si no coinciden, no carga.

## `cuerpo.glb`

- La malla base de MakeHuman sin proxy (13.380 vértices) y con los pies en el suelo.
- 53 huesos humanoides + 4 **huesos de anclaje** sin peso: `socket_hand_r` / `socket_hand_l` (hijos de la mano), `socket_back` (hijo de `UpperChest`) y `socket_hip` (hijo de `Hips`). Al ser huesos, se reajustan como los demás. Al exportar el personaje (paso 3.6) pasan a ser nodos vacíos, como pide `CLAUDE.md`.
- Color por vértice `garment` (ver más abajo).
- Formas (*blend shapes*): `<id>_decr` e `<id>_incr`, con `<id>` del CSV. Si `lados` = 2, hay una por lado: `<id>_incr_l`, `<id>_incr_r`.
  Los deslizadores Proporción y Por crear no tienen formas.

### Formas que suman varios targets

Una forma puede ser la suma de varios targets (`a+b` en el CSV) **solo si van siempre en la misma proporción**,
es decir, si un único deslizador los mueve a la vez y con el mismo peso. Ejemplo: `arm_length` = brazo + antebrazo.
Si algún día hay que moverlos por separado, se guardan como formas distintas.

## Deslizadores Global (macros)

En MakeHuman, sexo, edad, músculo, peso, altura, proporciones, pecho y etnia son **macros**: no son una forma, sino
muchos cuerpos combinados (p. ej. `universal-female-young-maxmuscle-maxweight`). El peso de cada cuerpo es el
producto de lo que aporta cada macro, así que el músculo se ve distinto según el peso o el sexo.

**Cómo se guardan aquí:** cada macro de la tabla son dos formas medidas desde el cuerpo neutro
(todas las macros en su valor por defecto, 0,5):

- `<id>_decr` = cuerpo con esa macro a 0 − cuerpo neutro.
- `<id>_incr` = cuerpo con esa macro a 1 − cuerpo neutro.

**Cómo calcula Godot los pesos** (valor del deslizador `v` de 0 a 1; 0,5 = neutro):

```
peso(<id>_decr) = max(0, 1 − 2·v)
peso(<id>_incr) = max(0, 2·v − 1)
```

- Si solo se mueve **una** macro, el resultado es igual al de MakeHuman, porque entre 0 y 0,5 y entre 0,5 y 1 MakeHuman también mezcla en línea recta.
- Si se mueven **varias**, Godot suma sus formas y MakeHuman usaría su cuerpo combinado: se parecen, pero no son idénticos. El paso 2.4 mide esa diferencia y la informa aparte. La mezcla exacta está en `IDEAS.md`.
- Las macros que no están en la tabla se quedan en su valor por defecto: **edad** 0,5 (adulto joven; el MVP solo hace adultos), **altura** 0,5 (la altura se cambia con la escala del hueso `Root`, que es Proporción), proporciones y etnia.

## `articulaciones.json`

MPFB coloca cada hueso en el centro de unos cubos auxiliares que se borran en el paso 1.3. Las formas mueven esos
cubos siempre igual, así que basta con guardar la posición base y cuánto la mueve cada forma al 100 % (valores de ejemplo):

```json
{
  "bones": {
    "LeftUpperArm": {
      "parent": "LeftShoulder",
      "head": [0.18, 1.39, -0.02],
      "tail": [0.43, 1.18, -0.05],
      "deltas": {"arm_length_incr": {"head": [0, 0, 0], "tail": [0.031, -0.026, 0.0]}}
    }
  }
}
```

- Posición = base + Σ (peso de la forma × su delta). Solo se guardan las formas que mueven ese hueso.
- Los anclajes también se guardan aquí: la mano, entre la muñeca y el nudillo del dedo corazón; la espalda y la cadera, en un vértice fijo de la piel + 2 cm.
- Los deslizadores Proporción se aplican después, escalando el hueso por igual en todas direcciones.

## Pose

Se guarda en **pose A** porque los targets de MakeHuman están hechos sobre ella: si se guardara en pose T, los cambios de largo de los brazos saldrían torcidos.
En el editor, el núcleo gira los brazos a pose T como una pose del esqueleto (en vivo, en la tarjeta gráfica).
En el paso 3.6 se preparan dos salidas para comparar: **pose T horneada** y **pose A con la corrección de silueta del importador de Godot**. Se decide en la Fase 5.

## Prenda base

Es **color por vértice**, no una textura: el atributo `garment` vale 1 en la prenda y 0 en la piel, con un degradado de unos 6 cm (unas 2 aristas).
El shader corta en 0,5, así que en la malla completa el borde sale recto.
En una malla ligera (proxy) las aristas son mucho más largas y el borde saldría dentado: allí haría falta una máscara en textura.

## Malla ligera (proxy): se deja para después

`cuerpo_ligero.glb` (con las mismas formas y nombres) no entra en la versión 1 por estos motivos:

- `CLAUDE.md` pide la malla completa sin proxy, e `IDEAS.md` deja el proxy ligero para después del MVP.
- La prenda pintada por vértice saldría dentada en el proxy (ver arriba).
- Añadirlo después no rompe nada: es un archivo más en `files`.
