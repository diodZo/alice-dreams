class_name SwingPlatform
extends MovingPlatform
## Asiento colgado de una cuerda de lana: péndulo bajo el punto de anclaje. Sube un poco en
## los extremos del vaivén y transporta a la protagonista como las demás plataformas móviles.
## Hereda de MovingPlatform para que el nivel (y las herramientas) lo traten igual:
## `start` y `delta_px` describen el tramo horizontal que recorre el asiento.

var pivot := Vector2.ZERO
var length := 64.0
var amplitude := 0.55
## Posición del cuerpo con la cuerda en vertical (punto más bajo del arco).
var rest := Vector2.ZERO
var rope: Line2D


## def: { x, y (teselas, punto de anclaje), length (px), amplitude (rad), duration (ms), delay (ms), frame }
func setup(def: Dictionary, atlas: String) -> MovingPlatform:
	pivot = Vector2(float(def.x) * C.TILE, float(def.y) * C.TILE)
	length = float(def.get("length", 64))
	amplitude = float(def.get("amplitude", 0.55))
	duration = float(def.get("duration", 2800))
	phase = float(def.get("delay", 0)) / duration
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(atlas, def.get("frame", "button_blue"))
	add_child(spr)
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	sync_to_physics = true
	position.x = pivot.x
	CloudPlatform.add_cloud_shape(self, spr, spr.texture.get_size(), pivot.y + length, float(def.get("top", 3)))
	rest = position
	var reach := sin(amplitude) * length
	start = rest - Vector2(reach, 0)
	delta_px = Vector2(reach * 2.0, 0)
	rope = Line2D.new()
	rope.width = 2.0
	rope.default_color = C.rgb(0xd46fb0)
	rope.z_index = -1
	rope.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	add_child(rope)
	var knot := Sprite2D.new()
	knot.texture = Assets.frame(atlas, def.get("knot", "yarn_ball_pink"))
	knot.scale = Vector2(0.45, 0.45)
	knot.z_index = 1
	rope.add_child(knot)
	position = target_at(0.0)
	_update_rope()
	return self


## Ángulo de la cuerda en el instante ms (0 = vertical).
func angle_at(ms: float) -> float:
	return sin((ms / duration + phase) * TAU) * amplitude


func target_at(ms: float) -> Vector2:
	var a := angle_at(ms)
	return rest + Vector2(sin(a) * length, -(1.0 - cos(a)) * length)


func step(delta_ms: float) -> void:
	super(delta_ms)
	_update_rope()


func _update_rope() -> void:
	# la cuerda va del anclaje (fijo en el mundo) al centro superior del asiento
	var local_pivot := pivot - position
	rope.points = PackedVector2Array([local_pivot, Vector2(0, 2)])
	rope.get_child(0).position = local_pivot
