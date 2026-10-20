extends Node
## Catálogo de recursos gráficos y de datos (autoload "Assets").
##
## Equivale a PreloadScene + AnimationManager + PlaceholderFactory de Phaser:
##  - Atlas: data/atlases.json (Mundo 1, generado por tools/convert_phaser.mjs) y
##    data/world2/atlases.json (Mundo 2, generado por tools/world2/prepare_world2_assets.py)
##    -> AtlasTexture por fotograma. Cada mundo es un "paquete" de datos (PACKS).
##  - Animaciones: resources/**/<clave>_frames.tres (SpriteFrames generados por tools/build_resources.gd).
##  - Si un recurso falta se usa un marcador a cuadros magenta/negro, se registra en `used_placeholders`
##    y el menú muestra un aviso (nunca se oculta la falta).

const FRAMES_PATHS := {
	"player": "res://resources/player/player_frames.tres",
	"scratch": "res://resources/enemies/scratch_frames.tres",
	"spit": "res://resources/enemies/spit_frames.tres",
	"flea": "res://resources/enemies/flea_frames.tres",
	"nubarron": "res://resources/bosses/nubarron_frames.tres",
	"fx_portal": "res://resources/effects/portal_frames.tres",
	"eraser": "res://resources/world2/frames/eraser_frames.tres",
	"crayon": "res://resources/world2/frames/crayon_frames.tres",
	"brush": "res://resources/world2/frames/brush_frames.tres",
	"garabato": "res://resources/world2/frames/garabato_frames.tres",
	"rabbit": "res://resources/world3/frames/rabbit_frames.tres",
	"wool": "res://resources/world3/frames/wool_frames.tres",
	"pillow": "res://resources/world3/frames/pillow_frames.tres",
	"sieston": "res://resources/world3/frames/sieston_frames.tres",
	"bubble_fish": "res://resources/world4/frames/bubble_fish_frames.tres",
	"sponge_crab": "res://resources/world4/frames/sponge_crab_frames.tres",
	"pompa": "res://resources/world4/frames/pompa_frames.tres",
	"patoburbuja": "res://resources/world4/frames/patoburbuja_frames.tres",
	"estrellita": "res://resources/world5/frames/estrellita_frames.tres",
	"meteorito": "res://resources/world5/frames/meteorito_frames.tres",
	"cohetito": "res://resources/world5/frames/cohetito_frames.tres",
	"luna_estelar": "res://resources/world5/frames/luna_estelar_frames.tres",
	"payasito": "res://resources/world6/frames/payasito_frames.tres",
	"bloquecito": "res://resources/world6/frames/bloquecito_frames.tres",
	"vagoncito": "res://resources/world6/frames/vagoncito_frames.tres",
	"locomostro": "res://resources/world6/frames/locomostro_frames.tres",
	"cuppy": "res://resources/world7/frames/cuppy_frames.tres",
	"gomilito": "res://resources/world7/frames/gomilito_frames.tres",
	"gomilito_mini": "res://resources/world7/frames/gomilito_mini_frames.tres",
	"piruleta": "res://resources/world7/frames/piruleta_frames.tres",
	"don_chupeton": "res://resources/world7/frames/don_chupeton_frames.tres",
}
const TILESET_PATHS := {
	"world1_tiles": "res://resources/tilesets/world1/world1_tileset.tres",
	"world2_tiles": "res://resources/world2/terrain/world2_tileset.tres",
	"world3_tiles": "res://resources/world3/terrain/world3_tileset.tres",
	"world4_tiles": "res://resources/world4/terrain/world4_tileset.tres",
	"world5_tiles": "res://resources/world5/terrain/world5_tileset.tres",
	"world6_tiles": "res://resources/world6/terrain/world6_tileset.tres",
	"world7_tiles": "res://resources/world7/terrain/world7_tileset.tres",
}
## Paquetes de datos por mundo (atlases.json + characters.json). El primero es obligatorio.
const PACKS := ["res://data", "res://data/world2", "res://data/world3", "res://data/world4", "res://data/world5", "res://data/world6", "res://data/world7"]
const ENEMY_DIRS := ["res://resources/enemies", "res://resources/world2/enemies", "res://resources/world3/enemies", "res://resources/world4/enemies", "res://resources/world5/enemies", "res://resources/world6/enemies", "res://resources/world7/enemies"]

