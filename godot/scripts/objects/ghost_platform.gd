class_name GhostPlatform
extends StaticBody2D
## Plataforma fantasma del Mundo 8: aparece y desaparece con un ciclo fijo sobre el reloj del
## nivel (determinista, siempre igual):
##   VISIBLE  -> se puede pisar
##   WARNING  -> sigue sólida, pero parpadea y brilla (aviso: va a desaparecer)
##   INVISIBLE-> no colisiona; queda un contorno tenue para saber dónde volverá
##   REAPPEAR -> se materializa (ya es sólida) y vuelve a VISIBLE
## Los datos desfasan (`delay`) las plataformas de un mismo hueco para que nunca desaparezcan
## todas a la vez.

const REAPPEAR_MS := 400.0

var level: Node
var sprite: Sprite2D
var outline: Sprite2D
var shape: CollisionShape2D
var period := 4000.0
var visible_ms := 2200.0
var warn_ms := 800.0
var delay := 0.0
var state := ""


## def: { x (centro), y (superficie) en teselas, period, visible (ms sólida, aviso incluido),
##        warn (ms de aviso al final de la parte visible), delay, frame, frame_off, top }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> GhostPlatform:
	level = owner_level
	period = float(def.get("period", 4000))
	visible_ms = float(def.get("visible", 2200))
	warn_ms = float(def.get("warn", 800))
	delay = float(def.get("delay", 0))
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	position.x = float(def.x) * C.TILE
	outline = Sprite2D.new()
	outline.texture = Assets.frame(atlas, def.get("frame_off", "ghost_plat_off"))
	outline.modulate.a = 0.0
	add_child(outline)
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "ghost_plat_on"))
	add_child(sprite)
	shape = CloudPlatform.add_cloud_shape(self, sprite, sprite.texture.get_size(), float(def.y) * C.TILE, float(def.get("top", 3)))
	outline.centered = false
	outline.offset = Vector2(-round(outline.texture.get_width() / 2.0), sprite.texture.get_height() - outline.texture.get_height())
	_apply(state_at(0.0), 0.0)
	return self


## Estado del ciclo en el instante t (ms del nivel).
func state_at(t: float) -> String:
	var k := fposmod(t - delay, period)
	if k < visible_ms - warn_ms:
		return "VISIBLE"
	if k < visible_ms:
		return "WARNING"
	if k < period - REAPPEAR_MS:
		return "INVISIBLE"
	return "REAPPEAR"


func is_solid() -> bool:
	return state != "INVISIBLE"


func _physics_process(_delta: float) -> void:
	if level == null:
		return
	var t: float = level.now
	_apply(state_at(t), t)


func _apply(s: String, t: float) -> void:
	var k := fposmod(t - delay, period)
	if s != state:
		if s == "INVISIBLE" and state != "":
			level.effects.poof(position.x, position.y + 6, 6)
		if s == "WARNING" and absf(position.x - level.player.position.x) < C.GAME_W:
			AudioManager.play("ghost_warn")
		state = s
		shape.set_deferred("disabled", s == "INVISIBLE")
	match s:
		"VISIBLE":
			sprite.modulate = Color(1, 1, 1, 0.92)
			outline.modulate.a = 0.0
		"WARNING":
			# parpadeo cada vez más rápido y brillo lunar
			var u := (k - (visible_ms - warn_ms)) / warn_ms
			var blink := int(k / lerpf(140.0, 60.0, u)) % 2 == 0
			sprite.modulate = C.rgb(0xffe18c, 1.0) if blink else Color(1, 1, 1, 0.55)
			outline.modulate.a = 0.0
		"INVISIBLE":
			sprite.modulate.a = 0.0
			outline.modulate.a = 0.28
		"REAPPEAR":
			var r := (k - (period - REAPPEAR_MS)) / REAPPEAR_MS
			sprite.modulate = Color(1, 1, 1, r * 0.92)
			outline.modulate.a = 0.28 * (1.0 - r)
