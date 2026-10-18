class_name SpongeCrabMonster
extends Enemy
## Cangrejito Esponja: vigila su plataforma. Al ver a Alice avanza a pasitos (anda, espera,
## anda) y, ya cerca, levanta la pinza como aviso y da un pinzazo corto con estela de espuma.

const STEP_MS := 650.0
const WAIT_MS := 450.0

var step_until := 0.0
var wait_until := 0.0

func alert_update(time: float) -> void:
	var d := distance_to_player()
	if grounded and time >= attack_ready_at and d.dist <= def.attack_range and absf(d.dy) < 30:
		fsm.set_state(ATTACK)
		return
	# avanza a pasitos: un tramo andando y una pausa vigilando
	if time < wait_until:
		velocity.x = 0
		face_player()
		anim("idle")
		return
	if step_until <= time:
		if step_until > 0:
			wait_until = time + WAIT_MS
			step_until = 0
			return
		step_until = time + STEP_MS
	if d.dist > 14 and walk(int(signf(d.dx)), def.speed):
		anim("walk")
	else:
		velocity.x = 0
		anim("idle")

func attack() -> void:
	step_until = 0
	wait_until = 0
	Anim.show_frame(sprite, "attack", 0)
	telegraph(380)
	after(380, func():
		face_player()
		Anim.show_frame(sprite, "attack", 1)
		if ground_ahead(facing):
			velocity.x = facing * 115 * speed_factor()
		level.spawn_projectile("enemy", {"x": position.x + facing * 16, "y": position.y - 10, "vx": facing * 70, "vy": 0,
			"texture": "w4_fx", "frame": "crab_splash", "lifespan": 260, "body": 12, "owner": "enemy", "kind": "foam", "damage": 1, "scale": 0.7})
		AudioManager.play("shoot_paint"))
	after(560, func(): velocity.x = 0)
	after(900, func(): fsm.set_state(ALERT))

func _update_ATTACK(_time: float, _delta: float) -> void:
	if velocity.x != 0 and (not ground_ahead(facing) or blocked_left or blocked_right):
		velocity.x = 0
