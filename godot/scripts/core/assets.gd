extends Node
## Catálogo de recursos gráficos y de datos (autoload "Assets").
##
## Equivale a PreloadScene + AnimationManager + PlaceholderFactory de Phaser:
##  - Atlas: data/atlases.json (generado por tools/convert_phaser.mjs) -> AtlasTexture por fotograma.
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
}
const TILESET_PATH := "res://resources/tilesets/world1/world1_tileset.tres"

var atlases: Dictionary = {}
var images: Dictionary = {}
var tileset_info: Dictionary = {}
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
	var a: Variant = C.load_json("res://data/atlases.json")
	if a is Dictionary:
		atlases = a.atlases
		images = a.images
		tileset_info = a.tileset
	else:
		ok = false
	var ch: Variant = C.load_json("res://data/characters.json")
	if ch is Dictionary:
		characters = ch
	else:
		ok = false
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


func tileset() -> TileSet:
	if ResourceLoader.exists(TILESET_PATH):
		return load(TILESET_PATH) as TileSet
	mark_placeholder("tileset")
	return null


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
		var path := "res://resources/enemies/%s.tres" % type
		_enemies[type] = load(path) as EnemyDef if ResourceLoader.exists(path) else null
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
