class_name SpitMonster
extends Enemy
## Escupitín: mantiene la distancia y escupe gotas de baba esquivables
## (port de entities/SpitMonster.js).


func alert_update(time: float) -> void:
	var d := distance_to_player()
	var near := def.keep_distance.x
	var far := def.keep_distance.y
	var moving := false
	if d.dist < near:
		moving = walk(-int(signf(d.dx)), def.speed)
	elif d.dist > far:
		moving = walk(int(signf(d.dx)), def.speed)
	if moving:
		anim("walk")
		sprite.flip_h = d.dx < 0 # retrocede mirando a la protagonista
	else:
		velocity.x = 0
		face_player()
		anim("idle")
	if time >= attack_ready_at and d.dist < def.detect_range and can_see_player():
		fsm.set_state(ATTACK)


func attack() -> void:
	# aviso: se infla y destella antes de escupir
	Anim.show_frame(sprite, "attack", 0)
	telegraph(550)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(0.92, 1.12), 0.27)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.27)
	after(550, func():
		anim("attack", false)
		face_player()
		level.spawn_projectile("enemy", {
			"x": position.x + facing * 12,
			"y": position.y - 12,
			"vx": facing * 125,
			"vy": -50,
			"gravity": 170,
			"texture": "fx",
			"frame": "spit_blob",
			"lifespan": 2200,
			"body": 7,
			"owner": "enemy",
			"kind": "spit",
			"damage": 1,
			"rotate": true,
		}))
	after(1050, func(): fsm.set_state(ALERT))
