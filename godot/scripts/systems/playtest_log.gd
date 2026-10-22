class_name PlaytestLog
extends RefCounted
## Registro opcional para las pruebas jugadas (IMP-034): con el argumento "--playtest"
##   godot --path godot -- --playtest      (o AliceDreams.exe -- --playtest)
## cada golpe, caída, desmayo, sección, checkpoint, inicio y fin de nivel se añade como una fila
## a user://playtest.csv (en Windows %APPDATA%\Godot\app_userdata\<juego>\playtest.csv).
## Sin el argumento no escribe nada. Las filas de una misma ejecución comparten `sesion`.

const HEADER := "sesion,fecha_hora,mundo,escena,seccion,evento,tesela_x,tiempo_nivel_s,vida,detalle"

static var enabled := "--playtest" in OS.get_cmdline_user_args()
static var path := "user://playtest.csv"
static var session := Time.get_datetime_string_from_system().replace(":", "")


## Añade una fila. `level` es el Level (o arena) donde ocurre el evento.
## (Sin tipar como Level: este script lo cargan el jugador y los checkpoints, que el nivel ya
## carga, y el tipo crearía un ciclo de carga entre scripts.)
static func event(level: Node, kind: String, detail := "") -> void:
	if not enabled or not is_instance_valid(level) or not ("data" in level) or level.data == null:
		return
	var new_file := not FileAccess.file_exists(path)
	var f := FileAccess.open(path, FileAccess.WRITE if new_file else FileAccess.READ_WRITE)
	if f == null:
		return
	if new_file:
		f.store_line(HEADER)
	f.seek_end()
	var p = level.player
	var section := ""
	if level.data.sections.size() > 0:
		section = str(level.data.sections[mini(level.section_index, level.data.sections.size() - 1)].id)
	f.store_line(",".join([
		session, Time.get_datetime_string_from_system(), str(GameState.get_v("world", "")), str(level.data.get("key", "")),
		section, kind, str(int(p.position.x / C.TILE)) if p else "", "%.1f" % (level.now / 1000.0),
		str(p.hp) if p else "", '"%s"' % detail.replace('"', "'"),
	]))
	# se cierra ya: en Windows otro programa (o la prueba) no puede leerlo mientras esté abierto
	f.close()
