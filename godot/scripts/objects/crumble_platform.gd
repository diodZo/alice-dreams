class_name CrumblePlatform
extends StaticBody2D
## Nube de vapor: se deshace poco después de pisarla y reaparece al rato
## (port de CrumblePlatform en entities/Platforms.js).

var level: Node
var sprite: Sprite2D
var shape: CollisionShape2D
var base_x := 0.0
var crumbling := false


## def: { x, y, frame? } en teselas
func setup(owner_level: Node, def: Dictionary, atlas: String) -> CrumblePlatform:
	level = owner_level
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "cloud_puff"))
	sprite.modulate = C.rgb(0xe9f3ff)
	add_child(sprite)
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	position.x = float(def.x) * C.TILE
	shape = CloudPlatform.add_cloud_shape(self, sprite, sprite.texture.get_size(), float(def.y) * C.TILE)
	base_x = sprite.position.x
	return self


func on_player_contact() -> void:
	step_on()


func step_on() -> void:
	if crumbling:
		return
	crumbling = true
	var tw := sprite.create_tween()
	for i in 7:
		tw.tween_property(sprite, "position:x", base_x + 1.5, 0.045)
		tw.tween_property(sprite, "position:x", base_x, 0.045)
	sprite.modulate = Color.WHITE
	var ref: WeakRef = weakref(self)
	level.after(560, func():
		var c: CrumblePlatform = ref.get_ref()
		if c != null:
			c._vanish())


func _vanish() -> void:
	shape.set_deferred("disabled", true)
	level.effects.poof(position.x, position.y + 6, 10)
	var fade := sprite.create_tween().set_parallel()
	fade.tween_property(sprite, "modulate:a", 0.0, 0.22)
	fade.tween_property(sprite, "scale:y", 0.4, 0.22)
	var ref: WeakRef = weakref(self)
	level.after(2600, func():
		var c: CrumblePlatform = ref.get_ref()
		if c != null:
			c.restore())


func restore() -> void:
	sprite.position.x = base_x
	var tw := sprite.create_tween().set_parallel()
	tw.tween_property(sprite, "modulate:a", 1.0, 0.3)
	tw.tween_property(sprite, "scale:y", 1.0, 0.3)
	tw.chain().tween_callback(func():
		shape.set_deferred("disabled", false)
		crumbling = false)
