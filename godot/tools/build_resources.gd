extends SceneTree
## Conversión Phaser -> Godot (paso 2 de 2). Genera recursos nativos a partir de data/*.json:
##  - SpriteFrames (.tres) de cada personaje con sus animaciones (fotogramas, fps, bucle).
##  - TileSet (.tres) del terreno 16x16 con colisión en cada tesela.
##  - WeaponDef (.tres) de las tres armas y EnemyDef (.tres) de los tres monstruos.
##
## Uso (después de convert_phaser.mjs y de importar las texturas):
##     godot --headless --path godot --import
##     godot --headless --path godot --script res://tools/build_resources.gd

const CHAR_OUT := {
	"player": "res://resources/player/player_frames.tres",
	"scratch": "res://resources/enemies/scratch_frames.tres",
	"spit": "res://resources/enemies/spit_frames.tres",
	"flea": "res://resources/enemies/flea_frames.tres",
	"nubarron": "res://resources/bosses/nubarron_frames.tres",
	"fx_portal": "res://resources/effects/portal_frames.tres",
}
## Mundo 2 (data/world2, generado por tools/world2/prepare_world2_assets.py).
const WORLD2_FRAMES_DIR := "res://resources/world2/frames"
const WORLD3_FRAMES_DIR := "res://resources/world3/frames"
const WORLD4_FRAMES_DIR := "res://resources/world4/frames"
const WORLD5_FRAMES_DIR := "res://resources/world5/frames"
const WORLD6_FRAMES_DIR := "res://resources/world6/frames"
const WORLD7_FRAMES_DIR := "res://resources/world7/frames"
const TILESET_OUT := {
	"world1_tiles": "res://resources/tilesets/world1/world1_tileset.tres",
	"world2_tiles": "res://resources/world2/terrain/world2_tileset.tres",
	"world3_tiles": "res://resources/world3/terrain/world3_tileset.tres",
	"world4_tiles": "res://resources/world4/terrain/world4_tileset.tres",
	"world5_tiles": "res://resources/world5/terrain/world5_tileset.tres",
	"world6_tiles": "res://resources/world6/terrain/world6_tileset.tres",
	"world7_tiles": "res://resources/world7/terrain/world7_tileset.tres",
}

var errors := 0


func _init() -> void:
	var atlases: Dictionary = _json("res://data/atlases.json")
	var characters: Dictionary = _json("res://data/characters.json")
	if atlases.is_empty() or characters.is_empty():
		quit(1)
		return
	_build_sprite_frames(atlases.atlases, characters)
	_build_tileset(atlases.tileset)
	_build_weapons(_json("res://data/weapons/weapons.json"))
	_build_enemies(_json("res://data/enemies/enemies.json"), "res://resources/enemies")
	if FileAccess.file_exists("res://data/world2/atlases.json"):
		var a2: Dictionary = _json("res://data/world2/atlases.json")
		_build_sprite_frames(a2.atlases, _json("res://data/world2/characters.json"), WORLD2_FRAMES_DIR)
		_build_tileset(a2.tileset)
		_build_enemies(_json("res://data/world2/enemies.json"), "res://resources/world2/enemies")
	if FileAccess.file_exists("res://data/world3/atlases.json"):
		var a3: Dictionary = _json("res://data/world3/atlases.json")
		_build_sprite_frames(a3.atlases, _json("res://data/world3/characters.json"), WORLD3_FRAMES_DIR)
		_build_tileset(a3.tileset)
		_build_enemies(_json("res://data/world3/enemies.json"), "res://resources/world3/enemies")
	if FileAccess.file_exists("res://data/world4/atlases.json"):
		var a4: Dictionary = _json("res://data/world4/atlases.json")
		_build_sprite_frames(a4.atlases, _json("res://data/world4/characters.json"), WORLD4_FRAMES_DIR)
		_build_tileset(a4.tileset)
		_build_enemies(_json("res://data/world4/enemies.json"), "res://resources/world4/enemies")
	if FileAccess.file_exists("res://data/world5/atlases.json"):
		var a5: Dictionary = _json("res://data/world5/atlases.json")
		_build_sprite_frames(a5.atlases, _json("res://data/world5/characters.json"), WORLD5_FRAMES_DIR)
		_build_tileset(a5.tileset)
		_build_enemies(_json("res://data/world5/enemies.json"), "res://resources/world5/enemies")
	if FileAccess.file_exists("res://data/world6/atlases.json"):
		var a6: Dictionary = _json("res://data/world6/atlases.json")
		_build_sprite_frames(a6.atlases, _json("res://data/world6/characters.json"), WORLD6_FRAMES_DIR)
		_build_tileset(a6.tileset)
		_build_enemies(_json("res://data/world6/enemies.json"), "res://resources/world6/enemies")
	if FileAccess.file_exists("res://data/world7/atlases.json"):
		var a7: Dictionary = _json("res://data/world7/atlases.json")
		_build_sprite_frames(a7.atlases, _json("res://data/world7/characters.json"), WORLD7_FRAMES_DIR)
		_build_tileset(a7.tileset)
		_build_enemies(_json("res://data/world7/enemies.json"), "res://resources/world7/enemies")
	print("[build_resources] terminado con %d errores" % errors)
	quit(1 if errors > 0 else 0)


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Falta %s: ejecuta antes node godot/tools/convert_phaser.mjs" % path)
		errors += 1
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


func _save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("No se pudo guardar %s (%d)" % [path, err])
		errors += 1
	else:
		print("  escrito ", path)


