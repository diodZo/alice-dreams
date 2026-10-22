extends "res://tests/test_base.gd"
## Pruebas automáticas — Narrativa (criaturas rescatadas, Diario de Sueños, purificación y final). Las lanza run_tests.gd (en este orden).

const TESTS := [
	"test_narrative_registry", "test_narrative_save_compat", "test_narrative_rescue_once", "test_narrative_rescue_weapons",
	"test_narrative_boss_purification", "test_narrative_all_bosses_purify", "test_narrative_journal", "test_narrative_celebration_pick",
	"test_narrative_ending",
]


## Sólo las claves de enemigos de los datos de un mundo (fuente: WorldRegistry).
func _world_enemy_types(world_id: int) -> Array:
	var data: Dictionary = C.load_json(WorldRegistry.get_world(world_id).data)
	var types: Array = []
	for e in data.enemies:
		if not e.type in types:
			types.append(e.type)
	return types


func test_narrative_registry() -> void:
	check(DreamNarrative.world_ids().size() == 8, "datos narrativos de los ocho mundos")
	for w in WorldRegistry.WORLDS:
		var id := int(w.id)
		var n := DreamNarrative.get_world(id)
		var types := _world_enemy_types(id)
		var rescuable := DreamNarrative.rescuable(id)
		check(rescuable.size() >= 1 and rescuable.size() < types.size(), "Mundo %d: criaturas representativas, no todas (%d de %d)" % [id, rescuable.size(), types.size()])
		for c in rescuable:
			check(c in types and EnemySpawner.SCENES.has(c), "Mundo %d: %s aparece en los datos de ese mundo (numeración 5/6 respetada)" % [id, c])
			check(DreamNarrative.creature_name(c) != c, "Mundo %d: %s tiene nombre visible (EnemyDef)" % [id, c])
		check(not "gomilito_mini" in rescuable, "las gomitas no son rescatables")
		check(String(n.get("reflection", "")) != "" and String(n.get("purified", "")) != "", "Mundo %d: reflexión y forma purificada" % id)
		check(DreamNarrative.memento_texture(id) != null, "Mundo %d: el recuerdo/sticker usa un recurso existente" % id)


func test_narrative_save_compat() -> void:
	SaveManager.reset_progress()
	# guardado de la versión anterior (sin campos narrativos) y con numeración antigua
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 2, "unlockedWorld": 3, "worlds": {"1": {"completed": true, "bestStars": 90, "totalStars": 144, "specialStar": true, "bestTime": 1000}, "2": {"completed": true, "bestStars": 50, "magicCrayons": ["red"]}}, "settings": {"music": false, "sfx": true}}))
	f.close()
	SaveManager.load_state()
	check(SaveManager.is_world_completed(1) and SaveManager.get_world(1).bestStars == 90 and SaveManager.unlocked_world() == 3, "un guardado anterior conserva su progreso")
	check(SaveManager.get_setting("music") == false, "y sus ajustes")
	check(SaveManager.get_rescued(1).is_empty() and SaveManager.journal_seen().is_empty(), "los campos narrativos empiezan vacíos")
	check(int(SaveManager.state.narrativeVersion) == DreamNarrative.VERSION, "versión narrativa por defecto")
	check(SaveManager.add_rescued(1, "scratch") and not SaveManager.add_rescued(1, "scratch"), "una criatura se registra una sola vez")
	SaveManager.add_rescued(3, "rabbit")
	check(not SaveManager.is_world_completed(3) and SaveManager.unlocked_world() == 3, "rescatar no completa ni desbloquea mundos")
	SaveManager.mark_world_completed(1, 10, 144)
	SaveManager.mark_journal_seen(1)
	SaveManager.load_state()
	check(SaveManager.get_rescued(1) == ["scratch"] and SaveManager.get_rescued(3) == ["rabbit"], "los rescates persisten tras recargar y tras completar el mundo")
	check(SaveManager.get_world(1).bestStars == 90, "completar otra vez no pierde la mejor marca")
	check(SaveManager.journal_seen() == [1], "las páginas vistas persisten")
	# datos inválidos en los campos nuevos: se ignoran sin fallar
	f = FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"worlds": {"1": {"completed": true, "rescued": ["spit", 7, null, "spit"]}}, "journal": {"seen": ["x", 2, 2.0]}}))
	f.close()
	SaveManager.load_state()
	check(SaveManager.get_rescued(1) == ["spit"] and SaveManager.journal_seen() == [2], "campos narrativos dañados se limpian")
	SaveManager.reset_progress()
	check(SaveManager.get_rescued(1).is_empty() and SaveManager.journal_seen().is_empty(), "borrar progreso borra también la narrativa")


