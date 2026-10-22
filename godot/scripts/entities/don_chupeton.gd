class_name DonChupeton
extends BossBase
## Don Chupetón, jefe del Mundo 7: monstruo gigante de pastel y crema con una fresa encima,
## piruletas, galletas y caramelos. Recorre el suelo del Castillo del Gran Pastel. Misma interfaz
## que los jefes anteriores (setup, intro, hit_by, fsm, hp, max_hp, defeated_at, is_defeated...).
## Cada ataque tiene anticipación ("!", destello y pose previa) y termina en un descanso
## vulnerable (REST). Nada es inevitable: los caramelos van lentos y con huecos, la piruleta y los
## remolinos ruedan por el suelo (se saltan), el glaseado marca antes dónde cae y el giro se
## esquiva subiendo a las nubes de crema.
##  1 Lluvia de caramelos (100-65 %): caramelos pequeños, piruleta horizontal, avance lento.
##  2 Tormenta de glaseado (65-30 %): chorros de glaseado, caramelos en abanico, remolinos de
##    piruletas y más movilidad.
##  3 El gran remolino dulce (30-0 %): giro de caramelo multicolor, ráfagas de glaseado a los dos
##    lados, proyectiles múltiples y combinaciones.

const MAX_HP := 65
const BLOB_GRAVITY := 520.0
const BLOB_FLIGHT := 1.05
const PHASES := {
	1: {"speed": 26.0, "interval": 1600.0, "rest": 1700.0, "turn": 0.0, "pattern": ["CANDY_SHOT", "LOLLIPOP", "CANDY_SHOT", "LOLLIPOP"]},
	2: {"speed": 40.0, "interval": 1300.0, "rest": 1450.0, "turn": 1200.0, "pattern": ["FROSTING_JET", "CANDY_FAN", "SWIRLS", "FROSTING_JET", "CANDY_FAN"]},
	3: {"speed": 50.0, "interval": 1150.0, "rest": 1500.0, "turn": 950.0, "pattern": ["SPIN", "FROSTING_BURST", "MULTI", "COMBO", "SPIN"]},
}
const WRAPPED := ["wrapped_pink", "wrapped_orange", "wrapped_blue"]

var turn_at := 0.0
var trail_at := 0.0
var combo := false
var drop_at := 0.0


func setup(owner_level: Node, boss_cfg: Dictionary) -> void:
	level = owner_level
	cfg = boss_cfg
	min_x = float(cfg.minX) * C.TILE + 48
	max_x = float(cfg.maxX) * C.TILE - 48
	floor_y = float(cfg.floorY)
	position = Vector2(max_x + 200, floor_y)


func _ready() -> void:
	z_index = C.Z_ENEMY + 2
	collision_layer = C.L_BOSS
	collision_mask = 0
	monitoring = false
	set_meta("kind", "boss")
	set_meta("entity", self)
	sprite.sprite_frames = Assets.sprite_frames("don_chupeton")
	Anim.set_origin(sprite, Assets.cell_size("don_chupeton"), 0.5, 1.0)
	flash = ShaderMaterial.new()
	flash.shader = preload("res://resources/effects/flash.gdshader")
	sprite.material = flash
	fsm = StateMachine.new(self)
	set_body_enabled(false)


func anim(anim_name: String, ignore := true) -> void: Anim.play(sprite, anim_name, ignore)
## El dibujo mira a la derecha; flip_h = mira a la izquierda.
func face(d: int) -> void:
	dir = d
	sprite.flip_h = d < 0
func face_player() -> void: face(-1 if player.position.x < position.x else 1)
## Boca (salida de caramelos y glaseado).
func mouth() -> Vector2: return position + Vector2(facing() * 34, -28)


func _physics_process(delta: float) -> void:
	if level == null: return
	timers.process(now)
	if fsm.current != "": fsm.update(now, delta * 1000.0)
	if body_enabled and fsm.current != "INTRO" and not is_defeated():
		position.x = clampf(position.x + velocity.x * delta, min_x, max_x)
		if absf(velocity.x) > 120 and now >= trail_at:
			trail_at = now + 80
			level.effects.sparkle(position.x - facing() * 30, position.y - 16, 3)


