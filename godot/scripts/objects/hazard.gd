class_name Hazard
extends Area2D
## Obstáculo con patrón predecible: una burbuja con pinchos que sube y baja (o va de lado
## a lado) siempre al mismo ritmo. Daña al tocarla (port de entities/Hazards.js).


## def: { x, y (teselas), frame, dx, dy (teselas), duration, delay (ms) }
## Mundo 7: shape "spikes" (plataforma con pinchos de caramelo): fija, apoyada en el suelo
## (y = fila de la superficie) y con colisión rectangular sólo en la franja de los pinchos
## (insetX, insetTop: márgenes en px que la estrechan respecto al dibujo).
func setup(def: Dictionary, atlas: String) -> Hazard:
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(atlas, def.get("frame", "spiky_bubble"))
	add_child(spr)
	z_index = C.Z_ENEMY
	position = Vector2(float(def.x) * C.TILE + C.TILE / 2.0, float(def.y) * C.TILE + C.TILE / 2.0)
	var size := spr.texture.get_size()
	if def.get("shape", "") == "spikes":
		position.y = float(def.y) * C.TILE
		Anim.set_origin(spr, size, 0.5, 1.0)
		# franja de los pinchos; insetX / insetTop (px) la hacen más pequeña que el dibujo para
		# dar margen al saltar por encima (tartas del Mundo 7)
		var inset_x := float(def.get("insetX", 3))
		var inset_top := float(def.get("insetTop", 1))
		var rect := RectangleShape2D.new()
		rect.size = Vector2(size.x - 2.0 * inset_x, size.y * 0.45 - (inset_top - 1.0))
		var rs := CollisionShape2D.new()
		rs.shape = rect
		rs.position = Vector2(0, -size.y + inset_top + rect.size.y / 2.0)
		add_child(rs)
		Trigger.configure(self, "hazard")
		return self
	var circle := CircleShape2D.new()
	circle.radius = minf(size.x, size.y) * 0.36
	var cs := CollisionShape2D.new()
	cs.shape = circle
	add_child(cs)
	Trigger.configure(self, "hazard")
	var to := position + Vector2(float(def.get("dx", 0)), float(def.get("dy", 0))) * C.TILE
	var dur := float(def.get("duration", 1500)) / 1000.0
	var delay := float(def.get("delay", 0)) / 1000.0
	var from := position
	var start := func():
		var tw := create_tween().set_loops()
		tw.tween_property(self, "position", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(self, "position", from, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if delay > 0:
		create_tween().tween_interval(delay).finished.connect(start)
	else:
		start.call()
	if def.get("spin", false):
		# hélice giratoria (Mundo 6): se estrecha y cambia de lado, como un giro visto de lado
		var sp := spr.create_tween().set_loops()
		sp.tween_property(spr, "scale:x", 0.2, 0.09)
		sp.tween_callback(func(): spr.flip_h = not spr.flip_h)
		sp.tween_property(spr, "scale:x", 1.0, 0.09)
		return self
	spr.rotation_degrees = -8
	var wobble := spr.create_tween().set_loops()
	wobble.tween_property(spr, "rotation_degrees", 8.0, 0.6)
	wobble.tween_property(spr, "rotation_degrees", -8.0, 0.6)
	return self
