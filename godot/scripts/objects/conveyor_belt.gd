class_name ConveyorBelt
extends StaticBody2D
## Correa de chocolate del Mundo 7: plataforma sólida que arrastra en horizontal a lo que se
## apoya encima. Usa constant_linear_velocity: Godot la aplica como velocidad de plataforma al
## CharacterBody2D que la pisa (igual que el arrastre de una plataforma móvil), así Alice no
## patina ni recibe empujones bruscos y conserva su control. Las flechas del dibujo indican el
## sentido; un brillo las recorre en ese sentido.

const FRAME := "choco_belt"
## Distancia del borde superior del dibujo a la superficie pisable (borde rosa de la correa).
const TOP := 2.0

var speed := 40.0
var sprite: Sprite2D
var shine: ColorRect
var width := 0.0


## def: { x (tesela del borde izquierdo), y (fila de la superficie), dir (1 derecha, -1 izquierda),
##        speed (px/s), frame }
func setup(def: Dictionary, atlas: String) -> ConveyorBelt:
	var tex := Assets.frame(atlas, def.get("frame", FRAME))
	var dir := -1 if int(def.get("dir", 1)) < 0 else 1
	speed = absf(float(def.get("speed", 40))) * dir
	position = Vector2(float(def.x) * C.TILE, float(def.y) * C.TILE)
	z_index = C.Z_PLATFORM
	collision_layer = C.L_WORLD
	collision_mask = 0
	constant_linear_velocity = Vector2(speed, 0)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.flip_h = dir < 0
	sprite.position = Vector2(0, -TOP)
	add_child(sprite)
	width = tex.get_width()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width - 4, 12)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(width / 2.0, 6)
	add_child(cs)
	# brillo que recorre la banda de las flechas en el sentido del arrastre
	shine = ColorRect.new()
	shine.color = Color(1, 1, 1, 0.35)
	shine.size = Vector2(3, 9)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.position = Vector2(0, 2)
	add_child(shine)
	var tw := shine.create_tween().set_loops()
	var a := 6.0 if dir > 0 else width - 9.0
	var b := width - 9.0 if dir > 0 else 6.0
	tw.tween_property(shine, "position:x", b, maxf(0.4, (width - 15.0) / absf(speed))).from(a)
	return self


## Velocidad de arrastre en px/s (con signo).
func belt_speed() -> float:
	return speed
