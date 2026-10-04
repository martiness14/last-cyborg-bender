extends RefCounted
## Renderer-independent arcade simulation. All durations use active game time.
signal event(kind: String, data: Dictionary)

const LAST_WAVE := 5
const MAX_ENEMIES := 12
const MAX_SHOTS := 256
const GRAVITY := Vector3(0,-9.81,0)
var pressure := 0.0
var pump_count := 0
var pump_stream := 0.0
var pump_idle := 0.0
var state := "intro"
var wave := 0
var health := 100.0
var foam := 45.0
var heat := 0.0
var overheated := false
var score := 0
var combo := 0
var combo_time := 0.0
var kills := 0
var rage := 0.0
var taunt_cd := 0.0
var clap_cd := 0.0
var shot_cd := 0.0
var shield := false
var remaining_spawns := 0
var spawn_clock := 0.0
var intermission := 0.0
var elapsed := 0.0
var next_id := 1
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var muck: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var emit_position := Vector3(0.25, 1.25, -0.8)
var emit_direction := Vector3.FORWARD

func _init(seed_value: int = 7349) -> void:
	rng.seed = seed_value

func reset() -> void:
	state = "playing"
	wave = 0
	health = 100.0
	foam = 45.0
	heat = 0.0
	pressure = 0.0
	pump_count = 0
	pump_stream = 0.0
	pump_idle = 0.0
	overheated = false
	score = 0
	combo = 0
	combo_time = 0.0
	kills = 0
	rage = 0.0
	taunt_cd = 0.0
	clap_cd = 0.0
	shot_cd = 0.0
	elapsed = 0.0
	shield = false
	enemies.clear()
	shots.clear()
	muck.clear()
	next_wave()

func next_wave() -> void:
	wave += 1
	if wave > LAST_WAVE:
		state = "victory"
		event.emit("victory", {"score": score})
		return
	state = "playing"
	remaining_spawns = 3 + wave * 2
	spawn_clock = 1.0
	foam = minf(100.0, foam + 18)
	event.emit("wave", {"wave": wave, "count": remaining_spawns})

func set_aim(position: Vector3, direction: Vector3) -> void:
	emit_position = position
	if direction.is_finite() and direction.length() > 0.1:
		emit_direction = direction.normalized()

func stroke(interval: float = 1.0) -> void:
	if state not in ["playing", "break"] or overheated:
		return
	# Deliberate strokes build pressure more efficiently than frantic shaking.
	var efficiency := clampf((interval-0.35)/0.65,0.0,1.0)
	pressure = minf(100.0,pressure + lerpf(5.0,8.0,efficiency))
	pump_count += 1
	pump_idle = 0.0
	pump_stream = clampf(interval*1.35,1.4,2.2)
	foam = minf(100.0, foam + 14.0)
	heat = minf(100.0, heat + lerpf(7.0,1.5,efficiency))
	event.emit("pump", {})
	if heat >= 100.0:
		overheated = true
		event.emit("overheat", {})

func flow_rate() -> float:
	if pressure <= 0.0 or pump_count == 0 or pump_stream <= 0.0:
		return 0.0
	var strength := pressure/100.0
	var rate := lerpf(3.0,100.0,strength*strength)
	# The strong, joined stream requires ten genuine full pumping cycles.
	if pump_count < 10:
		rate = minf(rate,22.0)
	var tail := clampf(pump_stream/0.45,0.0,1.0)
	return rate*tail

func fire(frame_age: float = -1.0) -> bool:
	var rate := flow_rate()
	if state != "playing" or rate < 1.0 or foam < 0.12 or overheated or shot_cd > 0 or shots.size() >= MAX_SHOTS:
		return false
	foam -= 0.12
	heat = minf(100.0,heat+0.09)
	var spread := Vector3(sin(elapsed*6.0)*0.002,sin(elapsed*4.0)*0.0015,0)
	var strength := pressure/100.0
	var speed := lerpf(1.8,16.0,strength)
	var velocity := (emit_direction+spread).normalized()*speed + Vector3.UP*lerpf(0.25,1.3,strength)
	var age_in_frame := maxf(0,frame_age)
	shots.append({"id":next_id,"pos":emit_position,"vel":velocity,"life":2.5,
		"size":lerpf(0.65,1.05,strength)*rng.randf_range(0.9,1.1),"damage":0.40,
		"born":elapsed-age_in_frame,
		"liquid":pump_count>=10 and pressure>=55.0})
	if frame_age >= 0.0:
		shots[-1]["first_step"] = age_in_frame
	next_id += 1
	shot_cd += 1.0/rate
	event.emit("shoot", {"pos":emit_position})
	if heat >= 100.0:
		overheated = true
		event.emit("overheat", {})
	return true

