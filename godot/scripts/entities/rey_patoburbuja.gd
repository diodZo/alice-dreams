class_name ReyPatoburbuja
extends Area2D
## Rey Patoburbuja, jefe del Mundo 4: pato de goma coronado que flota entre la espuma.
## Misma interfaz que Nubarrón, Garabato y Rey Siestón (setup, intro, hit_by, fsm, hp...).
## Tres fases; cada ataque tiene aviso visual ("!", destello y pose de anticipación) y va
## seguido de un descanso vulnerable.
##  1 Burbujas reales (100-65 %): burbujas en línea recta, golpes de agua suaves, flota despacio.
##  2 Oleaje juguetón (65-30 %): olas pequeñas, burbujas grandes, remolinos pequeños, más rápido.
##  3 Tormenta de espuma (30-0 %): remolino amplio, lluvia de burbujas y ataques encadenados.

signal defeated_at(x: float, y: float)
const MAX_HP := 50
const PHASES := {
	1: {"speed": 34.0, "interval": 1600.0, "rest": 1500.0, "pattern": ["SPIT", "SLAP", "SPIT"]},
	2: {"speed": 50.0, "interval": 1300.0, "rest": 1350.0, "pattern": ["BIG_BUBBLE", "WAVE", "SMALL_WHIRL", "SPIT"]},
	3: {"speed": 64.0, "interval": 1050.0, "rest": 1450.0, "pattern": ["WHIRL", "RAIN", "COMBO", "BIG_BUBBLE", "WAVE"]},
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
var dir := -1
var invulnerable := true
var body_enabled := false
var flash: ShaderMaterial
var bob := 0.0


func setup(owner_level: Node, boss_cfg: Dictionary) -> void:
	level = owner_level
	cfg = boss_cfg
	min_x = float(cfg.minX) * C.TILE + 40
	max_x = float(cfg.maxX) * C.TILE - 40
	floor_y = float(cfg.floorY)
	position = Vector2(float(cfg.homeX) * C.TILE, -80)


func _ready() -> void:
	z_index = C.Z_ENEMY + 2
	collision_layer = C.L_BOSS
	collision_mask = 0
	monitoring = false
	set_meta("kind", "boss")
	set_meta("entity", self)
	sprite.sprite_frames = Assets.sprite_frames("patoburbuja")
	Anim.set_origin(sprite, Assets.cell_size("patoburbuja"), 0.5, 1.0)
	flash = ShaderMaterial.new()
	flash.shader = preload("res://resources/effects/flash.gdshader")
	sprite.material = flash
	fsm = StateMachine.new(self)
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


func _physics_process(delta: float) -> void:
	if level == null: return
	timers.process(now)
	if fsm.current != "": fsm.update(now, delta * 1000.0)
	if body_enabled and fsm.current != "INTRO" and not is_defeated():
		position.x = clampf(position.x + velocity.x * delta, min_x, max_x)
		# flota: un vaivén suave sobre la espuma
		bob += delta
		sprite.position.y = sin(bob * 2.4) * 2.0


func _enter_INTRO(_p: String, _d: Variant) -> void:
	anim("idle")
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "position:y", floor_y, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		level.camera.shake(260, 0.005)
		_splash_ring(10)
		AudioManager.play("splash"))
	tw.tween_interval(0.5)
	tw.tween_callback(func(): invulnerable = false; fsm.set_state("IDLE"))


func _enter_IDLE(_p: String, _d: Variant) -> void: anim("move")
func _update_IDLE(_t: float, _d: float) -> void:
	if position.x <= min_x: dir = 1
	elif position.x >= max_x: dir = -1
	velocity.x = dir * float(phase_data().speed)
	sprite.flip_h = dir < 0
	if fsm.elapsed > float(phase_data().interval):
		var p: Array = phase_data().pattern
		fsm.set_state(p[pattern_index % p.size()])
		pattern_index += 1


## Descanso vulnerable: brillo amarillo para que se lea "¡ahora!".
func _enter_REST(_p: String, _d: Variant) -> void:
	velocity.x = 0
	anim("idle")
	level.effects.glow_flash(position + Vector2(0, -32), C.YELLOW, 2, 5, float(phase_data().rest), 0.45, 0)
func _update_REST(_t: float, _d: float) -> void:
	if fsm.elapsed > float(phase_data().rest): fsm.set_state("IDLE")


## Aviso de ataque: "!" sobre la corona y destello.
func warn(ms: float) -> void:
	level.effects.glow_flash(position + Vector2(0, -36), C.YELLOW, 2, 6, ms, 0.9, 2)
	var mark := PixelText.make("!", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW, "scale": 2})
	mark.position = position + Vector2(0, -88)
	mark.z_index = C.Z_UI_WORLD
	level.fx_root.add_child(mark)
	var tw := mark.create_tween().set_parallel()
	tw.tween_property(mark, "position:y", mark.position.y - 6, ms / 1000.0)
	tw.tween_property(mark, "modulate:a", 0.0, ms / 1000.0)
	tw.chain().tween_callback(mark.queue_free)


