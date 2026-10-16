class_name Router
## Cambio de escena por clave (las mismas claves que las escenas de Phaser).

const SCENES := {
	"Boot": "res://scenes/main/Main.tscn",
	"Menu": "res://scenes/menus/Menu.tscn",
	"World1": "res://scenes/worlds/World1.tscn",
	"Boss": "res://scenes/bosses/World1Boss.tscn",
	"Victory": "res://scenes/menus/Victory.tscn",
}


static func go(key: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if not SCENES.has(key):
		push_error("[Router] Escena desconocida: %s" % key)
		return
	tree.paused = false
	tree.change_scene_to_file(SCENES[key])
