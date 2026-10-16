class_name ParticleBurst
extends Node2D
## Partículas pixel art con la semántica de los emisores de Phaser: velocidad y ángulo
## aleatorios (o speedX/speedY), vida aleatoria, escala y alfa interpolados linealmente,
## gravedad vertical y tinte elegido al azar de una lista. Se dibujan como rectángulos
## nítidos de 2x2 px ('px') o 3x2 px ('confetti') escalados.
##
## Modo ráfaga: explode(count, pos). Modo continuo: emitting = true con frequency (ms);
## `follow` permite seguir a un nodo (estela de la pintura).

var cfg := {}
var emitting := false
var follow: Node2D = null
## El nodo se libera solo cuando no emite y no le quedan partículas.
var auto_free := true

var _parts: Array = []
var _acc := 0.0
var _rng := RandomNumberGenerator.new()


## cfg admite: speed:[min,max] | speed_x/speed_y:[min,max], angle:[min,max] (grados),
## life:[min,max] (ms), scale:[ini,fin], scale_y:[ini,fin], alpha:[ini,fin], gravity,
## colors:[Color], size:Vector2, rotate:[min,max], x_range:[min,max] (local), frequency (ms)
func setup(config: Dictionary) -> ParticleBurst:
	cfg = config
	_rng.randomize()
	return self


func explode(count: int, at: Vector2) -> void:
	for i in count:
		_spawn(at)


func _spawn(at: Vector2) -> void:
	var v: Vector2
	if cfg.has("speed_x") or cfg.has("speed_y"):
		var sx: Array = cfg.get("speed_x", [0, 0])
		var sy: Array = cfg.get("speed_y", [0, 0])
		v = Vector2(_rng.randf_range(sx[0], sx[1]), _rng.randf_range(sy[0], sy[1]))
	else:
		var sp: Array = cfg.get("speed", [0, 0])
		var an: Array = cfg.get("angle", [0, 360])
		var a := deg_to_rad(_rng.randf_range(an[0], an[1]))
		v = Vector2(cos(a), sin(a)) * _rng.randf_range(sp[0], sp[1])
	var life: Array = cfg.get("life", [500, 500])
	var colors: Array = cfg.get("colors", [Color.WHITE])
	var rot: Array = cfg.get("rotate", [0, 0])
	var pos := at
	if cfg.has("x_range"):
		pos.x += _rng.randf_range(cfg.x_range[0], cfg.x_range[1])
	_parts.append({
		"p": pos,
		"v": v,
		"age": 0.0,
		"life": _rng.randf_range(life[0], life[1]),
		"c": colors[_rng.randi() % colors.size()],
		"r": deg_to_rad(_rng.randf_range(rot[0], rot[1])),
	})


func _physics_process(delta: float) -> void:
	var ms := delta * 1000.0
	if emitting:
		_acc += ms
		var freq: float = cfg.get("frequency", 50.0)
		while _acc >= freq:
			_acc -= freq
			var at := Vector2.ZERO
			if follow != null:
				if is_instance_valid(follow):
					at = to_local(follow.global_position)
				else:
					emitting = false
					break
			_spawn(at)
	var g: float = cfg.get("gravity", 0.0)
	var alive: Array = []
	for p in _parts:
		p.age += ms
		if p.age >= p.life:
			continue
		p.v.y += g * delta
		p.p += p.v * delta
		alive.append(p)
	_parts = alive
	if auto_free and not emitting and _parts.is_empty():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var size: Vector2 = cfg.get("size", Vector2(2, 2))
	var sc: Array = cfg.get("scale", [1, 1])
	var scy: Array = cfg.get("scale_y", sc)
	var al: Array = cfg.get("alpha", [1, 1])
	for p in _parts:
		var t: float = p.age / p.life
		var s := Vector2(size.x * lerpf(sc[0], sc[1], t), size.y * lerpf(scy[0], scy[1], t))
		if s.x <= 0.01 or s.y <= 0.01:
			continue
		var c: Color = p.c
		c.a *= lerpf(al[0], al[1], t)
		draw_set_transform(p.p, p.r)
		draw_rect(Rect2(-s / 2.0, s), c)
	draw_set_transform(Vector2.ZERO)
