class_name WorldRegistry
## Registro de los ocho mundos (port de data/worlds.js). Todos comparten el mismo motor
## (Level); cada mundo sólo necesita:
##   1. su archivo de datos  data/worlds/worldN.json  (+ worldN_boss.json para su arena),
##   2. una escena ligera que extienda Level (scenes/worlds/WorldN.tscn) y, si tiene jefe,
##      su arena (scenes/bosses/WorldNBoss.tscn),
##   3. su entrada en esta tabla y en Router.SCENES.
## Cada mundo define en sus datos: tileset, fondo, longitud, secciones, enemigos, obstáculos,
## coleccionables, checkpoints, jefe, música y portal de salida.
## De momento sólo el Mundo 1 está implementado; el resto queda reservado.

const WORLDS := [
	{"id": 1, "name": "El Reino de las Nubes de Algodón", "scene": "World1", "data": "res://data/worlds/world1.json", "boss_data": "res://data/worlds/world1_boss.json", "implemented": true},
	{"id": 2, "name": "Mundo 2", "scene": "", "data": "", "boss_data": "", "implemented": false},
	{"id": 3, "name": "Mundo 3", "scene": "", "data": "", "boss_data": "", "implemented": false},
	{"id": 4, "name": "Mundo 4", "scene": "", "data": "", "boss_data": "", "implemented": false},
	{"id": 5, "name": "Mundo 5", "scene": "", "data": "", "boss_data": "", "implemented": false},
	{"id": 6, "name": "Mundo 6", "scene": "", "data": "", "boss_data": "", "implemented": false},
	{"id": 7, "name": "Mundo 7", "scene": "", "data": "", "boss_data": "", "implemented": false},
	{"id": 8, "name": "Mundo 8", "scene": "", "data": "", "boss_data": "", "implemented": false},
]


static func get_world(id: int) -> Dictionary:
	for w in WORLDS:
		if w.id == id:
			return w
	return {}


## Prepara una partida nueva en el mundo indicado y devuelve la clave de su escena.
static func start_run(id: int) -> String:
	var w := get_world(id)
	if w.is_empty() or not w.implemented:
		push_warning("[WorldRegistry] El mundo %d aún no está implementado" % id)
		return ""
	var data: Variant = C.load_json(w.data)
	var boss: Variant = C.load_json(w.boss_data) if w.boss_data != "" else {}
	GameState.new_run(data if data is Dictionary else {}, boss if boss is Dictionary else {})
	return w.scene
