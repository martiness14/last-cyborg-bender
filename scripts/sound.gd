extends Node
var pool: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var enabled := true
var next_voice := 0
var anthem: AudioStreamWAV
var anthem_player: AudioStreamPlayer
var anthem_task := -1

func _exit_tree() -> void:
	_finish_anthem_task()
	anthem_player.stop()
	anthem_player.stream = null
	for player in pool:
		player.stop()
		player.stream = null
	sounds.clear()

func _ready() -> void:
	for n in range(10):
		var player := AudioStreamPlayer.new()
		player.volume_db = -15
		add_child(player)
		pool.append(player)
	var specs := {"shoot":[740,210,0.13], "pump":[180,480,0.12], "hit":[1100,180,0.08],
		"kill":[520,900,0.20], "wave":[240,780,0.55], "taunt":[190,80,0.5],
		"block":[900,600,0.12], "clap":[240,40,0.38], "damage":[120,45,0.3],
		"menu":[330,660,0.45], "victory":[440,1100,0.85], "defeat":[350,60,0.85],
		"overheat":[1000,650,0.4], "cooled":[260,600,0.2], "intro_stroke":[280,420,0.12], "title":[110,440,1.5]}
	for key in specs:
		var s: Array = specs[key]
		sounds[key] = synth(s[0],s[1],s[2],key in ["shoot","clap","hit"])
	# The cyborg boss gets its own full-level voice; ~20 s of music is rendered off the main thread.
	anthem_player = AudioStreamPlayer.new()
	anthem_player.volume_db = 0.0
	add_child(anthem_player)
	anthem_task = WorkerThreadPool.add_task(_render_anthem)

func synth(start: float, finish: float, duration: float, noisy: bool) -> AudioStreamWAV:
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var count := int(duration * 22050)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	var random := RandomNumberGenerator.new()
	random.seed = 531
	for n in range(count):
		var t := float(n)/count
		phase += TAU * lerpf(start,finish,t)/22050.0
		var envelope := minf(t*30,1.0)*pow(1.0-t,1.6)
		var value := (sin(phase)*0.65 + sin(phase*1.5)*0.15)
		if noisy:
			value += random.randf_range(-0.2,0.2)
		bytes.encode_s16(n*2,int(value*envelope*22000))
	wave.data = bytes
	return wave

func play(cue: String) -> void:
	if not enabled or not sounds.has(cue):
		return
	var player: AudioStreamPlayer = pool[next_voice % pool.size()]
	next_voice += 1
	player.stream = sounds[cue]
	player.play()

func _render_anthem() -> void:
	anthem = build_anthem()

func _finish_anthem_task() -> void:
	if anthem_task >= 0:
		WorkerThreadPool.wait_for_task_completion(anthem_task)
		anthem_task = -1

func anthem_length() -> float:
	_finish_anthem_task()
	return anthem.get_length() if anthem else 0.0

## Boss entrance music. Plays even when cues are muted: it is the cutscene, not a cue.
func play_anthem() -> void:
	_finish_anthem_task()
	if not anthem:
		return
	unmute_master()
	anthem_player.stream = anthem
	anthem_player.play()

func unmute_master() -> void:
	AudioServer.set_bus_mute(0,false)
	AudioServer.set_bus_volume_db(0,0.0)

func stop_anthem() -> void:
	anthem_player.stop()

static func midi_hz(note: int) -> float:
	return 440.0*pow(2.0,(note-69)/12.0)

## Synth-pop boss theme at 113 BPM: one groove bar, then an eight-bar hook with bass, pads and drums.
static func build_anthem() -> AudioStreamWAV:
	const RATE := 22050
	const STEP := 60.0/113.0/4.0
	# [MIDI note, sixteenths]; 0 is a rest.
	var a := [68,1, 70,1, 73,1, 70,1, 77,3, 77,3, 75,6]
	var b := [68,1, 70,1, 73,1, 70,1, 75,3, 75,3, 73,3, 72,1, 70,2]
	var c := [68,1, 70,1, 73,1, 70,1, 73,4, 75,2, 72,3, 70,1, 68,2, 0,2, 68,2, 75,4, 73,8]
	var e := [68,1, 70,1, 73,1, 70,1, 80,3, 72,3, 73,3, 72,1, 70,2]
	var lead: Array = [0,16]
	for part in [a,b,c,a,e,c]:
		lead.append_array(part)
	var roots := [37,39,36,41,37,39,44,44]
	var chords := [[61,65,68],[63,67,70],[60,63,67],[65,68,72],[61,65,68],[63,67,70],[60,63,68],[60,63,68]]
	var bars := 9
	var total := int(bars*16*STEP*RATE)+11025
	var mix := PackedFloat32Array()
	mix.resize(total)
	# Lead: bright pulse with a short attack and release.
	var at := 0
	for i in range(0,lead.size(),2):
		var length := int(lead[i+1]*STEP*RATE)
		if lead[i] > 0:
			var freq := midi_hz(lead[i])
			var phase := 0.0
			for n in range(length):
				phase = fmod(phase+freq/RATE,1.0)
				var env := minf(n/110.0,1.0)*minf((length-n)/330.0,1.0)
				var tone := (0.6 if phase < 0.5 else -0.6) + sin(phase*TAU)*0.35
				mix[at+n] += tone*env*0.34
		at += length
	var half := int(8*STEP*RATE)
	var eighth := int(2*STEP*RATE)
	for bar in range(bars):
		var harmony := (bar-1) % 4 if bar > 0 else 0
		for side in range(2):
			var slot := (harmony*2+side) % 8
			var start := int(bar*16*STEP*RATE)+side*half
			# Octave-jumping eighth-note bass.
			for k in range(4):
				var freq := midi_hz(roots[slot]+(12 if k%2==1 else 0))
				var phase := 0.0
				var from := start+k*eighth
				for n in range(eighth):
					phase = fmod(phase+freq/RATE,1.0)
					var env := minf(n/60.0,1.0)*pow(1.0-float(n)/eighth,0.7)
					mix[from+n] += (phase*2.0-1.0)*env*0.30
			for note in chords[slot]:
				var freq := midi_hz(note)
				for n in range(half):
					mix[start+n] += sin(TAU*freq*n/RATE)*minf(n/900.0,1.0)*minf((half-n)/900.0,1.0)*0.06
	# Kick on every beat, snare on two and four, offbeat hats.
	var noise := RandomNumberGenerator.new()
	noise.seed = 113
	for step in range(bars*16):
		var from := int(step*STEP*RATE)
		if step % 4 == 0:
			for n in range(int(0.16*RATE)):
				var t := float(n)/RATE
				mix[from+n] += sin(TAU*(50.0*t+140.0*(1.0-exp(-t*30.0))/30.0))*exp(-t*18.0)*0.55
		if step % 8 == 4:
			for n in range(int(0.14*RATE)):
				mix[from+n] += noise.randf_range(-1.0,1.0)*exp(-n/1100.0)*0.32
		if step % 4 == 2:
			for n in range(int(0.05*RATE)):
				mix[from+n] += noise.randf_range(-1.0,1.0)*exp(-n/250.0)*0.12
	var peak := 0.001
	for v in mix:
		peak = maxf(peak,absf(v))
	var gain := 0.97/peak
	var bytes := PackedByteArray()
	bytes.resize(total*2)
	for n in range(total):
		bytes.encode_s16(n*2,int(clampf(mix[n]*gain,-1.0,1.0)*32767.0))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = RATE
	wave.data = bytes
	return wave
