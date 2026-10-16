class_name WeaponManager
extends RefCounted
## Inventario y disparo de armas (port de weapons/WeaponManager.js). Las armas se desbloquean
## al recoger su objeto en el nivel; el estado se guarda en GameState para pasar entre escenas.

var level: Node
var player: Player
var owned: Array = []
var current_id := ""
var ready_at := 0.0
var color_index := 0
var no_weapon_hint_at := 0.0


func _init(owner_level: Node, p: Player, owned_ids: Array, current: Variant) -> void:
	level = owner_level
	player = p
	owned = Assets.weapon_order().filter(func(id): return id in owned_ids)
	if current != null and current in owned:
		current_id = current
	else:
		current_id = owned[0] if owned.size() > 0 else ""


var current: WeaponDef:
	get:
		return Assets.weapon(current_id) if current_id != "" else null


func has(id: String) -> bool:
	return id in owned


func unlock(id: String) -> bool:
	if Assets.weapon(id) == null or has(id):
		return false
	owned = Assets.weapon_order().filter(func(w): return w == id or w in owned)
	current_id = id
	emit()
	return true


func cycle() -> void:
	if owned.size() < 2:
		if owned.is_empty():
			hint_no_weapon()
		return
	var i := owned.find(current_id)
	current_id = owned[(i + 1) % owned.size()]
	AudioManager.play("weapon_switch")
	emit()


func emit() -> void:
	GameState.set_v("weapon", current_id if current_id != "" else null)
	GameState.set_v("weaponsOwned", owned.duplicate())


func update(time: float) -> void:
	var c := player.controls
	if player.dead or player.frozen or player.celebrating:
		return
	if c.switch_pressed:
		cycle()
	var wants_fire := c.fire_pressed or (c.fire_held and current_id == "bubble")
	if not wants_fire:
		return
	if current == null:
		if c.fire_pressed:
			hint_no_weapon()
		return
	if time < ready_at or time < player.stunned_until:
		return
	fire(time, c.up)


func hint_no_weapon() -> void:
	AudioManager.play("no_weapon")
	var now: float = level.now
	if now > no_weapon_hint_at:
		no_weapon_hint_at = now + 2500
		GameState.show_toast("¡Aún no tienes arma! Salta sobre los monstruos.")


func fire(time: float, aim_up: bool) -> void:
	var w := current
	var m := player.muzzle()
	var dir := player.facing
	var vx := dir * w.proj_speed
	var vy := w.proj_vy
	if aim_up:
		vx = dir * w.proj_speed * 0.7
		vy = minf(vy, 0) - w.proj_speed * 0.7
	var tint: Variant = null
	if w.proj_tint_cycle == "paint":
		var list: Array = Assets.weapons_meta.paintColors
		tint = C.rgb(int(list[color_index % list.size()]))
		color_index += 1
	elif w.proj_tint_cycle == "foam":
		var list: Array = Assets.weapons_meta.foamColors
		tint = C.rgb(int(list[color_index % list.size()]))
		color_index += 1
	var proj: Projectile = level.spawn_projectile("player", {
		"x": m.x,
		"y": m.y - 6 if aim_up else m.y,
		"vx": vx,
		"vy": vy,
		"gravity": w.proj_gravity,
		"texture": w.proj_texture,
		"frame": w.proj_frame,
		"lifespan": w.proj_lifespan,
		"body": w.proj_body,
		"scale": w.proj_scale,
		"alpha": w.proj_alpha,
		"wobble": 0.0 if aim_up else w.proj_wobble,
		"spin": w.proj_spin,
		"tint": tint,
		"owner": "player",
		"kind": w.id,
		"damage": w.damage,
	})
	if proj == null:
		return
	proj.weapon = w
	proj.paint_color = tint if tint is Color else Color.WHITE
	ready_at = time + w.cooldown
	player.play_attack(w.id, w.recoil)
	AudioManager.play(w.sound)
	if w.proj_trail:
		level.effects.paint_trail(proj, proj.paint_color)
	if w.id == "sling":
		level.camera.shake(60, 0.0015)
