extends Level
## Arena del jefe de cada mundo (port de scenes/BossScene.js). Usa el mismo motor que el resto
## del nivel y añade: puerta que se cierra, combate con el jefe, estrella especial y portal al
## siguiente mundo. Lo propio de cada jefe sale de los datos (data.boss); los valores por
## defecto son los del Mundo 1 (Nubarrón).
##   boss.scene, boss.name, boss.introBanner, boss.defeatBanner, boss.portalToast,
##   boss.afterMusic, worldId

const DEFAULT_BOSS := "res://scenes/bosses/Nubarron.tscn"
## Nombre del jefe del Mundo 1 (su arena no lo declara en los datos).
const DEFAULT_BOSS_NAME := "Nubarrón"
const PURIFICATION := preload("res://scenes/narrative/BossPurification.tscn")

## Nubarron o Garabato (misma interfaz: setup, intro, hit_by, fsm, hp, defeated_at...).
var boss: Node2D
var fight_started := false
var portal: Portal
## Encuadre del combate (boss.frameBoth): la cámara sigue un punto entre la protagonista y el
## jefe para mantener a ambos a la vista en arenas de más de una pantalla.
var cam_focus: Node2D


func on_create() -> void:
	fight_started = false
	portal = null
	boss = load(data.boss.get("scene", DEFAULT_BOSS)).instantiate()
	boss.setup(self, data.boss)
	world_root.add_child(boss)
	boss.visible = false
	boss.defeated_at.connect(on_boss_defeated)
	GameState.set_v("bossVisible", false)
	GameState.set_v("bossName", data.boss.get("name", DEFAULT_BOSS_NAME))


func on_update(_time: float, _delta: float) -> void:
	if not fight_started and player.position.x > float(data.triggerX) * C.TILE:
		start_fight()
	if cam_focus != null:
		var b := boss.position + Vector2(0, -24)
		var w := 0.4 if fight_started and boss.position.y > 0 else 0.0
		cam_focus.position = player.position.lerp(b, w)


func on_custom_overlap(kind: String, _entity: Object) -> void:
	match kind:
		"boss":
			if boss.is_defeated() or boss.fsm.is_state("INTRO") or not fight_started:
				return
			player.hurt(boss.position.x)
		"portal":
			enter_portal()


func start_fight() -> void:
	fight_started = true
	# la entrada queda bloqueada durante el combate
	var gate: Dictionary = data.gate
	for r in gate.rows:
		builder.set_block(int(gate.x), int(r), gate.tile)
		effects.poof(float(gate.x) * C.TILE + 8, float(r) * C.TILE + 8, 6)
	AudioManager.play("boss_appear")
	AudioManager.play_music(data.bossMusic)
	camera.shake(500, 0.005)
	player.frozen = true
	after(1500, func(): player.frozen = false)
	if data.boss.get("frameBoth", false):
		cam_focus = Node2D.new()
		cam_focus.position = player.position
		world_root.add_child(cam_focus)
		camera.target = cam_focus
	boss.visible = true
	boss.set_body_enabled(true)
	boss.intro()
	GameState.set_v("bossMaxHp", boss.max_hp)
	GameState.set_v("bossHp", boss.hp)
	GameState.set_v("bossVisible", true)
	GameState.show_banner(data.boss.get("introBanner", "¡Nubarrón!"))


func on_boss_defeated(x: float, y: float) -> void:
	PlaytestLog.event(self, "jefe_vencido")
	GameState.set_v("bossVisible", false)
	kill_enemy_projectiles()
	AudioManager.play_music(data.boss.get("afterMusic", "world1"))
	GameState.show_banner(data.boss.get("defeatBanner", "¡Has calmado a Nubarrón!"))
	purify_boss()
	# entrega la estrella dorada especial, que cae hasta el suelo de la arena
	var star := Star.new().setup(self, Vector2(x, y), {"special": true})
	level_objects.stars_root.add_child(star)
	star.drop_to(float(data.boss.floorY) - 22)


## Narrativa: el jefe vencido recupera su forma tierna (efecto común, no bloquea nada).
func purify_boss() -> BossPurification:
	var fx: BossPurification = PURIFICATION.instantiate()
	fx.setup(self, boss, int(data.get("worldId", 1)))
	fx_root.add_child(fx)
	GameState.set_v("bossPurified", true)
	return fx


func on_special_star(_star: Star) -> void:
	GameState.set_v("specialStar", true)
	GameState.show_toast("¡Estrella dorada especial!")
	var p: Dictionary = data.portal
	after(700, func():
		portal = Portal.new().setup(Vector2(float(p.x) * C.TILE + C.TILE / 2.0, float(p.y) * C.TILE))
		level_objects.objects.add_child(portal)
		AudioManager.play("portal")
		GameState.show_toast(data.boss.get("portalToast", "Se ha abierto el portal al Mundo 2")))


func enter_portal() -> void:
	if leaving or portal == null or portal.used:
		return
	portal.used = true
	leaving = true
	controls.set_enabled(false)
	player.celebrate()
	AudioManager.stop_music()
	AudioManager.play("victory")
	effects.confetti(player.position.x, player.position.y - 40, 80)

	var stars := int(GameState.get_v("stars", 0))
	var total := int(GameState.get_v("starsTotal", 0))
	var special := bool(GameState.get_v("specialStar", false))
	var time: float = GameState.get_v("playTime", 0.0)
	var world_id := int(data.get("worldId", 1))
	var magic: Array = GameState.get_v("magicCrayons", [])
	var dream: Array = GameState.get_v("dreamCollectibles", [])
	var no_falls := int(GameState.get_v("falls", 0)) == 0
	SaveManager.mark_world_completed(world_id, stars, total, special, time, magic, dream, no_falls)

	after(2200, func():
		await Fader.fade_out(700, Color8(255, 247, 255))
		if not is_inside_tree():
			return
		GameState.entry = {"stars": stars, "total": total, "special": special, "time": time, "world": world_id, "magic": magic, "magicTotal": int(GameState.get_v("magicTotal", 0)), "dream": dream, "dreamTotal": int(GameState.get_v("dreamTotal", 0)), "noFalls": no_falls,
			"rescued": RescuedCreatureManager.run_creatures(), "newPage": DreamJournalManager.is_new_page(world_id)}
		Router.go("Victory"))


## Si la protagonista cae rendida durante el combate, el combate empieza de nuevo.
func respawn(full: bool) -> void:
	if fight_started and not boss.is_defeated():
		if respawning:
			return
		respawning = true
		GameState.set_v("hp", player.max_hp)
		GameState.set_v("bossVisible", false)
		GameState.show_toast("¡Inténtalo otra vez!")
		await Fader.fade_out(500)
		if is_inside_tree():
			get_tree().reload_current_scene()
		return
	super.respawn(full)
