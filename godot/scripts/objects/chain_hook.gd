class_name ChainHook
extends Node2D
## Gancho en cadena del Mundo 8: un gancho (luna o estrella) colgado de una cadena que se
## balancea como un péndulo con un ritmo fijo (reloj del nivel). Sólo hace daño el gancho; la
## cadena es decorado. El empuje del golpe se calcula desde el propio gancho.

var level: Node
var arm: Node2D
var head: Area2D
var chain: Line2D
var length := 64.0
var swing := 50.0
var speed := 90.0
var base_angle := 0.0


## def: { x, y (tesela del anclaje: borde superior de la celda), length (px), swing (grados de
##        amplitud), speed (grados de fase por segundo), angle (desfase en grados), frame }
func setup(owner_level: Node, def: Dictionary, atlas: String) -> ChainHook:
	level = owner_level
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	z_index = C.Z_ENEMY
	length = float(def.get("length", 64))
	swing = float(def.get("swing", 50))
	speed = float(def.get("speed", 90))
	base_angle = float(def.get("angle", 0))
	arm = Node2D.new()
	add_child(arm)
	chain = Line2D.new()
	chain.width = 2.0
	chain.default_color = C.rgb(0x8a5a3a)
	chain.points = PackedVector2Array([Vector2.ZERO, Vector2(0, length)])
	arm.add_child(chain)
	# eslabones claros sobre la cadena
	for i in int(length / 8.0):
		var link := ColorRect.new()
		link.color = C.rgb(0xd09a5a)
		link.size = Vector2(2, 2)
		link.position = Vector2(-1, 4 + i * 8)
		arm.add_child(link)
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(atlas, def.get("frame", "hook_moon"))
	var size := spr.texture.get_size()
	Anim.set_origin(spr, size, 0.5, 0.0)
	spr.position = Vector2(0, length - size.y * 0.35)
	arm.add_child(spr)
	head = Area2D.new()
	head.position = Vector2(0, length + size.y * 0.3)
	var circle := CircleShape2D.new()
	circle.radius = minf(size.x, size.y) * 0.38
	var cs := CollisionShape2D.new()
	cs.shape = circle
	head.add_child(cs)
	arm.add_child(head)
	Trigger.configure(head, "hazard", head)
	var anchor := Sprite2D.new()
	anchor.texture = Assets.generated("glow")
	anchor.modulate = Color(C.rgb(0xffe18c), 0.7)
	anchor.scale = Vector2(0.35, 0.35)
	add_child(anchor)
	_apply(0.0)
	return self


func angle_at(ms: float) -> float:
	return base_angle + sin(ms / 1000.0 * deg_to_rad(speed) * 3.0) * swing


func _physics_process(_delta: float) -> void:
	if level != null:
		_apply(level.now)


func _apply(ms: float) -> void:
	arm.rotation_degrees = angle_at(ms)


## Posición del gancho en coordenadas del nivel (pruebas).
func head_position() -> Vector2:
	return head.global_position
