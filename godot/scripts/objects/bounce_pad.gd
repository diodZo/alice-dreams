class_name BouncePad
extends Area2D
## Cojín de burbujas que lanza a la protagonista hacia arriba (port de BouncePad).
## Se activa al pisarlo, tanto cayendo encima como entrando caminando.

var level: Node
var sprite: Sprite2D
var power := -520.0
var ready_at := 0.0


## def: { x, y (teselas), power }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> BouncePad:
	level = owner_level
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "jump_pad"))
	var size := sprite.texture.get_size()
	Anim.set_origin(sprite, size, 0.5, 1.0)
	add_child(sprite)
	z_index = C.Z_PLATFORM
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x - 4, 8)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(-round(size.x / 2.0) + 2 + shape.size.x / 2.0, -4)
	add_child(cs)
	Trigger.configure(self, "pad")
	power = float(def.get("power", -520))
	return self


func trigger(player: Player) -> void:
	var now: float = level.now
	if now < ready_at:
		return
	ready_at = now + 200
	player.bounce(power)
	AudioManager.play("bounce")
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.25, 0.6), 0.07)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.07)
	level.effects.sparkle(position.x, position.y - 8, 6)
