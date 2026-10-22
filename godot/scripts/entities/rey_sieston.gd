class_name ReySieston
extends BossBase
## Rey Siestón: tres fases con avisos legibles y ventanas de contraataque.

const MAX_HP := 50
const PHASES := {
	1:{"speed":30.0,"interval":1500.0,"rest":1450.0,"pattern":["PILLOW","HOP","PILLOW"]},
	2:{"speed":48.0,"interval":1250.0,"rest":1350.0,"pattern":["DOUBLE","HOP","CLOUD","WAVE"]},
	3:{"speed":68.0,"interval":980.0,"rest":1500.0,"pattern":["SPIN","RAIN","CLOUD","DOUBLE","WAVE"]},
}

var hop_tween: Tween

func setup(owner_level: Node, boss_cfg: Dictionary) -> void:
	level = owner_level
	cfg = boss_cfg
	min_x = float(cfg.minX) * C.TILE + 38
	max_x = float(cfg.maxX) * C.TILE - 38
	floor_y = float(cfg.floorY)
	position = Vector2(float(cfg.homeX) * C.TILE, -70)

func _ready() -> void:
	z_index = C.Z_ENEMY + 2
	collision_layer = C.L_BOSS
	collision_mask = 0
	monitoring = false
	set_meta("kind", "boss")
	set_meta("entity", self)
	sprite.sprite_frames = Assets.sprite_frames("sieston")
	Anim.set_origin(sprite, Assets.cell_size("sieston"), 0.5, 1.0)
	flash = ShaderMaterial.new()
	flash.shader = preload("res://resources/effects/flash.gdshader")
	sprite.material = flash
	fsm = StateMachine.new(self)
	set_body_enabled(false)

func anim(name: String, ignore := true) -> void: Anim.play(sprite, name, ignore)
func face_player() -> void: sprite.flip_h = player.position.x < position.x
func _physics_process(delta: float) -> void:
	if level == null: return
	timers.process(now)
	if fsm.current != "": fsm.update(now, delta * 1000.0)
	if body_enabled and fsm.current != "INTRO" and not is_defeated():
		position.x = clampf(position.x + velocity.x * delta, min_x, max_x)

func _enter_INTRO(_p: String, _d: Variant) -> void:
	anim("idle")
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self,"position:y",floor_y,1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): level.camera.shake(260,0.005); level.effects.poof(position.x,floor_y,18))
	tw.tween_interval(0.5)
	tw.tween_callback(func(): invulnerable=false; fsm.set_state("IDLE"))

func _enter_IDLE(_p: String, _d: Variant) -> void: anim("move")
func _update_IDLE(_t: float, _d: float) -> void:
	if position.x <= min_x: dir=1
	elif position.x >= max_x: dir=-1
	velocity.x = dir * float(phase_data().speed)
	sprite.flip_h = dir < 0
	if fsm.elapsed > float(phase_data().interval):
		var p: Array = phase_data().pattern
		fsm.set_state(p[pattern_index % p.size()]); pattern_index += 1

func _enter_REST(_p: String, _d: Variant) -> void:
	velocity.x=0; anim("idle")
	level.effects.glow_flash(position+Vector2(0,-35),C.YELLOW,2,5,float(phase_data().rest),0.45,0)
func _update_REST(_t: float, _d: float) -> void:
	if fsm.elapsed > float(phase_data().rest): fsm.set_state("IDLE")

func warn(ms: float) -> void:
	level.effects.glow_flash(position+Vector2(0,-38),C.YELLOW,2,6,ms,0.9,2)
	var mark := PixelText.make("!",{"origin":Vector2(0.5,0.5),"tint":C.YELLOW,"scale":2})
	mark.position=position+Vector2(0,-84); mark.z_index=C.Z_UI_WORLD; level.fx_root.add_child(mark)
	var tw:=mark.create_tween().set_parallel(); tw.tween_property(mark,"position:y",mark.position.y-6,ms/1000.0); tw.tween_property(mark,"modulate:a",0.0,ms/1000.0); tw.chain().tween_callback(mark.queue_free)

func _enter_PILLOW(_p:String,_d:Variant)->void:
	velocity.x=0; face_player(); Anim.show_frame(sprite,"pillow",0); warn(550)
	after(550,func(): anim("pillow",false); _pillow_shot(0))
	after(1350,func(): fsm.set_state("REST"))
func _enter_DOUBLE(_p:String,_d:Variant)->void:
	velocity.x=0; face_player(); Anim.show_frame(sprite,"pillow",0); warn(600)
	for i in 2: after(600+i*330,func(): anim("pillow",false); _pillow_shot(i))
	after(1800,func(): fsm.set_state("REST"))
