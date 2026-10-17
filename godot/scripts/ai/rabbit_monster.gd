class_name RabbitMonster
extends Enemy
## Peluche saltarín: anticipa y encadena hasta dos saltos hacia Alice antes de descansar.

var jumps_left := 0
var airborne_at := 0.0

func alert_update(time: float) -> void:
	var d := distance_to_player()
	if grounded and time >= attack_ready_at and d.dist <= def.attack_range:
		fsm.set_state(ATTACK)
	elif d.dist > 24 and walk(int(signf(d.dx)), def.speed):
		anim("walk")
	else:
		velocity.x = 0
		anim("idle")

func attack() -> void:
	jumps_left = 2
	_prepare_jump()

func _prepare_jump() -> void:
	velocity.x = 0
	Anim.show_frame(sprite, "jump", 0)
	telegraph(320)
	after(320, _jump)

func _jump() -> void:
	face_player()
	jumps_left -= 1
	airborne_at = now
	velocity = Vector2(clampf(player.position.x - position.x, -120, 120) / 0.72, -280)
	anim("jump", false)
	AudioManager.play("bounce")

func _update_ATTACK(_time: float, _delta: float) -> void:
	if grounded and now - airborne_at > 140:
		level.effects.dust(position.x, position.y)
		if jumps_left > 0 and absf(player.position.x - position.x) < def.detect_range:
			_prepare_jump()
		else:
			velocity.x = 0
			anim("idle")
			after(520, func(): fsm.set_state(ALERT))
