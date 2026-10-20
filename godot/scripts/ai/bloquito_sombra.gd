class_name BloquitoSombraMonster
extends Enemy
## Bloquito Sombra: bloque de piedra violeta oscura con cara brillante y ojos rosados.
##  1 camina por su plataforma (salta escalones de una tesela; nunca se cae por los bordes),
##  2 al ver a Alice a su altura se detiene, brillan sus ojos (aviso WARN_MS) y levanta una
##    pequeña barrera de sombra: mientras dura (BARRIER_MS) los disparos rebotan en ella,
##  3 embiste en horizontal (CHARGE_MS como mucho; frena en bordes y muros),
##  4 al terminar choca y queda aturdido y SIN barrera (VULNERABLE_MS): el momento de atacar,
##  5 vuelve a vigilar tras attack_cooldown.

const WARN_MS := 650.0
const BARRIER_MS := 1100.0
const CHARGE_MS := 900.0
const VULNERABLE_MS := 1000.0
const CHARGE_SPEED := 175.0
const HOP_VY := -210.0

var charging := false
var barrier_until := 0.0
var barrier: Node2D
var dust_at := 0.0


func anim(anim_name: String, ignore_if_playing := true) -> void:
	if anim_name == "defeated":
		anim_name = "defeat"
	super(anim_name, ignore_if_playing)


func has_barrier() -> bool:
	return now < barrier_until


func _update_PATROL(time: float, delta: float) -> void:
	if can_see_player() and absf(distance_to_player().dy) < 26:
		fsm.set_state(ALERT)
		return
	# escalón de una tesela delante: lo salta
	if grounded and ((facing < 0 and blocked_left) or (facing > 0 and blocked_right)) and _step_free(facing):
		velocity = Vector2(facing * def.speed, HOP_VY)
		Anim.show_frame(sprite, "jump", 0)
		return
	if not grounded:
		Anim.show_frame(sprite, "jump", 1 if velocity.y > 0 else 0)
		return
	super(time, delta)


## ¿Hay hueco libre justo encima del escalón de delante?
func _step_free(dir: int) -> bool:
	var ahead := position + Vector2(dir * (def.body_size.x / 2.0 + 6.0), -C.TILE - 4.0)
	return not level.terrain_solid_at(ahead) and not level.terrain_solid_at(ahead + Vector2(0, -C.TILE))


func alert_update(time: float) -> void:
	var d := distance_to_player()
	face_player()
	if grounded and time >= attack_ready_at and d.dist <= def.attack_range and absf(d.dy) < 26:
		fsm.set_state(ATTACK)
		return
	if d.dist > 40 and walk(int(signf(d.dx)), def.speed * 0.6):
		anim("walk")
	else:
		velocity.x = 0
		anim("idle")


func attack() -> void:
	charging = false
	face_player()
	Anim.show_frame(sprite, "charge", 0)
	telegraph(WARN_MS)
	_raise_barrier()
	after(WARN_MS, func():
		face_player()
		charging = true
		anim("charge", false)
		AudioManager.play("shadow_charge"))
	after(WARN_MS + CHARGE_MS, _stop_charge)
	after(WARN_MS + CHARGE_MS + VULNERABLE_MS, func(): fsm.set_state(ALERT))


func _raise_barrier() -> void:
	barrier_until = now + BARRIER_MS
	_drop_barrier()
	barrier = Node2D.new()
	barrier.position = Vector2(0, -def.body_size.y / 2.0)
	add_child(barrier)
	var glow := Sprite2D.new()
	glow.texture = Assets.generated("glow")
	glow.modulate = Color(C.rgb(0x713ca8), 0.55)
	glow.scale = Vector2(1.6, 1.6)
	barrier.add_child(glow)
	for i in 3:
		var w := Sprite2D.new()
		w.texture = Assets.frame("w8_fx", "shadow_wisp")
		w.scale = Vector2(0.6, 0.6)
		w.position = Vector2(cos(TAU * i / 3.0), sin(TAU * i / 3.0)) * 14.0
		barrier.add_child(w)
	var tw := barrier.create_tween().set_loops()
	tw.tween_property(barrier, "rotation", TAU, 0.9).from(0.0)
	var ref: WeakRef = weakref(barrier)
	after(BARRIER_MS, func():
		var b: Node2D = ref.get_ref()
		if b != null:
			level.effects.poof(b.global_position.x, b.global_position.y, 5)
			b.queue_free())


func _drop_barrier() -> void:
	if barrier != null and is_instance_valid(barrier):
		barrier.queue_free()
	barrier = null


func _stop_charge() -> void:
	if not charging:
		return
	charging = false
	velocity.x = 0
	barrier_until = 0
	_drop_barrier()
	Anim.show_frame(sprite, "attack", 0)
	level.camera.shake(80, 0.002)
	level.effects.poof(position.x + facing * 10, position.y - 6, 6)
	for i in 3:
		_rock(i)


func _rock(i: int) -> void:
	var r := Sprite2D.new()
	r.texture = Assets.frame("w8_fx", "rock_bit")
	r.scale = Vector2(0.6, 0.6)
	r.position = position + Vector2(facing * 10, -8)
	level.fx_root.add_child(r)
	var to := r.position + Vector2(facing * (6 + i * 7), -10 + i * 6)
	var tw := r.create_tween().set_parallel()
	tw.tween_property(r, "position", to, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(r.queue_free)


func _update_ATTACK(time: float, _delta: float) -> void:
	if not charging:
		velocity.x = 0
		return
	if not ground_ahead(facing) or (facing < 0 and blocked_left) or (facing > 0 and blocked_right) or fsm.elapsed > WARN_MS + CHARGE_MS:
		_stop_charge()
		return
	velocity.x = facing * CHARGE_SPEED * speed_factor()
	if time >= dust_at:
		dust_at = time + 90
		level.effects.poof(position.x - facing * 10, position.y - 3, 2)


func _exit_ATTACK(next: String) -> void:
	super(next)
	charging = false
	barrier_until = 0
	_drop_barrier()


## La barrera de sombra detiene los disparos (y la burbuja) mientras dura.
func hit_by(projectile: Projectile) -> bool:
	if is_alive() and has_barrier() and not is_trapped():
		level.effects.sparkle(projectile.position.x, projectile.position.y, 4)
		AudioManager.play("boss_hit")
		return true
	return super(projectile)


func stomp() -> void:
	if has_barrier():
		return
	super()


## Derrota: se desmorona en piedrecitas y su sombra se va.
func _enter_DEFEATED(prev: String, data: Variant) -> void:
	_drop_barrier()
	super(prev, data)
	if data is Dictionary and data.get("toStar", false):
		return
	for i in 4:
		_rock(i)
	var puff := Sprite2D.new()
	puff.texture = Assets.frame("w8_fx", "shadow_puff")
	puff.position = position + Vector2(0, -10)
	level.fx_root.add_child(puff)
	var tw := puff.create_tween().set_parallel()
	tw.tween_property(puff, "position:y", puff.position.y - 16, 0.9)
	tw.tween_property(puff, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(puff.queue_free)
