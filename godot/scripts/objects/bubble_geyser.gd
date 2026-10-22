class_name BubbleGeyser
extends Area2D
## Géiser de burbujas del Mundo 4: ciclo fijo y legible (burbujea, avisa y entra en erupción).
## Durante la erupción empuja hacia arriba a la protagonista (como una corriente fuerte), lanza
## hacia arriba a los monstruos de suelo y desvía los proyectiles enemigos que lo cruzan.
## Fotogramas geyser_0..4 (base) y bubble_col_0..2 (columna) de tilesets_world_4.png.

const WARN_MS := 650.0
const ERUPT_MS := 1300.0

var level: Node
var atlas := ""
var period := 3200.0
var delay := 0.0
var power := 300.0
var height := 64.0
var base: Sprite2D
var column: Sprite2D
var state := "idle"
var last_sound_at := -9999.0


## def: { x, y (teselas, superficie), h (teselas de altura de la columna), period, delay (ms), power }
func setup(owner_level: Node, def: Dictionary, atlas_name: String) -> BubbleGeyser:
	level = owner_level
	atlas = atlas_name
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	period = float(def.get("period", 3200))
	delay = float(def.get("delay", 0))
	power = float(def.get("power", 300))
	height = float(def.get("h", 4)) * C.TILE
	column = Sprite2D.new()
	column.centered = false
	column.visible = false
	add_child(column)
	base = Sprite2D.new()
	base.centered = false
	base.scale = Vector2(1.5, 1.5)  # la base se lee bien aunque esté en reposo
	add_child(base)
	_show_base(0)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(26, height)
	cs.shape = shape
	cs.position = Vector2(0, -height / 2.0)
	add_child(cs)
	Trigger.configure(self, "geyser")
	z_index = C.Z_PLATFORM + 1
	return self


func _show_base(i: int) -> void:
	var tex := Assets.frame(atlas, "geyser_%d" % i)
	base.texture = tex
	base.offset = Vector2(-round(tex.get_width() / 2.0), -tex.get_height() + 1)


func phase_ms() -> float:
	return fposmod(level.now + delay, period)


func is_erupting() -> bool:
	return state == "erupt"


func _physics_process(_delta: float) -> void:
	if level == null:
		return
	var t := phase_ms()
	var idle_end := period - WARN_MS - ERUPT_MS
	var next := "idle" if t < idle_end else ("warn" if t < idle_end + WARN_MS else "erupt")
	if next != state:
		state = next
		if state == "warn" and level.camera.view_rect().grow(32).has_point(position):
			AudioManager.play("bubble_trap")
		elif state == "erupt" and level.camera.view_rect().grow(32).has_point(position):
			AudioManager.play("wind")
	match state:
		"idle":
			column.visible = false
			_show_base(0 if int(t / 300.0) % 2 == 0 else 1)
		"warn":
			column.visible = false
			_show_base(1 + int((t - idle_end) / 110.0) % 2)
			base.position.x = 1.0 if int(t / 60.0) % 2 == 0 else -1.0
		"erupt":
			base.position.x = 0
			_show_base(4 if int(t / 120.0) % 2 == 0 else 3)
			var ctex := Assets.frame(atlas, "bubble_col_%d" % (int(t / 110.0) % 3))
			column.texture = ctex
			column.visible = true
			column.scale = Vector2(1.0, height / ctex.get_height())
			column.offset = Vector2(-round(ctex.get_width() / 2.0), -ctex.get_height())
			_push_others()


## La protagonista dentro de la columna en erupción sube con fuerza (lo llama el nivel).
func apply(player: Player, delta: float) -> void:
	if not is_erupting():
		return
	player.velocity.y = maxf(player.velocity.y - 2600.0 * delta, -power)
	player.jumping = false


func _push_others() -> void:
	var rect := Rect2(position.x - 13, position.y - height, 26, height)
	for e in level.enemies_root.get_children():
		if e is Enemy and e.is_alive() and e.gravity_enabled and rect.has_point(e.position + Vector2(0, -4)):
			e.velocity.y = -220
	for p in level.enemy_projectiles.get_children():
		if p is Projectile and p.active and rect.has_point(p.position):
			p.velocity.y = minf(p.velocity.y, -120)
			p.base_vy = p.velocity.y


## La protagonista toca el objeto (lo llama Level._process_overlaps cada fotograma).
func on_player_overlap(_level: Node, player: Player, delta: float) -> void:
	apply(player, delta)
