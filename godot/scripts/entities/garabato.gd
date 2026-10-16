class_name Garabato
extends Area2D
## GARABATO, EL REY DE LOS CRAYONES — jefe del Mundo 2 (caja viviente de crayones de jefemundo2.png).
## Misma interfaz que Nubarrón (setup, intro, hit_by, defeated_at...) para compartir la arena.
##
## Fases según la vida restante:
##  1 Lluvia de colores    (100-65 %): disparos de pintura arcoíris, salpicaduras rasantes, vaivén.
##  2 Remolino de crayones (65-30 %):  remolinos en distintas trayectorias, crayones orbitando, más rápido.
##  3 El Gran Garabato     (30-0 %):   remolinos grandes, ráfagas, lluvia de crayones y pintura en el suelo.
## Todos los ataques tienen aviso ("!" + destello) y huecos; tras cada uno descansa (ventana de contraataque).

signal defeated_at(x: float, y: float)

const PHASES := {
	1: {"speed": 40.0, "interval": 1400.0, "rest": 1400.0, "pattern": ["SHOOT", "SPLASH", "SHOOT", "SPLASH"]},
	2: {"speed": 66.0, "interval": 1150.0, "rest": 1300.0, "pattern": ["SWIRL", "ORBIT", "SHOOT", "SWIRL", "SPLASH", "ORBIT"]},
	3: {"speed": 92.0, "interval": 900.0, "rest": 1500.0, "pattern": ["RAIN", "BIG_SWIRL", "PAINT_FLOOR", "ORBIT", "SHOOT", "RAIN", "BIG_SWIRL"]},
}
const MAX_HP := 48
const CRAYONS := ["crayon_red", "crayon_yellow", "crayon_blue", "crayon_purple", "crayon_green"]
const RAINBOW := [0xf7489a, 0xff9f5a, 0xffe082, 0x7ee07e, 0x78c5f8, 0xb9a7f4]

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape

var level: Node
var cfg: Dictionary
var fsm: StateMachine
var timers := Timers.new()
var velocity := Vector2.ZERO
var max_hp := MAX_HP
var hp := MAX_HP
var phase := 1
var pattern_index := 0
var home_x := 0.0
var min_x := 0.0
var max_x := 0.0
var floor_y := 0.0
var dir := -1
var invulnerable := true
var body_enabled := false
var rest_glow: Sprite2D
var orbit: Array[Area2D] = []
var orbit_angle := 0.0
var _markers: Array = []
var _flash_material: ShaderMaterial


## cfg: { homeX, minX, maxX (teselas), floorY (px) }
func setup(owner_level: Node, boss_cfg: Dictionary) -> void:
	level = owner_level
	cfg = boss_cfg
	home_x = float(cfg.homeX) * C.TILE
	min_x = float(cfg.minX) * C.TILE + 40
	max_x = float(cfg.maxX) * C.TILE - 40
	floor_y = float(cfg.floorY)
	position = Vector2(home_x, -60)


func _ready() -> void:
	z_index = C.Z_ENEMY + 2
	collision_layer = C.L_BOSS
	collision_mask = 0
	monitoring = false
	set_meta("kind", "boss")
	set_meta("entity", self)
	sprite.sprite_frames = Assets.sprite_frames("garabato")
	Anim.set_origin(sprite, Assets.cell_size("garabato"), 0.5, 1.0)
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = preload("res://resources/effects/flash.gdshader")
	sprite.material = _flash_material
	fsm = StateMachine.new(self)
	set_body_enabled(false)


var player: Player:
	get:
		return level.player


var now: float:
	get:
		return level.now


func is_defeated() -> bool:
	return fsm.is_state("DEFEATED")


func phase_data() -> Dictionary:
	return PHASES[phase]


func set_body_enabled(on: bool) -> void:
	body_enabled = on
	shape.set_deferred("disabled", not on)


func anim(anim_name: String, ignore := true) -> void:
	Anim.play(sprite, anim_name, ignore)


func after(ms: float, fn: Callable) -> void:
	timers.add(now, ms, func():
		if not is_defeated():
			fn.call())


func clear_timers() -> void:
	timers.clear()


