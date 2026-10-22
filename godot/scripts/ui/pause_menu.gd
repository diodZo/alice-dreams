extends CanvasLayer
## Menú de pausa superpuesto al nivel, que queda en pausa (port de scenes/PauseScene.js).

var level: Node


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var W := float(C.GAME_W)
	var H := float(C.GAME_H)
	var dim := ColorRect.new()
	dim.color = Color(C.INK, 0.6)
	dim.size = Vector2(W, H)
	add_child(dim)
	var title := PixelText.make("Pausa", {"origin": Vector2(0.5, 0.5), "scale": 2, "tint": C.YELLOW})
	title.position = Vector2(W / 2, 50)
	add_child(title)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.position = Vector2(W / 2 - 85, 75)
	box.size = Vector2(170, 130)
	add_child(box)
	var resume := CloudButton.make("Continuar", 170)
	resume.activated.connect(func(_b): resume_game())
	var music := CloudButton.make(_music_label(), 170)
	music.activated.connect(func(b):
		AudioManager.set_music_enabled(not AudioManager.music_on)
		b.set_label(_music_label()))
	var sfx := CloudButton.make(_sfx_label(), 170)
	sfx.activated.connect(func(b):
		AudioManager.set_sfx_enabled(not AudioManager.sfx_on)
		b.set_label(_sfx_label())
		AudioManager.play("ui_select"))
	var run := CloudButton.make(_run_label(), 170)
	run.activated.connect(func(b):
		SaveManager.set_setting("alwaysRun", SaveManager.get_setting("alwaysRun") != true)
		b.set_label(_run_label())
		AudioManager.play("ui_select"))
	var restart := CloudButton.make("Volver al checkpoint", 170)
	restart.activated.connect(func(_b): level.restart_from_checkpoint())
	var quit := CloudButton.make("Salir al menú", 170)
	quit.activated.connect(func(_b): level.exit_to_menu())
	var buttons: Array[CloudButton] = [resume, music, sfx, run, restart, quit]
	for b in buttons:
		box.add_child(b)
	add_child(MenuList.new().setup(buttons))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (not event.pressed or event.echo):
		return
	# Esc / P o el botón táctil de pausa reanudan
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resume_game()


func _music_label() -> String:
	return "Música: %s" % ("Sí" if AudioManager.music_on else "No")


func _run_label() -> String:
	return "Correr: %s" % ("siempre" if SaveManager.get_setting("alwaysRun") == true else "mantener")


func _sfx_label() -> String:
	return "Efectos: %s" % ("Sí" if AudioManager.sfx_on else "No")


func resume_game() -> void:
	AudioManager.play("pause")
	level.resume_game()
