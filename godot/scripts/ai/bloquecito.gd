class_name BloquecitoMonster
extends Enemy
## Bloquecito Travieso: cubo de juguete que patrulla plataformas y pasarelas (se para en los
## bordes). Al ver a Alice a su altura:
##  1 se detiene, 2 cambia de expresión (fotograma de carga), 3 retrocede un poco (aviso),
##  4 embiste en horizontal dejando polvo, 5 se recupera (mareíto) y vuelve a vigilar.
## La embestida también frena en los bordes y contra los muros: nunca se cae.
## Puede ir en grupo (cada uno con su propia patrulla).

const BACK_MS := 450.0
const CHARGE_MS := 850.0
const RECOVER_MS := 600.0
const CHARGE_SPEED := 185.0

var charging := false
var dust_at := 0.0


func _update_PATROL(time: float, delta: float) -> void:
	if can_see_player() and absf(distance_to_player().dy) < 26:
		fsm.set_state(ALERT)
		return
	super(time, delta)


func alert_update(time: float) -> void:
	var d := distance_to_player()
	face_player()
	if grounded and time >= attack_ready_at and d.dist <= def.attack_range and absf(d.dy) < 26:
		fsm.set_state(ATTACK)
		return
	if d.dist > 44 and walk(int(signf(d.dx)), def.speed * 0.5):
		anim("walk")
	else:
		velocity.x = 0
		anim("idle")


func attack() -> void:
	charging = false
	face_player()
	Anim.show_frame(sprite, "attack", 0)
	telegraph(BACK_MS)
	after(BACK_MS, func():
		face_player()
		charging = true
		anim("attack", false)
		AudioManager.play("block_dash"))
	after(BACK_MS + CHARGE_MS, _stop_charge)
	after(BACK_MS + CHARGE_MS + RECOVER_MS, func(): fsm.set_state(ALERT))


func _stop_charge() -> void:
	if not charging:
		return
	charging = false
	velocity.x = 0
	Anim.show_frame(sprite, "hurt", 1)
	level.effects.poof(position.x + facing * 10, position.y - 6, 5)


func _update_ATTACK(time: float, _delta: float) -> void:
	if not charging:
		# retrocede un poquito antes de embestir (sin salirse de su plataforma)
		if fsm.elapsed < BACK_MS and ground_ahead(-facing) and not (blocked_left if facing > 0 else blocked_right):
			velocity.x = -facing * 22.0
		else:
			velocity.x = 0
		return
	if not ground_ahead(facing) or (facing < 0 and blocked_left) or (facing > 0 and blocked_right):
		_stop_charge()
		return
	velocity.x = facing * CHARGE_SPEED * speed_factor()
	if time >= dust_at:
		dust_at = time + 90
		_dust()


func _dust() -> void:
	var p := Sprite2D.new()
	p.texture = Assets.frame("w6_fx", "dust_s")
	p.position = position + Vector2(-facing * 10, -4)
	level.fx_root.add_child(p)
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "position:x", p.position.x - facing * 8, 0.35)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(p.queue_free)


func _exit_ATTACK(next: String) -> void:
	super(next)
	charging = false


## Derrota infantil: ojos en cruz y se desmonta en piezas de colores que rebotan.
func _enter_DEFEATED(prev: String, data: Variant) -> void:
	super(prev, data)
	if data is Dictionary and data.get("toStar", false):
		return
	for i in 4:
		var f := Sprite2D.new()
		f.texture = Assets.frame("w6_fx", ["cube_red", "cube_green", "cube_blue", "cube_orange"][i])
		f.position = position + Vector2(randf_range(-6, 6), -10)
		level.fx_root.add_child(f)
		var to := f.position + Vector2((i - 1.5) * 12, randf_range(-14, 2))
		var tw := f.create_tween().set_parallel()
		tw.tween_property(f, "position", to, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(f, "modulate:a", 0.0, 0.7)
		tw.chain().tween_callback(f.queue_free)
