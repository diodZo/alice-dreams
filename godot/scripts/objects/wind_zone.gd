class_name WindZone
extends Area2D
## Corriente de aire ascendente: empuja suavemente hacia arriba dentro de su zona
## (port de WindZone en entities/Hazards.js).

var level: Node
var force := 1400.0
var max_up := 180.0
var last_sound_at := 0.0


## def: { x, y, w, h (teselas), force, maxUp }
func setup(owner_level: Node, def: Dictionary) -> WindZone:
	level = owner_level
	position = Vector2(float(def.x), float(def.y)) * C.TILE
	var size := Vector2(float(def.w), float(def.h)) * C.TILE
	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = size / 2.0
	add_child(cs)
	Trigger.configure(self, "wind")
	force = float(def.get("force", 1400))
	max_up = float(def.get("maxUp", 180))
	# partículas que suben desde la base de la zona
	var e := ParticleBurst.new().setup({
		"x_range": [0, size.x],
		"speed_y": [-170, -110],
		"speed_x": [-6, 6],
		"life": [size.y / 140.0 * 1000.0, size.y / 140.0 * 1000.0],
		"scale_y": [3, 1],
		"scale": [1, 1],
		"alpha": [0.55, 0],
		"frequency": 45.0,
		"colors": Effects.colors([0xfff7ff, 0xc8e8ff]),
	})
	e.position = Vector2(0, size.y)
	e.emitting = true
	e.auto_free = false
	e.z_as_relative = false
	e.z_index = C.Z_DECOR_BACK
	add_child(e)
	return self


func apply(player: Player, delta: float) -> void:
	player.velocity.y = maxf(player.velocity.y - force * delta, -max_up)
	player.jumping = false # el corte de salto variable no frena la corriente
	var now: float = level.now
	if now - last_sound_at > 900:
		last_sound_at = now
		AudioManager.play("wind")


## La protagonista toca el objeto (lo llama Level._process_overlaps cada fotograma).
func on_player_overlap(_level: Node, player: Player, delta: float) -> void:
	apply(player, delta)
