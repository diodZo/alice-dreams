class_name LunaEstelar
extends Area2D
## Luna Estelar, jefa del Mundo 5: luna creciente envuelta en nubes que flota sobre el trono
## lunar con estrellas orbitando a su alrededor. Misma interfaz que Nubarrón, Garabato, Rey
## Siestón y Rey Patoburbuja (setup, intro, hit_by, fsm, hp, defeated_at...).
## Tres fases; cada ataque tiene aviso visual ("!", destello y pose de anticipación) y va
## seguido de un descanso vulnerable.
##  1 Destellos nocturnos (100-65 %): estrellitas, movimiento lateral suave y embestidas breves.
##  2 Órbita celestial (65-30 %): giro lunar, estrellas en órbita, ondas cósmicas, más movilidad.
##  3 Tormenta de constelaciones (30-0 %): aura cósmica, estrellas múltiples, giro con anillo de
##    energía y lluvia de estrellas con huecos marcados. Siempre esquivable.

signal defeated_at(x: float, y: float)
const MAX_HP := 50
## Altura de vuelo sobre el suelo de la arena (px).
const HOVER := 14.0
const PHASES := {
	1: {"speed": 38.0, "interval": 1600.0, "rest": 1500.0, "orbit": 1.6, "pattern": ["STAR_SHOT", "DASH", "STAR_SHOT"]},
	2: {"speed": 56.0, "interval": 1250.0, "rest": 1350.0, "orbit": 2.4, "pattern": ["SPIN", "ORBIT", "WAVE", "STAR_SHOT"]},
	3: {"speed": 66.0, "interval": 1050.0, "rest": 1450.0, "orbit": 3.2, "pattern": ["COSMIC", "STARFALL", "SPIN_RING", "MULTI_SHOT", "ORBIT"]},
}

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape
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
var hover_y := 0.0
var dir := -1
var invulnerable := true
var body_enabled := false
var flash: ShaderMaterial
var bob := 0.0
## Estrellitas decorativas que orbitan siempre a su alrededor (giran más lento al dormirse).
var orbit_deco: Array[Sprite2D] = []
var orbit_angle := 0.0
var orbit_speed := 1.6
## Proyectiles en órbita del ataque ORBIT (se sueltan hacia fuera al terminar).
var orbiters: Array = []
var orbit_radius := 40.0


func setup(owner_level: Node, boss_cfg: Dictionary) -> void:
	level = owner_level
	cfg = boss_cfg
	min_x = float(cfg.minX) * C.TILE + 40
	max_x = float(cfg.maxX) * C.TILE - 40
	floor_y = float(cfg.floorY)
	hover_y = floor_y - HOVER
	position = Vector2(float(cfg.homeX) * C.TILE, -80)


func _ready() -> void:
	z_index = C.Z_ENEMY + 2
	collision_layer = C.L_BOSS
	collision_mask = 0
	monitoring = false
	set_meta("kind", "boss")
	set_meta("entity", self)
	sprite.sprite_frames = Assets.sprite_frames("luna_estelar")
	Anim.set_origin(sprite, Assets.cell_size("luna_estelar"), 0.5, 1.0)
	flash = ShaderMaterial.new()
	flash.shader = preload("res://resources/effects/flash.gdshader")
	sprite.material = flash
	fsm = StateMachine.new(self)
	for i in 4:
		var s := Sprite2D.new()
		s.texture = Assets.frame("w5_fx", "mini_star" if i % 2 == 0 else "spark_gold")
		s.z_index = 1
		add_child(s)
		orbit_deco.append(s)
	_place_orbit_deco()
	set_body_enabled(false)


var player: Player:
	get: return level.player
var now: float:
	get: return level.now


func is_defeated() -> bool: return fsm.is_state("DEFEATED")
func phase_data() -> Dictionary: return PHASES[phase]
func set_body_enabled(on: bool) -> void:
	body_enabled = on
	shape.set_deferred("disabled", not on)
func intro() -> void: fsm.set_state("INTRO")
func anim(anim_name: String, ignore := true) -> void: Anim.play(sprite, anim_name, ignore)
func face_player() -> void: sprite.flip_h = player.position.x < position.x
func facing() -> int: return -1 if sprite.flip_h else 1
func after(ms: float, fn: Callable) -> void:
	timers.add(now, ms, func():
		if not is_defeated(): fn.call())
