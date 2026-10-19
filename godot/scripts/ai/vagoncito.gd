class_name VagoncitoMonster
extends Enemy
## Vagoncito Chispa: locomotora pequeña y sonriente que patrulla vías y pasarelas (se para en
## los bordes) soltando humo de juguete por la chimenea. Al ver a Alice alterna, siempre en el
## mismo orden, tres ataques con aviso (silbato, destello y pose de carga):
##  SPARKS: lanza dos chispas estelares hacia delante.
##  DASH: acelera en horizontal un tramo corto (frena en bordes y muros).
##  SMOKE: suelta una nube de humo translúcida delante: tapa un poco la vista de una zona
##         pequeña durante SMOKE_MS, nunca oculta del todo a Alice y no hace daño.
## Es mucho más pequeño que Locomostro y sus ataques son cortos.

const WARN_MS := 550.0
const DASH_MS := 700.0
const DASH_SPEED := 165.0
const SMOKE_MS := 2200.0
const SPARK_SPEED := 120.0
const PATTERN := ["SPARKS", "DASH", "SMOKE"]

var pattern_i := 0
var current := ""
var dashing := false
var puff_at := 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if finished or level == null or not is_alive():
		return
	if level.now >= puff_at and not is_trapped():
		puff_at = level.now + (260.0 if dashing else 700.0)
		_chimney_puff()


func _update_PATROL(time: float, delta: float) -> void:
	if can_see_player() and absf(distance_to_player().dy) < 34:
		fsm.set_state(ALERT)
		return
	super(time, delta)


func alert_update(time: float) -> void:
	var d := distance_to_player()
	face_player()
	velocity.x = 0
	anim("idle")
	if grounded and time >= attack_ready_at and d.dist <= def.attack_range:
		fsm.set_state(ATTACK)


func attack() -> void:
	current = PATTERN[pattern_i % PATTERN.size()]
	pattern_i += 1
	dashing = false
	face_player()
	Anim.show_frame(sprite, "attack", 0)
	telegraph(WARN_MS)
	AudioManager.play("whistle_small")
	match current:
		"SPARKS":
			after(WARN_MS, _sparks)
			after(WARN_MS + 600, func(): fsm.set_state(ALERT))
		"DASH":
			after(WARN_MS, func():
				dashing = true
				anim("walk", false))
			after(WARN_MS + DASH_MS, func():
				dashing = false
				velocity.x = 0)
			after(WARN_MS + DASH_MS + 400, func(): fsm.set_state(ALERT))
		_:
			after(WARN_MS, _smoke)
			after(WARN_MS + 500, func(): fsm.set_state(ALERT))


func _update_ATTACK(_time: float, _delta: float) -> void:
	if not dashing:
		velocity.x = 0
		return
	if not ground_ahead(facing) or (facing < 0 and blocked_left) or (facing > 0 and blocked_right):
		dashing = false
		velocity.x = 0
		return
	velocity.x = facing * DASH_SPEED * speed_factor()


func _sparks() -> void:
	anim("attack", false)
	for vy in [-30.0, 10.0]:
		level.spawn_projectile("enemy", {"x": position.x + facing * 14, "y": position.y - 12, "vx": facing * SPARK_SPEED, "vy": vy,
			"texture": "w6_fx", "frame": "spark_star", "lifespan": 2200, "body": 8, "owner": "enemy", "kind": "spark", "damage": 1, "spin": 300})
	level.effects.sparkle(position.x + facing * 14, position.y - 12, 5)
	AudioManager.play("shoot_sling")


func _smoke() -> void:
	var c := Sprite2D.new()
	c.texture = Assets.frame("w6_fx", "smoke_big")
	c.position = position + Vector2(facing * 34, -22)
	c.z_index = C.Z_DECOR_FRONT
	c.modulate.a = 0.0
	c.scale = Vector2(0.4, 0.4)
	level.fx_root.add_child(c)
	var tw := c.create_tween()
	tw.set_parallel()
	tw.tween_property(c, "modulate:a", 0.62, 0.3)
	tw.tween_property(c, "scale", Vector2.ONE, 0.3)
	tw.chain().tween_interval(SMOKE_MS / 1000.0 - 0.8)
	tw.chain().tween_property(c, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(c.queue_free)
	c.set_meta("smoke", true)
	AudioManager.play("wind")


func _chimney_puff() -> void:
	var p := Sprite2D.new()
	p.texture = Assets.frame("w6_fx", "smoke_s")
	p.position = position + Vector2(facing * 6, -def.body_size.y - 10)
	p.scale = Vector2(0.6, 0.6)
	level.fx_root.add_child(p)
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "position:y", p.position.y - 12, 0.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(p.queue_free)


func _exit_ATTACK(next: String) -> void:
	super(next)
	dashing = false


## Derrota infantil: frena, se tambalea y vuelca suavemente entre nubecitas de humo blanco.
func _enter_DEFEATED(prev: String, data: Variant) -> void:
	super(prev, data)
	if data is Dictionary and data.get("toStar", false):
		return
	for i in 3:
		level.effects.poof(position.x + (i - 1) * 8, position.y - 12, 3)
