class_name Portal
extends Area2D
## Portal al siguiente mundo: aparece al derrotar al jefe (port de Portal en Collectibles.js).

var used := false
var sprite: AnimatedSprite2D


func setup(pos: Vector2) -> Portal:
	position = pos
	z_index = C.Z_PICKUP
	var glow := Sprite2D.new()
	glow.texture = Assets.generated("glow")
	glow.position = Vector2(0, -20)
	glow.scale = Vector2(4, 4)
	glow.modulate = C.LAVENDER
	glow.z_index = -1
	add_child(glow)
	var gt := glow.create_tween().set_loops().set_parallel()
	gt.tween_property(glow, "modulate:a", 0.4, 0.7)
	gt.tween_property(glow, "scale", Vector2(4.6, 4.6), 0.7)
	gt.chain().tween_property(glow, "modulate:a", 1.0, 0.7)
	gt.parallel().tween_property(glow, "scale", Vector2(4, 4), 0.7)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Assets.sprite_frames("fx_portal")
	Anim.set_origin(sprite, Vector2(40, 40), 0.5, 1.0)
	add_child(sprite)
	sprite.play("spin")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 34)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -20)
	add_child(cs)
	Trigger.configure(self, "portal")
	sprite.scale = Vector2.ZERO
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return self
