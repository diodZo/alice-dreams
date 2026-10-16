class_name CheckpointManager
extends RefCounted
## Puntos de control de una escena: activación y punto de reaparición
## (port de systems/CheckpointManager.js). El último checkpoint se guarda en GameState para
## sobrevivir a reinicios de escena ("Volver al checkpoint" en el menú de pausa).

var level: Node
var scene_key := ""
var start := Vector2.ZERO
var flags: Array[Checkpoint] = []
var current: Variant = null


func _init(owner_level: Node, defs: Array, atlas: String, key: String, start_point: Vector2, parent: Node) -> void:
	level = owner_level
	scene_key = key
	start = start_point
	for i in defs.size():
		var f := Checkpoint.new().setup(level, defs[i], atlas, i)
		parent.add_child(f)
		flags.append(f)
	var saved: Variant = GameState.get_v("checkpoint")
	if saved is Dictionary and saved.get("scene") == scene_key:
		current = saved
		for f in flags:
			if f.index <= int(saved.index):
				f.activate(true)


## Punto de reaparición actual (checkpoint o inicio de la escena).
func respawn_point() -> Vector2:
	if current is Dictionary:
		return Vector2(current.x, current.y)
	return start


func activate(flag: Checkpoint) -> void:
	if not flag.activate():
		return
	if current is Dictionary and int(current.index) >= flag.index:
		return
	current = {"scene": scene_key, "index": flag.index, "x": flag.respawn.x, "y": flag.respawn.y}
	GameState.set_v("checkpoint", current)
	AudioManager.play("checkpoint")
	GameState.show_toast("¡Punto de control!")
	# al tocar un checkpoint se recupera la vida
	level.player.heal(true)
