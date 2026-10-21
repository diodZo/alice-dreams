class_name RescuedCreatureManager
extends RefCounted
## Rescate de criaturas de un nivel (uno por escena, como CheckpointManager). Alice no destruye a
## los monstruos: al vencer a una criatura rescatable (DreamNarrative.rescuable) se libera de la
## pesadilla. Se llama desde Enemy._enter_DEFEATED, tanto en la derrota normal como al convertir
## en estrella a un monstruo atrapado en una burbuja (la estrella extra no cambia).
##
## Un rescate es válido una sola vez por enemigo: el enemigo se marca y su id de aparición se
## guarda en GameState ("rescued": {id de aparición: tipo}), que sobrevive a "Volver al
## checkpoint". El tipo se guarda además en SaveManager (sólo la primera vez en cada mundo).

signal creature_rescued(world_id: int, creature_id: String)

const RESCUED_SCENE := preload("res://scenes/narrative/RescuedCreature.tscn")
## Tras la derrota normal el monstruo tarda ~1,1 s en desvanecerse (Enemy._enter_DEFEATED):
## la forma liberada aparece cuando ya se está desvaneciendo.
const NORMAL_DELAY_MS := 750.0

var level: Node


func _init(owner_level: Node) -> void:
	level = owner_level


func world_id() -> int:
	return int(GameState.get_v("world", 1))


## Rescates de esta partida en este mundo: {id de aparición: tipo}.
static func run_rescues() -> Dictionary:
	var d: Variant = GameState.get_v("rescued", {})
	return d if d is Dictionary else {}


## Tipos rescatados en esta partida, uno por criatura (para la celebración).
static func run_creatures() -> Array:
	return run_rescues().values()


## Intenta rescatar al enemigo vencido. Devuelve true si el rescate es nuevo y válido.
func try_rescue(enemy: Enemy, to_star := false) -> bool:
	if enemy == null or enemy.rescue_done:
		return false
	var type := enemy.enemy_type
	var wid := world_id()
	if not DreamNarrative.is_rescuable(wid, type):
		return false
	var spawn_id := str(enemy.spawn.get("id", "node:%d" % enemy.get_instance_id()))
	var rescues := run_rescues().duplicate()
	if rescues.has(spawn_id):
		return false
	enemy.rescue_done = true
	rescues[spawn_id] = type
	GameState.set_v("rescued", rescues)
	SaveManager.add_rescued(wid, type)
	_show(enemy, type, to_star)
	creature_rescued.emit(wid, type)
	return true


## Efecto de liberación: independiente del nodo del enemigo (que se libera enseguida).
func _show(enemy: Enemy, type: String, to_star: bool) -> void:
	var pos := Vector2(enemy.position.x, enemy.position.y)
	var flip := enemy.sprite.flip_h
	var spawn_fx := func():
		if not is_instance_valid(level) or level.fx_root == null:
			return
		var fx: RescuedCreature = RESCUED_SCENE.instantiate()
		fx.setup(type, pos, flip)
		level.fx_root.add_child(fx)
	if to_star:
		spawn_fx.call()
	else:
		level.after(NORMAL_DELAY_MS, spawn_fx)
