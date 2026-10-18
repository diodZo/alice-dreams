class_name MeteoritoMonster
extends Enemy
## Meteorito Travieso: roca simpática que rueda por el suelo de su isla. En las pendientes rueda
## cuesta abajo más deprisa. Cuando ve a Alice a su altura tiembla (aviso) y hace una embestida
## en línea recta que se detiene en los bordes y contra los muros. Al ser derrotado se parte en
## fragmentos pequeños (sólo efecto visual).

const CHARGE_SPEED := 170.0
const CHARGE_MS := 900.0
const WARN_MS := 560.0

var charging := false
var trail_at := 0.0

## ¿Está sobre una pendiente? Devuelve el sentido cuesta abajo (0 en llano).
func downhill() -> int:
	if not grounded:
		return 0
	var n := get_floor_normal()
	return int(signf(n.x)) if absf(n.x) > 0.2 else 0

## En las bajadas (rampas, escalones de una tesela) también hay suelo delante; en un borde real no.
func ground_ahead(dir: int) -> bool:
	return super(dir) or level.terrain_solid_at(Vector2(position.x + dir * (def.body_size.x / 2.0 + 4.0), position.y + 4.0 + C.TILE))

func _update_PATROL(_time: float, _delta: float) -> void:
	if can_see_player() and absf(distance_to_player().dy) < 28:
		fsm.set_state(ALERT)
		return
	var slope := downhill()
	if slope != 0:
		facing = slope
	elif position.x <= patrol_min:
		facing = 1
	elif position.x >= patrol_max:
		facing = -1
	if not walk(facing, def.speed * (1.8 if slope != 0 else 0.7)):
		facing *= -1
		fsm.set_state(IDLE)
	anim("walk")

func alert_update(time: float) -> void:
	var d := distance_to_player()
	face_player()
	if grounded and time >= attack_ready_at and d.dist <= def.attack_range and absf(d.dy) < 28:
		fsm.set_state(ATTACK)
		return
	# se acerca rodando despacio sin caerse de su isla
	if d.dist > 40 and walk(int(signf(d.dx)), def.speed * 0.6):
		anim("walk")
	else:
		velocity.x = 0
		anim("idle")

func attack() -> void:
	charging = false
	Anim.show_frame(sprite, "attack", 0)
	telegraph(WARN_MS)
	var tw := sprite.create_tween().set_loops(5)
	tw.tween_property(sprite, "position:x", 1.5, 0.05)
	tw.tween_property(sprite, "position:x", -1.5, 0.05)
	after(WARN_MS, func():
		sprite.position.x = 0
		face_player()
		charging = true
		anim("attack", false)
		AudioManager.play("rocket"))
	after(WARN_MS + CHARGE_MS, _stop_charge)
	after(WARN_MS + CHARGE_MS + 500, func(): fsm.set_state(ALERT))

func _stop_charge() -> void:
	charging = false
	velocity.x = 0
	anim("idle")

func _update_ATTACK(time: float, _delta: float) -> void:
	if not charging:
		if grounded:
			velocity.x = 0
		return
	if not ground_ahead(facing) or (facing < 0 and blocked_left) or (facing > 0 and blocked_right):
		_stop_charge()
		level.effects.poof(position.x + facing * 10, position.y - 6, 5)
		return
	velocity.x = facing * CHARGE_SPEED * speed_factor()
	if time >= trail_at:
		trail_at = time + 60
		level.effects.sparkle(position.x - facing * 10, position.y - 10, 2)

func _exit_ATTACK(next: String) -> void:
	super(next)
	charging = false
	sprite.position.x = 0

func _enter_DEFEATED(prev: String, data: Variant) -> void:
	super(prev, data)
	if data is Dictionary and data.get("toStar", false):
		return
	# fragmentos pequeños que saltan y se desvanecen
	for i in 5:
		var f := Sprite2D.new()
		f.texture = Assets.frame("w5_fx", "pebble")
		f.position = position + Vector2(randf_range(-6, 6), -10)
		f.scale = Vector2.ONE * randf_range(0.5, 1.0)
		level.fx_root.add_child(f)
		var to := f.position + Vector2(randf_range(-26, 26), randf_range(-18, 4))
		var tw := f.create_tween().set_parallel()
		tw.tween_property(f, "position", to, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(f, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(f.queue_free)
