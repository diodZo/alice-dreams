extends Node
## Captura de pantalla para la verificación visual (no forma parte del juego).
## godot --path godot res://tests/Capture.tscn -- scene=World1 x=40 frames=90 out=C:/ruta/img.png
##   scene  World1 | Boss | Menu | Victory | Main
##   x      columna (teselas) donde colocar a la protagonista (opcional)
##   y      fila (teselas) (opcional, por defecto la del suelo de salida)
##   hold   acciones mantenidas separadas por comas (p. ej. move_right,run)
##   weapons=1  entrega las tres armas
##   boss_hp     vida del jefe al empezar la captura (fuerza la fase)
##   shots  número de capturas (separadas por `every` fotogramas)

var args := {}
var level: Node
var frame := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# guardado aislado: las capturas nunca tocan el progreso real del jugador
	SaveManager.save_path = "user://tools_save.json"
	SaveManager.load_state()
	if "real_save" in OS.get_cmdline_user_args():
		SaveManager.save_path = SaveManager.SAVE_PATH
		SaveManager.load_state()
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var scene_key: String = args.get("scene", "World1")
	if scene_key in ["World1", "Boss", "World2", "Boss2"]:
		WorldRegistry.start_run(2 if scene_key.ends_with("2") else 1)
		if args.has("weapons"):
			GameState.set_v("weaponsOwned", ["bubble", "paint", "sling"])
			GameState.set_v("weapon", args.get("weapon", "bubble"))
		GameState.entry = {"introBanner": true}
	if scene_key == "Victory":
		GameState.entry = {"stars": 97, "total": 144, "special": true, "time": 412000, "world": int(args.get("world", "1")), "magic": ["red", "blue"], "magicTotal": 3 if args.get("world", "1") == "2" else 0}
	var inst: Node = load(Router.SCENES[scene_key]).instantiate()
	add_child(inst)
	level = inst
	if level is Level and args.has("x"):
		var y := float(args.get("y", "-1"))
		level.player.position = Vector2(float(args.x) * C.TILE + 8, (y if y >= 0 else level.player.position.y / C.TILE) * C.TILE)
		level.camera.snap_to_target()
	if level is Level and args.has("hold"):
		level.controls.scripted = true
		for act in String(args.hold).split(","):
			level.controls.script_held[act] = true


func _physics_process(_delta: float) -> void:
	frame += 1
	if level is Level and args.has("press_every"):
		var n := int(args.press_every)
		if frame % n == 0:
			for act in String(args.get("press", "jump")).split(","):
				level.controls.script_pressed[act] = true
	if args.has("boss_hp") and level is Level and level.has_method("start_fight") and frame == 5:
		level.player.position.x = (float(level.data.triggerX) + 1) * C.TILE
	if args.has("boss_hp") and level is Level and level.get("boss") and level.boss.fsm.current == "IDLE" and not args.has("_hp_set"):
		args["_hp_set"] = true
		var hp := int(args.boss_hp)
		level.boss.hp = hp
		var ratio: float = float(hp) / level.boss.max_hp
		level.boss.phase = 3 if ratio <= 0.3 else (2 if ratio <= 0.65 else 1)
		if level.boss.phase == 3:
			level.boss.sprite.modulate = Nubarron.PHASE3_TINT
		GameState.set_v("bossHp", hp)
	if args.has("kill_at") and level is Level and frame == int(args.kill_at) and level.get("boss"):
		level.player.invulnerable_until = level.now + 100000
		level.boss.hp = 0
		level.boss.fsm.set_state("DEFEATED")
	if args.has("pause") and level is Level and frame == int(args.pause):
		level.pause_game()
	var total := int(args.get("frames", "60"))
	var shots := int(args.get("shots", "1"))
	var every := int(args.get("every", "30"))
	var first := total - (shots - 1) * every
	if frame >= first and (frame - first) % every == 0:
		var idx := (frame - first) / every
		var out: String = args.get("out", "user://capture.png")
		if shots > 1:
			out = out.get_basename() + "_%d.png" % idx
		get_viewport().get_texture().get_image().save_png(out)
		print("[capture] ", out)
		if idx >= shots - 1:
			get_tree().quit()
