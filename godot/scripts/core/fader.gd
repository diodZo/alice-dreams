extends CanvasLayer
## Fundidos y destellos de pantalla (autoload "Fader").
## Equivale a camera.fadeIn / fadeOut / flash de Phaser. Queda por debajo del HUD
## (capa 8 < 10), igual que en Phaser el fundido de la cámara del nivel no tapaba el HUD.

var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.size = Vector2(C.GAME_W, C.GAME_H)
	_rect.color = Color(0, 0, 0, 0)
	add_child(_rect)


## Oscurece hasta el color indicado. Devuelve la señal de fin (se puede usar con await).
func fade_out(ms: float, color: Color = C.FADE_BLUE) -> Signal:
	return _run(Color(color, _rect.color.a if _rect.color.a > 0 else 0.0), Color(color, 1.0), ms)


## Aparece desde el color indicado (pantalla cubierta -> transparente).
func fade_in(ms: float, color: Color = C.FADE_BLUE) -> Signal:
	return _run(Color(color, 1.0), Color(color, 0.0), ms)


## Destello: el color aparece de golpe y se desvanece.
func flash(ms: float, color: Color) -> Signal:
	return _run(Color(color, 1.0), Color(color, 0.0), ms)


func is_covered() -> bool:
	return _rect.color.a > 0.99


func clear() -> void:
	if _tween:
		_tween.kill()
	_rect.color = Color(0, 0, 0, 0)


func _run(from: Color, to: Color, ms: float) -> Signal:
	if _tween:
		_tween.kill()
	_rect.color = from
	_tween = create_tween()
	_tween.tween_property(_rect, "color", to, maxf(ms, 1.0) / 1000.0)
	return _tween.finished
