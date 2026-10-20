class_name MurcibolaMonster
extends Enemy
## Murcibola de Trapo: murciélago de peluche morado con alas rosadas, costuras y ojos de botón.
##  1 patrulla el aire de su ruta con un aleteo ondulado,
##  2 al ver a Alice se coloca A UN LADO de ella y por encima (nunca justo encima: siempre a
##    SIDE_DX px en horizontal), a la vista,
##  3 se encoge (anticipación WINDUP_MS con destello y "!"),
##  4 se lanza en picada en línea recta hacia el punto donde estaba Alice al avisar (fijado:
##    si Alice se aparta, falla),
##  5 remonta y vuelve a su zona de descanso (`rest`) antes de poder repetir.
## Opciones de aparición: rest = [x, y] en teselas (zona de descanso; por defecto, donde aparece).

const WINDUP_MS := 700.0
const DIVE_SPEED := 190.0
const DIVE_MAX_MS := 900.0
const SIDE_DX := 70.0
const ABOVE := 70.0
const RETURN_SPEED := 70.0
## Hacia dónde mira el dibujo de la hoja (la estela de la picada queda detrás, a la derecha).
const SPRITE_FACES := -1

var rest_pos := Vector2.ZERO
var dive_target := Vector2.ZERO
var dive_dir := Vector2.ZERO
var phase := ""


func _ready() -> void:
	super()
	gravity_enabled = false
	var r: Variant = spawn.get("rest")
	rest_pos = Vector2(float(r[0]) * C.TILE + 8, float(r[1]) * C.TILE) if r is Array else position


func anim(anim_name: String, ignore_if_playing := true) -> void:
	match anim_name:
		"walk": anim_name = "fly"
		"defeated": anim_name = "defeat"
		"attack": anim_name = "dive_attack"
	super(anim_name, ignore_if_playing)


func _look(dir: float) -> void:
	if dir != 0:
		facing = int(signf(dir))
	sprite.flip_h = facing != SPRITE_FACES


func face_player() -> void:
	_look(player.position.x - position.x)


func _fly_to(target: Vector2, speed: float) -> void:
	var d := target - position
	var bob := sin(now / 260.0) * 10.0
	velocity = Vector2(clampf(d.x * 3.0, -speed, speed), clampf((d.y + bob) * 3.0, -speed, speed)) * speed_factor()


func _update_IDLE(time: float, delta: float) -> void:
	super(time, delta)
	_fly_to(rest_pos, RETURN_SPEED)


func _update_PATROL(_time: float, _delta: float) -> void:
	if can_see_player():
		fsm.set_state(ALERT)
		return
	if position.x <= patrol_min or blocked_left:
		facing = 1
	elif position.x >= patrol_max or blocked_right:
		facing = -1
	_look(facing)
	velocity.x = facing * def.speed * 0.7 * speed_factor()
	velocity.y = (rest_pos.y + sin(now / 300.0) * 8.0 - position.y) * 3.0
	anim("fly")


func alert_update(time: float) -> void:
	anim("fly")
	face_player()
	# a un lado de Alice (el lado en que ya está) y por encima, dentro de su ruta
	var side := -1.0 if position.x < player.position.x else 1.0
	var spot := Vector2(clampf(player.position.x + side * SIDE_DX, patrol_min - 32, patrol_max + 32), minf(player.position.y - ABOVE, rest_pos.y + 24))
	_fly_to(spot, def.speed)
	var dx := absf(player.position.x - position.x)
	if time >= attack_ready_at and position.distance_to(spot) < 18 and dx >= SIDE_DX * 0.6 and not player.dead:
		fsm.set_state(ATTACK)


func attack() -> void:
	phase = "windup"
	velocity = Vector2.ZERO
	face_player()
	Anim.show_frame(sprite, "dive_attack", 0)
	show_alert()
	telegraph(WINDUP_MS)
	# el punto de la picada se fija al avisar
	dive_target = player.position + Vector2(0, -12)
	after(WINDUP_MS, func():
		phase = "dive"
		dive_dir = (dive_target - position).normalized()
		_look(dive_dir.x)
		Anim.show_frame(sprite, "dive_attack", 2)
		AudioManager.play("bat_dive"))
	after(WINDUP_MS + DIVE_MAX_MS, _end_dive)


func _update_ATTACK(_time: float, _delta: float) -> void:
	match phase:
		"windup":
			velocity = Vector2(0, -12)
		"dive":
			velocity = dive_dir * DIVE_SPEED * speed_factor()
			if position.distance_to(dive_target) < 8 or blocked_up or blocked_left or blocked_right or is_on_floor():
				_end_dive()
		_:
			_fly_to(rest_pos, RETURN_SPEED * 1.4)


func _end_dive() -> void:
	if phase != "dive":
		return
	phase = "return"
	Anim.show_frame(sprite, "dive_attack", 3)
	level.effects.poof(position.x, position.y, 4)
	after(1100, func():
		phase = ""
		fsm.set_state(ALERT))


func _exit_ATTACK(next: String) -> void:
	super(next)
	phase = ""


func _enter_HURT(prev: String, data: Variant) -> void:
	super(prev, data)
	phase = ""
	velocity.y = -40


func _update_HURT(_time: float, _delta: float) -> void:
	velocity *= 0.9


## Derrota: cae dormido entre una nubecita de sombra y se deshace en bruma.
func _enter_DEFEATED(prev: String, data: Variant) -> void:
	super(prev, data)
	if data is Dictionary and data.get("toStar", false):
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", position.y + 16, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var puff := Sprite2D.new()
	puff.texture = Assets.frame("w8_fx", "shadow_puff")
	puff.position = position + Vector2(0, -4)
	puff.modulate.a = 0.0
	level.fx_root.add_child(puff)
	var pt := puff.create_tween()
	pt.tween_interval(0.5)
	pt.tween_property(puff, "modulate:a", 0.85, 0.2)
	pt.tween_property(puff, "modulate:a", 0.0, 0.6)
	pt.tween_callback(puff.queue_free)