func _shot(cfg_extra: Dictionary) -> void:
	var c := {"owner": "boss", "texture": "w4_fx", "damage": 1, "lifespan": 3600}
	c.merge(cfg_extra, true)
	level.spawn_projectile("boss", c)


# ---------------------------------------------------------------- fase 1
## Burbujas en línea recta: mejillas infladas (aviso) y tres burbujas seguidas a la altura del pico.
func _enter_SPIT(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "spit", 0)
	warn(600)
	var n := 3 if phase == 1 else 4
	after(600, func(): anim("spit", false))
	for i in n:
		after(650 + i * 260, func():
			var d := facing()
			_shot({"x": position.x + d * 40, "y": position.y - 30, "vx": d * 125, "vy": 0, "frame": "bubble_m", "body": 9, "kind": "boss_bubble", "wobble": 1.0})
			AudioManager.play("shoot_bubble"))
	after(650 + n * 260 + 300, func(): fsm.set_state("REST"))


## Golpe de agua suave: chapotea y lanza dos salpicaduras cortas por el suelo, una a cada lado.
func _enter_SLAP(_p: String, _d: Variant) -> void:
	velocity.x = 0
	Anim.show_frame(sprite, "wave", 0)
	warn(550)
	after(550, func():
		anim("wave", false)
		level.camera.shake(140, 0.003)
		_splash_ring(6)
		for d in [-1, 1]:
			_shot({"x": position.x + d * 36, "y": floor_y - 8, "vx": d * 95, "vy": 0, "frame": "splash_2", "body": 10, "kind": "wave", "lifespan": 1300}))
	after(1400, func(): fsm.set_state("REST"))


# ---------------------------------------------------------------- fase 2
## Burbuja grande: lenta y en arco suave, fácil de saltar.
func _enter_BIG_BUBBLE(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "spit", 0)
	warn(650)
	var n := 2 if phase == 2 else 3
	after(650, func(): anim("spit", false))
	for i in n:
		after(700 + i * 450, func():
			var d := facing()
			_shot({"x": position.x + d * 42, "y": position.y - 34, "vx": d * (80 + i * 15), "vy": -40, "gravity": 30, "frame": "bubble_l", "body": 14,
				"kind": "boss_bubble", "scale": 1.3, "wobble": 2.0, "lifespan": 4200})
			AudioManager.play("bubble_trap"))
	after(700 + n * 450 + 400, func(): fsm.set_state("REST"))


## Olas pequeñas de espuma a ambos lados (se saltan).
func _enter_WAVE(_p: String, _d: Variant) -> void:
	velocity.x = 0
	Anim.show_frame(sprite, "wave", 0)
	warn(650)
	after(650, func():
		anim("wave", false)
		_waves(125.0))
	if phase == 3:
		after(1500, func(): _waves(150.0))
	after(1500 if phase == 2 else 2300, func(): fsm.set_state("REST"))


func _waves(speed: float) -> void:
	for d in [-1, 1]:
		_shot({"x": position.x + d * 40, "y": floor_y - 9, "vx": d * speed, "vy": 0, "frame": "splash_4", "body": 12, "kind": "wave", "lifespan": 4000})
	level.camera.shake(160, 0.003)
	_splash_ring(10)
	AudioManager.play("splash")


