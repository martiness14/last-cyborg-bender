extends Node3D
const Rules = preload("res://scripts/rules.gd")
const Gestures = preload("res://scripts/gestures.gd")
const Art = preload("res://scripts/art.gd")
const Hands = preload("res://scripts/hands.gd")
const EnemyModel = preload("res://scripts/enemy_model.gd")
const TitleScreen = preload("res://scripts/title_screen.gd")
const Sound = preload("res://scripts/sound.gd")
var rules = Rules.new()
var gestures = Gestures.new()
var hands: Node3D
var audio: Node
var xr_origin: XROrigin3D
var camera: XRCamera3D
var xr_interface: OpenXRInterface
var level := Node3D.new()
var ui := Node3D.new()
var pointer: MeshInstance3D
var pointer_line: MeshInstance3D
var shield_visual: MeshInstance3D
var intro_label: Label3D
var tracking_label: Label3D
var hud_label: Label3D
var hud_board: Node3D
var toast_label: Label3D
var buttons: Array[Dictionary] = []
var enemy_nodes: Dictionary = {}
var shot_batch: MultiMeshInstance3D
var muck_batch: MultiMeshInstance3D
var liquid_batch: MultiMeshInstance3D
var last_liquid_sound := -1.0
var effects: Array[Dictionary] = []
const dominant := 1
var paused := false
var focus_ok := true
var stable_tracking := 0.0
var tracking_ready := false
var clock := 0.0
var toast_time := 0.0
var menu_debounce := 0.0
var hint_time := 0.0
var best := 0
var desktop_demo := false
var qa_capture := false
var demo_stage := 0
var demo_time := 0.0
var last_hud := ""
var game_started := false
var fps_clock := 0.0
var intro_saved := false
var save_scores := true
var pause_button: Node3D
var pause_caption: Label3D
var pause_hover := 0.0
var pressure_fill: MeshInstance3D
var title_revealed := false
## One-time cyborg boss entrance after a minute of real fighting.
const CYBORG_ENTRANCE_AT := 65.0
const CYBORG_RISE := 2.5
var cyborg_seen := false
var cyborg_show: Node3D
var cyborg_model
var cyborg_label: Label3D
var cyborg_time := -1.0
var cyborg_end := INF
var cyborg_stage: Node3D
var cyborg_lights: Array[Dictionary] = []
const BOSS_VIDEO := "res://assets/boss_intro.ogv"
const BOSS_VIDEO_LOOPS := 3
var cyborg_video: VideoStreamPlayer
const DISCO := [Color("ff3fa4"),Color("3fd2ff"),Color("ffe14a"),Color("7dff6a"),Color("b06bff")]

func _ready() -> void:
	# Desktop automation is explicitly gated off on Android. Shipping input is hands only.
	desktop_demo = not OS.has_feature("android") and "--demo" in OS.get_cmdline_user_args()
	qa_capture = not OS.has_feature("android") and "--capture" in OS.get_cmdline_user_args()
	var config := ConfigFile.new()
	if config.load("user://scores.cfg") == OK:
		best = int(config.get_value("arcade","best",0))
		cyborg_seen = bool(config.get_value("arcade","cyborg_entrance",false))
	xr_origin = XROrigin3D.new()
	add_child(xr_origin)
	camera = XRCamera3D.new()
	xr_origin.add_child(camera)
	camera.near = 0.04
	camera.far = 35
	camera.fov = 85
	camera.position.y = 1.6
	xr_interface = XRServer.find_interface("OpenXR") as OpenXRInterface
	if not desktop_demo and xr_interface and (xr_interface.is_initialized() or xr_interface.initialize()):
		get_viewport().use_xr = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		camera.position = Vector3.ZERO
		if xr_interface.has_signal("session_focussed"):
			xr_interface.connect("session_focussed", _xr_focus.bind(true))
			xr_interface.connect("session_visible", _xr_focus.bind(false))
			xr_interface.connect("session_stopping", _xr_focus.bind(false))
			xr_interface.session_begun.connect(_xr_begun)
			xr_interface.pose_recentered.connect(_recenter)
		print("CHAYKA XR READY hands-only")
	else:
		print("CHAYKA DESKTOP " + ("DEMO" if desktop_demo else "NO XR - WAITING FOR HANDS"))
	hands = Hands.new()
	hands.origin = xr_origin
	add_child(hands)
	audio = Sound.new()
	add_child(audio)
	add_child(level)
	Art.new().build_house(level)
	level.visible = false
	var desni := Art.character(level,3,1.6)
	desni.position = Vector3(-1.6,0.86,2.68)
	Art.label(level,"ДЕСНИСЛАВА",Vector3(-1.6,2.65,2.55),32).rotation.y = PI
	add_child(ui)
	pointer = Art.ball(self,0.014,Vector3.ZERO,Art.YELLOW)
	pointer.visible = false
	pointer_line = Art.tube(self,0.002,1.0,Vector3.ZERO,Art.YELLOW)
	pointer_line.visible = false
	shield_visual = Art.box(self,Vector3(0.78,0.86,0.025),Vector3.ZERO,Color("73ccae"))
	var sm := Art.material(Color(0.35,0.86,0.72,0.30))
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_visual.material_override = sm
	shield_visual.visible = false
	intro_label = Art.label(camera,"",Vector3(0,-0.25,-1.7),29)
	tracking_label = Art.label(camera,"",Vector3(0,0.15,-1.7),28,Art.YELLOW)
	hud_board = Node3D.new()
	camera.add_child(hud_board)
	hud_board.position = Vector3(0,0.70,-1.75)
	Art.box(hud_board,Vector3(2.40,0.32,0.016),Vector3.ZERO,Art.BLUE)
	Art.box(hud_board,Vector3(2.37,0.29,0.018),Vector3(0,0,0.012),Art.INK)
	hud_board.visible = false
	hud_label = Art.label(hud_board,"",Vector3(0,0,0.025),26,Art.CREAM)
	toast_label = Art.label(camera,"",Vector3(0,-0.48,-1.7),26,Art.YELLOW)
	pause_button = Node3D.new()
	camera.add_child(pause_button)
	pause_button.position = Vector3(1.01,0.37,-1.75)
	Art.box(pause_button,Vector3(0.39,0.15,0.025),Vector3.ZERO,Art.INK)
	pause_caption = Art.label(pause_button,"ПАУЗА",Vector3(0,0,0.02),23,Art.CREAM)
	pause_button.visible = false
	Art.box(hud_board,Vector3(1.25,0.025,0.016),Vector3(0,-0.19,0.03),Art.INK)
	pressure_fill = Art.box(hud_board,Vector3(1.23,0.021,0.018),Vector3(0,-0.19,0.045),Art.BLUE)
	shot_batch = _projectile_batch(Rules.MAX_SHOTS,Color("ffffff"),0.012)
	liquid_batch = _make_liquid_batch()
	muck_batch = _projectile_batch(32,Color("a1c641"))
	rules.event.connect(_on_event)
	show_intro()
	print("CHAYKA READY: intro -> menu -> five waves -> result; no controller bindings")

