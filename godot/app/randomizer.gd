extends RefCounted
# Paso PL.5: cuerpo al azar (botón «Aleatorio» de la galería y de «Nuevo personaje»). Cada deslizador Forma o Proporción
# del cuerpo toma un valor entre LOW y HIGH, igual en los dos lados; Complexión, la cara y el alisado se quedan como
# están, así se respeta la plantilla de partida (femenina o masculina).
# Uso: editor.load_values(Randomizer.values(editor.values, species.sliders, rng))

const LOW := 0.2
const HIGH := 0.8
const KEEP_ZONES := ["Cara", "Base"]
const KEEP := ["gender"]


static func values(current: Dictionary, sliders: Array, rng: RandomNumberGenerator) -> Dictionary:
	var result := current.duplicate()
	for row: Dictionary in sliders:
		if not row["tipo"] in ["Forma", "Proporción"] or row["zona"] in KEEP_ZONES or row["id"] in KEEP:
			continue
		var value := rng.randf_range(LOW, HIGH)
		for side: String in (["_l", "_r"] if row["lados"] == "2" else [""]):
			result[row["id"] + side] = value
	return result
