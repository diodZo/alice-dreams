class_name PayasitoMonster
extends Enemy
## Payasito Resorte: juguete medio escondido en su caja de estrellas. Cuando Alice se acerca:
##  1 la caja tiembla (aviso, SHAKE_MS),
##  2 salta hacia arriba con el resorte estirado (salto parabólico, sin moverse de su caja),
##  3 en lo alto lanza dos estrellitas hacia Alice,
##  4 vuelve a su caja (el resorte se comprime al caer),
##  5 espera (attack_cooldown) antes de repetir.
## No patrulla: su sitio es su caja. Comportamiento determinista.

const SHAKE_MS := 650.0
const JUMP_VY := -250.0
const STAR_SPEED := 95.0

var home_x := 0.0
var jumping := false
var shot := false


func _ready() -> void:
	super()
	home_x = position.x


func _update_IDLE(_time: float, _delta: float) -> void:
	velocity.x = 0
	if can_see_player():
		fsm.set_state(ALERT)


func _update_PATROL(_time: float, _delta: float) -> void:
	fsm.set_state(IDLE)


func alert_update(time: float) -> void:
	velocity.x = 0
	face_player()
	anim("idle")
	if grounded and time >= attack_ready_at:
		fsm.set_state(ATTACK)


func attack() -> void:
	jumping = false
	shot = false
	Anim.show_frame(sprite, "jump", 0)
	telegraph(SHAKE_MS)
	var tw := sprite.create_tween().set_loops(int(SHAKE_MS / 100.0))
	tw.tween_property(sprite, "position:x", 1.5, 0.05)
	tw.tween_property(sprite, "position:x", -1.5, 0.05)
	after(SHAKE_MS, _jump)


func _jump() -> void:
	sprite.position.x = 0
	jumping = true
	velocity = Vector2(0, JUMP_VY)
	grounded = false
	Anim.show_frame(sprite, "jump", 1)
	AudioManager.play("spring")
	# el resorte se estira al salir
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(0.85, 1.25), 0.1)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.18)


func _update_ATTACK(_time: float, _delta: float) -> void:
	velocity.x = 0
	position.x = move_toward(position.x, home_x, 1.0)
	if not jumping:
		return
	if not shot and velocity.y >= -20:
		shot = true
		_throw()
	if shot and velocity.y > 0 and not grounded:
		Anim.show_frame(sprite, "jump", 2)
	if grounded and velocity.y >= 0 and fsm.elapsed > SHAKE_MS + 150:
		jumping = false
		anim("idle")
		# aterriza en su caja: el resorte se comprime
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.07)
		tw.tween_property(sprite, "scale", Vector2.ONE, 0.12)
		level.effects.poof(position.x, position.y, 4)
		after(350, func(): fsm.set_state(ALERT))


func _throw() -> void:
	face_player()
	anim("attack", false)
	var from := position + Vector2(facing * 10, -def.body_size.y)
	var target := player.position + Vector2(0, -14)
	for spread in [-10.0, 10.0]:
		var vel := (target - from).normalized().rotated(deg_to_rad(spread)) * STAR_SPEED
		level.spawn_projectile("enemy", {"x": from.x, "y": from.y, "vx": vel.x, "vy": vel.y, "texture": "w6_fx", "frame": "clown_star",
			"lifespan": 2600, "body": 8, "owner": "enemy", "kind": "clown_star", "damage": 1, "spin": 260})
	AudioManager.play("twinkle")


func _exit_ATTACK(next: String) -> void:
	super(next)
	jumping = false
	sprite.position.x = 0
	sprite.scale = Vector2.ONE


## Derrota infantil: el resorte salta fuera de la caja y el payasito queda tumbado, sonriente.
func _enter_DEFEATED(prev: String, data: Variant) -> void:
	super(prev, data)
	if data is Dictionary and data.get("toStar", false):
		return
	AudioManager.play("spring")
	for i in 3:
		level.effects.float_text(position.x + (i - 1) * 8, position.y - 24 - i * 3, "*", C.YELLOW)
