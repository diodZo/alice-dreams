class_name ReyPesadelo
extends Area2D
## Rey Pesadelo, jefe final (Mundo 8): monstruo de pesadilla del salón del trono, con el diseño
## oficial de jefemundo8.png. Misma interfaz que los jefes anteriores (setup, intro, hit_by, fsm,
## hp, max_hp, defeated_at, is_defeated, set_body_enabled, invulnerable).
##
## Estados explícitos (StateMachine):
##   INTRO -> IDLE -> MOVE -> TELEGRAPH -> (SPIT | CLAW | SLOW_CLOUD | FURY_SCREAM) -> STUNNED -> IDLE
##   HURT (cambio de fase: retrocede, invulnerable un momento), DEFEATED -> TRANSFORMING -> CAT
## TELEGRAPH es siempre el aviso del ataque siguiente (pose previa, "!" y destello). Después de
## cada ataque viene STUNNED: la ventana para contraatacar (más larga tras los especiales).
##
## Ataques: escupitajo oscuro (proyectil que se esquiva saltando o apartándose), garrazo de
## ráfaga (media luna que recorre el suelo: salto preciso), nube ralentizadora (sin daño,
## ralentiza 3 s sin acumularse) y grito de furia (ondas que se expanden por el suelo, aviso
## largo). Nunca empieza un grito mientras Alice esté ralentizada.
##   Fase 1 El monstruo despierta  (100-65 %): escupitajo y garrazo, desplazamiento lento.
##   Fase 2 El reino tiembla       ( 65-30 %): garrazos dobles, escupitajos, nube; más rápido;
##                                             el cielo se oscurece y caen estrellas con aviso.
##   Fase 3 La última pesadilla    ( 30- 0 %): grito, garrazos dobles, escupitajos seguidos,
##                                             nubes y combinaciones controladas; música de furia.

signal defeated_at(x: float, y: float)
signal transformed(cat: Node2D)

const MAX_HP := 80
const PHASES := {
	1: {"speed": 30.0, "idle": 750.0, "move": 1300.0, "rest": 1500.0, "warn": 850.0, "spit": 1, "claw": 1,
		"pattern": ["SPIT", "CLAW", "SPIT", "CLAW"]},
	2: {"speed": 46.0, "idle": 600.0, "move": 1100.0, "rest": 1350.0, "warn": 750.0, "spit": 2, "claw": 2,
		"pattern": ["CLAW", "SPIT", "SLOW_CLOUD", "CLAW", "SPIT"]},
	3: {"speed": 54.0, "idle": 550.0, "move": 1000.0, "rest": 1450.0, "warn": 700.0, "spit": 3, "claw": 2,
		"pattern": ["FURY_SCREAM", "CLAW", "SPIT", "SLOW_CLOUD", "FURY_SCREAM", "COMBO"]},
}
## Ataques especiales: su ventana de contraataque es más larga.
const SPECIAL := ["SLOW_CLOUD", "FURY_SCREAM"]
## Proyectiles (configurables): velocidad (px/s), daño, vida (ms), escala.
const SPIT := {"speed": 125.0, "damage": 1, "lifespan": 3200.0, "scale": 0.8}
const CLAW_WAVE := {"speed": 150.0, "damage": 1, "lifespan": 3400.0, "scale": 0.72, "gap": 520.0}
const FURY := {"speed": 125.0, "damage": 1, "lifespan": 2800.0, "scale": 0.6, "waves": 3, "gap": 700.0, "warn": 1500.0}
const CLOUD := {"speed": 34.0, "life": 4200.0}

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape
@onready var hurtbox: Area2D = $Hurtbox
var level: Node
var cfg := {}
var fsm: StateMachine
var timers := Timers.new()
var velocity := Vector2.ZERO
var max_hp := MAX_HP
var hp := MAX_HP
var phase := 1
var pattern_index := 0
var min_x := 0.0
var max_x := 0.0
var floor_y := 0.0
var dir := -1
var invulnerable := true
var body_enabled := false
var flash: ShaderMaterial
var eyes: Array[Sprite2D] = []
var dash_at := 0.0
var cat: Node2D


