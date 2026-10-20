class_name EnemySpawner
extends RefCounted
## Activación por distancia (port de systems/EnemySpawner.js): crea los enemigos sólo cuando
## la cámara se acerca a su posición y los retira cuando quedan muy lejos, con un máximo de
## enemigos activos simultáneos. Los enemigos derrotados no reaparecen.

const SCENES := {
	"scratch": preload("res://scenes/enemies/Scratch.tscn"),
	"spit": preload("res://scenes/enemies/Spit.tscn"),
	"flea": preload("res://scenes/enemies/Flea.tscn"),
	# Mundo 2
	"eraser": preload("res://scenes/enemies/world2/Eraser.tscn"),
	"crayon": preload("res://scenes/enemies/world2/Crayon.tscn"),
	"brush": preload("res://scenes/enemies/world2/Brush.tscn"),
	# Mundo 3
	"rabbit": preload("res://scenes/enemies/world3/Rabbit.tscn"),
	"wool": preload("res://scenes/enemies/world3/Wool.tscn"),
	"pillow": preload("res://scenes/enemies/world3/Pillow.tscn"),
	# Mundo 4
	"bubble_fish": preload("res://scenes/enemies/world4/BubbleFish.tscn"),
	"sponge_crab": preload("res://scenes/enemies/world4/SpongeCrab.tscn"),
	"pompa": preload("res://scenes/enemies/world4/Pompa.tscn"),
	# Mundo 5
	"estrellita": preload("res://scenes/enemies/world5/Estrellita.tscn"),
	"meteorito": preload("res://scenes/enemies/world5/Meteorito.tscn"),
	"cohetito": preload("res://scenes/enemies/world5/Cohetito.tscn"),
	# Mundo 6
	"payasito": preload("res://scenes/enemies/world6/Payasito.tscn"),
	"bloquecito": preload("res://scenes/enemies/world6/Bloquecito.tscn"),
	"vagoncito": preload("res://scenes/enemies/world6/Vagoncito.tscn"),
	# Mundo 7
	"cuppy": preload("res://scenes/enemies/world7/Cuppy.tscn"),
	"gomilito": preload("res://scenes/enemies/world7/Gomilito.tscn"),
	"gomilito_mini": preload("res://scenes/enemies/world7/GomilitoMini.tscn"),
	"piruleta": preload("res://scenes/enemies/world7/Piruleta.tscn"),
	# Mundo 8
	"fantasmita": preload("res://scenes/enemies/world8/Fantasmita.tscn"),
	"murcibola": preload("res://scenes/enemies/world8/Murcibola.tscn"),
	"bloquito": preload("res://scenes/enemies/world8/BloquitoSombra.tscn"),
}

var level: Node
var parent: Node
var max_active := 6
var margin := 80.0
var pending: Array = []
var defeated := {}
var active := {}
var started := false


func _init(owner_level: Node, spawns: Array, container: Node, max_enemies := 6, view_margin := 80.0) -> void:
	level = owner_level
	parent = container
	max_active = max_enemies
	margin = view_margin
	pending = spawns
	for id in GameState.get_v("defeatedEnemies", []):
		defeated[id] = true


func on_enemy_finished(enemy: Enemy) -> void:
	var id: String = enemy.spawn.id
	defeated[id] = true
	active.erase(id)
	GameState.set_v("defeatedEnemies", defeated.keys())


func update() -> void:
	var view: Rect2 = level.camera.view_rect()
	var sx := view.position.x
	var left := sx - margin
	var right := sx + C.GAME_W + margin
	for s in pending:
		if active.size() >= max_active:
			break
		if defeated.has(s.id) or active.has(s.id):
			continue
		var x: float = s.x
		if x >= left and x <= right and (x < sx - 8 or x > sx + C.GAME_W + 8):
			# sólo aparecen fuera del encuadre, nunca de golpe delante de la protagonista
			spawn(s)
		elif x >= left and x <= right and not started:
			spawn(s)
	started = true
	for id in active.keys():
		# sin tipo: la entrada puede ser un nodo ya liberado (gomitas añadidas al vuelo)
		var e = active[id]
		if not is_instance_valid(e) or e.finished:
			active.erase(id)
			continue
		if e.position.x < sx - margin * 4 or e.position.x > sx + C.GAME_W + margin * 4:
			e.despawn()
			active.erase(id)


func spawn(s: Dictionary) -> void:
	if not SCENES.has(s.type):
		push_error("[EnemySpawner] Tipo de enemigo desconocido: %s" % s.type)
		defeated[s.id] = true
		return
	var e: Enemy = SCENES[s.type].instantiate()
	e.setup(level, s)
	parent.add_child(e)
	active[s.id] = e


## Al reaparecer en un checkpoint se retiran todos y vuelven a aparecer al acercarse.
func reset_active() -> void:
	for e in active.values():
		if is_instance_valid(e) and not e.finished:
			e.despawn()
	active.clear()
	started = false
