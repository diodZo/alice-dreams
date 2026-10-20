class_name SlowCloud
extends Area2D
## Nube ralentizadora del Rey Pesadelo (ataque humorístico): gas violeta con calaveritas
## caricaturescas que avanza despacio por el suelo. No hace daño: mientras Alice la toca queda
## ralentizada SLOW_MS (el plazo se renueva, nunca se acumula) y puede saltar y disparar igual.
## Se desvanece sola al terminar su vida.

const SLOW_MS := 3000.0
const SLOW_FACTOR := 0.5

var level: Node
var velocity := Vector2.ZERO
var die_at := 0.0
var fading := false
var sprite: Sprite2D


func setup(owner_level: Node, pos: Vector2, vx: float, life_ms: float, big := true) -> SlowCloud:
	level = owner_level
	position = pos
	velocity = Vector2(vx, 0)
	die_at = level.now + life_ms
	z_index = C.Z_PROJECTILE
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame("w8_fx", "gas_cloud" if big else "gas_cloud_s")
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0)
	sprite.modulate.a = 0.0
	add_child(sprite)
	var size := sprite.texture.get_size()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size.x * 0.75, size.y * 0.7)
	var cs := CollisionShape2D.new()
	cs.shape = rect
	cs.position = Vector2(0, -rect.size.y / 2.0)
	add_child(cs)
	Trigger.configure(self, "slow_cloud")
	add_to_group("boss_hazard")
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "modulate:a", 0.9, 0.35)
	var wob := sprite.create_tween().set_loops()
	wob.tween_property(sprite, "scale", Vector2(1.06, 0.95), 0.5).set_trans(Tween.TRANS_SINE)
	wob.tween_property(sprite, "scale", Vector2(0.96, 1.05), 0.5).set_trans(Tween.TRANS_SINE)
	return self


func apply(player: Player) -> void:
	if fading:
		return
	var was := player.is_slowed()
	player.apply_slow(SLOW_MS, SLOW_FACTOR)
	if not was:
		level.effects.float_text(player.position.x, player.position.y - 40, "¡Puaj!", C.rgb(0xd85cd5))


func _physics_process(delta: float) -> void:
	if level == null:
		return
	position += velocity * delta
	if not fading and level.now >= die_at:
		vanish()


func vanish() -> void:
	if fading:
		return
	fading = true
	set_deferred("monitorable", false)
	var tw := create_tween().set_parallel()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tw.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.5)
	tw.chain().tween_callback(queue_free)