func _xr_focus(value: bool) -> void:
	focus_ok = value
	stable_tracking = 0
	gestures.reset_motion()

func _xr_begun() -> void:
	var rates: Array = xr_interface.get_available_display_refresh_rates()
	if 72.0 in rates:
		xr_interface.set_display_refresh_rate(72.0)
	print("CHAYKA XR refresh=",xr_interface.get_display_refresh_rate())

func _recenter() -> void:
	stable_tracking = 0
	gestures.reset_motion()
	_recenter_scene.call_deferred()

func _recenter_scene() -> void:
	if rules.state in ["playing","break"]:
		level.global_position = Vector3(camera.global_position.x,0,camera.global_position.z)
		level.rotation.y = camera.global_rotation.y
		# Recentering must never turn ordinary hand movement into a pause menu.
	elif ui.visible:
		_anchor_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		focus_ok = false
		stable_tracking = 0
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		focus_ok = true
		stable_tracking = 0

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	clock += delta
	fps_clock += delta
	if fps_clock > 5:
		fps_clock = 0
		print("CHAYKA FPS ",Engine.get_frames_per_second()," state=",rules.state," enemies=",rules.enemies.size()," hands=",tracking_ready)
	menu_debounce = maxf(0,menu_debounce-delta)
	toast_time = maxf(0,toast_time-delta)
	if toast_time <= 0:
		toast_label.text = ""
	var sample: Array[Dictionary] = hands.sample()
	if desktop_demo:
		sample = _demo_hands()
		for h in range(2):
			hands.visualize(h,sample[h])
	var right_tracked: bool = sample[1].get("valid",false)
	if right_tracked and focus_ok:
		stable_tracking += delta
	else:
		stable_tracking = 0
		gestures.reset_motion()
	tracking_ready = stable_tracking >= 0.4
	var input: Dictionary = gestures.update(sample[0],sample[1],delta) if tracking_ready else {}
	if rules.state == "intro":
		# The name appears automatically; there is no invisible gesture gate.
		if clock > 0.8:
			rules.state = "menu"
			show_menu()
	elif rules.state in ["menu","victory","defeat"] or paused:
		_menu_input(sample,input)
	elif cyborg_time >= 0.0:
		_update_cyborg_entrance(delta)
	else:
		_pause_input(sample,input,delta)
		if tracking_ready and not paused:
			_update_hand_emitter(sample)
			if input.get("stroke",false):
				rules.stroke(input.get("stroke_interval",0.65))
			if input.get("taunt",false):
				rules.taunt()
			if input.get("clap",false):
				if not rules.clap():
					toast("Плясъкът иска 55 пяна • изчакай зареждането")
			rules.shield = input.get("shield",false) and rules.foam > 0
		else:
			rules.shield = false
		rules.tick(delta,not tracking_ready or paused)
		_sync_game(delta)
		if not cyborg_seen and rules.state == "playing" and tracking_ready and not paused and rules.elapsed >= CYBORG_ENTRANCE_AT:
			_start_cyborg_entrance()
	_update_tracking_notice(right_tracked)
	if not tracking_ready:
		shield_visual.visible = false
		pointer_line.visible = false
	hud_board.visible = rules.state in ["playing","break"] and not paused and cyborg_time < 0.0
	pause_button.visible = hud_board.visible
	_update_effects(delta if tracking_ready and not paused else 0)
	if desktop_demo:
		_demo_step(delta)

