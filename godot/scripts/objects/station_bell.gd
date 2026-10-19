class_name StationBell
extends Area2D
## Campana de estación del Mundo 6: al tocarla suena, se balancea y suelta notas y destellos.
## Puede llamar a un tren que espera en su estación (TrainLine con bellWait) y, la primera vez,
## dar una estrella de regalo.

signal rung

var level: Node
var sprite: Sprite2D
var train: TrainLine
var gift := false
var _last_touch := -10
var ready_at := 0.0
var rung_once := false


## def: { x, y (teselas: altura del soporte), train (índice o -1), gift (bool) }
func setup(owner_level: Node, def: Dictionary, atlas: String, target: TrainLine) -> StationBell:
	level = owner_level
	train = target
	gift = bool(def.get("gift", false))
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, "bell")
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 0.0)
	add_child(sprite)
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(sprite.texture.get_width() + 6, sprite.texture.get_height() + 10)
	cs.shape = shape
	cs.position = Vector2(0, shape.size.y / 2.0)
	add_child(cs)
	Trigger.configure(self, "bell")
	z_index = C.Z_PICKUP
	return self


func touch() -> void:
	var f := Engine.get_physics_frames()
	var fresh := f - _last_touch > 2
	_last_touch = f
	if fresh:
		ring()


func ring() -> void:
	if level.now < ready_at:
		return
	ready_at = level.now + 700
	AudioManager.play("train_bell")
	var tw := sprite.create_tween()
	for a in [22.0, -18.0, 12.0, -8.0, 0.0]:
		tw.tween_property(sprite, "rotation_degrees", a, 0.09)
	level.effects.sparkle(position.x, position.y + 8, 8)
	level.effects.float_text(position.x, position.y - 4, "Din don", C.YELLOW)
	if train != null:
		train.call_train()
	if gift and not rung_once:
		level.spawn_bonus_star(position.x, position.y - 10)
	rung_once = true
	rung.emit()