func setup(owner_level: Node, boss_cfg: Dictionary) -> void:
	level = owner_level
	cfg = boss_cfg
	min_x = float(cfg.minX) * C.TILE + 56
	max_x = float(cfg.maxX) * C.TILE - 40
	floor_y = float(cfg.floorY)
	position = Vector2(max_x + 220, floor_y)


func _ready() -> void:
	z_index = C.Z_ENEMY + 2
	collision_layer = C.L_BOSS
	collision_mask = 0
	monitoring = false
	set_meta("kind", "boss")
	set_meta("entity", self)
	# el cuerpo entero recibe los disparos de Alice (también desde las plataformas)
	hurtbox.collision_layer = C.L_ENEMY_HITBOX
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.set_meta("kind", "shootable")
	hurtbox.set_meta("entity", self)
	sprite.sprite_frames = Assets.sprite_frames("rey_pesadelo")
	Anim.set_origin(sprite, Assets.cell_size("rey_pesadelo"), 0.5, 1.0)
	flash = ShaderMaterial.new()
	flash.shader = preload("res://resources/effects/flash.gdshader")
	sprite.material = flash
	# brillo de los ojos amarillos (se apaga en la transformación)
	for i in 2:
		var e := Sprite2D.new()
		e.texture = Assets.generated("glow")
		e.modulate = Color(C.rgb(0xffd23c), 0.0)
		e.scale = Vector2(0.45, 0.45)
		e.z_index = 1
		add_child(e)
		eyes.append(e)
	fsm = StateMachine.new(self)
	set_body_enabled(false)


var player: Player:
	get: return level.player
var now: float:
	get: return level.now


func is_defeated() -> bool: return fsm.current in ["DEFEATED", "TRANSFORMING", "CAT"]
func phase_data() -> Dictionary: return PHASES[phase]
func set_body_enabled(on: bool) -> void:
	body_enabled = on
	shape.set_deferred("disabled", not on)
	for c in hurtbox.get_children():
		c.set_deferred("disabled", not on)
func intro() -> void: fsm.set_state("INTRO")
func anim(anim_name: String, ignore := true) -> void: Anim.play(sprite, anim_name, ignore)
## El dibujo mira a la derecha; flip_h = mira a la izquierda.
func face(d: int) -> void:
	dir = d
	sprite.flip_h = d < 0
	_place_eyes()
func face_player() -> void: face(-1 if player.position.x < position.x else 1)
func facing() -> int: return -1 if sprite.flip_h else 1
func after(ms: float, fn: Callable) -> void:
	timers.add(now, ms, func():
		if not is_defeated(): fn.call())
## Boca (salida del escupitajo y del grito).
func mouth() -> Vector2: return position + Vector2(facing() * 38, -50)


func _place_eyes() -> void:
	for i in eyes.size():
		eyes[i].position = Vector2(facing() * (22 + i * 9), -60 + i)


func _physics_process(delta: float) -> void:
	if level == null:
		return
	timers.process(now)
	if fsm.current != "":
		fsm.update(now, delta * 1000.0)
	if body_enabled and fsm.current != "INTRO" and not is_defeated():
		position.x = clampf(position.x + velocity.x * delta, min_x, max_x)


# ------------------------------------------------------------------ entrada
func _enter_INTRO(_p: String, _d: Variant) -> void:
	face(-1)
	anim("move")
	AudioManager.play("boss_appear")
	var home := float(cfg.homeX) * C.TILE
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "position:x", home, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		Anim.show_frame(sprite, "fury", 0)
		_eyes_glow(0.8, 600)
		level.camera.shake(260, 0.003)
		AudioManager.play("fury_scream"))
	tw.tween_interval(0.8)
	tw.tween_callback(func(): invulnerable = false; fsm.set_state("IDLE"))


# ------------------------------------------------------- reposo y movimiento
func _enter_IDLE(_p: String, _d: Variant) -> void:
	velocity.x = 0
	sprite.speed_scale = 1.0
	anim("idle")
	face_player()