## Centro del cuerpo (la luna), punto de salida de los ataques.
func core() -> Vector2: return position + Vector2(0, -28)


func _physics_process(delta: float) -> void:
	if level == null: return
	timers.process(now)
	if fsm.current != "": fsm.update(now, delta * 1000.0)
	orbit_angle += orbit_speed * delta
	_place_orbit_deco()
	if body_enabled and fsm.current != "INTRO" and not is_defeated():
		position.x = clampf(position.x + velocity.x * delta, min_x, max_x)
		# flota: vaivén suave entre las nubes
		bob += delta
		sprite.position.y = sin(bob * 2.2) * 2.5
	_update_orbiters()


func _place_orbit_deco() -> void:
	for i in orbit_deco.size():
		var a := orbit_angle + i * TAU / orbit_deco.size()
		orbit_deco[i].position = Vector2(cos(a) * 46.0, -30 + sin(a) * 16.0)
		# por detrás de la luna en la mitad superior de la órbita
		orbit_deco[i].z_index = 1 if sin(a) > 0 else -1


func _enter_INTRO(_p: String, _d: Variant) -> void:
	anim("idle")
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "position:y", hover_y, 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		level.camera.shake(240, 0.004)
		level.effects.sparkle(position.x, position.y - 30, 16)
		AudioManager.play("twinkle"))
	tw.tween_interval(0.5)
	tw.tween_callback(func(): invulnerable = false; fsm.set_state("IDLE"))


func _enter_IDLE(_p: String, _d: Variant) -> void: anim("move")
func _update_IDLE(_t: float, _d: float) -> void:
	if position.x <= min_x: dir = 1
	elif position.x >= max_x: dir = -1
	velocity.x = dir * float(phase_data().speed)
	sprite.flip_h = dir < 0
	position.y = move_toward(position.y, hover_y, 1.0)
	if fsm.elapsed > float(phase_data().interval):
		var p: Array = phase_data().pattern
		fsm.set_state(p[pattern_index % p.size()])
		pattern_index += 1


## Descanso vulnerable: brillo dorado para que se lea "¡ahora!".
func _enter_REST(_p: String, _d: Variant) -> void:
	velocity.x = 0
	anim("idle")
	level.effects.glow_flash(core(), C.YELLOW, 2, 5, float(phase_data().rest), 0.45, 0)
func _update_REST(_t: float, _d: float) -> void:
	position.y = move_toward(position.y, hover_y, 1.0)
	if fsm.elapsed > float(phase_data().rest): fsm.set_state("IDLE")


## Aviso de ataque: "!" sobre la luna y destello.
func warn(ms: float) -> void:
	level.effects.glow_flash(core(), C.YELLOW, 2, 6, ms, 0.9, 2)
	var mark := PixelText.make("!", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW, "scale": 2})
	mark.position = position + Vector2(0, -78)
	mark.z_index = C.Z_UI_WORLD
	level.fx_root.add_child(mark)
	var tw := mark.create_tween().set_parallel()
	tw.tween_property(mark, "position:y", mark.position.y - 6, ms / 1000.0)
	tw.tween_property(mark, "modulate:a", 0.0, ms / 1000.0)
	tw.chain().tween_callback(mark.queue_free)


func _shot(cfg_extra: Dictionary) -> Projectile:
	var c := {"owner": "boss", "texture": "w5_fx", "damage": 1, "lifespan": 3600, "frame": "mini_star", "body": 9, "kind": "boss_star"}
	c.merge(cfg_extra, true)
	return level.spawn_projectile("boss", c)


## Estrella dirigida a Alice desde el frente de la luna.
func _aimed(speed: float, spread_deg := 0.0, extra := {}) -> void:
	var from := core() + Vector2(facing() * 30, 4)
	var target := player.position + Vector2(0, -15)
	var v := (target - from).normalized().rotated(deg_to_rad(spread_deg)) * speed
	var c := {"x": from.x, "y": from.y, "vx": v.x, "vy": v.y, "spin": 300}
	c.merge(extra, true)
	_shot(c)


