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
## Respuesta al golpe (IMP-020): pausa de impacto y destello blanco.
const HURT_HIT_STOP_MS := 70.0
const HURT_FLASH_MS := 90.0
var _flash: ShaderMaterial
## Velocidad horizontal del tren al saltar desde un vagón (Mundo 5, IMP-035): se conserva en el
## aire para volver a caer sobre el vagón en lugar de quedarse atrás. 0 fuera de un salto así.
var carry_x := 0.0
var _ride_vx := 0.0
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
## Superficies pintadas (Mundo 2). Valores neutros = comportamiento original. Las fija el nivel
## en cada fotograma según la pintura que se pisa y vuelven a 1 al salir del área.
var surface_speed := 1.0
var surface_friction := 1.0
## Somnolencia temporal del Mundo 3: conserva el control, sólo reduce la velocidad.
var sleepy_until := 0.0
## Velocidad vertical con la que se aterrizó en el último paso (para la pintura elástica).
var landed_speed := 0.0
## Agua del Mundo 4: altura (y) de la superficie del agua en la que nada, o INF fuera del agua.
## La fija el nivel en cada fotograma. Dentro: menos gravedad, caída lenta y brazadas con salto.
var water_surface := INF
var swim_ready_at := 0.0
const WATER_GRAVITY := 0.32
const WATER_MAX_FALL := 80.0
const WATER_MAX_RISE := -340.0
const SWIM_STROKE := -150.0
const SWIM_SPEED := 0.72
## Tobogán arcoíris del Mundo 5: velocidad horizontal (px/s, con signo) hacia la que se desliza
## Alice mientras lo pisa. La fija el nivel en cada fotograma; 0 = comportamiento normal.
## Las flechas siguen acelerando o frenando un poco el deslizamiento.
var slide_speed := 0.0
const SLIDE_CONTROL := 55.0
const SLIDE_ACCEL := 520.0
## Ralentización del Mundo 8 (nube del Rey Pesadelo): reduce la velocidad y la aceleración
## horizontales hasta `slow_until`; no bloquea el salto ni los disparos. Una nube nueva sólo
## renueva el plazo (nunca se acumula) y el efecto termina solo.
var slow_until := 0.0
var slow_factor := 1.0
const SLOW_TINT := Color(0.82, 0.68, 1.0)


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
	# destello blanco al recibir un golpe (IMP-020), el mismo que usan los jefes
	_flash = ShaderMaterial.new()
	_flash.shader = preload("res://resources/effects/flash.gdshader")
	sprite.material = _flash
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
	var sleepy_speed := 0.72 if time < sleepy_until else 1.0
	var swim := SWIM_SPEED if in_water() else 1.0
	var slow := slow_factor if time < slow_until else 1.0
	var target := axis * (float(T.runSpeed) if controls.run else float(T.walkSpeed)) * surface_speed * sleepy_speed * swim * slow
	if not grounded:
		target += carry_x
	var vx := velocity.x
	var rate: float
	if grounded:
		var same_dir := axis != 0 and signf(axis) == signf(vx if vx != 0 else axis)
		rate = (T.groundAccel if same_dir else T.groundDecel) * surface_friction
	else:
		rate = T.airAccel if axis != 0 else T.airDecel
	rate *= slow
	var next := target
	if absf(target - vx) > rate * dt:
		next = vx + signf(target - vx) * rate * dt
	# empuje externo (viento del jefe, retroceso del tirachinas)
	if push_x != 0:
		next += push_x * dt
		push_x *= pow(0.02, dt)
		if absf(push_x) < 5:
			push_x = 0
	if slide_speed != 0 and grounded and time >= stunned_until:
		# deslizamiento rápido con algo de control (no se para del todo ni sube el tobogán)
		next = move_toward(vx, slide_speed + axis * SLIDE_CONTROL, SLIDE_ACCEL * dt)
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
	if in_water():
		_swim(time, can_control and buffered)
	elif can_control and buffered and coyote and not jumping:
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
	if in_water():
		velocity.y = clampf(velocity.y, WATER_MAX_RISE, WATER_MAX_FALL)

	# tinte violeta mientras dura la ralentización
	if slow < 1.0:
		sprite.modulate = Color(SLOW_TINT, sprite.modulate.a)
	elif slow_until > 0:
		clear_slow()
	# parpadeo durante la invulnerabilidad
	if time < invulnerable_until:
		sprite.modulate.a = 0.35 if int(floor(time / 70.0)) % 2 else 1.0
	else:
		sprite.modulate.a = 1.0


