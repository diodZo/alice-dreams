class_name HeartPickup
extends Area2D
## Corazón dulce del Mundo 7: devuelve un corazón de vida a Alice al recogerlo (si le falta
## alguno; con la vida llena se queda donde está). Flota y late. No se guarda: es una ayuda.

var level: Node
var active := true
var sprite: Sprite2D


## def: { x, y (teselas, centro), frame }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> HeartPickup:
	level = owner_level
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE + 8)
	z_index = C.Z_PICKUP
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "heart_w7"))
	add_child(sprite)
	var shape := CircleShape2D.new()
	shape.radius = 7
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	Trigger.configure(self, "heart")
	var tw := sprite.create_tween().set_loops()
	tw.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE)
	var bob := sprite.create_tween().set_loops()
	bob.tween_property(sprite, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(sprite, "position:y", 2.0, 0.6).set_trans(Tween.TRANS_SINE)
	return self


## Lo llama el nivel al tocarlo. Devuelve true si se recoge.
func collect(player: Player) -> bool:
	if not active or player.hp >= player.max_hp:
		return false
	active = false
	set_deferred("monitorable", false)
	player.heal(false)
	AudioManager.play("pickup")
	level.effects.sparkle(position.x, position.y, 10)
	var tw := create_tween().set_parallel()
	tw.tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
	return true