func taunt() -> bool:
	if state != "playing" or taunt_cd > 0.0:
		return false
	foam = minf(100.0, foam + 40.0)
	rage = 6.0
	taunt_cd = 12.0
	event.emit("taunt", {})
	return true

func clap() -> bool:
	if state != "playing" or clap_cd > 0 or foam < 55.0 or overheated:
		return false
	foam -= 55.0
	clap_cd = 8.0
	for e in enemies:
		if e.hp > 0 and e.pos.length() < 5.0:
			e.hp -= 4.0
			e.slow = 3.0
			e.pos.z -= 0.7
			if e.hp <= 0:
				kill_enemy(e, false)
	muck.clear()
	event.emit("clap", {})
	return true

func tick(delta: float, paused: bool = false) -> void:
	if paused or state not in ["playing", "break"]:
		return
	elapsed += delta
	pump_idle += delta
	if pump_idle > 2.2:
		pressure = maxf(0,pressure-delta*10.0)
	pump_stream = maxf(0,pump_stream-delta)
	shot_cd = maxf(-delta,shot_cd-delta)
	taunt_cd = maxf(0, taunt_cd - delta)
	clap_cd = maxf(0, clap_cd - delta)
	rage = maxf(0, rage - delta)
	heat = maxf(0, heat - delta * 16.0)
	if overheated and heat <= 35:
		overheated = false
		event.emit("cooled", {})
	combo_time = maxf(0, combo_time - delta)
	if combo_time <= 0:
		combo = 0
	if shield and foam > 0:
		foam = maxf(0, foam - delta * 9.0)
	else:
		shield = false
	if state == "break":
		intermission -= delta
		if intermission <= 0:
			next_wave()
		return
	if pump_stream > 0:
		for emission in range(8):
			if not fire(maxf(0,-shot_cd)):
				break
	spawn_clock -= delta
	if remaining_spawns > 0 and enemies.size() < MAX_ENEMIES and spawn_clock <= 0:
		spawn_enemy()
		remaining_spawns -= 1
		spawn_clock = maxf(0.65, 2.3 - wave * 0.22)
	for e in enemies:
		if e.hp <= 0:
			e.death -= delta
			continue
		e.age += delta
		e.flash = maxf(0, e.flash - delta)
		e.slow = maxf(0, e.slow - delta)
		var speed: float = e.speed * (1.55 if rage > 0 else 1.0) * (0.55 if e.slow > 0 else 1.0)
		var p: Vector3 = e.pos
		var target := Vector3(0, 0, 0.65)
		var stop_to_throw: bool = e.kind == 2 and p.distance_to(target) < 4.5
		if not stop_to_throw:
			e.pos = p.move_toward(target, delta * speed)
		else:
			e.throw_clock -= delta * (1.5 if rage > 0 else 1.0)
			if e.throw_clock <= 0:
				e.throw_clock = 3.3
				var source: Vector3 = e.pos + Vector3(0, 1.1, 0)
				muck.append({"id": next_id, "pos": source, "vel": (Vector3(0, 1.35, 0) - source).normalized() * 2.5, "life": 5.0})
				next_id += 1
				event.emit("throw", {"pos": source})
		if e.pos.distance_to(target) < 1.15:
			if shield and foam >= 8:
				foam -= 8
				e.pos.z -= 1.25
				e.slow = 1.8
				event.emit("block", {})
			else:
				damage(20 if e.kind == 1 else (16 if e.kind == 3 else 12))
				e.hp = 0
				e.death = 0.1
				if state == "defeat":
					return
	for shot in shots:
		var before: Vector3 = shot.pos
		var step: float = minf(delta,shot.get("first_step",delta))
		shot.erase("first_step")
		shot.pos += shot.vel * step + GRAVITY * (0.5*step*step)
		shot.vel += GRAVITY * step
		shot.life -= step
		if shot.pos.y < 0.025:
			shot.life = 0
			if int(shot.id)%8 == 0:
				event.emit("splash",{"pos":Vector3(shot.pos.x,0.025,shot.pos.z)})
			continue
		for e in enemies:
			if e.hp <= 0:
				continue
			var center: Vector3 = e.pos + Vector3(0, e.height * 0.52, 0)
			var closest: Vector3 = Geometry3D.get_closest_point_to_segment(center, before, shot.pos)
			var radius: float = 0.49 * e.scale
			if closest.distance_to(center) < radius:
				var headshot: bool = closest.y > e.height * 0.65
				# Orange brutes and cyborgs are armoured; the head stays the weak point.
				var armour: float = 1.0 if headshot else (0.5 if e.kind == 1 else (0.6 if e.kind == 3 else 1.0))
				e.hp -= shot.get("damage",1.0) * (2.0 if headshot else 1.0) * armour
				e.flash = 0.15
				e.slow = 1.0
				shot.life = 0
				event.emit("hit", {"pos": closest, "critical": headshot})
				if e.hp <= 0:
					kill_enemy(e, headshot)
				break
	for blob in muck:
		blob.pos += blob.vel * delta
		blob.life -= delta
		if blob.pos.distance_to(Vector3(0, 1.35, 0)) < 0.65:
			blob.life = 0
			if shield and foam >= 4:
				foam -= 4
				event.emit("block", {})
			else:
				damage(9)
				if state == "defeat":
					return
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0 or e.death > 0)
	shots = shots.filter(func(s: Dictionary) -> bool: return s.life > 0)
	muck = muck.filter(func(s: Dictionary) -> bool: return s.life > 0)
	if enemies.is_empty() and remaining_spawns == 0:
		muck.clear()
		shots.clear()
		if wave >= LAST_WAVE:
			state = "victory"
			event.emit("victory", {"score": score})
		else:
			state = "break"
			intermission = 5.0
			health = minf(100, health + 8)
			event.emit("break", {})

