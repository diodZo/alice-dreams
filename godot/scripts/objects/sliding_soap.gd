class_name SlidingSoap
extends Area2D
## Jabón móvil del Mundo 4 como obstáculo: se desliza por el suelo de un extremo a otro de su
## tramo dejando burbujas; tocarlo hace daño (área "hazard"). Los jabones que sirven de
## plataforma son plataformas móviles normales con el fotograma del jabón.

var level: Node
var sprite: Sprite2D
var x_min := 0.0
var x_max := 0.0
var speed := 70.0
var dir := 1
var bubble_at := 0.0


## def: { x, y (teselas, superficie), range: [desde, hasta] (teselas), speed (px/s), frame }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> SlidingSoap:
	level = owner_level
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "soap_pink"))
	var size := sprite.texture.get_size()
	sprite.position.y = -size.y / 2.0 + 1
	add_child(sprite)
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE)
	x_min = float(def.range[0]) * C.TILE + 8
	x_max = float(def.range[1]) * C.TILE + 8
	speed = float(def.get("speed", 70))
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x - 10, size.y - 8)
	cs.shape = shape
	cs.position = Vector2(0, -shape.size.y / 2.0)
	add_child(cs)
	Trigger.configure(self, "hazard")
	z_index = C.Z_ENEMY
	return self


func _physics_process(delta: float) -> void:
	position.x += dir * speed * delta
	if position.x >= x_max or position.x <= x_min:
		position.x = clampf(position.x, x_min, x_max)
		dir *= -1
	sprite.flip_h = dir < 0
	bubble_at += delta
	if bubble_at > 0.22 and level != null:
		bubble_at = 0
		var b := Sprite2D.new()
		b.texture = Assets.frame("w4_fx", "bubble_s")
		b.position = position + Vector2(-dir * 18, -6)
		level.fx_root.add_child(b)
		var tw := b.create_tween().set_parallel()
		tw.tween_property(b, "position:y", b.position.y - 12, 0.6)
		tw.tween_property(b, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(b.queue_free)
