class_name CohetitoMonster
extends Enemy
## Cohetito Centinela: cohete guardián que patrulla el aire en horizontal (de un extremo a otro
## de su tramo) o en vertical (`axis: "v"`, sube y baja `range` teselas). Al detectar a Alice
## se detiene, enciende el motor como aviso y dispara un rayo estelar recto y lento en
## horizontal; después espera y sigue vigilando. Protege pasos importantes.
## Opciones de aparición: axis ("h" | "v"), range (teselas, patrulla vertical).

const SHOT_SPEED := 135.0

var hover_y := 0.0
var vertical := false
var v_min := 0.0
var v_max := 0.0
var v_dir := -1

func _ready() -> void:
	super()
	gravity_enabled = false
	hover_y = position.y
	vertical = str(spawn.get("axis", "h")) == "v"
	var r := float(spawn.get("range", 2)) * C.TILE
	v_min = position.y - r
	v_max = position.y + r
	sprite.flip_h = facing < 0

func _hover(time: float) -> void:
	velocity.y = clampf((hover_y - position.y) * 4.0, -60, 60) + sin(time / 260.0) * 4.0

func _update_IDLE(time: float, delta: float) -> void:
	super(time, delta)
	_hover(time)

func _update_PATROL(time: float, delta: float) -> void:
	if can_see_player():
		fsm.set_state(ALERT)
		return
	if vertical:
		# sube y baja por su columna mirando siempre al mismo lado
		if hover_y <= v_min or blocked_up:
			v_dir = 1
		elif hover_y >= v_max:
			v_dir = -1
		velocity.x = 0
		hover_y = clampf(hover_y + v_dir * def.speed * 0.7 * speed_factor() * delta / 1000.0, v_min, v_max)
	else:
		if position.x <= patrol_min or blocked_left:
			facing = 1
		elif position.x >= patrol_max or blocked_right:
			facing = -1
		sprite.flip_h = facing < 0
		velocity.x = facing * def.speed * speed_factor()
	_hover(time)
	anim("walk")

func alert_update(time: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 4.0)
	_hover(time)
	face_player()
	anim("idle")
	if time >= attack_ready_at:
		fsm.set_state(ATTACK)

func attack() -> void:
	velocity = Vector2.ZERO
	face_player()
	# aviso: motor encendido (fotograma de carga) y destello
	Anim.show_frame(sprite, "attack", 0)
	telegraph(620)
	after(620, _shoot)
	after(1100, func(): fsm.set_state(ALERT))

func _update_ATTACK(time: float, _delta: float) -> void:
	velocity.x = 0
	_hover(time)

func _exit_TRAPPED(next: String) -> void:
	super(next)
	gravity_enabled = false
	hover_y = position.y

func _shoot() -> void:
	Anim.show_frame(sprite, "attack", 1)
	level.spawn_projectile("enemy", {"x": position.x + facing * 16, "y": position.y - 8, "vx": facing * SHOT_SPEED, "vy": 0,
		"texture": "w5_fx", "frame": "beam_small", "lifespan": 2800, "body": 8, "owner": "enemy", "kind": "star_beam", "damage": 1})
	level.effects.sparkle(position.x + facing * 14, position.y - 8, 4)
	AudioManager.play("shoot_sling")
