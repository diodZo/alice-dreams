class_name CandyLauncher
extends Node2D
## Lanzador de caramelos del Mundo 7: cañoncito rosa que dispara una bola de caramelo recta cada
## `period` ms. Antes de cada disparo avisa (WARN_MS): tiembla, se hincha y brilla la boca del
## cañón. La bola vuela a altura fija y despacio: se salta o se esquiva agachándose bajo ella
## (si el lanzador está en alto). No se destruye: es parte del escenario.

const WARN_MS := 700.0

var level: Node
var sprite: Sprite2D
var dir := 1
var period := 2600.0
var delay := 0.0
var shot_speed := 95.0
var muzzle := Vector2.ZERO
var cycle_start := -1.0
var warned := false
var shots := 0


## def: { x, y (tesela, superficie donde se apoya), dir (1 derecha, -1 izquierda), period, delay (ms),
##        speed (px/s de la bola), frame ("launcher_a" en el suelo, "launcher_b" sobre su pie) }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> CandyLauncher:
	level = owner_level
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	z_index = C.Z_ENEMY
	dir = -1 if int(def.get("dir", 1)) < 0 else 1
	period = maxf(float(def.get("period", 2600)), WARN_MS + 400.0)
	delay = float(def.get("delay", 0))
	shot_speed = float(def.get("speed", 95))
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "launcher_a"))
	var size := sprite.texture.get_size()
	Anim.set_origin(sprite, size, 0.5, 1.0)
	sprite.flip_h = dir < 0
	add_child(sprite)
	# la boca del cañón está en el lado hacia el que dispara, en la mitad alta del dibujo
	muzzle = Vector2(dir * size.x * 0.46, -size.y * 0.68)
	return self


func _physics_process(_delta: float) -> void:
	if level == null:
		return
	var now: float = level.now
	if now < delay:
		return
	if cycle_start < 0:
		cycle_start = now
	var t := now - cycle_start
	if not warned and t >= period - WARN_MS:
		warned = true
		_warn()
	if t >= period:
		cycle_start = now
		warned = false
		_fire()


func _warn() -> void:
	level.effects.glow_flash(global_position + muzzle, C.rgb(0xff8fc8), 1.0, 2.4, WARN_MS, 0.85, 1)
	var tw := sprite.create_tween()
	for i in 4:
		tw.tween_property(sprite, "scale", Vector2(1.08, 0.94), 0.08)
		tw.tween_property(sprite, "scale", Vector2.ONE, 0.08)


func _fire() -> void:
	shots += 1
	var p := global_position + muzzle
	level.spawn_projectile("enemy", {"x": p.x, "y": p.y, "vx": dir * shot_speed, "vy": 0, "texture": "w7_fx",
		"frame": "launcher_ball", "lifespan": 4200, "body": 9, "owner": "enemy", "kind": "candy_ball", "damage": 1, "spin": 200})
	level.effects.poof(p.x, p.y, 4)
	AudioManager.play("candy_pop")
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "position:x", -dir * 2.0, 0.05)
	tw.tween_property(sprite, "position:x", 0.0, 0.12)
