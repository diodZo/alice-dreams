class_name RainbowSlide
extends StaticBody2D
## Tobogán arcoíris del Mundo 5: rampa unidireccional (se atraviesa desde abajo) por la que
## Alice se desliza rápido hacia el extremo bajo. Mientras la pisa, el nivel fija
## Player.slide_speed (área "slide"); las flechas siguen acelerando o frenando un poco.
## Dibujo: la banda arcoíris de tilesets_world_5.png repetida a lo largo de la rampa, con una
## nube al pie y una estrella en lo alto, como los "segmentos de tobogán arcoíris".

const BAND_OFFSET := 5.0

var speed := 190.0
var from := Vector2.ZERO
var to := Vector2.ZERO
var area: Area2D


## def: { x0, y0, x1, y1 (teselas: superficie en los dos extremos), speed (px/s) }
func setup(def: Dictionary, atlas: String) -> RainbowSlide:
	from = Vector2(float(def.x0), float(def.y0)) * C.TILE
	to = Vector2(float(def.x1), float(def.y1)) * C.TILE
	# el extremo bajo marca el sentido del deslizamiento
	var down := signf(to.x - from.x) if to.y > from.y else signf(from.x - to.x)
	speed = float(def.get("speed", 190)) * down
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	var seg := to - from
	var angle := seg.angle()
	var length := seg.length()
	# cuerpo: franja fina de colisión unidireccional pegada a la superficie
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length, 8)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.rotation = angle
	cs.position = (from + to) / 2.0 + Vector2(0, 4).rotated(angle)
	cs.one_way_collision = true
	cs.one_way_collision_margin = 6.0
	add_child(cs)
	# banda arcoíris (se repite a lo largo de la rampa)
	var band := Line2D.new()
	# Line2D no recorta las AtlasTexture: se usa una textura propia con la región de la banda
	band.texture = ImageTexture.create_from_image(Assets.frame(atlas, "rainbow_band").get_image())
	band.texture_mode = Line2D.LINE_TEXTURE_TILE
	band.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	band.width = band.texture.get_height()
	var off := Vector2(0, BAND_OFFSET).rotated(angle)
	band.points = PackedVector2Array([from + off, to + off])
	add_child(band)
	# detección del deslizamiento: banda de 14 px por encima de la superficie
	area = Area2D.new()
	var ashape := RectangleShape2D.new()
	ashape.size = Vector2(length, 14)
	var acs := CollisionShape2D.new()
	acs.shape = ashape
	acs.rotation = angle
	acs.position = (from + to) / 2.0 + Vector2(0, -5).rotated(angle)
	area.add_child(acs)
	Trigger.configure(area, "slide", self)
	add_child(area)
	# nube al pie del tobogán y estrella en lo alto
	var low := to if to.y > from.y else from
	var high := from if low == to else to
	var puff := Sprite2D.new()
	puff.texture = Assets.frame(atlas, "cloud_s")
	puff.position = low + Vector2(0, 6)
	puff.z_index = 1
	add_child(puff)
	var star := Sprite2D.new()
	star.texture = Assets.frame(atlas, "star_post_a")
	Anim.set_origin(star, star.texture.get_size(), 0.5, 1.0)
	star.position = high + Vector2(0, 2)
	star.z_index = -1
	add_child(star)
	return self


## Velocidad de deslizamiento (px/s con signo) para Player.slide_speed.
func slide_velocity() -> float:
	return speed