func _enter_INTRO(_p: String, _d: Variant) -> void:
	face(-1)
	anim("move")
	AudioManager.play("boss_appear")
	var home := float(cfg.homeX) * C.TILE
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "position:x", home, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		anim("idle")
		level.camera.shake(220, 0.004)
		level.effects.confetti(position.x, position.y - 60, 24))
	tw.tween_interval(0.5)
	tw.tween_callback(func(): invulnerable = false; fsm.set_state("IDLE"))


## Avance lento de lado a lado; en las fases 2 y 3 cambia de sentido de vez en cuando.
func _enter_IDLE(_p: String, _d: Variant) -> void:
	anim("move")
	sprite.speed_scale = 1.0
	turn_at = now + float(phase_data().turn) if float(phase_data().turn) > 0 else INF


func _update_IDLE(_t: float, _d: float) -> void:
	if position.x <= min_x: face(1)
	elif position.x >= max_x: face(-1)
	elif now >= turn_at:
		face(-dir)
		turn_at = now + float(phase_data().turn)
	velocity.x = dir * float(phase_data().speed)
	if fsm.elapsed > float(phase_data().interval):
		var p: Array = phase_data().pattern
		fsm.set_state(p[pattern_index % p.size()])
		pattern_index += 1


## Descanso vulnerable: brillo dorado (ojos en espiral después del giro).
func _enter_REST(_p: String, d: Variant) -> void:
	velocity.x = 0
	sprite.speed_scale = 1.0
	var stunned: bool = d is Dictionary and d.get("stunned", false)
	var ms := float(phase_data().rest) + (500.0 if stunned else 0.0)
	anim("stunned" if stunned else "idle")
	level.effects.glow_flash(position + Vector2(0, -30), C.YELLOW, 2, 5, ms, 0.45, 0)
	after(ms, func(): fsm.set_state("IDLE"))


## Aviso de ataque: "!" sobre el pastel y destello.
func warn(ms: float) -> void:
	level.effects.glow_flash(position + Vector2(0, -36), C.YELLOW, 2, 6, ms, 0.9, 2)
	var mark := PixelText.make("!", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW, "scale": 2})
	mark.position = position + Vector2(0, -98)
	mark.z_index = C.Z_UI_WORLD
	level.fx_root.add_child(mark)
	var tw := mark.create_tween().set_parallel()
	tw.tween_property(mark, "position:y", mark.position.y - 6, ms / 1000.0)
	tw.tween_property(mark, "modulate:a", 0.0, ms / 1000.0)
	tw.chain().tween_callback(mark.queue_free)
	AudioManager.play("block_warn")


func _shot(extra: Dictionary) -> Projectile:
	var c := {"owner": "boss", "texture": "w7_fx", "damage": 1, "lifespan": 3200, "frame": "boss_candy", "body": 9, "kind": "boss_candy"}
	c.merge(extra, true)
	return level.spawn_projectile("boss", c)


func _candy_at(from: Vector2, angle_deg: float, speed: float) -> void:
	var v := Vector2(facing(), 0).rotated(deg_to_rad(angle_deg * facing())) * speed
	_shot({"x": from.x, "y": from.y, "vx": v.x, "vy": v.y, "spin": 300})


# ---------------------------------------------------------------- fase 1
## Caramelos pequeños: tres caramelos lentos hacia Alice, uno detrás de otro.
func _enter_CANDY_SHOT(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "candy_attack", 0)
	warn(700)
	for i in 3:
		after(700 + i * 300, func():
			Anim.show_frame(sprite, "candy_attack", 1)
			var m := mouth()
			var aim := (player.position + Vector2(0, -14) - m).normalized()
			var v := aim * 110.0
			_shot({"x": m.x, "y": m.y, "vx": v.x, "vy": v.y, "spin": 300})
			AudioManager.play("candy_pop"))
	after(700 + 3 * 300 + 150, func(): Anim.show_frame(sprite, "candy_attack", 2))
	after(700 + 3 * 300 + 600, func(): fsm.set_state("REST"))


