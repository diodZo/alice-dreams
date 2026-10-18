class_name WoolMonster
extends Enemy
## Ovillo viviente: acelera, embiste y queda aturdido brevemente al chocar.
## Las animaciones de la hoja ya ruedan: el cuerpo no se gira (la hitbox sigue recta).

var charging := false
var dust_at := 0.0

func alert_update(time: float) -> void:
	var d := distance_to_player()
	if grounded and time >= attack_ready_at and d.dist <= def.attack_range and absf(d.dy) < 32:
		fsm.set_state(ATTACK)
	elif walk(int(signf(d.dx)), def.speed * 1.2):
		anim("walk")
	else:
		velocity.x = 0
		anim("idle")

func attack() -> void:
	charging = false
	Anim.show_frame(sprite, "attack", 0)
	telegraph(420)
	after(420, func():
		face_player()
		if not ground_ahead(facing):
			_recover()
			return
		charging = true
		velocity.x = facing * 185 * speed_factor()
		anim("attack", false)
		AudioManager.play("wind"))
	after(1050, _recover)

func _update_ATTACK(_time: float, _delta: float) -> void:
	if not charging:
		if grounded:
			velocity.x = 0
		return
	if now >= dust_at:
		dust_at = now + 90
		level.effects.dust(position.x, position.y)
	if blocked_left or blocked_right or not ground_ahead(facing):
		velocity.x = 0
		level.camera.shake(100, 0.002)
		_recover()

func _recover() -> void:
	if not fsm.is_state(ATTACK):
		return
	charging = false
	velocity.x = 0
	anim("hurt", false)
	clear_timers()
	apply_tint()
	after(520, func(): fsm.set_state(ALERT))
