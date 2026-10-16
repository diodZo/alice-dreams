class_name PlayerAnimator
extends RefCounted
## Selecciona la animación de la protagonista según su estado físico (port de PlayerAnimator.js).
## No modifica la física: sólo lee el estado de Player.
##
## Animaciones (de resources/player/player_frames.tres): idle, blink, walk, run, jump, fall,
## hurt, victory, bubble, paint, sling. "run" reutiliza los fotogramas de caminar a más
## velocidad y "fall" los de salto (la hoja original no trae esas poses).

var player: Player
var next_blink_at := 0.0
var attack_restart := false


func _init(p: Player) -> void:
	player = p
	p.sprite.animation_finished.connect(_on_animation_finished)


func restart_attack() -> void:
	attack_restart = true


func update(time: float) -> void:
	var p := player
	if p.dead or p.celebrating:
		return
	var s := p.sprite
	var key: String
	if time < p.stunned_until:
		key = "hurt"
	elif time < p.attack_until and p.attack_anim != "":
		key = p.attack_anim
		if attack_restart:
			attack_restart = false
			Anim.play(s, key, false)
			return
	elif not p.grounded:
		key = "jump" if p.velocity.y < 0 else "fall"
	elif absf(p.velocity.x) > 12:
		key = "run" if absf(p.velocity.x) > 115 else "walk"
	else:
		key = "idle"
		# parpadeo ocasional en reposo
		if time > next_blink_at:
			next_blink_at = time + 2500 + randf() * 2500
			Anim.play(s, "blink", true)
			return
		if s.animation == "blink" and s.is_playing():
			return
	Anim.play(s, key, true)


func _on_animation_finished() -> void:
	if player.sprite.animation == "blink" and not player.dead and not player.celebrating:
		Anim.play(player.sprite, "idle", true)