func _update_tracking_notice(right_tracked: bool) -> void:
	if tracking_ready:
		tracking_label.text = ""
	elif rules.state == "intro" and clock < 4:
		tracking_label.text = ""
	else:
		tracking_label.text = "Покажи дясната ръка пред каската" if not right_tracked else "Ръката е тук…"
		if game_started and not right_tracked:
			tracking_label.text += "\nБоят е спрян"

func _update_hand_emitter(sample: Array[Dictionary]) -> void:
	var grip: Dictionary = sample[dominant]
	var scrub: Dictionary = sample[1-dominant]
	var axis: Vector3 = grip.axis.normalized()
	# Start foam just beyond the tracked glove, rather than at a tool barrel.
	var emitter: Vector3 = grip.palm + axis * 0.08
	rules.set_aim(level.to_local(emitter),level.global_basis.inverse()*axis)
	shield_visual.visible = rules.shield and scrub.get("valid",false)
	if shield_visual.visible:
		shield_visual.global_position = scrub.palm + (-camera.global_basis.z)*0.12
		shield_visual.global_basis = camera.global_basis

func _clear_ui() -> void:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	buttons.clear()
	pointer.visible = false
	pointer_line.visible = false

func show_intro() -> void:
	_clear_ui()
	intro_label.text = ""
	level.visible = false
	ui.visible = false

func _anchor_ui() -> void:
	var forward := -camera.global_basis.z
	forward.y = 0
	if forward.length() < 0.1:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	ui.global_position = camera.global_position + forward * 2.3
	ui.global_rotation = Vector3(0,atan2(-forward.x,-forward.z),0)

func show_menu(heading: String = "") -> void:
	_clear_ui()
	_anchor_ui()
	ui.visible = true
	shield_visual.visible = false
	intro_label.text = ""
	if heading == "":
		var title := TitleScreen.new()
		ui.add_child(title)
		title.build(not title_revealed)
		title_revealed = true
		menu_debounce = 1.4
		Art.label(ui,"Бавно движение ↑↓ зарежда налягането",Vector3(0,-0.38,0.12),24,Art.CREAM)
		_add_button("start","В БОЯ",Vector2(0,-0.60),Vector2(1.50,0.27),Art.ORANGE)
		_add_button("sound","ЗВУК: " + ("ДА" if audio.enabled else "НЕ"),Vector2(0,-0.92),Vector2(0.85,0.16),Color("9bbdc0"))
		Art.label(ui,"Насочи и щипни   •   Рекорд: %d" % best,Vector3(0,-1.08,0.12),20,Art.CREAM)
		audio.play("title")
	else:
		menu_debounce = 0.65
		Art.box(ui,Vector3(2.65,1.85,0.06),Vector3.ZERO,Art.INK)
		Art.box(ui,Vector3(2.57,1.77,0.03),Vector3(0,0,0.04),Art.CREAM)
		Art.label(ui,heading,Vector3(0,0.68,0.065),47,Art.ORANGE)
		var instructions := "Десен юмрук ↑↓ → налягане и пяна\nБавно и ритмично → по-силна струя\n10 помпания → плътна струя  •  Лява длан → щит\nСреден пръст → ярост  •  Плясък → взрив"
		Art.label(ui,instructions,Vector3(0,0.18,0.068),29,Art.INK)
		_add_button("continue","ПРОДЪЛЖИ",Vector2(0,-0.30),Vector2(1.5,0.26),Art.ORANGE)
		_add_button("sound","ЗВУК: " + ("ДА" if audio.enabled else "НЕ"),Vector2(0,-0.65),Vector2(1.10,0.20),Color("9bbdc0"))

func _pause_input(sample: Array[Dictionary], input: Dictionary, delta: float) -> void:
	# A deliberate pointed button replaces the ambiguous open-palms gesture.
	if not tracking_ready or not sample[1].get("valid",false):
		pause_hover = 0
		return
	var hand: Dictionary = sample[1]
	var origin: Vector3 = pause_button.to_local(hand.ray_origin)
	var ray: Vector3 = pause_button.global_basis.inverse()*hand.ray_direction
	var over := false
	if absf(ray.z)>0.01:
		var t: float = (0.02-origin.z)/ray.z
		var p: Vector3 = origin+ray*t
		over = t>0 and t<4 and absf(p.x)<0.20 and absf(p.y)<0.09
	pause_hover = pause_hover+delta if over else 0.0
	pause_caption.text = "ЩИПНИ" if pause_hover>=0.75 else "ПАУЗА"
	pause_caption.modulate = Art.YELLOW if over else Art.CREAM
	if pause_hover>=0.75 and input.get("pinch_right",false):
		paused = true
		pause_hover = 0
		show_menu("ПАУЗА")
		print("CHAYKA PAUSE deliberate_button")

