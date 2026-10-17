class_name SwingPlatform
extends AnimatableBody2D
## Plataforma suspendida que sigue un arco sinusoidal y transporta al jugador por física.

var anchor := Vector2.ZERO
var radius := 42.0
var amplitude := 0.45
var duration := 2600.0
var elapsed := 0.0

func setup(def: Dictionary, atlas := "world3_objects") -> SwingPlatform:
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(atlas, def.get("frame", "rope_mid"))
	add_child(spr)
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE)
	anchor = position
	radius = float(def.get("radius", 42))
	amplitude = float(def.get("amplitude", 0.45))
	duration = float(def.get("duration", 2600))
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	sync_to_physics = true
	z_index = C.Z_PLATFORM
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(28, spr.texture.get_width()), 6)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position.y = -3
	cs.one_way_collision = true
	add_child(cs)
	return self

func step(delta_ms: float) -> void:
	elapsed += delta_ms
	position = target_at(elapsed)
	var a := sin(elapsed / duration * TAU) * amplitude
	rotation = a * 0.18


func target_at(ms: float) -> Vector2:
	var a := sin(ms / duration * TAU) * amplitude
	return anchor + Vector2(sin(a) * radius, (1.0 - cos(a)) * radius)

func on_player_contact() -> void:
	pass
