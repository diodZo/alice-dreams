class_name GomilitoMonster
extends Enemy
## Gomilito Saltarín: gelatina alegre y elástica que siempre se mueve a saltitos.
##  - Patrulla su plataforma dando pequeños saltos (se gira en los bordes).
##  - Al ver a Alice se acerca saltando; cerca de ella se agacha (aviso, CROUCH_MS) y salta en
##    plancha hacia donde estaba (ataque). Al caer rebota y se recompone.
##  - Al recibir suficiente daño (vida <= splitAt) se divide en dos gomitas pequeñas
##    (GomilitoMini), con menos vida y velocidad configurable. Las gomitas no se dividen y hay
##    un máximo de gomitas activas en el nivel (MAX_MINIS): nunca hay generación infinita.
## Opciones de aparición: splitAt (vida a la que se divide; 0 = no se divide), miniSpeed.

const HOP_VY := -170.0
const HOP_GAP_MS := 420.0
const LEAP_VY := -250.0
const CROUCH_MS := 550.0
const MAX_MINIS := 6
const MINI_SCENE := "res://scenes/enemies/world7/GomilitoMini.tscn"
const MINI_COLORS := ["blue", "yellow", "green", "pink"]

var hopping := false
var hop_ready_at := 0.0
var leaping := false
var split_done := false


func is_harmful() -> bool:
	return super() and not fsm.is_state("SPLIT")


## Salto pequeño hacia `dir` si hay suelo donde va a caer.
func hop(dir: int, speed: float, vy := HOP_VY) -> bool:
	if (dir < 0 and blocked_left) or (dir > 0 and blocked_right):
		return false
	var reach := speed * (2.0 * absf(vy) / C.GRAVITY)
	if not ground_ahead(dir) or not level.terrain_solid_at(Vector2(position.x + dir * (reach + def.body_size.x / 2.0), position.y + 4.0)):
		return false
	facing = dir
	sprite.flip_h = dir < 0
	hopping = true
	velocity = Vector2(dir * speed * speed_factor(), vy)
	grounded = false
	Anim.show_frame(sprite, "jump", 1)
	return true


func land() -> void:
	hopping = false
	velocity.x = 0
	hop_ready_at = now + HOP_GAP_MS
	anim("idle")
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.25, 0.75), 0.07)
	tw.tween_property(sprite, "scale", Vector2(0.92, 1.08), 0.08)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.08)


func _update_PATROL(_time: float, _delta: float) -> void:
	if can_see_player():
		fsm.set_state(ALERT)
		return
	if not grounded:
		return
	if hopping:
		land()
	if now < hop_ready_at:
		return
	if position.x <= patrol_min:
		facing = 1
	elif position.x >= patrol_max:
		facing = -1
	if not hop(facing, def.speed * 0.8):
		facing *= -1
		hop_ready_at = now + HOP_GAP_MS


func alert_update(time: float) -> void:
	if not grounded:
		return
	if hopping:
		land()
	face_player()
	var d := distance_to_player()
	if absf(d.dx) > def.attack_range and time >= hop_ready_at:
		if not hop(facing, def.speed):
			hop_ready_at = time + HOP_GAP_MS
	elif absf(d.dx) <= def.attack_range and time >= attack_ready_at:
		fsm.set_state(ATTACK)


func attack() -> void:
	hopping = false
	leaping = false
	if _has_attack_frames():
		Anim.show_frame(sprite, "attack", 0)
	telegraph(CROUCH_MS)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.2, 0.8), CROUCH_MS / 1000.0)
	after(CROUCH_MS, _leap)


func _leap() -> void:
	face_player()
	sprite.scale = Vector2.ONE
	var dx := clampf(absf(player.position.x - position.x), 20.0, def.attack_range)
	var t := 2.0 * absf(LEAP_VY) / C.GRAVITY
	var speed := dx / t
	# no salta al vacío: si no hay suelo donde caería, salta en el sitio
	if not level.terrain_solid_at(Vector2(position.x + facing * dx, position.y + 4.0)):
		speed = 0.0
	leaping = true
	velocity = Vector2(facing * speed * speed_factor(), LEAP_VY)
	grounded = false
	if _has_attack_frames():
		Anim.show_frame(sprite, "attack", 1)
	AudioManager.play("jelly")


## Las gomitas (gomilito_mini) sólo tienen un fotograma por color: atacan sin cambiarlo.
func _has_attack_frames() -> bool:
	return sprite.sprite_frames.has_animation("attack")


func _update_ATTACK(_time: float, _delta: float) -> void:
	if leaping and grounded and velocity.y >= 0 and fsm.elapsed > CROUCH_MS + 120:
		leaping = false
		land()
		level.effects.poof(position.x, position.y, 5)
		after(380, func(): fsm.set_state(ALERT))


func _exit_ATTACK(next: String) -> void:
	super(next)
	leaping = false
	sprite.scale = Vector2.ONE


# ------------------------------------------------------------------ división
## ¿Puede dividirse ahora? (sólo una vez, si quedan huecos para gomitas en el nivel)
func can_split() -> bool:
	if split_done or int(spawn.get("splitAt", 2)) <= 0:
		return false
	var minis: Array = level.enemies_root.get_children().filter(func(n): return n is GomilitoMini and not n.finished)
	return minis.size() + 2 <= MAX_MINIS


func take_damage(amount: int, dir: float) -> void:
	var left := hp - amount
	if left > 0 and left <= int(spawn.get("splitAt", 2)) and can_split():
		hp = left
		split_done = true
		AudioManager.play("enemy_hit")
		fsm.set_state("SPLIT")
		return
	super(amount, dir)


func _enter_SPLIT(_prev: String, _data: Variant) -> void:
	clear_timers()
	velocity = Vector2.ZERO
	anim("split", false)
	AudioManager.play("gummy_split")
	after(420, _spawn_minis)


func _update_SPLIT(_time: float, _delta: float) -> void:
	velocity.x = 0


func _spawn_minis() -> void:
	var scene: PackedScene = load(MINI_SCENE)
	var speed := float(spawn.get("miniSpeed", 0))
	for i in 2:
		var side := -1 if i == 0 else 1
		var m: Enemy = scene.instantiate()
		var s := {
			"id": "%s:m%d" % [spawn.id, i], "type": "gomilito_mini",
			"x": position.x + side * 6, "y": position.y,
			"patrol": [patrol_min, patrol_max], "color": MINI_COLORS[(i + int(position.x / 16)) % MINI_COLORS.size()],
			"facing": side, "speed": speed, "kick": side,
		}
		m.setup(level, s)
		level.enemies_root.add_child(m)
		# el gestor de apariciones las retira con las demás (fuera de cámara o al reaparecer)
		level.spawner.active[s.id] = m
	level.effects.confetti(position.x, position.y - 12, 16)
	visible = false
	finish()
