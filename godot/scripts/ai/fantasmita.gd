class_name FantasmitaMonster
extends Enemy
## Fantasmita Farol: fantasma blanco con gorro de dormir morado y un farol. Determinista:
##  1 flota por su ruta con una onda suave,
##  2 al ver a Alice se coloca a una altura cómoda (dentro de su franja de vuelo),
##  3 levanta el farol (aviso PREP_MS: destello y farol brillante),
##  4 lanza UNA estrellita luminosa lenta hacia Alice,
##  5 retrocede un poco (RETREAT_MS) y vuelve a vigilar tras attack_cooldown.
## Su farol ilumina: los puentes ocultos cercanos se ven (y se pisan) un rato mientras pasa.
## Derrotado se disuelve en partículas: el farol cae y su espíritu sube.
## Opciones de aparición: fly = [teselas que sube, teselas que baja], wave (px).

const PREP_MS := 750.0
const RETREAT_MS := 650.0
const SHOT_SPEED := 82.0
const ABOVE := 46.0
const LIGHT_RANGE := 72.0
const LIGHT_MS := 1600.0

var hover_y := 0.0
var min_y := 0.0
var max_y := 0.0
var wave := 6.0
var retreat_until := 0.0
var light_at := 0.0


func _ready() -> void:
	super()
	gravity_enabled = false
	hover_y = position.y
	var fly: Array = spawn.get("fly", [3, 2])
	min_y = hover_y - float(fly[0]) * C.TILE
	max_y = hover_y + float(fly[1]) * C.TILE
	wave = float(spawn.get("wave", 6))


## Nombres de la hoja: "float" para moverse y "defeat" para la derrota.
func anim(anim_name: String, ignore_if_playing := true) -> void:
	match anim_name:
		"walk": anim_name = "float"
		"defeated": anim_name = "defeat"
	super(anim_name, ignore_if_playing)


func _hover_to(y: float) -> void:
	var target := y + sin(now / 340.0) * wave
	velocity.y = clampf((target - position.y) * 5.0, -70, 70)


func _physics_process(delta: float) -> void:
	super(delta)
	if not finished and is_alive() and level != null and now >= light_at:
		light_at = now + 300
		_light_bridges()


## La luz del farol revela un rato los puentes ocultos cercanos.
func _light_bridges() -> void:
	for hb in level.level_objects.get("hidden_bridges", []):
		if is_instance_valid(hb) and hb.position.distance_to(position) < LIGHT_RANGE:
			hb.reveal(LIGHT_MS)


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
	velocity.x = facing * def.speed * 0.7 * speed_factor()
	_hover_to(hover_y)
	anim("float")


func alert_update(time: float) -> void:
	anim("float")
	var target_y := clampf(player.position.y - ABOVE, min_y, max_y)
	_hover_to(target_y)
	var d := distance_to_player()
	if time < retreat_until:
		# retrocede tras disparar, sin salir de su ruta
		var away := -signf(d.dx)
		velocity.x = away * def.speed * speed_factor() if (away < 0 and position.x > patrol_min - 24) or (away > 0 and position.x < patrol_max + 24) else 0.0
		return
	face_player()
	var want := 0.0
	if absf(d.dx) < 64:
		want = -signf(d.dx)
	elif absf(d.dx) > 140:
		want = signf(d.dx)
	if (want < 0 and position.x <= patrol_min - 24) or (want > 0 and position.x >= patrol_max + 24):
		want = 0
	velocity.x = want * def.speed * speed_factor()
	if time >= attack_ready_at and absf(position.y - target_y) < 14:
		fsm.set_state(ATTACK)


func attack() -> void:
	velocity = Vector2.ZERO
	Anim.show_frame(sprite, "attack", 0)
	telegraph(PREP_MS)
	after(PREP_MS * 0.5, func(): Anim.show_frame(sprite, "attack", 1))
	after(PREP_MS, _shoot)
	after(PREP_MS + 350, func():
		retreat_until = now + RETREAT_MS
		fsm.set_state(ALERT))


func _update_ATTACK(_time: float, _delta: float) -> void:
	velocity = Vector2.ZERO


func _shoot() -> void:
	face_player()
	Anim.show_frame(sprite, "attack", 3)
	var from := position + Vector2(facing * 12, -def.body_size.y / 2.0)
	var v := (player.position + Vector2(0, -14) - from).normalized() * SHOT_SPEED
	level.spawn_projectile("enemy", {"x": from.x, "y": from.y, "vx": v.x, "vy": v.y, "texture": "w8_fx", "frame": "ghost_star",
		"lifespan": 3400, "body": 8, "owner": "enemy", "kind": "ghost_star", "damage": 1, "spin": 220})
	AudioManager.play("ghost_shot")


func _enter_HURT(prev: String, data: Variant) -> void:
	super(prev, data)
	velocity.y = -40


func _update_HURT(_time: float, _delta: float) -> void:
	velocity *= 0.92


## Derrota: se duerme sobre su nube, se disuelve en partículas, el farol cae y su espíritu sube.
func _enter_DEFEATED(prev: String, data: Variant) -> void:
	super(prev, data)
	if data is Dictionary and data.get("toStar", false):
		return
	AudioManager.play("ghost_vanish")
	var burst := ParticleBurst.new().setup({
		"speed": [20, 60], "angle": [200, 340], "life": [500, 900], "scale": [1.6, 0], "alpha": [1, 0],
		"gravity": -40, "colors": Effects.colors([0xffffff, 0xc8a5ff, 0xffe18c]),
	})
	burst.position = Vector2.ZERO
	level.fx_root.add_child(burst)
	burst.explode(18, position + Vector2(0, -10))
	var lantern := Sprite2D.new()
	lantern.texture = Assets.frame("w8_fx", "ghost_lantern")
	lantern.position = position + Vector2(-facing * 8, -8)
	level.fx_root.add_child(lantern)
	var lt := lantern.create_tween().set_parallel()
	lt.tween_property(lantern, "position:y", lantern.position.y + 40, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lt.tween_property(lantern, "rotation_degrees", 120.0, 0.8)
	lt.tween_property(lantern, "modulate:a", 0.0, 0.8)
	lt.chain().tween_callback(lantern.queue_free)
	var spirit := Sprite2D.new()
	spirit.texture = Assets.frame("w8_fx", "ghost_spirit")
	spirit.position = position + Vector2(0, -14)
	spirit.modulate.a = 0.8
	level.fx_root.add_child(spirit)
	var st := spirit.create_tween().set_parallel()
	st.tween_property(spirit, "position:y", spirit.position.y - 34, 1.2).set_trans(Tween.TRANS_SINE)
	st.tween_property(spirit, "modulate:a", 0.0, 1.2)
	st.chain().tween_callback(spirit.queue_free)
