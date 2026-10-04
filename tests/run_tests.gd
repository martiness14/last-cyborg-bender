extends SceneTree
const Rules = preload("res://scripts/rules.gd")
const Gestures = preload("res://scripts/gestures.gd")
const Sound = preload("res://scripts/sound.gd")
var checks := 0
var integration_completed := false
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _init() -> void:
	run.call_deferred()

func hand(pos: Vector3, fist: bool = true) -> Dictionary:
	return {"valid":true,"palm":pos,"axis":Vector3.FORWARD,"fist":fist,
		"open":not fist,"middle":false,"pinch_distance":0.06}

func skeleton(extended: Array) -> Array:
	var points: Array = []
	points.resize(26)
	points.fill(Vector3.ZERO)
	points[0] = Vector3(0,0.04,0)
	points[1] = Vector3.ZERO
	points[5] = Vector3(-0.075,0.06,0)
	for f in range(4):
		var x := (float(f)-1.5)*0.023
		var base := 7+f*5
		points[base-1] = Vector3(x,0.035,0)
		points[base] = Vector3(x,0.065,0)
		points[base+1] = Vector3(x,0.095,-0.008 if not extended[f] else 0)
		points[base+2] = Vector3(x,0.110 if extended[f] else 0.080,-0.027 if not extended[f] else 0)
		points[base+3] = Vector3(x,0.135 if extended[f] else 0.055,-0.025 if not extended[f] else 0)
	return points

