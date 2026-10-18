class_name BubbleColumn
extends WindZone
## Columna de burbujas del Mundo 4: corriente ascendente constante (misma física que WindZone)
## dibujada con la animación "columnas de burbujas" de tilesets_world_4.png.

const FRAME_MS := 120.0

var atlas := ""
var sprites: Array[Sprite2D] = []
var acc := 0.0
var frame_i := 0


## def: { x, y, w, h (teselas), force, maxUp }
func setup_column(owner_level: Node, def: Dictionary, atlas_name: String) -> BubbleColumn:
	setup(owner_level, def)
	atlas = atlas_name
	var size := Vector2(float(def.w), float(def.h)) * C.TILE
	var tex := Assets.frame(atlas, "bubble_col_0")
	# columnas una al lado de otra hasta cubrir todo el ancho de la corriente
	var n := maxi(1, int(round(size.x / (tex.get_width() - 4.0))))
	var step := size.x / n
	for i in n:
		var y := size.y
		while y > 0:
			var s := Sprite2D.new()
			s.centered = false
			s.texture = tex
			s.offset = Vector2(step * (i + 0.5) - round(tex.get_width() / 2.0), y - tex.get_height())
			s.modulate.a = 0.85
			s.z_as_relative = false
			s.z_index = C.Z_DECOR_BACK + 1
			add_child(s)
			sprites.append(s)
			y -= tex.get_height()
	return self


func _physics_process(delta: float) -> void:
	acc += delta * 1000.0
	if acc < FRAME_MS:
		return
	acc -= FRAME_MS
	frame_i = (frame_i + 1) % 3
	for s in sprites:
		s.texture = Assets.frame(atlas, "bubble_col_%d" % frame_i)
