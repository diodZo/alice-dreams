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
	for c in data.get("clouds", []):
		platforms.add_child(CloudPlatform.new().setup(c, atlas))
	for b in data.get("bridges", []):
		platforms.add_child(RainbowBridge.new().setup(b, atlas))
	# Mundo 2: puentes de reglas (rectos, inclinados, articulados, dibujados, temporales, activables)
	out.rulers = []
	for r in data.get("rulers", []):
		var rb := RulerBridge.new().setup(level, r, atlas)
		platforms.add_child(rb)
		out.rulers.append(rb)
	out.movers = []
	for m in data.get("movers", []):
		var p := MovingPlatform.new().setup(m, atlas)
		platforms.add_child(p)
		out.movers.append(p)
	out.crumbles = []
	for c in data.get("crumbles", []):
		var p := CrumblePlatform.new().setup(level, c, atlas)
		platforms.add_child(p)
		out.crumbles.append(p)
	# Mundo 3: plataformas oscilantes suspendidas por cuerdas.
	for s in data.get("swings", []):
		var p := SwingPlatform.new().setup(s, atlas)
		platforms.add_child(p)
		out.movers.append(p)
	# Mundo 5: cohetes móviles, lunas en órbita y toboganes arcoíris.
	for r in data.get("rockets", []):
		var p := RocketPlatform.new().setup(r, atlas)
		platforms.add_child(p)
		out.movers.append(p)
	for o in data.get("orbits", []):
		var p := OrbitPlatform.new().setup(o, atlas)
		platforms.add_child(p)
		out.movers.append(p)
	out.slides = []
	for s in data.get("slides", []):
		var sl := RainbowSlide.new().setup(s, atlas)
		platforms.add_child(sl)
		out.slides.append(sl)
	# Mundo 6: trenes de juguete (cada vagón es una plataforma móvil), plataformas con hélice,
	# puentes arcoíris en arco y bloques que caen.
	out.trains = []
	for t in data.get("trains", []):
		var line := TrainLine.new().setup(level, t, atlas)
		platforms.add_child(line)
		out.trains.append(line)
		for car in line.cars:
			out.movers.append(car)
	for h in data.get("helis", []):
		var p := HeliPlatform.new().setup(h, atlas)
		platforms.add_child(p)
		out.movers.append(p)
	for a in data.get("rainbowArches", []):
		platforms.add_child(RainbowArch.new().setup(a, atlas))
	for b in data.get("fallingBlocks", []):
		platforms.add_child(FallingBlock.new().setup(level, b, atlas))
	out.star_blocks = []
	for b in data.get("starBlocks", []):
		var sb := StarBlock.new().setup(level, b, atlas)
		platforms.add_child(sb)
		out.star_blocks.append(sb)
	# Mundo 7: correas de chocolate (arrastran a lo que se apoya encima).
	out.belts = []
	for b in data.get("belts", []):
		var belt := ConveyorBelt.new().setup(b, atlas)
		platforms.add_child(belt)
		out.belts.append(belt)
	# Mundo 8: plataformas fantasma (ciclo con aviso) y puentes ocultos que revelan los faroles.
	out.ghosts = []
	for g in data.get("ghostPlatforms", []):
		var gp := GhostPlatform.new().setup(level, g, atlas)
		platforms.add_child(gp)
		out.ghosts.append(gp)
	out.hidden_bridges = []
	for b in data.get("hiddenBridges", []):
		var hb := HiddenBridge.new().setup_hidden(level, b, atlas)
		platforms.add_child(hb)
		out.hidden_bridges.append(hb)

	var objects := Node2D.new()
	objects.name = "Objects"
	root.add_child(objects)
	out.objects = objects
	for p in data.get("pads", []):
		objects.add_child(BouncePad.new().setup(level, p, atlas))
	for h in data.get("hazards", []):
		objects.add_child(Hazard.new().setup(h, atlas))
	for w in data.get("winds", []):
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
	# Mundo 3: ovillos, nubes de sueño, coleccionables y mecanismos por señales.
	for y in data.get("yarnRollers", []):
		objects.add_child(RollingYarn.new().setup(y, atlas))
	for c in data.get("sleepClouds", []):
		objects.add_child(SleepCloud.new().setup(c, atlas))
	# Mundo 4: agua, géiseres, columnas de burbujas, rodillos de esponja y jabones móviles.
	out.waters = []
	for w in data.get("waters", []):
		var wz := WaterZone.new().setup(level, w, atlas)
		objects.add_child(wz)
		out.waters.append(wz)
	for g in data.get("geysers", []):
		objects.add_child(BubbleGeyser.new().setup(level, g, atlas))
	for c in data.get("bubbleColumns", []):
		objects.add_child(BubbleColumn.new().setup_column(level, c, atlas))
	for r in data.get("spongeRollers", []):
		objects.add_child(SpongeRoller.new().setup(level, r, atlas))
	for s in data.get("soaps", []):
		objects.add_child(SlidingSoap.new().setup(level, s, atlas))
	# Mundo 5: cascadas de luz (corriente ascendente), estrellas que caen y nubes explosivas.
	for f in data.get("lightFalls", []):
		objects.add_child(LightFall.new().setup_fall(level, f, atlas))
	for f in data.get("fallingStars", []):
		objects.add_child(FallingStar.new().setup(level, f, atlas))
	for c in data.get("explosiveClouds", []):
		objects.add_child(ExplosiveCloud.new().setup(level, c, atlas))
	# Mundo 6: ruedas rodantes, barreras de estrella, trenes enemigos, palancas y campanas.
	for w in data.get("rollingWheels", []):
		objects.add_child(RollingWheel.new().setup(level, w, atlas))
	for b in data.get("bumpers", []):
		objects.add_child(StarBumper.new().setup(level, b, atlas))
	for t in data.get("hazardTrains", []):
		objects.add_child(HazardTrain.new().setup(level, t, atlas))
	out.levers = []
	for l in data.get("levers", []):
		var ti := int(l.get("train", -1))
		var lever := RailLever.new().setup(level, l, atlas, out.trains[ti] if ti >= 0 and ti < out.trains.size() else null)
		objects.add_child(lever)
		out.levers.append(lever)
	out.bells = []
	for b in data.get("bells", []):
		var ti := int(b.get("train", -1))
		var bell := StationBell.new().setup(level, b, atlas, out.trains[ti] if ti >= 0 and ti < out.trains.size() else null)
		objects.add_child(bell)
		out.bells.append(bell)
	# Mundo 7: piruletas giratorias, lanzadores de caramelos, chorros de chocolate y corazones.
	out.lollipops = []
	for l in data.get("lollipops", []):
		var lp := SpinningLollipop.new().setup(l, atlas)
		objects.add_child(lp)
		out.lollipops.append(lp)
	out.launchers = []
	for l in data.get("launchers", []):
		var ln := CandyLauncher.new().setup(level, l, atlas)
		objects.add_child(ln)
		out.launchers.append(ln)
	out.choco_jets = []
	for j in data.get("chocoJets", []):
		var jet := ChocoJet.new().setup(level, j, atlas)
		objects.add_child(jet)
		out.choco_jets.append(jet)
	# Mundo 8: sombras, ganchos en cadena, faroles mágicos (conectados a sus puentes por señal) y cofres.
	out.shadows = []
	for z in data.get("shadowZones", []):
		var sz := ShadowZone.new().setup(z, atlas)
		objects.add_child(sz)
		out.shadows.append(sz)
	out.hooks = []
	for hk in data.get("hooks", []):
		var ch := ChainHook.new().setup(level, hk, atlas)
		objects.add_child(ch)
		out.hooks.append(ch)
	out.lanterns = []
	for l in data.get("lanterns", []):
		var lantern := MagicLantern.new().setup(level, l, atlas)
		objects.add_child(lantern)
		out.lanterns.append(lantern)
		for hb in out.hidden_bridges:
			if hb.id in lantern.bridges:
				lantern.lit.connect(func(_l): hb.reveal(0))
	out.chests = []
	for c in data.get("chests", []):
		var chest := TreasureChest.new().setup(level, c, atlas)
		objects.add_child(chest)
		out.chests.append(chest)
	for h in data.get("hearts", []):
		objects.add_child(HeartPickup.new().setup(level, h, atlas))
	for c in data.get("dreamCollectibles", []):
		if not (str(c.id) in GameState.get_v("dreamCollectibles", [])):
			objects.add_child(DreamCollectible.new().setup(level, c, atlas))
	for b in data.get("magicButtons", []):
		var button := MagicButton.new().setup(b, atlas)
		objects.add_child(button)
		var target_i := int(b.get("targetMover", -1))
		if target_i >= 0 and target_i < out.movers.size():
			button.activated.connect(out.movers[target_i].activate)
	for m in data.get("magicCrayons", []):
		if not (m.color in GameState.get_v("magicCrayons", [])):
			objects.add_child(MagicCrayon.new().setup(level, m, atlas))
	var rulers: Array = data.get("rulers", [])
	for i in rulers.size():
		var r: Dictionary = rulers[i]
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
		var sign := SignPost.new().setup(s, atlas, touch_mode, frame_of("signpost", "signpost"), cols * C.TILE)
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
	if data.get("crumbles", []).any(func(c): return not c.has("frame")):
		frames.append("cloud_puff")
	if not data.get("pads", []).is_empty():
		for p in data.get("pads", []):
			frames.append(p.get("frame", "jump_pad"))
	if not data.signs.is_empty():
		frames.append(frame_of("signpost", "signpost"))
	if not data.checkpoints.is_empty():
		frames.append(frame_of("flag", "flag"))
	if not data.get("bridges", []).is_empty():
		frames += ["rainbow_mid", "rainbow_cap_l", "rainbow_cap_r"]
	if not data.get("rulers", []).is_empty():
		frames += ["ruler_mid", "ruler_post", "ruler_hinge"]
	for x in data.get("swings", []):
		frames += [x.get("frame", "button_blue"), x.get("knot", "yarn_ball_pink")]
	for x in data.get("yarnRollers", []):
		frames.append(x.get("frame", "yarn_ball_pink"))
	for x in data.get("magicButtons", []):
		frames.append(x.get("frame", "magic_button"))
	for x in data.get("dreamCollectibles", []):
		frames.append(x.get("frame", DreamCollectible.FRAMES.get(x.get("kind", "moon"), "moon_w3")))
	for x in data.get("waters", []):
		frames += ["water_top_0", "water_top_1", "water_top_2", "water_deep_0", "water_deep_1", "water_deep_2"]
	for x in data.get("geysers", []) + data.get("bubbleColumns", []):
		frames += ["geyser_0", "geyser_4", "bubble_col_0", "bubble_col_2"]
	for x in data.get("spongeRollers", []) + data.get("soaps", []) + data.get("paints", []):
		if x.has("frame"):
			frames.append(x.frame)
	if not data.get("slides", []).is_empty():
		frames += ["rainbow_band", "cloud_s", "star_post_a"]
	if not data.get("lightFalls", []).is_empty():
		frames += ["light_fall_0", "light_fall_1", "star_w5"]
	for x in data.get("fallingStars", []):
		frames += x.get("frames", ["fall_star_0", "fall_star_1", "fall_star_2", "fall_star_3"])
		if x.has("warn_frame"):
			frames.append(x.warn_frame)
	if not data.get("explosiveClouds", []).is_empty():
		frames += ["boom_cloud", "boom_cloud_big", "boom_burst"]
	if not data.get("trains", []).is_empty() or not data.get("hazardTrains", []).is_empty():
		frames += ["rail_strip", "rail_stop", "rail_cross", "hazard_train", "rainbow_tunnel"]
	for x in data.get("trains", []):
		frames += x.get("cars", [])
	if not data.get("rainbowArches", []).is_empty():
		frames += ["rainbow_band_w6", "cloud_s"]
	if not data.get("helis", []).is_empty():
		frames += ["heli_plat", "heli_prop", "heli_plat_b", "heli_prop_b", "heli_plat_c", "heli_prop_c"]
	for x in data.get("fallingBlocks", []) + data.get("rollingWheels", []):
		if x.has("frame"):
			frames.append(x.frame)
	if not data.get("bumpers", []).is_empty():
		frames += ["bumper", "bumper_hit"]
	if not data.get("levers", []).is_empty():
		frames.append("rail_lever")
	if not data.get("bells", []).is_empty():
		frames.append("bell")
	if not data.get("starBlocks", []).is_empty():
		frames.append("star_block")
	for x in data.get("belts", []):
		frames.append(x.get("frame", "choco_belt"))
	for x in data.get("lollipops", []):
		frames.append(x.get("frame", "lolli_spin"))
	for x in data.get("launchers", []):
		frames.append(x.get("frame", "launcher_a"))
	for x in data.get("chocoJets", []):
		frames += [x.get("frame", "choco_jet_a"), "choco_drip"]
	for x in data.get("hearts", []):
		if not x.has("atlas"): # los de los Mundos 1-6 usan el corazón del HUD (atlas fx)
			frames.append(x.get("frame", "heart_w7"))
	for x in data.get("ghostPlatforms", []):
		frames += [x.get("frame", "ghost_plat_on"), x.get("frame_off", "ghost_plat_off")]
	for x in data.get("shadowZones", []):
		frames.append(x.get("frame", "shadow_pool" if x.get("kind", "pool") == "pool" else "shadow_mist"))
	for x in data.get("hooks", []):
		frames.append(x.get("frame", "hook_moon"))
	for x in data.get("lanterns", []):
		frames.append(x.get("frame", "lamp_post"))
	for x in data.get("hiddenBridges", []) + data.get("chests", []):
		frames.append(x.get("frame", "chest_w8"))
	for x in data.get("swings", []):
		frames.append(x.get("frame", "button_blue"))
	for x in data.get("sleepClouds", []):
		var fx_atlas: String = x.get("atlas", "w3_fx")
		var f: String = x.get("frame", "sleep_cloud")
		if not Assets.has_frame(fx_atlas, f):
			Assets.mark_placeholder("%s:%s" % [fx_atlas, f])
	for list in [data.get("clouds", []), data.get("movers", []), data.get("hazards", []), data.decor, data.get("crumbles", []), data.get("rockets", []), data.get("orbits", [])]:
		for x in list:
			if x.has("frame"):
				frames.append(x.frame)
	for f in frames:
		if not Assets.has_frame(atlas, f):
			Assets.mark_placeholder("%s:%s" % [atlas, f])