func _update_IDLE(_t: float, _d: float) -> void:
	if fsm.elapsed < float(phase_data().idle):
		return
	var p: Array = phase_data().pattern
	var next: String = p[pattern_index % p.size()]
	# nunca un grito de furia mientras Alice sigue ralentizada: espera a que se le pase
	if next == "FURY_SCREAM" and player.is_slowed():
		return
	fsm.set_state("MOVE")


## Se acerca (o se aleja) para quedar a una distancia cómoda de Alice; en las fases 2 y 3
## hace a veces un desplazamiento rápido.
func _enter_MOVE(_p: String, _d: Variant) -> void:
	anim("move")
	dash_at = now + 350.0 if phase >= 2 else INF


func _update_MOVE(_t: float, _d: float) -> void:
	var dx := player.position.x - position.x
	var want := 0.0
	if absf(dx) > 210:
		want = signf(dx)
	elif absf(dx) < 120:
		want = -signf(dx)
	if (want < 0 and position.x <= min_x + 2) or (want > 0 and position.x >= max_x - 2):
		want = 0
	var speed := float(phase_data().speed)
	# lejos de Alice se acerca deprisa: nunca ataca desde fuera de la vista
	var far := absf(dx) > 260
	if far:
		speed *= 2.6
	if now >= dash_at and now < dash_at + 380 and want != 0:
		speed *= 3.2
		if int(now / 60.0) % 2 == 0:
			level.effects.poof(position.x - facing() * 36, position.y - 4, 2)
	if want != 0:
		face(int(want))
	else:
		face_player()
	velocity.x = want * speed
	sprite.speed_scale = 1.6 if speed > float(phase_data().speed) else 1.0
	if (fsm.elapsed >= float(phase_data().move) and not far) or (want == 0 and fsm.elapsed > 300) or fsm.elapsed > 4000:
		var p: Array = phase_data().pattern
		var next: String = p[pattern_index % p.size()]
		pattern_index += 1
		fsm.set_state("TELEGRAPH", {"attack": next})


func _exit_MOVE(_n: String) -> void:
	velocity.x = 0
	sprite.speed_scale = 1.0


# ------------------------------------------------------------------- aviso
func _enter_TELEGRAPH(_p: String, d: Variant) -> void:
	velocity.x = 0
	face_player()
	var attack: String = d.attack
	var ms := float(phase_data().warn)
	var opts := {}
	match attack:
		"SPIT":
			Anim.show_frame(sprite, "spit", 0)
			_warn(ms, C.rgb(0xd85cd5))
			opts = {"count": int(phase_data().spit)}
		"CLAW":
			Anim.show_frame(sprite, "claw", 0)
			_warn(ms, C.rgb(0xd85cd5))
			_floor_mark(ms)
			opts = {"count": int(phase_data().claw)}
		"COMBO":
			# combinación controlada: garrazo y, tras una pausa, un escupitajo
			Anim.show_frame(sprite, "claw", 0)
			_warn(ms, C.rgb(0xd85cd5))
			_floor_mark(ms)
			attack = "CLAW"
			opts = {"count": 1, "then_spit": true}
		"SLOW_CLOUD":
			# se gira ligeramente con cara traviesa
			face(-facing())
			Anim.show_frame(sprite, "fart", 0)
			_warn(ms, C.rgb(0xc8a5ff))
		"FURY_SCREAM":
			ms = float(FURY.warn)
			anim("fury", false)
			sprite.pause()
			Anim.show_frame(sprite, "fury", 0)
			_warn(ms, C.rgb(0xff5a8a))
			AudioManager.duck(true)
			_eyes_glow(1.0, ms)
			AudioManager.play("fury_charge")
			for i in 3:
				after(ms * (0.3 + i * 0.25), func(): level.effects.glow_flash(position + Vector2(0, -44), C.rgb(0xd85cd5), 1.0, 2.6 + i, 500, 0.45, 0))
	after(ms, func(): fsm.set_state(attack, opts))