# ---------------------------------------------------------------- fase 1
## Destellos: carga una estrella (aviso) y lanza tres o cuatro estrellitas hacia Alice.
func _enter_STAR_SHOT(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "shoot", 0)
	warn(600)
	var n := 3 if phase == 1 else 4
	after(600, func(): anim("shoot", false))
	for i in n:
		after(650 + i * 280, func():
			_aimed(115.0 + phase * 10.0)
			AudioManager.play("twinkle"))
	after(650 + n * 280 + 300, func(): fsm.set_state("REST"))


## Embestida estelar breve: retrocede un poco (aviso), cruza parte de la arena con estela de
## cometa y frena. Se esquiva saltando a las nubes o por encima.
func _enter_DASH(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	anim("move")
	warn(750)
	var d := facing()
	var back := create_tween()
	back.tween_property(self, "position:x", clampf(position.x - d * 12, min_x, max_x), 0.6).set_trans(Tween.TRANS_SINE)
	after(750, func():
		velocity.x = d * 200
		AudioManager.play("rocket")
		_comet(d))
	after(1050, func(): _comet(d))
	after(1400, func(): velocity.x = 0)
	after(1700, func(): fsm.set_state("REST"))


func _comet(d: int) -> void:
	var c := Sprite2D.new()
	c.texture = Assets.frame("w5_fx", "comet")
	c.flip_h = d > 0
	c.position = core() + Vector2(-d * 30, 6)
	level.fx_root.add_child(c)
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(c.queue_free)


# ---------------------------------------------------------------- fase 2
## Giro lunar: gira sobre sí misma y lanza medias lunas de energía a ras de suelo (se saltan).
func _enter_SPIN(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	anim("spin")
	warn(700)
	after(700, func(): _blades(115.0))
	after(1500, func(): fsm.set_state("REST"))


func _blades(speed: float) -> void:
	for d in [-1, 1]:
		_shot({"x": position.x + d * 34, "y": floor_y - 14, "vx": d * speed, "vy": 0, "frame": "moon_blade", "body": 14,
			"kind": "moon_blade", "scale": 0.6, "spin": 540, "lifespan": 3800})
	level.camera.shake(140, 0.003)
	AudioManager.play("wind")


## Estrellas en órbita: seis estrellas giran a su alrededor y después salen disparadas hacia fuera
## en seis direcciones (siempre quedan huecos entre ellas).
func _enter_ORBIT(_p: String, _d: Variant) -> void:
	velocity.x = 0
	anim("spin")
	warn(650)
	after(650, func():
		orbiters.clear()
		orbit_radius = 26.0
		for i in 6:
			var p := _shot({"x": core().x, "y": core().y, "vx": 0, "vy": 0, "frame": "mini_star_b", "body": 8, "kind": "orbit_star", "lifespan": 5000})
			if p != null:
				orbiters.append({"p": p, "a": i * TAU / 6.0})
		AudioManager.play("twinkle"))
	after(2200, _release_orbiters)
	after(2900, func(): fsm.set_state("REST"))


func _update_orbiters() -> void:
	if orbiters.is_empty():
		return
	orbit_radius = move_toward(orbit_radius, 48.0, 0.8)
	var spin := 2.6 if phase < 3 else 3.2
	for o in orbiters:
		var p: Projectile = o.p
		if not is_instance_valid(p) or not p.active:
			continue
		o.a += spin / 60.0
		p.position = core() + Vector2(cos(o.a), sin(o.a) * 0.8) * orbit_radius


func _release_orbiters() -> void:
	for o in orbiters:
		var p: Projectile = o.p
		if is_instance_valid(p) and p.active:
			p.velocity = Vector2(cos(o.a), sin(o.a) * 0.8).normalized() * 95.0
	orbiters.clear()


## Ondas de energía cósmica que recorren el suelo a ambos lados (se saltan).
func _enter_WAVE(_p: String, _d: Variant) -> void:
	velocity.x = 0
	Anim.show_frame(sprite, "cosmic", 0)
	warn(650)
	after(650, func(): _waves(120.0))
	if phase == 3:
		after(1400, func(): _waves(145.0))
	after(1500 if phase == 2 else 2200, func(): fsm.set_state("REST"))


func _waves(speed: float) -> void:
	for d in [-1, 1]:
		_shot({"x": position.x + d * 36, "y": floor_y - 10, "vx": d * speed, "vy": 0, "frame": "dust_ring", "body": 12,
			"kind": "cosmic_wave", "lifespan": 4000, "scale": 1.2})
	level.effects.sparkle(position.x, floor_y - 10, 10)
	AudioManager.play("cloud_boom")


# ---------------------------------------------------------------- fase 3
## Aura cósmica ampliada: la luna se envuelve en su aura y suelta un anillo de doce estrellas
## lentas con un hueco seguro de tres estrellas (cada vez en un sitio distinto).
func _enter_COSMIC(_p: String, _d: Variant) -> void:
	velocity.x = 0
	anim("cosmic")
	warn(800)
	after(800, func():
		var gap := randi() % 12
		for i in 12:
			if (i - gap + 12) % 12 <= 2:
				continue
			var a := i * TAU / 12.0
			_shot({"x": core().x, "y": core().y, "vx": cos(a) * 80, "vy": sin(a) * 80, "frame": "mini_star", "spin": 240, "lifespan": 3600})
		level.effects.glow_flash(core(), C.rgb(0xd4b8ff), 2, 8, 500, 0.8, 1)
		AudioManager.play("cloud_boom"))
	after(1900, func(): fsm.set_state("REST"))


## Lluvia de estrellas invocada: se marcan antes las columnas donde caerán; tres columnas
## seguidas quedan libres.
func _enter_STARFALL(_p: String, _d: Variant) -> void:
	velocity.x = 0
	anim("cosmic")
	warn(800)
	var cols := 9
	var safe := randi() % (cols - 2) + 1
	for i in cols:
		if absi(i - safe) <= 1:
			continue
		var x := min_x - 20 + i * (max_x - min_x + 40) / float(cols - 1)
		var k := i
		after(100, func(): level.effects.glow_flash(Vector2(x, floor_y - 4), C.YELLOW, 1, 2.4, 750, 0.7, 0))
		after(850 + (k % 3) * 140, func():
			_shot({"x": x, "y": -16, "vx": 0, "vy": 150, "gravity": 80, "frame": "star_trail", "body": 9, "kind": "falling_star", "lifespan": 3000, "rotate": true}))
	after(2300, func(): fsm.set_state("REST"))


## Giro con anillo de energía: dos anillos de ocho estrellas que se abren hacia fuera, el
## segundo girado medio paso (los huecos del primero son los sitios seguros del segundo).
func _enter_SPIN_RING(_p: String, _d: Variant) -> void:
	velocity.x = 0
	anim("spin")
	warn(700)
	for r in 2:
		var off := r * PI / 8.0
		after(700 + r * 650, func():
			for i in 8:
				var a := off + i * TAU / 8.0
				_shot({"x": core().x, "y": core().y, "vx": cos(a) * 75, "vy": sin(a) * 75, "frame": "mini_star_b", "body": 8, "kind": "orbit_star", "lifespan": 3400})
			level.effects.glow_flash(core(), C.rgb(0xf7a8d8), 2, 7, 400, 0.8, 1)
			AudioManager.play("wind"))
	after(2100, func(): fsm.set_state("REST"))


## Estrellas múltiples: abanico de cinco estrellas hacia Alice (dos veces).
func _enter_MULTI_SHOT(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "shoot", 0)
	warn(650)
	for r in 2:
		after(650 + r * 600, func():
			anim("shoot", false)
			face_player()
			for s in [-28.0, -14.0, 0.0, 14.0, 28.0]:
				_aimed(105.0, s)
			AudioManager.play("twinkle"))
	after(2000, func(): fsm.set_state("REST"))


func _enter_PHASE_CHANGE(_p: String, _d: Variant) -> void:
	invulnerable = true
	velocity.x = 0
	pattern_index = 0
	timers.clear()
	_release_orbiters()
	orbit_speed = float(phase_data().orbit)
	if phase == 3:
		anim("cosmic")
	else:
		Anim.show_frame(sprite, "hurt", 1)
	level.camera.shake(350, 0.005)
	level.effects.glow_flash(core(), C.rgb(0xd4b8ff), 2, 9, 900, 0.8, 1)
	GameState.show_toast("¡Órbita celestial!" if phase == 2 else "¡Tormenta de constelaciones!")
	after(1200, func(): invulnerable = false; fsm.set_state("IDLE"))


# ---------------------------------------------------------------- derrota
## 1 pierde energía 2 sus estrellas giran más lento 3 la expresión se suaviza 4 se recuesta
## entre nubes 5 destellos y partículas 6 pose dormida 7 entrega la estrella dorada.
func _enter_DEFEATED(_p: String, _d: Variant) -> void:
	timers.clear()
	_release_orbiters()
	invulnerable = true
	velocity = Vector2.ZERO
	set_body_enabled(false)
	sprite.position.y = 0
	Anim.show_frame(sprite, "hurt", 0)
	AudioManager.play("enemy_defeat")
	level.camera.shake(260, 0.004)
	create_tween().tween_property(self, "orbit_speed", 0.25, 2.6).set_trans(Tween.TRANS_SINE)
	var ref: WeakRef = weakref(self)
	var alive := func() -> bool: return ref.get_ref() != null
	level.after(700, func():
		if alive.call(): Anim.show_frame(sprite, "hurt", 1))
	level.after(1400, func():
		if not alive.call(): return
		Anim.show_frame(sprite, "defeated", 0)
		create_tween().tween_property(self, "position:y", floor_y - 4, 1.0).set_trans(Tween.TRANS_SINE))
	level.after(2500, func():
		if not alive.call(): return
		Anim.show_frame(sprite, "defeated", 1)
		create_tween().tween_property(self, "position:y", floor_y + 2, 0.6).set_trans(Tween.TRANS_SINE)
		_clouds_front())
	level.after(3100, func():
		if not alive.call(): return
		level.effects.confetti(position.x, position.y - 40, 60)
		level.effects.sparkle(position.x, position.y - 24, 18)
		for s in orbit_deco:
			s.create_tween().tween_property(s, "modulate:a", 0.0, 0.8)
		for i in 6:
			var b := Sprite2D.new()
			b.texture = Assets.frame("w5_fx", ["spark_gold", "spark_pink", "spark_blue"][i % 3])
			b.position = position + Vector2(randf_range(-40, 40), -16)
			level.fx_root.add_child(b)
			var tw := b.create_tween().set_parallel()
			tw.tween_property(b, "position:y", b.position.y - 50 - randf() * 30, 1.4)
			tw.tween_property(b, "modulate:a", 0.0, 1.4)
			tw.chain().tween_callback(b.queue_free))
	level.after(3800, func():
		if not alive.call(): return
		var z := PixelText.make("Z z z", {"origin": Vector2(0.5, 0.5), "tint": C.rgb(0xfff3a0), "scale": 1})
		z.position = position + Vector2(10, -48)
		level.fx_root.add_child(z)
		defeated_at.emit(position.x - 70, position.y - 36))


## Nubes de la derrota por delante de la luna recostada (se dibujan sobre ella).
func _clouds_front() -> void:
	var f := Sprite2D.new()
	f.texture = Assets.frame("w5_fx", "sleep_cloud")
	Anim.set_origin(f, f.texture.get_size(), 0.5, 1.0)
	f.position = Vector2(position.x, floor_y + 2)
	f.z_index = C.Z_FX
	f.modulate.a = 0.0
	level.fx_root.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "modulate:a", 0.85, 0.6)
	tw.tween_interval(2.2)
	tw.tween_property(f, "modulate:a", 0.0, 1.0)
	tw.tween_callback(f.queue_free)


func hit_by(projectile: Projectile) -> bool:
	if is_defeated(): return true
	if invulnerable:
		level.effects.sparkle(projectile.position.x, projectile.position.y, 3)
		return true
	var dmg := projectile.weapon.boss_damage if projectile.weapon else 1
	hp = maxi(0, hp - dmg)
	GameState.set_v("bossHp", hp)
	AudioManager.play("boss_hit")
	flash.set_shader_parameter("flash", 1.0)
	level.after(60, func(): if is_instance_valid(self): flash.set_shader_parameter("flash", 0.0))
	var ratio := float(hp) / max_hp
	if hp <= 0: fsm.set_state("DEFEATED")
	elif phase == 1 and ratio <= 0.65: phase = 2; fsm.set_state("PHASE_CHANGE")
	elif phase == 2 and ratio <= 0.30: phase = 3; fsm.set_state("PHASE_CHANGE")
	return true
