class_name MagicCrayon
extends Area2D
## Crayón mágico (Mundo 2): rojo, azul y amarillo, uno en cada tramo del recorrido.
## Se guardan en la partida y en el progreso del mundo. def: {x, y (teselas), color}.

var level: Node
var color := "red"
var active := true


func setup(owner_level: Node, def: Dictionary, atlas := "world2_objects") -> MagicCrayon:
	level = owner_level
	color = def.color
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE - 12)
	z_index = C.Z_PICKUP
	var glow := Sprite2D.new()
	glow.texture = Assets.generated("glow")
	glow.scale = Vector2(2.4, 2.4)
	glow.modulate = C.YELLOW
	glow.z_index = -1
	add_child(glow)
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(atlas, "magic_crayon_%s" % color)
	add_child(spr)
	var shape := RectangleShape2D.new()
	shape.size = spr.texture.get_size()
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	Trigger.configure(self, "magic")
	var y := position.y
	var bob := create_tween().set_loops()
	bob.tween_property(self, "position:y", y - 4, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(self, "position:y", y, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "modulate:a", 0.3, 0.6)
	pulse.tween_property(glow, "modulate:a", 1.0, 0.6)
	return self


func collect() -> bool:
	if not active:
		return false
	active = false
	level.effects.sparkle(position.x, position.y, 24)
	level.effects.confetti(position.x, position.y, 20)
	set_deferred("monitorable", false)
	queue_free()
	return true
