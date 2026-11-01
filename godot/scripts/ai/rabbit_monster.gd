class_name RabbitMonster
extends Enemy
## Peluche saltarín: anticipa y encadena hasta dos saltos hacia Alice antes de descansar.

const HOP_VY := -280.0

var jumps_left := 0
var airborne_at := 0.0
## "prep" (agachado avisando), "air" (en el salto) o "rest" (descanso tras aterrizar).
var hop_state := ""

func alert_update(time: float) -> void:
	var d := distance_to_player()
	if grounded and time >= attack_ready_at and d.dist <= def.attack_range and absf(d.dy) < 48:
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
	hop_state = "prep"
	velocity.x = 0
	Anim.show_frame(sprite, "jump", 0)
	telegraph(400)
	after(400, _jump)

func _jump() -> void:
	face_player()
	jumps_left -= 1
	hop_state = "air"
	airborne_at = now
	var air_time := -2.0 * HOP_VY / C.GRAVITY
	var dx := clampf(player.position.x - position.x, -110, 110)
	# no salta al vacío: acorta el salto hasta que haya suelo donde caer
	for k in [1.0, 0.6, 0.3, 0.0]:
		if level.terrain_solid_at(Vector2(position.x + dx * k, position.y + 4)):
			dx *= k
			break
	velocity = Vector2(dx / air_time, HOP_VY)
	anim("jump", false)
	AudioManager.play("bounce")

func _update_ATTACK(_time: float, _delta: float) -> void:
	if hop_state != "air":
		if grounded:
			velocity.x = 0
		return
	if grounded and now - airborne_at > 140:
		velocity.x = 0
		level.effects.dust(position.x, position.y)
		if jumps_left > 0 and can_see_player():
			_prepare_jump()
		else:
			hop_state = "rest"
			anim("idle")
			after(520, func(): fsm.set_state(ALERT))
