class_name CameraRig
extends Camera2D
## Cámara del nivel (port del seguimiento de cámara de Phaser 3 usado en LevelScene):
##  - seguimiento con zona muerta de 40x60 centrada en la cámara y suavizado lerp 0,12;
##  - anticipación horizontal (lookAhead) hacia donde mira la protagonista;
##  - desplazamiento vertical controlado (offset de 16 px y zona muerta alta);
##  - límites del escenario y posiciones redondeadas (píxeles nítidos);
##  - sacudidas (shake) con la misma fórmula que Phaser.

var target: Node2D
var lerp_factor := 0.12
var deadzone := Vector2(40, 60)
## followOffset de Phaser: se resta a la posición del objetivo.
var follow_offset := Vector2(0, 16)
var bounds := Rect2()
## Esquina superior izquierda de la vista (scrollX/scrollY de Phaser).
var scroll := Vector2.ZERO
var mid_point := Vector2.ZERO

var _shake_left := 0.0
var _shake_intensity := 0.0


func _ready() -> void:
	anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	position_smoothing_enabled = false
	ignore_rotation = true
	enabled = true


func setup(follow_target: Node2D, world_bounds: Rect2, tuning: Dictionary) -> void:
	target = follow_target
	bounds = world_bounds
	lerp_factor = tuning.get("lerp", 0.12)
	var dz: Dictionary = tuning.get("deadzone", {"width": 40, "height": 60})
	deadzone = Vector2(dz.width, dz.height)
	snap_to_target()


## startFollow: centra la cámara en el objetivo de inmediato.
func snap_to_target() -> void:
	if target == null:
		return
	var f := target.position - follow_offset
	scroll = _clamp(f - Vector2(C.GAME_W, C.GAME_H) / 2.0)
	mid_point = scroll + Vector2(C.GAME_W, C.GAME_H) / 2.0
	_apply()


## Un paso de seguimiento (Camera.preRender de Phaser). Llamar tras mover a la protagonista.
func update_follow(delta_ms: float) -> void:
	if target != null and is_instance_valid(target):
		var f := target.position - follow_offset
		var dz := Rect2(mid_point - deadzone / 2.0, deadzone)
		var s := scroll
		if f.x < dz.position.x:
			s.x = lerpf(s.x, s.x - (dz.position.x - f.x), lerp_factor)
		elif f.x > dz.end.x:
			s.x = lerpf(s.x, s.x + (f.x - dz.end.x), lerp_factor)
		if f.y < dz.position.y:
			s.y = lerpf(s.y, s.y - (dz.position.y - f.y), lerp_factor)
		elif f.y > dz.end.y:
			s.y = lerpf(s.y, s.y + (f.y - dz.end.y), lerp_factor)
		scroll = _clamp(s)
	mid_point = scroll + Vector2(C.GAME_W, C.GAME_H) / 2.0
	if _shake_left > 0:
		_shake_left -= delta_ms
		var ix := _shake_intensity * C.GAME_W
		var iy := _shake_intensity * C.GAME_H
		offset = Vector2(round(randf() * ix * 2.0 - ix), round(randf() * iy * 2.0 - iy))
		if _shake_left <= 0:
			offset = Vector2.ZERO
	_apply()


func _clamp(s: Vector2) -> Vector2:
	var out := s
	var w := bounds.size.x - C.GAME_W
	var h := bounds.size.y - C.GAME_H
	out.x = bounds.position.x + w / 2.0 if w < 0 else clampf(s.x, bounds.position.x, bounds.position.x + w)
	out.y = bounds.position.y + h / 2.0 if h < 0 else clampf(s.y, bounds.position.y, bounds.position.y + h)
	return out


func _apply() -> void:
	position = scroll.round()


## shake(duración ms, intensidad) como camera.shake de Phaser (fracción del tamaño de la vista).
func shake(ms: float, intensity: float) -> void:
	if _shake_left > 0 and _shake_intensity > intensity:
		return
	_shake_left = ms
	_shake_intensity = intensity


## Esquina superior izquierda visible, redondeada (cam.scrollX/scrollY).
func view_rect() -> Rect2:
	return Rect2(scroll.round(), Vector2(C.GAME_W, C.GAME_H))
