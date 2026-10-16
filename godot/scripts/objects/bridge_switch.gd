class_name BridgeSwitch
extends Area2D
## Molinillo interruptor (Mundo 2): al tocarlo gira y dibuja el puente de reglas asociado.

var bridge: RulerBridge
var used := false
var sprite: Sprite2D


func setup(pos_tiles: Array, target: RulerBridge, atlas := "world2_objects") -> BridgeSwitch:
	bridge = target
	position = Vector2(float(pos_tiles[0]) * C.TILE + 8, float(pos_tiles[1]) * C.TILE)
	z_index = C.Z_PICKUP
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, "pinwheel_a")
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0)
	add_child(sprite)
	var shape := RectangleShape2D.new()
	shape.size = sprite.texture.get_size() * Vector2(0.8, 1.0)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -shape.size.y / 2.0)
	add_child(cs)
	Trigger.configure(self, "switch")
	sprite.modulate = Color(0.75, 0.75, 0.85)
	return self


func trigger() -> void:
	if used:
		return
	used = true
	sprite.modulate = Color.WHITE
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.12)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.12)
	bridge.activate()
	GameState.show_toast("¡Puente de reglas dibujado!")