var atlases: Dictionary = {}
var images: Dictionary = {}
## TileSet del Mundo 1 (compatibilidad); los de todos los mundos están en `tilesets`.
var tileset_info: Dictionary = {}
var tilesets: Dictionary = {}
var characters: Dictionary = {}
var tuning: Dictionary = {}
var weapons_meta: Dictionary = {}
var used_placeholders: Dictionary = {}
var ok := true

var _textures: Dictionary = {}
var _frame_cache: Dictionary = {}
var _frames_cache: Dictionary = {}
var _generated: Dictionary = {}
var _weapons: Dictionary = {}
var _enemies: Dictionary = {}


func _ready() -> void:
	for i in PACKS.size():
		var pack: String = PACKS[i]
		var required := i == 0
		if not required and not FileAccess.file_exists(pack.path_join("atlases.json")):
			continue
		var a: Variant = C.load_json(pack.path_join("atlases.json"))
		if a is Dictionary:
			atlases.merge(a.atlases)
			images.merge(a.images)
			tilesets[a.tileset.key] = a.tileset
		elif required:
			ok = false
		var ch: Variant = C.load_json(pack.path_join("characters.json"))
		if ch is Dictionary:
			characters.merge(ch)
		elif required:
			ok = false
	tileset_info = tilesets.get("world1_tiles", {})
	var t: Variant = C.load_json("res://data/tuning.json")
	tuning = t if t is Dictionary else {}
	if not t is Dictionary:
		ok = false
	var w: Variant = C.load_json("res://data/weapons/weapons.json")
	weapons_meta = w if w is Dictionary else {"order": [], "paintColors": [], "foamColors": []}


# --------------------------------------------------------------------- texturas
func texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		mark_placeholder(path)
		tex = placeholder(64, 64)
	_textures[path] = tex
	return tex


func image(key: String) -> Texture2D:
	if not images.has(key):
		mark_placeholder(key)
		return placeholder(64, 64)
	return texture(images[key])


func has_frame(atlas: String, frame_name: String) -> bool:
	return atlases.has(atlas) and atlases[atlas].frames.has(frame_name)


## Fotograma de un atlas como AtlasTexture (cacheado). Si falta, marcador provisional de 16x16.
func frame(atlas: String, frame_name: String) -> Texture2D:
	var key := atlas + ":" + frame_name
	if _frame_cache.has(key):
		return _frame_cache[key]
	if not has_frame(atlas, frame_name):
		mark_placeholder(key)
		return placeholder(16, 16)
	var f: Array = atlases[atlas].frames[frame_name]
	var at := AtlasTexture.new()
	at.atlas = texture(atlases[atlas].texture)
	at.region = Rect2(f[0], f[1], f[2], f[3])
	# conserva el recorte original (si lo hubiera) como margen
	at.margin = Rect2(f[4], f[5], f[6] - f[2], f[7] - f[3])
	at.filter_clip = true
	_frame_cache[key] = at
	return at


func sprite_frames(key: String) -> SpriteFrames:
	if _frames_cache.has(key):
		return _frames_cache[key]
	var sf: SpriteFrames = null
	var path: String = FRAMES_PATHS.get(key, "")
	if path != "" and ResourceLoader.exists(path):
		sf = load(path) as SpriteFrames
	if sf == null:
		mark_placeholder("frames:" + key)
		sf = _placeholder_frames(key)
	_frames_cache[key] = sf
	return sf


## Tamaño de celda de un personaje (para colocar el sprite respecto a su origen).
func cell_size(key: String) -> Vector2:
	var c: Dictionary = characters.get(key, {})
	return Vector2(c.get("frameWidth", 32), c.get("frameHeight", 32))


func tileset(key := "world1_tiles") -> TileSet:
	var path: String = TILESET_PATHS.get(key, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path) as TileSet
	mark_placeholder("tileset:" + key)
	return null