func _add_button(id: String, caption: String, pos: Vector2, size: Vector2, color: Color) -> void:
	Art.box(ui,Vector3(size.x+0.035,size.y+0.035,0.03),Vector3(pos.x,pos.y,0.08),Art.INK)
	var mesh := Art.box(ui,Vector3(size.x,size.y,0.04),Vector3(pos.x,pos.y,0.10),color)
	Art.label(ui,caption,Vector3(pos.x,pos.y,0.13),38,Art.INK)
	buttons.append({"id":id,"pos":pos,"size":size,"mesh":mesh,"color":color})

func _menu_input(sample: Array[Dictionary], input: Dictionary) -> void:
	if not ui.visible or not tracking_ready:
		pointer.visible = false
		pointer_line.visible = false
		return
	var chosen := ""
	var click := false
	var on_panel := false
	for h in [dominant,1-dominant]:
		var hand: Dictionary = sample[h]
		if not hand.get("valid",false):
			continue
		var ray_pos: Vector3 = ui.to_local(hand.ray_origin)
		var ray_dir: Vector3 = ui.global_basis.inverse()*hand.ray_direction
		if absf(ray_dir.z) < 0.01:
			continue
		var t: float = (0.14-ray_pos.z)/ray_dir.z
		if t <= 0 or t > 6:
			continue
		var point: Vector3 = ray_pos+ray_dir*t
		if not on_panel and absf(point.x)<2.0 and absf(point.y)<1.25:
			on_panel = true
			pointer.global_position = ui.to_global(point)
			var distance: float = hand.ray_origin.distance_to(pointer.global_position)
			pointer_line.global_position = (hand.ray_origin+pointer.global_position)/2
			pointer_line.global_basis = Basis(Quaternion(Vector3.UP,(pointer.global_position-hand.ray_origin).normalized())).scaled(Vector3(1,distance,1))
		for b in buttons:
			if absf(point.x-b.pos.x) <= b.size.x/2 and absf(point.y-b.pos.y) <= b.size.y/2:
				chosen = b.id
				pointer.global_position = ui.to_global(point)
				click = input.get("pinch_left" if h==0 else "pinch_right",false)
				break
		if chosen != "":
			break
	pointer.visible = on_panel
	pointer_line.visible = on_panel
	for b in buttons:
		b.mesh.material_override.albedo_color = b.color.lightened(0.25) if b.id == chosen else b.color
	if click and menu_debounce <= 0:
		_activate_button(chosen)

func _activate_button(id: String) -> void:
	menu_debounce = 0.5
	gestures.reset_motion()
	match id:
		"start": start_game()
		"continue":
			paused = false
			ui.visible = false
			stable_tracking = 0
		"sound":
			audio.enabled = not audio.enabled
			show_menu("ПАУЗА" if paused else "")
		"menu":
			rules.state = "menu"
			paused = false
			level.visible = false
			hud_label.text = ""
			show_menu()
	audio.play("menu")

func start_game() -> void:
	if cyborg_time >= 0.0:
		_end_cyborg_entrance()
	_clear_enemies()
	ui.visible = false
	pointer.visible = false
	pointer_line.visible = false
	paused = false
	game_started = true
	# Align the house with the user's current standing position and horizontal gaze.
	level.global_position = Vector3(camera.global_position.x,0,camera.global_position.z)
	level.rotation.y = camera.global_rotation.y
	level.visible = true
	stable_tracking = 0
	gestures.reset_motion()
	rules.reset()
	toast("Десен юмрук нагоре–надолу. Насочи пяната. Пази дома!",4.0)

func _start_cyborg_entrance() -> void:
	cyborg_seen = true
	cyborg_time = 0.0
	cyborg_end = INF
	rules.shield = false
	shield_visual.visible = false
	pause_hover = 0.0
	if save_scores and not desktop_demo:
		var save := ConfigFile.new()
		save.load("user://scores.cfg")
		save.set_value("arcade","cyborg_entrance",true)
		save.save("user://scores.cfg")
	cyborg_show = Node3D.new()
	level.add_child(cyborg_show)
	cyborg_show.position = Vector3(0,0,-5.2) if not ResourceLoader.exists(BOSS_VIDEO) else Vector3(1.75,0,-4.6)
	cyborg_show.scale = Vector3.ONE*0.01
	cyborg_model = EnemyModel.new()
	cyborg_show.add_child(cyborg_model)
	cyborg_model.setup(3,2.0 if not ResourceLoader.exists(BOSS_VIDEO) else 1.6)
	# Head-locked banner: the room ceiling would hide a label above the giant.
	cyborg_label = Art.label(camera,"КИБОРГ БЕНДЪР",Vector3(0,0.45,-1.7),72,Art.ORANGE)
	cyborg_label.outline_size = 10
	_dress_cyborg()
	toast("!!! ВНИМАНИЕ: КИБОРГ БЕНДЪР !!!",CYBORG_RISE)
	audio.play("wave")
	print("CHAYKA CYBORG ENTRANCE")

