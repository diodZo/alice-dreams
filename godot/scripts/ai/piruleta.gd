class_name PiruletaMonster
extends Enemy
## Piruleta Voladora: piruleta rosa y blanca con alitas y un palo corto.
##  1 flota y patrulla en horizontal por su ruta con una onda suave,
##  2 al ver a Alice se coloca a una altura cómoda por encima de ella (siempre dentro de su
##    franja de vuelo: puede subir o bajar a otra altura) y a cierta distancia,
##  3 se inclina hacia ella (aviso, PREP_MS, con destello),
##  4 lanza tres caramelitos lentos en abanico: siempre quedan huecos entre ellos,
##  5 vuelve a flotar y repite tras attack_cooldown.
## Opciones de aparición: fly = [teselas que puede subir, teselas que puede bajar] (por defecto
## [3, 2]) respecto a la altura en que aparece; wave (alto de la onda en px).

const PREP_MS := 700.0
const SHOT_SPEED := 72.0
const SPREAD := 22.0
const KEEP_DX := 96.0
const ABOVE := 52.0

var hover_y := 0.0
var min_y := 0.0
var max_y := 0.0
var wave := 6.0


func _ready() -> void:
	super()
	gravity_enabled = false
	hover_y = position.y
	var fly: Array = spawn.get("fly", [3, 2])
	min_y = hover_y - float(fly[0]) * C.TILE
	max_y = hover_y + float(fly[1]) * C.TILE
	wave = float(spawn.get("wave", 6))


## El dibujo de la hoja para "andar" es el de volar.
func anim(anim_name: String, ignore_if_playing := true) -> void:
	super("fly" if anim_name == "walk" else anim_name, ignore_if_playing)


## Vuelve hacia `y` con una onda regular.
func _hover_to(y: float) -> void:
	var target := y + sin(now / 320.0) * wave
	velocity.y = clampf((target - position.y) * 5.0, -70, 70)


func _update_IDLE(time: float, delta: float) -> void:
	super(time, delta)
	_hover_to(hover_y)


func _update_PATROL(_time: float, _delta: float) -> void:
	if can_see_player():
		fsm.set_state(ALERT)
		return
	if position.x <= patrol_min or blocked_left:
		facing = 1
	elif position.x >= patrol_max or blocked_right:
		facing = -1
	sprite.flip_h = facing < 0
	velocity.x = facing * def.speed * speed_factor()
	_hover_to(hover_y)
	anim("fly")


func alert_update(time: float) -> void:
	face_player()
	anim("fly")
	var target_y := clampf(player.position.y - ABOVE, min_y, max_y)
	_hover_to(target_y)
	# mantiene distancia en horizontal sin salir de su ruta (con un pequeño margen)
	var d := distance_to_player()
	var want := 0.0
	if absf(d.dx) < KEEP_DX * 0.7:
		want = -signf(d.dx)
	elif absf(d.dx) > KEEP_DX * 1.4:
		want = signf(d.dx)
	if (want < 0 and position.x <= patrol_min - 24) or (want > 0 and position.x >= patrol_max + 24):
		want = 0
	velocity.x = want * def.speed * speed_factor()
	if time >= attack_ready_at and absf(position.y - target_y) < 12:
		fsm.set_state(ATTACK)


func attack() -> void:
	velocity = Vector2.ZERO
	anim("attack", false)
	telegraph(PREP_MS)
	after(PREP_MS, _shoot)
	after(PREP_MS + 650, func(): fsm.set_state(ALERT))


func _update_ATTACK(_time: float, _delta: float) -> void:
	velocity = Vector2.ZERO


func _shoot() -> void:
	face_player()
	anim("shoot", false)
	var from := position + Vector2(facing * 10, -def.body_size.y / 2.0)
	var aim := (player.position + Vector2(0, -14) - from).normalized()
	for a in [-SPREAD, 0.0, SPREAD]:
		var v := aim.rotated(deg_to_rad(a)) * SHOT_SPEED
		level.spawn_projectile("enemy", {"x": from.x, "y": from.y, "vx": v.x, "vy": v.y, "texture": "w7_fx", "frame": "piru_candy",
			"lifespan": 3200, "body": 7, "owner": "enemy", "kind": "piru_candy", "damage": 1, "spin": 240})
	AudioManager.play("candy_pop")


func _enter_HURT(prev: String, data: Variant) -> void:
	super(prev, data)
	velocity.y = -40


func _update_HURT(_time: float, _delta: float) -> void:
	velocity *= 0.92


## Derrotada, cae suavemente dando vueltas antes de desaparecer.
func _enter_DEFEATED(prev: String, data: Variant) -> void:
	super(prev, data)
	if data is Dictionary and data.get("toStar", false):
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y + 18, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "rotation_degrees", 90.0 * facing, 0.7)
