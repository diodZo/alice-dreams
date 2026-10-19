class_name TrainCar
extends MovingPlatform
## Vagón (o locomotora) de un TrainLine del Mundo 6. Es una plataforma móvil más: hereda de
## MovingPlatform (AnimatableBody2D con sync_to_physics) para que Godot traslade a Alice y
## para que el nivel y las herramientas la traten igual. El movimiento lo calcula su TrainLine
## (una vez por fotograma de física); `start` y `delta_px` describen el tramo que recorre.
## La franja pisable es el techo del vagón; nunca gira, también en las pendientes.

## Altura del techo pisable sobre el carril, igual en todas las piezas: así se puede andar de
## un vagón a otro (y hasta la cabina de la locomotora) sin escalones ni huecos donde caerse.
const SURFACE := 20.0

var line: TrainLine
var sprite: Sprite2D
var width := 32.0
var height := 24.0
var smoke_at := 0.0
var top := 0.0


func setup_car(owner_line: TrainLine, frame: String, index: int) -> TrainCar:
	line = owner_line
	sprite = Sprite2D.new()
	sprite.texture = Assets.frame(line.atlas, frame)
	add_child(sprite)
	width = sprite.texture.get_width()
	height = sprite.texture.get_height()
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	sync_to_physics = true
	top = height - SURFACE
	var cs := CloudPlatform.add_cloud_shape(self, sprite, sprite.texture.get_size(), 0.0, top)
	# franja a lo ancho de todo el vagón: entre vagones sólo queda la junta de CAR_GAP
	(cs.shape as RectangleShape2D).size.x = width
	cs.position.x = -round(width / 2.0) + width / 2.0
	position = Vector2.ZERO
	duration = 1000.0
	set_meta("loco", index == 0)
	line.add_child(self)
	return self


## Coloca el vagón con las ruedas sobre el punto del carril.
func place(rail: Vector2) -> void:
	position = Vector2(rail.x, rail.y - height + 1)


func step(delta_ms: float) -> void:
	line.tick(delta_ms)
	# el tramo recorrido (para el piloto automático y las pruebas)
	var a := line.rail_point(line.s_min() - line.offsets[get_index_in_line()])
	var b := line.rail_point(line.s_max() - line.offsets[get_index_in_line()])
	start = Vector2(minf(a.x, b.x), minf(a.y, b.y) - height + 1)
	delta_px = Vector2(absf(b.x - a.x), absf(b.y - a.y))
	# humo de juguete de la locomotora mientras avanza
	if get_meta("loco") and absf(line.velocity_x) > 5 and line.level.now >= smoke_at:
		smoke_at = line.level.now + 420.0
		_puff()


## Altura (y) del techo pisable.
func surface_y() -> float:
	return position.y + top


func get_index_in_line() -> int:
	return line.cars.find(self)


func _puff() -> void:
	var p := Sprite2D.new()
	p.texture = Assets.frame("w6_fx", "smoke_s")
	p.position = position + Vector2(width * 0.3 * signf(line.dir), -2)
	p.z_index = C.Z_PLATFORM + 1
	line.level.fx_root.add_child(p)
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "position:y", p.position.y - 14, 0.9)
	tw.tween_property(p, "scale", Vector2(1.6, 1.6), 0.9)
	tw.tween_property(p, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(p.queue_free)


func target_at(_ms: float) -> Vector2:
	return position


func activate() -> void:
	pass
