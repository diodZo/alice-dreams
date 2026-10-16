class_name PaintDrip
extends Node2D
## Pintura que gotea (Mundo 2): una mancha colgante que, con ritmo fijo, se hincha (aviso) y
## suelta una gota que cae y daña. def: {x, y (teselas: borde superior de la mancha), color,
## period (ms), delay (ms)}.

const TINTS := {"pink": Color.WHITE, "blue": Color("78c5f8"), "yellow": Color("ffe082")}

var level: Node
var color := "pink"
var period := 1800.0
var delay := 0.0
var sprite: Sprite2D
var _last_cycle := -1


func setup(owner_level: Node, def: Dictionary, atlas := "world2_objects") -> PaintDrip:
	level = owner_level
	color = def.get("color", "pink")
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, "drip_%s" % color)
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 0.0)
	add_child(sprite)
	z_index = C.Z_DECOR_FRONT - 1
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE)
	period = float(def.get("period", 1800))
	delay = float(def.get("delay", 0))
	return self


func _physics_process(_delta: float) -> void:
	if level == null:
		return
	var t: float = level.now + delay
	var cyc := int(floor(t / period))
	var phase := fposmod(t, period)
	# aviso: la mancha se estira durante los 400 ms previos a la gota
	var warn := clampf((phase - (period - 400.0)) / 400.0, 0.0, 1.0)
	sprite.scale = Vector2(1.0 - 0.15 * warn, 1.0 + 0.35 * warn)
	if cyc != _last_cycle:
		if _last_cycle != -1:
			_drop()
		_last_cycle = cyc


func _drop() -> void:
	var h := sprite.texture.get_height()
	level.spawn_projectile("enemy", {
		"x": position.x, "y": position.y + h, "vx": 0, "vy": 20, "gravity": 600,
		"texture": "w2_fx", "frame": "paint_drop", "lifespan": 2500, "body": 6,
		"owner": "enemy", "kind": "drop", "damage": 1, "rotate": true,
		"tint": TINTS.get(color, Color.WHITE),
	})
