class_name WeaponPickup
extends Area2D
## Objeto que desbloquea un arma (port de WeaponPickup en entities/Collectibles.js).

var level: Node
var weapon_id := ""
var active := true


## def: { x, y (teselas), weapon }
func setup(owner_level: Node, def: Dictionary) -> WeaponPickup:
	level = owner_level
	weapon_id = def.weapon
	var w := Assets.weapon(weapon_id)
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE - 14)
	z_index = C.Z_PICKUP
	var glow := Sprite2D.new()
	glow.texture = Assets.generated("glow")
	glow.scale = Vector2(2.2, 2.2)
	glow.modulate = C.YELLOW
	glow.z_index = -2
	add_child(glow)
	var halo := Sprite2D.new()
	halo.texture = Assets.frame("fx", "bubble")
	halo.scale = Vector2(1.7, 1.7)
	halo.modulate.a = 0.6
	halo.z_index = -1
	add_child(halo)
	var icon := Sprite2D.new()
	icon.texture = Assets.frame("fx", w.icon if w else "")
	add_child(icon)
	var shape := RectangleShape2D.new()
	shape.size = icon.texture.get_size()
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	Trigger.configure(self, "pickup")
	var y := position.y
	var bob := create_tween().set_loops()
	bob.tween_property(self, "position:y", y - 4, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(self, "position:y", y, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pulse := glow.create_tween().set_loops()
	pulse.tween_property(glow, "modulate:a", 0.35, 0.6)
	pulse.tween_property(glow, "modulate:a", 1.0, 0.6)
	return self


func collect() -> void:
	active = false
	level.effects.sparkle(position.x, position.y, 20)
	level.effects.bubble_pop(position.x, position.y)
	set_deferred("monitorable", false)
	queue_free()
