extends Node
## Persistencia del progreso (autoload "SaveManager"). Sustituye a localStorage de Phaser.
##
## Archivo: user://save.json (en Windows: %APPDATA%/Godot/app_userdata/<proyecto>/save.json).
## No toca los datos del juego Phaser (que viven en el localStorage del navegador).
## Carga segura: si el archivo no existe o está mal formado se usan valores por defecto
## (el archivo dañado se conserva como save.json.bad) y el juego sigue funcionando.

const SAVE_PATH := "user://save.json"
const VERSION := 1
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
		for k in p.worlds:
			var w: Variant = p.worlds[k]
			if w is Dictionary and str(k).is_valid_int():
				state.worlds[str(k)] = {
					"completed": bool(w.get("completed", false)),
					"bestStars": int(w.get("bestStars", 0)),
					"totalStars": int(w.get("totalStars", 0)),
					"specialStar": bool(w.get("specialStar", false)),
					"bestTime": float(w.get("bestTime", 0)),
					"completedAt": str(w.get("completedAt", "")),
				}
				if w.get("magicCrayons") is Array:
					state.worlds[str(k)]["magicCrayons"] = w.magicCrayons.filter(func(c): return c is String)
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


func mark_world_completed(world_id: int, stars: int, total_stars: int, special_star := false, time_ms := 0.0, magic_crayons: Array = []) -> void:
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
	state.unlockedWorld = clampi(maxi(int(state.unlockedWorld), world_id + 1), 1, WORLD_COUNT)
	persist()


## Borra el progreso conservando los ajustes de audio (como en Phaser).
func reset_progress() -> void:
	var settings: Dictionary = state.settings.duplicate()
	state = defaults()
	state.settings = settings
	persist()