## Remolinos pequeños que avanzan despacio por el suelo hacia Alice.
func _enter_SMALL_WHIRL(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	anim("whirl")
	warn(700)
	after(750, func(): _whirlpool(facing(), 70.0))
	after(1500, func(): fsm.set_state("REST"))


func _whirlpool(d: int, speed: float) -> void:
	_shot({"x": position.x + d * 34, "y": floor_y - 10, "vx": d * speed, "vy": 0, "frame": "whirl", "body": 14, "kind": "whirl", "lifespan": 4800, "spin": 260, "scale": 1.2})
	AudioManager.play("wind")


# ---------------------------------------------------------------- fase 3
## Remolino amplio: gira sobre sí mismo, cruza la arena y suelta dos remolinos al frenar.
func _enter_WHIRL(_p: String, _d: Variant) -> void:
	velocity.x = 0
	face_player()
	anim("whirl")
	warn(700)
	after(700, func(): velocity.x = facing() * 150)
	after(1600, func():
		velocity.x = 0
		_whirlpool(-1, 80.0)
		_whirlpool(1, 80.0))
	after(2100, func(): fsm.set_state("REST"))


## Lluvia de burbujas: cae en columnas con huecos seguros que se ven desde el principio.
func _enter_RAIN(_p: String, _d: Variant) -> void:
	velocity.x = 0
	anim("spit", false)
	warn(800)
	var cols := 9
	var safe := randi() % (cols - 2) + 1
	for i in cols:
		if absi(i - safe) <= 1:
			continue
		var x := min_x - 20 + i * (max_x - min_x + 40) / float(cols - 1)
		var k := i
		# marca dónde caerá cada burbuja
		after(100, func(): level.effects.glow_flash(Vector2(x, floor_y - 4), C.rgb(0xc8f0ff), 1, 2, 700, 0.6, 0))
		after(800 + (k % 3) * 120, func():
			_shot({"x": x, "y": -12, "vx": 0, "vy": 120, "gravity": 60, "frame": "bubble_m", "body": 9, "kind": "rain_bubble", "lifespan": 3000, "wobble": 1.0}))
	after(2200, func(): fsm.set_state("REST"))


## Ataques encadenados: ola y, sin pausa, burbujas en línea (cada uno con su aviso).
func _enter_COMBO(_p: String, _d: Variant) -> void:
	velocity.x = 0
	Anim.show_frame(sprite, "wave", 0)
	warn(600)
	after(600, func():
		anim("wave", false)
		_waves(130.0))
	after(1300, func():
		face_player()
		Anim.show_frame(sprite, "spit", 0)
		warn(450))
	for i in 3:
		after(1750 + i * 240, func():
			anim("spit", false)
			var d := facing()
			_shot({"x": position.x + d * 40, "y": position.y - 30, "vx": d * 140, "vy": 0, "frame": "bubble_m", "body": 9, "kind": "boss_bubble"}))
	after(2900, func(): fsm.set_state("REST"))


func _enter_PHASE_CHANGE(_p: String, _d: Variant) -> void:
	invulnerable = true
	velocity.x = 0
	pattern_index = 0
	timers.clear()
	Anim.show_frame(sprite, "hurt", 1)
	level.camera.shake(350, 0.005)
	_splash_ring(14)
	GameState.show_toast("¡Oleaje juguetón!" if phase == 2 else "¡Tormenta de espuma!")
	after(1200, func(): invulnerable = false; fsm.set_state("IDLE"))


# ---------------------------------------------------------------- derrota
## 1 pierde energía (mareado) 2 la corona se ladea 3 flota despacio 4 se hunde un poco en la
## espuma 5 estrellas y burbujas 6 queda dormido, adorable 7 entrega la estrella dorada.
func _enter_DEFEATED(_p: String, _d: Variant) -> void:
	timers.clear()
	invulnerable = true
	velocity = Vector2.ZERO
	set_body_enabled(false)
	sprite.position.y = 0
	Anim.show_frame(sprite, "hurt", 0)
	AudioManager.play("enemy_defeat")
	level.camera.shake(260, 0.004)
	var ref: WeakRef = weakref(self)
	var alive := func() -> bool: return ref.get_ref() != null
	level.after(700, func():
		if alive.call(): Anim.show_frame(sprite, "hurt", 1))
	level.after(1400, func():
		if not alive.call(): return
		Anim.show_frame(sprite, "defeated", 0)
		create_tween().tween_property(self, "position:y", floor_y - 14, 1.1).set_trans(Tween.TRANS_SINE))
	level.after(2600, func():
		if not alive.call(): return
		Anim.show_frame(sprite, "defeated", 1)
		create_tween().tween_property(self, "position:y", floor_y + 6, 0.7).set_trans(Tween.TRANS_SINE)
		_foam_front()
		AudioManager.play("splash"))
	level.after(3300, func():
		if not alive.call(): return
		level.effects.confetti(position.x, position.y - 40, 60)
		level.effects.sparkle(position.x, position.y - 30, 18)
		for i in 6:
			var b := Sprite2D.new()
			b.texture = Assets.frame("w4_fx", "spark_star" if i % 2 == 0 else "bubble_m")
			b.position = position + Vector2(randf_range(-40, 40), -20)
			level.fx_root.add_child(b)
			var tw := b.create_tween().set_parallel()
			tw.tween_property(b, "position:y", b.position.y - 50 - randf() * 30, 1.4)
			tw.tween_property(b, "modulate:a", 0.0, 1.4)
			tw.chain().tween_callback(b.queue_free))
	level.after(3900, func():
		if not alive.call(): return
		Anim.show_frame(sprite, "defeated", 0)
		var tw := create_tween()
		tw.tween_property(self, "position:y", floor_y, 0.8).set_trans(Tween.TRANS_SINE)
		var z := PixelText.make("Z z z", {"origin": Vector2(0.5, 0.5), "tint": C.rgb(0xc8f0ff), "scale": 1})
		z.position = position + Vector2(0, -70)
		level.fx_root.add_child(z)
		defeated_at.emit(position.x - 70, position.y - 36))


## Espuma por delante del pato mientras se hunde (se dibuja sobre él).
func _foam_front() -> void:
	for i in 4:
		var f := Sprite2D.new()
		f.texture = Assets.frame("w4_fx", "foam_pile" if i % 2 == 0 else "crab_foam")
		f.position = Vector2(position.x - 36 + i * 24, floor_y - 4)
		f.z_index = C.Z_FX
		level.fx_root.add_child(f)
		var tw := f.create_tween()
		tw.tween_interval(2.0)
		tw.tween_property(f, "modulate:a", 0.0, 0.8)
		tw.tween_callback(f.queue_free)


func _splash_ring(count: int) -> void:
	level.effects.poof(position.x - 30, floor_y - 4, count / 2)
	level.effects.poof(position.x + 30, floor_y - 4, count / 2)
	level.effects.sparkle(position.x, floor_y - 10, count / 2)


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
