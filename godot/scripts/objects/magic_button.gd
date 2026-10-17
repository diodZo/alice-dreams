class_name MagicButton
extends Area2D
signal activated

var used := false

func setup(def: Dictionary, atlas := "world3_objects") -> MagicButton:
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE)
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(atlas, def.get("frame", "button_pink"))
	Anim.set_origin(spr, spr.texture.get_size(), 0.5, 1.0)
	add_child(spr)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 12)
	cs.shape = shape
	cs.position.y = -6
	add_child(cs)
	Trigger.configure(self, "magic_button")
	return self

func trigger() -> void:
	if used:
		return
	used = true
	modulate = Color.WHITE
	activated.emit()
	GameState.show_toast("¡Mecanismo de sueños activado!")
