extends Level
## Mundo 1, secciones A-E hasta la puerta del castillo de Nubarrón (port de World1Scene.js).
## Todo lo demás lo aporta el motor común (Level) a partir de data/worlds/world1.json.

var door: CastleDoor


func on_create() -> void:
	door = CastleDoor.new().setup(data.door, data.backgroundAtlas)
	level_objects.objects.add_child(door)


func on_custom_overlap(kind: String, _entity: Object) -> void:
	if kind == "door":
		enter_castle()


func enter_castle() -> void:
	if leaving or player.dead:
		return
	leaving = true
	player.frozen = true
	player.velocity = Vector2.ZERO
	controls.set_enabled(false)
	AudioManager.play("portal")
	GameState.set_v("hp", player.hp)
	await Fader.fade_out(600)
	if is_inside_tree():
		Router.go(data.nextScene)
