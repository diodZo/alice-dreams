class_name PompaMonster
extends Enemy
## Pompa Traviesa: burbuja viviente que flota y se acerca despacio a Alice. Cuando la tiene
## cerca se hincha (aviso claro) y estalla en una ráfaga de burbujitas lentas en abanico;
## después se encoge, se aparta un poco y vuelve a formarse. Nunca deja de flotar.

const BURST := 6

var hover_y := 0.0

func _ready() -> void:
	super()
	gravity_enabled = false
	hover_y = position.y

func _hover(time: float) -> void:
	velocity.y = clampf((hover_y - position.y) * 2.0, -30, 30) + sin(time / 520.0) * 9

func _update_IDLE(time: float, delta: float) -> void:
	super(time, delta)
	_hover(time)

func _update_PATROL(time: float, _delta: float) -> void:
	if can_see_player():
		fsm.set_state(ALERT)
		return
	if position.x <= patrol_min or blocked_left:
		facing = 1
	elif position.x >= patrol_max or blocked_right:
		facing = -1
	sprite.flip_h = facing < 0
	velocity.x = facing * def.speed * 0.5 * speed_factor()
	_hover(time)
	anim("walk")

func alert_update(time: float) -> void:
	var p := player
	var d := distance_to_player()
	# se acerca despacio, un poco por encima de Alice
	var target := Vector2(p.position.x - signf(d.dx) * 30, p.position.y - 34)
	hover_y = move_toward(hover_y, clampf(target.y, spawn.y - 64, spawn.y + 24), 0.6)
	velocity.x = move_toward(velocity.x, signf(target.x - position.x) * def.speed * speed_factor(), 2.0)
	_hover(time)
	face_player()
	anim("walk")
	if time >= attack_ready_at and Vector2(d.dx, d.dy).length() <= def.attack_range + 20:
		fsm.set_state(ATTACK)

func attack() -> void:
	velocity = Vector2.ZERO
	Anim.show_frame(sprite, "attack", 0)
	telegraph(650)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.6).set_trans(Tween.TRANS_SINE)
	after(650, _burst)
	after(1500, func(): fsm.set_state(ALERT))

func _update_ATTACK(time: float, _delta: float) -> void:
	velocity.x = 0
	_hover(time)

func _burst() -> void:
	Anim.show_frame(sprite, "attack", 1)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.12)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.5)
	var c := position + Vector2(0, -def.body_size.y / 2.0)
	var fx := Sprite2D.new()
	fx.texture = Assets.frame("w4_fx", "pompa_burst")
	fx.position = c
	fx.scale = Vector2(0.6, 0.6)
	level.fx_root.add_child(fx)
	var ft := fx.create_tween().set_parallel()
	ft.tween_property(fx, "scale", Vector2(1.0, 1.0), 0.3)
	ft.tween_property(fx, "modulate:a", 0.0, 0.35)
	ft.chain().tween_callback(fx.queue_free)
	for i in BURST:
		# abanico hacia abajo y a los lados: siempre deja huecos para esquivar
		var ang := PI * (0.05 + 0.9 * i / float(BURST - 1))
		var v := Vector2(cos(ang), sin(ang) * 0.8) * 70.0
		level.spawn_projectile("enemy", {"x": c.x, "y": c.y, "vx": v.x, "vy": v.y, "texture": "w4_fx", "frame": "bubble_s",
			"lifespan": 1500, "body": 6, "owner": "enemy", "kind": "pompa_bubble", "damage": 1})
	AudioManager.play("bubble_pop")
	# tras estallar se aparta un poco
	hover_y = position.y - 14

func _exit_TRAPPED(next: String) -> void:
	super(next)
	gravity_enabled = false
	hover_y = position.y