func test_narrative_rescue_once() -> void:
	SaveManager.reset_progress()
	await load_level("World1", _with_weapons)
	await settle()
	_clear_spawner()
	place(60, 20)
	var events: Array = []
	level.rescues.creature_rescued.connect(func(w, c): events.append([w, c]))
	var e := _spawn_enemy("scratch", 66, 20)
	e.def = e.def.duplicate()
	e.def.detect_range = 0
	await frames(3)
	e.take_damage(10, 1)
	check(not e.is_alive() and e.rescue_done, "derrota normal: la criatura queda liberada")
	check(events == [[1, "scratch"]], "creature_rescued(1, scratch) se emite una vez")
	check(RescuedCreatureManager.run_rescues().get("test:scratch") == "scratch", "el rescate se anota en la partida")
	check(SaveManager.get_rescued(1) == ["scratch"], "y en el guardado")
	# señales duplicadas o colisiones posteriores no cuentan otra vez
	check(not level.rescue_creature(e), "el mismo enemigo no se rescata dos veces")
	var twin := _spawn_enemy("scratch", 70, 20)
	twin.take_damage(10, 1)
	check(events.size() == 1 and RescuedCreatureManager.run_rescues().size() == 1, "una aparición ya rescatada no se cuenta otra vez")
	var flea := _spawn_enemy("flea", 62, 20)
	flea.take_damage(10, 1)
	check(not flea.rescue_done and events.size() == 1, "las criaturas no seleccionadas sólo se derrotan, como siempre")
	await frames(50)
	var fx: Array = level.fx_root.get_children().filter(func(n): return n is RescuedCreature)
	check(fx.size() == 1 and fx[0].creature_id == "scratch", "aparece la forma liberada de la criatura")
	check(not level.player.frozen and level.controls.enabled, "el rescate no detiene a Alice")
	await frames(130)
	fx = level.fx_root.get_children().filter(func(n): return n is RescuedCreature)
	check(fx.is_empty(), "y desaparece sola sin bloquear el avance")
	SaveManager.reset_progress()


func test_narrative_rescue_weapons() -> void:
	SaveManager.reset_progress()
	await load_level("World1", _with_weapons)
	await settle()
	_clear_spawner()
	place(60, 20)
	# Lanzaburbujas: atrapa y, al tocarlo, estrella extra + rescate
	var e := _spawn_enemy("scratch", 66, 20)
	e.spawn.id = "test:bubble"
	e.def = e.def.duplicate()
	e.def.detect_range = 0
	await frames(5)
	press("fire")
	await frames(30)
	check(e.is_trapped(), "la burbuja atrapa a la criatura")
	level.player.position.x = e.position.x
	await frames(5)
	check(level.bonus_root.get_child_count() == 1, "la estrella extra sigue apareciendo (sin duplicarse)")
	check(RescuedCreatureManager.run_rescues().has("test:bubble"), "Lanzaburbujas: la criatura queda liberada")
	# Lanzapintura y Tirachinas: daño normal hasta la derrota
	for w in ["paint", "sling"]:
		var s := _spawn_enemy("spit", 66, 20)
		s.spawn.id = "test:%s" % w
		while s.is_alive():
			s.hit_by(_w8_shot(w))
		check(RescuedCreatureManager.run_rescues().has("test:%s" % w), "%s: la criatura queda liberada" % w)
	check(RescuedCreatureManager.run_rescues().size() == 3 and SaveManager.get_rescued(1).size() == 2, "tres rescates en la partida, dos tipos en el guardado")
	SaveManager.reset_progress()


func test_narrative_boss_purification() -> void:
	SaveManager.reset_progress()
	await load_level("Boss", func():
		_with_weapons()
		GameState.set_v("weapon", "sling"))
	await settle()
	place(12, 14)
	await frames(120)
	var boss: Nubarron = level.boss
	level.player.hp = 99
	level.player.max_hp = 99
	boss.invulnerable = false
	boss.hp = 1
	boss.hit_by(_w8_shot("sling"))
	check(boss.is_defeated(), "el jefe cae con su lógica original")
	var found: BossPurification = null
	for i in 400:
		await frames(1)
		var list: Array = level.fx_root.get_children().filter(func(n): return n is BossPurification)
		if not list.is_empty():
			found = list[0]
			break
	check(found != null and found.world_id == 1, "tras su animación de derrota empieza la purificación")
	check(GameState.get_v("bossPurified") == true, "el jefe queda purificado")
	check(not level.player.frozen, "la purificación no congela a Alice")
	var star: Array = level.level_objects.stars_root.get_children().filter(func(n): return n.special)
	check(star.size() == 1, "la estrella dorada especial sigue saliendo")
	await frames(200)
	check(level.fx_root.get_children().filter(func(n): return n is BossPurification).is_empty(), "la purificación termina sola")
	SaveManager.reset_progress()


