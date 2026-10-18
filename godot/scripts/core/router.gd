class_name Router
## Cambio de escena por clave (las mismas claves que las escenas de Phaser).

const SCENES := {
	"Boot": "res://scenes/main/Main.tscn",
	"Menu": "res://scenes/menus/Menu.tscn",
	"WorldMap": "res://scenes/menus/WorldMap.tscn",
	"World1": "res://scenes/worlds/World1.tscn",
	"Boss": "res://scenes/bosses/World1Boss.tscn",
	"Victory": "res://scenes/menus/Victory.tscn",
	"World2": "res://scenes/worlds/World2.tscn",
	"Boss2": "res://scenes/bosses/World2Boss.tscn",
	"World3": "res://scenes/worlds/World3.tscn",
	"Boss3": "res://scenes/bosses/World3Boss.tscn",
	"World4": "res://scenes/worlds/World4.tscn",
	"Boss4": "res://scenes/bosses/World4Boss.tscn",
	"World5": "res://scenes/worlds/World5.tscn",
	"Boss5": "res://scenes/bosses/World5Boss.tscn",
}


static func go(key: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not SCENES.has(key):
		push_error("[Router] Escena desconocida: %s" % key)
		return
	tree.paused = false
	tree.change_scene_to_file(SCENES[key])