# ------------------------------------------------------------------- terreno
func build_terrain() -> TileMapLayer:
	var ts: Dictionary = Assets.tileset_data(data.get("tileset", "world1_tiles"))
	# Mundo 4: varios materiales. El valor de la rejilla es 1 + índice del material.
	var mats: Array = ts.get("materials", {}).keys()
	var default_mat := maxi(0, mats.find(ts.get("defaultMaterial", "")))
	grid = []
	for y in rows:
		var row := PackedByteArray()
		row.resize(cols)
		grid.append(row)
	for r in data.terrain:
		var m: int = mats.find(r.get("mat", "")) if r.has("mat") else default_mat
		for y in range(int(r.y), mini(rows, int(r.y + r.h))):
			for x in range(maxi(0, int(r.x)), mini(cols, int(r.x + r.w))):
				grid[y][x] = 1 + maxi(m, 0)
	# rampas: cuentan como sólidas para el autotiling de sus vecinas
	var slopes := {}
	for sl in data.get("slopes", []):
		var c := Vector2i(int(sl.x), int(sl.y))
		slopes[c] = "%s_%s" % [sl.get("mat", ts.get("defaultMaterial", "sponge")), sl.get("dir", "up")]
		if c.y >= 0 and c.y < rows and c.x >= 0 and c.x < cols:
			grid[c.y][c.x] = 1 + default_mat
	layer = TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = Assets.tileset(data.get("tileset", "world1_tiles"))
	layer.z_index = C.Z_TERRAIN
	if layer.tile_set:
		var src := layer.tile_set.get_source(0) as TileSetAtlasSource
		tile_cols = int(src.texture.get_width() / C.TILE)

	# el fondo del mundo cuenta como sólido (el terreno no muestra borde inferior)
	var solid_below := func(x: int, y: int) -> bool:
		return y >= rows or grid[y][x] != 0
	# profundidad de cada celda bajo la superficie de su columna (bloques de 2x2 del Mundo 4)
	var depth := PackedInt32Array()
	depth.resize(cols)
	for y in rows:
		for x in cols:
			if grid[y][x] == 0:
				depth[x] = -1
				continue
			depth[x] = depth[x] + 1 if y > 0 and grid[y - 1][x] != 0 else 0
			var cell := Vector2i(x, y)
			if slopes.has(cell):
				if ts.get("slopes", {}).has(slopes[cell]):
					_put(x, y, int(ts.slopes[slopes[cell]]))
				continue
			var up: bool = y > 0 and grid[y - 1][x] != 0
			var down: bool = solid_below.call(x, y + 1)
			# en los extremos del mapa el terreno continúa (sin borde lateral visible)
			var left: bool = true if x == 0 else grid[y][x - 1] != 0
			var right: bool = true if x == cols - 1 else grid[y][x + 1] != 0
			var v := 2
			if not left and not right:
				v = 0
			elif not left:
				v = 1
			elif not right:
				v = 3
			if not mats.is_empty():
				_put(x, y, _material_tile(ts.materials[mats[grid[y][x] - 1]], x, depth[x], up, down, v))
				continue
			var set_tiles: Array
			if not up and not down:
				set_tiles = ts.terrain.plat
			elif not up:
				set_tiles = ts.terrain.top
			elif not down:
				set_tiles = ts.terrain.bottom
			else:
				set_tiles = ts.terrain.fill
			_put(x, y, int(set_tiles[v]))
	for b in data.get("blocks", []):
		if not ts.blocks.has(b.type):
			Assets.mark_placeholder("tileset:" + b.type)
			continue
		_put(int(b.x), int(b.y), int(ts.blocks[b.type]))
	return layer


## Tesela de un material del Mundo 4: la superficie usa el bloque con espuma (dos filas) y
## debajo se repite el bloque base; cada bloque ocupa 2x2 teselas (paridad de columna y fila).
func _material_tile(m: Dictionary, x: int, d: int, up: bool, down: bool, v: int) -> int:
	var px := x % 2
	var role: String
	var k := px
	if not down:
		role = "plat" if not up else ("cap1_bottom" if d == 1 else "bottom")
	else:
		role = "cap0" if not up else ("cap1" if d == 1 else "body")
	if role == "body" or role == "bottom":
		k = px + 2 * ((d - 2) % 2)
	return int(m[role][v + 4 * k])


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
	elif dec.get("water", false):
		# fondo submarino (Mundo 4): por delante del agua, por detrás de Alice y los monstruos
		img.z_index = C.Z_PLATFORM
	elif dec.get("back", false):
		img.z_index = C.Z_DECOR_BACK - 1
	else:
		img.z_index = C.Z_DECOR_BACK
	if dec.has("alpha"):
		img.modulate.a = float(dec.alpha)
	if dec.has("scale"):
		img.scale = Vector2(float(dec.scale), float(dec.scale))
	if dec.get("flip", false):
		img.flip_h = true
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
