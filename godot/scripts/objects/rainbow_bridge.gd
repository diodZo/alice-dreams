class_name RainbowBridge
extends StaticBody2D
## Puente arcoíris unidireccional (port de LevelBuilder.buildBridge): tramo central repetido,
## dos remates y un cuerpo invisible de 8 px a lo largo de todo el puente.


## def: { x, y (superficie), w } en teselas
func setup(def: Dictionary, atlas: String) -> RainbowBridge:
	var x0 := float(def.x) * C.TILE
	var w := float(def.w) * C.TILE
	var surface := float(def.y) * C.TILE
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	var mid := Assets.frame(atlas, "rainbow_mid")
	var h := mid.get_height()
	var strip := TiledSprite.new().setup(mid, Vector2(w, h))
	strip.position = Vector2(x0, surface - 2)
	add_child(strip)
	var cap_l := Sprite2D.new()
	cap_l.texture = Assets.frame(atlas, "rainbow_cap_l")
	cap_l.centered = false
	cap_l.position = Vector2(round(x0 - cap_l.texture.get_width() * 0.6), surface - 4)
	cap_l.z_index = 1
	add_child(cap_l)
	var cap_r := Sprite2D.new()
	cap_r.texture = Assets.frame(atlas, "rainbow_cap_r")
	cap_r.centered = false
	cap_r.position = Vector2(round(x0 + w - cap_r.texture.get_width() * 0.4), surface - 4)
	cap_r.z_index = 1
	add_child(cap_r)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, 8)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(x0 + w / 2.0, surface + 4)
	cs.one_way_collision = true
	cs.one_way_collision_margin = 5.0
	add_child(cs)
	return self


func on_player_contact() -> void:
	pass