## Jefes de los Mundos 2-7: su derrota original termina en la purificación común (el 1 y el 8
## tienen pruebas propias).
func test_narrative_all_bosses_purify() -> void:
	for key in ["Boss2", "Boss3", "Boss4", "Boss6", "Boss5", "Boss7"]:
		SaveManager.reset_progress()
		await load_level(key, _with_weapons)
		await settle()
		place(12, 14)
		await frames(150)
		var boss: Node2D = level.boss
		var wid := WorldRegistry.id_for_scene(key)
		level.player.max_hp = 99
		level.player.hp = 99
		level.player.invulnerable_until = level.now + 1000000
		boss.invulnerable = false
		boss.hp = 1
		boss.hit_by(_w8_shot("sling"))
		var found: BossPurification = null
		for i in 420:
			await frames(1)
			var list: Array = level.fx_root.get_children().filter(func(n): return n is BossPurification)
			if not list.is_empty():
				found = list[0]
				break
		check(boss.is_defeated() and found != null and found.world_id == wid, "%s (Mundo %d): derrota original y purificación" % [key, wid])
		var star: Array = level.level_objects.stars_root.get_children().filter(func(n): return n.special)
		check(star.size() == 1 and not level.player.frozen, "%s: estrella especial y Alice libre" % key)
	SaveManager.reset_progress()


func test_narrative_journal() -> void:
	SaveManager.reset_progress()
	check(DreamJournalManager.unlocked_count() == 0 and not DreamJournalManager.has_new_pages(), "diario vacío al empezar")
	SaveManager.add_rescued(1, "scratch")
	var e := DreamJournalManager.entry(1)
	check(not e.unlocked, "visitar o rescatar no desbloquea la página")
	SaveManager.mark_world_completed(1, 97, 144, true)
	e = DreamJournalManager.entry(1)
	check(e.unlocked and e.is_new and DreamJournalManager.has_new_pages(), "completar el mundo desbloquea su página (nueva)")
	check(e.name == WorldRegistry.get_world(1).name and e.boss_name == "Nubarrón", "nombre del mundo y del jefe desde sus fuentes")
	check(e.rescued == ["scratch"] and e.rescuable.size() == 2, "criaturas rescatadas 1 de 2")
	check(e.best_stars == 97 and e.secrets_total == 0 and e.sticker_unlocked(), "estrellas y sticker (el Mundo 1 no tiene secretos)")
	SaveManager.mark_world_completed(2, 50, 160, true, 0.0, ["red"])
	var e2 := DreamJournalManager.entry(2)
	check(e2.secrets_found == 1 and e2.secrets_total == 3 and not e2.sticker_unlocked(), "Mundo 2: secretos 1 de 3, sticker pendiente")
	check(DreamJournalManager.entry(5).name == "El Reino del Tren de Juguete", "la página 5 es el Tren de Juguete (numeración del registro)")
	# interfaz: se abre en la página del mundo, se navega y se cierra
	var holder := Node.new()
	add_child(holder)
	var j := DreamJournal.open(holder, 1)
	await frames(2)
	check(j.page == 1 and j.current_world() == 1, "abre en la página del Mundo 1")
	check(not DreamJournalManager.is_new_page(1), "verla la marca como vista")
	var pages: Array = j.page_root.get_children().filter(func(n): return n is DreamJournalPage)
	check(pages.size() == 1 and pages[0].entry.world_id == 1, "dibuja la página del Mundo 1")
	await _action("move_right")
	await frames(30)
	check(j.page == 2, "derecha pasa a la página siguiente")
	await _action("move_left")
	await frames(30)
	await _action("move_left")
	await frames(30)
	check(j.page == 0, "la portada está antes de la primera página")
	var j3 := DreamJournal.open(holder, 3)
	await frames(2)
	check(j3.page == 0, "una página bloqueada abre en la portada")
	j3.close()
	await _action("pause")
	await frames(2)
	check(not is_instance_valid(j) or not j.is_open, "Esc cierra el diario")
	holder.queue_free()
	# acceso desde el menú principal (y el carrusel) y desde la victoria
	var menu: Control = load(Router.SCENES.Menu).instantiate()
	add_child(menu)
	await frames(2)
	check(menu.journal_btn != null and menu.journal_btn in menu.list.buttons, "el menú principal tiene el botón del diario")
	menu.journal_btn.activate()
	await frames(2)
	var open_j: Array = menu.get_children().filter(func(n): return n is DreamJournal)
	var sel: int = menu.carousel.worlds[menu.carousel.index].id
	check(open_j.size() == 1 and (open_j[0].current_world() == sel if SaveManager.is_world_completed(sel) else open_j[0].page == 0), "abre el diario en el mundo del carrusel (portada si está bloqueado)")
	var idx_before: int = menu.carousel.index
	await _action("ui_right")
	check(menu.carousel.index == idx_before, "con el diario abierto el carrusel no recibe teclas")
	menu.queue_free()
	await get_tree().process_frame
	var v: Control = load(Router.SCENES.Victory).instantiate()
	GameState.entry = {"world": 2, "stars": 1, "total": 2, "rescued": ["crayon", "brush", "crayon"], "newPage": true}
	add_child(v)
	await frames(2)
	check(v.celebration != null and v.celebration.creatures.size() == 3, "la victoria celebra las criaturas liberadas (3)")
	var list: MenuList = v.get_children().filter(func(n): return n is MenuList)[0]
	check(list.buttons[0].label.text == "Ir al Mundo 3" and v.journal_btn in list.buttons, "victoria: botón del diario sin cambiar el primer botón")
	await frames(24)
	await _action("menu_accept")
	check(is_instance_valid(v.celebration) and v.celebration.done, "Enter salta la celebración sin activar el menú")
	await frames(30)
	check(v.journal_btn.label.text == "¡Página nueva!", "aviso de página nueva tras la celebración")
	v.queue_free()
	var v2: Control = load(Router.SCENES.Victory).instantiate()
	GameState.entry = {"world": 1, "stars": 1, "total": 2}
	add_child(v2)
	await frames(2)
	check(v2.celebration == null, "sin rescates no hay celebración")
	v2.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()