## Piruleta horizontal: rueda por el suelo girando (se salta).
func _enter_LOLLIPOP(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "frosting_attack", 2)
	warn(650)
	after(650, func():
		_lollipop(facing(), 0.0)
		Anim.show_frame(sprite, "candy_attack", 2))
	after(1500, func(): fsm.set_state("REST"))


func _lollipop(d: int, wobble: float) -> void:
	# ondulando va más alta: nunca roza el suelo (se desharía) y se salta igual
	_shot({"x": position.x + d * 44, "y": floor_y - (18.0 if wobble != 0 else 12.0), "vx": d * (112.0 + phase * 8.0), "vy": 0,
		"frame": "boss_lollipop", "body": 12, "kind": "lollipop", "spin": 420, "lifespan": 4600, "wobble": wobble})
	AudioManager.play("candy_spin")


# ---------------------------------------------------------------- fase 2
## Chorro de glaseado rosa: una ráfaga baja que avanza por el suelo (se salta) y tres gotas que
## caen en puntos marcados antes con un brillo.
func _enter_FROSTING_JET(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "frosting_attack", 0)
	warn(750)
	after(750, func():
		Anim.show_frame(sprite, "frosting_attack", 1)
		_jet(facing()))
	var px := clampf(player.position.x, min_x - 40, max_x + 40)
	_toss([px - 60, px + 60], 750)
	after(750 + BLOB_FLIGHT * 1000.0 + 300, func(): fsm.set_state("REST"))


func _jet(d: int) -> void:
	_shot({"x": position.x + d * 52, "y": floor_y - 14, "vx": d * 92.0, "vy": 0, "frame": "frosting_jet", "body": 14,
		"kind": "frosting", "lifespan": 3600, "scale": 0.6})
	AudioManager.play("frosting")


## Gotas de glaseado en parábola hacia puntos marcados en el suelo.
func _toss(targets: Array, warn_ms: float) -> void:
	for tx in targets:
		level.effects.glow_flash(Vector2(tx, floor_y - 3), C.rgb(0xff8fc8), 1, 2.6, warn_ms + BLOB_FLIGHT * 1000.0, 0.75, 0)
	after(warn_ms, func():
		var from := mouth() + Vector2(0, -10)
		for i in targets.size():
			var t := BLOB_FLIGHT
			var vx: float = (float(targets[i]) - from.x) / t
			var vy := (floor_y - 8 - from.y - 0.5 * BLOB_GRAVITY * t * t) / t
			_shot({"x": from.x, "y": from.y, "vx": vx, "vy": vy, "gravity": BLOB_GRAVITY, "frame": "frosting_blob" if i % 2 == 0 else "frosting_drop",
				"body": 11, "kind": "frosting", "lifespan": t * 1000.0 + 400}))


## Caramelos en abanico: cinco caramelos con huecos entre ellos.
func _enter_CANDY_FAN(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "candy_attack", 0)
	warn(750)
	after(750, func():
		Anim.show_frame(sprite, "candy_attack", 1)
		for a in [-34.0, -17.0, 0.0, 17.0, 34.0]:
			_candy_at(mouth(), a - 10.0, 95.0)
		AudioManager.play("candy_pop"))
	after(1500, func(): Anim.show_frame(sprite, "candy_attack", 2))
	after(1900, func(): fsm.set_state("REST"))


## Remolinos de piruletas: tres piruletas que ruedan ondulando (se saltan una a una).
func _enter_SWIRLS(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "spin_attack", 0)
	warn(650)
	for i in 3:
		after(650 + i * 480, func():
			anim("spin_attack")
			_lollipop(facing(), 0.8 if i % 2 == 0 else 0.0))
	after(650 + 3 * 480 + 300, func(): fsm.set_state("REST"))