func intro() -> void:
	fsm.set_state("INTRO")


func face_player() -> void:
	sprite.flip_h = player.position.x < position.x


func facing() -> int:
	return -1 if sprite.flip_h else 1


func _physics_process(delta: float) -> void:
	if level == null:
		return
	timers.process(now)
	if fsm.current != "":
		fsm.update(now, delta * 1000.0)
	if body_enabled and fsm.current != "INTRO" and not is_defeated():
		position.x = clampf(position.x + velocity.x * delta, min_x - 40, max_x + 40)
	_update_orbit(delta)


func _tween() -> Tween:
	return create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)


func _walk(speed_mul := 1.0) -> void:
	if position.x <= min_x:
		dir = 1
	elif position.x >= max_x:
		dir = -1
	velocity.x = dir * phase_data().speed * speed_mul
	sprite.flip_h = dir < 0


# --------------------------------------------------------------------- estados
func _enter_INTRO(_prev: String, _data: Variant) -> void:
	anim("idle")
	var tw := _tween()
	tw.tween_property(self, "position:y", floor_y, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		level.camera.shake(300, 0.006)
		level.effects.poof(position.x, floor_y, 18))
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		invulnerable = false
		fsm.set_state("IDLE"))


func _enter_IDLE(_prev: String, _data: Variant) -> void:
	anim("move")


func _update_IDLE(_time: float, _delta: float) -> void:
	_walk()
	if fsm.elapsed > phase_data().interval:
		var p: Array = phase_data().pattern
		var next: String = p[pattern_index % p.size()]
		pattern_index += 1
		fsm.set_state(next)


## Ventana de contraataque: se detiene, ríe y brilla.
func _enter_REST(_prev: String, _data: Variant) -> void:
	velocity.x = 0
	anim("idle")
	rest_glow = Sprite2D.new()
	rest_glow.texture = Assets.generated("glow")
	rest_glow.scale = Vector2(5, 4)
	rest_glow.position = Vector2(0, -30)
	rest_glow.modulate = Color(C.YELLOW, 0.5)
	rest_glow.z_index = -1
	add_child(rest_glow)
	var tw := rest_glow.create_tween().set_loops()
	tw.tween_property(rest_glow, "modulate:a", 0.15, 0.3)
	tw.tween_property(rest_glow, "modulate:a", 0.5, 0.3)


func _update_REST(_time: float, _delta: float) -> void:
	if fsm.elapsed > phase_data().rest:
		fsm.set_state("IDLE")


func _exit_REST(_next: String) -> void:
	if rest_glow:
		rest_glow.queue_free()
		rest_glow = null


## Disparos de pintura arcoíris en parábola hacia la protagonista.
func _enter_SHOOT(_prev: String, _data: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "shoot", 0)
	warn(550)
	var shots := 3 if phase < 3 else 4
	for i in shots:
		after(550 + i * 300, func():
			anim("shoot", false)
			face_player()
			_paint_shot(i))
	after(550 + shots * 300 + 450, func(): fsm.set_state("REST"))


func _paint_shot(i: int) -> void:
	var sx := position.x + facing() * 50
	var sy := position.y - 34
	var t := 0.95
	var dx := clampf(player.position.x - sx + (i - 1) * 18, -300, 300)
	var dy := player.position.y - 10 - sy
	var g := 320.0
	level.spawn_projectile("boss", {
		"x": sx, "y": sy, "vx": dx / t, "vy": (dy - 0.5 * g * t * t) / t, "gravity": g,
		"texture": "w2_fx", "frame": "rainbow_burst", "scale": 0.55, "lifespan": 3000, "body": 12,
		"owner": "boss", "kind": "rainbow", "damage": 1, "spin": 240,
		"tint": C.rgb(RAINBOW[i % RAINBOW.size()]).lerp(Color.WHITE, 0.55),
	})
	AudioManager.play("shoot_paint")


## Salpicadura rasante por el suelo: se esquiva saltando.
func _enter_SPLASH(_prev: String, _data: Variant) -> void:
	velocity.x = 0
	face_player()
	Anim.show_frame(sprite, "shoot", 3)
	warn(600)
	after(600, func():
		anim("shoot", false)
		_ground_splash(facing())
		if phase == 3:
			_ground_splash(-facing()))
	after(1500, func(): fsm.set_state("REST"))


