class_name RailLever
extends Area2D
## Palanca ferroviaria del Mundo 6: al tocarla (o al dispararle) cambia el desvío de su tren.
##  - El dibujo de la palanca se inclina al otro lado y la luz cambia de color.
##  - Suena la palanca.
##  - El tren toma el nuevo ramal en su siguiente punto seguro (TrainLine.request_branch).
## Se acciona al entrar en contacto: quedarse encima no la vuelve a mover.

signal toggled(branch: int)

var level: Node
var sprite: Sprite2D
var light: Sprite2D
var train: TrainLine
var state := 0
var _last_touch := -10
var ready_at := 0.0


## def: { x, y (teselas: superficie), train (índice) }
func setup(owner_level: Node, def: Dictionary, atlas: String, target: TrainLine) -> RailLever:
	level = owner_level
	train = target
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, "rail_lever")
	Anim.set_origin(sprite, sprite.texture.get_size(), 0.5, 1.0)
	add_child(sprite)
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	light = Sprite2D.new()
	light.texture = Assets.generated("glow")
	light.position = Vector2(0, -sprite.texture.get_height() - 4)
	light.scale = Vector2(0.8, 0.8)
	add_child(light)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(sprite.texture.get_width(), sprite.texture.get_height())
	cs.shape = shape
	cs.position = Vector2(0, -shape.size.y / 2.0)
	add_child(cs)
	Trigger.configure(self, "lever")
	# también reacciona a los disparos de Alice
	var shoot := Area2D.new()
	var scs := CollisionShape2D.new()
	scs.shape = shape
	scs.position = cs.position
	shoot.add_child(scs)
	shoot.collision_layer = C.L_ENEMY_HITBOX
	shoot.collision_mask = 0
	shoot.monitoring = false
	shoot.set_meta("kind", "shootable")
	shoot.set_meta("entity", self)
	add_child(shoot)
	z_index = C.Z_PICKUP
	state = train.branch if train != null else 0
	_show()
	return self


## Contacto con Alice en este fotograma (sólo actúa al empezar el contacto).
func touch() -> void:
	var f := Engine.get_physics_frames()
	var fresh := f - _last_touch > 2
	_last_touch = f
	if fresh:
		toggle()


func hit_by(_projectile: Projectile) -> bool:
	toggle()
	return true


func toggle() -> void:
	if level.now < ready_at:
		return
	ready_at = level.now + 400
	state = 1 - state
	if train != null:
		state = train.request_branch(state)
	_show()
	AudioManager.play("lever")
	level.effects.sparkle(position.x, position.y - 14, 6)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.15, 0.9), 0.06)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.08)
	toggled.emit(state)
	GameState.show_toast("¡Desvío cambiado!" if state == 1 else "Desvío en su sitio")


func _show() -> void:
	sprite.flip_h = state == 1
	light.modulate = Color(C.rgb(0x70d7b5) if state == 1 else C.rgb(0xffd85c), 0.85)


## La protagonista toca el objeto (lo llama Level._process_overlaps cada fotograma).
func on_player_overlap(_level: Node, _player: Player, _delta: float) -> void:
	touch()