func _update_cyborg_entrance(delta: float) -> void:
	var before := cyborg_time
	cyborg_time += delta
	var t := cyborg_time
	# The fight is frozen while the boss makes its entrance.
	rules.shield = false
	rules.tick(delta,true)
	_sync_game(0.0)
	# Clear the floor for the giant: frozen invaders step out of sight until the number ends.
	for visual in enemy_nodes.values():
		visual.root.visible = t < CYBORG_RISE*0.5
	if t < CYBORG_RISE:
		cyborg_show.scale = Vector3.ONE*maxf(0.01,ease(t/CYBORG_RISE,0.4))
		if int(before/0.5) != int(t/0.5):
			audio.play("overheat")
	elif cyborg_end == INF:
		cyborg_show.scale = Vector3.ONE
		cyborg_stage.visible = true
		if cyborg_video:
			# The intro clip on the big screen carries the music; the synth theme is the fallback.
			audio.unmute_master()
			cyborg_video.play()
			var length := cyborg_video.get_stream_length()
			cyborg_end = t+(length if length > 0.5 else 7.6)*BOSS_VIDEO_LOOPS+0.3
		else:
			audio.play_anthem()
			cyborg_end = t+audio.anthem_length()+0.3
	if cyborg_stage.visible:
		_animate_cyborg_stage(t,delta)
	# Dance on the 113 BPM beat.
	var beat := t*TAU*113.0/60.0
	cyborg_show.rotation.z = sin(beat*0.5)*0.12
	cyborg_show.position.y = absf(sin(beat*0.5))*0.25
	cyborg_model.animate(t*1.4,false,0.0,true)
	cyborg_model.parts.arm_l.rotation.z = -2.3+sin(beat)*0.45
	cyborg_model.parts.arm_r.rotation.z = 2.3-sin(beat)*0.45
	cyborg_label.modulate = Art.YELLOW if fmod(t*113.0/60.0,1.0) < 0.5 else Art.ORANGE
	if t >= cyborg_end:
		_end_cyborg_entrance()

func _end_cyborg_entrance() -> void:
	audio.stop_anthem()
	if cyborg_video:
		cyborg_video.stop()
	cyborg_video = null
	if cyborg_show:
		cyborg_show.queue_free()
		cyborg_label.queue_free()
		cyborg_stage.queue_free()
	cyborg_stage = null
	cyborg_lights.clear()
	for visual in enemy_nodes.values():
		visual.root.visible = true
	cyborg_show = null
	cyborg_model = null
	cyborg_label = null
	cyborg_time = -1.0
	cyborg_end = INF
	stable_tracking = 0
	gestures.reset_motion()
	toast("Киборгът ще се върне… Пази дома!",3.0)

## Showman costume and a disco stage for the boss number.
func _dress_cyborg() -> void:
	var hair := Color("7a3f22")
	var coat := Color("b9a27a")
	var head: Node3D = cyborg_model.parts.head
	for item in [[Vector3(0,0.38,0.08),Vector3(0.36,0.18,0.30)],[Vector3(0,0.50,0.17),Vector3(0.30,0.15,0.22)],[Vector3(0,0.33,-0.12),Vector3(0.38,0.18,0.26)]]:
		var tuft := Art.ball(head,1.0,item[0],hair)
		tuft.scale = item[1]
	var body: Node3D = cyborg_model.parts.body
	Art.box(body,Vector3(0.98,0.95,0.06),Vector3(0,0.62,-0.30),coat)
	for side in [-1,1]:
		var lapel := Art.box(body,Vector3(0.17,0.78,0.05),Vector3(side*0.30,0.66,0.27),coat)
		lapel.rotation.z = side*0.12
		var tail := Art.box(body,Vector3(0.22,0.55,0.05),Vector3(side*0.36,0.12,0.12),coat)
		tail.rotation.y = side*0.35
	var arm: Node3D = cyborg_model.parts.arm_l
	Art.box(arm,Vector3(0.05,0.30,0.05),Vector3(0,-0.40,0.14),Art.INK)
	Art.ball(arm,0.075,Vector3(0,-0.24,0.14),Color("3a3f44"))
	cyborg_stage = Node3D.new()
	level.add_child(cyborg_stage)
	cyborg_stage.visible = false
	_build_cyborg_screen()
	var center := Vector3(0,0,-5.2)
	var disco := Node3D.new()
	cyborg_stage.add_child(disco)
	disco.position = Vector3(-1.4,2.15,-3.6)
	Art.ball(disco,0.22,Vector3.ZERO,Color("d9e2e6"))
	for n in range(18):
		var facet := Art.box(disco,Vector3(0.07,0.07,0.02),Vector3.ZERO,DISCO[n%DISCO.size()])
		var dir := Vector3(cos(n*2.399),sin(n*1.3)*0.8,sin(n*2.399)).normalized()
		facet.position = dir*0.225
		facet.basis = Basis.looking_at(dir,Vector3.UP if absf(dir.y)<0.95 else Vector3.RIGHT)
	cyborg_lights.append({"node":disco,"kind":"disco"})
	for n in range(4):
		var beam := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.03
		cone.bottom_radius = 0.45
		cone.height = 2.6
		cone.radial_segments = 12
		beam.mesh = cone
		var glow := Art.material(Color(DISCO[n],0.16))
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam.material_override = glow
		var pivot := Node3D.new()
		cyborg_stage.add_child(pivot)
		pivot.position = Vector3((n-1.5)*1.2,2.55,-5.9)
		pivot.add_child(beam)
		beam.position = Vector3(0,-1.3,0)
		cyborg_lights.append({"node":pivot,"kind":"beam","phase":n*1.7,"material":glow,"color":n})
	for x in range(-2,3):
		for z in range(-1,2):
			var tile := Art.box(cyborg_stage,Vector3(0.9,0.02,0.9),center+Vector3(x*0.95,0.015,z*0.95+0.6),DISCO[0])
			var paint := Art.material(DISCO[0])
			tile.material_override = paint
			cyborg_lights.append({"node":tile,"kind":"tile","material":paint,"seed":(x+2)*3+z+1})
	for n in range(8):
		var note := Node3D.new()
		cyborg_stage.add_child(note)
		var color: Color = DISCO[n%DISCO.size()]
		var head_ball := Art.ball(note,0.07,Vector3.ZERO,color)
		head_ball.scale = Vector3(1.25,0.9,0.6)
		Art.box(note,Vector3(0.022,0.30,0.022),Vector3(0.075,0.15,0),color)
		Art.box(note,Vector3(0.12,0.03,0.022),Vector3(0.13,0.29,0),color).rotation.z = -0.5
		cyborg_lights.append({"node":note,"kind":"note","phase":float(n)/8.0,"x":(n-3.5)*0.75})

