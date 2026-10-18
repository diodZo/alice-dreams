class_name RollingYarn
extends Area2D
## Ovillo obstáculo con recorrido controlado y pequeñas hebras visuales.

var x_min := 0.0
var x_max := 0.0
var speed := 62.0
var dir := 1
var sprite: Sprite2D
var dust_at := 0.0

## def: { x, y (teselas, superficie), range: [desde, hasta] (teselas), speed (px/s), frame }
func setup(def: Dictionary, atlas := "world3_objects") -> RollingYarn:
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE)
	x_min = float(def.range[0]) * C.TILE + 8
	x_max = float(def.range[1]) * C.TILE + 8
	speed = float(def.get("speed", 62))
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "yarn_ball_pink"))
	# gira sobre su centro, apoyado en el suelo
	var size := sprite.texture.get_size()
	sprite.position.y = -size.y / 2.0
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = maxf(6.0, minf(size.x, size.y) * 0.4)
	cs.shape = shape
	cs.position.y = -size.y / 2.0
	add_child(cs)
	Trigger.configure(self, "hazard")
	z_index = C.Z_ENEMY
	return self

func _physics_process(delta: float) -> void:
	position.x += dir * speed * delta
	sprite.rotation += dir * speed * delta / maxf(sprite.texture.get_width() / 2.0, 1.0)
	if position.x >= x_max or position.x <= x_min:
		position.x = clampf(position.x, x_min, x_max)
		dir *= -1
	dust_at += delta
	if dust_at > 0.16:
		dust_at = 0
		var thread := Sprite2D.new()
		thread.texture = Assets.frame("w3_fx", "yarn_thread")
		thread.position = position + Vector2(-dir * 10, -5)
		thread.flip_h = dir < 0
		get_parent().add_child(thread)
		var tw := thread.create_tween().set_parallel()
		tw.tween_property(thread, "modulate:a", 0.0, 0.35)
		tw.tween_property(thread, "position:y", thread.position.y - 5, 0.35)
		tw.chain().tween_callback(thread.queue_free)
