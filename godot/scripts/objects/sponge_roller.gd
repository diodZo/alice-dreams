class_name SpongeRoller
extends Area2D
## Rodillo de esponja del Mundo 4: va y viene a velocidad constante con una pausa breve en cada
## extremo (patrón fácil de leer). No hace daño: empuja a la protagonista con un pequeño salto.
## Horizontal (axis "x") o vertical (axis "y").

const PAUSE_MS := 450.0

var level: Node
var sprite: Sprite2D
var a := 0.0
var b := 0.0
var speed := 50.0
var dir := 1
var axis := "x"
var paused_until := 0.0
var push_ready_at := 0.0


## def: { x, y (teselas, superficie), range: [desde, hasta] (teselas), speed (px/s), frame, axis }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> SpongeRoller:
	level = owner_level
	axis = def.get("axis", "x")
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(atlas, def.get("frame", "roller_a"))
	var size := sprite.texture.get_size()
	sprite.position.y = -size.y / 2.0
	add_child(sprite)
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE)
	if axis == "x":
		a = float(def.range[0]) * C.TILE + 8
		b = float(def.range[1]) * C.TILE + 8
	else:
		a = float(def.range[0]) * C.TILE
		b = float(def.range[1]) * C.TILE
	speed = float(def.get("speed", 50))
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x - 8, size.y - 4)
	cs.shape = shape
	cs.position = sprite.position
	add_child(cs)
	Trigger.configure(self, "roller")
	z_index = C.Z_ENEMY
	return self


func _physics_process(delta: float) -> void:
	if level == null or level.now < paused_until:
		return
	var p := position.x if axis == "x" else position.y
	p += dir * speed * delta
	if p >= maxf(a, b) or p <= minf(a, b):
		p = clampf(p, minf(a, b), maxf(a, b))
		dir *= -1
		paused_until = level.now + PAUSE_MS
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "scale", Vector2(0.9, 1.1), 0.1)
		tw.tween_property(sprite, "scale", Vector2.ONE, 0.12)
	if axis == "x":
		position.x = p
		sprite.rotation = 0
	else:
		position.y = p
	# gira la textura de la esponja sobre sí misma: un vaivén suave que indica el avance
	sprite.skew = sin(level.now / 140.0) * 0.08 * dir


## Empuja a la protagonista hacia el lado contrario (lo llama el nivel al tocarla).
func push(player: Player) -> void:
	if level.now < push_ready_at:
		return
	push_ready_at = level.now + 350
	var side := signf(player.position.x - position.x)
	if side == 0:
		side = float(dir)
	player.push(side * 360.0)
	if player.grounded:
		player.velocity.y = -150
	AudioManager.play("bounce")
	level.effects.poof(player.position.x - side * 6, player.position.y - 12, 6)