## Aviso: "!" sobre la cabeza, destello suave y sonido.
func _warn(ms: float, color: Color) -> void:
	level.effects.glow_flash(position + Vector2(0, -48), color, 1.5, 4.5, ms, 0.55, 2)
	var mark := PixelText.make("!", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW, "scale": 2})
	mark.position = position + Vector2(0, -104)
	mark.z_index = C.Z_UI_WORLD
	level.fx_root.add_child(mark)
	var tw := mark.create_tween().set_parallel()
	tw.tween_property(mark, "position:y", mark.position.y - 6, ms / 1000.0)
	tw.tween_property(mark, "modulate:a", 0.0, ms / 1000.0)
	tw.chain().tween_callback(mark.queue_free)
	AudioManager.play("block_warn")


## Marca en el suelo por donde va a pasar la ráfaga del garrazo.
func _floor_mark(ms: float) -> void:
	for i in 4:
		var x := position.x + facing() * (60 + i * 40)
		level.effects.glow_flash(Vector2(x, floor_y - 2), C.rgb(0xd85cd5), 0.8, 2.0, ms, 0.5, 0)


func _eyes_glow(alpha: float, ms: float) -> void:
	_place_eyes()
	for e in eyes:
		var tw := e.create_tween()
		tw.tween_property(e, "modulate:a", alpha, 0.25)
		tw.tween_interval(maxf(0.0, ms / 1000.0 - 0.5))
		tw.tween_property(e, "modulate:a", 0.0, 0.25)


func _shot(extra: Dictionary) -> Projectile:
	var c := {"owner": "boss", "texture": "w8_fx", "damage": 1, "lifespan": 3000, "frame": "spit_ball", "body": 10, "kind": "spit"}
	c.merge(extra, true)
	return level.spawn_projectile("boss", c)


# ------------------------------------------------------ escupitajo oscuro
func _enter_SPIT(_p: String, d: Variant) -> void:
	velocity.x = 0
	var count: int = d.get("count", 1) if d is Dictionary else 1
	for i in count:
		after(i * 650.0, func():
			face_player()
			Anim.show_frame(sprite, "spit", 1)
			level.effects.sparkle(mouth().x, mouth().y, 6)
			after(120, func():
				Anim.show_frame(sprite, "spit", 3)
				_spit()))
	after(count * 650.0 + 300, func(): Anim.show_frame(sprite, "spit", 0))
	after(count * 650.0 + 550, func(): fsm.set_state("STUNNED", {"ms": float(phase_data().rest)}))


func _spit() -> void:
	var m := mouth()
	var aim := (player.position + Vector2(0, -16) - m)
	var ang := clampf(rad_to_deg(atan2(aim.y, absf(aim.x))), -28.0, 28.0)
	var v := Vector2(facing(), 0).rotated(deg_to_rad(ang * facing())) * float(SPIT.speed)
	var p := _shot({"x": m.x, "y": m.y, "vx": v.x, "vy": v.y, "damage": SPIT.damage, "lifespan": SPIT.lifespan, "scale": SPIT.scale})
	if p != null:
		# estela violeta detrás del proyectil
		var trail := Sprite2D.new()
		trail.texture = Assets.frame("w8_fx", "spit_trail")
		trail.modulate.a = 0.75
		trail.position = Vector2(-signf(v.x) * 18, 0)
		trail.flip_h = v.x < 0
		trail.scale = Vector2(0.7, 0.7)
		trail.show_behind_parent = true
		p.add_child(trail)
	AudioManager.play("spit")


# ------------------------------------------------------- garrazo de ráfaga
func _enter_CLAW(_p: String, d: Variant) -> void:
	velocity.x = 0
	var count: int = d.get("count", 1) if d is Dictionary else 1
	var then_spit: bool = d.get("then_spit", false) if d is Dictionary else false
	for i in count:
		after(i * float(CLAW_WAVE.gap), func():
			Anim.show_frame(sprite, "claw", 1)
			_claw_wave()
			after(220, func(): Anim.show_frame(sprite, "claw", 0)))
	var end := count * float(CLAW_WAVE.gap) + 300
	if then_spit:
		after(end + 450, func():
			face_player()
			Anim.show_frame(sprite, "spit", 1)
			after(150, func():
				Anim.show_frame(sprite, "spit", 3)
				_spit()))
		end += 1100
	after(end, func(): fsm.set_state("STUNNED", {"ms": float(phase_data().rest)}))


