class_name Player
extends CharacterBody2D
## Protagonista: movimiento, salto y vida (port de entities/Player.js).
## - La física (aceleración, coyote time, jump buffer, salto variable) vive aquí.
## - La elección de animaciones vive en PlayerAnimator.
## - El disparo lo gestiona WeaponManager, que el nivel actualiza aparte.
##
## El origen del nodo es el mismo que el del sprite en Phaser: centro de los pies de la
## celda de 42x44 (origin 0.5, 1). La hitbox de 12x30 acaba 1 px por encima (footPadding).

signal hp_changed(hp: int)
signal fainted

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sensor: Area2D = $Sensor

var level: Node
var controls: InputController
var T: Dictionary
var animator: PlayerAnimator

var max_hp := 3
var hp := 3
var facing := 1
var last_grounded_at := -9999.0
var last_jump_press_at := -9999.0
var jumping := false
var invulnerable_until := 0.0
var stunned_until := 0.0
var attack_until := 0.0
var attack_anim := ""
var push_x := 0.0
var frozen := false
var dead := false
var celebrating := false
var gravity_enabled := true
var grounded := false
## Bloqueos contra los límites laterales/superior del mundo (collideWorldBounds de Phaser).
var world_width := 0.0


func setup(owner_level: Node, input: InputController) -> void:
	level = owner_level
	controls = input
	T = Assets.player_tuning()
	max_hp = int(T.get("maxHp", 3))
	hp = max_hp
	var body: Dictionary = T.get("body", {"width": 12, "height": 30, "footPadding": 1})
	var shape := RectangleShape2D.new()
	shape.size = Vector2(body.width, body.height)
	var y: float = -float(body.footPadding) - body.height / 2.0
	$Body.shape = shape
	$Body.position = Vector2(0, y)
	$Sensor/Shape.shape = shape
	$Sensor/Shape.position = Vector2(0, y)


func _ready() -> void:
	z_index = C.Z_PLAYER
	sprite.sprite_frames = Assets.sprite_frames("player")
	Anim.set_origin(sprite, Assets.cell_size("player"), 0.5, 1.0)
	animator = PlayerAnimator.new(self)
	Anim.play(sprite, "idle")


var now: float:
	get:
		return level.now if level else 0.0


func is_invulnerable() -> bool:
	return now < invulnerable_until or dead


## Un paso de juego. `time` en ms (reloj del nivel), `delta` en segundos.
func step(time: float, delta: float) -> void:
	if not dead:
		_control(time, delta)
	_integrate(delta)
	if not dead:
		animator.update(time)


func _control(time: float, dt: float) -> void:
	if grounded:
		last_grounded_at = time
		if velocity.y >= 0:
			jumping = false

	var can_control := not frozen and not celebrating and time >= stunned_until

	# --- horizontal: aceleración y desaceleración ---
	var axis: int = controls.axis if can_control else 0
	var target := axis * (float(T.runSpeed) if controls.run else float(T.walkSpeed))
	var vx := velocity.x
	var rate: float
	if grounded:
		var same_dir := axis != 0 and signf(axis) == signf(vx if vx != 0 else axis)
		rate = T.groundAccel if same_dir else T.groundDecel
	else:
		rate = T.airAccel if axis != 0 else T.airDecel
	var next := target
	if absf(target - vx) > rate * dt:
		next = vx + signf(target - vx) * rate * dt
	# empuje externo (viento del jefe, retroceso del tirachinas)
	if push_x != 0:
		next += push_x * dt
		push_x *= pow(0.02, dt)
		if absf(push_x) < 5:
			push_x = 0
	if time >= stunned_until or grounded:
		velocity.x = next
	if axis != 0 and can_control and time >= attack_until:
		facing = axis
	sprite.flip_h = facing < 0

	# --- salto: buffer + coyote time + altura variable ---
	if can_control and controls.jump_pressed:
		last_jump_press_at = time
	var buffered := time - last_jump_press_at <= float(T.jumpBuffer)
	var coyote := time - last_grounded_at <= float(T.coyoteTime)
	if can_control and buffered and coyote and not jumping:
		velocity.y = T.jumpVelocity
		jumping = true
		last_jump_press_at = -9999
		last_grounded_at = -9999
		AudioManager.play("jump")
		level.effects.dust(position.x, position.y)
	if jumping and not controls.jump_held and velocity.y < T.jumpCutVelocity:
		velocity.y = T.jumpCutVelocity

	# velocidad máxima de caída (la subida no se limita: rebotes y cojines la superan)
	if velocity.y > T.maxFallSpeed:
		velocity.y = T.maxFallSpeed

	# parpadeo durante la invulnerabilidad
	if time < invulnerable_until:
		sprite.modulate.a = 0.35 if int(floor(time / 70.0)) % 2 else 1.0
	else:
		sprite.modulate.a = 1.0


