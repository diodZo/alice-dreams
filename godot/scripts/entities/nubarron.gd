class_name Nubarron
extends BossBase
## NUBARRÓN — jefe del Mundo 1 (port de bosses/Nubarron.js).
##
## Fases según la vida restante (40 puntos):
##  1 (100-65 %): vaivén lento, ráfagas de viento y bolitas de nube.
##  2 (65-30 %):  más rápido, lluvia de nubecitas con aviso, invoca plataformas.
##  3 (30-0 %):   cambia de color, movimientos rápidos, ráfaga triple, alterna ataques.
## Tras cada ataque baja y descansa: es la ventana clara para golpearle.
## Los ataques siempre tienen aviso y huecos para esquivarlos.

const PHASES := {
	1: {"speed": 38.0, "interval": 1500.0, "rest": 1300.0, "pattern": ["WIND", "SHOOT", "SHOOT", "WIND"]},
	2: {"speed": 62.0, "interval": 1250.0, "rest": 1300.0, "pattern": ["RAIN", "SHOOT", "SUMMON", "WIND", "RAIN", "SHOOT"]},
	3: {"speed": 90.0, "interval": 950.0, "rest": 1500.0, "pattern": ["DASH", "TRIPLE", "RAIN", "DASH", "WIND", "TRIPLE", "SHOOT"]},
}
const PHASE3_TINT := Color("cdb8ff")
const MAX_HP := 40

var home_y := 0.0
var bob_t := 0.0
var target_y := 0.0
var rest_glow: Sprite2D
var _cleanup_markers := Callable()


## cfg: { homeX (teselas), homeY, minX, maxX (teselas), floorY (px) }
func setup(owner_level: Node, boss_cfg: Dictionary) -> void:
	level = owner_level
	cfg = boss_cfg
	position = Vector2(float(cfg.homeX) * C.TILE, -80)
	home_y = float(cfg.homeY)
	min_x = float(cfg.minX) * C.TILE + 40
	max_x = float(cfg.maxX) * C.TILE - 40
	floor_y = float(cfg.floorY)
	target_y = home_y


func _ready() -> void:
	z_index = C.Z_ENEMY + 2
	collision_layer = C.L_BOSS
	collision_mask = 0
	monitoring = false
	set_meta("kind", "boss")
	set_meta("entity", self)
	sprite.sprite_frames = Assets.sprite_frames("nubarron")
	flash = ShaderMaterial.new()
	flash.shader = preload("res://resources/effects/flash.gdshader")
	sprite.material = flash
	fsm = StateMachine.new(self)
	impact_effects = true
	set_body_enabled(false)


func anim(anim_name: String, ignore := true) -> void:
	var key := "storm" if phase == 3 and (anim_name == "idle" or anim_name == "move") else anim_name
	Anim.play(sprite, key, ignore)


func clear_timers() -> void:
	timers.clear()


func face_player() -> void:
	sprite.flip_h = player.position.x < position.x


## Vaivén horizontal + balanceo vertical suave hacia target_y.
func drift(delta: float, speed_mul := 1.0) -> void:
	var sp: float = phase_data().speed * speed_mul
	if position.x <= min_x:
		dir = 1
	elif position.x >= max_x:
		dir = -1
	bob_t += delta
	var y := target_y + sin(bob_t / 400.0) * 5
	velocity = Vector2(dir * sp, (y - position.y) * 4)


func hover(delta: float) -> void:
	bob_t += delta
	var y := target_y + sin(bob_t / 400.0) * 4
	velocity = Vector2(0, (y - position.y) * 5)


func _physics_process(delta: float) -> void:
	if level == null:
		return
	timers.process(now)
	if fsm.current != "":
		fsm.update(now, delta * 1000.0)
	if body_enabled:
		position += velocity * delta


func _tween() -> Tween:
	return create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)


# --------------------------------------------------------------------- estados
func _enter_INTRO(_prev: String, _data: Variant) -> void:
	anim("idle")
	var tw := _tween()
	tw.tween_property(self, "position:y", home_y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		invulnerable = false
		fsm.set_state("IDLE"))


func _enter_IDLE(_prev: String, _data: Variant) -> void:
	target_y = home_y
	anim("move")


func _update_IDLE(_time: float, delta: float) -> void:
	drift(delta)
	sprite.flip_h = dir < 0
	if fsm.elapsed > phase_data().interval:
		var p: Array = phase_data().pattern
		var next: String = p[pattern_index % p.size()]
		pattern_index += 1
		fsm.set_state(next)


## Ventana de vulnerabilidad: baja, se queda quieto y brilla.
func _enter_REST(_prev: String, _data: Variant) -> void:
	target_y = home_y + 34
	anim("idle")
	rest_glow = Sprite2D.new()
	rest_glow.texture = Assets.generated("glow")
	rest_glow.scale = Vector2(5, 5)
	rest_glow.modulate = Color(C.YELLOW, 0.5)
	rest_glow.z_index = -1
	add_child(rest_glow)
	var tw := rest_glow.create_tween().set_loops()
	tw.tween_property(rest_glow, "modulate:a", 0.15, 0.3)
	tw.tween_property(rest_glow, "modulate:a", 0.5, 0.3)


