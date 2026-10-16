extends Control
## Arranque y pantalla de carga (port de BootScene + PreloadScene). Los recursos gráficos
## ya están importados por Godot; aquí se espera a que la música provisional sintetizada
## del menú esté lista y se comprueba que los datos convertidos existen.

var bar: ColorRect
var _elapsed := 0.0


func _ready() -> void:
	var W := float(C.GAME_W)
	var bg := ColorRect.new()
	bg.color = C.BLUE
	bg.size = Vector2(C.GAME_W, C.GAME_H)
	add_child(bg)
	var title := PixelText.make("Guardiana de los Sueños", {"origin": Vector2(0.5, 0.5), "scale": 2, "tint": C.YELLOW})
	title.position = Vector2(W / 2, 100)
	add_child(title)
	var sub := PixelText.make("Cargando el sueño...", {"origin": Vector2(0.5, 0.5), "tint": C.CREAM})
	sub.position = Vector2(W / 2, 128)
	add_child(sub)
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C.INK
	sb.border_color = C.CREAM
	sb.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", sb)
	frame.position = Vector2(W / 2 - 101, 145)
	frame.size = Vector2(202, 10)
	add_child(frame)
	bar = ColorRect.new()
	bar.color = C.PINK
	bar.position = Vector2(W / 2 - 100, 147)
	bar.size = Vector2(0, 6)
	add_child(bar)
	if not Assets.ok:
		# Error explícito: sin datos convertidos no hay nada que cargar.
		push_error("[Boot] Faltan los datos convertidos. Ejecuta: node godot/tools/convert_phaser.mjs")
		var err := PixelText.make("Faltan los recursos.\nEjecuta: node godot/tools/convert_phaser.mjs", {"origin": Vector2(0.5, 0.5), "tint": C.rgb(0xff8080), "center": true})
		err.position = Vector2(W / 2, 190)
		add_child(err)
		set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	var ready := AudioManager.is_music_ready("menu")
	# la barra avanza con el tiempo hasta que la música está lista (como mucho ~8 s)
	var p := 1.0 if ready else minf(0.9, _elapsed / 3.0)
	bar.size.x = 200 * p
	if ready or _elapsed > 8.0:
		set_process(false)
		Router.go("Menu")
