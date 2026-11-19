extends RefCounted
# Paso IU.10c: fundido corto al aparecer un panel (guía §3 «Movimiento»); con «Reducir animaciones», de golpe.
# Lee el ajuste en cada fundido: el diálogo de Ajustes vale al momento. Plegar es de golpe (visible = false).
# Uso: Motion.fade_in(panel)  # devuelve el Tween, o null si fue de golpe

const SettingsFile := preload("settings_file.gd")
const FADE := 0.18  # s, guía §3 «Movimiento»


## Hace visible el control con un fundido; con «Reducir animaciones», de golpe. Devuelve el Tween o null.
static func fade_in(control: CanvasItem) -> Tween:
	control.visible = true
	if SettingsFile.get_reduce_motion():
		control.modulate.a = 1.0
		return null
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, FADE).set_ease(Tween.EASE_OUT)
	return tween