func _update_REST(_time: float, delta: float) -> void:
	hover(delta)
	if fsm.elapsed > phase_data().rest:
		fsm.set_state("IDLE")


func _exit_REST(_next: String) -> void:
	if rest_glow:
		rest_glow.queue_free()
		rest_glow = null


func _enter_WIND(_prev: String, _data: Variant) -> void:
	face_player()
	target_y = home_y + 10
	anim("blow", false)
	sprite.pause()
	sprite.frame = 1
	warn(700)
	after(700, func():
		sprite.play()
		var d := -1 if sprite.flip_h else 1
		AudioManager.play("wind")
		# ráfaga baja: se esquiva saltando. Empuja, no daña.
		level.spawn_projectile("boss", {
			"x": position.x + d * 40, "y": floor_y - 12, "vx": d * 150, "vy": 0,
			"texture": "fx", "frame": "wind", "lifespan": 4500, "body": 18,
			"owner": "boss", "kind": "wind", "damage": 0, "alpha": 0.9,
		})
		level.effects.poof(position.x + d * 30, position.y, 10))
	after(1500, func(): fsm.set_state("REST"))


func _update_WIND(_time: float, delta: float) -> void:
	hover(delta)


func _enter_SHOOT(_prev: String, _data: Variant) -> void:
	face_player()
	anim("shoot", false)
	warn(500)
	var shots := 2 if phase == 1 else 3
	for i in shots:
		after(500 + i * 320, func(): fire_ball(0))
	after(500 + shots * 320 + 400, func(): fsm.set_state("REST"))


func _update_SHOOT(_time: float, delta: float) -> void:
	hover(delta)


func _enter_TRIPLE(_prev: String, _data: Variant) -> void:
	face_player()
	anim("shoot", false)
	warn(650)
	for v in 3:
		after(650 + v * 420, func():
			face_player()
			for a in [-0.32, 0.0, 0.32]:
				fire_ball(a, 105))
	after(650 + 3 * 420 + 400, func(): fsm.set_state("REST"))


func _update_TRIPLE(_time: float, delta: float) -> void:
	hover(delta)


func _enter_RAIN(_prev: String, _data: Variant) -> void:
	anim("storm")
	target_y = home_y - 20
	# posiciones con huecos amplios entre gotas: siempre hay sitio seguro
	var count := 5 if phase == 3 else 4
	var span := max_x + 40 - (min_x - 40)
	var gap := span / count
	var offset := randi_range(10, floori(gap) - 30)
	var xs: Array = []
	for i in count:
		xs.append(min_x - 40 + offset + i * gap)
	var markers: Array = []
	for x in xs:
		var m := Sprite2D.new()
		m.texture = Assets.frame("fx", "cloudball")
		m.position = Vector2(x, floor_y - 2)
		m.scale = Vector2(0.9, 0.3)
		m.modulate = Color(C.BLUE, 0.6)
		level.fx_root.add_child(m)
		var tw := m.create_tween().set_loops()
		tw.tween_property(m, "modulate:a", 0.15, 0.12)
		tw.tween_property(m, "modulate:a", 0.6, 0.12)
		markers.append(m)
	_cleanup_markers = func():
		for m in markers:
			if is_instance_valid(m):
				m.queue_free()
	after(1000, func():
		_cleanup_markers.call()
		for i in xs.size():
			var x: float = xs[i]
			after(i * 60, func():
				level.spawn_projectile("boss", {
					"x": x, "y": -10, "vx": 0, "vy": 170, "gravity": 260,
					"texture": "fx", "frame": "cloudball", "scale": 0.75, "lifespan": 2500,
					"body": 12, "owner": "boss", "kind": "rain", "damage": 1,
				})))
	after(2100, func(): fsm.set_state("REST"))


func _update_RAIN(_time: float, delta: float) -> void:
	hover(delta)


func _exit_RAIN(_next: String) -> void:
	if _cleanup_markers.is_valid():
		_cleanup_markers.call()


func _enter_SUMMON(_prev: String, _data: Variant) -> void:
	anim("blow", false)
	warn(500)
	var spots := [
		Vector2(randi_range(int(min_x), int(min_x) + 120), floor_y - 52),
		Vector2(randi_range(int(max_x) - 120, int(max_x)), floor_y - 52),
	]
	for s in spots:
		level.effects.sparkle(s.x, s.y, 12)
	after(500, func():
		for s in spots:
			level.add_temporary_platform(s.x, s.y, 5500))
	after(1200, func(): fsm.set_state("REST"))


func _update_SUMMON(_time: float, delta: float) -> void:
	hover(delta)