# ---------------------------------------------------------------- fase 3
## Giro de caramelo multicolor: gira y recorre la arena deprisa soltando caramelos envueltos
## que caen en arco; las nubes de crema son el sitio seguro. Acaba mareado (descanso largo).
func _enter_SPIN(_p: String, _d: Variant) -> void:
	_start_spin(false)


func _enter_COMBO(_p: String, _d: Variant) -> void:
	_start_spin(true)


func _start_spin(with_frosting: bool) -> void:
	combo = with_frosting
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "spin_attack", 0)
	warn(900)
	level.effects.glow_flash(position + Vector2(0, -36), C.rgb(0xffd85c), 2, 7, 900, 0.8, 1)
	after(900, func():
		anim("spin_attack")
		AudioManager.play("candy_spin"))
	drop_at = now + 1300
	after(3800, _end_spin)


func _update_SPIN(_t: float, _d: float) -> void:
	_spin_move()


func _update_COMBO(_t: float, _d: float) -> void:
	_spin_move()


func _spin_move() -> void:
	if fsm.elapsed < 900:
		return
	if position.x <= min_x + 1: face(1)
	elif position.x >= max_x - 1: face(-1)
	velocity.x = dir * float(phase_data().speed) * 2.6
	if now >= drop_at:
		drop_at = now + 700
		var c := position + Vector2(0, -60)
		var vx := randf_range(-60, 60)
		_shot({"x": c.x, "y": c.y, "vx": vx, "vy": -200, "gravity": BLOB_GRAVITY, "frame": WRAPPED[randi() % WRAPPED.size()],
			"body": 9, "kind": "wrapped_candy", "spin": 360, "lifespan": 1800})


func _end_spin() -> void:
	velocity.x = 0
	level.camera.shake(240, 0.005)
	level.effects.confetti(position.x, position.y - 50, 20)
	if combo:
		combo = false
		face_player()
		Anim.show_frame(sprite, "frosting_attack", 0)
		var px := clampf(player.position.x, min_x - 40, max_x + 40)
		_toss([px - 50, px + 50], 500)
		after(500 + BLOB_FLIGHT * 1000.0 + 200, func(): fsm.set_state("REST", {"stunned": true}))
	else:
		fsm.set_state("REST", {"stunned": true})


## Ráfagas de glaseado: hacia un lado y después hacia el otro.
func _enter_FROSTING_BURST(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "frosting_attack", 0)
	warn(750)
	after(750, func():
		Anim.show_frame(sprite, "frosting_attack", 1)
		_jet(facing()))
	after(1600, func():
		face(-facing())
		Anim.show_frame(sprite, "frosting_attack", 1)
		_jet(facing()))
	after(2500, func(): fsm.set_state("REST"))


## Proyectiles múltiples: dos abanicos de caramelos desfasados y una piruleta por el suelo.
func _enter_MULTI(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "candy_attack", 0)
	warn(800)
	after(800, func():
		Anim.show_frame(sprite, "candy_attack", 1)
		for a in [-36.0, -12.0, 12.0]:
			_candy_at(mouth(), a - 8.0, 90.0)
		AudioManager.play("candy_pop"))
	after(1350, func():
		for a in [-24.0, 0.0, 24.0]:
			_candy_at(mouth(), a - 8.0, 90.0)
		_lollipop(facing(), 0.0))
	after(2200, func(): fsm.set_state("REST"))


func _enter_PHASE_CHANGE(_p: String, _d: Variant) -> void:
	invulnerable = true
	velocity.x = 0
	pattern_index = 0
	timers.clear()
	anim("stunned")
	level.camera.shake(350, 0.005)
	level.effects.glow_flash(position + Vector2(0, -36), C.rgb(0xf8add8), 2, 9, 900, 0.8, 1)
	AudioManager.play("frosting")
	GameState.show_toast("¡Tormenta de glaseado!" if phase == 2 else "¡El gran remolino dulce!")
	after(1300, func(): invulnerable = false; fsm.set_state("IDLE"))