func _claw_wave() -> void:
	var slash := Sprite2D.new()
	slash.texture = Assets.frame("w8_fx", "claw_slash")
	slash.flip_h = facing() < 0
	slash.position = position + Vector2(facing() * 54, -34)
	slash.scale = Vector2(0.7, 0.7)
	level.fx_root.add_child(slash)
	var tw := slash.create_tween()
	tw.tween_property(slash, "modulate:a", 0.0, 0.3)
	tw.tween_callback(slash.queue_free)
	var s := float(CLAW_WAVE.scale)
	_shot({"x": position.x + facing() * 52, "y": floor_y - 15, "vx": facing() * float(CLAW_WAVE.speed), "vy": 0,
		"frame": "claw_wave", "body": 16, "kind": "claw_wave", "damage": CLAW_WAVE.damage, "lifespan": CLAW_WAVE.lifespan, "scale": s})
	level.camera.shake(90, 0.002)
	AudioManager.play("claw")


# ------------------------------------------------- nube ralentizadora (¡pfff!)
func _enter_SLOW_CLOUD(_p: String, _d: Variant) -> void:
	velocity.x = 0
	Anim.show_frame(sprite, "fart", 1)
	after(160, func():
		Anim.show_frame(sprite, "fart", 2)
		AudioManager.play("fart")
		# la nube sale por detrás y avanza despacio hacia Alice
		var toward := signf(player.position.x - position.x)
		var start := position + Vector2(-facing() * 44, 0)
		var cloud := SlowCloud.new().setup(level, start, toward * float(CLOUD.speed), float(CLOUD.life))
		level.level_objects.objects.add_child(cloud)
		level.effects.sparkle(start.x, start.y - 20, 8)
		level.effects.poof(start.x, start.y - 10, 6))
	after(900, func(): face_player())
	after(1200, func(): fsm.set_state("STUNNED", {"ms": float(phase_data().rest) + 500.0}))


# ------------------------------------------------------- grito de furia
func _enter_FURY_SCREAM(_p: String, _d: Variant) -> void:
	velocity.x = 0
	sprite.play("fury")
	Anim.show_frame(sprite, "fury", 1)
	AudioManager.play("fury_scream")
	level.camera.shake(400, 0.003)
	var waves := int(FURY.waves)
	for i in waves:
		after(i * float(FURY.gap), func():
			Anim.show_frame(sprite, "fury", 1 + i % 2)
			level.effects.glow_flash(mouth(), C.rgb(0xd85cd5), 1.0, 5.0, 600, 0.5, 1)
			_ring(-1)
			_ring(1))
	after(waves * float(FURY.gap) + 200, func(): AudioManager.duck(false))
	after(waves * float(FURY.gap) + 500, func(): fsm.set_state("STUNNED", {"ms": float(phase_data().rest) + 600.0}))


## Onda concéntrica que se expande por el suelo hacia un lado (se salta o se espera arriba).
func _ring(d: int) -> void:
	var p := _shot({"x": position.x + d * 40, "y": floor_y - 15, "vx": d * float(FURY.speed), "vy": 0, "frame": "fury_ring",
		"body": 14, "kind": "fury_ring", "damage": FURY.damage, "lifespan": FURY.lifespan, "scale": FURY.scale})
	if p != null:
		var tw := p.create_tween().set_loops()
		tw.tween_property(p, "modulate:a", 0.7, 0.2)
		tw.tween_property(p, "modulate:a", 1.0, 0.2)


func _exit_FURY_SCREAM(_n: String) -> void:
	AudioManager.duck(false)


