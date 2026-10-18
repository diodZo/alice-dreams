class_name SleepCloud
extends Area2D
## Nube violeta: reduce levemente la velocidad durante un tiempo, sin quitar control.

var duration := 2400.0

## def: { x, y (teselas, centro de la nube), w, h (teselas), duration (ms), atlas, frame }
func setup(def: Dictionary, _atlas := "") -> SleepCloud:
	position = Vector2(float(def.x) * C.TILE + 8, float(def.y) * C.TILE)
	duration = float(def.get("duration", 2400))
	var size := Vector2(float(def.get("w", 3)), float(def.get("h", 2))) * C.TILE
	var spr := Sprite2D.new()
	spr.texture = Assets.frame(def.get("atlas", "w3_fx"), def.get("frame", "sleep_cloud"))
	# el dibujo cubre la zona que adormece, así se ve exactamente dónde está
	spr.scale = size / spr.texture.get_size() * 1.15
	spr.modulate = Color(1, 1, 1, 0.78)
	add_child(spr)
	var tw := spr.create_tween().set_loops()
	tw.tween_property(spr, "modulate:a", 0.55, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "modulate:a", 0.78, 1.1).set_trans(Tween.TRANS_SINE)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	add_child(cs)
	Trigger.configure(self, "sleep_cloud")
	z_index = C.Z_FX
	return self

func apply(player: Player) -> void:
	player.apply_sleep(duration)
	var next_z := float(player.get_meta("sleep_z_at", 0.0))
	if player.now >= next_z:
		player.set_meta("sleep_z_at", player.now + 420)
		var z := Sprite2D.new()
		z.texture = Assets.frame("w3_fx", "sleep_z")
		z.position = player.position + Vector2(7, -34)
		player.level.fx_root.add_child(z)
		var tw := z.create_tween().set_parallel()
		tw.tween_property(z, "position:y", z.position.y - 15, 0.8)
		tw.tween_property(z, "modulate:a", 0.0, 0.8)
		tw.chain().tween_callback(z.queue_free)
