extends Node
## Estado de la partida en curso (autoload "GameState").
## Equivale al registro (registry) de Phaser: el nivel escribe, el HUD lee y escucha `changed`.
## También transporta los avisos del HUD ("hud-banner" / "hud-toast").

signal changed(key: String)
signal banner(text: String)
signal toast(text: String)

var data: Dictionary = {}
## Datos de entrada para la próxima escena (p. ej. {"introBanner": true}).
var entry: Dictionary = {}
## Botones táctiles: dispositivo táctil o argumento "--touch" (equivale a ?touch=1).
var touch_mode := false


func _ready() -> void:
	touch_mode = DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()


func get_v(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)


func set_v(key: String, value: Variant) -> void:
	data[key] = value
	changed.emit(key)


func inc(key: String, amount: float) -> void:
	set_v(key, get_v(key, 0) + amount)


func show_banner(text: String) -> void:
	banner.emit(text)


func show_toast(text: String) -> void:
	toast.emit(text)


## Estado inicial de una partida nueva en el mundo indicado (newRunState de worlds.js).
func new_run(world: Dictionary, boss: Dictionary = {}) -> void:
	var run := {
		"stars": 0,
		"starsTotal": world.get("stars", []).size() + boss.get("stars", []).size(),
		"collectedStars": [],
		"defeatedEnemies": [],
		"weaponsOwned": [],
		"weapon": null,
		"checkpoint": null,
		"hp": 3,
		"playTime": 0.0,
		"progress": 0.0,
		"specialStar": false,
		"bossVisible": false,
		# Mundo 2: crayones mágicos recogidos (rojo, azul, amarillo)
		"magicCrayons": [],
		"magicTotal": world.get("magicCrayons", []).size(),
		"dreamCollectibles": [],
		"dreamTotal": world.get("dreamCollectibles", []).size(),
		"world": int(world.get("id", 1)),
	}
	for k in run:
		set_v(k, run[k])
