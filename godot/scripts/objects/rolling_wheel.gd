class_name RollingWheel
extends Area2D
## Rueda rodante del Mundo 6: obstáculo que recorre una ruta sencilla (también pendientes) a
## velocidad constante, girando según la distancia recorrida. Su posición sólo depende del reloj
## del nivel (comportamiento predecible). Modos:
##  "loop": al final de la ruta se deshace en una nubecita y vuelve a salir del principio.
##  "pingpong": va y vuelve.

const PAUSE_MS := 900.0

var level: Node
var sprite: Sprite2D
var points := PackedVector2Array()
var lengths: Array[float] = []
var total := 0.0
var speed := 70.0
var delay := 0.0
var mode := "loop"
var radius := 8.0
var _was_visible := true


## def: { points: [[x, y]...] (teselas: superficie del suelo), speed (px/s), delay (ms), mode, frame }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> RollingWheel:
	level = owner_level
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "wheel_l"))
	add_child(sprite)
	radius = sprite.texture.get_height() / 2.0
	for p in def.points:
		points.append(Vector2(float(p[0]), float(p[1])) * C.TILE)
	lengths.append(0.0)
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
		lengths.append(total)
	speed = float(def.get("speed", 70))
	delay = float(def.get("delay", 0))
	mode = str(def.get("mode", "loop"))
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.72
	cs.shape = circle
	add_child(cs)
	Trigger.configure(self, "hazard")
	z_index = C.Z_ENEMY
	_place(0.0)
	return self


func period() -> float:
	var run := total / speed * 1000.0
	return run * 2.0 if mode == "pingpong" else run + PAUSE_MS


## Distancia recorrida en el instante t del nivel (-1 = en la pausa entre vueltas).
func distance_at(t: float) -> float:
	var k := fposmod(t - delay, period())
	var run := total / speed * 1000.0
	if mode == "pingpong":
		return (k if k < run else 2.0 * run - k) / 1000.0 * speed
	return k / 1000.0 * speed if k < run else -1.0


func point_at(d: float) -> Vector2:
	for i in range(1, points.size()):
		if d <= lengths[i]:
			var t := (d - lengths[i - 1]) / maxf(lengths[i] - lengths[i - 1], 0.001)
			return points[i - 1].lerp(points[i], t)
	return points[points.size() - 1]


func _place(d: float) -> void:
	position = point_at(d) - Vector2(0, radius)
	sprite.rotation = d / radius


func _physics_process(_delta: float) -> void:
	if level == null:
		return
	var d := distance_at(level.now)
	var on := d >= 0.0
	if on:
		_place(d)
	if on != _was_visible:
		_was_visible = on
		visible = on
		monitorable = on
		if not on:
			level.effects.poof(position.x, position.y, 6)
