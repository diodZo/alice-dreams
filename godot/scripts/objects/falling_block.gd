class_name FallingBlock
extends StaticBody2D
## Bloque de juguete que cae (Mundo 6). Estados: IDLE -> WARNING -> FALLING -> RESTING -> RESET.
##  IDLE: suspendido; se activa cuando Alice pasa por debajo.
##  WARNING (WARN_MS): tiembla, suelta polvo y marca en el suelo dónde caerá. Tiempo de sobra
##    para apartarse andando.
##  FALLING: cae acelerando; sólo hace daño mientras cae.
##  RESTING: se queda en el suelo como plataforma (se puede pisar).
##  RESET: se desvanece y vuelve a su sitio arriba.

const WARN_MS := 850.0
const REST_MS := 2400.0
const RESET_MS := 700.0
const GRAVITY := 700.0
const TRIGGER_DX := 22.0

var level: Node
var sprite: Sprite2D
var hit: Area2D
var marker: Sprite2D
var body_shape: CollisionShape2D
var state := "IDLE"
var state_at := 0.0
var top_y := 0.0
var ground_y := 0.0
var vy := 0.0


## def: { x (tesela), y (fila donde cuelga, borde superior), ground (fila de la superficie donde cae), frame }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> FallingBlock:
	level = owner_level
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "fall_block_orange"))
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 0.0)
	add_child(sprite)
	var size := sprite.texture.get_size()
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	top_y = position.y
	ground_y = float(def.ground) * C.TILE - size.y
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x - 2, 8)
	body_shape = CollisionShape2D.new()
	body_shape.shape = shape
	body_shape.position = Vector2(0, 4)
	body_shape.one_way_collision = true
	body_shape.one_way_collision_margin = 5.0
	body_shape.disabled = true
	add_child(body_shape)
	hit = Area2D.new()
	var hs := RectangleShape2D.new()
	hs.size = size - Vector2(4, 4)
	var hcs := CollisionShape2D.new()
	hcs.shape = hs
	hcs.position = Vector2(0, size.y / 2.0)
	hit.add_child(hcs)
	Trigger.configure(hit, "hazard")
	hit.monitorable = false
	add_child(hit)
	marker = Sprite2D.new()
	marker.texture = Assets.generated("glow")
	marker.modulate = Color(C.rgb(0xf76b73), 0.0)
	marker.scale = Vector2(size.x / 14.0, 0.5)
	marker.z_as_relative = false
	marker.z_index = C.Z_DECOR_BACK + 1
	add_child(marker)
	_place_marker()
	return self


func _place_marker() -> void:
	marker.position = Vector2(0, ground_y + sprite.texture.get_height() - 2 - position.y)


func _set_state(s: String) -> void:
	state = s
	state_at = level.now


func _physics_process(delta: float) -> void:
	if level == null:
		return
	var t: float = level.now - state_at
	match state:
		"IDLE":
			var p: Player = level.player
			if not p.dead and absf(p.position.x - position.x) < TRIGGER_DX and p.position.y > position.y and p.position.y - position.y < 12 * C.TILE:
				_set_state("WARNING")
				AudioManager.play("block_warn")
				level.effects.poof(position.x, position.y + sprite.texture.get_height(), 4)
		"WARNING":
			var u := t / WARN_MS
			sprite.position.x = sin(t / 22.0) * 1.5
			marker.modulate.a = 0.25 + 0.55 * u
			_place_marker()
			if t >= WARN_MS:
				sprite.position.x = 0
				vy = 0
				_set_state("FALLING")
				hit.set_deferred("monitorable", true)
		"FALLING":
			vy += GRAVITY * delta
			position.y = minf(position.y + vy * delta, ground_y)
			_place_marker()
			if position.y >= ground_y:
				_set_state("RESTING")
				hit.set_deferred("monitorable", false)
				body_shape.set_deferred("disabled", false)
				marker.modulate.a = 0.0
				level.effects.poof(position.x, ground_y + sprite.texture.get_height(), 8)
				level.camera.shake(90, 0.003)
				AudioManager.play("block_land")
		"RESTING":
			if t >= REST_MS:
				_set_state("RESET")
				body_shape.set_deferred("disabled", true)
				var tw := sprite.create_tween()
				tw.tween_property(sprite, "modulate:a", 0.0, RESET_MS / 2000.0)
		"RESET":
			if t >= RESET_MS / 2.0 and position.y != top_y:
				position.y = top_y
				_place_marker()
				var tw := sprite.create_tween()
				tw.tween_property(sprite, "modulate:a", 1.0, RESET_MS / 2000.0)
			if t >= RESET_MS + 600:
				_set_state("IDLE")


func is_falling() -> bool:
	return state == "FALLING"


func on_player_contact() -> void:
	pass
