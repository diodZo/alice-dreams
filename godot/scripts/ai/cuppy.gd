class_name CuppyMonster
extends Enemy
## Cuppy Dulzón: pastelito de crema rosada con una fresa en la cabeza que rueda sobre sus
## galletas y lleva una piruleta. Comportamiento determinista:
##  1 patrulla su plataforma rodando,
##  2 al ver a Alice se acerca dando saltitos (nunca salta fuera de su plataforma),
##  3 cerca de ella levanta la piruleta (preparación PREP_MS con destello: el aviso),
##  4 dispara un caramelo redondo recto y lento a la altura de sus galletas (se salta),
##  5 se recupera (RECOVER_MS) y vuelve a empezar tras attack_cooldown.

const HOP_VY := -180.0
const HOP_GAP_MS := 380.0
const PREP_MS := 650.0
const RECOVER_MS := 600.0
const CANDY_SPEED := 105.0

var hopping := false
var hop_ready_at := 0.0


func alert_update(time: float) -> void:
	if not grounded:
		return
	if hopping:
		_land()
	face_player()
	var d := distance_to_player()
	var far: bool = absf(d.dx) > def.attack_range * 0.7
	if far and time >= hop_ready_at and _can_hop(facing):
		_hop(facing)
	elif not far and time >= attack_ready_at:
		fsm.set_state(ATTACK)
	else:
		velocity.x = 0
		anim("idle")


## Hay suelo al llegar del salto (y no hay pared delante).
func _can_hop(dir: int) -> bool:
	if (dir < 0 and blocked_left) or (dir > 0 and blocked_right):
		return false
	var reach := def.speed * 1.6 * (2.0 * absf(HOP_VY) / C.GRAVITY)
	return ground_ahead(dir) and level.terrain_solid_at(Vector2(position.x + dir * (reach + def.body_size.x / 2.0), position.y + 4.0))


func _hop(dir: int) -> void:
	hopping = true
	velocity = Vector2(dir * def.speed * 1.6 * speed_factor(), HOP_VY)
	grounded = false
	Anim.show_frame(sprite, "jump", 0)


func _land() -> void:
	hopping = false
	velocity.x = 0
	hop_ready_at = now + HOP_GAP_MS
	Anim.show_frame(sprite, "jump", 1)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.07)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.1)
	level.effects.poof(position.x, position.y, 3)


func attack() -> void:
	hopping = false
	Anim.show_frame(sprite, "attack", 0)
	telegraph(PREP_MS)
	after(PREP_MS, _shoot)
	after(PREP_MS + RECOVER_MS, func():
		anim("idle")
		fsm.set_state(ALERT))


func _shoot() -> void:
	face_player()
	Anim.show_frame(sprite, "attack", 1)
	var from := position + Vector2(facing * 12, -9)
	level.spawn_projectile("enemy", {"x": from.x, "y": from.y, "vx": facing * CANDY_SPEED, "vy": 0, "texture": "w7_fx",
		"frame": "cuppy_candy", "lifespan": 2600, "body": 8, "owner": "enemy", "kind": "candy", "damage": 1, "spin": 300})
	AudioManager.play("candy_pop")


func _exit_ATTACK(next: String) -> void:
	super(next)
	sprite.scale = Vector2.ONE


func _exit_ALERT(_next: String) -> void:
	hopping = false
