class_name WaterZone
extends Area2D
## Tramo de agua del Mundo 4: superficie animada y agua submarina (tres fotogramas cada una,
## de la hoja tilesets_world_4.png). Dentro, la protagonista nada (Player.set_water): menos
## gravedad, caída lenta y brazadas con el botón de salto. El agua no hace daño; el fondo del
## tramo es terreno real (los huecos sin fondo siguen siendo vacío).

const FRAME_MS := 260.0

var level: Node
var atlas := ""
var surface_y := 0.0
var size := Vector2.ZERO
var top: TiledSprite
var deep: TiledSprite
var deep_fill: ColorRect
var frame_i := 0
var acc := 0.0


## def: { x, y (fila de la superficie), w, h (teselas de profundidad) }
func setup(owner_level: Node, def: Dictionary, atlas_name: String) -> WaterZone:
	level = owner_level
	atlas = atlas_name
	surface_y = float(def.y) * C.TILE
	size = Vector2(float(def.w), float(def.h)) * C.TILE
	position = Vector2(float(def.x) * C.TILE, surface_y)
	z_as_relative = false
	z_index = C.Z_PLATFORM - 1
	# agua submarina: el fotograma se apoya en el fondo (lecho de espuma) y encima se rellena
	# con el azul del agua para que las bandas no se repitan en los tramos hondos
	var dtex := Assets.frame(atlas, "water_deep_0")
	var band := minf(dtex.get_height(), size.y - 4)
	deep_fill = ColorRect.new()
	deep_fill.color = _mid_color(dtex)
	deep_fill.position = Vector2(0, 4)
	deep_fill.size = Vector2(size.x, maxf(0, size.y - 4 - band + 2))
	deep_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(deep_fill)
	deep = TiledSprite.new().setup(dtex, Vector2(size.x, band))
	deep.position = Vector2(0, size.y - band)
	deep.tile_offset = Vector2(0, dtex.get_height() - band)
	add_child(deep)
	modulate.a = 0.9
	var ttex := Assets.frame(atlas, "water_top_0")
	top = TiledSprite.new().setup(ttex, Vector2(size.x, ttex.get_height()))
	top.position = Vector2(0, -6)
	add_child(top)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.position = size / 2.0
	add_child(cs)
	Trigger.configure(self, "water")
	# burbujas que suben desde el fondo
	var e := ParticleBurst.new().setup({
		"x_range": [4, size.x - 4],
		"speed_y": [-40, -22],
		"speed_x": [-4, 4],
		"life": [size.y / 32.0 * 1000.0, size.y / 32.0 * 1000.0],
		"scale": [1, 1],
		"alpha": [0.8, 0.2],
		"frequency": maxf(60.0, 9000.0 / maxf(size.x, 1.0)),
		"colors": Effects.colors([0xffffff, 0xc8f0ff]),
	})
	e.position = Vector2(0, size.y - 4)
	e.emitting = true
	e.auto_free = false
	add_child(e)
	return self


func _mid_color(tex: Texture2D) -> Color:
	var img := tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		return C.rgb(0x2f86e0)
	return img.get_pixel(int(img.get_width() / 2.0), int(img.get_height() * 0.3))


func _physics_process(delta: float) -> void:
	acc += delta * 1000.0
	if acc < FRAME_MS:
		return
	acc -= FRAME_MS
	frame_i = (frame_i + 1) % 3
	top.texture = Assets.frame(atlas, "water_top_%d" % frame_i)
	deep.texture = Assets.frame(atlas, "water_deep_%d" % frame_i)
	top.queue_redraw()
	deep.queue_redraw()


## Salpicadura animada al zambullirse (fotogramas splash_0..4 de la hoja de teselas).
func splash(x: float) -> void:
	var s := Sprite2D.new()
	s.position = Vector2(x, surface_y)
	s.centered = false
	s.z_index = C.Z_FX
	level.fx_root.add_child(s)
	var tw := s.create_tween()
	for i in 5:
		var tex := Assets.frame("w4_fx", "splash_%d" % i)
		tw.tween_callback(func():
			s.texture = tex
			s.offset = Vector2(-round(tex.get_width() / 2.0), -tex.get_height() + 4))
		tw.tween_interval(0.06)
	tw.tween_callback(s.queue_free)
	AudioManager.play("splash")
