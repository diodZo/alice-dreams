class_name Locomostro
extends BossBase
## Locomostro, jefe del Mundo 6: locomotora de juguete azul, roja y amarilla con un vagón lleno
## de peluches. Recorre el suelo de la Gran Estación Real. Misma interfaz que los jefes
## anteriores (setup, intro, hit_by, fsm, hp, max_hp, defeated_at, is_defeated...).
## Cada ataque tiene anticipación ("!", destello, silbato y pose previa) y termina en un
## descanso vulnerable (REST). Nada es inevitable: los bloques marcan antes dónde caen, el
## humo sólo empuja, los remolinos se saltan y la embestida se esquiva subiendo a las nubes.
##  1 El tren travieso (100-65 %): ráfaga de humo, remolinos de viento, avance lento y un bloque.
##  2 La carga del ferrocarril (65-30 %): embestidas por una ruta fija (de un extremo al otro)
##    seguidas de un descanso aturdido, bloques de colores, humo más amplio, cambios de sentido.
##  3 El expreso arcoíris (30-0 %): aceleración temporal con estrellas, ráfagas dobles, lluvia de
##    bloques con hueco marcado y combinaciones (embestida + bloques).

const MAX_HP := 60
const BLOCK_GRAVITY := 520.0
const BLOCK_FLIGHT := 1.05
const PHASES := {
	1: {"speed": 30.0, "interval": 1700.0, "rest": 1600.0, "turn": 0.0, "pattern": ["SMOKE", "BLOCK_TOSS", "WHIRLS", "BLOCK_TOSS"]},
	2: {"speed": 46.0, "interval": 1350.0, "rest": 1400.0, "turn": 1100.0, "pattern": ["CHARGE", "BLOCK_TOSS", "SMOKE", "CHARGE", "WHIRLS"]},
	3: {"speed": 58.0, "interval": 1150.0, "rest": 1450.0, "turn": 900.0, "pattern": ["EXPRESS", "MULTI_BLOCKS", "DOUBLE_SMOKE", "COMBO", "CHARGE"]},
}
const CHARGE_SPEED := {2: 230.0, 3: 290.0}

var turn_at := 0.0
var spark_at := 0.0
var combo := false
var gap_slot := 0
var rest_ms := 0.0


func setup(owner_level: Node, boss_cfg: Dictionary) -> void:
	level = owner_level
	cfg = boss_cfg
	min_x = float(cfg.minX) * C.TILE + 56
	max_x = float(cfg.maxX) * C.TILE - 56
	floor_y = float(cfg.floorY)
	position = Vector2(max_x + 200, floor_y)


func _ready() -> void:
	z_index = C.Z_ENEMY + 2
	collision_layer = C.L_BOSS
	collision_mask = 0
	monitoring = false
	set_meta("kind", "boss")
	set_meta("entity", self)
	sprite.sprite_frames = Assets.sprite_frames("locomostro")
	Anim.set_origin(sprite, Assets.cell_size("locomostro"), 0.5, 1.0)
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
## Chimenea / frente del tren (salida del humo) y vagón de carga (salida de los bloques).
func chimney() -> Vector2: return position + Vector2(facing() * 34, -44)
func cargo() -> Vector2: return position + Vector2(-facing() * 30, -40)


func _physics_process(delta: float) -> void:
	if level == null: return
	timers.process(now)
	if fsm.current != "": fsm.update(now, delta * 1000.0)
	if body_enabled and fsm.current != "INTRO" and not is_defeated():
		position.x = clampf(position.x + velocity.x * delta, min_x, max_x)
		if absf(velocity.x) > 150 and now >= spark_at:
			spark_at = now + 70
			level.effects.sparkle(position.x - facing() * 40, position.y - 20, 3)


func _enter_INTRO(_p: String, _d: Variant) -> void:
	face(-1)
	anim("move")
	AudioManager.play("whistle")
	var home := float(cfg.homeX) * C.TILE
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "position:x", home, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		anim("idle")
		level.camera.shake(220, 0.004)
		level.effects.poof(position.x, position.y - 6, 10))
	tw.tween_interval(0.5)
	tw.tween_callback(func(): invulnerable = false; fsm.set_state("IDLE"))


## Avance lento de lado a lado; en las fases 2 y 3 cambia de sentido de vez en cuando.
func _enter_IDLE(_p: String, _d: Variant) -> void:
	anim("move")
	turn_at = now + float(phase_data().turn) if float(phase_data().turn) > 0 else INF