## Big screen behind the dance floor, fed by a SubViewport with the boss intro clip.
func _build_cyborg_screen() -> void:
	if not ResourceLoader.exists(BOSS_VIDEO):
		return
	var stream: VideoStream = load(BOSS_VIDEO)
	if not stream:
		return
	var feed := SubViewport.new()
	feed.size = Vector2i(640,360)
	feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cyborg_stage.add_child(feed)
	cyborg_video = VideoStreamPlayer.new()
	cyborg_video.stream = stream
	cyborg_video.expand = true
	cyborg_video.size = Vector2(640,360)
	cyborg_video.volume_db = 0.0
	cyborg_video.loop = true
	feed.add_child(cyborg_video)
	var screen := Node3D.new()
	cyborg_stage.add_child(screen)
	screen.position = Vector3(0,1.32,-6.0)
	Art.box(screen,Vector3(3.10,1.82,0.06),Vector3(0,0,-0.04),Art.INK)
	var panel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.96,1.665)
	panel.mesh = quad
	var picture := Art.material(Color.WHITE)
	picture.albedo_texture = feed.get_texture()
	panel.material_override = picture
	screen.add_child(panel)
	for side in [-1,1]:
		Art.box(screen,Vector3(0.08,1.32,0.08),Vector3(side*1.2,-1.32,-0.05),Art.INK)

func _animate_cyborg_stage(t: float, delta: float) -> void:
	var beats := t*113.0/60.0
	var step := int(beats)
	for light in cyborg_lights:
		var node: Node3D = light.node
		match light.kind:
			"disco":
				node.rotation.y += delta*1.6
			"beam":
				node.rotation = Vector3(0.25+sin(t*1.3+light.phase)*0.3,0,cos(t*0.9+light.phase)*0.45)
				var tint: Color = DISCO[(light.color+step)%DISCO.size()]
				light.material.albedo_color = Color(tint,0.16)
			"tile":
				var lit: bool = (light.seed+step)%3 == 0
				light.material.albedo_color = DISCO[(light.seed+step)%DISCO.size()] if lit else Art.INK.lightened(0.15)
			"note":
				var rise: float = fmod(t*0.35+light.phase,1.0)
				node.position = Vector3(light.x+sin(t*2.0+light.x)*0.25,0.6+rise*2.0,-4.3)
				node.rotation.z = sin(t*4.0+light.x)*0.4
				node.scale = Vector3.ONE*(1.0-absf(rise-0.5)*1.2)

func _projectile_batch(count: int, color: Color, radius: float = 0.09) -> MultiMeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius*2
	sphere.radial_segments = 8
	sphere.rings = 4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = count
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = Art.material(color)
	level.add_child(node)
	return node

