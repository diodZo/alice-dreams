class_name C
## Constantes compartidas (equivalente a config/gameConfig.js de Phaser).

## Resolución lógica: todo el juego se dibuja a 480x270 y se escala sin suavizado.
const GAME_W := 480
const GAME_H := 270
const TILE := 16
const GRAVITY := 900.0

## Profundidades de dibujo (DEPTH de gameConfig.js) -> z_index de Godot.
const Z_BG := -100
const Z_DECOR_BACK := 2
const Z_TERRAIN := 10
const Z_PLATFORM := 12
const Z_PICKUP := 15
const Z_ENEMY := 20
const Z_PLAYER := 25
const Z_PROJECTILE := 30
const Z_DECOR_FRONT := 35
const Z_FX := 40
const Z_UI_WORLD := 50

## Capas de colisión (ver [layer_names] en project.godot).
const L_WORLD := 1
const L_ONE_WAY := 2
const L_PLAYER := 4
const L_ENEMY_BODY := 8
const L_ENEMY_HITBOX := 16
const L_PLAYER_PROJ := 32
const L_ENEMY_PROJ := 64
const L_TRIGGER := 128
const L_BOSS := 256

## Vida restante (fracción) a la que los jefes pasan a la fase 2 y a la 3 (BossBase y la barra del HUD).
const BOSS_PHASE_THRESHOLDS := [0.65, 0.30]

## Colores de la paleta usados por la interfaz.
const INK := Color("2a2350")
const CREAM := Color("fff7ff")
const YELLOW := Color("ffe082")
const PINK := Color("f7a8d8")
const BLUE := Color("3455a4")
const LAVENDER := Color("b9a7f4")
## Color de los fundidos de cámara (52, 85, 164).
const FADE_BLUE := Color8(52, 85, 164)


## Convierte un entero 0xRRGGBB (como en el código Phaser) en Color.
static func rgb(c: int, a: float = 1.0) -> Color:
	return Color8((c >> 16) & 0xff, (c >> 8) & 0xff, c & 0xff, int(round(a * 255.0)))


## Lee un archivo JSON del proyecto. Devuelve null (y avisa) si falta o está mal formado.
static func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[Datos] Falta %s. Ejecuta: node godot/tools/convert_phaser.mjs" % path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("[Datos] JSON mal formado: %s" % path)
	return parsed
