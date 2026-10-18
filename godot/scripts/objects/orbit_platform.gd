class_name OrbitPlatform
extends MovingPlatform
## Luna creciente en órbita (Mundo 5): recorre una elipse alrededor de un centro, formando una
## ruta curva. Hereda de MovingPlatform para que el nivel (y las herramientas) la traten igual:
## `start` y `delta_px` describen el tramo horizontal que recorre.

var center := Vector2.ZERO
var radius := Vector2(32, 16)
var direction := 1.0


## def: { x, y (teselas, superficie en el centro de la órbita), rx, ry (teselas), duration, delay (ms), dir (1 | -1), frame, top }
func setup(def: Dictionary, atlas: String) -> MovingPlatform:
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(atlas, def.frame)
	add_child(spr)
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	sync_to_physics = true
	position.x = float(def.x) * C.TILE
	CloudPlatform.add_cloud_shape(self, spr, spr.texture.get_size(), float(def.y) * C.TILE, float(def.get("top", 3)))
	center = position
	radius = Vector2(float(def.get("rx", 2)), float(def.get("ry", 1))) * C.TILE
	duration = float(def.get("duration", 4000))
	phase = float(def.get("delay", 0)) / duration
	direction = float(def.get("dir", 1))
	start = center - Vector2(radius.x, 0)
	delta_px = Vector2(radius.x * 2.0, 0)
	position = target_at(0.0)
	return self


func target_at(ms: float) -> Vector2:
	var a := (ms / duration + phase) * TAU * direction
	return center + Vector2(cos(a) * radius.x, sin(a) * radius.y)
