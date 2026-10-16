class_name BrushMonster
extends Enemy
## Pincel travieso (Mundo 2): mantiene la distancia, se reposiciona si la protagonista se acerca
## y dispara pintura rosa alternando disparos sueltos y pequeñas ráfagas de tres.

var shots := 0


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
		sprite.flip_h = d.dx < 0 # se aparta mirando a la protagonista
	else:
		velocity.x = 0
		face_player()
		anim("idle")
	if time >= attack_ready_at and d.dist < def.detect_range and can_see_player():
		fsm.set_state(ATTACK)


func attack() -> void:
	Anim.show_frame(sprite, "attack", 0)
	telegraph(450)
	var burst := shots % 3 == 2
	shots += 1
	var count := 3 if burst else 1
	for i in count:
		after(450 + i * 170, func():
			anim("attack", false)
			face_player()
			_shoot(i))
	after(450 + count * 170 + 450, func(): fsm.set_state(ALERT))


func _shoot(i: int) -> void:
	AudioManager.play("shoot_paint")
	level.spawn_projectile("enemy", {
		"x": position.x + facing * 12, "y": position.y - 14,
		"vx": facing * (125 + i * 12), "vy": -55 - i * 18, "gravity": 190,
		"texture": "w2_fx", "frame": "paint_blob", "lifespan": 2200, "body": 8,
		"owner": "enemy", "kind": "brushpaint", "damage": 1, "rotate": true,
	})
