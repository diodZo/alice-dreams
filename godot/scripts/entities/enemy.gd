class_name Enemy
extends CharacterBody2D
## Base de los monstruos de peluche (port de entities/Enemy.js). Gestiona vida, daño,
## atrapado en burbuja, pintura, patrulla y percepción. Cada subclase define su
## comportamiento de alerta y su ataque mediante alert_update() y attack().
##
## Estados: IDLE, PATROL, ALERT, ATTACK, HURT, TRAPPED (burbuja), DEFEATED.
## Origen del nodo = pies (origin 0.5, 1 en Phaser); la hitbox acaba 1 px por encima.

const IDLE := "IDLE"
const PATROL := "PATROL"
const ALERT := "ALERT"
const ATTACK := "ATTACK"
const HURT := "HURT"
const DEFEATED := "DEFEATED"
const TRAPPED := "TRAPPED"
const MAX_FALL := 420.0

@export var enemy_type := "scratch"

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox

var def: EnemyDef
var spawn: Dictionary = {}
var level: Node
var fsm: StateMachine
var timers := Timers.new()

var hp := 1
var facing := -1
var patrol_min := 0.0
var patrol_max := 0.0
var attack_ready_at := 0.0
var painted_until := 0.0
var paint_color: Variant = null
var lost_sight_at := 0.0
var trap_until := 0.0
var bubble: Sprite2D
var alert_icon: Node2D
var gravity_enabled := true
var body_enabled := true
var finished := false
var grounded := false
var blocked_left := false
var blocked_right := false
var blocked_up := false


func setup(owner_level: Node, spawn_data: Dictionary) -> void:
	level = owner_level
	spawn = spawn_data
	position = Vector2(spawn.x, spawn.y)


func _ready() -> void:
	def = Assets.enemy_def(enemy_type)
	z_index = C.Z_ENEMY
	collision_layer = C.L_ENEMY_BODY
	collision_mask = C.L_WORLD | C.L_ONE_WAY
	sprite.sprite_frames = Assets.sprite_frames(enemy_type)
	Anim.set_origin(sprite, Assets.cell_size(enemy_type), 0.5, 1.0)
	var shape := RectangleShape2D.new()
	shape.size = def.body_size
	$Body.shape = shape
	$Body.position = Vector2(0, -1 - def.body_size.y / 2.0)
	$Hitbox/Shape.shape = shape
	$Hitbox/Shape.position = $Body.position
	hitbox.collision_layer = C.L_ENEMY_HITBOX
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.set_meta("kind", "enemy")
	hitbox.set_meta("entity", self)
	hp = def.hp
	facing = int(spawn.get("facing", -1))
	var patrol: Variant = spawn.get("patrol")
	patrol_min = patrol[0] if patrol is Array else position.x - 48
	patrol_max = patrol[1] if patrol is Array else position.x + 48
	fsm = StateMachine.new(self, IDLE)


var player: Player:
	get:
		return level.player


var now: float:
	get:
		return level.now


func is_alive() -> bool:
	return not fsm.is_state(DEFEATED)


func is_trapped() -> bool:
	return fsm.is_state(TRAPPED)


## Puede dañar a la protagonista por contacto.
func is_harmful() -> bool:
	return is_alive() and not is_trapped() and not fsm.is_state(HURT)


func speed_factor() -> float:
	return 0.55 if now < painted_until else 1.0


func anim(anim_name: String, ignore_if_playing := true) -> void:
	Anim.play(sprite, anim_name, ignore_if_playing)


## Programa una acción ligada al enemigo (se cancela si cambia a herido/derrotado).
func after(ms: float, fn: Callable) -> void:
	timers.add(now, ms, func():
		if not finished:
			fn.call())


func clear_timers() -> void:
	timers.clear()


func distance_to_player() -> Dictionary:
	var p := player
	return {"dx": p.position.x - position.x, "dy": p.position.y - position.y, "dist": absf(p.position.x - position.x)}


func can_see_player(detect_range := -1.0) -> bool:
	var p := player
	if p == null or p.dead:
		return false
	var r := def.detect_range if detect_range < 0 else detect_range
	var d := distance_to_player()
	return absf(d.dx) < r and absf(d.dy) < def.detect_height


func face_player() -> void:
	facing = -1 if player.position.x < position.x else 1
	sprite.flip_h = facing < 0


## ¿Hay suelo delante? (evita caer por los bordes al patrullar o perseguir)
func ground_ahead(dir: int) -> bool:
	return level.terrain_solid_at(Vector2(position.x + dir * (def.body_size.x / 2.0 + 4.0), position.y + 4.0))