func test_narrative_celebration_pick() -> void:
	check(RescueCelebration.make([]) == null, "sin criaturas no se crea")
	var one := RescueCelebration.make(["pompa"])
	check(one.creatures == ["pompa"], "una sola criatura")
	var many := RescueCelebration.make(["a", "a", "a", "b", "b", "b", "b"])
	check(many.creatures.size() == 5 and "a" in many.creatures and "b" in many.creatures, "como mucho cinco, variadas")
	one.free()
	many.free()


## Completa los ocho mundos con todos sus secretos y criaturas (diario completo).
func _complete_journal() -> void:
	for w in WorldRegistry.WORLDS:
		var id := int(w.id)
		var data: Dictionary = C.load_json(w.data)
		var magic: Array = data.get("magicCrayons", []).map(func(m): return m.color)
		var dream: Array = data.get("dreamCollectibles", []).map(func(d): return str(d.id))
		SaveManager.mark_world_completed(id, 10, 10, true, 1000, magic, dream)
		for c in DreamNarrative.rescuable(id):
			SaveManager.add_rescued(id, c)


func test_narrative_ending() -> void:
	SaveManager.reset_progress()
	var aw: Node2D = load(Router.SCENES.Awakening).instantiate()
	add_child(aw)
	await frames(4)
	check(aw.memories.size() == 7, "siete recuerdos en la habitación (el octavo es el gato)")
	var inside := true
	for id in aw.memories:
		var p: Vector2 = aw.memories[id].position
		inside = inside and p.x > 0 and p.x < C.GAME_W and p.y > 0 and p.y < C.GAME_H and aw.memories[id].texture != null
	check(inside, "todos visibles dentro de la habitación")
	check(aw.cat.sprite_frames == Assets.sprite_frames("gato_morado"), "el gato morado es el recuerdo del Mundo 8")
	check(not aw.diary_bonus, "sin el diario completo no hay detalle extra (el final es el mismo)")
	check(aw.light.modulate.a < 0.2, "empieza con poca luz: amanece")
	aw.set_process(false)
	aw.queue_free()
	_complete_journal()
	check(DreamJournalManager.is_complete(), "diario completo con los ocho mundos, secretos y criaturas")
	var aw2: Node2D = load(Router.SCENES.Awakening).instantiate()
	add_child(aw2)
	await frames(4)
	aw2.t = 11.5
	await frames(4)
	check(aw2.diary_bonus and aw2.diary != null, "con el diario completo, el diario brilla en la mesilla")
	aw2.set_process(false)
	aw2.queue_free()
	var cr: Control = load(Router.SCENES.Credits).instantiate()
	add_child(cr)
	await frames(4)
	check(cr.parade != null and cr.parade.get_child_count() == 6, "las criaturas liberadas desfilan en los créditos (hasta 6)")
	cr.set_process(false)
	cr.queue_free()
	await get_tree().process_frame
	SaveManager.reset_progress()
