extends "res://scripts/levels/boss_arena.gd"
## El Trono de las Pesadillas (Mundo 8, sección F): arena del Rey Pesadelo con el motor común de
## arenas (puerta que se cierra, barra de vida, encuadre de Alice y el jefe). Lo propio del final:
##  - fase 2: el cielo se oscurece, algunas estrellas cambian de color y caen estrellas con aviso;
##    fase 3: música de furia,
##  - la nube ralentizadora del jefe (contacto "slow_cloud": sin daño),
##  - derrota sin estrella ni portal: el HUD se oculta poco a poco, Alice ya no puede disparar,
##    el jefe se transforma en el gato morado y, al abrazarlo, se guarda el final de la aventura
##    y empieza la cinemática: el castillo recupera la luz, Alice brilla y despierta.

## IMP-032: fase en la que Alice cayó rendida (2 o 3). La guarda respawn() antes de recargar la
## escena y la lee (y borra) on_create(): el combate sigue en esa fase, sin la intro ni el salón.
const RETRY_KEY := "bossRetryPhase"

var phase_stars: Array = []
var ending := false
var retry_phase := 1
var cat: PurpleCat
var ghosts_root: Node2D


func on_create() -> void:
	super()
	boss.transformed.connect(_on_transformed)
	retry_phase = int(GameState.get_v(RETRY_KEY, 1))
	GameState.data.erase(RETRY_KEY)
	if retry_phase >= 2:
		# justo pasado el disparador del combate, que empieza en el primer fotograma
		player.position.x = (float(data.triggerX) + 1.5) * C.TILE
		camera.snap_to_target()


func begin_boss() -> void:
	if retry_phase < 2:
		super()
		return
	boss.start_at_phase(retry_phase)
	# el escenario de cada fase ya superada (cielo, estrellas que caen, música de furia)
	for p in range(2, retry_phase + 1):
		on_boss_phase(p)
	GameState.show_toast("¡Sigues en la fase %d!" % retry_phase)


func on_custom_overlap(kind: String, entity: Object) -> void:
	match kind:
		"slow_cloud":
			if not ending:
				entity.apply(player)
		"shootable":
			pass  # el cuerpo del jefe recibe los disparos con su propia área
		_:
			super(kind, entity)


## Margen máximo (px) entre Alice y el centro del encuadre: la arena mide dos pantallas y el
## encuadre común (entre Alice y el jefe) nunca debe dejarla fuera de la vista.
const KEEP_IN_VIEW := 150.0


func on_update(time: float, delta: float) -> void:
	super(time, delta)
	if cam_focus == null:
		return
	if cat != null and is_instance_valid(cat):
		cam_focus.position = player.position.lerp(cat.position, 0.45)
	cam_focus.position.x = clampf(cam_focus.position.x, player.position.x - KEEP_IN_VIEW, player.position.x + KEEP_IN_VIEW)


## Cambios del escenario con cada fase (los llama el jefe al entrar en HURT).
func on_boss_phase(phase: int) -> void:
	match phase:
		2:
			var tw := create_tween().set_parallel()
			tw.tween_property(parallax, "modulate", Color(0.74, 0.66, 0.92), 1.5)
			# algunas estrellas cambian de color
			for s in level_objects.stars_root.get_children():
				if s is Star and not s.special:
					s.create_tween().tween_property(s, "modulate", C.rgb(0xf6b4e9), 1.2)
			# obstáculos temporales: estrellas que caen con aviso (siempre queda sitio libre)
			for d in data.get("phaseStars", []):
				var def: Dictionary = d.duplicate()
				def.delay = now + float(d.get("delay", 0))
				var fs := FallingStar.new().setup(self, def, data.objectsAtlas)
				level_objects.objects.add_child(fs)
				phase_stars.append(fs)
		3:
			create_tween().tween_property(parallax, "modulate", Color(0.66, 0.56, 0.88), 1.5)
			AudioManager.play_music(data.get("furyMusic", data.bossMusic))


func on_boss_defeated(_x: float, _y: float) -> void:
	PlaytestLog.event(self, "jefe_vencido")
	GameState.set_v("bossVisible", false)
	kill_enemy_projectiles()
	for fs in phase_stars:
		if is_instance_valid(fs):
			fs.queue_free()
	phase_stars.clear()
	player.clear_slow()
	controls.combat_enabled = false
	GameState.show_banner(data.boss.get("defeatBanner", "El Rey Pesadelo está agotado..."))
	# el HUD se oculta poco a poco
	var root: Control = hud.get_node("Root")
	create_tween().tween_property(root, "modulate:a", 0.0, 2.5)


func _on_transformed(new_cat: Node2D) -> void:
	cat = new_cat
	cat.hugged.connect(_on_hugged)
	GameState.show_toast("Un gatito morado... ¡Acércate a él!")


