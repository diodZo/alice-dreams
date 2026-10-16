class_name Projectile
extends CharacterBody2D
## Proyectil genérico (armas de la protagonista, enemigos y jefe). Port de weapons/Projectile.js.
## - El cuerpo (CharacterBody2D) choca sólo con el terreno: rebote de las pulgas, fin del
##   resto de proyectiles. La ráfaga de viento se desliza sin desaparecer.
## - El área "Hitbox" detecta impactos: los de la protagonista buscan enemigos y al jefe;
##   los de enemigos y jefe los detecta el sensor de la protagonista.
## Un único código de colisiones para todas las armas: lo que cambia es la configuración.

signal expired

@onready var sprite: Sprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox

var level: Node
var cfg: Dictionary = {}
var active := false
var owner_kind := "player"
var kind := ""
var damage := 1
var weapon: WeaponDef = null
var paint_color := Color.WHITE
## Color del proyectil para el efecto de impacto (tintTopLeft en Phaser).
var tint_color := Color.WHITE
var hit_targets := {}
var bounces_left := 0
var born_at := 0.0
var die_at := 0.0
var base_vy := 0.0
var gravity := 0.0


## cfg: { x, y, vx, vy, gravity, texture, frame, lifespan, damage, owner, kind, body, scale,
##        alpha, tint, spin, wobble, bounces, bounce_velocity, rotate }
func fire(owner_level: Node, config: Dictionary) -> Projectile:
	level = owner_level
	cfg = config
	return self


func _ready() -> void:
	z_index = C.Z_PROJECTILE
	collision_layer = 0
	collision_mask = C.L_WORLD
	var c := cfg
	position = Vector2(c.x, c.y)
	owner_kind = c.get("owner", "player")
	kind = c.get("kind", "")
	damage = int(c.get("damage", 1))
	var tex_name: String = c.get("texture", "fx")
	if tex_name == "fx":
		sprite.texture = Assets.frame("fx", c.get("frame", ""))
	else:
		sprite.texture = Assets.generated(tex_name)
	var s: float = c.get("scale", 1.0)
	sprite.scale = Vector2(s, s)
	var tint: Variant = c.get("tint")
	tint_color = tint if tint is Color else Color.WHITE
	sprite.modulate = Color(tint_color, float(c.get("alpha", 1.0)))
	velocity = Vector2(c.get("vx", 0.0), c.get("vy", 0.0))
	sprite.flip_h = velocity.x < 0
	var size: float = c.get("body", minf(sprite.texture.get_width(), sprite.texture.get_height()))
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size, size)
	$Body.shape = shape
	$Hitbox/Shape.shape = shape
	gravity = float(c.get("gravity", 0.0))
	bounces_left = int(c.get("bounces", 0))
	born_at = level.now
	die_at = born_at + float(c.get("lifespan", 1500))
	base_vy = velocity.y
	if owner_kind == "player":
		hitbox.collision_layer = C.L_PLAYER_PROJ
		hitbox.collision_mask = C.L_ENEMY_HITBOX | C.L_BOSS
	else:
		hitbox.collision_layer = C.L_ENEMY_PROJ
		hitbox.collision_mask = 0
		hitbox.monitoring = false
	hitbox.set_meta("kind", "projectile")
	hitbox.set_meta("entity", self)
	active = true


func _physics_process(delta: float) -> void:
	if not active:
		return
	var time: float = level.now
	if time >= die_at:
		expire()
		return
	var spin: float = cfg.get("spin", 0.0)
	if spin != 0:
		sprite.rotation_degrees += spin * delta * (signf(velocity.x) if velocity.x != 0 else 1.0)
	var wobble: float = cfg.get("wobble", 0.0)
	if wobble != 0:
		velocity.y = base_vy + sin((time - born_at) / 90.0) * wobble * 10.0
	if cfg.get("rotate", false):
		sprite.rotation = atan2(velocity.y, velocity.x)
	if gravity != 0:
		velocity.y += gravity * delta
	var col := move_and_collide(velocity * delta)
	if col != null:
		if _hit_world(col):
			return
	# fuera del mundo
	if position.y > level.world_h + 80 + 32 or position.x < -64 or position.x > level.world_w + 64:
		kill()
		return
	if owner_kind == "player":
		_check_hits()


## Choque con el escenario. Devuelve true si el proyectil desaparece.
func _hit_world(col: KinematicCollision2D) -> bool:
	var n := col.get_normal()
	if kind == "wind":
		# la ráfaga se detiene contra la pared pero no desaparece
		velocity = velocity.slide(n)
		return false
	if bounces_left > 0 and n.y < -0.5:
		bounces_left -= 1
		velocity.y = -absf(float(cfg.get("bounce_velocity", 140)))
		return false
	expire()
	return true


func _check_hits() -> void:
	for area in hitbox.get_overlapping_areas():
		if not active:
			return
		var target: Variant = area.get_meta("entity", null)
		if target == null or not is_instance_valid(target):
			continue
		match area.get_meta("kind", ""):
			"enemy":
				if target.is_alive() and target.hit_by(self):
					expire()
			"boss":
				if target.hit_by(self):
					expire()


## Fin natural (tiempo o impacto): avisa al nivel para el efecto visual.
func expire() -> void:
	if not active:
		return
	level.on_projectile_expired(self)
	kill()


func kill() -> void:
	if not active:
		return
	active = false
	expired.emit()
	hitbox.set_deferred("monitorable", false)
	queue_free()