func walk(dir: int, speed: float) -> bool:
	if not ground_ahead(dir) or (dir < 0 and blocked_left) or (dir > 0 and blocked_right):
		velocity.x = 0
		return false
	facing = dir
	sprite.flip_h = dir < 0
	velocity.x = dir * speed * speed_factor()
	return true


func show_alert() -> void:
	if alert_icon != null and is_instance_valid(alert_icon):
		alert_icon.queue_free()
	var icon := PixelText.make("!", {"origin": Vector2(0.5, 0.5), "tint": C.YELLOW})
	icon.position = Vector2(position.x, position.y - def.body_size.y - 8)
	icon.z_index = C.Z_UI_WORLD
	level.fx_root.add_child(icon)
	alert_icon = icon
	var tw := icon.create_tween()
	tw.tween_property(icon, "position:y", icon.position.y - 4, 0.16)
	tw.tween_property(icon, "position:y", icon.position.y, 0.16)
	tw.tween_callback(icon.queue_free)


## Aviso visual antes de atacar (destello).
func telegraph(ms: float) -> void:
	for n in 6:
		var k := n
		timers.add(now, ms / 6.0 * (n + 1), func():
			if k % 2 == 0:
				sprite.modulate = Color(C.rgb(0xfff3a0), sprite.modulate.a)
			else:
				apply_tint())
	level.effects.glow_flash(Vector2(position.x, position.y - def.body_size.y / 2.0), C.YELLOW, 1.0, 2.0, ms, 0.9, 0)


func apply_tint() -> void:
	var c: Color = paint_color if now < painted_until and paint_color is Color else Color.WHITE
	sprite.modulate = Color(c, sprite.modulate.a)


# ------------------------------------------------------------------- estados
func _enter_IDLE(_prev: String, _data: Variant) -> void:
	velocity.x = 0
	anim("idle")


func _update_IDLE(_time: float, _delta: float) -> void:
	if can_see_player():
		fsm.set_state(ALERT)
	elif fsm.elapsed > 900:
		fsm.set_state(PATROL)


func _enter_PATROL(_prev: String, _data: Variant) -> void:
	anim("walk")


func _update_PATROL(_time: float, _delta: float) -> void:
	if can_see_player():
		fsm.set_state(ALERT)
		return
	if position.x <= patrol_min:
		facing = 1
	elif position.x >= patrol_max:
		facing = -1
	if not walk(facing, def.speed * 0.6):
		facing *= -1
		fsm.set_state(IDLE)
	anim("walk")


func _enter_ALERT(prev: String, _data: Variant) -> void:
	velocity.x = 0
	face_player()
	if prev == IDLE or prev == PATROL:
		show_alert()
		attack_ready_at = maxf(attack_ready_at, now + def.reaction_time)
	anim("idle")


func _update_ALERT(time: float, _delta: float) -> void:
	if not can_see_player(def.detect_range * 1.4):
		if lost_sight_at == 0:
			lost_sight_at = time
		if time - lost_sight_at > 1400:
			lost_sight_at = 0
			fsm.set_state(PATROL)
	else:
		lost_sight_at = 0
	alert_update(time)


func _enter_ATTACK(_prev: String, _data: Variant) -> void:
	velocity.x = 0
	face_player()
	attack()


func _update_ATTACK(_time: float, _delta: float) -> void:
	if grounded:
		velocity.x = 0


func _exit_ATTACK(_next: String) -> void:
	attack_ready_at = now + def.attack_cooldown


func _enter_HURT(_prev: String, data: Variant) -> void:
	clear_timers()
	anim("hurt", false)
	var dir: float = data.get("dir", -facing) if data is Dictionary else -facing
	velocity = Vector2(dir * 70, -90)
	after(380, func(): fsm.set_state(ALERT))


func _enter_TRAPPED(_prev: String, _data: Variant) -> void:
	clear_timers()
	anim("hurt", false)
	sprite.pause()
	gravity_enabled = false
	velocity = Vector2(0, -16)
	bubble = Sprite2D.new()
	bubble.texture = Assets.frame("fx", "bubble")
	var size := maxf(def.body_size.x, def.body_size.y) + 12
	bubble.scale = Vector2(size / bubble.texture.get_width(), size / bubble.texture.get_height())
	bubble.position = Vector2(0, -def.body_size.y / 2.0)
	bubble.modulate.a = 0.8
	bubble.z_index = 1
	add_child(bubble)
	trap_until = now + def.trap_time
	AudioManager.play("bubble_trap")


