class_name DreamJournalManager
## Diario de Sueños: una página por mundo (orden y nombres de WorldRegistry). Sin estado propio:
## todo se calcula desde SaveManager, así que el diario siempre refleja el guardado real.
##  - Una página se desbloquea exclusivamente cuando el mundo está completado.
##  - "Nueva" = desbloqueada y aún no vista (SaveManager.journal.seen).

## Totales de secretos por mundo (se leen una vez de sus datos).
static var _secret_totals := {}
static var _boss_names := {}


static func world_ids() -> Array:
	var ids: Array = []
	for w in WorldRegistry.WORLDS:
		ids.append(int(w.id))
	return ids


static func entry(world_id: int) -> DreamJournalEntry:
	var e := DreamJournalEntry.new()
	var w := WorldRegistry.get_world(world_id)
	var n := DreamNarrative.get_world(world_id)
	var save := SaveManager.get_world(world_id)
	e.world_id = world_id
	e.name = w.get("name", "")
	e.short_name = w.get("short", e.name)
	e.unlocked = SaveManager.is_world_completed(world_id)
	e.is_new = e.unlocked and not world_id in SaveManager.journal_seen()
	e.boss_name = _boss_name(world_id)
	e.boss_purified = e.unlocked
	e.purified_form = n.get("purified", "")
	e.boss_frames = w.get("bossFrames", "")
	e.boss_anim = w.get("bossAnim", "idle")
	e.boss_frame = int(w.get("bossFrame", 0))
	e.reflection = n.get("reflection", "")
	e.rescuable = DreamNarrative.rescuable(world_id)
	e.rescued = SaveManager.get_rescued(world_id).filter(func(c): return c in e.rescuable)
	e.secrets_total = _secret_total(world_id)
	e.secrets_found = mini(e.secrets_total, save.get("magicCrayons", []).size() + save.get("dreamCollectibles", []).size())
	e.best_stars = int(save.get("bestStars", 0))
	e.total_stars = int(save.get("totalStars", 0))
	e.special_star = bool(save.get("specialStar", false))
	return e


static func entries() -> Array[DreamJournalEntry]:
	var list: Array[DreamJournalEntry] = []
	for id in world_ids():
		list.append(entry(id))
	return list


static func unlocked_count() -> int:
	return entries().filter(func(e): return e.unlocked).size()


static func is_new_page(world_id: int) -> bool:
	return SaveManager.is_world_completed(world_id) and not world_id in SaveManager.journal_seen()


static func has_new_pages() -> bool:
	for id in world_ids():
		if is_new_page(id):
			return true
	return false


static func mark_seen(world_id: int) -> void:
	if SaveManager.is_world_completed(world_id):
		SaveManager.mark_journal_seen(world_id)


## Diario completo: las ocho páginas completas (variante opcional del final).
static func is_complete() -> bool:
	for e in entries():
		if not e.is_complete():
			return false
	return true


static func _secret_total(world_id: int) -> int:
	if not _secret_totals.has(world_id):
		var data: Variant = C.load_json(WorldRegistry.get_world(world_id).get("data", ""))
		var total := 0
		if data is Dictionary:
			total = data.get("magicCrayons", []).size() + data.get("dreamCollectibles", []).size()
		_secret_totals[world_id] = total
	return _secret_totals[world_id]


static func _boss_name(world_id: int) -> String:
	if not _boss_names.has(world_id):
		var data: Variant = C.load_json(WorldRegistry.get_world(world_id).get("boss_data", ""))
		var boss: Dictionary = data.get("boss", {}) if data is Dictionary else {}
		# la arena del Mundo 1 no declara el nombre: el valor por defecto vive en boss_arena.gd
		_boss_names[world_id] = str(boss.get("name", load("res://scripts/levels/boss_arena.gd").DEFAULT_BOSS_NAME))
	return _boss_names[world_id]