# ---------------------------------------------------------------- derrota
## 1 deja de atacar 2 cara de sorpresa 3 sus piruletas dejan de girar 4 el glaseado cae
## suavemente 5 aparecen estrellas 6 queda convertido en un pastelito dormido; después entrega
## la estrella especial (y el portal al Mundo 8 se abre).
func _enter_DEFEATED(_p: String, _d: Variant) -> void:
	timers.clear()
	invulnerable = true
	velocity.x = 0
	set_body_enabled(false)
	level.kill_enemy_projectiles()
	AudioManager.play("enemy_defeat")
	level.camera.shake(240, 0.004)
	# sorpresa: la boca abierta del ataque de caramelos, con la piruleta girando aún
	anim("spin_attack")
	var tw := create_tween()
	tw.tween_property(sprite, "speed_scale", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
	var ref: WeakRef = weakref(self)
	var alive := func() -> bool: return ref.get_ref() != null
	level.after(1200, func():
		if not alive.call(): return
		sprite.speed_scale = 1.0
		Anim.show_frame(sprite, "candy_attack", 0)
		level.effects.float_text(position.x, position.y - 96, "!", C.YELLOW))
	level.after(1900, func():
		if not alive.call(): return
		for i in 6:
			_falling_frosting(i))
	level.after(2900, func():
		if not alive.call(): return
		Anim.show_frame(sprite, "defeated", 0)
		level.effects.sparkle(position.x, position.y - 30, 20)
		for i in 5:
			_star(i))
	level.after(3700, func():
		if not alive.call(): return
		level.effects.confetti(position.x, position.y - 50, 70))
	level.after(4300, func():
		if not alive.call(): return
		Anim.show_frame(sprite, "defeated", 1)
		var z := PixelText.make("Z z z", {"origin": Vector2(0.5, 0.5), "tint": C.rgb(0xfff3a0), "scale": 1})
		z.position = position + Vector2(facing() * 24, -46)
		level.fx_root.add_child(z)
		var zt := z.create_tween().set_loops()
		zt.tween_property(z, "position:y", z.position.y - 4, 0.8).set_trans(Tween.TRANS_SINE)
		zt.tween_property(z, "position:y", z.position.y, 0.8).set_trans(Tween.TRANS_SINE)
		defeated_at.emit(position.x - facing() * 64, position.y - 40))


## Gota de glaseado que baja despacio balanceándose.
func _falling_frosting(i: int) -> void:
	var g := Sprite2D.new()
	g.texture = Assets.frame("w7_fx", "frosting_drop" if i % 2 else "frosting_blob")
	g.position = position + Vector2((i - 2.5) * 16.0, -76 - (i % 3) * 8)
	g.scale = Vector2(0.7, 0.7)
	level.fx_root.add_child(g)
	var tw := g.create_tween().set_parallel()
	tw.tween_property(g, "position:y", floor_y - 4, 1.6 + i * 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(g, "position:x", g.position.x + (8.0 if i % 2 else -8.0), 1.6 + i * 0.15).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_interval(1.8)
	tw.chain().tween_property(g, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(g.queue_free)


func _star(i: int) -> void:
	var s := Sprite2D.new()
	s.texture = Assets.frame("w7_fx", "candy_star")
	s.position = position + Vector2(0, -40)
	level.fx_root.add_child(s)
	var to := position + Vector2(cos(TAU * i / 5.0) * 54.0, -46 + sin(TAU * i / 5.0) * 26.0)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "position", to, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "rotation_degrees", 360.0, 0.6)
	tw.chain().tween_interval(1.4)
	tw.chain().tween_property(s, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(s.queue_free)


## Golpe durante el descanso (sin cambio de fase): gesto de dolor.
func on_hurt() -> void:
	if fsm.is_state("REST") and not sprite.animation == "stunned":
		Anim.show_frame(sprite, "hurt", int(now / 200.0) % 3)
