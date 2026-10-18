class_name LightFall
extends WindZone
## Cascada de luz del Mundo 5 que funciona como corriente ascendente (misma física que WindZone).
## Se distingue de las cascadas decorativas (tenues, al fondo y sin brillos) por ir a plena luz,
## con chispas doradas que suben y una estrella dorada en su base.
## Dibujo: la animación de dos fotogramas "cascadas de luz" de tilesets_world_5.png.

const FRAME_MS := 140.0

var atlas := ""
var sprites: Array[Sprite2D] = []
var acc := 0.0
var frame_i := 0


## def: { x, y, w, h (teselas), force, maxUp }
func setup_fall(owner_level: Node, def: Dictionary, atlas_name: String) -> LightFall:
	setup(owner_level, def)
	atlas = atlas_name
	var size := Vector2(float(def.w), float(def.h)) * C.TILE
	var tex := Assets.frame(atlas, "light_fall_0")
	var n := maxi(1, int(round(size.x / (tex.get_width() - 4.0))))
	var step := size.x / n
	for i in n:
		var y := size.y
		while y > 0:
			var s := Sprite2D.new()
			s.centered = false
			s.texture = tex
			s.offset = Vector2(step * (i + 0.5) - round(tex.get_width() / 2.0), y - tex.get_height())
			s.modulate.a = 0.8
			s.z_as_relative = false
			s.z_index = C.Z_DECOR_BACK + 1
			add_child(s)
			sprites.append(s)
			y -= tex.get_height()
	# chispas doradas que suben: la cascada "funciona"
	var e := ParticleBurst.new().setup({
		"x_range": [2, size.x - 2],
		"speed_y": [-120, -70],
		"speed_x": [-4, 4],
		"life": [size.y / 95.0 * 1000.0, size.y / 95.0 * 1000.0],
		"scale": [1.2, 0.4],
		"alpha": [1.0, 0],
		"frequency": 70.0,
		"colors": Effects.colors([0xffe082, 0xfff7ff, 0x9ff0ff]),
	})
	e.position = Vector2(0, size.y)
	e.emitting = true
	e.auto_free = false
	e.z_as_relative = false
	e.z_index = C.Z_DECOR_FRONT - 1
	add_child(e)
	var base := Sprite2D.new()
	base.texture = Assets.frame(atlas, "star_w5")
	base.position = Vector2(size.x / 2.0, size.y - 6)
	base.z_as_relative = false
	base.z_index = C.Z_PLATFORM
	add_child(base)
	var tw := base.create_tween().set_loops()
	tw.tween_property(base, "scale", Vector2(1.3, 1.3), 0.45)
	tw.tween_property(base, "scale", Vector2.ONE, 0.45)
	return self


func _physics_process(delta: float) -> void:
	acc += delta * 1000.0
	if acc < FRAME_MS:
		return
	acc -= FRAME_MS
	frame_i = (frame_i + 1) % 2
	for s in sprites:
		s.texture = Assets.frame(atlas, "light_fall_%d" % frame_i)
