class_name MagicButton
extends Area2D
## Pulsador del Mundo 3: al pisarlo despierta una plataforma dormida (señal `activated`).
signal activated

var used := false
var sprite: Sprite2D
var glow: Tween

## def: { x, y (teselas, superficie), frame, targetMover (índice en movers) }
func setup(def: Dictionary, atlas := "world3_objects") -> MagicButton:
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE)
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "magic_button"))
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0)
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(18, sprite.texture.get_width() - 4), 12)
	cs.shape = shape
	cs.position.y = -6
	add_child(cs)
	Trigger.configure(self, "magic_button")
	z_index = C.Z_PICKUP
	# brillo suave mientras espera a ser pulsado
	glow = sprite.create_tween().set_loops()
	glow.tween_property(sprite, "modulate", C.rgb(0xfff3a0), 0.6)
	glow.tween_property(sprite, "modulate", Color.WHITE, 0.6)
	return self

func trigger() -> void:
	if used:
		return
	used = true
	# hundido y apagado: se ve que ya se usó
	glow.kill()
	sprite.modulate = Color(0.8, 0.75, 0.9)
	var press := create_tween()
	press.tween_property(sprite, "scale", Vector2(1.15, 0.45), 0.08)
	press.tween_property(sprite, "scale", Vector2(1.0, 0.55), 0.1)
	AudioManager.play("ui_select")
	activated.emit()
	GameState.show_toast("¡Mecanismo de sueños activado!")


## La protagonista toca el objeto (lo llama Level._process_overlaps cada fotograma).
func on_player_overlap(_level: Node, _player: Player, _delta: float) -> void:
	trigger()