# ----------------------------------------------------- ventana de contraataque
func _enter_STUNNED(_p: String, d: Variant) -> void:
	velocity.x = 0
	sprite.speed_scale = 1.0
	anim("stunned")
	var ms: float = d.get("ms", 1400.0) if d is Dictionary else 1400.0
	level.effects.glow_flash(position + Vector2(0, -40), C.YELLOW, 2, 5, ms, 0.35, 0)
	after(ms, func(): fsm.set_state("IDLE"))


# ------------------------------------------------------------ cambio de fase
func _enter_HURT(_p: String, _d: Variant) -> void:
	invulnerable = true
	velocity.x = 0
	pattern_index = 0
	timers.clear()
	AudioManager.duck(false)
	anim("hurt", false)
	level.camera.shake(300, 0.003)
	level.effects.glow_flash(position + Vector2(0, -40), C.rgb(0xd85cd5), 2, 8, 900, 0.6, 1)
	level.on_boss_phase(phase)
	GameState.show_toast("¡El reino tiembla!" if phase == 2 else "¡La última pesadilla!")
	after(1400, func(): invulnerable = false; fsm.set_state("IDLE"))


# ------------------------------------------------------------------ derrota
## 1 cancela ataques  2 desactiva golpes  3 no salen más proyectiles  4 baja la música
## 5 se detiene  6 agotamiento  -> TRANSFORMING (NightmareTransformation)  -> CAT.
func _enter_DEFEATED(_p: String, _d: Variant) -> void:
	timers.clear()
	invulnerable = true
	velocity.x = 0
	set_body_enabled(false)
	level.kill_enemy_projectiles()
	get_tree().call_group("boss_hazard", "vanish")
	AudioManager.duck(false)
	AudioManager.fade_out_music(2200)
	AudioManager.play("enemy_defeat")
	level.camera.shake(200, 0.003)
	face_player()
	Anim.show_frame(sprite, "hurt", 1)
	for e in eyes:
		e.modulate.a = 0.0
	defeated_at.emit(position.x, position.y)
	var ref: WeakRef = weakref(self)
	level.after(1300, func():
		var b: ReyPesadelo = ref.get_ref()
		if b != null and b.fsm.is_state("DEFEATED"):
			b.fsm.set_state("TRANSFORMING"))


func _enter_TRANSFORMING(_p: String, _d: Variant) -> void:
	var tr: NightmareTransformation = preload("res://scenes/cinematics/NightmareTransformation.tscn").instantiate()
	tr.position = position
	tr.flip = sprite.flip_h
	level.world_root.add_child(tr)
	sprite.visible = false
	tr.finished.connect(func():
		fsm.set_state("CAT", {"at": tr.position})
		# el gato interactivo sustituye al de la animación
		tr.queue_free())
	tr.play()


func _enter_CAT(_p: String, d: Variant) -> void:
	cat = preload("res://scenes/cinematics/PurpleCat.tscn").instantiate()
	cat.position = d.at if d is Dictionary else position
	level.world_root.add_child(cat)
	cat.setup(level, sprite.flip_h)
	transformed.emit(cat)


# --------------------------------------------------------------------- daño
func hit_by(projectile: Projectile) -> bool:
	if is_defeated():
		return true
	if invulnerable:
		level.effects.sparkle(projectile.position.x, projectile.position.y, 3)
		return true
	var dmg := projectile.weapon.boss_damage if projectile.weapon else 1
	take_damage(dmg)
	return true


func take_damage(dmg: int) -> void:
	if is_defeated() or invulnerable:
		return
	hp = maxi(0, hp - dmg)
	GameState.set_v("bossHp", hp)
	AudioManager.play("boss_hit")
	flash.set_shader_parameter("flash", 1.0)
	level.after(60, func(): if is_instance_valid(self): flash.set_shader_parameter("flash", 0.0))
	var ratio := float(hp) / max_hp
	if hp <= 0:
		fsm.set_state("DEFEATED")
	elif phase == 1 and ratio <= 0.65:
		phase = 2
		fsm.set_state("HURT")
	elif phase == 2 and ratio <= 0.30:
		phase = 3
		fsm.set_state("HURT")
	elif fsm.is_state("STUNNED"):
		Anim.show_frame(sprite, "hurt", int(now / 200.0) % 2)