func _ground_splash(d: int) -> void:
	level.spawn_projectile("boss", {
		"x": position.x + d * 40, "y": floor_y - 7, "vx": d * 150, "vy": 0,
		"texture": "w2_fx", "frame": "paint_big", "lifespan": 3500, "body": 12,
		"owner": "boss", "kind": "splash", "damage": 1,
	})
	level.effects.paint_splat(position.x + d * 34, floor_y - 4, C.rgb(0xf7489a))
	AudioManager.play("shoot_paint")


## Remolinos multicolores con trayectorias onduladas a distintas alturas.
func _enter_SWIRL(_prev: String, _data: Variant) -> void:
	velocity.x = 0
	face_player()
	anim("swirl", false)
	warn(600)
	after(600, func():
		_swirl(facing(), -18, 0, 1.0)
		after(280, func(): _swirl(facing(), -48, 7, 1.0)))
	after(1700, func(): fsm.set_state("REST"))


func _swirl(d: int, dy: float, wobble: float, s: float) -> void:
	level.spawn_projectile("boss", {
		"x": position.x + d * 44, "y": floor_y + dy, "vx": d * 115, "vy": 0,
		"texture": "w2_fx", "frame": "swirl", "scale": 0.7 * s, "lifespan": 5000, "body": 14 * s,
		"owner": "boss", "kind": "swirl", "damage": 1, "spin": 400, "wobble": wobble,
	})
	AudioManager.play("wind")


## Crayones que giran alrededor del jefe mientras avanza más deprisa.
func _enter_ORBIT(_prev: String, _data: Variant) -> void:
	anim("spin")
	warn(500)
	after(500, _spawn_orbit)
	after(500 + 2600, func():
		_clear_orbit()
		fsm.set_state("REST"))


func _update_ORBIT(_time: float, _delta: float) -> void:
	if fsm.elapsed > 500:
		dir = 1 if player.position.x > position.x else -1
		velocity.x = dir * phase_data().speed * 1.25
		sprite.flip_h = dir < 0
	else:
		velocity.x = 0


func _exit_ORBIT(_next: String) -> void:
	_clear_orbit()


func _spawn_orbit() -> void:
	var n := 4 if phase < 3 else 5
	for i in n:
		var a := Area2D.new()
		var spr := Sprite2D.new()
		spr.texture = Assets.frame("w2_fx", CRAYONS[i % CRAYONS.size()])
		a.add_child(spr)
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 6
		cs.shape = circle
		a.add_child(cs)
		Trigger.configure(a, "hazard")
		a.z_index = z_index + 1
		level.fx_root.add_child(a)
		orbit.append(a)
	AudioManager.play("wind")


func _update_orbit(delta: float) -> void:
	if orbit.is_empty():
		return
	orbit_angle += delta * 3.2
	var center := position + Vector2(0, -30)
	for i in orbit.size():
		var a := orbit[i]
		if not is_instance_valid(a):
			continue
		var ang := orbit_angle + TAU * i / orbit.size()
		a.global_position = center + Vector2(cos(ang) * 52, sin(ang) * 34)
		a.rotation = ang + PI / 2


func _clear_orbit() -> void:
	for a in orbit:
		if is_instance_valid(a):
			level.effects.poof(a.global_position.x, a.global_position.y, 4)
			a.queue_free()
	orbit.clear()


