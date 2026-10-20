extends Node
## Persistencia del progreso (autoload "SaveManager"). Sustituye a localStorage de Phaser.
##
## Archivo: user://save.json (en Windows: %APPDATA%/Godot/app_userdata/<proyecto>/save.json).
## No toca los datos del juego Phaser (que viven en el localStorage del navegador).
## Carga segura: si el archivo no existe o está mal formado se usan valores por defecto
## (el archivo dañado se conserva como save.json.bad) y el juego sigue funcionando.

const SAVE_PATH := "user://save.json"
## 2: los Mundos 5 y 6 intercambiaron su número (Juguetes pasó a ser el 5 y Parque de las
## Estrellas el 6, como en la ilustración); un guardado de la versión 1 se convierte al cargarlo.
const VERSION := 2
const WORLD_COUNT := 8

var state: Dictionary = {}
var storage_ok := true
var save_path := SAVE_PATH


func _ready() -> void:
	load_state()


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		# Primer mundo jugable que aún no se ha completado (se desbloquea el siguiente al completar uno).
		"unlockedWorld": 1,
		# { "1": { completed, bestStars, totalStars, specialStar, bestTime, completedAt } }
		"worlds": {},
		"settings": {"music": true, "sfx": true},
		# Mundo 8: victoria final (desbloquea volver a ver el final desde el menú). Campos nuevos:
		# un guardado anterior se carga igual (valores por defecto) y no pierde nada.
		"adventureCompleted": false,
		"adventureCompletedAt": "",
	}


func load_state() -> Dictionary:
	state = defaults()
	if not FileAccess.file_exists(save_path):
		return state
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		storage_ok = false
		push_warning("[SaveManager] No se pudo leer el progreso guardado (%d)" % FileAccess.get_open_error())
		return state
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("[SaveManager] Archivo de guardado mal formado: se usan valores por defecto")
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".bad"))
		return state
	_merge(parsed)
	return state


## Mezcla sólo los campos válidos sobre los valores por defecto.
func _merge(p: Dictionary) -> void:
	if p.get("unlockedWorld") is float or p.get("unlockedWorld") is int:
		state.unlockedWorld = clampi(int(p.unlockedWorld), 1, WORLD_COUNT)
	if p.get("worlds") is Dictionary:
		var old_numbering := int(p.get("version", 1)) < 2
		for k in p.worlds:
			var w: Variant = p.worlds[k]
			if w is Dictionary and str(k).is_valid_int():
				var key := str(k)
				if old_numbering and key in ["5", "6"]:
					key = "6" if key == "5" else "5"
				state.worlds[key] = {
					"completed": bool(w.get("completed", false)),
					"bestStars": int(w.get("bestStars", 0)),
					"totalStars": int(w.get("totalStars", 0)),
					"specialStar": bool(w.get("specialStar", false)),
					"bestTime": float(w.get("bestTime", 0)),
					"completedAt": str(w.get("completedAt", "")),
				}
				if w.get("magicCrayons") is Array:
					state.worlds[key]["magicCrayons"] = w.magicCrayons.filter(func(c): return c is String)
				if w.get("dreamCollectibles") is Array:
					state.worlds[key]["dreamCollectibles"] = w.dreamCollectibles.filter(func(c): return c is String)
	if p.get("adventureCompleted") is bool:
		state.adventureCompleted = p.adventureCompleted
		state.adventureCompletedAt = str(p.get("adventureCompletedAt", ""))
	if p.get("settings") is Dictionary:
		for k in ["music", "sfx"]:
			if p.settings.get(k) is bool:
				state.settings[k] = p.settings[k]


func persist() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		if storage_ok:
			push_warning("[SaveManager] No se pudo guardar el progreso (%d)" % FileAccess.get_open_error())
		storage_ok = false
		return
	f.store_string(JSON.stringify(state, "\t"))
	f.close()
	storage_ok = true


func is_storage_available() -> bool:
	return storage_ok


func get_setting(setting: String) -> Variant:
	return state.settings.get(setting)


func set_setting(setting: String, value: Variant) -> void:
	state.settings[setting] = value
	persist()


func is_world_completed(world_id: int) -> bool:
	return bool(get_world(world_id).get("completed", false))


func get_world(world_id: int) -> Dictionary:
	return state.worlds.get(str(world_id), {})


func unlocked_world() -> int:
	return int(state.unlockedWorld)


func mark_world_completed(world_id: int, stars: int, total_stars: int, special_star := false, time_ms := 0.0, magic_crayons: Array = [], dream_collectibles: Array = []) -> void:
	var prev := get_world(world_id)
	var best_time: float = prev.get("bestTime", 0.0)
	if time_ms > 0 and (best_time <= 0 or time_ms < best_time):
		best_time = time_ms
	state.worlds[str(world_id)] = {
		"completed": true,
		"bestStars": maxi(int(prev.get("bestStars", 0)), stars),
		"totalStars": total_stars,
		"specialStar": bool(prev.get("specialStar", false)) or special_star,
		"bestTime": best_time,
		"completedAt": Time.get_datetime_string_from_system(true),
	}
	# Mundo 2: crayones mágicos (se acumulan entre partidas)
	var prev_magic: Array = prev.get("magicCrayons", [])
	if not magic_crayons.is_empty() or not prev_magic.is_empty():
		var all := prev_magic.duplicate()
		for c in magic_crayons:
			if not c in all:
				all.append(c)
		state.worlds[str(world_id)]["magicCrayons"] = all
	var prev_dream: Array = prev.get("dreamCollectibles", [])
	if not dream_collectibles.is_empty() or not prev_dream.is_empty():
		var all_dream := prev_dream.duplicate()
		for item in dream_collectibles:
			if not item in all_dream:
				all_dream.append(item)
		state.worlds[str(world_id)]["dreamCollectibles"] = all_dream
	state.unlockedWorld = clampi(maxi(int(state.unlockedWorld), world_id + 1), 1, WORLD_COUNT)
	persist()


## Final de la aventura (al abrazar al gato morado): registra la victoria final. El progreso de
## los mundos ya se guardó con mark_world_completed; no se desbloquea ningún mundo más.
func mark_adventure_completed() -> void:
	state.adventureCompleted = true
	if str(state.get("adventureCompletedAt", "")) == "":
		state.adventureCompletedAt = Time.get_datetime_string_from_system(true)
	persist()


## ¿Se ha terminado la aventura? (desbloquea "Ver el final" en el menú)
func is_adventure_completed() -> bool:
	return bool(state.get("adventureCompleted", false))


## Borra el progreso conservando los ajustes de audio (como en Phaser).
func reset_progress() -> void:
	var settings: Dictionary = state.settings.duplicate()
	state = defaults()
	state.settings = settings
	persist()
