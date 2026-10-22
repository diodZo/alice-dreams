class_name WorldRegistry
## Registro de los ocho mundos (port de data/worlds.js). Todos comparten el mismo motor
## (Level); cada mundo sólo necesita:
##   1. su archivo de datos  data/worlds/worldN.json  (+ worldN_boss.json para su arena),
##   2. una escena ligera que extienda Level (scenes/worlds/WorldN.tscn) y, si tiene jefe,
##      su arena (scenes/bosses/WorldNBoss.tscn),
##   3. su entrada en esta tabla y en Router.SCENES.
## Cada mundo define en sus datos: tileset, fondo, longitud, secciones, enemigos, obstáculos,
## coleccionables, checkpoints, jefe, música y portal de salida.
## Implementados: los ocho mundos. El Mundo 8 es el final de la historia: no desbloquea ningún
## mundo más (SaveManager.WORLD_COUNT = 8) y termina con la cinemática y los créditos.
## El número de mundo (id) sigue la ilustración del menú y el orden de juego; los archivos
## conservan el nombre con que se crearon: el Mundo 5 (Juguetes) usa World6 / data/world6 y
## el Mundo 6 (Parque de las Estrellas) usa World5 / data/world5.
## Campos de presentación (menú y pantalla de victoria): victoryTitle, victorySub, bossFrames,
## bossFrame (fotograma del jefe vencido), nextPortal, victoryMusic. "short": nombre corto.

const WORLDS := [
	{"id": 1, "name": "El Reino de las Nubes de Algodón", "short": "Nubes de Algodón", "scene": "World1", "data": "res://data/worlds/world1.json", "boss_data": "res://data/worlds/world1_boss.json", "implemented": true,
		"victoryTitle": "¡Mundo 1 completado!", "victorySub": "Nubarrón vuelve a ser una nube feliz",
		"bossFrames": "nubarron", "bossAnim": "idle", "bossFrame": 1, "bossScale": 0.5,
		"nextPortal": "Portal al Mundo 2: abierto", "victoryMusic": "menu"},
	{"id": 2, "name": "El Reino de los Crayones Encantados", "short": "Crayones", "scene": "World2", "data": "res://data/world2/world2.json", "boss_data": "res://data/world2/world2_boss.json", "implemented": true,
		"victoryTitle": "¡Mundo 2 completado!", "victorySub": "Garabato devuelve los colores al lienzo",
		"bossFrames": "garabato", "bossAnim": "idle", "bossFrame": 1, "bossScale": 0.5,
		"nextPortal": "Portal al Mundo 3: abierto", "victoryMusic": "world2_victory"},
	{"id": 3, "name": "El Reino de los Peluches Dormilones", "short": "Peluches", "scene": "World3", "data": "res://data/world3/world3.json", "boss_data": "res://data/world3/world3_boss.json", "implemented": true,
		"victoryTitle": "¡Mundo 3 completado!", "victorySub": "El Rey Siestón duerme feliz otra vez",
		"bossFrames": "sieston", "bossAnim": "defeated", "bossFrame": 2, "bossScale": 0.5,
		"nextPortal": "Portal al Mundo 4: abierto", "victoryMusic": "world3_victory"},
	{"id": 4, "name": "Reino de las Burbujas", "short": "Océano de Burbujas", "scene": "World4", "data": "res://data/world4/world4.json", "boss_data": "res://data/world4/world4_boss.json", "implemented": true,
		"victoryTitle": "¡Mundo 4 completado!", "victorySub": "El Rey Patoburbuja duerme feliz entre la espuma",
		"bossFrames": "patoburbuja", "bossAnim": "defeated", "bossFrame": 0, "bossScale": 0.6,
		"nextPortal": "Portal al Mundo 5: abierto", "victoryMusic": "world4_victory"},
	{"id": 5, "name": "El Reino del Tren de Juguete", "short": "Juguetes", "scene": "World6", "data": "res://data/world6/world6.json", "boss_data": "res://data/world6/world6_boss.json", "implemented": true,
		"victoryTitle": "¡Mundo 5 completado!", "victorySub": "Locomostro duerme feliz en la Gran Estación",
		"bossFrames": "locomostro", "bossAnim": "defeated", "bossFrame": 2, "bossScale": 0.5,
		"nextPortal": "Portal al Mundo 6: abierto", "victoryMusic": "world6_victory"},
	{"id": 6, "name": "Sueños Cósmicos — Islas en el Cielo", "short": "Parque de las Estrellas", "scene": "World5", "data": "res://data/world5/world5.json", "boss_data": "res://data/world5/world5_boss.json", "implemented": true,
		"victoryTitle": "¡Mundo 6 completado!", "victorySub": "Luna Estelar duerme feliz entre las nubes",
		"bossFrames": "luna_estelar", "bossAnim": "defeated", "bossFrame": 1, "bossScale": 0.6,
		"nextPortal": "Portal al Mundo 7: abierto", "victoryMusic": "world5_victory"},
	{"id": 7, "name": "El Valle de Caramelo", "short": "Bosque de Caramelos", "scene": "World7", "data": "res://data/world7/world7.json", "boss_data": "res://data/world7/world7_boss.json", "implemented": true,
		"victoryTitle": "¡Mundo 7 completado!", "victorySub": "Don Chupetón duerme feliz convertido en pastelito",
		"bossFrames": "don_chupeton", "bossAnim": "defeated", "bossFrame": 1, "bossScale": 0.5,
		"nextPortal": "Portal al Mundo 8: abierto", "victoryMusic": "world7_victory"},
	{"id": 8, "name": "El Castillo de las Pesadillas", "short": "Castillo de los Sueños", "scene": "World8", "data": "res://data/world8/world8.json", "boss_data": "res://data/world8/world8_boss.json", "implemented": true,
		"victoryTitle": "¡Aventura completada!", "victorySub": "El Rey Pesadelo era un gatito que sólo quería un abrazo",
		"bossFrames": "gato_morado", "bossAnim": "purr", "bossFrame": 0, "bossScale": 1.2,
		"nextPortal": "Has terminado Alice Dreams", "victoryMusic": "alice_credits", "final": true},
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


## Reanuda la partida guardada del mundo en su último checkpoint (IMP-016). Devuelve la escena
## ("" si no hay partida guardada de ese mundo).
static func resume_run(id: int) -> String:
	var r := SaveManager.get_resume(id)
	if r.is_empty() or start_run(id) == "":
		return ""
	for k in r.run:
		GameState.set_v(k, r.run[k])
	return r.scene


## Número de mundo de una escena de Router ("World6" -> 5, "Boss6" -> 5, "Boss" -> 1).
static func id_for_scene(key: String) -> int:
	var scene := "World1" if key == "Boss" else key.replace("Boss", "World")
	for w in WORLDS:
		if w.scene == scene:
			return w.id
	return 1


## ¿Se puede jugar? (implementado y desbloqueado en el guardado)
static func is_playable(id: int) -> bool:
	var w := get_world(id)
	return not w.is_empty() and w.implemented and id <= SaveManager.unlocked_world()
