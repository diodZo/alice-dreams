class_name BubbleFishMonster
extends Enemy
## Pez Burbuja: nada (o flota) en horizontal por su tramo y, al ver a Alice, infla las mejillas
## como aviso y le lanza una burbuja lenta. Siempre va rodeado de burbujitas.

var hover_y := 0.0
var trail_at := 0.0

func _ready() -> void:
	super()
	gravity_enabled = false
	hover_y = position.y

## Flota hacia `hover_y` con un vaivén suave, como si nadara.
func _hover(time: float) -> void:
	velocity.y = clampf((hover_y - position.y) * 2.5, -40, 40) + sin(time / 380.0) * 12

func _physics_process(delta: float) -> void:
	super(delta)
	if finished or level == null or not is_alive():
		return
	if level.now >= trail_at:
		trail_at = level.now + 420 + randf() * 300
		var b := Sprite2D.new()
		b.texture = Assets.frame("w4_fx", "bubble_s")
		b.position = position + Vector2(randf_range(-10, 10), -def.body_size.y - 2)
		b.scale = Vector2(0.6, 0.6)
		level.fx_root.add_child(b)
		var tw := b.create_tween().set_parallel()
		tw.tween_property(b, "position:y", b.position.y - 14, 0.9)
		tw.tween_property(b, "modulate:a", 0.0, 0.9)
		tw.chain().tween_callback(b.queue_free)

func _update_IDLE(time: float, delta: float) -> void:
	super(time, delta)
	_hover(time)

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

func alert_update(time: float) -> void:
	var d := distance_to_player()
	var target_x := 0.0
	if d.dist < def.keep_distance.x:
		target_x = -signf(d.dx) * def.speed
	elif d.dist > def.keep_distance.y:
		target_x = signf(d.dx) * def.speed
	# no se aleja de su tramo de agua
	if (position.x <= patrol_min - 24 and target_x < 0) or (position.x >= patrol_max + 24 and target_x > 0):
		target_x = 0
	velocity.x = move_toward(velocity.x, target_x * speed_factor(), 3.0)
	_hover(time)
	face_player()
	anim("walk")
	if time >= attack_ready_at and d.dist < def.detect_range:
		fsm.set_state(ATTACK)

func attack() -> void:
	velocity = Vector2.ZERO
	face_player()
	# aviso: mejillas infladas y destello
	Anim.show_frame(sprite, "attack", 0)
	telegraph(520)
	after(520, _shoot)
	after(1000, func(): fsm.set_state(ALERT))

func _update_ATTACK(time: float, _delta: float) -> void:
	velocity.x = 0
	_hover(time)

func _exit_TRAPPED(next: String) -> void:
	super(next)
	gravity_enabled = false
	hover_y = position.y

func _shoot() -> void:
	Anim.show_frame(sprite, "attack", 1)
	var dx := player.position.x - position.x
	var dy := clampf(player.position.y - 14 - position.y, -40, 40)
	var len := maxf(Vector2(dx, dy).length(), 1.0)
	level.spawn_projectile("enemy", {"x": position.x + facing * 12, "y": position.y - 9, "vx": dx / len * 85, "vy": dy / len * 85,
		"texture": "w4_fx", "frame": "bubble_m", "lifespan": 3000, "body": 8, "owner": "enemy", "kind": "bubble_w4", "damage": 1, "wobble": 1.5})
	AudioManager.play("shoot_bubble")
