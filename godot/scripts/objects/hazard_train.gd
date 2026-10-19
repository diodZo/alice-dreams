class_name HazardTrain
extends Node2D
## Tren enemigo del Mundo 6: sale de un túnel arcoíris, cruza su tramo de vía y entra en el
## otro túnel, siempre con el mismo ciclo (comportamiento predecible y esquivable):
##  1 aviso (WARN_MS): silbato y señales rojas parpadeando en las dos bocas.
##  2 paso: cruza de x0 a x1; sólo hace daño mientras está fuera de los túneles.
##  3 vía libre hasta el siguiente aviso (tiempo de sobra para cruzar andando).
## Esperar delante de la boca de salida es seguro: el tren nunca sale del tramo [x0, x1].

const WARN_MS := 1300.0

var level: Node
var x0 := 0.0
var x1 := 0.0
var rail_y := 0.0
var period := 6000.0
var delay := 0.0
var speed := 200.0
var dir := 1
var train: Sprite2D
var hit: Area2D
var signals: Array[Sprite2D] = []
var _whistled := false


## def: { x0, x1 (teselas: bocas de los túneles), y (fila de la superficie), period, delay (ms), speed, dir }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> HazardTrain:
	level = owner_level
	x0 = float(def.x0) * C.TILE
	x1 = float(def.x1) * C.TILE
	rail_y = float(def.y) * C.TILE
	period = float(def.get("period", 6000))
	delay = float(def.get("delay", 0))
	speed = float(def.get("speed", 200))
	dir = int(def.get("dir", 1))
	z_index = C.Z_ENEMY
	# vía visible entre las dos bocas
	var tex := ImageTexture.create_from_image(Assets.frame(atlas, "rail_strip").get_image())
	var line := Line2D.new()
	line.texture = tex
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	line.width = tex.get_height()
	line.points = PackedVector2Array([Vector2(x0, rail_y + tex.get_height() / 2.0 - 3), Vector2(x1, rail_y + tex.get_height() / 2.0 - 3)])
	line.z_as_relative = false
	line.z_index = C.Z_DECOR_BACK
	add_child(line)
	train = Sprite2D.new()
	train.texture = Assets.frame(atlas, "hazard_train")
	Anim.set_origin(train, train.texture.get_size(), 0.5, 1.0)
	train.flip_h = dir < 0
	train.visible = false
	add_child(train)
	hit = Area2D.new()
	var shape := RectangleShape2D.new()
	shape.size = train.texture.get_size() - Vector2(10, 12)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -shape.size.y / 2.0 - 2)
	hit.add_child(cs)
	Trigger.configure(hit, "hazard")
	hit.monitorable = false
	train.add_child(hit)
	# bocas de túnel (por delante del tren, por detrás de Alice) y señales
	for x in [x0, x1]:
		var tunnel := Sprite2D.new()
		tunnel.texture = Assets.frame(atlas, "rainbow_tunnel")
		Anim.set_origin(tunnel, tunnel.texture.get_size(), 0.5, 1.0)
		tunnel.position = Vector2(x + (-1 if x == x0 else 1) * dir * tunnel.texture.get_width() * 0.3, rail_y + 8)
		tunnel.z_as_relative = false
		tunnel.z_index = C.Z_ENEMY + 1
		add_child(tunnel)
		var sig := Sprite2D.new()
		sig.texture = Assets.generated("glow")
		sig.position = Vector2(x, rail_y - 44)
		sig.modulate = Color(C.rgb(0x70d7b5), 0.8)
		sig.z_as_relative = false
		sig.z_index = C.Z_ENEMY + 2
		add_child(sig)
		signals.append(sig)
	return self


func run_ms() -> float:
	return (absf(x1 - x0) + train.texture.get_width()) / speed * 1000.0


## Fase del ciclo: "warn", "run" o "clear".
func phase_at(t: float) -> String:
	var k := fposmod(t - delay, period)
	if k < WARN_MS:
		return "warn"
	if k < WARN_MS + run_ms():
		return "run"
	return "clear"


## Milisegundos hasta el próximo aviso.
func time_to_warn(t: float) -> float:
	return period - fposmod(t - delay, period)


## ¿Es peligroso cruzar ahora desde x? (lo usa el piloto automático para esperar)
func blocks(x: float, cross_ms := 2600.0) -> bool:
	var near := x < minf(x0, x1) and x > minf(x0, x1) - 72
	if not near:
		return false
	var t: float = level.now
	return phase_at(t) != "clear" or time_to_warn(t) < cross_ms


func _physics_process(_delta: float) -> void:
	if level == null:
		return
	var t: float = level.now
	var k := fposmod(t - delay, period)
	match phase_at(t):
		"warn":
			train.visible = false
			hit.monitorable = false
			var on := int(k / 160.0) % 2 == 0
			for s in signals:
				s.modulate = Color(C.rgb(0xf76b73), 0.95 if on else 0.3)
			if not _whistled and absf(level.player.position.x - (x0 + x1) / 2.0) < C.GAME_W:
				_whistled = true
				AudioManager.play("whistle")
		"run":
			_whistled = false
			var w := train.texture.get_width()
			var from := (x0 - w / 2.0) if dir > 0 else (x1 + w / 2.0)
			train.position = Vector2(from + dir * (k - WARN_MS) / 1000.0 * speed, rail_y)
			train.visible = true
			var inside := train.position.x > minf(x0, x1) - w * 0.3 and train.position.x < maxf(x0, x1) + w * 0.3
			hit.monitorable = inside
			for s in signals:
				s.modulate = Color(C.rgb(0xf76b73), 0.8)
		_:
			train.visible = false
			hit.monitorable = false
			for s in signals:
				s.modulate = Color(C.rgb(0x70d7b5), 0.8)