## Movimiento rápido de un lado a otro de la arena por encima de la protagonista.
func _enter_DASH(_prev: String, _data: Variant) -> void:
	anim("storm")
	warn(600)
	var to_left := position.x > (min_x + max_x) / 2.0
	var tx := min_x if to_left else max_x
	after(600, func():
		velocity = Vector2.ZERO
		AudioManager.play("wind")
		var tw := _tween()
		tw.tween_property(self, "position", Vector2(tx, home_y - 16), 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_ghost_trail(0.52))
	after(1300, func(): fsm.set_state("REST"))


func _update_DASH(_time: float, _delta: float) -> void:
	# el tween controla la posición
	velocity = Vector2.ZERO


func _ghost_trail(seconds: float) -> void:
	var frames := int(seconds * 60)
	for i in frames:
		timers.add(now, i * (1000.0 / 60.0), func():
			if randf() < 0.5:
				ghost())


func _enter_PHASE_CHANGE(_prev: String, _data: Variant) -> void:
	invulnerable = true
	clear_timers()
	velocity = Vector2.ZERO
	anim("hurt", false)
	level.camera.shake(400, 0.006)
	AudioManager.play("boss_appear")
	if phase == 3:
		Fader.flash(250, Color8(205, 184, 255))
		sprite.modulate = PHASE3_TINT
	GameState.show_toast("¡Nubarrón se enfada!" if phase == 2 else "¡Nubarrón desata la tormenta!")
	after(1200, func():
		invulnerable = false
		fsm.set_state("IDLE"))


func _update_PHASE_CHANGE(_time: float, delta: float) -> void:
	hover(delta)


func _enter_DEFEATED(_prev: String, _data: Variant) -> void:
	clear_timers()
	invulnerable = true
	velocity = Vector2.ZERO
	set_body_enabled(false)
	sprite.modulate = Color.WHITE
	flash.set_shader_parameter("flash", 0.0)
	anim("defeated", false)
	AudioManager.play("enemy_defeat")
	level.effects.confetti(position.x, position.y, 80)
	var ref: WeakRef = weakref(self)
	for i in 11:
		level.after(180 * (i + 1), func():
			var b: Nubarron = ref.get_ref()
			if b != null and not b._transformed:
				b.level.effects.sparkle(b.position.x + randi_range(-30, 30), b.position.y + randi_range(-20, 20), 8))
	# gira suavemente y se transforma en una nubecita sonriente
	var tw := _tween().set_parallel()
	tw.tween_property(self, "rotation_degrees", 720.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position:y", floor_y - 70, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(_transform_into_cloud)


var _transformed := false


func _transform_into_cloud() -> void:
	_transformed = true
	level.effects.poof(position.x, position.y, 20)
	level.effects.confetti(position.x, position.y, 60)
	Anim.show_frame(sprite, "idle", 1) # expresión sonriente con los ojos cerrados
	rotation_degrees = 0
	var tw := _tween()
	tw.tween_property(self, "scale", Vector2(0.45, 0.45), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var y := position.y
	var bob := _tween().set_loops()
	bob.tween_interval(0.4)
	bob.tween_property(self, "position:y", y - 6, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(self, "position:y", y, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	defeated_at.emit(position.x, position.y)


## Aviso visual previo a cada ataque.
func warn(ms: float) -> void:
	level.effects.glow_flash(position, C.YELLOW, 2.0, 6.0, ms, 0.9, z_index + 1 - C.Z_FX)
	var mark := PixelText.make("!", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW, "scale": 2})
	mark.position = Vector2(position.x, position.y - 44)
	mark.z_as_relative = false
	mark.z_index = C.Z_UI_WORLD
	level.fx_root.add_child(mark)
	var tw := mark.create_tween().set_parallel()
	tw.tween_property(mark, "position:y", mark.position.y - 6, ms / 1000.0)
	tw.tween_property(mark, "modulate:a", 0.0, ms / 1000.0)
	tw.chain().tween_callback(mark.queue_free)


func ghost() -> void:
	var g := Sprite2D.new()
	g.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	g.position = position
	g.flip_h = sprite.flip_h
	g.modulate = Color(PHASE3_TINT, 0.35)
	g.z_as_relative = false
	g.z_index = z_index - 1
	level.fx_root.add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.26)
	tw.tween_callback(g.queue_free)


func fire_ball(angle_offset := 0.0, speed := 120.0) -> void:
	var dir_x := -1 if sprite.flip_h else 1
	var sx := position.x + dir_x * 34
	var sy := position.y + 8
	var base := atan2(player.position.y - 16 - sy, player.position.x - sx)
	var a := base + angle_offset
	level.spawn_projectile("boss", {
		"x": sx, "y": sy, "vx": cos(a) * speed, "vy": sin(a) * speed,
		"texture": "fx", "frame": "cloudball", "scale": 0.7, "lifespan": 4000, "body": 11,
		"owner": "boss", "kind": "cloudball", "damage": 1,
	})
	AudioManager.play("shoot_bubble")

