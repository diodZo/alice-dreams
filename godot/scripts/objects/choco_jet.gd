class_name ChocoJet
extends Node2D
## Chorro de chocolate del Mundo 7: obstáculo telegráfico con un ciclo fijo.
##  1 reposo: sólo se ve un charquito de chocolate que gotea.
##  2 aviso (WARN_MS): el charco burbujea y brilla.
##  3 chorro (UP_MS): una columna de chocolate sube desde el suelo; sólo hace daño mientras
##    está levantada (la colisión crece con el dibujo).
##  4 vuelve a bajar.
## El aviso dura lo bastante para apartarse: es siempre esquivable.

const WARN_MS := 800.0
const RISE := 0.18

var level: Node
var column: Sprite2D
var puddle: Sprite2D
var hit: Area2D
var shape: RectangleShape2D
var cs: CollisionShape2D
var period := 3200.0
var up_ms := 1300.0
var delay := 0.0
var cycle_start := -1.0
var state := "idle"
var height := 0.0


## def: { x, y (tesela, superficie), period, up (ms con el chorro arriba), delay (ms), frame }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> ChocoJet:
	level = owner_level
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	z_index = C.Z_ENEMY
	period = float(def.get("period", 3200))
	up_ms = float(def.get("up", 1300))
	delay = float(def.get("delay", 0))
	period = maxf(period, up_ms + WARN_MS + 600.0)
	column = Sprite2D.new()
	column.texture = Assets.frame(atlas, def.get("frame", "choco_jet_a"))
	var size := column.texture.get_size()
	height = size.y
	Anim.set_origin(column, size, 0.5, 1.0)
	column.scale = Vector2(1, 0)
	column.visible = false
	add_child(column)
	puddle = Sprite2D.new()
	puddle.texture = Assets.frame(atlas, "choco_drip")
	Anim.set_origin(puddle, puddle.texture.get_size(), 0.5, 1.0)
	puddle.scale = Vector2(0.8, 0.45)
	add_child(puddle)
	hit = Area2D.new()
	shape = RectangleShape2D.new()
	shape.size = Vector2(size.x * 0.6, 1)
	cs = CollisionShape2D.new()
	cs.shape = shape
	cs.disabled = true
	hit.add_child(cs)
	add_child(hit)
	Trigger.configure(hit, "hazard", self)
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
	if t >= period:
		cycle_start = now
		t = 0.0
	var up_at := period - up_ms
	var warn_at := up_at - WARN_MS
	var k := 0.0
	if t < warn_at:
		_set_state("idle")
	elif t < up_at:
		_set_state("warn")
		puddle.scale.y = 0.45 + 0.08 * absf(sin(t / 60.0))
	else:
		_set_state("up")
		var u := (t - up_at) / up_ms
		# sube deprisa, se mantiene y baja deprisa
		k = clampf(minf(u / RISE, (1.0 - u) / RISE), 0.0, 1.0)
	column.visible = k > 0.02
	column.scale.y = k
	var h := height * k * 0.92
	cs.disabled = h < 6.0
	shape.size.y = maxf(h, 1.0)
	cs.position = Vector2(0, -h / 2.0)


func _set_state(s: String) -> void:
	if s == state:
		return
	state = s
	match s:
		"warn":
			level.effects.glow_flash(global_position + Vector2(0, -4), C.rgb(0xc07a4a), 1.2, 2.6, WARN_MS, 0.8, 0)
			AudioManager.play("choco_bubble")
		"up":
			level.effects.poof(global_position.x, global_position.y - 4, 6)


## ¿El chorro está levantado y hace daño? (pruebas)
func is_dangerous() -> bool:
	return not cs.disabled
