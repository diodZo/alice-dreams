class_name ParallaxBackground2
extends Node2D
## Fondo multicapa con parallax (port de systems/ParallaxBackground.js). Las capas no tienen
## colisión. De lejos a cerca: cielo, estrellas, luna, castillo, islas flotantes, banco de
## nubes lejano, nubes a la deriva y banco de nubes cercano.
## Cada capa es un Parallax2D cuyo scroll_scale equivale al scrollFactor de Phaser.

var camera: CameraRig
var world_height := 0.0
var clouds_far: TiledSprite
var clouds_near: TiledSprite
var base_far_y := 0.0
var base_near_y := 0.0
var drifters: Array = []


func build(cam: CameraRig, atlas: String, objects_atlas: String, world_width: float, world_h: float, show_castle := true, seed_key := "1") -> void:
	camera = cam
	world_height = world_h
	var rnd := RandomNumberGenerator.new()
	rnd.seed = hash(seed_key)
	var fixed := _layer(Vector2.ZERO, 0)

	var sky := Sprite2D.new()
	sky.texture = Assets.image("sky")
	sky.centered = false
	sky.scale = Vector2(C.GAME_W, C.GAME_H) / sky.texture.get_size()
	fixed.add_child(sky)

	# estrellas titilantes del cielo
	var stars := _layer(Vector2.ZERO, 1)
	for i in 26:
		var s := Sprite2D.new()
		s.texture = Assets.frame("fx", "sparkle")
		s.position = Vector2(rnd.randi_range(4, C.GAME_W - 4), rnd.randi_range(4, 120))
		var sc := rnd.randf_range(0.3, 0.6)
		s.scale = Vector2(sc, sc)
		var a := rnd.randf_range(0.4, 1.0)
		s.modulate.a = a
		stars.add_child(s)
		var d := rnd.randi_range(600, 1600) / 1000.0
		var twinkle := func():
			var tw := s.create_tween().set_loops()
			tw.tween_property(s, "modulate:a", 0.15, d)
			tw.tween_property(s, "modulate:a", a, d)
		s.create_tween().tween_interval(rnd.randi_range(0, 1500) / 1000.0 + 0.001).finished.connect(twinkle)

	# objetos lejanos: el parallax lo resuelve scroll_scale
	var moon_layer := _layer(Vector2(0.02, 0.05), 2)
	var moon := Sprite2D.new()
	moon.texture = Assets.frame(atlas, "moon")
	moon.position = Vector2(C.GAME_W - 70, 44)
	moon.rotation_degrees = -3
	moon_layer.add_child(moon)
	var mt := moon.create_tween().set_loops()
	mt.tween_property(moon, "rotation_degrees", 3.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mt.tween_property(moon, "rotation_degrees", -3.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if show_castle:
		var castle_layer := _layer(Vector2(0.05, 0.08), 3)
		var castle := Sprite2D.new()
		castle.texture = Assets.frame(atlas, "castle")
		castle.position = Vector2(C.GAME_W * 0.62, 118)
		castle.modulate.a = 0.95
		castle_layer.add_child(castle)

	# islas flotantes a media distancia (se repiten a lo largo del recorrido)
	var islands := ["island_big", "island_wide", "island_eggs", "island_small_a", "island_small_b", "island_tiny"]
	var layers := [
		{"fx": 0.15, "depth": 4, "step": 190, "yMin": 50, "yMax": 120, "alpha": 0.75, "scale": 0.75},
		{"fx": 0.3, "depth": 6, "step": 260, "yMin": 70, "yMax": 150, "alpha": 1.0, "scale": 1.0},
	]
	for L in layers:
		var layer := _layer(Vector2(L.fx, L.fx * 0.4), L.depth)
		var span: float = world_width * L.fx + C.GAME_W + 200
		var x := -60.0
		while x < span:
			var img := Sprite2D.new()
			img.texture = Assets.frame(atlas, islands[rnd.randi() % islands.size()])
			img.position = Vector2(x, rnd.randi_range(L.yMin, L.yMax))
			img.modulate.a = L.alpha
			img.scale = Vector2(L.scale, L.scale)
			layer.add_child(img)
			var y := img.position.y
			var d := rnd.randi_range(1600, 2600) / 1000.0
			var tw := img.create_tween().set_loops()
			tw.tween_property(img, "position:y", y + 3, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(img, "position:y", y, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			x += L.step + rnd.randi_range(-40, 40)

	var far_tex := Assets.image("clouds_far")
	clouds_far = TiledSprite.new().setup(far_tex, Vector2(C.GAME_W, far_tex.get_height()))
	clouds_far.position = Vector2(0, C.GAME_H - far_tex.get_height() + 20)
	_layer(Vector2.ZERO, 8).add_child(clouds_far)

	# nubes sueltas que se desplazan solas
	var drift_layer := _layer(Vector2.ZERO, 9)
	for i in 5:
		var c := Sprite2D.new()
		c.texture = Assets.frame(objects_atlas, ["cloud_small", "cloud_puff", "cloud_med"][rnd.randi() % 3])
		c.position = Vector2(rnd.randi_range(0, C.GAME_W), rnd.randi_range(30, 110))
		c.modulate.a = 0.7
		c.scale = Vector2(0.6, 0.6)
		drift_layer.add_child(c)
		drifters.append({"obj": c, "speed": rnd.randf_range(4, 10)})

	var near_tex := Assets.image("clouds_near")
	clouds_near = TiledSprite.new().setup(near_tex, Vector2(C.GAME_W, near_tex.get_height()))
	clouds_near.position = Vector2(0, C.GAME_H - near_tex.get_height() + 30)
	_layer(Vector2.ZERO, 10).add_child(clouds_near)
	base_far_y = clouds_far.position.y
	base_near_y = clouds_near.position.y


func _layer(scroll_factor: Vector2, depth: int) -> Parallax2D:
	var p := Parallax2D.new()
	p.scroll_scale = scroll_factor
	p.z_index = C.Z_BG + depth
	add_child(p)
	return p


func update(delta_ms: float) -> void:
	var s := camera.scroll.round()
	var max_sy := maxf(1.0, world_height - C.GAME_H)
	var vy := s.y / max_sy # 0 arriba .. 1 abajo
	clouds_far.tile_offset = Vector2(s.x * 0.4, 0)
	clouds_near.tile_offset = Vector2(s.x * 0.65, 0)
	clouds_far.position.y = base_far_y + (1 - vy) * 18
	clouds_near.position.y = base_near_y + (1 - vy) * 30
	var dt := delta_ms / 1000.0
	for d in drifters:
		d.obj.position.x -= d.speed * dt
		if d.obj.position.x < -40:
			d.obj.position.x = C.GAME_W + 40
