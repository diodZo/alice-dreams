class_name LevelBuilder
extends RefCounted
## Convierte los datos de un mundo (data/worlds/*.json) en nodos de Godot (port de
## systems/LevelBuilder.js): TileMapLayer de terreno con autotiling, plataformas, obstáculos,
## coleccionables y decoración. No contiene reglas de juego: las aplica Level.

var level: Node
var data: Dictionary
var cols := 0
var rows := 0
var layer: TileMapLayer
var tile_cols := 8
var grid: Array = []


func _init(owner_level: Node, level_data: Dictionary) -> void:
	level = owner_level
	data = level_data
	cols = int(data.widthTiles)
	rows = int(data.heightTiles)


## Crea todo el nivel bajo `root`. Devuelve un diccionario con los grupos de objetos.
func build(root: Node2D, touch_mode: bool, collected_stars: Array) -> Dictionary:
	var out := {}
	var atlas: String = data.objectsAtlas
	_check_frames(atlas)
	out.terrain = build_terrain()
	root.add_child(out.terrain)

	var platforms := Node2D.new()
	platforms.name = "Platforms"
	root.add_child(platforms)
	out.platforms = platforms
	for c in data.clouds:
		platforms.add_child(CloudPlatform.new().setup(c, atlas))
	for b in data.bridges:
		platforms.add_child(RainbowBridge.new().setup(b, atlas))
	# Mundo 2: puentes de reglas (rectos, inclinados, articulados, dibujados, temporales, activables)
	out.rulers = []
	for r in data.get("rulers", []):
		var rb := RulerBridge.new().setup(level, r, atlas)
		platforms.add_child(rb)
		out.rulers.append(rb)
	out.movers = []
	for m in data.movers:
		var p := MovingPlatform.new().setup(m, atlas)
		platforms.add_child(p)
		out.movers.append(p)
	out.crumbles = []
	for c in data.crumbles:
		var p := CrumblePlatform.new().setup(level, c, atlas)
		platforms.add_child(p)
		out.crumbles.append(p)

	var objects := Node2D.new()
	objects.name = "Objects"
	root.add_child(objects)
	out.objects = objects
	for p in data.pads:
		objects.add_child(BouncePad.new().setup(level, p, atlas))
	for h in data.hazards:
		objects.add_child(Hazard.new().setup(h, atlas))
	for w in data.winds:
		objects.add_child(WindZone.new().setup(level, w))
	# Mundo 2: pintura, lápices rodantes, borradores que rebotan, goteos, crayones e interruptores
	for p in data.get("paints", []):
		objects.add_child(PaintSurface.new().setup(p, atlas))
	for r in data.get("rollers", []):
		objects.add_child(RollingPencil.new().setup(level, r, atlas))
	for b in data.get("bouncers", []):
		objects.add_child(BouncingEraser.new().setup(level, b, atlas))
	for d in data.get("drips", []):
		objects.add_child(PaintDrip.new().setup(level, d, atlas))
	for m in data.get("magicCrayons", []):
		if not (m.color in GameState.get_v("magicCrayons", [])):
			objects.add_child(MagicCrayon.new().setup(level, m, atlas))
	for i in data.get("rulers", []).size():
		var r: Dictionary = data.rulers[i]
		if r.has("switch"):
			objects.add_child(BridgeSwitch.new().setup(r.switch, out.rulers[i], atlas))

	out.stars = []
	var stars_root := Node2D.new()
	stars_root.name = "Stars"
	root.add_child(stars_root)
	out.stars_root = stars_root
	for i in data.stars.size():
		var s: Dictionary = data.stars[i]
		var id := "%s:s%d" % [data.key, i]
		if id in collected_stars:
			continue
		var star := Star.new().setup(level, Vector2(float(s.x) * C.TILE + C.TILE / 2.0, float(s.y) * C.TILE + C.TILE / 2.0), {"id": id, "look": frame_of("star", "")})
		stars_root.add_child(star)
		out.stars.append(star)
	out.stars_total = data.stars.size()
	for p in data.pickups:
		objects.add_child(WeaponPickup.new().setup(level, p))
	out.signs = []
	for s in data.signs:
		var sign := SignPost.new().setup(s, atlas, touch_mode, frame_of("signpost", "signpost"))
		objects.add_child(sign)
		out.signs.append(sign)
	var decor := Node2D.new()
	decor.name = "Decor"
	root.add_child(decor)
	# Mundo 2: ríos de pintura (decorado al fondo de los huecos; caer sigue siendo caer al vacío)
	for r in data.get("rivers", []):
		var tex := Assets.frame(atlas, "paint_%s_surface" % r.color)
		var river := TiledSprite.new().setup(tex, Vector2(float(r.w) * C.TILE, tex.get_height()))
		river.position = Vector2(float(r.x) * C.TILE, float(rows) * C.TILE - tex.get_height() - 4)
		river.z_index = C.Z_DECOR_BACK
		decor.add_child(river)
		var tw := river.create_tween().set_loops()
		tw.tween_property(river, "tile_offset:x", float(tex.get_width()), 2.4).from(0.0)
	for d in data.decor:
		decor.add_child(_build_decor(d, atlas))
	return out


## Fotograma de un elemento común que cada mundo puede sustituir en sus datos ("frames").
func frame_of(key: String, default: Variant) -> Variant:
	return data.get("frames", {}).get(key, default)