## Datos del TileSet (autotiling de terreno y bloques) por clave.
func tileset_data(key := "world1_tiles") -> Dictionary:
	return tilesets.get(key, {})


# ------------------------------------------------------------------ armas/enemigos
func weapon(id: String) -> WeaponDef:
	if not _weapons.has(id):
		var path := "res://resources/weapons/%s.tres" % id
		_weapons[id] = load(path) as WeaponDef if ResourceLoader.exists(path) else null
		if _weapons[id] == null:
			push_error("[Assets] Falta el recurso de arma %s" % path)
	return _weapons[id]


func weapon_order() -> Array:
	return weapons_meta.get("order", [])


func enemy_def(type: String) -> EnemyDef:
	if not _enemies.has(type):
		_enemies[type] = null
		for dir in ENEMY_DIRS:
			var path: String = dir.path_join("%s.tres" % type)
			if ResourceLoader.exists(path):
				_enemies[type] = load(path) as EnemyDef
				break
	return _enemies[type]


func player_tuning() -> Dictionary:
	return tuning.get("player", {})


func camera_tuning() -> Dictionary:
	return tuning.get("camera", {})


# ------------------------------------------------- texturas generadas por código
## Equivalen a createRuntimeTextures() de PreloadScene: px, confetti, paint_blob, glow.
func generated(key: String) -> Texture2D:
	if _generated.has(key):
		return _generated[key]
	var img: Image
	match key:
		"px":
			img = Image.create(2, 2, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
		"confetti":
			img = Image.create(3, 2, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
		"paint_blob":
			# gota de pintura: círculo de 7 px con contorno (se tiñe al disparar)
			img = Image.create(9, 9, false, Image.FORMAT_RGBA8)
			_fill_circle(img, 4, 4, 4, C.INK)
			_fill_circle(img, 4, 4, 3, Color.WHITE)
			img.fill_rect(Rect2i(5, 1, 3, 3), Color.WHITE)
		"glow":
			# brillo circular suave: círculos concéntricos con alfa 0,12 acumulado
			img = Image.create(20, 20, false, Image.FORMAT_RGBA8)
			for y in 20:
				for x in 20:
					var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(10, 10))
					var n := 0
					for r in [10, 8, 6, 4, 2]:
						if d <= r:
							n += 1
					if n > 0:
						img.set_pixel(x, y, Color(1, 1, 1, 1.0 - pow(0.88, n)))
		_:
			return placeholder(16, 16)
	var tex := ImageTexture.create_from_image(img)
	_generated[key] = tex
	return tex


func _fill_circle(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx + 0.5, cy + 0.5)) <= r:
				img.set_pixel(x, y, col)


# ------------------------------------------------------------ marcadores provisionales
## Cuadro a cuadros magenta/negro con borde amarillo: imposible de confundir con arte final.
func placeholder(w: int, h: int) -> Texture2D:
	var key := "__placeholder_%dx%d" % [w, h]
	if _generated.has(key):
		return _generated[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var on := ((x / 4) + (y / 4)) % 2 == 0
			img.set_pixel(x, y, Color.MAGENTA if on else Color.BLACK)
	for x in w:
		img.set_pixel(x, 0, Color.YELLOW)
		img.set_pixel(x, h - 1, Color.YELLOW)
	for y in h:
		img.set_pixel(0, y, Color.YELLOW)
		img.set_pixel(w - 1, y, Color.YELLOW)
	var tex := ImageTexture.create_from_image(img)
	_generated[key] = tex
	return tex


func mark_placeholder(what: String) -> void:
	if not used_placeholders.has(what):
		used_placeholders[what] = true
		push_warning("[Placeholder] Recurso no disponible, se usa marcador provisional: %s" % what)


func _placeholder_frames(key: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	var size := cell_size(key)
	var tex := placeholder(int(size.x), int(size.y))
	var anims: Dictionary = characters.get(key, {}).get("anims", {})
	for anim_name in anims:
		sf.add_animation(anim_name)
		sf.add_frame(anim_name, tex)
	return sf
