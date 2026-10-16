class_name RollingPencil
extends Area2D
## Lápiz rodante (Mundo 2): recorre el suelo de un extremo a otro a ritmo fijo y daña al
## tocarlo. Se salta por encima. def: {x, y (superficie), range: [x0, x1] (teselas), speed}.

var level: Node
var x_min := 0.0
var x_max := 0.0
var speed := 60.0
var dir := 1
var sprite: Sprite2D
var _t := 0.0


func setup(owner_level: Node, def: Dictionary, atlas := "world2_objects") -> RollingPencil:
	level = owner_level
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, "rolling_pencil")
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0)
	add_child(sprite)
	z_index = C.Z_ENEMY
	var size := sprite.texture.get_size()
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE)
	x_min = float(def.range[0]) * C.TILE + size.x / 2.0
	x_max = float(def.range[1]) * C.TILE + C.TILE - size.x / 2.0
	speed = float(def.get("speed", 60))
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x - 6, size.y * 0.5)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -size.y * 0.3)
	add_child(cs)
	Trigger.configure(self, "hazard")
	return self


func _physics_process(delta: float) -> void:
	position.x += dir * speed * delta
	if position.x >= x_max:
		position.x = x_max
		dir = -1
	elif position.x <= x_min:
		position.x = x_min
		dir = 1
	# la punta mira hacia donde avanza; pequeño traqueteo al rodar
	sprite.flip_h = dir < 0
	_t += delta
	sprite.position.y = -absf(sin(_t * 14.0)) * 1.0
