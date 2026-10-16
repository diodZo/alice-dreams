class_name FleaMonster
extends Enemy
## Pulgoso: retrocede si la protagonista se acerca y lanza pulgas en parábola
## (port de entities/FleaMonster.js).

const FLEA_GRAVITY := 520.0
const FLIGHT_TIME := 0.95


func alert_update(time: float) -> void:
	var d := distance_to_player()
	if d.dist < def.retreat_distance and walk(-int(signf(d.dx)), def.speed):
		anim("walk")
		sprite.flip_h = d.dx < 0
	else:
		velocity.x = 0
		face_player()
		anim("idle")
	if time >= attack_ready_at and can_see_player():
		fsm.set_state(ATTACK)


func attack() -> void:
	Anim.show_frame(sprite, "attack", 0)
	telegraph(500)
	after(500, func():
		anim("attack", false)
		face_player()
		var sx := position.x + facing * 10
		var sy := position.y - 16
		var p := player
		# trayectoria parabólica hacia donde está la protagonista (alcance limitado)
		var dx := clampf(p.position.x - sx, -190, 190)
		var dy := p.position.y - 12 - sy
		var t := FLIGHT_TIME
		level.spawn_projectile("enemy", {
			"x": sx,
			"y": sy,
			"vx": dx / t,
			"vy": (dy - 0.5 * FLEA_GRAVITY * t * t) / t,
			"gravity": FLEA_GRAVITY,
			"texture": "fx",
			"frame": "flea_bug",
			"lifespan": 2600,
			"body": 8,
			"owner": "enemy",
			"kind": "flea",
			"damage": 1,
			"bounces": 1,
			"bounce_velocity": 150,
		}))
	after(950, func(): fsm.set_state(ALERT))