## Lluvia de crayones: marcas de aviso en el suelo y huecos seguros entre ellas.
func _enter_RAIN(_prev: String, _data: Variant) -> void:
	velocity.x = 0
	anim("swirl", false)
	var count := 6
	var span := max_x + 40 - (min_x - 40)
	var gap := span / count
	var offset := randi_range(10, floori(gap) - 34)
	var xs: Array = []
	for i in count:
		xs.append(min_x - 40 + offset + i * gap)
	_markers.clear()
	for x in xs:
		var m := Sprite2D.new()
		m.texture = Assets.frame("world2_objects", "paint_pink_puddle")
		m.position = Vector2(x, floor_y - 2)
		m.modulate.a = 0.7
		level.fx_root.add_child(m)
		var tw := m.create_tween().set_loops()
		tw.tween_property(m, "modulate:a", 0.15, 0.12)
		tw.tween_property(m, "modulate:a", 0.7, 0.12)
		_markers.append(m)
	warn(1000)
	after(1000, func():
		_clear_markers()
		for i in xs.size():
			var x: float = xs[i]
			after(i * 70, func():
				level.spawn_projectile("boss", {
					"x": x, "y": -10, "vx": 0, "vy": 160, "gravity": 300,
					"texture": "w2_fx", "frame": CRAYONS[i % CRAYONS.size()], "lifespan": 2500, "body": 10,
					"owner": "boss", "kind": "crayon", "damage": 1, "rotate": true,
				})))
	after(2200, func(): fsm.set_state("REST"))


func _exit_RAIN(_next: String) -> void:
	_clear_markers()


func _clear_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()


## Remolinos grandes en abanico y ráfaga de pintura.
func _enter_BIG_SWIRL(_prev: String, _data: Variant) -> void:
	velocity.x = 0
	face_player()
	anim("swirl", false)
	warn(650)
	after(650, func():
		_swirl(facing(), -16, 0, 1.35)
		_swirl(-facing(), -16, 0, 1.35)
		after(350, func(): _swirl(facing(), -54, 8, 1.2)))
	after(1300, func():
		anim("shoot", false)
		for i in 3:
			_paint_shot(i))
	after(2300, func(): fsm.set_state("REST"))


## Cambio temporal del terreno: charcos de pintura rosa (lenta) y azul (resbaladiza).
func _enter_PAINT_FLOOR(_prev: String, _data: Variant) -> void:
	velocity.x = 0
	anim("shoot", false)
	warn(700)
	var left := (min_x - 40) / C.TILE
	var right := (max_x + 40) / C.TILE
	var a := randf_range(left + 2, (left + right) / 2.0 - 6)
	var b := randf_range((left + right) / 2.0 + 1, right - 7)
	for spot in [[a, "pink"], [b, "blue"]]:
		var m := Sprite2D.new()
		m.texture = Assets.frame("world2_objects", "paint_%s_puddle" % spot[1])
		m.position = Vector2((spot[0] + 2.5) * C.TILE, floor_y - 2)
		level.fx_root.add_child(m)
		var tw := m.create_tween().set_loops(4)
		tw.tween_property(m, "modulate:a", 0.2, 0.09)
		tw.tween_property(m, "modulate:a", 1.0, 0.09)
		tw.finished.connect(m.queue_free)
	after(700, func():
		for spot in [[a, "pink"], [b, "blue"]]:
			var p := PaintSurface.new().setup({"x": spot[0], "y": floor_y / C.TILE, "w": 5, "color": spot[1]})
			level.level_objects.objects.add_child(p)
			p.make_temporary(level, 5500)
			level.effects.paint_splat(p.position.x + 40, floor_y - 4, C.rgb(0xf7489a) if spot[1] == "pink" else C.rgb(0x78c5f8)))
	after(1500, func(): fsm.set_state("REST"))


func _enter_PHASE_CHANGE(_prev: String, _data: Variant) -> void:
	invulnerable = true
	pattern_index = 0 # cada fase empieza por su primer ataque
	clear_timers()
	_clear_orbit()
	_clear_markers()
	velocity.x = 0
	anim("hurt", false)
	level.camera.shake(400, 0.006)
	AudioManager.play("boss_appear")
	level.effects.confetti(position.x, position.y - 40, 30)
	if phase == 3:
		Fader.flash(250, Color8(255, 224, 130))
	GameState.show_toast("¡Remolino de crayones!" if phase == 2 else "¡El Gran Garabato!")
	after(1200, func():
		invulnerable = false
		fsm.set_state("IDLE"))


