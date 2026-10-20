class_name FallingStar
extends Node2D
## Estrella que cae (Mundo 5): obstáculo telegráfico con un ciclo fijo.
##  1 aviso (WARN_MS): brilla un destello en el suelo donde va a caer y la estrella titila arriba.
##  2 caída: baja recta con su estela ("estrellas que caen", tilesets_world_5.png); sólo
##    hace daño mientras cae.
##  3 impacto: chispas y desaparece hasta el siguiente ciclo.
## El aviso dura lo bastante para apartarse andando: es siempre esquivable.

const WARN_MS := 1000.0
const FALL_SPEED := 260.0

var level: Node
var atlas := ""
var period := 3200.0
var delay := 0.0
var ground_y := 0.0
var top_y := 0.0
var star: Sprite2D
var hit: Area2D
var marker: Sprite2D
var falling := false
var cycle_start := -1.0
var anim_acc := 0.0
var frame_i := 0
## Fotogramas de la caída (Mundo 5: estrella con estela) y del aviso (Mundo 8: la estrella aún
## colgada de su cadena). Se pueden cambiar en los datos con "frames" y "warn_frame".
var fall_frames: Array = ["fall_star_0", "fall_star_1", "fall_star_2", "fall_star_3"]
var warn_frame := ""


## def: { x (tesela), y (fila de la superficie donde cae), height (teselas por encima), period, delay (ms),
##        frames (fotogramas de la caída), warn_frame (fotograma durante el aviso) }
func setup(owner_level: Node, def: Dictionary, atlas_name: String) -> FallingStar:
	level = owner_level
	atlas = atlas_name
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, 0)
	ground_y = float(def.y) * C.TILE
	top_y = ground_y - float(def.get("height", 9)) * C.TILE
	period = float(def.get("period", 3200))
	delay = float(def.get("delay", 0))
	fall_frames = def.get("frames", fall_frames)
	warn_frame = def.get("warn_frame", "")
	z_index = C.Z_ENEMY
	marker = Sprite2D.new()
	marker.texture = Assets.generated("glow")
	marker.modulate = Color(C.YELLOW, 0.0)
	marker.scale = Vector2(1.6, 0.5)
	marker.position = Vector2(0, ground_y - 2)
	add_child(marker)
	star = Sprite2D.new()
	star.texture = Assets.frame(atlas, fall_frames[0])
	# la estela queda por encima: el origen es la estrella (parte baja del dibujo)
	Anim.set_origin(star, star.texture.get_size(), 0.5, 0.85)
	star.position = Vector2(0, top_y)
	star.visible = false
	add_child(star)
	hit = Area2D.new()
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6
	cs.shape = circle
	hit.add_child(cs)
	Trigger.configure(hit, "hazard")
	hit.monitorable = false
	star.add_child(hit)
	hit.position = Vector2(0, -3)
	return self


## Fase del ciclo en el instante del nivel: "wait", "warn" o "fall".
func phase_at(t: float) -> String:
	var k := fposmod(t - delay, period)
	var fall_ms := (ground_y - top_y) / FALL_SPEED * 1000.0
	if k < WARN_MS:
		return "warn"
	if k < WARN_MS + fall_ms:
		return "fall"
	return "wait"


func is_falling() -> bool:
	return falling


func _physics_process(delta: float) -> void:
	if level == null:
		return
	var t: float = level.now
	var k := fposmod(t - delay, period)
	match phase_at(t):
		"warn":
			if falling:
				_stop()
			star.visible = true
			star.position.y = top_y
			if warn_frame != "":
				star.texture = Assets.frame(atlas, warn_frame)
			# titila arriba y el destello del suelo crece: "¡aquí va a caer!"
			var u := k / WARN_MS
			star.modulate.a = 0.45 + 0.55 * absf(sin(u * PI * 5.0))
			marker.modulate.a = 0.25 + 0.55 * u
			marker.scale = Vector2(1.2 + u * 0.8, 0.5)
			if k < delta * 1000.0 + 1.0:
				_twinkle()
		"fall":
			if not falling:
				falling = true
				hit.set_deferred("monitorable", true)
				star.modulate.a = 1.0
				star.texture = Assets.frame(atlas, fall_frames[0])
			star.visible = true
			star.position.y = top_y + (k - WARN_MS) / 1000.0 * FALL_SPEED
			marker.modulate.a = 0.8
			anim_acc += delta
			if anim_acc > 0.08:
				anim_acc = 0
				frame_i = (frame_i + 1) % fall_frames.size()
				star.texture = Assets.frame(atlas, fall_frames[frame_i])
		_:
			if falling:
				_impact()
			star.visible = false
			marker.modulate.a = 0.0


func _twinkle() -> void:
	if absf(position.x - level.player.position.x) < C.GAME_W:
		AudioManager.play("twinkle")


func _stop() -> void:
	falling = false
	hit.set_deferred("monitorable", false)


func _impact() -> void:
	_stop()
	level.effects.sparkle(position.x, ground_y - 4, 10)
	level.effects.glow_flash(Vector2(position.x, ground_y - 4), C.YELLOW, 1, 3, 300, 0.8, 0)
