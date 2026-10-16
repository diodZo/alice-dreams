class_name CastleDoor
extends Area2D
## Entrada al castillo de Nubarrón (World1Scene.onCreate): fachada decorativa con una puerta
## luminosa; al tocarla empieza la batalla en la arena del jefe.


## def: { x, y (teselas, superficie) }
## def admite "atlas", "frame" y "scale" para que cada mundo use su propia entrada.
func setup(def: Dictionary, bg_atlas: String) -> CastleDoor:
	var x := float(def.x) * C.TILE + C.TILE / 2.0
	var y := float(def.y) * C.TILE
	position = Vector2(x, y)
	var castle := Sprite2D.new()
	castle.texture = Assets.frame(def.get("atlas", bg_atlas), def.get("frame", "castle"))
	Anim.set_origin(castle, castle.texture.get_size(), 0.5, 1.0)
	var sc: float = def.get("scale", 1.6)
	castle.scale = Vector2(sc, sc)
	castle.position = Vector2(0, 6)
	castle.z_as_relative = false
	castle.z_index = C.Z_DECOR_BACK - 1
	add_child(castle)
	var glow := Sprite2D.new()
	glow.texture = Assets.generated("glow")
	glow.position = Vector2(0, -18)
	glow.scale = Vector2(3, 4)
	glow.modulate = C.YELLOW
	glow.z_as_relative = false
	glow.z_index = C.Z_DECOR_BACK
	add_child(glow)
	var tw := glow.create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.35, 0.6)
	tw.tween_property(glow, "modulate:a", 1.0, 0.6)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 40)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -20)
	add_child(cs)
	Trigger.configure(self, "door")
	return self
