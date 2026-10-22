class_name Anim
## Utilidades de animación con la semántica de Phaser.

## Animaciones pedidas que no existen y ya avisadas ("personaje:animación").
static var _warned := {}

## anims.play(key, ignoreIfPlaying): con ignore=true no reinicia si esa animación ya se está
## reproduciendo; si terminó (no está en bucle) vuelve a empezar, igual que en Phaser.
static func play(sprite: AnimatedSprite2D, anim_name: String, ignore_if_playing := true) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		_warn_missing(sprite, anim_name)
		return
	if ignore_if_playing and sprite.animation == anim_name and sprite.is_playing():
		return
	sprite.play(anim_name)
	sprite.set_frame_and_progress(0, 0.0)


## Muestra un fotograma fijo de una animación (equivale a setFrame + anims.stop).
static func show_frame(sprite: AnimatedSprite2D, anim_name: String, index: int) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim_name):
		_warn_missing(sprite, anim_name)
		return
	sprite.stop()
	sprite.animation = anim_name
	sprite.frame = clampi(index, 0, sprite.sprite_frames.get_frame_count(anim_name) - 1)


## Coloca un AnimatedSprite2D/Sprite2D con origen (ox, oy) relativo a su celda, como setOrigin.
static func set_origin(sprite: Node2D, size: Vector2, ox: float, oy: float) -> void:
	sprite.set("centered", false)
	sprite.set("offset", Vector2(-round(size.x * ox), -round(size.y * oy)))


## Una animación inexistente no rompe el juego (se ignora, como en Phaser), pero en las versiones
## de depuración se avisa una vez por personaje y animación: un nombre mal escrito no pasa
## desapercibido (IMP-012).
static func _warn_missing(sprite: AnimatedSprite2D, anim_name: String) -> void:
	if not OS.is_debug_build() or sprite.sprite_frames == null:
		return
	# nombre legible: escena del personaje (los enemigos instanciados tienen nombres @...@)
	var parent := sprite.get_parent()
	var owner_name := str(sprite.name)
	if parent:
		owner_name = parent.scene_file_path.get_file().get_basename() if parent.scene_file_path != "" else str(parent.name)
	var key := "%s:%s" % [owner_name, anim_name]
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning("[Anim] %s no tiene la animación «%s»" % [owner_name, anim_name])
