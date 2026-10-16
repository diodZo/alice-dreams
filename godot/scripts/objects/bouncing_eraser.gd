class_name BouncingEraser
extends Area2D
## Borrador que rebota en su sitio (obstáculo del Mundo 2, no es un enemigo): sube y baja con
## un ritmo fijo y se aplasta al tocar el suelo. Se pasa por debajo cuando está arriba.
## def: {x, y (superficie), height (teselas), period (ms), delay (ms)}.

var level: Node
var base_y := 0.0
var height := 48.0
var period := 1200.0
var delay := 0.0
var sprite: Sprite2D


func setup(owner_level: Node, def: Dictionary, atlas := "world2_objects") -> BouncingEraser:
	level = owner_level
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, "bouncing_eraser")
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0)
	add_child(sprite)
	z_index = C.Z_ENEMY
	base_y = float(def.y) * C.TILE
	position = Vector2(float(def.x) * C.TILE + 8, base_y)
	height = float(def.get("height", 3)) * C.TILE
	period = float(def.get("period", 1200))
	delay = float(def.get("delay", 0))
	var size := sprite.texture.get_size()
	var shape := RectangleShape2D.new()
	shape.size = size * Vector2(0.75, 0.7)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -size.y * 0.45)
	add_child(cs)
	Trigger.configure(self, "hazard")
	return self


func _physics_process(_delta: float) -> void:
	if level == null:
		return
	var t := fposmod(level.now + delay, period) / period
	# parábola: arriba a mitad del periodo, apoyado en los extremos
	var h := 4.0 * t * (1.0 - t)
	position.y = base_y - h * height
	var squash := clampf(1.0 - h * 6.0, 0.0, 1.0)
	sprite.scale = Vector2(1.0 + 0.25 * squash, 1.0 - 0.3 * squash)