## Al abrazar al gato: se guarda el final y empieza la cinemática.
func _on_hugged() -> void:
	if ending:
		return
	ending = true
	controls.set_enabled(false)
	player.velocity.x = 0
	save_ending()
	# narrativa: el Rey Pesadelo vuelve a ser un gatito; su página del diario queda escrita
	GameState.set_v("bossPurified", true)
	GameState.show_toast("¡Nueva página en el Diario de Sueños!")
	after(1500, _castle_light)


func save_ending() -> void:
	var stars := int(GameState.get_v("stars", 0))
	var total := int(GameState.get_v("starsTotal", 0))
	var time: float = GameState.get_v("playTime", 0.0)
	var dream: Array = GameState.get_v("dreamCollectibles", [])
	SaveManager.mark_world_completed(8, stars, total, true, time, [], dream, int(GameState.get_v("falls", 0)) == 0)
	SaveManager.mark_adventure_completed()


## Escena 1 — el castillo recupera la luz: las sombras desaparecen, las estrellas iluminan el
## castillo, el cielo pasa de morado oscuro a lavanda, la música se suaviza y los fantasmas
## del escenario sonríen.
func _castle_light() -> void:
	AudioManager.play_music("alice_awakening")
	var tw := create_tween().set_parallel()
	tw.tween_property(parallax, "modulate", Color(1.15, 1.05, 1.25), 2.5)
	tw.tween_property(world_root, "modulate", Color(1.08, 1.04, 1.12), 2.5)
	var view := camera.view_rect()
	for i in 14:
		after(i * 140, func():
			effects.sparkle(view.position.x + randf() * view.size.x, view.position.y + randf() * 120, 8))
	ghosts_root = Node2D.new()
	ghosts_root.z_index = C.Z_DECOR_BACK
	world_root.add_child(ghosts_root)
	for i in 4:
		var g := Sprite2D.new()
		g.texture = Assets.frame(data.objectsAtlas, "ghost_bg")
		g.position = Vector2(view.position.x + 60 + i * 110, view.position.y + 70 + (i % 2) * 24)
		g.modulate.a = 0.0
		ghosts_root.add_child(g)
		var gt := g.create_tween()
		gt.tween_interval(0.6 + i * 0.3)
		gt.tween_property(g, "modulate:a", 0.9, 0.8)
		var bob := g.create_tween().set_loops()
		bob.tween_property(g, "position:y", g.position.y - 5, 1.0).set_trans(Tween.TRANS_SINE)
		bob.tween_property(g, "position:y", g.position.y, 1.0).set_trans(Tween.TRANS_SINE)
	GameState.show_banner("¡El castillo recupera la luz!")
	after(3600, _dream_fades)


## Escena 2 — el sueño se desvanece: Alice brilla, pequeñas estrellas giran a su alrededor y
## todo se funde suavemente hacia la habitación de Alice.
func _dream_fades() -> void:
	player.celebrate()
	var glow := Sprite2D.new()
	glow.texture = Assets.generated("glow")
	glow.modulate = Color(C.rgb(0xffe18c), 0.0)
	glow.scale = Vector2(2.5, 3.0)
	glow.position = Vector2(0, -16)
	glow.show_behind_parent = true
	player.add_child(glow)
	var gt := glow.create_tween()
	gt.tween_property(glow, "modulate:a", 0.75, 1.2)
	var ring := Node2D.new()
	ring.position = Vector2(0, -18)
	ring.z_index = 1
	player.add_child(ring)
	for i in 6:
		var s := Sprite2D.new()
		s.texture = Assets.frame(data.objectsAtlas, "star_w8")
		s.scale = Vector2(0.6, 0.6)
		s.position = Vector2(cos(TAU * i / 6.0) * 22.0, sin(TAU * i / 6.0) * 12.0)
		ring.add_child(s)
	var rt := ring.create_tween().set_loops()
	rt.tween_property(ring, "rotation", TAU, 2.2).from(0.0)
	AudioManager.play("portal")
	after(2600, func():
		await Fader.fade_out(1600, Color8(255, 240, 250))
		if is_inside_tree():
			GameState.entry = {"fromGame": true}
			Router.go("Awakening"))


## Si Alice cae rendida durante el combate, el combate empieza de nuevo (como en las demás
## arenas), pero en la fase en la que estaba (IMP-032); después de la derrota del jefe ya no hay
## peligro.
func respawn(full: bool) -> void:
	if ending:
		return
	remember_retry_phase()
	super.respawn(full)


func remember_retry_phase() -> void:
	if fight_started and not boss.is_defeated() and not respawning:
		GameState.set_v(RETRY_KEY, boss.phase)