func _update_IDLE(_t: float, _d: float) -> void:
	if position.x <= min_x: face(1)
	elif position.x >= max_x: face(-1)
	elif now >= turn_at:
		face(-dir)
		turn_at = now + float(phase_data().turn)
		level.effects.poof(position.x - dir * 30, position.y - 6, 4)
	velocity.x = dir * float(phase_data().speed)
	if fsm.elapsed > float(phase_data().interval):
		var p: Array = phase_data().pattern
		fsm.set_state(p[pattern_index % p.size()])
		pattern_index += 1


## Descanso vulnerable: brillo dorado (y ojos en espiral después de una embestida).
func _enter_REST(_p: String, d: Variant) -> void:
	velocity.x = 0
	var stunned: bool = d is Dictionary and d.get("stunned", false)
	rest_ms = float(phase_data().rest) + (500.0 if stunned else 0.0)
	anim("stunned" if stunned else "idle")
	level.effects.glow_flash(position + Vector2(0, -30), C.YELLOW, 2, 5, rest_ms, 0.45, 0)


func _update_REST(_t: float, _d: float) -> void:
	if fsm.elapsed > rest_ms: fsm.set_state("IDLE")


## Aviso de ataque: "!" sobre la locomotora, destello y silbato.
func warn(ms: float) -> void:
	level.effects.glow_flash(position + Vector2(0, -30), C.YELLOW, 2, 6, ms, 0.9, 2)
	var mark := PixelText.make("!", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW, "scale": 2})
	mark.position = position + Vector2(0, -96)
	mark.z_index = C.Z_UI_WORLD
	level.fx_root.add_child(mark)
	var tw := mark.create_tween().set_parallel()
	tw.tween_property(mark, "position:y", mark.position.y - 6, ms / 1000.0)
	tw.tween_property(mark, "modulate:a", 0.0, ms / 1000.0)
	tw.chain().tween_callback(mark.queue_free)
	AudioManager.play("whistle_small")


func _shot(extra: Dictionary) -> Projectile:
	var c := {"owner": "boss", "texture": "w6_fx", "damage": 1, "lifespan": 3000, "frame": "smoke_puff", "body": 12, "kind": "smoke_whirl"}
	c.merge(extra, true)
	return level.spawn_projectile("boss", c)


# ---------------------------------------------------------------- humo
## Ráfaga de humo: sólo empuja (no quita corazones). En la fase 2 sale más amplia (dos nubes).
func _enter_SMOKE(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "wind_attack", 0)
	warn(700)
	after(700, func():
		anim("wind_attack", false)
		_gust(facing(), phase >= 2))
	after(1700, func(): fsm.set_state("REST"))


## Ráfagas dobles (fase 3): hacia los dos lados, una detrás de otra.
func _enter_DOUBLE_SMOKE(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "wind_attack", 0)
	warn(700)
	after(700, func():
		anim("wind_attack", false)
		_gust(facing(), true))
	after(1300, func():
		face(-facing())
		anim("wind_attack", false)
		_gust(facing(), true)
		_whirl(facing(), 0))
	after(2300, func(): fsm.set_state("REST"))


func _gust(d: int, wide: bool) -> void:
	var ys := [-18.0, -44.0] if wide else [-26.0]
	for y in ys:
		_shot({"x": position.x + d * 48, "y": position.y + y, "vx": d * 125.0, "vy": 0, "frame": "wind_swirl", "body": 22,
			"kind": "wind", "damage": 0, "lifespan": 2400, "alpha": 0.9})
	level.effects.poof(chimney().x, chimney().y, 6)
	AudioManager.play("wind")


## Remolinos de viento: tres nubecitas que ruedan por el suelo ondulando (se saltan).
func _enter_WHIRLS(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "wind_attack", 0)
	warn(650)
	for i in 3:
		after(650 + i * 420, func():
			anim("wind_attack", false)
			_whirl(facing(), i))
	after(650 + 3 * 420 + 300, func(): fsm.set_state("REST"))


func _whirl(d: int, i: int) -> void:
	_shot({"x": position.x + d * 46, "y": floor_y - 10, "vx": d * (78.0 + phase * 8.0), "vy": 0, "frame": "smoke_puff", "body": 11,
		"kind": "smoke_whirl", "spin": 360, "lifespan": 4200, "wobble": 1.2 if i % 2 == 0 else 0.0})
	AudioManager.play("wind")