func run() -> void:
	var g = Gestures.new()
	var open: Dictionary = Gestures.classify(skeleton([true,true,true,true]))
	var closed: Dictionary = Gestures.classify(skeleton([false,false,false,false]))
	var middle: Dictionary = Gestures.classify(skeleton([false,true,false,false]))
	check(open.open and not open.fist and not open.middle,"Open palm classified")
	check(closed.fist and not closed.middle,"Closed hand classified")
	check(middle.middle and not middle.fist,"Isolated middle finger classified")
	check(not Gestures.classify([]).valid,"Missing joint data rejected")
	var strokes := 0
	for i in range(180):
		var out: Dictionary = g.update(hand(Vector3(0,0,-0.2)),hand(Vector3.ZERO),1.0/90)
		strokes += int(out.stroke)
	check(strokes==0,"Stationary hands do not charge")
	g.reset_motion()
	for i in range(180):
		var translation := Vector3(float(i)*0.01,0,float(i)*0.003)
		var out: Dictionary = g.update(hand(translation+Vector3(0,0,-0.2)),hand(translation),1.0/90)
		strokes += int(out.stroke)
	check(strokes==0,"Horizontal translation does not charge")
	g.reset_motion()
	for i in range(270):
		var out: Dictionary = g.update({"valid":false},hand(Vector3(0,sin(i/90.0*8)*0.08,0)),1.0/90)
		strokes += int(out.stroke)
	check(strokes>=3,"Right fist pumps vertically with no left hand")
	g.update(hand(Vector3.ZERO),{"valid":false},0.02)
	check(not g.active,"Tracking loss resets motion history")
	var out: Dictionary = g.update(hand(Vector3(0,0,-0.4)),hand(Vector3.ZERO),0.02)
	check(not out.stroke,"Reacquiring hands cannot emit a stroke")
	for orientation in [Vector3.UP,Vector3.DOWN,Vector3.LEFT,Vector3.FORWARD]:
		g.reset_motion()
		strokes = 0
		for i in range(180):
			var rh := hand(Vector3(0,sin(i/90.0*8)*0.08,0))
			rh.axis = orientation
			strokes += int(g.update(hand(Vector3(2,0,2),false),rh,1.0/90).stroke)
		check(strokes>=2,"Pump ignores palm direction: "+str(orientation))
	g.reset_motion()
	strokes = 0
	for i in range(180):
		strokes += int(g.update({"valid":false},hand(Vector3(0,sin(i*0.7)*0.012,0)),1.0/90).stroke)
	check(strokes==0,"Small vertical tracking jitter cannot pump")
	g.reset_motion()
	strokes = 0
	for i in range(180):
		strokes += int(g.update({"valid":false},hand(Vector3(0,sin(i/90.0*8)*0.08,0),false),1.0/90).stroke)
	check(strokes==0,"Moving open right palm cannot pump")
	g.reset_motion()
	g.update({"valid":false},hand(Vector3.ZERO),0.02)
	check(not g.update({"valid":false},hand(Vector3(0,0.5,0)),0.2).stroke,"Tracking teleport cannot pump")
	check(Gestures.classify(skeleton([true,false,false,false])).fist,"Loose pipe grip accepts slightly extended index finger")
	var taunts := 0
	var mh: Dictionary = hand(Vector3(0,0,-0.2))
	mh.middle = true
	mh.fist = false
	for i in range(200):
		taunts += int(g.update(mh,hand(Vector3.ZERO),0.01).taunt)
	check(taunts==1,"Middle gesture fires once per hold")
	g.reset_motion()
	g.update(hand(Vector3(-0.3,0,0),false),hand(Vector3(0.3,0,0),false),0.02)
	out = g.update(hand(Vector3(-0.04,0,0),false),hand(Vector3(0.04,0,0),false),0.02)
	check(out.clap,"Clap requires separated palms then convergence")
	check(not g.update(hand(Vector3(-0.04,0,0),false),hand(Vector3(0.04,0,0),false),0.02).clap,"Held palms cannot repeat clap")
	g.reset_motion()
	var pinchy := hand(Vector3(0,0,-0.2))
	pinchy.pinch_distance = 0.020
	check(g.update(pinchy,hand(Vector3.ZERO),0.02).pinch_left,"Pinch activation edge")
	check(not g.update(pinchy,hand(Vector3.ZERO),0.02).pinch_left,"Held pinch does not repeat menu clicks")
	var r = Rules.new(1)
	r.reset()
	check(r.wave==1 and r.state=="playing" and r.health==100,"Start initializes first wave")
	var time_before: float = r.spawn_clock
	r.tick(2.0,true)
	check(r.spawn_clock==time_before and r.elapsed==0,"Pause freezes spawn and game clocks")
	r.foam = 10
	check(r.taunt() and r.foam==50 and r.rage==6,"Taunt grants foam and rage")
	check(not r.taunt(),"Taunt cooldown blocks farming")
	r.foam = 30
	check(not r.clap(),"Clap enforces resource cost")
	r.remaining_spawns = 0
	var enemy: Dictionary = r.spawn_enemy(0)
	enemy.pos = Vector3(0,0,-3)
	enemy.hp = 0.25
	r.foam = 100
	r.stroke(1.0)
	r.pressure = 100
	r.set_aim(Vector3(0,0.85,-0.6),Vector3.FORWARD)
	check(r.fire(),"Foam shot spawns")
	r.tick(0.20)
	check(enemy.hp<=0 and r.score>0,"Swept collision prevents fast foam passing through an enemy")
	r.reset()
	r.remaining_spawns = 0
	enemy = r.spawn_enemy(0)
	enemy.pos = Vector3(0,0,-0.4)
	r.shield = true
	r.tick(0.016)
	check(r.health==100 and enemy.pos.z < -1,"Shield repels approaching enemies")
	r.shield = false
	enemy.pos = Vector3(0,0,-0.4)
	r.tick(0.016)
	check(r.health==88,"Unblocked enemy damages home")
	r.reset()
	r.heat = 99
	r.stroke()
	check(r.overheated,"Heat reaches overheat state")
	check(not r.fire(),"Overheat blocks firing")
	r.tick(4.2)
	check(not r.overheated,"Cooling releases overheat lock")
	r.damage(500)
	check(r.state=="defeat" and r.health==0,"Defeat transition clamps health")
	r.reset()
	check(r.score==0 and r.kills==0 and not r.overheated and r.health==100,"Restart clears prior run state")
	for n in range(10):
		r.stroke(1.0)
	# End-to-end simulation: real shots and real collisions across every wave, including boss.
	var steps := 0
	while r.state not in ["victory","defeat"] and steps < 24000:
		if r.state=="playing":
			r.foam = 100
			r.pressure = 100
			r.pump_stream = 2.0
			r.heat = 0
			r.overheated = false
			for e in r.enemies:
				if e.hp>0:
					var source := Vector3(0,1.05,0)
					var target: Vector3 = e.pos+Vector3(0,e.height*0.56,0)
					var flight: float = source.distance_to(target)/16.0
					# Ballistic aiming bot: lead the approaching target and compensate gravity.
					target += (Vector3(0,0,0.65)-e.pos).normalized()*e.speed*flight
					var aim: Vector3 = target-source-Vector3.UP*1.3*flight-Vector3(0,-9.81,0)*0.5*flight*flight
					r.set_aim(source,aim.normalized())
					r.fire()
					break
		r.tick(1.0/60)
		steps += 1
	check(r.state=="victory" and r.wave==5,"All five waves can be completed via shot collisions")
	check(r.kills==45,"Every scheduled enemy, including final boss, can be cleared")
	# Regression: open palms and pumping must never implicitly request pause.
	g.reset_motion()
	var accidental_pause := false
	for n in range(240):
		var palms: Dictionary = g.update(hand(Vector3(-0.3,1,0),false),hand(Vector3(0.3,1,0),false),1.0/60)
		accidental_pause = accidental_pause or palms.get("pause",false)
	check(not accidental_pause,"Holding open palms for four seconds never requests pause")
	var slow = Rules.new(2)
	var fast = Rules.new(2)
	slow.reset()
	fast.reset()
	slow.stroke(0.7)
	fast.stroke(0.18)
	check(slow.pressure>fast.pressure and slow.heat<fast.heat,"Slow deliberate pump builds more pressure and less heat")
	var charged: float = slow.pressure
	slow.tick(0.1,true)
	check(slow.pressure==charged,"Pause freezes pressure and stream")
	var ballistics = Rules.new(3)
	ballistics.reset()
	ballistics.remaining_spawns = 99
	ballistics.spawn_clock = 99
	ballistics.shots.append({"id":1,"pos":Vector3(0,1.5,0),"vel":Vector3(0,3,-8),"life":2.5})
	ballistics.tick(0.2)
	check(absf(ballistics.shots[0].pos.y-(1.5+3*0.2-0.5*9.81*0.04))<0.0001,"Foam follows a gravitational parabola")
	check(absf(ballistics.shots[0].vel.y-(3-9.81*0.2))<0.0001,"Foam vertical velocity accelerates downward")
	ballistics.shots.clear()
	ballistics.shots.append({"id":2,"pos":Vector3(0,0.04,0),"vel":Vector3(0,-2,-8),"life":2.5})
	ballistics.tick(0.05)
	check(ballistics.shots.is_empty(),"Foam stops at floor instead of flying below the house")
	ballistics.stroke(1.0)
	ballistics.pressure = 8
	ballistics.fire()
	var low_speed: float = absf(ballistics.shots[0].vel.z)
	ballistics.shots.clear()
	ballistics.shot_cd = 0
	ballistics.pressure = 100
	ballistics.fire()
	check(absf(ballistics.shots[0].vel.z)>low_speed*2,"Pressure increases launch speed and range")
	var liquid = Rules.new(8)
	liquid.reset()
	liquid.spawn_clock = 999
	check(liquid.pressure==0 and liquid.pump_count==0 and not liquid.fire(),"New run cannot emit before any pumping")
	for n in range(120):
		liquid.tick(1.0/60)
	check(liquid.shots.is_empty(),"Waiting with zero pumps never produces foam")
	liquid.taunt()
	check(not liquid.fire(),"Foam bonus cannot bypass pump requirement")
	liquid.stroke(1.0)
	var weak_rate: float = liquid.flow_rate()
	check(weak_rate<5.0 and liquid.pressure<=8.0,"First full pump produces only a weak trickle")
	for cycle in range(1,9):
		for n in range(60):
			liquid.tick(1.0/60)
		liquid.stroke(1.0)
	check(liquid.pump_count==9 and liquid.flow_rate()<=22.0,"Nine full pumps cannot unlock the dense stream")
	liquid.stroke(1.0)
	check(liquid.pump_count==10 and liquid.flow_rate()>weak_rate*10 and liquid.pressure>=75,"Ten full pumps build the stronger liquid flow")
	for n in range(15):
		liquid.tick(1.0/60)
	check(liquid.shots.any(func(drop: Dictionary) -> bool: return drop.get("liquid",false)),"Strong flow marks droplets for continuous liquid rendering")
	for n in range(300):
		liquid.tick(1.0/60)
	check(liquid.flow_rate()==0 and liquid.shots.is_empty(),"Stopping pumping fades the stream and clears its tail")
	liquid.reset()
	check(liquid.pressure==0 and liquid.pump_count==0,"Restart clears all accumulated pumping")
	g.reset_motion()
	var full_cycles := 0
	for i in range(121):
		var height := 0.12*sin(float(i)*TAU/120.0)
		full_cycles += int(g.update({"valid":false},hand(Vector3(0,height,0)),1.0/120).stroke)
	check(full_cycles==1,"One physical up-down cycle counts once, not twice")
	var cyborgs = Rules.new(4)
	cyborgs.reset()
	var cyborg: Dictionary = cyborgs.spawn_enemy(3)
	check(cyborg.kind==3 and cyborg.scale>1.0 and cyborg.speed>0.72,"Cyborg bender spawns as its own faster, larger type")
	var wave_one_cyborg := false
	for n in range(60):
		wave_one_cyborg = wave_one_cyborg or cyborgs.spawn_enemy().kind==3
	check(not wave_one_cyborg,"First wave has no cyborgs")
	cyborgs.wave = 3
	var later_cyborg := false
	for n in range(60):
		later_cyborg = later_cyborg or cyborgs.spawn_enemy().kind==3
	check(later_cyborg,"Cyborgs join random spawns from the second wave")
	cyborgs.wave = Rules.LAST_WAVE
	cyborgs.remaining_spawns = 1
	var boss: Dictionary = cyborgs.spawn_enemy()
	check(boss.boss and boss.kind==3 and boss.hp==22.0,"Final boss is the cyborg bender")
	var armoured = Rules.new(5)
	armoured.reset()
	armoured.remaining_spawns = 0
	armoured.spawn_clock = 99
	var target: Dictionary = armoured.spawn_enemy(3)
	target.pos = Vector3(0,0,-3)
	var full_hp: float = target.hp
	armoured.shots.append({"id":900,"pos":Vector3(0,0.8,-2.6),"vel":Vector3(0,0,-8),"life":2.5,"damage":1.0})
	armoured.tick(0.1)
	check(absf(full_hp-target.hp-0.6)<0.0001,"Cyborg body armour absorbs part of a hit")
	var anthem: AudioStreamWAV = Sound.build_anthem()
	check(anthem.get_length()>15.0 and anthem.get_length()<25.0,"Cyborg boss theme renders at full length")
	await integration()
	check(integration_completed,"Integration suite reaches completion without runtime abort")
	var report := {"checks":checks,"passed":checks-failures.size(),"failures":failures,"physical_quest_test":false}
	var file := FileAccess.open("res://qa/tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("CHAYKA TESTS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func integration() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.save_scores = false
	await process_frame
	main.set_process(false)
	check(not main.ui.visible and not main.level.visible,"Runtime starts in black room without title or house")
	for n in range(20):
		main._process(0.05)
	check(main.ui.visible and main.buttons.size()==2,"Animated title menu appears automatically without any tracked hands")
	main.tracking_ready = true
	main.menu_debounce = 0
	var hit: Vector3 = main.ui.to_global(Vector3(0,-0.60,0.14))
	var origin := Vector3(0,1.3,-0.4)
	var sample: Array[Dictionary] = [{"valid":true,"ray_origin":origin,"ray_direction":(hit-origin).normalized()},
		{"valid":true,"ray_origin":origin,"ray_direction":(hit-origin).normalized()}]
	main._menu_input(sample,{"pinch_right":true})
	check(main.rules.state=="playing" and main.level.visible and not main.ui.visible,"Hand ray plus pinch starts gameplay")
	main.rules.spawn_enemy(1)
	main._sync_game(0.016)
	check(main.enemy_nodes.size()==1,"Simulation enemy produces a 3D rig")
	var model = main.enemy_nodes.values()[0].model
	check(model.parts.size()==6 and model.parts.head.mesh.get_aabb().size.z>0.4,"Enemy has articulated volumetric geometry with real depth")
	main._recenter_scene()
	check(not main.paused and not main.ui.visible,"Recentering does not open pause menu")
	main.tracking_ready = true
	var pause_hit: Vector3 = main.pause_button.to_global(Vector3(0,0,0.02))
	var pause_sample: Array[Dictionary] = [{"valid":false},{"valid":true,"ray_origin":origin,"ray_direction":(pause_hit-origin).normalized()}]
	main._pause_input(pause_sample,{"pinch_right":true},0.016)
	check(not main.paused,"A passing pinch cannot pause before deliberate hover")
	for n in range(50):
		main._pause_input(pause_sample,{},0.016)
	main._pause_input(pause_sample,{"pinch_right":true},0.016)
	check(main.paused and main.ui.visible,"Intentional hover then pinch opens pause")
	main._activate_button("continue")
	main.rules.shots.assign([{"id":1,"pos":Vector3(0,1,0),"vel":Vector3(0,0,-8),"liquid":true,"born":0.0},
		{"id":2,"pos":Vector3(0.1,0.99,-0.2),"vel":Vector3(0,0,-8),"liquid":true,"born":0.02}])
	main._sync_liquid()
	check(main.liquid_batch.multimesh.visible_instance_count==1,"Consecutive strong-flow droplets form a continuous liquid segment")
	var liquid_transform: Transform3D = main.liquid_segment_transform(Vector3(0,1,0),Vector3(0.1,0.99,-0.2),0.008)
	check(liquid_transform.basis.y.normalized().dot(Vector3(0.1,-0.01,-0.2).normalized())>0.999,"Liquid segment follows trajectory rather than world vertical")
	check((liquid_transform*Vector3(0,0.5,0)).distance_to(Vector3(0.1,0.99,-0.2))<0.0001,"Liquid connector reaches the next droplet without a gap")
	main.rules.shots[1].id = 4
	main._sync_liquid()
	check(main.liquid_batch.multimesh.visible_instance_count==0,"Liquid does not bridge gaps left by hits")
	main.rules.shots.clear()
	main.rules.damage(100)
	check(main.rules.state=="defeat" and main.ui.visible,"Defeat opens gesture result menu")
	main._activate_button("start")
	check(main.rules.health==100 and main.enemy_nodes.is_empty(),"Gesture restart clears enemies and restores health")
	main.rules.spawn_enemy(3)
	main._sync_game(0.016)
	var cyborg_rig = main.enemy_nodes.values()[0].model
	check(cyborg_rig.kind==3 and cyborg_rig.parts.size()==6,"Cyborg enemy produces an articulated 3D rig")
	main.rules.elapsed = main.CYBORG_ENTRANCE_AT
	main._start_cyborg_entrance()
	var frozen_time: float = main.rules.elapsed
	var frozen_pos: Vector3 = main.rules.enemies[0].pos
	for n in range(60):
		main._update_cyborg_entrance(0.05)
	check(main.cyborg_end<INF and main.cyborg_show.scale.is_equal_approx(Vector3.ONE),"Cyborg boss rises, then its theme starts")
	check(main.rules.elapsed==frozen_time and main.rules.enemies[0].pos==frozen_pos,"Fight is frozen during the cyborg entrance")
	for n in range(600):
		if main.cyborg_time < 0.0:
			break
		main._update_cyborg_entrance(0.05)
	check(main.cyborg_time<0.0 and main.cyborg_show==null and main.cyborg_seen,"Cyborg entrance ends and the fight resumes")
	# Drive the actual XRServer sampling path using known raw joint poses.
	var trackers: Array[XRHandTracker] = []
	for h in range(2):
		var tracker := XRHandTracker.new()
		tracker.name = "/user/hand_tracker/"+("left" if h==0 else "right")
		tracker.has_tracking_data = true
		tracker.hand_tracking_source = XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED
		var points: Array = skeleton([false,false,false,false])
		for j in range(26):
			tracker.set_hand_joint_transform(j,Transform3D(Basis.IDENTITY,points[j]+Vector3(h*0.3,1.0,-0.6)))
			tracker.set_hand_joint_flags(j,15)
		# A closed fist can put thumb and index together: it must not act as a gun trigger.
		tracker.set_hand_joint_transform(5,tracker.get_hand_joint_transform(10))
		XRServer.add_tracker(tracker)
		trackers.append(tracker)
	var tracked: Array[Dictionary] = main.hands.sample()
	check(tracked[0].valid and tracked[1].valid and tracked[0].fist,"Raw XR joint samples reach gesture classifier")
	check(tracked[1].palm.distance_to(Vector3(0.3,1.04,-0.6))<0.0001,"Joint positions use the XR origin correctly")
	trackers[1].hand_tracking_source = XRHandTracker.HAND_TRACKING_SOURCE_CONTROLLER
	check(not main.hands.sample_hand(1).valid,"Controller-derived skeletons are rejected")
	trackers[1].hand_tracking_source = XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED
	trackers[0].set_hand_joint_flags(10,0)
	check(not main.hands.sample_hand(0).valid,"Missing index joint blocks stale gesture data")
	trackers[0].set_hand_joint_flags(10,15)
	for n in range(40):
		main._process(0.016)
	check(main.tracking_ready and main.rules.elapsed>0,"Stable optical tracking resumes simulation")
	check(main.rules.pressure==0 and main.rules.pump_count==0 and main.rules.shots.is_empty(),"Stationary closed fist with pinched fingers cannot fire in actual gameplay")
	var active_time: float = main.rules.elapsed
	trackers[0].has_tracking_data = false
	main._process(0.016)
	check(main.tracking_ready and main.rules.elapsed>active_time,"Losing left hand does not stop right-hand gameplay")
	active_time = main.rules.elapsed
	trackers[1].has_tracking_data = false
	main._process(0.016)
	check(not main.tracking_ready and main.rules.elapsed==active_time,"Loss of right hand freezes simulation immediately")
	for tracker in trackers:
		XRServer.remove_tracker(tracker)
	main.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	integration_completed = true