func spawn_enemy(forced_kind: int = -1) -> Dictionary:
	var kind: int = forced_kind if forced_kind >= 0 else (rng.randi_range(0, mini(2, wave - 1)))
	# Cyborgs join from the second wave onwards.
	if forced_kind < 0 and wave >= 2 and rng.randf() < 0.3:
		kind = 3
	var lane: int = rng.randi_range(0, 2)
	var positions := [Vector3(-3.0, 0, -5.8), Vector3(0, 0, -7.0), Vector3(3.0, 0, -5.8)]
	var size: float = 1.25 if kind == 1 else (1.12 if kind == 3 else 1.0)
	var boss: bool = wave == LAST_WAVE and remaining_spawns == 1
	if boss:
		size = 1.65
		kind = 3
	var hp: float = (3.0 if kind == 0 else (4.5 if kind == 3 else 5.0)) + wave * 0.4
	if boss:
		hp = 22.0
	var base_speed: float = 0.50 if kind == 1 else (0.72 if kind == 3 else 0.65)
	var e := {"id": next_id, "kind": kind, "pos": positions[lane], "hp": hp, "max_hp": hp,
		"height": 1.55 * size, "scale": size, "speed": base_speed + wave * 0.045,
		"slow": 0.0, "flash": 0.0, "death": 0.65, "age": 0.0, "throw_clock": 2.2, "boss": boss}
	next_id += 1
	enemies.append(e)
	event.emit("spawn", {"id": e.id, "boss": boss})
	return e

func kill_enemy(e: Dictionary, critical: bool) -> void:
	e.hp = 0
	e.death = 0.65
	kills += 1
	combo = mini(5, combo + 1)
	combo_time = 3.0
	var points: int = (150 if e.kind == 1 else (175 if e.kind == 3 else 100)) * combo + (50 if critical else 0)
	if e.boss:
		points += 1000
	score += points
	foam = minf(100, foam + 5)
	event.emit("kill", {"pos": e.pos + Vector3(0, 1.2, 0), "points": points, "combo": combo})

func damage(amount: float) -> void:
	health = maxf(0, health - amount)
	combo = 0
	event.emit("damage", {"amount": amount})
	if health <= 0:
		state = "defeat"
		event.emit("defeat", {"score": score})
