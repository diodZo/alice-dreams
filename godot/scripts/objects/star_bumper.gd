class_name StarBumper
extends Area2D
## Barrera de estrella (parachoques estrella del Mundo 6): no hace daño; al tocarla aparta a
## Alice con un rebote suave hacia el lado contrario y destella.

const COOLDOWN := 350.0

var level: Node
var atlas := ""
var sprite: Sprite2D
var ready_at := 0.0


## def: { x, y (teselas: superficie), power (px/s de empuje) }
var power := 300.0


func setup(owner_level: Node, def: Dictionary, atlas_name: String) -> StarBumper:
	level = owner_level
	atlas = atlas_name
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, "bumper")
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0)
	add_child(sprite)
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	power = float(def.get("power", 300))
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = sprite.texture.get_height() * 0.45
	cs.shape = circle
	cs.position = Vector2(0, -sprite.texture.get_height() / 2.0)
	add_child(cs)
	Trigger.configure(self, "bumper")
	z_index = C.Z_PICKUP
	return self


func bump(player: Player) -> void:
	if level.now < ready_at:
		return
	ready_at = level.now + COOLDOWN
	var dir := signf(player.position.x - position.x)
	if dir == 0:
		dir = -float(player.facing)
	player.velocity.x = dir * power * 0.5
	player.push(dir * power)
	player.bounce(-170)
	AudioManager.play("bounce")
	level.effects.sparkle(position.x, position.y - 10, 8)
	sprite.texture = Assets.frame(atlas, "bumper_hit")
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.07)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(0.12)
	tw.tween_callback(func():
		sprite.texture = Assets.frame(atlas, "bumper")
		Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0))


## La protagonista toca el objeto (lo llama Level._process_overlaps cada fotograma).
func on_player_overlap(_level: Node, player: Player, _delta: float) -> void:
	bump(player)