func _update_TRAPPED(time: float, _delta: float) -> void:
	velocity.x = sin(time / 250.0) * 8
	if blocked_up:
		velocity.y = 0
	var left := trap_until - time
	if left < 900:
		bubble.modulate.a = 0.3 if int(floor(time / 90.0)) % 2 else 0.8
	if left <= 0:
		# se escapa: la burbuja revienta y vuelve a la carga
		var bp := bubble.global_position
		level.effects.bubble_pop(bp.x, bp.y)
		AudioManager.play("bubble_pop")
		fsm.set_state(ALERT)


func _exit_TRAPPED(_next: String) -> void:
	sprite.play()
	gravity_enabled = true
	if bubble != null:
		bubble.queue_free()
		bubble = null


func _enter_DEFEATED(_prev: String, data: Variant) -> void:
	clear_timers()
	velocity = Vector2.ZERO
	body_enabled = false
	$Body.set_deferred("disabled", true)
	hitbox.set_deferred("monitorable", false)
	sprite.modulate = Color(Color.WHITE, sprite.modulate.a)
	if data is Dictionary and data.get("toStar", false):
		visible = false
		level.effects.bubble_pop(position.x, position.y - def.body_size.y / 2.0)
		finish()
		return
	anim("defeated", false)
	AudioManager.play("enemy_defeat")
	level.effects.sparkle(position.x, position.y - 10, 12)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		level.effects.poof(position.x, position.y - 6)
		finish())


# ---------------------------------------------------------------------- bucle
func _physics_process(delta: float) -> void:
	if finished or level == null:
		return
	var time: float = level.now
	timers.process(time)
	if finished:
		return
	fsm.update(time, delta * 1000.0)
	if painted_until != 0 and time >= painted_until:
		painted_until = 0
		apply_tint()
	if body_enabled:
		if gravity_enabled:
			velocity.y = minf(velocity.y + C.GRAVITY * delta, MAX_FALL)
		move_and_slide()
		grounded = is_on_floor()
		blocked_left = false
		blocked_right = false
		blocked_up = is_on_ceiling()
		if is_on_wall():
			var n := get_wall_normal()
			blocked_left = n.x > 0
			blocked_right = n.x < 0
	if position.y > level.world_h + 80 + 40:
		finish()


## Impacto de un proyectil de la protagonista. Devuelve true si lo consume.
func hit_by(projectile: Projectile) -> bool:
	if not is_alive():
		return false
	var w := projectile.weapon
	if is_trapped():
		# un segundo disparo sobre la burbuja la revienta y el monstruo se vuelve estrella
		convert_to_star()
		return true
	if w.effect == "trap":
		fsm.set_state(TRAPPED)
		return true
	if w.effect == "paint":
		painted_until = now + 2500
		paint_color = projectile.paint_color
		level.effects.paint_splat(projectile.position.x, projectile.position.y, projectile.paint_color)
	else:
		level.effects.impact(projectile.position.x, projectile.position.y, projectile.tint_color)
	var dir := signf(projectile.velocity.x)
	take_damage(w.damage, dir if dir != 0 else 1.0)
	return true


func stomp() -> void:
	if not is_alive() or is_trapped():
		return
	take_damage(1, 1 if player.position.x < position.x else -1)


func take_damage(amount: int, dir: float) -> void:
	hp -= amount
	AudioManager.play("enemy_hit")
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.07)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.07)
	if hp <= 0:
		fsm.set_state(DEFEATED)
	else:
		fsm.set_state(HURT, {"dir": dir})
	apply_tint()


func convert_to_star() -> void:
	var x := position.x
	var y := position.y - def.body_size.y / 2.0
	AudioManager.play("bubble_pop")
	fsm.set_state(DEFEATED, {"toStar": true})
	level.spawn_bonus_star(x, y)


func finish() -> void:
	if finished:
		return
	finished = true
	clear_timers()
	if alert_icon != null and is_instance_valid(alert_icon):
		alert_icon.queue_free()
	level.on_enemy_finished(self)
	queue_free()


## Retirada por el gestor de apariciones (fuera de cámara).
func despawn() -> void:
	finished = true
	clear_timers()
	if alert_icon != null and is_instance_valid(alert_icon):
		alert_icon.queue_free()
	queue_free()


## Rectángulo de la hitbox en coordenadas del nivel.
func body_rect() -> Rect2:
	return Rect2(position + $Body.position - def.body_size / 2.0, def.body_size)


# ------------------------------------------------- a implementar por cada monstruo
func alert_update(_time: float) -> void:
	pass


func attack() -> void:
	after(300, func(): fsm.set_state(ALERT))
