class_name DreamCollectible
extends Area2D

var level: Node
var id := ""
var kind := "moon"
var active := true

func setup(owner_level: Node, def: Dictionary, atlas := "world3_objects") -> DreamCollectible:
	level = owner_level
	id = str(def.get("id", "%s_%s" % [kind, def.x]))
	kind = str(def.get("kind", "moon"))
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE - 12)
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(atlas, def.get("frame", "%s_w3" % kind))
	add_child(spr)
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10
	cs.shape = shape
	add_child(cs)
	Trigger.configure(self, "dream_collectible")
	z_index = C.Z_PICKUP
	var y := position.y
	var tw := create_tween().set_loops()
	tw.tween_property(self, "position:y", y - 4, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position:y", y, 0.8).set_trans(Tween.TRANS_SINE)
	return self

func collect() -> bool:
	if not active:
		return false
	active = false
	level.effects.sparkle(position.x, position.y, 18)
	queue_free()
	return true
