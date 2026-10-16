class_name WorldRegistry
## Registro de los ocho mundos (port de data/worlds.js). Todos comparten el mismo motor
## (Level); cada mundo sólo necesita:
##   1. su archivo de datos  data/worlds/worldN.json  (+ worldN_boss.json para su arena),
##   2. una escena ligera que extienda Level (scenes/worlds/WorldN.tscn) y, si tiene jefe,
##      su arena (scenes/bosses/WorldNBoss.tscn),
##   3. su entrada en esta tabla y en Router.SCENES.
## Cada mundo define en sus datos: tileset, fondo, longitud, secciones, enemigos, obstáculos,
## coleccionables, checkpoints, jefe, música y portal de salida.
## Implementados: Mundo 1 y Mundo 2; el resto queda reservado.
## Campos de presentación (menú y pantalla de victoria): victoryTitle, victorySub, bossFrames,
## bossFrame (fotograma del jefe vencido), nextPortal, victoryMusic.

const WORLDS := [
	{"id": 1, "name": "El Reino de las Nubes de Algodón", "scene": "World1", "data": "res://data/worlds/world1.json", "boss_data": "res://data/worlds/world1_boss.json", "implemented": true,
		"victoryTitle": "¡Mundo 1 completado!", "victorySub": "Nubarrón vuelve a ser una nube feliz",
		"bossFrames": "nubarron", "bossAnim": "idle", "bossFrame": 1, "bossScale": 0.5,
		"nextPortal": "Portal al Mundo 2: abierto", "victoryMusic": "menu"},
	{"id": 2, "name": "El Reino de los Crayones Encantados", "scene": "World2", "data": "res://data/world2/world2.json", "boss_data": "res://data/world2/world2_boss.json", "implemented": true,
		"victoryTitle": "¡Mundo 2 completado!", "victorySub": "Garabato devuelve los colores al lienzo",
		"bossFrames": "garabato", "bossAnim": "idle", "bossFrame": 1, "bossScale": 0.5,
		"nextPortal": "Portal al Mundo 3: abierto (próximamente)", "victoryMusic": "world2_victory"},
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
	if data is Dictionary and data.has("startWeapons"):
		GameState.set_v("weaponsOwned", data.startWeapons.duplicate())
		GameState.set_v("weapon", data.startWeapons[0])
	return w.scene


## ¿Se puede jugar? (implementado y desbloqueado en el guardado)
static func is_playable(id: int) -> bool:
	var w := get_world(id)
	return not w.is_empty() and w.implemented and id <= SaveManager.unlocked_world()
