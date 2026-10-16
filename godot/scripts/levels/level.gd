class_name Level
extends Node2D
## MOTOR COMÚN de todos los niveles (port de scenes/LevelScene.js). Las subclases sólo aportan
## sus datos (data_path) y sus reglas particulares (on_create / on_update / on_respawn /
## on_special_star / on_custom_overlap). No se duplican física, controles ni combate entre mundos.
##
## Reloj: `now` (ms) avanza en cada fotograma de física y se detiene con la pausa; todos los
## temporizadores de juego (invulnerabilidad, enfriamientos, ataques) lo usan.

const PROJECTILE := preload("res://scenes/weapons/Projectile.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const PAUSE_SCENE := preload("res://scenes/menus/Pause.tscn")
const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")

## Datos del nivel (generados desde src/data/*.js por tools/convert_phaser.mjs).
@export_file("*.json") var data_path := ""
## Clave de la escena (equivale a la clave de escena Phaser: "World1", "Boss").
@export var scene_key := "World1"

var data: Dictionary
var now := 0.0
var world_w := 0.0
var world_h := 0.0
var respawning := false
var leaving := false
var touch_mode := false

var world_root: Node2D
var fx_root: Node2D
var enemies_root: Node2D
var player_projectiles: Node2D
var enemy_projectiles: Node2D
var bonus_root: Node2D
var camera: CameraRig
var parallax: ParallaxBackground2
var effects: Effects
var builder: LevelBuilder
var level_objects: Dictionary
var controls: InputController
var checkpoints: CheckpointManager
var player: Player
var weapons: WeaponManager
var spawner: EnemySpawner
var hud: CanvasLayer
var timers := Timers.new()
var look_ahead := 0.0
var section_index := 0
var progress_timer := 0.0
var _pause_menu: Node
## La misma pulsación que reanuda desde el menú de pausa no debe volver a pausar.
var _pause_block_frame := -1


func _ready() -> void:
	data = C.load_json(data_path)
	if data == null:
		push_error("[Level] No se pudieron cargar los datos del nivel: %s" % data_path)
		return
	var entry := GameState.entry
	GameState.entry = {}
	world_w = float(data.widthTiles) * C.TILE
	world_h = float(data.heightTiles) * C.TILE
	touch_mode = GameState.touch_mode

	camera = CameraRig.new()
	camera.name = "Camera"
	parallax = ParallaxBackground2.new()
	parallax.name = "Background"
	add_child(parallax)
	world_root = Node2D.new()
	world_root.name = "World"
	add_child(world_root)
	fx_root = Node2D.new()
	fx_root.name = "FX"
	fx_root.z_index = C.Z_FX
	effects = Effects.new(fx_root)
	parallax.build(camera, data.backgroundAtlas, data.objectsAtlas, world_w, world_h, true, data.key)

	builder = LevelBuilder.new(self, data)
	level_objects = builder.build(world_root, touch_mode, GameState.get_v("collectedStars", []))

	controls = InputController.new()
	var start := Vector2(float(data.playerStart.x) * C.TILE + C.TILE / 2.0, float(data.playerStart.y) * C.TILE)
	checkpoints = CheckpointManager.new(self, data.checkpoints, data.objectsAtlas, scene_key, start, level_objects.objects)
	var spawn := checkpoints.respawn_point()
	player = PLAYER_SCENE.instantiate()
	player.setup(self, controls)
	player.position = spawn
	player.world_width = world_w
	var hp: int = int(GameState.get_v("hp", 0))
	enemies_root = _container("Enemies")
	world_root.add_child(player)
	player.hp = mini(hp, player.max_hp) if hp > 0 else player.max_hp
	player.hp_changed.connect(func(v): GameState.set_v("hp", v))
	player.fainted.connect(func(): after(900, func(): respawn(true)))
	bonus_root = _container("BonusStars")
	player_projectiles = _container("PlayerProjectiles")
	enemy_projectiles = _container("EnemyProjectiles")
	world_root.add_child(fx_root)

	weapons = WeaponManager.new(self, player, GameState.get_v("weaponsOwned", []), GameState.get_v("weapon"))
	weapons.emit()

	var spawns: Array = []
	for i in data.enemies.size():
		var e: Dictionary = data.enemies[i]
		var s := {
			"id": "%s:e%d" % [data.key, i],
			"type": e.type,
			"x": float(e.x) * C.TILE + C.TILE / 2.0,
			"y": float(e.y) * C.TILE,
		}
		if e.has("patrol"):
			s.patrol = [float(e.patrol[0]) * C.TILE, float(e.patrol[1]) * C.TILE + C.TILE]
		spawns.append(s)
	spawner = EnemySpawner.new(self, spawns, enemies_root, 6)

	add_child(camera)
	camera.setup(player, Rect2(0, 0, world_w, world_h), Assets.camera_tuning())

	GameState.set_v("maxHp", player.max_hp)
	GameState.set_v("hp", player.hp)
	GameState.set_v("bossVisible", false)
	var marks: Array = []
	for s in data.sections:
		marks.append(float(s.from) / float(data.progress.total))
	GameState.set_v("progressMarks", marks)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	if data.has("music"):
		AudioManager.play_music(data.music)

	section_index = find_section()
	GameState.set_v("section", data.sections[section_index].id if data.sections.size() > 0 else "")
	if entry.get("introBanner", false):
		announce_section()

	on_create()
	Fader.fade_in(450)


func _container(node_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = node_name
	world_root.add_child(n)
	return n


## Programa una acción sobre el reloj del nivel (se detiene con la pausa).
func after(ms: float, fn: Callable) -> int:
	return timers.add(now, ms, fn)


# ------------------------------------------------------------------ bucle
func _physics_process(delta: float) -> void:
	if data == null:
		return
	var ms := delta * 1000.0
	now += ms
	timers.process(now)
	controls.update()
	if controls.pause_pressed and Engine.get_physics_frames() > _pause_block_frame:
		pause_game()
		return
	player.step(now, delta)
	_process_overlaps(delta)
	weapons.update(now)
	spawner.update()
	for m in level_objects.movers:
		m.step(ms)
	update_signs()
	update_camera(ms)
	parallax.update(ms)
	update_progress(ms)
	if player.position.y > world_h + 24:
		handle_fall()
	on_update(now, delta)


# -------------------------------------------------------------- colisiones
## Despacha los solapamientos del sensor de la protagonista (equivale a los overlap de
## Arcade Physics registrados en LevelScene.setupCollisions).
func _process_overlaps(delta: float) -> void:
	for area in player.sensor.get_overlapping_areas():
		if player.dead and not leaving:
			return
		var entity: Variant = area.get_meta("entity", null)
		if entity == null or not is_instance_valid(entity):
			continue
		match area.get_meta("kind", ""):
			"enemy":
				on_player_touch_enemy(entity)
			"projectile":
				on_enemy_projectile(entity)
			"star":
				on_star(entity)
			"pickup":
				on_pickup(entity)
			"checkpoint":
				checkpoints.activate(entity)
			"pad":
				if player.velocity.y >= 0:
					entity.trigger(player)
			"hazard":
				player.hurt(entity.position.x)
			"wind":
				entity.apply(player, delta)
			var kind:
				on_custom_overlap(kind, entity)


func on_platform_contact(plat: Node) -> void:
	if plat is CloudPlatform and plat.bouncy != 0:
		player.bounce(plat.bouncy)
		AudioManager.play("bounce")
		plat.squash()
		effects.sparkle(player.position.x, player.position.y, 6)
	elif plat is CrumblePlatform:
		plat.step_on()


func on_player_touch_enemy(e: Enemy) -> void:
	if not e.is_alive() or player.dead:
		return
	if e.is_trapped():
		e.convert_to_star()
		return
	var pb := player.body_rect()
	var eb := e.body_rect()
	if player.velocity.y > 20 and pb.end.y <= eb.position.y + 10:
		e.stomp()
		player.bounce(float(player.T.stompBounce))
		effects.sparkle(e.position.x, eb.position.y, 6)
		return
	if e.is_harmful():
		player.hurt(e.position.x)


func on_enemy_projectile(proj: Projectile) -> void:
	if not proj.active or player.dead:
		return
	if proj.kind == "wind":
		if proj.hit_targets.has("player"):
			return
		proj.hit_targets["player"] = true
		player.push(signf(proj.velocity.x) * 330)
		if player.grounded:
			player.velocity.y = -90
		effects.poof(player.position.x, player.position.y - 14, 6)
		return
	if player.hurt(proj.position.x, proj.damage):
		proj.expire()


func on_star(star: Star) -> void:
	if not star.collect():
		return
	GameState.inc("stars", 1)
	if star.id != "":
		var list: Array = GameState.get_v("collectedStars", []).duplicate()
		list.append(star.id)
		GameState.set_v("collectedStars", list)
	if star.special:
		on_special_star(star)


func on_pickup(pk: WeaponPickup) -> void:
	if not pk.active:
		return
	var w := Assets.weapon(pk.weapon_id)
	weapons.unlock(pk.weapon_id)
	pk.collect()
	AudioManager.play("pickup")
	GameState.show_banner("¡Nueva arma: %s!" % w.display_name)


## Estrella extra que sale de un monstruo atrapado en una burbuja.
func spawn_bonus_star(x: float, y: float) -> void:
	var s := Star.new().setup(self, Vector2(x, y), {"bonus": true})
	bonus_root.add_child(s)
	var ref: WeakRef = weakref(s)
	after(9000, func():
		var star: Star = ref.get_ref()
		if star != null:
			star.fade_out())


## Nube temporal (la invoca el jefe en la fase 2).
func add_temporary_platform(x: float, y: float, ms: float) -> void:
	var plat := CloudPlatform.new().setup({"x": x / C.TILE, "y": y / C.TILE, "frame": "cloud_face_small"}, data.objectsAtlas)
	level_objects.platforms.add_child(plat)
	plat.modulate.a = 0.0
	plat.create_tween().tween_property(plat, "modulate:a", 1.0, 0.25)
	var ref: WeakRef = weakref(plat)
	after(ms - 1000, func():
		var p: CloudPlatform = ref.get_ref()
		if p != null:
			var tw := p.create_tween()
			for i in 4:
				tw.tween_property(p, "modulate:a", 0.3, 0.12)
				tw.tween_property(p, "modulate:a", 1.0, 0.12))
	after(ms, func():
		var p: CloudPlatform = ref.get_ref()
		if p == null:
			return
		effects.poof(p.position.x, p.position.y + 6, 10)
		p.queue_free())


func spawn_projectile(owner_kind: String, cfg: Dictionary) -> Projectile:
	var container := player_projectiles if owner_kind == "player" else enemy_projectiles
	var max_count := 24 if owner_kind == "player" else 48
	var count := 0
	for p in container.get_children():
		if p.active:
			count += 1
	if count >= max_count:
		return null
	var proj: Projectile = PROJECTILE.instantiate()
	proj.fire(self, cfg)
	container.add_child(proj)
	return proj


func on_projectile_expired(proj: Projectile) -> void:
	var x := proj.position.x
	var y := proj.position.y
	match proj.kind:
		"bubble":
			effects.bubble_pop(x, y)
		"paint":
			effects.paint_splat(x, y, proj.paint_color)
		"sling":
			effects.impact(x, y, proj.tint_color)
		"spit":
			effects.impact(x, y, C.rgb(0x7ee07e))
		"cloudball", "rain", "flea":
			effects.poof(x, y, 5)


func on_enemy_finished(enemy: Enemy) -> void:
	spawner.on_enemy_finished(enemy)


func kill_enemy_projectiles() -> void:
	for p in enemy_projectiles.get_children():
		if p.active:
			p.kill()


func terrain_solid_at(pos: Vector2) -> bool:
	return builder.is_solid(pos)


# ------------------------------------------------------------------ cámara
func update_camera(delta_ms: float) -> void:
	var target := player.facing * float(Assets.camera_tuning().get("lookAhead", 36))
	look_ahead += (target - look_ahead) * minf(1.0, delta_ms / 400.0)
	camera.follow_offset = Vector2(-look_ahead, 16)
	camera.update_follow(delta_ms)


# ------------------------------------------------------------- reaparición
func handle_fall() -> void:
	if respawning or player.dead or leaving:
		return
	player.hp = maxi(0, player.hp - 1)
	GameState.set_v("hp", player.hp)
	AudioManager.play("hurt")
	respawn(player.hp <= 0)


func respawn(full: bool) -> void:
	if respawning or leaving:
		return
	respawning = true
	player.dead = true
	player.velocity = Vector2.ZERO
	player.gravity_enabled = false
	await Fader.fade_out(280)
	if not is_inside_tree():
		return
	var pt := checkpoints.respawn_point()
	player.gravity_enabled = true
	player.respawn_at(pt.x, pt.y)
	if full or player.hp <= 0:
		player.heal(true)
	spawner.reset_active()
	kill_enemy_projectiles()
	on_respawn()
	camera.snap_to_target()
	Fader.fade_in(300)
	respawning = false


# ------------------------------------------------------------------- pausa
func pause_game() -> void:
	if leaving or respawning or _pause_menu != null:
		return
	controls.reset()
	AudioManager.play("pause")
	AudioManager.duck(true)
	_pause_menu = PAUSE_SCENE.instantiate()
	_pause_menu.level = self
	add_child(_pause_menu)
	get_tree().paused = true


func resume_game() -> void:
	get_tree().paused = false
	if _pause_menu:
		_pause_menu.queue_free()
		_pause_menu = null
	controls.reset()
	AudioManager.duck(false)
	_pause_block_frame = Engine.get_physics_frames() + 1


## Reinicia la escena desde el último checkpoint (opción del menú de pausa).
func restart_from_checkpoint() -> void:
	GameState.set_v("hp", player.max_hp)
	get_tree().paused = false
	AudioManager.duck(false)
	get_tree().reload_current_scene()


func exit_to_menu() -> void:
	get_tree().paused = false
	AudioManager.duck(false)
	Fader.clear()
	Router.go("Menu")


# ------------------------------------------------------- secciones y HUD
func progress_px() -> float:
	var pr: Dictionary = data.progress
	return float(pr.offset) + player.position.x * float(pr.scale)


func find_section() -> int:
	var px := progress_px()
	var idx := 0
	for i in data.sections.size():
		if px >= float(data.sections[i].from):
			idx = i
	return idx


func announce_section() -> void:
	if section_index < data.sections.size():
		var s: Dictionary = data.sections[section_index]
		GameState.show_banner("Sección %s: %s" % [s.id, s.name])


func update_progress(delta_ms: float) -> void:
	progress_timer += delta_ms
	GameState.data["playTime"] = float(GameState.get_v("playTime", 0.0)) + delta_ms
	if progress_timer < 120:
		return
	progress_timer = 0
	GameState.set_v("progress", clampf(progress_px() / float(data.progress.total), 0, 1))
	var idx := find_section()
	if idx != section_index:
		section_index = idx
		GameState.set_v("section", data.sections[idx].id)
		announce_section()


## Sólo el cartel más cercano (a menos de 56 px) muestra su bocadillo.
func update_signs() -> void:
	var best: SignPost = null
	var best_d := 56.0
	for s in level_objects.signs:
		var d: float = s.distance_to_player(player)
		if d < best_d:
			best_d = d
			best = s
	for s in level_objects.signs:
		s.update_proximity(s == best)


# ------------------------------------------------- ganchos de las subclases
func on_create() -> void:
	pass


func on_update(_time: float, _delta: float) -> void:
	pass


func on_respawn() -> void:
	pass


func on_special_star(_star: Star) -> void:
	pass


## Solapamientos propios de cada escena (puerta del castillo, portal, jefe...).
func on_custom_overlap(_kind: String, _entity: Object) -> void:
	pass