func _enter_DEFEATED(_prev: String, _data: Variant) -> void:
	clear_timers()
	_clear_orbit()
	_clear_markers()
	invulnerable = true
	velocity.x = 0
	set_body_enabled(false)
	_flash_material.set_shader_parameter("flash", 0.0)
	anim("stun")
	AudioManager.play("enemy_defeat")
	level.camera.shake(300, 0.005)
	var ref: WeakRef = weakref(self)
	# 1. pierde la energía (aturdido)  2. los crayones caen alrededor  3. estrellas de colores
	for i in 14:
		level.after(150 * i, func():
			var b: Garabato = ref.get_ref()
			if b != null:
				b._falling_crayon()
				b.level.effects.sparkle(b.position.x + randi_range(-40, 40), b.position.y - randi_range(10, 60), 8))
	level.after(1300, func():
		var b: Garabato = ref.get_ref()
		if b != null:
			Anim.play(b.sprite, "hurt", false))
	level.after(1900, func():
		var b: Garabato = ref.get_ref()
		if b != null:
			Anim.play(b.sprite, "defeated", false)
			b.level.effects.confetti(b.position.x, b.position.y - 40, 90)
			b.level.effects.poof(b.position.x, b.position.y - 10, 20))
	level.after(2700, func():
		var b: Garabato = ref.get_ref()
		if b != null:
			# la estrella sale hacia el centro de la arena para no quedar tapada por el jefe
			var side := -1.0 if b.position.x > (b.min_x + b.max_x) / 2.0 else 1.0
			b.defeated_at.emit(b.position.x + side * 72, b.position.y - 40))


## Crayón que salta de la caja y cae alrededor (sin daño).
func _falling_crayon() -> void:
	var c := Sprite2D.new()
	c.texture = Assets.frame("w2_fx", CRAYONS[randi() % CRAYONS.size()])
	c.position = position + Vector2(randi_range(-20, 20), -50)
	c.rotation = randf() * TAU
	level.fx_root.add_child(c)
	var tx := c.position.x + randi_range(-90, 90)
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "position:x", tx, 0.8)
	tw.tween_property(c, "position:y", c.position.y - 40, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position:y", floor_y - 3, 0.5).set_delay(0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "rotation", c.rotation + TAU, 0.8)
	tw.chain().tween_interval(2.5)
	tw.chain().tween_property(c, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(c.queue_free)


## Aviso visual previo a cada ataque.
func warn(ms: float) -> void:
	level.effects.glow_flash(position + Vector2(0, -30), C.YELLOW, 2.0, 6.0, ms, 0.9, z_index + 1 - C.Z_FX)
	var mark := PixelText.make("!", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW, "scale": 2})
	mark.position = Vector2(position.x, position.y - 82)
	mark.z_as_relative = false
	mark.z_index = C.Z_UI_WORLD
	level.fx_root.add_child(mark)
	var tw := mark.create_tween().set_parallel()
	tw.tween_property(mark, "position:y", mark.position.y - 6, ms / 1000.0)
	tw.tween_property(mark, "modulate:a", 0.0, ms / 1000.0)
	tw.chain().tween_callback(mark.queue_free)


## Impacto de un arma de la protagonista. Siempre consume el proyectil.
func hit_by(projectile: Projectile) -> bool:
	if is_defeated():
		return true
	if invulnerable:
		level.effects.sparkle(projectile.position.x, projectile.position.y, 3)
		return true
	var dmg := projectile.weapon.boss_damage if projectile.weapon else 1
	hp = maxi(0, hp - dmg)
	AudioManager.play("boss_hit")
	if projectile.weapon and projectile.weapon.effect == "paint":
		level.effects.paint_splat(projectile.position.x, projectile.position.y, projectile.paint_color)
	else:
		level.effects.impact(projectile.position.x, projectile.position.y, Color.WHITE)
	_flash_material.set_shader_parameter("flash", 1.0)
	var ref: WeakRef = weakref(self)
	level.after(60, func():
		var b: Garabato = ref.get_ref()
		if b != null and not b.is_defeated():
			b._flash_material.set_shader_parameter("flash", 0.0))
	GameState.set_v("bossHp", hp)
	var ratio := float(hp) / max_hp
	if hp <= 0:
		fsm.set_state("DEFEATED")
	elif phase == 1 and ratio <= 0.65:
		phase = 2
		fsm.set_state("PHASE_CHANGE")
	elif phase == 2 and ratio <= 0.3:
		phase = 3
		fsm.set_state("PHASE_CHANGE")
	return true
