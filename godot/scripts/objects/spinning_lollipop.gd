class_name SpinningLollipop
extends Node2D
## Piruleta giratoria del Mundo 7: una piruleta gigante gira despacio alrededor de la base de su
## palo, como la aguja de un reloj (o se balancea como un péndulo con `swing`). Sólo hace daño la
## cabeza de caramelo: el círculo de colisión va dentro del brazo que gira y sigue exactamente a
## la cabeza; el palo no daña. Velocidad constante: el patrón es fácil de leer y de esquivar.

var arm: Node2D
var head: Area2D
var speed := 70.0
var swing := 0.0
var t := 0.0
var base_angle := 0.0


## def: { x, y (tesela de la base del palo: borde inferior de la celda), speed (grados/s; el signo
##        da el sentido), angle (grados al empezar), swing (amplitud en grados: péndulo), frame }
func setup(def: Dictionary, atlas: String) -> SpinningLollipop:
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE)
	z_index = C.Z_ENEMY
	speed = float(def.get("speed", 70))
	swing = float(def.get("swing", 0))
	base_angle = float(def.get("angle", 0))
	arm = Node2D.new()
	add_child(arm)
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(atlas, def.get("frame", "lolli_spin"))
	var size := spr.texture.get_size()
	Anim.set_origin(spr, size, 0.5, 1.0)
	arm.add_child(spr)
	# la cabeza es el círculo de la parte superior del dibujo (tan ancha como la piruleta)
	var r := size.x / 2.0
	head = Area2D.new()
	head.position = Vector2(0, -size.y + r)
	var circle := CircleShape2D.new()
	circle.radius = r * 0.82
	var cs := CollisionShape2D.new()
	cs.shape = circle
	head.add_child(cs)
	arm.add_child(head)
	# entity = la piruleta: el empuje del golpe se calcula desde su base
	Trigger.configure(head, "hazard", self)
	# base: un caramelito fijo que tapa el eje de giro
	var hub := Sprite2D.new()
	hub.texture = Assets.generated("glow")
	hub.modulate = Color(C.rgb(0xff8fc8), 0.8)
	hub.scale = Vector2(0.45, 0.45)
	add_child(hub)
	_apply()
	return self


func _physics_process(delta: float) -> void:
	t += delta
	_apply()


func _apply() -> void:
	if swing > 0:
		arm.rotation_degrees = base_angle + sin(t * deg_to_rad(absf(speed))) * swing
	else:
		arm.rotation_degrees = base_angle + t * speed


## Posición de la cabeza en coordenadas del nivel (pruebas y depuración).
func head_position() -> Vector2:
	return head.global_position
