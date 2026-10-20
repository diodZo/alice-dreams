class_name TreasureChest
extends Area2D
## Cofre final del Mundo 8. Se abre con la llave del castillo (coleccionable "key_1"): suelta
## estrellas y devuelve toda la vida. Sin la llave avisa de que hace falta. Queda abierto.

var level: Node
var opened := false
var stars := 8
var sprite: Sprite2D
var _hint_at := 0.0


## def: { x, y (superficie) en teselas, frame, stars }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> TreasureChest:
	level = owner_level
	stars = int(def.get("stars", 8))
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	z_index = C.Z_PICKUP
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "chest_w8"))
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0)
	sprite.position.y = 4
	add_child(sprite)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 20)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	cs.position = Vector2(0, -10)
	add_child(cs)
	Trigger.configure(self, "chest")
	return self


## Lo llama el nivel al tocarlo. Devuelve true si se abre.
func touch(has_key: bool, player: Player) -> bool:
	if opened:
		return false
	if not has_key:
		if level.now >= _hint_at:
			_hint_at = level.now + 2500
			GameState.show_toast("Hace falta la llave del castillo")
		return false
	opened = true
	AudioManager.play("pickup")
	level.effects.confetti(position.x, position.y - 20, 40)
	level.effects.glow_flash(position + Vector2(0, -14), C.rgb(0xffe18c), 1.0, 4.0, 600, 0.9, 1)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.1)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.15)
	sprite.modulate = C.rgb(0xfff3c0)
	for i in stars:
		level.spawn_bonus_star(position.x - 28 + i * 8, position.y - 30 - (i % 2) * 10)
	player.heal(true)
	return true
