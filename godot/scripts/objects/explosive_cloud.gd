class_name ExplosiveCloud
extends Area2D
## Nube explosiva (Mundo 5): flota en su sitio. Al tocarla se hincha y destella (aviso de
## FUSE_MS) y estalla en un pequeño destello de luz y nube; si Alice sigue cerca le quita un
## corazón. Un disparo de cualquier arma la hace estallar al momento (desde lejos es seguro).
## Se vuelve a formar al cabo de REFORM_MS. Sin violencia: sólo luz, nube y estrellitas.
## Área "shootable": la detectan los proyectiles de Alice y su sensor.

const FUSE_MS := 650.0
const REFORM_MS := 3200.0
const RADIUS := 30.0

var level: Node
var atlas := ""
var sprite: Sprite2D
var state := "idle"
var base_y := 0.0
var bob := 0.0


## def: { x, y (teselas, centro) }
func setup(owner_level: Node, def: Dictionary, atlas_name: String) -> ExplosiveCloud:
	level = owner_level
	atlas = atlas_name
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE + C.TILE / 2.0)
	base_y = position.y
	bob = randf() * TAU
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, "boom_cloud")
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11
	cs.shape = circle
	add_child(cs)
	collision_layer = C.L_ENEMY_HITBOX
	collision_mask = 0
	monitoring = false
	monitorable = true
	set_meta("kind", "shootable")
	set_meta("entity", self)
	z_index = C.Z_ENEMY
	return self


func _physics_process(delta: float) -> void:
	if state == "idle":
		bob += delta * 2.0
		position.y = base_y + sin(bob) * 2.0


## Contacto con Alice: empieza la mecha (sólo desde el reposo).
func touch(_player: Node = null) -> void:
	if state != "idle":
		return
	state = "fuse"
	sprite.texture = Assets.frame(atlas, "boom_cloud_big")
	var tw := sprite.create_tween()
	for i in 3:
		tw.tween_property(sprite, "modulate", C.rgb(0xfff3a0), FUSE_MS / 6000.0)
		tw.tween_property(sprite, "modulate", Color.WHITE, FUSE_MS / 6000.0)
	level.effects.glow_flash(position, C.YELLOW, 1, 3, FUSE_MS, 0.7, 0)
	var ref: WeakRef = weakref(self)
	level.after(FUSE_MS, func():
		var c: ExplosiveCloud = ref.get_ref()
		if c != null:
			c.explode())


## Disparo de Alice: estalla al momento.
func hit_by(_projectile: Node) -> bool:
	if state == "gone":
		return false
	explode()
	return true


func is_ready() -> bool:
	return state == "idle"


func explode() -> void:
	if state == "gone":
		return
	state = "gone"
	set_deferred("monitorable", false)
	AudioManager.play("cloud_boom")
	level.effects.poof(position.x, position.y, 12)
	level.effects.sparkle(position.x, position.y, 10)
	level.effects.glow_flash(position, C.CREAM, 1, 4, 320, 0.9, 1)
	var burst := Sprite2D.new()
	burst.texture = Assets.frame(atlas, "boom_burst")
	burst.position = position
	level.fx_root.add_child(burst)
	var bt := burst.create_tween().set_parallel()
	bt.tween_property(burst, "scale", Vector2(1.6, 1.6), 0.3)
	bt.tween_property(burst, "modulate:a", 0.0, 0.35)
	bt.chain().tween_callback(burst.queue_free)
	var p: Player = level.player
	if p != null and not p.dead and (p.position + Vector2(0, -16)).distance_to(position) < RADIUS:
		p.hurt(position.x)
	sprite.visible = false
	var ref: WeakRef = weakref(self)
	level.after(REFORM_MS, func():
		var c: ExplosiveCloud = ref.get_ref()
		if c != null:
			c.reform())


func reform() -> void:
	state = "idle"
	sprite.texture = Assets.frame(atlas, "boom_cloud")
	sprite.visible = true
	sprite.modulate = Color(1, 1, 1, 0)
	sprite.scale = Vector2(0.4, 0.4)
	var tw := sprite.create_tween().set_parallel()
	tw.tween_property(sprite, "modulate:a", 1.0, 0.4)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.4)
	set_deferred("monitorable", true)