## Avisa (sin ocultarlo) si el atlas no contiene algún fotograma usado por los datos.
func _check_frames(atlas: String) -> void:
	var frames: Array = []
	if data.crumbles.any(func(c): return not c.has("frame")):
		frames.append("cloud_puff")
	if not data.pads.is_empty():
		frames.append("jump_pad")
	if not data.signs.is_empty():
		frames.append(frame_of("signpost", "signpost"))
	if not data.checkpoints.is_empty():
		frames.append(frame_of("flag", "flag"))
	if not data.bridges.is_empty():
		frames += ["rainbow_mid", "rainbow_cap_l", "rainbow_cap_r"]
	if not data.get("rulers", []).is_empty():
		frames += ["ruler_mid", "ruler_post", "ruler_hinge"]
	for list in [data.clouds, data.movers, data.hazards, data.decor, data.crumbles]:
		for x in list:
			if x.has("frame"):
				frames.append(x.frame)
	for f in frames:
		if not Assets.has_frame(atlas, f):
			Assets.mark_placeholder("%s:%s" % [atlas, f])


# ------------------------------------------------------------------- terreno
func build_terrain() -> TileMapLayer:
	var ts: Dictionary = Assets.tileset_data(data.get("tileset", "world1_tiles"))
	grid = []
	for y in rows:
		var row := PackedByteArray()
		row.resize(cols)
		grid.append(row)
	for r in data.terrain:
		for y in range(int(r.y), mini(rows, int(r.y + r.h))):
			for x in range(maxi(0, int(r.x)), mini(cols, int(r.x + r.w))):
				grid[y][x] = 1
	layer = TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = Assets.tileset(data.get("tileset", "world1_tiles"))
	layer.z_index = C.Z_TERRAIN
	if layer.tile_set:
		var src := layer.tile_set.get_source(0) as TileSetAtlasSource
		tile_cols = int(src.texture.get_width() / C.TILE)

	# el fondo del mundo cuenta como sólido (el terreno no muestra borde inferior)
	var solid_below := func(x: int, y: int) -> bool:
		return y >= rows or grid[y][x] == 1
	for y in rows:
		for x in cols:
			if grid[y][x] == 0:
				continue
			var up: bool = y > 0 and grid[y - 1][x] == 1
			var down: bool = solid_below.call(x, y + 1)
			# en los extremos del mapa el terreno continúa (sin borde lateral visible)
			var left: bool = true if x == 0 else grid[y][x - 1] == 1
			var right: bool = true if x == cols - 1 else grid[y][x + 1] == 1
			var set_tiles: Array
			if not up and not down:
				set_tiles = ts.terrain.plat
			elif not up:
				set_tiles = ts.terrain.top
			elif not down:
				set_tiles = ts.terrain.bottom
			else:
				set_tiles = ts.terrain.fill
			var v := 2
			if not left and not right:
				v = 0
			elif not left:
				v = 1
			elif not right:
				v = 3
			_put(x, y, int(set_tiles[v]))
	for b in data.blocks:
		if not ts.blocks.has(b.type):
			Assets.mark_placeholder("tileset:" + b.type)
			continue
		_put(int(b.x), int(b.y), int(ts.blocks[b.type]))
	return layer


func _put(x: int, y: int, idx: int) -> void:
	layer.set_cell(Vector2i(x, y), 0, Vector2i(idx % tile_cols, idx / tile_cols))


## Coloca (o quita, con type "") un bloque sólido en tiempo de juego (la puerta del jefe).
func set_block(x: int, y: int, type: String) -> void:
	if type == "":
		layer.erase_cell(Vector2i(x, y))
	else:
		_put(x, y, int(Assets.tileset_data(data.get("tileset", "world1_tiles")).blocks[type]))


func is_solid(world_pos: Vector2) -> bool:
	return layer.get_cell_source_id(layer.local_to_map(world_pos)) != -1


# --------------------------------------------------------------- decoración
func _build_decor(dec: Dictionary, atlas: String) -> Sprite2D:
	var img := Sprite2D.new()
	img.texture = Assets.frame(atlas, dec.frame)
	Anim.set_origin(img, img.texture.get_size(), 0.5, 1.0)
	img.position = Vector2(float(dec.x) * C.TILE + C.TILE / 2.0, float(dec.y) * C.TILE + 1)
	if dec.get("front", false):
		img.z_index = C.Z_DECOR_FRONT
	elif dec.get("back", false):
		img.z_index = C.Z_DECOR_BACK - 1
	else:
		img.z_index = C.Z_DECOR_BACK
	if dec.get("sway", false):
		var d := (1400 + randf() * 600) / 1000.0
		img.rotation_degrees = -2.5
		var tw := img.create_tween().set_loops()
		tw.tween_property(img, "rotation_degrees", 2.5, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(img, "rotation_degrees", -2.5, d).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if dec.get("shimmer", false):
		img.modulate.a = 0.9
		var tw := img.create_tween().set_loops()
		tw.tween_property(img, "modulate:a", 0.7, 0.5)
		tw.tween_property(img, "modulate:a", 0.9, 0.5)
		var w := img.texture.get_width()
		var mist := ParticleBurst.new().setup({
			"x_range": [-w / 3.0, w / 3.0],
			"speed_y": [-30, -10],
			"speed_x": [-12, 12],
			"life": [700, 700],
			"scale": [1.5, 0],
			"alpha": [0.8, 0],
			"frequency": 90.0,
			"colors": Effects.colors([0xffffff, 0xc8f0ff]),
		})
		mist.position = Vector2(0, -4)
		mist.emitting = true
		mist.auto_free = false
		mist.z_index = 1
		img.add_child(mist)
	return img
