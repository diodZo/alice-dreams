class_name ScratchMonster
extends Enemy
## Arañitas: persigue a la protagonista y ataca con un arañazo de corto alcance
## (port de entities/ScratchMonster.js).


func alert_update(time: float) -> void:
	var d := distance_to_player()
	if d.dist <= def.attack_range and time >= attack_ready_at:
		fsm.set_state(ATTACK)
		return
	if time < attack_ready_at - def.attack_cooldown + 300:
		anim("idle")
		return
	if d.dist > def.attack_range - 6 and walk(int(signf(d.dx)), def.speed):
		anim("walk")
	else:
		velocity.x = 0
		face_player()
		anim("idle")


func attack() -> void:
	anim("attack", false)
	telegraph(300)
	after(300, func():
		level.spawn_projectile("enemy", {
			"x": position.x + facing * 14,
			"y": position.y - 11,
			"vx": facing * 70,
			"vy": 0,
			"texture": "fx",
			"frame": "slash",
			"lifespan": 170,
			"body": 14,
			"owner": "enemy",
			"kind": "slash",
			"damage": 1,
		}))
	after(700, func(): fsm.set_state(ALERT))
