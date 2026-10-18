class_name RocketPlatform
extends MovingPlatform
## Cohete móvil del Mundo 5: plataforma que patrulla de lado a lado o eleva a Alice, con la
## trayectoria estable (vaivén suavizado) de MovingPlatform. Lleva la llama del motor encendida
## y, si va de lado, mira hacia donde avanza.

var sprite: Sprite2D
var flame: ParticleBurst
var last_x := 0.0
var horizontal := true


## def: { x, y, frame, top, dx, dy (teselas), duration, delay (ms) }
func setup(def: Dictionary, atlas: String) -> MovingPlatform:
	super(def, atlas)
	for child in get_children():
		if child is Sprite2D:
			sprite = child
	horizontal = absf(float(def.get("dx", 0))) >= absf(float(def.get("dy", 0)))
	var w := sprite.texture.get_width()
	var h := sprite.texture.get_height()
	flame = ParticleBurst.new().setup({
		"x_range": [-2, 2],
		"speed_y": [10, 40] if horizontal else [50, 90],
		"speed_x": [-60, -30] if horizontal else [-6, 6],
		"life": [220, 320],
		"scale": [1.6, 0],
		"alpha": [0.9, 0],
		"frequency": 30.0,
		"colors": Effects.colors([0xffe082, 0xffb36b, 0xfff7ff]),
	})
	flame.position = Vector2(-w / 2.0 + 2, h * 0.55) if horizontal else Vector2(0, h - 2)
	flame.emitting = true
	flame.auto_free = false
	flame.z_index = -1
	add_child(flame)
	last_x = position.x
	return self


func step(delta_ms: float) -> void:
	super(delta_ms)
	if horizontal and absf(position.x - last_x) > 0.05:
		var left := position.x < last_x
		sprite.flip_h = left
		flame.position.x = (sprite.texture.get_width() / 2.0 - 2) if left else (-sprite.texture.get_width() / 2.0 + 2)
		flame.cfg.speed_x = [30, 60] if left else [-60, -30]
	last_x = position.x