# ---------------------------------------------------------------- bloques
## Lanza bloques de juguete en parábola a puntos marcados antes en el suelo.
func _toss(targets: Array, warn_ms: float) -> void:
	for tx in targets:
		level.effects.glow_flash(Vector2(tx, floor_y - 3), C.rgb(0xf76b73), 1, 2.6, warn_ms + BLOCK_FLIGHT * 1000.0, 0.75, 0)
	after(warn_ms, func():
		anim("block_attack", false)
		AudioManager.play("block_warn")
		var from := cargo()
		var frames := ["toy_block_pink", "toy_block_blue", "toy_block_green"]
		for i in targets.size():
			var t := BLOCK_FLIGHT
			var vx: float = (float(targets[i]) - from.x) / t
			var vy := (floor_y - 8 - from.y - 0.5 * BLOCK_GRAVITY * t * t) / t
			_shot({"x": from.x, "y": from.y, "vx": vx, "vy": vy, "gravity": BLOCK_GRAVITY, "frame": frames[i % 3], "body": 14,
				"kind": "toy_block", "spin": 200, "lifespan": t * 1000.0 + 400}))


func _enter_BLOCK_TOSS(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "block_attack", 0)
	warn(750)
	var px := clampf(player.position.x, min_x - 40, max_x + 40)
	var targets := [px] if phase == 1 else [px - 56, px, px + 56]
	_toss(targets, 750)
	after(750 + BLOCK_FLIGHT * 1000.0 + 300, func(): fsm.set_state("REST"))


## Lluvia de bloques (fase 3): siete huecos en la arena, cinco con bloque; el hueco libre
## (dos puntos seguidos) se ve porque no tiene marca y cambia de sitio cada vez.
func _enter_MULTI_BLOCKS(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "block_attack", 0)
	warn(850)
	_toss(_rain_targets(), 850)
	after(850 + BLOCK_FLIGHT * 1000.0 + 350, func(): fsm.set_state("REST"))


func _rain_targets() -> Array:
	var slots := 7
	gap_slot = (gap_slot + 3) % (slots - 1)
	var out := []
	for i in slots:
		if i == gap_slot or i == gap_slot + 1:
			continue
		out.append(lerpf(min_x - 30, max_x + 30, float(i) / (slots - 1)))
	return out


# ---------------------------------------------------------------- embestida
## Embestida por una ruta fija: aviso en el sitio, retrocede hasta el extremo más cercano de la
## arena, se gira, pita y cruza la arena entera hasta el otro extremo. Al chocar con el tope
## queda aturdido (descanso vulnerable). Se esquiva subiendo a las nubes.
func _enter_CHARGE(_p: String, _d: Variant) -> void:
	_start_charge(false)


func _enter_COMBO(_p: String, _d: Variant) -> void:
	_start_charge(true)


func _start_charge(with_blocks: bool) -> void:
	combo = with_blocks
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "charge", 0)
	warn(800)
	var to_left := position.x - min_x < max_x - position.x
	var end_x := min_x if to_left else max_x
	after(800, func():
		face(-1 if to_left else 1)
		anim("move")
		velocity.x = dir * 120.0)
	var back_ms := 800.0 + absf(end_x - position.x) / 120.0 * 1000.0
	after(back_ms, func():
		position.x = end_x
		velocity.x = 0
		face(1 if to_left else -1)
		Anim.show_frame(sprite, "charge", 0)
		level.effects.poof(position.x, position.y - 8, 8)
		AudioManager.play("whistle"))
	var go_ms := back_ms + 650.0
	var speed: float = CHARGE_SPEED.get(phase, 230.0)
	after(go_ms, func():
		anim("charge")
		velocity.x = dir * speed
		AudioManager.play("rocket"))
	var run_ms := go_ms + (max_x - min_x) / speed * 1000.0 + 60.0
	after(run_ms, _end_charge)


func _update_CHARGE(_t: float, _d: float) -> void:
	_charge_trail()


func _update_COMBO(_t: float, _d: float) -> void:
	_charge_trail()


func _charge_trail() -> void:
	# llega al tope antes de tiempo (choque con el extremo de la arena)
	if absf(velocity.x) > 150 and ((velocity.x > 0 and position.x >= max_x) or (velocity.x < 0 and position.x <= min_x)):
		_end_charge()


func _end_charge() -> void:
	if not (fsm.is_state("CHARGE") or fsm.is_state("COMBO")) or absf(velocity.x) < 1:
		return
	velocity.x = 0
	level.camera.shake(260, 0.006)
	level.effects.poof(position.x + facing() * 50, position.y - 20, 12)
	AudioManager.play("block_land")
	if combo:
		combo = false
		Anim.show_frame(sprite, "block_attack", 0)
		var px := clampf(player.position.x, min_x - 40, max_x + 40)
		_toss([px - 48, px + 48], 500)
		after(500 + BLOCK_FLIGHT * 1000.0 + 200, func(): fsm.set_state("REST", {"stunned": true}))
	else:
		fsm.set_state("REST", {"stunned": true})


