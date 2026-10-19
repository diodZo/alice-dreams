class_name StarBlock
extends StaticBody2D
## Bloque de estrella del Mundo 6 ("bloque coleccionable"): sólido; al golpearlo desde abajo
## con la cabeza o con un disparo suelta estrellas extra (count veces) y después se queda
## apagado.

var level: Node
var sprite: Sprite2D
var left := 1
var ready_at := 0.0
var glow: Tween


## def: { x, y (teselas: celda del bloque), count }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> StarBlock:
	level = owner_level
	left = int(def.get("count", 1))
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, "star_block")
	sprite.scale = Vector2(16.0, 16.0) / sprite.texture.get_size()
	add_child(sprite)
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE + 8)
	collision_layer = C.L_WORLD
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	z_index = C.Z_TERRAIN + 1
	glow = sprite.create_tween().set_loops()
	glow.tween_property(sprite, "modulate", C.rgb(0xfff3a0), 0.5)
	glow.tween_property(sprite, "modulate", Color.WHITE, 0.5)
	return self


func is_empty() -> bool:
	return left <= 0


## Golpe desde abajo o disparo: suelta una estrella mientras le queden.
func bump() -> void:
	if left <= 0 or level.now < ready_at:
		return
	ready_at = level.now + 250
	left -= 1
	level.spawn_bonus_star(position.x, position.y - 18)
	AudioManager.play("star")
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", -4.0, 0.06)
	tw.tween_property(sprite, "position:y", 0.0, 0.08)
	if left <= 0:
		glow.kill()
		sprite.modulate = Color(0.7, 0.7, 0.8)


## Un disparo de Alice choca con el bloque (lo avisa Projectile al tocar algo sólido).
func shot_by(_projectile: Projectile) -> void:
	bump()


func on_player_contact() -> void:
	pass
