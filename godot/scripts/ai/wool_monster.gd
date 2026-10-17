class_name WoolMonster
extends Enemy
## Ovillo viviente: acelera, embiste y queda aturdido brevemente al chocar.

var charging := false

func alert_update(time: float) -> void:
	var d := distance_to_player()
	if grounded and time >= attack_ready_at and d.dist <= def.attack_range:
		fsm.set_state(ATTACK)
	elif walk(int(signf(d.dx)), def.speed * 1.35):
		anim("walk")
		rotation += velocity.x * 0.0008
	else:
		velocity.x = 0

func attack() -> void:
	charging = false
	Anim.show_frame(sprite, "attack", 0)
	telegraph(420)
	after(420, func():
		face_player()
		charging = true
		velocity.x = facing * 185
		anim("attack", false)
		AudioManager.play("wind"))
	after(1050, _recover)

func _update_ATTACK(_time: float, _delta: float) -> void:
	if charging:
		rotation += velocity.x * 0.0012
		level.effects.dust(position.x, position.y)
		if blocked_left or blocked_right or not ground_ahead(facing):
			level.camera.shake(100, 0.002)
			_recover()

func _recover() -> void:
	if not charging:
		return
	charging = false
	velocity.x = 0
	anim("hurt", false)
	after(520, func(): fsm.set_state(ALERT))
