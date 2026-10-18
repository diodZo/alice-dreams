class_name MovingPlatform
extends AnimatableBody2D
## Nube que se desplaza con un vaivén suavizado y transporta a la protagonista
## (port de MovingPlatform en entities/Platforms.js). Con sync_to_physics, Godot traslada
## al CharacterBody2D que va encima, como el arrastre de Arcade Physics.

var start := Vector2.ZERO
var delta_px := Vector2.ZERO
var duration := 3000.0
var phase := 0.0
var elapsed := 0.0
var active := true


## def: { x, y, frame, dx, dy (teselas), duration (ms), delay (ms) }
func setup(def: Dictionary, atlas: String) -> MovingPlatform:
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(atlas, def.frame)
	add_child(spr)
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	sync_to_physics = true
	position.x = float(def.x) * C.TILE
	CloudPlatform.add_cloud_shape(self, spr, spr.texture.get_size(), float(def.y) * C.TILE, float(def.get("top", 3)))
	start = position
	delta_px = Vector2(float(def.get("dx", 0)), float(def.get("dy", 0))) * C.TILE
	duration = float(def.get("duration", 3000))
	phase = float(def.get("delay", 0)) / duration
	active = bool(def.get("active", true))
	# dormida: se ve translúcida (para que se entienda qué despierta el botón) pero no se pisa
	modulate.a = 1.0 if active else 0.35
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = not active
	return self


## Posición del vaivén suavizado en el instante ms (0..1 ida, 1..2 vuelta).
func target_at(ms: float) -> Vector2:
	var t := fposmod(ms / duration + phase, 2.0)
	var k := t if t < 1.0 else 2.0 - t
	var e := 0.5 - 0.5 * cos(PI * k)
	return start + delta_px * e


## La llama el nivel una vez por fotograma de física.
func step(delta_ms: float) -> void:
	if not active:
		return
	elapsed += delta_ms
	position = target_at(elapsed)


func on_player_contact() -> void:
	pass


func activate() -> void:
	if active:
		return
	active = true
	visible = true
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", false)
