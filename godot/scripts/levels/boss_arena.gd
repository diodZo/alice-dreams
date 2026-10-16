extends Level
## Arena del castillo, tramo final del Mundo 1 (port de scenes/BossScene.js). Usa el mismo
## motor que el resto del nivel y añade: puerta que se cierra, combate con Nubarrón,
## estrella especial y portal al siguiente mundo.

const NUBARRON := preload("res://scenes/bosses/Nubarron.tscn")

var boss: Nubarron
var fight_started := false
var portal: Portal


func on_create() -> void:
	fight_started = false
	portal = null
	boss = NUBARRON.instantiate()
	boss.setup(self, data.boss)
	world_root.add_child(boss)
	boss.visible = false
	boss.defeated_at.connect(on_boss_defeated)
	GameState.set_v("bossVisible", false)


func on_update(_time: float, _delta: float) -> void:
	if not fight_started and player.position.x > float(data.triggerX) * C.TILE:
		start_fight()


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
	boss.visible = true
	boss.set_body_enabled(true)
	boss.intro()
	GameState.set_v("bossMaxHp", boss.max_hp)
	GameState.set_v("bossHp", boss.hp)
	GameState.set_v("bossVisible", true)
	GameState.show_banner("¡Nubarrón!")


func on_boss_defeated(x: float, y: float) -> void:
	GameState.set_v("bossVisible", false)
	kill_enemy_projectiles()
	AudioManager.play_music("world1")
	GameState.show_banner("¡Has calmado a Nubarrón!")
	# entrega la estrella dorada especial, que cae hasta el suelo de la arena
	var star := Star.new().setup(self, Vector2(x, y), {"special": true})
	level_objects.stars_root.add_child(star)
	star.drop_to(float(data.boss.floorY) - 22)


func on_special_star(_star: Star) -> void:
	GameState.set_v("specialStar", true)
	GameState.show_toast("¡Estrella dorada especial!")
	var p: Dictionary = data.portal
	after(700, func():
		portal = Portal.new().setup(Vector2(float(p.x) * C.TILE + C.TILE / 2.0, float(p.y) * C.TILE))
		level_objects.objects.add_child(portal)
		AudioManager.play("portal")
		GameState.show_toast("Se ha abierto el portal al Mundo 2"))


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
	SaveManager.mark_world_completed(1, stars, total, special, time)

	after(2200, func():
		await Fader.fade_out(700, Color8(255, 247, 255))
		if not is_inside_tree():
			return
		GameState.entry = {"stars": stars, "total": total, "special": special, "time": time}
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