func _integrate(delta: float) -> void:
	if gravity_enabled:
		velocity.y += C.GRAVITY * delta * (WATER_GRAVITY if in_water() else 1.0)
	var was_grounded := grounded
	var vy_before := velocity.y
	move_and_slide()
	grounded = is_on_floor()
	landed_speed = vy_before if grounded and not was_grounded else 0.0
	_update_train_carry(was_grounded)
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


## Al despegar de un vagón en marcha se guarda su velocidad (ver carry_x); al tocar suelo o
## agua se olvida. Sólo los trenes: las demás plataformas móviles no cambian.
func _update_train_carry(was_grounded: bool) -> void:
	if grounded or in_water() or dead:
		carry_x = 0.0
		_ride_vx = 0.0
		if grounded:
			for i in get_slide_collision_count():
				var col := get_slide_collision(i)
				var other := col.get_collider()
				if col.get_normal().y < -0.5 and other != null and "line" in other:
					_ride_vx = get_platform_velocity().x
		return
	if was_grounded and _ride_vx != 0.0:
		carry_x = _ride_vx
		_ride_vx = 0.0


func in_water() -> bool:
	return water_surface < INF


## Entra o sale del agua (lo llama el nivel en cada fotograma). Devuelve true al zambullirse.
func set_water(surface: float) -> bool:
	var entering := surface < INF and not in_water()
	# al asomar fuera del agua se puede saltar como desde el suelo (mismo coyote time)
	if surface == INF and in_water() and not dead:
		last_grounded_at = now
	water_surface = surface
	sprite.self_modulate = C.rgb(0xc8e6ff) if in_water() else Color.WHITE
	if entering:
		jumping = false
		velocity.y = minf(velocity.y, 110.0)
	return entering


## Brazada: con la cabeza en la superficie, el salto saca a Alice del agua; si no, sube un poco.
func _swim(time: float, pressed: bool) -> void:
	if not pressed or time < swim_ready_at:
		return
	last_jump_press_at = -9999
	swim_ready_at = time + 220
	if position.y - 31 <= water_surface + 6:
		# salto fuera del agua: a toques también sale (no se le aplica el corte del salto variable)
		velocity.y = float(T.jumpVelocity) * 0.92
		jumping = false
		AudioManager.play("jump")
	else:
		velocity.y = SWIM_STROKE
		AudioManager.play("swim")
	level.effects.bubble_pop(position.x, position.y - 30)


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


func apply_sleep(duration_ms: float) -> void:
	sleepy_until = maxf(sleepy_until, now + duration_ms)


## Ralentiza a Alice `duration_ms` (renueva el plazo, sin acumular). factor: 0..1.
func apply_slow(duration_ms: float, factor := 0.5) -> void:
	slow_factor = clampf(factor, 0.2, 1.0)
	slow_until = maxf(slow_until, minf(now + duration_ms, now + 4000.0))


func is_slowed() -> bool:
	return now < slow_until


func clear_slow() -> void:
	slow_until = 0.0
	slow_factor = 1.0
	sprite.modulate = Color(Color.WHITE, sprite.modulate.a)


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
	_flash.set_shader_parameter("flash", 0.85)
	level.after(HURT_FLASH_MS, func(): _flash.set_shader_parameter("flash", 0.0))
	level.hit_stop(HURT_HIT_STOP_MS)
	hp_changed.emit(hp)
	PlaytestLog.event(level, "golpe", "x=%s" % str(from_x) if from_x != null else "")
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
	set_water(INF)
	push_x = 0
	clear_slow()
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