func _make_liquid_batch() -> MultiMeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 7
	var node := MultiMeshInstance3D.new()
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.mesh = cylinder
	node.multimesh.instance_count = Rules.MAX_SHOTS
	node.multimesh.visible_instance_count = 0
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded;
void fragment() {
 float shine = dot(normalize(NORMAL),normalize(vec3(-0.4,0.6,0.7)));
 ALBEDO = mix(vec3(0.70,0.84,0.87),vec3(1.0),smoothstep(-0.4,0.5,shine));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material_override = material
	shot_batch.material_override = material
	level.add_child(node)
	return node

func _sync_liquid() -> void:
	var count: int = mini(Rules.MAX_SHOTS,rules.shots.size())
	shot_batch.multimesh.visible_instance_count = count
	var links := 0
	for i in range(count):
		var shot: Dictionary = rules.shots[i]
		var speed: float = shot.vel.length()
		var size: float = shot.get("size",1.0)
		var length: float = clampf(speed*0.012,0.025,0.09)
		var facing := Basis(Quaternion(Vector3.UP,shot.vel.normalized())) if speed>0.01 else Basis.IDENTITY
		var shape := facing * Basis.from_scale(Vector3(size,size*length/0.024,size))
		shot_batch.multimesh.set_instance_transform(i,Transform3D(shape,shot.pos))
		if i == 0 or not shot.get("liquid",false):
			continue
		var previous: Dictionary = rules.shots[i-1]
		var difference: Vector3 = shot.pos-previous.pos
		var distance := difference.length()
		var gap: float = shot.get("born",0.0)-previous.get("born",0.0)
		# Join only neighboring live droplets from a continuous flow. Never bridge a hit or a hand jump.
		if previous.get("liquid",false) and shot.id==previous.id+1 and gap>0 and gap<0.04 and distance>0.002 and distance<0.6:
			var radius := 0.008*minf(size,previous.get("size",1.0))
			liquid_batch.multimesh.set_instance_transform(links,liquid_segment_transform(previous.pos,shot.pos,radius))
			links += 1
	liquid_batch.multimesh.visible_instance_count = links

static func liquid_segment_transform(start: Vector3, finish: Vector3, radius: float) -> Transform3D:
	var difference := finish-start
	var length := difference.length()
	if length < 0.0001:
		return Transform3D(Basis.IDENTITY,start)
	var basis := Basis(Quaternion(Vector3.UP,difference/length)) * Basis.from_scale(Vector3(radius,length,radius))
	return Transform3D(basis,(start+finish)*0.5)

func _clear_enemies() -> void:
	for entry in enemy_nodes.values():
		entry.root.queue_free()
	enemy_nodes.clear()
	for effect in effects:
		effect.node.queue_free()
	effects.clear()

func _sync_game(delta: float) -> void:
	var alive: Dictionary = {}
	for e in rules.enemies:
		alive[e.id] = true
		if not enemy_nodes.has(e.id):
			var root := Node3D.new()
			level.add_child(root)
			var model := EnemyModel.new()
			root.add_child(model)
			model.setup(e.kind,e.scale)
			var bar := Art.box(root,Vector3(0.7,0.04,0.02),Vector3(0,e.height+0.08,0),Art.ORANGE)
			var caption := Art.label(root,"",Vector3(0,e.height+0.22,0),25,Art.YELLOW)
			caption.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			enemy_nodes[e.id] = {"root":root,"model":model,"bar":bar,"caption":caption}
		var visual: Dictionary = enemy_nodes[e.id]
		visual.root.position = e.pos
		visual.root.rotation.y = atan2(-e.pos.x,-e.pos.z)
		visual.model.animate(e.age,rules.rage>0,e.flash,e.kind!=2 or e.pos.length()>4.5)
		visual.bar.scale.x = maxf(0.01,e.hp/e.max_hp)
		visual.caption.text = "КИБОРГ БЕНДЪР" if e.boss else ("ЯРОСТ!" if rules.rage>0 else "")
		if e.hp <= 0:
			visual.root.scale = Vector3.ONE * maxf(0.01,e.death/0.65)
			visual.root.rotation.z += delta*4
			visual.bar.visible = false
	for id in enemy_nodes.keys():
		if not alive.has(id):
			enemy_nodes[id].root.queue_free()
			enemy_nodes.erase(id)
	_sync_liquid()
	_sync_batch(muck_batch,rules.muck)
	var text := "ВЪЛНА %d / 5     ДОМ %d%%     ТОЧКИ %d\nПЯНА %d%%     НАЛЯГАНЕ %d%%     КОМБО x%d" % [rules.wave,rules.health,rules.score,rules.foam,rules.pressure,maxi(1,rules.combo)]
	if rules.pump_count < 10:
		text += "\nПОМПАНЕ %d / 10" % rules.pump_count
	if rules.overheated:
		text += "\nПРЕГРЯ! Изчакай охлаждането."
	elif rules.state == "break":
		text += "\nСледваща вълна: %d • Зареди пяна!" % ceili(rules.intermission)
	elif rules.rage > 0:
		text += "\nРАЗГНЕВЕНИ: %d сек" % ceili(rules.rage)
	pressure_fill.scale.x = maxf(0.01,rules.pressure/100.0)
	pressure_fill.position.x = -0.615*(1.0-rules.pressure/100.0)
	if text != last_hud:
		last_hud = text
		hud_label.text = text

func _sync_batch(batch: MultiMeshInstance3D, items: Array) -> void:
	var count := mini(batch.multimesh.instance_count,items.size())
	batch.multimesh.visible_instance_count = count
	for i in range(count):
		batch.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*items[i].get("size",1.0)),items[i].pos))

func toast(message: String, duration: float = 2.0) -> void:
	toast_label.text = message
	toast_time = duration

func _on_event(kind: String, data: Dictionary) -> void:
	if kind != "shoot" or clock-last_liquid_sound > 0.12:
		audio.play(kind)
		if kind == "shoot":
			last_liquid_sound = clock
	match kind:
		"menu": show_menu()
		"wave": toast("ВЪЛНА %d • %d нашественици%s" % [data.wave,data.count," + КИБОРГИ!" if data.wave==2 else ""],3)
		"taunt": toast("+40 ПЯНА • РАЗГНЕВИ ГИ ЗА 6 СЕК!")
		"clap":
			toast("ГОЛЯМОТО ИЗПИРАНЕ!")
			_burst(Vector3(0,1.2,-1),18,1.4)
		"hit": _burst(data.pos,3,0.2)
		"splash": _burst(data.pos,3,0.18)
		"kill":
			_burst(data.pos,9,0.55)
			var label := Art.label(level,"+%d"%data.points,data.pos,45,Art.YELLOW)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			effects.append({"node":label,"life":0.85,"max":0.85,"velocity":Vector3(0,0.8,0)})
		"damage": toast("ПРОБИВ! −%d ДОМ" % data.amount)
		"block": toast("БЛОКИРАНО!",0.6)
		"overheat": toast("ПРЕГРЯ! Дай си почивка.",2)
		"cooled": toast("Готова за още пяна.")
		"break": toast("ЧИСТО! +8 ДОМ • Зареди за следващата вълна",3)
		"victory","defeat": show_result(kind=="victory")