# ---------------------------------------------------------------- expreso
## Aceleración temporal (fase 3): se rodea de estrellas, pita y recorre la arena deprisa dos
## veces; las nubes son el sitio seguro.
func _enter_EXPRESS(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "charge", 0)
	warn(850)
	level.effects.glow_flash(position + Vector2(0, -30), C.rgb(0xffd85c), 2, 7, 850, 0.8, 1)
	after(850, func():
		anim("charge")
		AudioManager.play("rocket"))
	after(3600, func(): fsm.set_state("REST"))


func _update_EXPRESS(_t: float, _d: float) -> void:
	if fsm.elapsed < 850:
		return
	if position.x <= min_x + 1: face(1)
	elif position.x >= max_x - 1: face(-1)
	velocity.x = dir * float(phase_data().speed) * 2.6


func _enter_PHASE_CHANGE(_p: String, _d: Variant) -> void:
	invulnerable = true
	velocity.x = 0
	pattern_index = 0
	timers.clear()
	anim("stunned")
	level.camera.shake(350, 0.005)
	level.effects.glow_flash(position + Vector2(0, -30), C.rgb(0xf8add8), 2, 9, 900, 0.8, 1)
	AudioManager.play("whistle")
	GameState.show_toast("¡La carga del ferrocarril!" if phase == 2 else "¡El expreso arcoíris!")
	after(1300, func(): invulnerable = false; fsm.set_state("IDLE"))


# ---------------------------------------------------------------- derrota
## 1 reduce la velocidad 2 las ruedas dejan de girar 3 el humo se vuelve nubecitas blancas
## 4 ojos cansados 5 caen sus bloques de juguete alrededor 6 se inclina un poco 7 estrellas y
## confeti 8 se queda dormido; después entrega la estrella especial (y el portal se abre).
func _enter_DEFEATED(_p: String, _d: Variant) -> void:
	timers.clear()
	invulnerable = true
	set_body_enabled(false)
	level.kill_enemy_projectiles()
	AudioManager.play("enemy_defeat")
	level.camera.shake(240, 0.004)
	anim("move")
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "velocity:x", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "speed_scale", 0.0, 1.0)
	var ref: WeakRef = weakref(self)
	var alive := func() -> bool: return ref.get_ref() != null
	level.after(1000, func():
		if not alive.call(): return
		velocity.x = 0
		Anim.show_frame(sprite, "defeated", 0)
		for i in 4:
			_white_cloud(i))
	level.after(1800, func():
		if not alive.call(): return
		Anim.show_frame(sprite, "defeated", 1)
		for i in 5:
			_falling_toy(i))
	level.after(2500, func():
		if not alive.call(): return
		create_tween().tween_property(sprite, "rotation_degrees", -4.0 * facing(), 0.6).set_trans(Tween.TRANS_SINE))
	level.after(3100, func():
		if not alive.call(): return
		level.effects.confetti(position.x, position.y - 50, 70)
		level.effects.sparkle(position.x, position.y - 30, 20))
	level.after(3800, func():
		if not alive.call(): return
		Anim.show_frame(sprite, "defeated", 2)
		var z := PixelText.make("Z z z", {"origin": Vector2(0.5, 0.5), "tint": C.rgb(0xfff3a0), "scale": 1})
		z.position = position + Vector2(facing() * 30, -62)
		level.fx_root.add_child(z)
		defeated_at.emit(position.x - facing() * 70, position.y - 40))


func _white_cloud(i: int) -> void:
	var c := Sprite2D.new()
	c.texture = Assets.frame("w6_fx", "smoke_s" if i % 2 else "smoke_puff")
	c.position = chimney() + Vector2(i * 6 - 9, 0)
	c.scale = Vector2(0.6, 0.6)
	level.fx_root.add_child(c)
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "position:y", c.position.y - 30 - i * 8, 1.4 + i * 0.2)
	tw.tween_property(c, "scale", Vector2(1.1, 1.1), 1.4)
	tw.tween_property(c, "modulate:a", 0.0, 1.6 + i * 0.2)
	tw.chain().tween_callback(c.queue_free)


func _falling_toy(i: int) -> void:
	var b := Sprite2D.new()
	b.texture = Assets.frame("w6_fx", ["toy_block_pink", "toy_block_blue", "toy_block_green"][i % 3])
	var x := position.x + (i - 2) * 26.0
	b.position = Vector2(x, position.y - 110 - i * 12)
	level.fx_root.add_child(b)
	var tw := b.create_tween()
	tw.tween_property(b, "position:y", floor_y - 7, 0.55 + i * 0.07).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.5)
	tw.tween_property(b, "modulate:a", 0.0, 0.8)
	tw.tween_callback(b.queue_free)


## Golpe durante el descanso (sin cambio de fase): gesto de dolor.
func on_hurt() -> void:
	if fsm.is_state("REST") and not sprite.animation == "stunned":
		Anim.show_frame(sprite, "hurt", 0)
