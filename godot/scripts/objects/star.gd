class_name Star
extends CharacterBody2D
## Estrella coleccionable (port de Star en entities/Collectibles.js): del mapa (flota en su
## sitio), extra (sale despedida de un monstruo atrapado, cae con rebote) o la estrella
## dorada especial que suelta Nubarrón.

var level: Node
var id := ""
var bonus := false
var special := false
var collectable_at := 0.0
var active := true
var sprite: Sprite2D
var glow: Sprite2D
var area: Area2D
var moves := false
var bounce_factor := 0.4
var _float_tween: Tween
var _spin_tween: Tween


func setup(owner_level: Node, pos: Vector2, opts: Dictionary = {}) -> Star:
	level = owner_level
	id = opts.get("id", "")
	bonus = opts.get("bonus", false)
	special = opts.get("special", false)
	position = pos
	z_index = C.Z_PICKUP
	collision_layer = 0
	collision_mask = C.L_WORLD
	var s := 1.5 if special else 0.8
	sprite = Sprite2D.new()
	# "look": [atlas, fotograma] permite a cada mundo usar su propia estrella (Mundo 2)
	var look: Variant = opts.get("look", "")
	if look is Array and look.size() == 2:
		sprite.texture = Assets.frame(look[0], look[1])
		s *= 16.0 / maxf(sprite.texture.get_width(), 1.0)
	else:
		sprite.texture = Assets.frame("fx", "star_gold")
	sprite.scale = Vector2(s, s)
	add_child(sprite)
	var circle := CircleShape2D.new()
	circle.radius = sprite.texture.get_width() * 0.35 * s
	var body := CollisionShape2D.new()
	body.shape = circle
	add_child(body)
	area = Area2D.new()
	var acs := CollisionShape2D.new()
	acs.shape = circle
	area.add_child(acs)
	add_child(area)
	Trigger.configure(area, "star", self)
	return self


func _ready() -> void:
	if bonus:
		# sale despedida hacia arriba y cae al suelo
		moves = true
		velocity = Vector2(randi_range(-40, 40), -180)
		collectable_at = level.now + 350
	else:
		_float_tween = create_tween().set_loops()
		var y := position.y
		var d := (700 + randf() * 300) / 1000.0
		_float_tween.tween_property(self, "position:y", y - 2, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_float_tween.tween_property(self, "position:y", y, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if special:
		glow = Sprite2D.new()
		glow.texture = Assets.generated("glow")
		glow.scale = Vector2(3, 3)
		glow.modulate = C.YELLOW
		glow.z_index = -1
		glow.show_behind_parent = true
		add_child(glow)
		var gt := glow.create_tween().set_loops()
		gt.tween_property(glow, "modulate:a", 0.4, 0.5)
		gt.tween_property(glow, "modulate:a", 1.0, 0.5)
		_spin_tween = sprite.create_tween().set_loops()
		_spin_tween.tween_property(sprite, "rotation_degrees", 360.0, 3.0).from(0.0)


func _physics_process(delta: float) -> void:
	if not moves or not active:
		return
	velocity.y += C.GRAVITY * delta
	var col := move_and_collide(velocity * delta)
	if col != null:
		# rebote de Arcade Physics (bounce 0.4) en el eje del choque
		var n := col.get_normal()
		if absf(n.y) > 0.5:
			velocity.y = -velocity.y * bounce_factor
			if absf(velocity.y) < 8:
				velocity.y = 0
		if absf(n.x) > 0.5:
			velocity.x = -velocity.x * bounce_factor


## La estrella especial deja de flotar y cae hasta el suelo con rebote (BossScene).
func drop_to(y: float) -> void:
	moves = false
	if _float_tween:
		_float_tween.kill()
	if _spin_tween:
		_spin_tween.kill()
	var tw := create_tween()
	tw.tween_property(self, "position:y", y, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func collect() -> bool:
	if not active or level.now < collectable_at:
		return false
	active = false
	level.effects.sparkle(position.x, position.y, 30 if special else 8)
	AudioManager.play("pickup" if special else "star")
	area.set_deferred("monitorable", false)
	queue_free()
	return true


func fade_out() -> void:
	if not active:
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