func _burst(pos: Vector3, count: int, speed: float) -> void:
	for n in range(count):
		if effects.size() >= 72:
			break
		var ball := Art.ball(level,0.012+randi_range(0,3)*0.004,pos,Art.CREAM)
		var velocity := Vector3(sin(n*2.4),0.5+cos(n),cos(n*2.4))*speed
		effects.append({"node":ball,"life":0.6,"max":0.6,"velocity":velocity})

func _update_effects(delta: float) -> void:
	for e in effects:
		e.life -= delta
		e.node.position += e.velocity*delta
		e.velocity.y -= 4.0*delta
		e.node.scale = Vector3.ONE * maxf(0.01,e.life/e.max)
		if e.life <= 0:
			e.node.queue_free()
	effects = effects.filter(func(e: Dictionary) -> bool: return e.life>0)

func show_result(won: bool) -> void:
	best = maxi(best,rules.score)
	if not desktop_demo and save_scores:
		var save := ConfigFile.new()
		save.set_value("arcade","best",best)
		save.save("user://scores.cfg")
	_clear_ui()
	_anchor_ui()
	ui.visible = true
	shield_visual.visible = false
	menu_debounce = 1.0
	Art.box(ui,Vector3(2.5,1.5,0.05),Vector3.ZERO,Art.INK)
	Art.box(ui,Vector3(2.42,1.42,0.035),Vector3(0,0,0.04),Art.CREAM)
	Art.label(ui,"ДЕСНИСЛАВА Е СПАСЕНА!" if won else "ДОМЪТ ПАДНА…",Vector3(0,0.46,0.07),43,Art.ORANGE)
	Art.label(ui,"Точки: %d  •  Рекорд: %d\nИзчистени: %d  •  Вълна: %d / 5" % [rules.score,best,rules.kills,rules.wave],Vector3(0,0.17,0.07),29,Art.INK)
	_add_button("start","ОЩЕ ВЕДНЪЖ",Vector2(0,-0.18),Vector2(1.7,0.26),Art.ORANGE)
	_add_button("menu","МЕНЮ",Vector2(0,-0.50),Vector2(1.2,0.20),Color("a2b96d"))

func _demo_hands() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for h in range(2):
		var p := Vector3(-0.22 if h==0 else 0.26,1.18,-0.58)
		var axis := Vector3(0,0,-1)
		if h == 1:
			p.y += sin(clock*6)*0.10
		var palm_basis := Basis(Vector3.RIGHT,-PI/2)
		var points: Array = []
		points.resize(26)
		points.fill(p)
		points[1] = p + palm_basis*Vector3(0,-0.042,0)
		var sign_x := 1.0 if h==0 else -1.0
		for j in range(2,6):
			points[j] = p+palm_basis*Vector3(sign_x*(0.025+(j-2)*0.009),-0.026+(j-2)*0.015,0.009)
		for finger in range(4):
			var x: float = (finger-1.5)*0.019*sign_x
			var first := 6+finger*5
			points[first] = p+palm_basis*Vector3(x,-0.012,0)
			points[first+1] = p+palm_basis*Vector3(x,0.029,0)
			points[first+2] = p+palm_basis*Vector3(x,0.056,0.004)
			points[first+3] = p+palm_basis*Vector3(x,0.050,0.026)
			points[first+4] = p+palm_basis*Vector3(x,0.024,0.030)
		var data: Dictionary = Gestures.classify(points,palm_basis)
		data.basis = palm_basis
		data.ray_origin = p
		data.ray_direction = axis
		output.append(data)
	return output

func _demo_step(delta: float) -> void:
	demo_time += delta
	if not intro_saved and clock>0.65 and qa_capture:
		intro_saved = true
		_capture.call_deferred("intro")
	if demo_stage == 0 and rules.state == "menu" and clock > 2.5:
		demo_stage = 1
		demo_time = 0
		if qa_capture:
			_capture.call_deferred("menu")
	if demo_stage == 1 and demo_time > 2.0:
		start_game()
		demo_stage = 2
		demo_time = 0
	if demo_stage == 2:
		if demo_time > 6 and demo_time < 6.1:
			rules.taunt()
		if demo_time > 13.5 and qa_capture:
			demo_stage = 3
			_capture.call_deferred("gameplay")
			demo_time = 0
	if demo_stage == 3 and demo_time > 2:
		get_tree().quit()

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://qa/"+filename+".png")
	print("CHAYKA CAPTURE ",filename)
