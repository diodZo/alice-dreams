class_name Effects
extends RefCounted
## Efectos visuales reutilizables (port de systems/EffectsManager.js). Sólo dibuja:
## no conoce reglas de juego ni colisiones. Los nodos se añaden a `root` (capa FX).

const SPARKLES := {"speed": [30, 90], "life": [300, 600], "scale": [1, 0], "gravity": 60.0}
const SPLAT := {"speed": [40, 120], "life": [250, 450], "scale": [1.5, 0.5], "gravity": 300.0}
const PUFFS := {"speed": [10, 45], "life": [300, 500], "scale": [2.5, 0], "alpha": [0.9, 0]}
const CONFETTI := {"speed": [60, 180], "angle": [200, 340], "life": [1200, 2000], "gravity": 160.0, "rotate": [0, 360], "size": Vector2(3, 2)}
const TRAIL := {"speed": [0, 0], "life": [200, 200], "scale": [1, 0], "alpha": [0.8, 0], "frequency": 25.0}

var root: Node2D


func _init(fx_root: Node2D) -> void:
	root = fx_root


func _burst(cfg: Dictionary, count: int, at: Vector2) -> ParticleBurst:
	var b := ParticleBurst.new().setup(cfg)
	root.add_child(b)
	b.explode(count, at)
	return b


static func colors(list: Array) -> Array:
	return list.map(func(c): return C.rgb(c))


func sparkle(x: float, y: float, count := 10) -> void:
	var cfg := SPARKLES.duplicate()
	cfg.colors = colors([0xffe082, 0xfff7ff, 0xf7a8d8])
	_burst(cfg, count, Vector2(x, y))


## Acierto en el descanso de un jefe (IMP-005).
func gold_spark(x: float, y: float) -> void:
	var cfg := SPARKLES.duplicate()
	cfg.colors = colors([0xffd23f, 0xfff0a0])
	_burst(cfg, 8, Vector2(x, y))


func paint_splat(x: float, y: float, color: Color) -> void:
	var cfg := SPLAT.duplicate()
	cfg.colors = [color]
	_burst(cfg, 10, Vector2(x, y))
	var s := Sprite2D.new()
	s.texture = Assets.frame("fx", "paint_splash")
	s.position = Vector2(x, y)
	s.modulate = color
	s.scale = Vector2(0.6, 0.6)
	s.rotation_degrees = randf() * 360.0
	root.add_child(s)
	var tw := s.create_tween().set_parallel()
	tw.tween_property(s, "scale", Vector2.ONE, 0.28)
	tw.tween_property(s, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(s.queue_free)


func poof(x: float, y: float, count := 8) -> void:
	var cfg := PUFFS.duplicate()
	cfg.colors = colors([0xfff7ff, 0xe8e0ff])
	_burst(cfg, count, Vector2(x, y))


func dust(x: float, y: float) -> void:
	poof(x, y - 2, 4)


func bubble_pop(x: float, y: float) -> void:
	sparkle(x, y, 6)
	var ring := RingFx.new()
	ring.position = Vector2(x, y)
	root.add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.22)
	tw.tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(ring.queue_free)


func impact(x: float, y: float, color := Color.WHITE) -> void:
	var cfg := SPLAT.duplicate()
	cfg.colors = [color]
	_burst(cfg, 6, Vector2(x, y))


func confetti(x: float, y: float, count := 60) -> void:
	var cfg := CONFETTI.duplicate()
	var list: Array = Assets.weapons_meta.get("paintColors", []).duplicate()
	list.append(0xffffff)
	cfg.colors = colors(list)
	_burst(cfg, count, Vector2(x, y))


## Estela de pintura que sigue al proyectil mientras está activo.
func paint_trail(target: Node2D, color: Color) -> void:
	var cfg := TRAIL.duplicate()
	cfg.colors = [color]
	var e := ParticleBurst.new().setup(cfg)
	e.follow = target
	e.emitting = true
	e.z_index = -1
	root.add_child(e)
	target.tree_exiting.connect(func(): e.emitting = false)
	if target.has_signal("expired"):
		target.connect("expired", func(): e.emitting = false)


## Texto flotante corto (p. ej. "+1").
func float_text(x: float, y: float, txt: String, color := C.YELLOW) -> void:
	var t := PixelText.make(txt, {"origin": Vector2(0.5, 0.5), "tint": color})
	t.position = Vector2(x, y)
	root.add_child(t)
	var tw := t.create_tween().set_parallel()
	tw.tween_property(t, "position:y", y - 18, 0.7)
	tw.tween_property(t, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(t.queue_free)


## Destello circular suave (textura 'glow') que crece y se desvanece.
func glow_flash(pos: Vector2, color: Color, from_scale: float, to_scale: float, ms: float, alpha := 0.9, z := 0) -> Sprite2D:
	var g := Sprite2D.new()
	g.texture = Assets.generated("glow")
	g.position = pos
	g.modulate = Color(color, alpha)
	g.scale = Vector2(from_scale, from_scale)
	g.z_index = z
	root.add_child(g)
	var tw := g.create_tween().set_parallel()
	tw.tween_property(g, "scale", Vector2(to_scale, to_scale), ms / 1000.0)
	tw.tween_property(g, "modulate:a", 0.0, ms / 1000.0)
	tw.chain().tween_callback(g.queue_free)
	return g


## Anillo de burbuja (círculo con trazo de 1 px).
class RingFx:
	extends Node2D

	func _draw() -> void:
		draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 24, C.rgb(0xc8f0ff), 1.0, false)
