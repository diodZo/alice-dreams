class_name Checkpoint
extends Area2D
## Bandera de punto de control (port de entities/Checkpoint.js). La lógica de reaparición
## está en CheckpointManager.

var level: Node
var index := 0
var respawn := Vector2.ZERO
var activated := false
var sprite: Sprite2D


## def: { x, y (teselas, superficie) }
func setup(owner_level: Node, def: Dictionary, atlas: String, i: int, flag_frame := "flag") -> Checkpoint:
	level = owner_level
	index = i
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE + 3)
	respawn = Vector2(position.x, float(def.y) * C.TILE)
	z_index = C.Z_DECOR_BACK + 1
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, flag_frame)
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0)
	sprite.modulate = C.rgb(0x8b86b8)
	add_child(sprite)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 44)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -22)
	add_child(cs)
	Trigger.configure(self, "checkpoint")
	return self


func activate(silent := false) -> bool:
	if activated:
		return false
	activated = true
	sprite.modulate = Color.WHITE
	if not silent:
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "scale:y", 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "scale:y", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		level.effects.sparkle(position.x, position.y - 30, 16)
	return true
