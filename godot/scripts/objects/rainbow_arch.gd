class_name RainbowArch
extends StaticBody2D
## Puente arcoíris del Mundo 6: une dos islas con un arco (o un tramo recto si h = 0).
## Dibujo: la banda del "puente arcoíris" de tilesets_world_6.png repetida a lo largo del arco.
## Colisión: una cinta fina que sigue la curva (polígono unidireccional): se atraviesa desde
## abajo y por debajo del arco queda el hueco libre que se ve, sin rectángulos grandes.

const SEGMENTS := 16
const THICK := 6.0

var points := PackedVector2Array()


## def: { x0, x1, y (teselas: superficie en los extremos), h (teselas de altura del arco) }
func setup(def: Dictionary, atlas: String) -> RainbowArch:
	z_index = C.Z_PLATFORM
	collision_layer = C.L_ONE_WAY
	collision_mask = 0
	var x0 := float(def.x0) * C.TILE
	var x1 := float(def.x1) * C.TILE
	var y := float(def.y) * C.TILE
	var h := float(def.get("h", 2)) * C.TILE
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		points.append(Vector2(lerpf(x0, x1, t), y - sin(PI * t) * h))
	var ribbon := PackedVector2Array(points)
	for i in range(points.size() - 1, -1, -1):
		ribbon.append(points[i] + Vector2(0, THICK))
	var poly := CollisionPolygon2D.new()
	poly.polygon = ribbon
	poly.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	poly.one_way_collision = true
	poly.one_way_collision_margin = 6.0
	add_child(poly)
	var band := Line2D.new()
	band.texture = ImageTexture.create_from_image(Assets.frame(atlas, "rainbow_band_w6").get_image())
	band.texture_mode = Line2D.LINE_TEXTURE_TILE
	band.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	band.width = band.texture.get_height()
	band.joint_mode = Line2D.LINE_JOINT_ROUND
	var off := Vector2(0, band.width / 2.0 - 1.0)
	var shifted := PackedVector2Array()
	for p in points:
		shifted.append(p + off)
	band.points = shifted
	add_child(band)
	# nubecitas en los apoyos
	for p in [points[0], points[points.size() - 1]]:
		var puff := Sprite2D.new()
		puff.texture = Assets.frame(atlas, "cloud_s")
		puff.position = p + Vector2(0, 8)
		puff.z_index = 1
		add_child(puff)
	return self


## Altura de la superficie del arco en una x (para pruebas y colocación).
func surface_at(x: float) -> float:
	for i in points.size() - 1:
		if x >= points[i].x and x <= points[i + 1].x:
			var t := (x - points[i].x) / (points[i + 1].x - points[i].x)
			return lerpf(points[i].y, points[i + 1].y, t)
	return INF


func on_player_contact() -> void:
	pass
