class_name EraserMonster
extends Enemy
## Borrador saltarín (Mundo 2): patrulla, se agacha como aviso, salta hacia la protagonista y
## al caer embiste con un deslizamiento corto. Al aterrizar puede borrar un rato los puentes
## de reglas dibujados que tenga cerca.

const JUMP_VY := -300.0
const MAX_JUMP_DX := 150.0
const DASH_SPEED := 170.0
const ERASE_MS := 3200.0

var phase := ""
var leap_at := 0.0


func alert_update(time: float) -> void:
	var d := distance_to_player()
	if d.dist <= def.attack_range and time >= attack_ready_at and grounded:
		fsm.set_state(ATTACK)
		return
	if d.dist > 28 and walk(int(signf(d.dx)), def.speed):
		anim("walk")
	else:
		velocity.x = 0
		face_player()
		anim("idle")


func attack() -> void:
	# anticipación: se aplasta y destella antes de saltar
	phase = "windup"
	Anim.show_frame(sprite, "jump", 0)
	telegraph(450)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.2, 0.72), 0.2)
	tw.tween_interval(0.2)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.05)
	after(450, _leap)


func _leap() -> void:
	face_player()
	phase = "air"
	leap_at = now
	var airtime := 2.0 * absf(JUMP_VY) / C.GRAVITY
	var dx := clampf(player.position.x - position.x, -MAX_JUMP_DX, MAX_JUMP_DX)
	velocity = Vector2(dx / airtime, JUMP_VY)
	anim("jump", false)
	AudioManager.play("bounce")


func _update_ATTACK(_time: float, _delta: float) -> void:
	match phase:
		"windup", "recover":
			if grounded:
				velocity.x = 0
		"air":
			if grounded and now - leap_at > 150:
				_land()
		"dash":
			if not ground_ahead(facing) or (facing < 0 and blocked_left) or (facing > 0 and blocked_right):
				velocity.x = 0


func _land() -> void:
	phase = "dash"
	level.effects.dust(position.x, position.y)
	_erase_bridges()
	anim("attack", false)
	velocity.x = facing * DASH_SPEED
	after(260, func():
		phase = "recover"
		velocity.x = 0
		anim("idle"))
	after(700, func(): fsm.set_state(ALERT))


## Borra los puentes dibujados cercanos (no el que tiene bajo los pies).
func _erase_bridges() -> void:
	for rb in level.level_objects.get("rulers", []):
		if not is_instance_valid(rb) or not rb.drawn or not rb.solid:
			continue
		var under: bool = rb.covers_x(position.x) and absf(rb.surface_y_at(position.x) - position.y) < 6
		if under:
			continue
		var near: bool = absf(rb.points[0].x - position.x) < 72 or absf(rb.points[-1].x - position.x) < 72
		if near and absf(rb.points[0].y - position.y) < 40:
			rb.erase_temporarily(ERASE_MS)
			var fx := Sprite2D.new()
			fx.texture = Assets.frame("w2_fx", "eraser_dust")
			fx.position = Vector2(position.x + facing * 14, position.y - 8)
			level.fx_root.add_child(fx)
			var tw := fx.create_tween().set_parallel()
			tw.tween_property(fx, "modulate:a", 0.0, 0.5)
			tw.tween_property(fx, "scale", Vector2(1.6, 1.6), 0.5)
			tw.chain().tween_callback(fx.queue_free)
