class_name EstrellitaMonster
extends Enemy
## Estrellita Fugaz: estrellita viviente que vuela rápido por su ruta (ida y vuelta con una onda
## suave, siempre el mismo dibujo en el aire) dejando una estela brillante. Suele ir en grupos:
## cada una de un grupo sale con un desfase de onda (`wave_phase`). Al ver a Alice se queda a
## distancia, se encoge y brilla como aviso y le lanza una miniestrella lenta.
## Opciones de aparición: wave (alto de la onda en px), wave_phase (0-1).

var hover_y := 0.0
var wave := 10.0
var wave_phase := 0.0
var trail_at := 0.0

func _ready() -> void:
	super()
	gravity_enabled = false
	hover_y = position.y
	wave = float(spawn.get("wave", 10))
	wave_phase = float(spawn.get("wave_phase", 0.0))

## Vuelo: vuelve hacia `hover_y` con una onda regular (patrón claro y predecible).
func _hover(time: float) -> void:
	var target := hover_y + sin(time / 300.0 + wave_phase * TAU) * wave
	velocity.y = clampf((target - position.y) * 6.0, -90, 90)

func _physics_process(delta: float) -> void:
	super(delta)
	if finished or level == null or not is_alive():
		return
	if level.now >= trail_at and absf(velocity.x) > 10:
		trail_at = level.now + 90
		var s := Sprite2D.new()
		s.texture = Assets.frame("w5_fx", ["spark_gold", "spark_pink", "spark_blue"][randi() % 3])
		s.position = position + Vector2(-signf(velocity.x) * 8, -def.body_size.y / 2.0 + randf_range(-3, 3))
		s.scale = Vector2(0.6, 0.6)
		level.fx_root.add_child(s)
		var tw := s.create_tween().set_parallel()
		tw.tween_property(s, "scale", Vector2(0.1, 0.1), 0.45)
		tw.tween_property(s, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(s.queue_free)

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
	velocity.x = facing * def.speed * speed_factor()
	_hover(time)
	anim("walk")

func alert_update(time: float) -> void:
	var d := distance_to_player()
	var target_x := 0.0
	if d.dist < def.keep_distance.x:
		target_x = -signf(d.dx) * def.speed
	elif d.dist > def.keep_distance.y:
		target_x = signf(d.dx) * def.speed
	# no se aleja mucho de su ruta
	if (position.x <= patrol_min - 32 and target_x < 0) or (position.x >= patrol_max + 32 and target_x > 0):
		target_x = 0
	velocity.x = move_toward(velocity.x, target_x * speed_factor(), 6.0)
	_hover(time)
	face_player()
	anim("walk" if absf(velocity.x) > 8 else "idle")
	if time >= attack_ready_at and d.dist < def.detect_range:
		fsm.set_state(ATTACK)

func attack() -> void:
	velocity = Vector2.ZERO
	face_player()
	# aviso: se encoge y brilla
	Anim.show_frame(sprite, "attack", 0)
	telegraph(480)
	after(480, _shoot)
	after(900, func(): fsm.set_state(ALERT))

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
	var dy := clampf(player.position.y - 14 - position.y, -50, 50)
	var len := maxf(Vector2(dx, dy).length(), 1.0)
	level.spawn_projectile("enemy", {"x": position.x + facing * 8, "y": position.y - 8, "vx": dx / len * 105, "vy": dy / len * 105,
		"texture": "w5_fx", "frame": "mini_star", "lifespan": 2600, "body": 8, "owner": "enemy", "kind": "mini_star", "damage": 1, "spin": 360})
	AudioManager.play("twinkle")