func _build_sprite_frames(atlases: Dictionary, characters: Dictionary, out_dir := "") -> void:
	for key in characters:
		var c: Dictionary = characters[key]
		var atlas_key: String = c.get("atlas", key)
		var atlas: Dictionary = atlases[atlas_key]
		var tex := load(atlas.texture) as Texture2D
		if tex == null:
			push_error("Textura no importada: %s (ejecuta --import antes)" % atlas.texture)
			errors += 1
			continue
		var sf := SpriteFrames.new()
		sf.remove_animation("default")
		var cache := {}
		for anim_name in c.anims:
			var a: Dictionary = c.anims[anim_name]
			sf.add_animation(anim_name)
			sf.set_animation_speed(anim_name, float(a.fps))
			sf.set_animation_loop(anim_name, bool(a.loop))
			for fname in a.frames:
				if not cache.has(fname):
					var f: Array = atlas.frames[fname]
					var at := AtlasTexture.new()
					at.atlas = tex
					at.region = Rect2(f[0], f[1], f[2], f[3])
					at.margin = Rect2(f[4], f[5], f[6] - f[2], f[7] - f[3])
					at.filter_clip = true
					at.resource_name = fname
					cache[fname] = at
				sf.add_frame(anim_name, cache[fname])
		_save(sf, out_dir.path_join("%s_frames.tres" % key) if out_dir != "" else CHAR_OUT[key])


func _build_tileset(info: Dictionary) -> void:
	var size: int = int(info.tileSize)
	var tex := load(info.texture) as Texture2D
	if tex == null:
		push_error("Textura de teselas no importada: %s" % info.texture)
		errors += 1
		return
	var ts := TileSet.new()
	ts.tile_size = Vector2i(size, size)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, C.L_WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(size, size)
	ts.add_source(src, 0)
	# Se crean todas las teselas usadas por el terreno (autotiling) y por los bloques.
	var used := {}
	_collect_tiles(info.terrain, used)
	# Mundo 4: materiales (esponja, azulejo) con variantes por paridad
	_collect_tiles(info.get("materials", {}), used)
	for b in info.blocks:
		used[int(info.blocks[b])] = true
	var cols := tex.get_width() / size
	var h := size / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	# rampas de 45 grados: colisión triangular (sube hacia la derecha "_up" o hacia la izquierda "_down")
	var slopes: Dictionary = info.get("slopes", {})
	for key in slopes:
		used[int(slopes[key])] = true
	for idx in used:
		var coords := Vector2i(idx % cols, idx / cols)
		src.create_tile(coords)
		var td := src.get_tile_data(coords, 0)
		td.add_collision_polygon(0)
		var points := square
		for key in slopes:
			if int(slopes[key]) == idx:
				points = PackedVector2Array([Vector2(-h, h), Vector2(h, -h), Vector2(h, h)]) if String(key).ends_with("_up") 					else PackedVector2Array([Vector2(-h, -h), Vector2(h, h), Vector2(-h, h)])
		td.set_collision_polygon_points(0, 0, points)
	_save(ts, TILESET_OUT[info.key])


## Índices de teselas de un diccionario o lista anidados (terrain y materials).
func _collect_tiles(v: Variant, used: Dictionary) -> void:
	if v is Dictionary:
		for k in v:
			_collect_tiles(v[k], used)
	elif v is Array:
		for x in v:
			_collect_tiles(x, used)
	elif v is float or v is int:
		used[int(v)] = true


func _build_weapons(data: Dictionary) -> void:
	if data.is_empty():
		return
	var WeaponDefScript := load("res://scripts/weapons/weapon_def.gd")
	for id in data.weapons:
		var w: Dictionary = data.weapons[id]
		var p: Dictionary = w.projectile
		var r: Resource = WeaponDefScript.new()
		r.id = w.id
		r.display_name = w.name
		r.icon = w.icon
		r.sound = w.sound
		r.cooldown = float(w.cooldown)
		r.damage = int(w.damage)
		r.boss_damage = int(w.bossDamage)
		r.effect = w.effect
		r.recoil = float(w.recoil)
		r.proj_texture = p.texture
		r.proj_frame = p.get("frame", "")
		r.proj_speed = float(p.speed)
		r.proj_vy = float(p.get("vy", 0))
		r.proj_gravity = float(p.get("gravity", 0))
		r.proj_lifespan = float(p.get("lifespan", 1500))
		r.proj_alpha = float(p.get("alpha", 1))
		r.proj_wobble = float(p.get("wobble", 0))
		r.proj_body = float(p.get("body", 8))
		r.proj_scale = float(p.get("scale", 1))
		r.proj_tint_cycle = p.get("tintCycle", "")
		r.proj_trail = bool(p.get("trail", false))
		r.proj_spin = float(p.get("spin", 0))
		_save(r, "res://resources/weapons/%s.tres" % id)


func _build_enemies(data: Dictionary, out_dir: String) -> void:
	var EnemyDefScript := load("res://scripts/entities/enemy_def.gd")
	for key in data:
		var e: Dictionary = data[key]
		var r: Resource = EnemyDefScript.new()
		r.key = e.key
		r.display_name = e.name
		r.hp = int(e.hp)
		r.speed = float(e.speed)
		r.body_size = Vector2(e.body.width, e.body.height)
		r.detect_range = float(e.detectRange)
		r.detect_height = float(e.detectHeight)
		r.reaction_time = float(e.reactionTime)
		r.attack_cooldown = float(e.attackCooldown)
		r.trap_time = float(e.trapTime)
		r.attack_range = float(e.get("attackRange", 0))
		if e.has("keepDistance"):
			r.keep_distance = Vector2(e.keepDistance[0], e.keepDistance[1])
		r.retreat_distance = float(e.get("retreatDistance", 0))
		_save(r, out_dir.path_join("%s.tres" % key))
