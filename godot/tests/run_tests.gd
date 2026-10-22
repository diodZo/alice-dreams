extends "res://tests/test_base.gd"
## Pruebas automáticas (headless). Uso desde la carpeta del repositorio:
##   godot --headless --path godot --fixed-fps 60 res://tests/Tests.tscn
## Cada prueba crea su propio nivel, simula fotogramas de física con controles programados
## y comprueba el resultado. Los valores esperados salen del código Phaser (tuning.js,
## weaponDefs.js, enemyDefs.js, world1.js, Nubarron.js).
##
## Las pruebas están repartidas en tests/suites/ (un archivo por mundo, IMP-013).
##   -- only=test_x,test_y   sólo esas pruebas
##   -- only=w7              sólo un grupo (common, w2 ... w8, narrative)

## [clave del grupo, script]: el orden de ejecución es el de esta lista y el de su TESTS.
const SUITES := [
	["common", preload("res://tests/suites/common_tests.gd")],
	["w2", preload("res://tests/suites/world2_tests.gd")],
	["w3", preload("res://tests/suites/world3_tests.gd")],
	["w4", preload("res://tests/suites/world4_tests.gd")],
	["w5", preload("res://tests/suites/world5_tests.gd")],
	["w6", preload("res://tests/suites/world6_tests.gd")],
	["w7", preload("res://tests/suites/world7_tests.gd")],
	["w8", preload("res://tests/suites/world8_tests.gd")],
	["narrative", preload("res://tests/suites/narrative_tests.gd")],
]


func _ready() -> void:
	SaveManager.save_path = "user://test_save.json"
	SaveManager.load_state()
	# sin pausas de impacto: las pruebas cuentan fotogramas (la de IMP-020 la activa)
	Level.hit_stop_scale = 0.0
	AudioManager.sfx_on = false # sin persistir: no toca el guardado del usuario
	var plan: Array = [] # [grupo (nodo), prueba]
	var groups := {}
	for s in SUITES:
		var node: Node = s[1].new()
		node.name = s[0]
		add_child(node)
		groups[s[0]] = node
		for t in node.TESTS:
			plan.append([node, t])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			var wanted := Array(a.substr(5).split(","))
			plan = plan.filter(func(p): return p[1] in wanted or String(p[0].name) in wanted)
	for p in plan:
		current = p[1]
		var before := failed
		await p[0].call(p[1])
		if is_instance_valid(level):
			level.queue_free()
			level = null
			await get_tree().process_frame
		get_tree().paused = false
		print("%s %s" % ["OK  " if failed == before else "FALLO", p[1]])
	print("
[tests] %d comprobaciones correctas, %d fallidas" % [passed, failed])
	for f in ["user://test_save.json", "user://test_save.json.bad"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	SaveManager.save_path = SaveManager.SAVE_PATH
	SaveManager.load_state()
	get_tree().quit(1 if failed > 0 else 0)