func _pillow_shot(i:int)->void:
	var d:=facing()
	level.spawn_projectile("boss",{"x":position.x+d*42,"y":position.y-40-i*18,"vx":d*(125+i*20),"vy":-35-i*12,"gravity":80,"texture":"w3_fx","frame":"pillow_shot","lifespan":3600,"body":11,"owner":"boss","kind":"pillow","damage":1,"wobble":5,"spin":90})
	AudioManager.play("shoot_sling")

func _enter_HOP(_p:String,_d:Variant)->void:
	velocity.x=0; face_player(); anim("jump",false); warn(520)
	after(520,func():
		var target:=clampf(player.position.x,min_x,max_x)
		var start:=position
		hop_tween=create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		hop_tween.tween_method(func(k): position=Vector2(lerpf(start.x,target,k),floor_y-sin(k*PI)*90),0.0,1.0,0.85)
		hop_tween.tween_callback(func():
			if not fsm.is_state("HOP"): return
			level.camera.shake(200,0.004); _wave_both(); fsm.set_state("REST")))
## El salto se interrumpe (cambio de fase o derrota): vuelve al suelo sin onda ni descanso.
func _exit_HOP(_n:String)->void:
	if hop_tween and hop_tween.is_valid(): hop_tween.kill()
	position.y=floor_y

func _enter_WAVE(_p:String,_d:Variant)->void:
	velocity.x=0; anim("jump",false); warn(650)
	after(650,_wave_both); after(1450,func(): fsm.set_state("REST"))
func _wave_both()->void:
	for d in [-1,1]: level.spawn_projectile("boss",{"x":position.x+d*35,"y":floor_y-8,"vx":d*125,"vy":0,"texture":"w3_fx","frame":"cotton_wave","lifespan":4000,"body":10,"owner":"boss","kind":"cotton","damage":1})
	level.effects.poof(position.x,floor_y-5,14); AudioManager.play("wind")

func _enter_CLOUD(_p:String,_d:Variant)->void:
	velocity.x=0; anim("special",false); warn(700)
	after(700,func():
		for x in [min_x+80,(min_x+max_x)/2.0,max_x-80]:
			level.spawn_projectile("boss",{"x":x,"y":60,"vx":0,"vy":45,"texture":"w3_fx","frame":"sleep_cloud","lifespan":4200,"body":17,"owner":"boss","kind":"sleep","damage":1,"wobble":10}))
	after(1900,func(): fsm.set_state("REST"))

func _enter_SPIN(_p:String,_d:Variant)->void:
	velocity.x=0; face_player(); anim("special",false); warn(550)
	after(550,func(): velocity.x=facing()*165)
	after(1350,func(): velocity.x=0; _wave_both(); fsm.set_state("REST"))

func _enter_RAIN(_p:String,_d:Variant)->void:
	velocity.x=0; anim("special",false); warn(800)
	after(800,func():
		for i in 7:
			var x:=min_x+30+i*(max_x-min_x-60)/6.0
			if i%3!=1: level.spawn_projectile("boss",{"x":x,"y":-10,"vx":0,"vy":150,"gravity":120,"texture":"w3_fx","frame":"pillow_shot","lifespan":2600,"body":9,"owner":"boss","kind":"pillow_rain","damage":1,"spin":160}))
	after(2050,func(): fsm.set_state("REST"))

func _enter_PHASE_CHANGE(_p:String,_d:Variant)->void:
	invulnerable=true; velocity.x=0; pattern_index=0; timers.clear(); anim("hurt",false)
	level.camera.shake(350,0.005); GameState.show_toast("¡Tormenta de almohadas!" if phase==2 else "¡El último bostezo!")
	after(1100,func(): invulnerable=false; fsm.set_state("IDLE"))

func _enter_DEFEATED(_p:String,_d:Variant)->void:
	timers.clear(); invulnerable=true; velocity=Vector2.ZERO; set_body_enabled(false); anim("hurt",false)
	AudioManager.play("enemy_defeat"); level.camera.shake(260,0.004)
	level.after(650,func(): if is_instance_valid(self): anim("defeated",false); level.effects.confetti(position.x,position.y-38,60))
	level.after(1900,func():
		if is_instance_valid(self):
			var z:=PixelText.make("Z z z",{"origin":Vector2(0.5,0.5),"tint":C.rgb(0xc9b5ff),"scale":1})
			z.position=position+Vector2(0,-82); level.fx_root.add_child(z); defeated_at.emit(position.x-76,position.y-38))
