class_name CrayonMonster
extends Enemy
## Crayón guerrero (Mundo 2): camina por las plataformas, detecta a la protagonista, prepara una
## embestida (carga con aviso), ataca con un golpe corto y se recupera antes de repetir.

const DASH_SPEED := 210.0

var phase := ""


func alert_update(time: float) -> void:
	var d := distance_to_player()
	if d.dist <= def.attack_range and time >= attack_ready_at:
		fsm.set_state(ATTACK)
		return
	if time < attack_ready_at - def.attack_cooldown + 400:
		anim("idle")
		return
	if d.dist > 20 and walk(int(signf(d.dx)), def.speed):
		anim("walk")
	else:
		velocity.x = 0
		face_player()
		anim("idle")


func attack() -> void:
	phase = "charge"
	anim("charge", false)
	telegraph(520)
	level.effects.dust(position.x - facing * 8, position.y)
	after(520, _dash)


func _dash() -> void:
	face_player()
	phase = "dash"
	anim("attack", false)
	velocity.x = facing * DASH_SPEED
	AudioManager.play("shoot_sling")
	level.spawn_projectile("enemy", {
		"x": position.x + facing * 14, "y": position.y - 14, "vx": facing * DASH_SPEED, "vy": 0,
		"texture": "w2_fx", "frame": "crayon_trail", "lifespan": 300, "body": 14,
		"owner": "enemy", "kind": "slash", "damage": 1,
	})
	after(320, func():
		phase = "recover"
		velocity.x = 0
		anim("idle"))
	after(900, func(): fsm.set_state(ALERT))


func _update_ATTACK(_time: float, _delta: float) -> void:
	if phase == "dash":
		if not ground_ahead(facing) or (facing < 0 and blocked_left) or (facing > 0 and blocked_right):
			velocity.x = 0
	elif grounded:
		velocity.x = 0
