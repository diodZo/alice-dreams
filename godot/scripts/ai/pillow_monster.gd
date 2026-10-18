class_name PillowMonster
extends Enemy
## Almohada voladora: mantiene distancia, dispara estrellas y alterna con una embestida.
## Vuela siempre: patrulla sin necesitar suelo y vuelve a su altura tras cada golpe.

var shots := 0
var hover_y := 0.0

func _ready() -> void:
	super()
	gravity_enabled = false
	hover_y = position.y

## Flota hacia `hover_y` con un vaivén suave.
func _hover(time: float) -> void:
	velocity.y = clampf((hover_y - position.y) * 2.5, -40, 40) + sin(time / 420.0) * 10

func _update_PATROL(time: float, _delta: float) -> void:
	if can_see_player():
		fsm.set_state(ALERT)
		return
	if position.x <= patrol_min or blocked_left:
		facing = 1
	elif position.x >= patrol_max or blocked_right:
		facing = -1
	sprite.flip_h = facing < 0
	velocity.x = facing * def.speed * 0.6 * speed_factor()
	_hover(time)
	anim("walk")

func _update_IDLE(time: float, delta: float) -> void:
	super(time, delta)
	_hover(time)

func alert_update(time: float) -> void:
	var d := distance_to_player()
	var target_x := 0.0
	if d.dist < def.keep_distance.x:
		target_x = -signf(d.dx) * def.speed
	elif d.dist > def.keep_distance.y:
		target_x = signf(d.dx) * def.speed
	velocity.x = move_toward(velocity.x, target_x * speed_factor(), 3.0)
	_hover(time)
	face_player()
	anim("walk")
	if time >= attack_ready_at and d.dist < def.detect_range:
		fsm.set_state(ATTACK)

func attack() -> void:
	velocity = Vector2.ZERO
	face_player()
	telegraph(450)
	shots += 1
	if shots % 3 == 0:
		Anim.show_frame(sprite, "dash", 0)
		after(450, func(): velocity.x = facing * 190; anim("dash", false))
		after(950, func(): velocity = Vector2.ZERO; fsm.set_state(ALERT))
	else:
		Anim.show_frame(sprite, "attack", 0)
		after(450, _shoot)
		after(950, func(): fsm.set_state(ALERT))

func _update_ATTACK(_time: float, _delta: float) -> void:
	velocity.y = 0

func _exit_TRAPPED(next: String) -> void:
	super(next)
	gravity_enabled = false
	hover_y = position.y

func _shoot() -> void:
	anim("attack", false)
	var dx := player.position.x - position.x
	var dy := player.position.y - 10 - position.y
	var len := maxf(Vector2(dx, dy).length(), 1.0)
	level.spawn_projectile("enemy", {"x":position.x + facing * 14,"y":position.y - 8,"vx":dx / len * 105,"vy":dy / len * 105,"texture":"w3_fx","frame":"soft_star","lifespan":3200,"body":7,"owner":"enemy","kind":"soft_star","damage":1,"spin":180})
	AudioManager.play("shoot_sling")