func _integrate(delta: float) -> void:
	if gravity_enabled:
		velocity.y += C.GRAVITY * delta
	move_and_slide()
	grounded = is_on_floor()
	# límites del mundo: izquierda, derecha y arriba (abajo no: caer al vacío es peligro)
	var half: float = ($Body.shape as RectangleShape2D).size.x / 2.0
	var top: float = -$Body.position.y + ($Body.shape as RectangleShape2D).size.y / 2.0
	if position.x - half < 0:
		position.x = half
		velocity.x = maxf(velocity.x, 0)
	elif world_width > 0 and position.x + half > world_width:
		position.x = world_width - half
		velocity.x = minf(velocity.x, 0)
	if position.y - top < 0:
		position.y = top
		velocity.y = maxf(velocity.y, 0)
	# contactos con plataformas especiales (nube elástica, nubes de vapor)
	if not dead:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col.get_normal().y < -0.5:
				var other := col.get_collider()
				if other != null and other.has_method("on_player_contact"):
					level.on_platform_contact(other)


## Impulso hacia arriba al pisar a un enemigo o una plataforma elástica.
func bounce(vy: float) -> void:
	velocity.y = vy
	# un rebote no es un salto: no se le aplica el corte de salto variable
	jumping = false
	last_grounded_at = -9999
	grounded = false


## Marca la pose de ataque del arma actual (la llama WeaponManager).
func play_attack(weapon_id: String, recoil := 0.0) -> void:
	attack_until = now + float(T.attackPoseTime)
	attack_anim = weapon_id
	animator.restart_attack()
	if recoil != 0:
		push_x -= facing * recoil


func push(vx: float) -> void:
	push_x += vx


## Recibe daño. Devuelve true si el golpe se aplicó.
func hurt(from_x: Variant = null, amount := 1) -> bool:
	if is_invulnerable() or celebrating:
		return false
	hp = maxi(0, hp - amount)
	invulnerable_until = now + float(T.invulnerableTime)
	stunned_until = now + float(T.hurtStunTime)
	var dir := -1 if from_x != null and float(from_x) > position.x else 1
	velocity = Vector2(dir * float(T.hurtKnockback.x), float(T.hurtKnockback.y))
	jumping = false
	AudioManager.play("hurt")
	level.camera.shake(120, 0.004)
	hp_changed.emit(hp)
	if hp <= 0:
		faint()
	return true


func faint() -> void:
	dead = true
	velocity = Vector2(0, -120)
	Anim.play(sprite, "hurt", true)
	fainted.emit()


func heal(full := true) -> void:
	hp = max_hp if full else mini(max_hp, hp + 1)
	hp_changed.emit(hp)


func respawn_at(x: float, y: float) -> void:
	dead = false
	push_x = 0
	position = Vector2(x, y)
	velocity = Vector2.ZERO
	invulnerable_until = now + float(T.invulnerableTime)
	stunned_until = 0
	sprite.modulate.a = 1.0
	visible = true
	reset_physics_interpolation()


func celebrate() -> void:
	celebrating = true
	velocity.x = 0
	Anim.play(sprite, "victory", true)


## Punto de salida de los proyectiles (la mano de la protagonista).
func muzzle() -> Vector2:
	return Vector2(position.x + facing * 15, position.y - 17)


## Rectángulo de la hitbox en coordenadas del nivel (body.top/bottom de Phaser).
func body_rect() -> Rect2:
	var s := ($Body.shape as RectangleShape2D).size
	return Rect2(position + $Body.position - s / 2.0, s)
